import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createServer } from "node:http";
import { once } from "node:events";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { unstable_dev } from "wrangler";
import router from "./worker.js";

process.env.WRANGLER_SEND_METRICS = "false";

const token = randomUUID();
const script = fileURLToPath(new URL("./worker.js", import.meta.url));
const config = fileURLToPath(new URL("./wrangler.jsonc", import.meta.url));
const auth = { Authorization: `Bearer ${token}` };

async function startWorker(t, origins = {}) {
  const worker = await unstable_dev(script, {
    config,
    local: true,
    ip: "127.0.0.1",
    port: 0,
    inspectorPort: 0,
    persist: false,
    logLevel: "error",
    vars: { STATE_API_TOKEN: token, ORIGINS: origins },
    experimental: {
      forceLocal: true,
      disableExperimentalWarning: true,
      disableDevRegistry: true,
      watch: false,
    },
  });
  t.after(() => worker.stop());
  return worker;
}

function post(worker, message, headers = {}) {
  return worker.fetch("/state/messages", {
    method: "POST",
    headers: { ...auth, "Content-Type": "application/json", ...headers },
    body: JSON.stringify(message),
  });
}

function payload(overrides = {}) {
  return { id: randomUUID(), text: "Hello from AWS", provider: "aws", region: "eu-west-1", ...overrides };
}

test("authenticated state uses real local D1 during empty-origin bootstrap", async (t) => {
  const worker = await startWorker(t);
  await t.test("bootstrap and authentication are honest and uncached", async () => {
    assert.equal((await worker.fetch("/")).status, 503);
    for (const headers of [{}, { Authorization: "Bearer incorrect" }]) {
      const response = await worker.fetch("/state/messages", { headers });
      assert.equal(response.status, 401);
      assert.equal(response.headers.get("Cache-Control"), "no-store");
      assert.deepEqual(await response.json(), { error: "Unauthorized." });
    }
    const empty = await worker.fetch("/state/messages", { headers: auth });
    assert.equal(empty.status, 200);
    assert.deepEqual(await empty.json(), { messages: [] });
    assert.equal((await worker.fetch("/state/unknown", { headers: auth })).status, 404);
    const unsupported = await worker.fetch("/state/messages", { method: "DELETE", headers: auth });
    assert.equal(unsupported.status, 405);
    assert.equal(unsupported.headers.get("Allow"), "GET, POST");
  });
  await t.test("cross-provider writes share a primary-consistent history and stable retries", async () => {
    const aws = payload({ text: "  Hello from AWS 🌍  " });
    const azure = payload({ text: "Hello from Azure", provider: "azure", region: "westeurope" });
    const first = await post(worker, aws);
    assert.equal(first.status, 201);
    assert.equal(first.headers.get("Cache-Control"), "no-store");
    const { message } = await first.json();
    assert.equal(message.text, aws.text.trim());
    assert.equal(new Date(message.created_at).toISOString(), message.created_at);
    const replay = await post(worker, aws);
    assert.equal(replay.status, 200);
    assert.deepEqual(await replay.json(), { message });
    for (const conflict of [{ text: "changed" }, { provider: "gcp" }, { region: "other" }]) {
      assert.equal((await post(worker, { ...aws, ...conflict })).status, 409);
    }
    assert.equal((await post(worker, azure)).status, 201);
    const history = await (await worker.fetch("/state/messages", { headers: auth })).json();
    assert.equal(history.messages.length, 2);
    assert.ok(history.messages.some((row) => row.id === aws.id && row.provider === "aws" && row.region === "eu-west-1"));
    assert.ok(history.messages.some((row) => row.id === azure.id && row.provider === "azure" && row.region === "westeurope"));
    const concurrent = payload();
    const statuses = await Promise.all(Array.from({ length: 5 }, async () => (await post(worker, concurrent)).status));
    assert.deepEqual(statuses.sort(), [200, 200, 200, 200, 201]);
  });
  await t.test("validation bounds Unicode, request size, and malformed bodies", async () => {
    assert.equal((await post(worker, payload({ text: "🌍".repeat(500) }))).status, 201);
    for (const invalid of [
      { text: "🌍".repeat(501) }, { text: " \n\t " }, { text: "\ud800" },
      { id: "not-a-uuid" }, { provider: "unknown" }, { region: "" },
    ]) {
      assert.equal((await post(worker, payload(invalid))).status, 400);
    }
    assert.equal((await post(worker, payload({ text: "x".repeat(5000) }))).status, 413);
    assert.equal((await worker.fetch("/state/messages", {
      method: "POST", headers: { ...auth, "Content-Type": "application/json" }, body: "{",
    })).status, 400);
    assert.equal((await worker.fetch("/state/messages", {
      method: "POST", headers: { ...auth, "Content-Type": "application/json" }, body: new Uint8Array([0xff]),
    })).status, 400);
    assert.equal((await post(worker, payload(), { "Content-Type": "text/plain" })).status, 415);
  });
  await t.test("only latest fifty are returned in deterministic descending order", async () => {
    for (let i = 0; i < 51; i++) {
      assert.equal((await post(worker, payload({ text: `Message ${i}` }))).status, 201);
    }
    const { messages } = await (await worker.fetch("/state/messages", { headers: auth })).json();
    assert.equal(messages.length, 50);
    const ordered = [...messages].sort((a, b) =>
      a.created_at === b.created_at ? (a.id < b.id ? 1 : a.id > b.id ? -1 : 0) : (a.created_at < b.created_at ? 1 : -1));
    assert.deepEqual(messages, ordered);
  });
});

