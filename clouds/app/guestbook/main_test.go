package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"
)

const testID = "a6ca7a10-d040-47ed-9fbc-af535ee40883"

func testEnvironment() map[string]string {
	return map[string]string{
		"LAB_PROVIDER": "aws", "LAB_REGION": "us-east-1", "LAB_CONTINENT": "North America", "POD_NAME": "guestbook-test",
		"APP_MODE": "shared", "STATE_API_URL": "https://state.example.test", "STATE_API_TOKEN": "secret-never-public",
	}
}

func configFrom(t *testing.T, values map[string]string) config {
	t.Helper()
	c, err := loadConfig(func(key string) string { return values[key] })
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func TestInvalidConfiguration(t *testing.T) {
	cases := []struct{ key, value string }{
		{"LAB_PROVIDER", "unknown"}, {"LAB_REGION", " "}, {"LAB_CONTINENT", ""}, {"APP_MODE", "unknown"},
		{"APP_MODE", "stateless"}, {"APP_MODE", "stateful"},
		{"STATE_API_TOKEN", ""}, {"STATE_API_TOKEN", "secret\r\nheader: value"},
		{"STATE_API_URL", "http://state.example.test"}, {"STATE_API_URL", "/state"},
		{"STATE_API_URL", "https://user:password@state.example.test"},
		{"STATE_API_URL", "https://state.example.test?token=secret"}, {"STATE_API_URL", "https://state.example.test/#secret"},
		{"PORT", "0"}, {"PORT", "65536"}, {"PORT", "localhost:8080"},
	}
	for _, tc := range cases {
		t.Run(tc.key+"="+tc.value, func(t *testing.T) {
			env := testEnvironment()
			env[tc.key] = tc.value
			if _, err := loadConfig(func(key string) string { return env[key] }); err == nil {
				t.Fatal("invalid configuration accepted")
			}
		})
	}
}

func TestMetadataDoesNotExposeStateCredentials(t *testing.T) {
	env := testEnvironment()
	a := &app{config: configFrom(t, env)}
	rr := httptest.NewRecorder()
	a.handler().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/api/deployment", nil))
	if rr.Code != http.StatusOK || rr.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("metadata status/cache: %d %v", rr.Code, rr.Header())
	}
	if strings.Contains(rr.Body.String(), env["STATE_API_TOKEN"]) || strings.Contains(rr.Body.String(), env["STATE_API_URL"]) {
		t.Fatal("private state configuration exposed")
	}
	if !strings.Contains(rr.Body.String(), `"mode":"shared"`) || !strings.Contains(rr.Body.String(), `"storage":"d1"`) {
		t.Fatal("shared deployment did not identify shared mode and D1 storage")
	}
	for _, path := range []string{"/env", "/info", "/lrange/guestbook", "/rpush/guestbook/hello", "/api/request"} {
		rr := httptest.NewRecorder()
		a.handler().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, path, nil))
		if rr.Code != http.StatusNotFound {
			t.Errorf("private/unsupported path %s accessible: %d", path, rr.Code)
		}
	}
}

func TestLocalConfigurationAndMetadata(t *testing.T) {
	env := testEnvironment()
	delete(env, "APP_MODE")
	env["REDIS_ADDRESS"] = "redis-private.example:6379"
	c := configFrom(t, env)
	if c.Deployment.Mode != "local" || c.Deployment.Storage != "redis" || c.StateURL != "" || c.StateToken != "" {
		t.Fatalf("unexpected local configuration: %+v", c.Deployment)
	}
	a := &app{config: c}
	for _, path := range []string{"/api/deployment", "/api/request"} {
		rr := httptest.NewRecorder()
		a.handler().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, path, nil))
		want := http.StatusOK
		if path == "/api/request" {
			want = http.StatusNotFound
		}
		if rr.Code != want || strings.Contains(rr.Body.String(), env["REDIS_ADDRESS"]) || strings.Contains(rr.Body.String(), env["STATE_API_TOKEN"]) {
			t.Fatalf("unexpected local metadata/retired endpoint: %d %s", rr.Code, rr.Body.String())
		}
		if path == "/api/deployment" && (!strings.Contains(rr.Body.String(), `"mode":"local"`) || !strings.Contains(rr.Body.String(), `"storage":"redis"`)) {
			t.Fatal("local deployment did not identify local mode and Redis storage")
		}
	}
	for _, address := range []string{"", "redis", ":6379", "redis:0", "redis:65536", "redis:wrong", "redis://redis:6379", "user@redis:6379", "redis\nprivate:6379"} {
		t.Run(address, func(t *testing.T) {
			env["REDIS_ADDRESS"] = address
			if _, err := loadConfig(func(key string) string { return env[key] }); err == nil {
				t.Fatal("invalid Redis address accepted")
			}
		})
	}
}

