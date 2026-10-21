/*
Copyright 2014 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"bytes"
	"context"
	"embed"
	"encoding/json"
	"errors"
	"io"
	"io/fs"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/redis/go-redis/v9"
)

//go:embed public/*
var assets embed.FS

type deployment struct {
	Provider  string `json:"provider"`
	Region    string `json:"region"`
	Continent string `json:"continent"`
	Pod       string `json:"pod"`
	Mode      string `json:"mode"`
	Storage   string `json:"storage"`
}

type config struct {
	Deployment   deployment
	StateURL     string
	StateToken   string
	RedisAddress string
	Port         string
}

type message struct {
	ID        string `json:"id"`
	Text      string `json:"text"`
	Provider  string `json:"provider"`
	Region    string `json:"region"`
	CreatedAt string `json:"created_at"`
}

type app struct {
	config    config
	client    *http.Client
	redis     *redis.Client
	redisKeys []string
}

func loadConfig(getenv func(string) string) (config, error) {
	c := config{Deployment: deployment{
		Provider: getenv("LAB_PROVIDER"), Region: strings.TrimSpace(getenv("LAB_REGION")),
		Continent: strings.TrimSpace(getenv("LAB_CONTINENT")), Pod: getenv("POD_NAME"),
	}, StateURL: strings.TrimRight(getenv("STATE_API_URL"), "/"), StateToken: getenv("STATE_API_TOKEN"),
		RedisAddress: strings.TrimSpace(getenv("REDIS_ADDRESS")), Port: getenv("PORT")}
	c.Deployment.Mode = getenv("APP_MODE")
	if c.Deployment.Mode == "" {
		c.Deployment.Mode = "local"
	}
	if c.Deployment.Mode != "local" && c.Deployment.Mode != "shared" {
		return config{}, errors.New("APP_MODE must be local or shared")
	}
	if c.Port == "" {
		c.Port = "8080"
	}
	if port, err := strconv.Atoi(c.Port); err != nil || port < 1 || port > 65535 {
		return config{}, errors.New("PORT must be a number between 1 and 65535")
	}
	switch c.Deployment.Provider {
	case "aws", "azure", "gcp", "digitalocean":
	default:
		return config{}, errors.New("LAB_PROVIDER must be aws, azure, gcp, or digitalocean")
	}
	if c.Deployment.Region == "" || c.Deployment.Continent == "" {
		return config{}, errors.New("LAB_REGION and LAB_CONTINENT are required")
	}
	if c.Deployment.Mode == "local" {
		host, port, err := net.SplitHostPort(c.RedisAddress)
		if err != nil || strings.TrimSpace(host) == "" || strings.ContainsAny(host, " \t\r\n/@") {
			return config{}, errors.New("REDIS_ADDRESS is required and must be host:port")
		}
		if n, err := strconv.Atoi(port); err != nil || n < 1 || n > 65535 {
			return config{}, errors.New("REDIS_ADDRESS must include a port between 1 and 65535")
		}
		c.Deployment.Storage = "redis"
		c.StateURL, c.StateToken = "", ""
		return c, nil
	}
	c.Deployment.Storage = "d1"
	c.RedisAddress = ""
	if strings.TrimSpace(c.StateToken) == "" || strings.ContainsAny(c.StateToken, "\r\n") {
		return config{}, errors.New("STATE_API_TOKEN is required and must not contain line breaks")
	}
	u, err := url.Parse(c.StateURL)
	if err != nil || u.Host == "" || u.User != nil || u.RawQuery != "" || u.Fragment != "" || u.Opaque != "" {
		return config{}, errors.New("STATE_API_URL must be an absolute HTTPS URL without credentials, query, or fragment")
	}
	loopback := u.Hostname() == "localhost"
	if ip := net.ParseIP(u.Hostname()); ip != nil {
		loopback = ip.IsLoopback()
	}
	if u.Scheme != "https" && !(u.Scheme == "http" && loopback) {
		return config{}, errors.New("STATE_API_URL requires HTTPS (HTTP is allowed only on localhost for local smoke checks)")
	}
	return c, nil
}

func (a *app) handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("GET /api/deployment", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, a.config.Deployment)
	})
	mux.HandleFunc("GET /api/messages", a.messages)
	mux.HandleFunc("POST /api/messages", a.postMessage)
	mux.HandleFunc("/api/", func(w http.ResponseWriter, r *http.Request) {
		writeError(w, http.StatusNotFound, "API endpoint not found")
	})
	public, err := fs.Sub(assets, "public")
	if err != nil {
		panic(err)
	}
	files := http.FileServer(http.FS(public))
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			w.Header().Set("Allow", "GET, HEAD")
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}
		if r.URL.Path != "/" && r.URL.Path != "/style.css" && r.URL.Path != "/script.js" {
			http.NotFound(w, r)
			return
		}
		files.ServeHTTP(w, r)
	})
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'")
		w.Header().Set("Cache-Control", "no-store")
		mux.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func writeError(w http.ResponseWriter, status int, text string) {
	writeJSON(w, status, map[string]string{"error": text})
}

func decodeJSON(r io.Reader, target any) error {
	d := json.NewDecoder(r)
	d.DisallowUnknownFields()
	if err := d.Decode(target); err != nil {
		return err
	}
	if err := d.Decode(new(any)); err != io.EOF {
		return errors.New("expected one JSON object")
	}
	return nil
}

func validID(id string) bool {
	if len(id) != 36 {
		return false
	}
	for i, c := range id {
		if i == 8 || i == 13 || i == 18 || i == 23 {
			if c != '-' {
				return false
			}
		} else if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
			return false
		}
	}
	return true
}

func (a *app) messages(w http.ResponseWriter, r *http.Request) {
	var result struct {
		Messages []message `json:"messages"`
	}
	if a.config.Deployment.Storage == "redis" {
		ctx, cancel := context.WithTimeout(r.Context(), 4*time.Second)
		defer cancel()
		rows, err := a.redis.Eval(ctx, redisReadMessages, a.messageKeys()).StringSlice()
		if err != nil {
			writeError(w, http.StatusServiceUnavailable, "Local message store is unavailable; please try again")
			return
		}
		result.Messages = make([]message, 0, len(rows))
		for _, row := range rows {
			var m message
			if json.Unmarshal([]byte(row), &m) != nil {
				writeError(w, http.StatusBadGateway, "Local message store returned an invalid message list")
				return
			}
			result.Messages = append(result.Messages, m)
		}
		writeJSON(w, http.StatusOK, result)
		return
	}
	if !a.stateRequest(w, r, nil, &result) {
		return
	}
	if result.Messages == nil {
		writeError(w, http.StatusBadGateway, "Shared message service returned an invalid message list")
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (a *app) postMessage(w http.ResponseWriter, r *http.Request) {
	mediaType := strings.TrimSpace(strings.Split(r.Header.Get("Content-Type"), ";")[0])
	if !strings.EqualFold(mediaType, "application/json") {
		writeError(w, http.StatusUnsupportedMediaType, "Use application/json")
		return
	}
	var input struct {
		ID   string `json:"id"`
		Text string `json:"text"`
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 4096))
	if err != nil {
		writeError(w, http.StatusRequestEntityTooLarge, "Message request is too large")
		return
	}
	if !utf8.Valid(body) || decodeJSON(bytes.NewReader(body), &input) != nil {
		writeError(w, http.StatusBadRequest, "Expected a JSON object with id and text")
		return
	}
	input.Text = strings.TrimSpace(input.Text)
	if !validID(input.ID) {
		writeError(w, http.StatusBadRequest, "id must be a UUID")
		return
	}
	if n := utf8.RuneCountInString(input.Text); n < 1 || n > 500 {
		writeError(w, http.StatusBadRequest, "Message must contain 1 to 500 characters")
		return
	}
	if a.config.Deployment.Storage == "redis" {
		a.postRedisMessage(w, r, input.ID, input.Text)
		return
	}
	payload, _ := json.Marshal(struct {
		ID       string `json:"id"`
		Text     string `json:"text"`
		Provider string `json:"provider"`
		Region   string `json:"region"`
	}{input.ID, input.Text, a.config.Deployment.Provider, a.config.Deployment.Region})
	var result struct {
		Message message `json:"message"`
	}
	if a.stateRequest(w, r, payload, &result) {
		if result.Message.ID != input.ID || result.Message.Text != input.Text || result.Message.Provider != a.config.Deployment.Provider || result.Message.Region != a.config.Deployment.Region || result.Message.CreatedAt == "" {
			writeError(w, http.StatusBadGateway, "Shared message service did not confirm this message; retry the same message to confirm")
			return
		}
		writeJSON(w, http.StatusOK, result)
	}
}

func (a *app) stateRequest(w http.ResponseWriter, r *http.Request, payload []byte, result any) bool {
	req, err := http.NewRequestWithContext(r.Context(), r.Method, a.config.StateURL+"/state/messages", bytes.NewReader(payload))
	if err != nil {
		writeError(w, http.StatusBadGateway, "Shared message service is unavailable")
		return false
	}
	req.Header.Set("Authorization", "Bearer "+a.config.StateToken)
	req.Header.Set("Accept", "application/json")
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := a.client.Do(req)
	if err != nil {
		writeError(w, http.StatusBadGateway, "Shared message service is unreachable; your message may not have been saved. Retry with the same message.")
		return false
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		status, text := http.StatusBadGateway, "Shared message service returned an error"
		switch resp.StatusCode {
		case http.StatusConflict:
			status, text = http.StatusConflict, "This message id is already used by a different message"
		case http.StatusBadRequest, http.StatusRequestEntityTooLarge:
			status, text = resp.StatusCode, "Shared message service rejected the message"
		case http.StatusTooManyRequests:
			status, text = http.StatusTooManyRequests, "Shared message service is busy; please try again"
		case http.StatusUnauthorized, http.StatusForbidden:
			text = "Shared message service authentication failed; contact the operator"
		case http.StatusServiceUnavailable:
			status, text = http.StatusServiceUnavailable, "Shared message service is unavailable; please try again"
		}
		writeError(w, status, text)
		return false
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 256*1024+1))
	if err != nil || len(body) > 256*1024 || decodeJSON(bytes.NewReader(body), result) != nil {
		writeError(w, http.StatusBadGateway, "Shared message service returned an invalid response")
		return false
	}
	return true
}

// Keep every ID to preserve idempotency even after it leaves the latest-50 view.
// Both scripts execute atomically; EVAL avoids a script-cache fallback round trip.
var redisMessageKeys = []string{"guestbook:messages", "guestbook:order"}

func (a *app) messageKeys() []string {
	if a.redisKeys != nil {
		return a.redisKeys
	}
	return redisMessageKeys
}

const redisReadMessages = `
local ids = redis.call('ZREVRANGE', KEYS[2], 0, 49)
local messages = {}
for _, id in ipairs(ids) do
  local message = redis.call('HGET', KEYS[1], id)
  if not message then return redis.error_reply('message index is inconsistent') end
  messages[#messages + 1] = message
end
return messages
`

const redisWriteMessage = `
local existing = redis.call('HGET', KEYS[1], ARGV[1])
if existing then
  local message = cjson.decode(existing)
  if message.text ~= ARGV[2] or message.provider ~= ARGV[3] or message.region ~= ARGV[4] then
    return {0, ''}
  end
  return {1, existing}
end
redis.call('HSET', KEYS[1], ARGV[1], ARGV[5])
redis.call('ZADD', KEYS[2], ARGV[6], ARGV[1])
return {1, ARGV[5]}
`

func newRedisClient(address string) *redis.Client {
	return redis.NewClient(&redis.Options{
		Addr: address, Protocol: 2, MaxRetries: -1, DisableIdentity: true,
		DialTimeout: 3 * time.Second, ReadTimeout: 3 * time.Second, WriteTimeout: 3 * time.Second,
		ContextTimeoutEnabled: true,
	})
}

func (a *app) postRedisMessage(w http.ResponseWriter, r *http.Request, id, text string) {
	now := time.Now().UTC()
	m := message{ID: id, Text: text, Provider: a.config.Deployment.Provider,
		Region: a.config.Deployment.Region, CreatedAt: now.Format("2006-01-02T15:04:05.000Z")}
	payload, _ := json.Marshal(m)
	ctx, cancel := context.WithTimeout(r.Context(), 4*time.Second)
	defer cancel()
	result, err := a.redis.Eval(ctx, redisWriteMessage, a.messageKeys(),
		id, text, m.Provider, m.Region, payload, now.UnixMilli()).Slice()
	if err != nil || len(result) != 2 {
		writeError(w, http.StatusServiceUnavailable, "Local message store is unavailable; your message may not have been saved. Retry with the same message.")
		return
	}
	status, ok := result[0].(int64)
	if !ok {
		writeError(w, http.StatusBadGateway, "Local message store returned an invalid response")
		return
	}
	if status == 0 {
		writeError(w, http.StatusConflict, "This message id is already used by a different message")
		return
	}
	stored, ok := result[1].(string)
	if !ok || json.Unmarshal([]byte(stored), &m) != nil || m.ID != id || m.Text != text ||
		m.Provider != a.config.Deployment.Provider || m.Region != a.config.Deployment.Region || m.CreatedAt == "" {
		writeError(w, http.StatusBadGateway, "Local message store did not confirm this message; retry the same message to confirm")
		return
	}
	writeJSON(w, http.StatusOK, struct {
		Message message `json:"message"`
	}{m})
}

func main() {
	c, err := loadConfig(os.Getenv)
	if err != nil {
		log.Fatal(err)
	}
	a := &app{config: c, client: &http.Client{
		Timeout:       12 * time.Second,
		CheckRedirect: func(r *http.Request, via []*http.Request) error { return http.ErrUseLastResponse },
	}}
	if c.Deployment.Storage == "redis" {
		a.redis = newRedisClient(c.RedisAddress)
		defer a.redis.Close()
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		err := a.redis.Ping(ctx).Err()
		cancel()
		if err != nil {
			log.Fatal("Local message store is unavailable")
		}
	}
	srv := &http.Server{Addr: ":" + c.Port, Handler: a.handler(), ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout: 10 * time.Second, WriteTimeout: 20 * time.Second, IdleTimeout: 60 * time.Second}
	log.Printf("Guestbook listening on :%s (%s / %s / %s)", c.Port, c.Deployment.Provider, c.Deployment.Region, c.Deployment.Mode)
	log.Fatal(srv.ListenAndServe())
}