test("router uses continent geography unless a valid affinity cookie takes precedence", async (t) => {
  const providers = ["aws", "azure", "gcp", "digitalocean"];
  const origins = Object.fromEntries(providers.map((provider) => [provider, `${provider}.test:8080`]));
  const geography = { NA: "digitalocean", SA: "digitalocean", EU: "azure", AF: "azure", AS: "gcp", OC: "aws" };
  const hits = [];
  let randomStart = 0;
  t.mock.method(Math, "random", () => randomStart);
  t.mock.method(globalThis, "fetch", async (request) => {
    hits.push(new URL(request.url).host);
    return new Response("Healthy origin");
  });

  async function route(continent, cookie) {
    hits.length = 0;
    const request = new Request("https://guestbook.test/api/deployment", {
      headers: cookie ? { Cookie: cookie } : {},
    });
    // Node's Request has no Cloudflare metadata; inject it without changing the Worker API.
    Object.defineProperty(request, "cf", { value: { continent } });
    return router.fetch(request, { ORIGINS: origins });
  }

  async function assertOrigin(continent, cookie, expected) {
    // Ensure random fallback cannot accidentally satisfy the expected preference.
    randomStart = ((providers.indexOf(expected) + 1) % providers.length) / providers.length;
    const response = await route(continent, cookie);
    assert.equal(response.status, 200);
    assert.deepEqual(hits, [origins[expected]]);
    assert.equal(response.headers.get("X-Lab-Origin"), expected);
    assert.match(response.headers.get("Set-Cookie"), new RegExp(`clouds_origin=${expected};`));
    await response.text();
  }

  for (const [continent, provider] of Object.entries(geography)) {
    await t.test(`${continent} prefers ${provider} without valid affinity`, async () => {
      for (const cookie of [undefined, "clouds_origin=unknown", "clouds_origin=%ZZ"]) {
        await assertOrigin(continent, cookie, provider);
      }
    });
    await t.test(`${continent} preserves every valid provider cookie`, async () => {
      for (const pinned of providers) {
        await assertOrigin(continent, `clouds_origin=${pinned}`, pinned);
      }
    });
  }
});