func TestExplicitDatastoreModes(t *testing.T) {
	for _, tc := range []struct{ mode, storage string }{{"local", "redis"}, {"shared", "d1"}} {
		t.Run(tc.mode, func(t *testing.T) {
			env := testEnvironment()
			env["APP_MODE"], env["REDIS_ADDRESS"] = tc.mode, "redis:6379"
			c := configFrom(t, env)
			if c.Deployment.Mode != tc.mode || c.Deployment.Storage != tc.storage {
				t.Fatalf("unexpected datastore configuration: %+v", c.Deployment)
			}
			if tc.mode == "local" && (c.StateURL != "" || c.StateToken != "") {
				t.Fatal("local mode retained shared datastore credentials")
			}
			if tc.mode == "shared" && c.RedisAddress != "" {
				t.Fatal("shared mode retained a local Redis address")
			}
		})
	}
}

func TestMessageInputErrors(t *testing.T) {
	cases := []struct {
		name, body, contentType string
		status                  int
	}{
		{"wrong media", `{}`, "text/plain", http.StatusUnsupportedMediaType},
		{"bad JSON", `{`, "application/json", http.StatusBadRequest},
		{"multiple objects", `{} {}`, "application/json", http.StatusBadRequest},
		{"invalid UUID", `{"id":"not-a-uuid","text":"hello"}`, "application/json", http.StatusBadRequest},
		{"blank", `{"id":"` + testID + `","text":"   \n "}`, "application/json", http.StatusBadRequest},
		{"over limit", `{"id":"` + testID + `","text":"` + strings.Repeat("🌍", 501) + `"}`, "application/json", http.StatusBadRequest},
		{"forged provider", `{"id":"` + testID + `","text":"hello","provider":"azure"}`, "application/json", http.StatusBadRequest},
		{"oversized", strings.Repeat("x", 4097), "application/json", http.StatusRequestEntityTooLarge},
		{"invalid UTF8", "{\"id\":\"" + testID + "\",\"text\":\"\xff\"}", "application/json", http.StatusBadRequest},
	}
	for _, mode := range []string{"shared", "local"} {
		env := testEnvironment()
		env["APP_MODE"], env["REDIS_ADDRESS"] = mode, "redis:6379"
		a := &app{config: configFrom(t, env), client: &http.Client{Transport: transportFunc(func(r *http.Request) (*http.Response, error) {
			t.Fatal("invalid input reached state service")
			return nil, nil
		})}}
		// A nil Redis client also makes any invalid request reaching storage fail.
		for _, tc := range cases {
			t.Run(mode+"/"+tc.name, func(t *testing.T) {
				rr := httptest.NewRecorder()
				r := httptest.NewRequest(http.MethodPost, "/api/messages", strings.NewReader(tc.body))
				r.Header.Set("Content-Type", tc.contentType)
				a.handler().ServeHTTP(rr, r)
				if rr.Code != tc.status {
					t.Fatalf("want %d, got %d: %s", tc.status, rr.Code, rr.Body.String())
				}
			})
		}
	}
}

type transportFunc func(*http.Request) (*http.Response, error)

func (fn transportFunc) RoundTrip(r *http.Request) (*http.Response, error) { return fn(r) }

func TestUpstreamFailuresDoNotLeakResponseOrToken(t *testing.T) {
	for _, tc := range []struct{ upstream, want int }{
		{401, 502}, {403, 502}, {409, 409}, {429, 429}, {503, 503}, {500, 502}, {302, 502},
	} {
		t.Run(http.StatusText(tc.upstream), func(t *testing.T) {
			c := configFrom(t, testEnvironment())
			a := &app{config: c, client: &http.Client{Transport: transportFunc(func(r *http.Request) (*http.Response, error) {
				return &http.Response{StatusCode: tc.upstream, Header: make(http.Header), Body: io.NopCloser(bytes.NewBufferString("upstream-private " + c.StateToken))}, nil
			})}}
			rr := httptest.NewRecorder()
			a.handler().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/api/messages", nil))
			if rr.Code != tc.want {
				t.Fatalf("want %d, got %d", tc.want, rr.Code)
			}
			if strings.Contains(rr.Body.String(), c.StateToken) || strings.Contains(rr.Body.String(), "upstream-private") {
				t.Fatal("upstream secrets exposed")
			}
		})
	}
}