test("router keeps stickiness and never replays mutations across origins", async (t) => {
  const hits = [];
  const origins = {};
  for (const provider of ["aws", "azure", "gcp", "digitalocean"]) {
    const server = createServer(async (request, response) => {
      let body = "";
      for await (const chunk of request) body += chunk;
      hits.push({ provider, method: request.method, path: request.url, body });
      if (provider === "aws" && request.url === "/network-failure") {
        request.socket.destroy();
        return;
      }
      if (provider === "aws" && request.url === "/slow-origin") {
        const timer = setTimeout(() => response.writeHead(503).end(), 8000);
        timer.unref();
        response.on("close", () => clearTimeout(timer));
        return;
      }
      response.writeHead(provider === "aws" ? 503 : 200, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ provider, body }));
    });
    server.listen(0, "127.0.0.1");
    await once(server, "listening");
    origins[provider] = `127.0.0.1:${server.address().port}`;
    t.after(() => new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve())));
  }
  // Exercise string bindings too, as used by local Wrangler --var overrides.
  const worker = await startWorker(t, JSON.stringify(origins));
  await t.test("GET fails over and updates the sticky cookie", async () => {
    hits.length = 0;
    const response = await worker.fetch("/api/deployment?proof=1", { headers: { Cookie: "clouds_origin=aws" } });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("Cache-Control"), "no-store");
    const origin = response.headers.get("X-Lab-Origin");
    assert.notEqual(origin, "aws");
    assert.match(response.headers.get("Set-Cookie"), new RegExp(`clouds_origin=${origin};.*Secure; HttpOnly; SameSite=Lax`));
    assert.equal(hits[0].provider, "aws");
    assert.equal(hits[1].provider, origin);
    assert.equal(hits[1].path, "/api/deployment?proof=1");
  });
  await t.test("HEAD fails over without inventing a response body", async () => {
    hits.length = 0;
    const response = await worker.fetch("/api/deployment", {
      method: "HEAD", headers: { Cookie: "clouds_origin=aws" },
    });
    assert.equal(response.status, 200);
    assert.equal(await response.text(), "");
    assert.equal(hits[0].provider, "aws");
    assert.equal(hits.length, 2);
  });
  await t.test("GET and HEAD abandon a stalled origin and stick to a healthy fallback", async () => {
    for (const method of ["GET", "HEAD"]) {
      hits.length = 0;
      const response = await worker.fetch("/slow-origin", {
        method,
        headers: { Cookie: "clouds_origin=aws" },
        signal: AbortSignal.timeout(6000),
      });
      assert.equal(response.status, 200);
      const origin = response.headers.get("X-Lab-Origin");
      assert.notEqual(origin, "aws");
      assert.equal(hits[0].provider, "aws");
      assert.equal(hits[1].provider, origin);
      assert.match(response.headers.get("Set-Cookie"), new RegExp(`clouds_origin=${origin};`));
      if (method === "HEAD") assert.equal(await response.text(), "");
      else assert.equal((await response.json()).provider, origin);
    }
  });
  await t.test("a malformed cookie does not throw", async () => {
    assert.equal((await worker.fetch("/", { headers: { Cookie: "clouds_origin=%ZZ" } })).status, 200);
  });
  await t.test("mutation 503 and network failure never try another cloud", async () => {
    for (const [method, path] of [
      ["POST", "/api/messages"], ["POST", "/network-failure"],
      ["PUT", "/api/messages"], ["PATCH", "/api/messages"], ["DELETE", "/api/messages"],
    ]) {
      hits.length = 0;
      const body = JSON.stringify({ id: randomUUID(), text: "do not replay me" });
      const response = await worker.fetch(path, {
        method, headers: { Cookie: "clouds_origin=aws", "Content-Type": "application/json" }, body,
      });
      assert.equal(response.status, 503);
      assert.equal(hits.length, 1);
      assert.equal(hits[0].provider, "aws");
      assert.equal(hits[0].body, body);
    }
  });
  await t.test("state bypasses all origin routing", async () => {
    hits.length = 0;
    assert.equal((await post(worker, payload())).status, 201);
    assert.equal((await worker.fetch("/state/messages", { headers: auth })).status, 200);
    assert.equal(hits.length, 0);
  });
});

test("empty provider values allow bootstrap and AWS-first routing", async (t) => {
  const empty = { aws: "", azure: "", gcp: "", digitalocean: "" };
  const bootstrap = await startWorker(t, empty);
  assert.equal((await bootstrap.fetch("/")).status, 503);
  const state = await bootstrap.fetch("/state/messages", { headers: auth });
  assert.equal(state.status, 200);
  assert.deepEqual(await state.json(), { messages: [] });

  const server = createServer((request, response) => {
    response.writeHead(200, { "Content-Type": "text/plain" });
    response.end("AWS application");
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve())));
  const worker = await startWorker(t, { ...empty, aws: `127.0.0.1:${server.address().port}` });
  for (const headers of [{}, { Cookie: "clouds_origin=azure" }]) {
    const response = await worker.fetch("/", { headers });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("X-Lab-Origin"), "aws");
    assert.match(response.headers.get("Set-Cookie"), /clouds_origin=aws;/);
    assert.equal(await response.text(), "AWS application");
  }
});