func TestInterfaceAssetsDoNotRemainCachedAcrossDeployments(t *testing.T) {
	a := &app{config: configFrom(t, testEnvironment())}
	handler := a.handler()
	for _, path := range []string{"/", "/style.css?v=20261021-ui", "/script.js?v=20261021-ui"} {
		t.Run(path, func(t *testing.T) {
			rr := httptest.NewRecorder()
			handler.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, path, nil))
			if rr.Code != http.StatusOK {
				t.Fatalf("asset unavailable: %d", rr.Code)
			}
			if rr.Header().Get("Cache-Control") != "no-store" {
				t.Fatalf("interface asset can remain stale after rollout: %v", rr.Header())
			}
		})
	}
}

func localTestConfig(t *testing.T, address string) config {
	t.Helper()
	env := testEnvironment()
	env["APP_MODE"], env["REDIS_ADDRESS"] = "local", address
	return configFrom(t, env)
}

func messageRequest(a *app, id, text string) *httptest.ResponseRecorder {
	body, _ := json.Marshal(map[string]string{"id": id, "text": text})
	r := httptest.NewRequest(http.MethodPost, "/api/messages", bytes.NewReader(body))
	r.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	a.handler().ServeHTTP(rr, r)
	return rr
}

func decodeMessage(t *testing.T, rr *httptest.ResponseRecorder) message {
	t.Helper()
	var result struct {
		Message message `json:"message"`
	}
	if rr.Code != http.StatusOK || json.Unmarshal(rr.Body.Bytes(), &result) != nil {
		t.Fatalf("message write failed: %d %s", rr.Code, rr.Body.String())
	}
	return result.Message
}

func readMessages(t *testing.T, a *app) []message {
	t.Helper()
	rr := httptest.NewRecorder()
	a.handler().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/api/messages", nil))
	var result struct {
		Messages []message `json:"messages"`
	}
	if rr.Code != http.StatusOK || json.Unmarshal(rr.Body.Bytes(), &result) != nil || result.Messages == nil {
		t.Fatalf("message read failed: %d %s", rr.Code, rr.Body.String())
	}
	return result.Messages
}

func TestRedisFailuresAreSanitized(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := listener.Addr().String()
	if err := listener.Close(); err != nil {
		t.Fatal(err)
	}
	client := newRedisClient(address)
	defer client.Close()
	a := &app{config: localTestConfig(t, address), redis: client}
	for _, method := range []string{http.MethodGet, http.MethodPost} {
		r := httptest.NewRequest(method, "/api/messages", strings.NewReader(`{"id":"`+testID+`","text":"hello"}`))
		r.Header.Set("Content-Type", "application/json")
		rr := httptest.NewRecorder()
		a.handler().ServeHTTP(rr, r)
		if rr.Code != http.StatusServiceUnavailable || strings.Contains(rr.Body.String(), address) ||
			strings.Contains(rr.Body.String(), "dial tcp") || strings.Contains(rr.Body.String(), "connection refused") {
			t.Fatalf("unsanitized Redis failure: %d %s", rr.Code, rr.Body.String())
		}
		if method == http.MethodPost && !strings.Contains(rr.Body.String(), "Retry with the same message") {
			t.Fatal("uncertain write did not retain idempotent retry guidance")
		}
	}
}

// Set REDIS_TEST_ADDRESS to a real Redis instance. Each run owns random keys and
// deletes only those keys; no FLUSHDB or simulated Redis responses are used.
func TestRedisGuestbook(t *testing.T) {
	address := os.Getenv("REDIS_TEST_ADDRESS")
	if address == "" {
		t.Skip("set REDIS_TEST_ADDRESS to run against real Redis")
	}
	var namespace [16]byte
	if _, err := rand.Read(namespace[:]); err != nil {
		t.Fatal(err)
	}
	prefix := fmt.Sprintf("guestbook:test:%x", namespace)
	keys := []string{prefix + ":messages", prefix + ":order"}
	client := newRedisClient(address)
	t.Cleanup(func() { _ = client.Close() })
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := client.Ping(ctx).Err(); err != nil {
		t.Fatalf("real Redis is unavailable: %v", err)
	}
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := client.Del(ctx, keys...).Err(); err != nil {
			t.Errorf("cleaning isolated Redis keys: %v", err)
		}
	})
	a := &app{config: localTestConfig(t, address), redis: client, redisKeys: keys,
		client: &http.Client{Transport: transportFunc(func(r *http.Request) (*http.Response, error) {
			t.Error("local messages called shared D1 service")
			return nil, fmt.Errorf("unexpected shared request")
		})}}
	if got := readMessages(t, a); len(got) != 0 {
		t.Fatalf("new local guestbook is not empty: %+v", got)
	}
	first := decodeMessage(t, messageRequest(a, testID, "  hello 🌍 \n"))
	if first.ID != testID || first.Text != "hello 🌍" || first.Provider != "aws" || first.Region != "us-east-1" {
		t.Fatalf("message lost content or server writer metadata: %+v", first)
	}
	if _, err := time.Parse(time.RFC3339Nano, first.CreatedAt); err != nil {
		t.Fatalf("invalid server timestamp: %q", first.CreatedAt)
	}
	// A separate client/app must see persisted messages and original retry time.
	secondClient := newRedisClient(address)
	t.Cleanup(func() { _ = secondClient.Close() })
	second := &app{config: a.config, redis: secondClient, redisKeys: keys}
	if got := decodeMessage(t, messageRequest(second, testID, first.Text)); got != first {
		t.Fatalf("retry changed original message: %+v != %+v", got, first)
	}
	if got := readMessages(t, second); len(got) != 1 || got[0] != first {
		t.Fatalf("another app cannot read the saved message: %+v", got)
	}
	if rr := messageRequest(second, testID, "different"); rr.Code != http.StatusConflict {
		t.Fatalf("same ID with changed text was accepted: %d %s", rr.Code, rr.Body.String())
	}
	for _, change := range []func(*deployment){
		func(d *deployment) { d.Provider = "azure" },
		func(d *deployment) { d.Region = "eu-west-1" },
	} {
		other := *second
		change(&other.config.Deployment)
		if rr := messageRequest(&other, testID, first.Text); rr.Code != http.StatusConflict {
			t.Fatalf("same ID with changed writer metadata was accepted: %d %s", rr.Code, rr.Body.String())
		}
	}
	const concurrentID = "00000000-0000-4000-8000-000000000001"
	var wg sync.WaitGroup
	responses := make(chan *httptest.ResponseRecorder, 16)
	for range cap(responses) {
		wg.Add(1)
		go func() {
			defer wg.Done()
			responses <- messageRequest(second, concurrentID, "concurrent")
		}()
	}
	wg.Wait()
	close(responses)
	var concurrent message
	for rr := range responses {
		got := decodeMessage(t, rr)
		if concurrent.ID == "" {
			concurrent = got
		}
		if got != concurrent {
			t.Fatalf("concurrent retries returned different originals: %+v != %+v", got, concurrent)
		}
	}
	all := []message{first, concurrent}
	for i := range 55 {
		id := fmt.Sprintf("00000000-0000-4000-8000-%012x", i+2)
		all = append(all, decodeMessage(t, messageRequest(second, id, fmt.Sprintf("message %d", i))))
	}
	sort.Slice(all, func(i, j int) bool {
		if all[i].CreatedAt == all[j].CreatedAt {
			return all[i].ID > all[j].ID
		}
		return all[i].CreatedAt > all[j].CreatedAt
	})
	got := readMessages(t, second)
	if len(got) != 50 {
		t.Fatalf("latest view contains %d messages, want 50", len(got))
	}
	for i := range got {
		if got[i] != all[i] {
			t.Fatalf("latest view ordering/content mismatch at %d: %+v != %+v", i, got[i], all[i])
		}
	}
	if retried := decodeMessage(t, messageRequest(second, testID, first.Text)); retried != first {
		t.Fatalf("old message lost idempotency after leaving latest-50 view: %+v", retried)
	}
	if n, err := client.HLen(context.Background(), keys[0]).Result(); err != nil || n != int64(len(all)) {
		t.Fatalf("retries duplicated or lost persisted messages: count=%d err=%v", n, err)
	}
}
