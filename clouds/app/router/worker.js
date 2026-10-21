const COOKIE_NAME = "clouds_origin";
const COOKIE_MAX_AGE = 3600;
const MAX_BODY_BYTES = 4096;
const READ_ORIGIN_TIMEOUT_MS = 2000;
const PROVIDERS = ["aws", "azure", "gcp", "digitalocean"];
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const schemaReady = new WeakMap();

class RequestError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...extraHeaders,
    },
  });
}

async function readMessage(request) {
  if (request.headers.get("Content-Type")?.split(";")[0].trim().toLowerCase() !== "application/json") {
    throw new RequestError(415, "Use application/json.");
  }
  if (Number(request.headers.get("Content-Length")) > MAX_BODY_BYTES) {
    throw new RequestError(413, "Request body exceeds 4096 bytes.");
  }
  let text = "";
  let size = 0;
  const decoder = new TextDecoder("utf-8", { fatal: true });
  const reader = request.body?.getReader();
  try {
    if (reader) {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > MAX_BODY_BYTES) {
          await reader.cancel();
          throw new RequestError(413, "Request body exceeds 4096 bytes.");
        }
        text += decoder.decode(value, { stream: true });
      }
    }
    text += decoder.decode();
  } catch (error) {
    if (error instanceof RequestError) throw error;
    throw new RequestError(400, "Request body must be valid UTF-8 JSON.");
  } finally {
    reader?.releaseLock();
  }
  let message;
  try {
    message = JSON.parse(text);
  } catch {
    throw new RequestError(400, "Request body must be valid JSON.");
  }
  if (!message || typeof message !== "object" || Array.isArray(message)) {
    throw new RequestError(400, "Request body must be a message object.");
  }
  if (typeof message.id !== "string" || !UUID.test(message.id)) {
    throw new RequestError(400, "Message id must be a UUID.");
  }
  if (typeof message.text !== "string") {
    throw new RequestError(400, "Message text must be a string.");
  }
  message.text = message.text.trim();
  const length = Array.from(message.text).length;
  if (length < 1 || length > 500 || /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(message.text)) {
    throw new RequestError(400, "Message text must contain 1 to 500 Unicode characters.");
  }
  if (!PROVIDERS.includes(message.provider)) {
    throw new RequestError(400, "Message provider must be aws, azure, gcp, or digitalocean.");
  }
  if (typeof message.region !== "string" || !message.region.trim()) {
    throw new RequestError(400, "Message region is required.");
  }
  return message;
}

async function ensureSchema(db) {
  let ready = schemaReady.get(db);
  if (!ready) {
    ready = db.prepare(`CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      text TEXT NOT NULL,
      provider TEXT NOT NULL,
      region TEXT NOT NULL,
      created_at TEXT NOT NULL
    )`).run();
    schemaReady.set(db, ready);
    try {
      await ready;
    } catch (error) {
      schemaReady.delete(db);
      throw error;
    }
  } else {
    await ready;
  }
}

async function state(request, env, pathname) {
  if (typeof env.STATE_API_TOKEN !== "string" || !env.STATE_API_TOKEN) {
    return json({ error: "State authentication is not configured." }, 503);
  }
  if (request.headers.get("Authorization") !== `Bearer ${env.STATE_API_TOKEN}`) {
    return json({ error: "Unauthorized." }, 401, { "WWW-Authenticate": "Bearer" });
  }
  if (pathname !== "/state/messages") {
    return json({ error: "State endpoint not found." }, 404);
  }
  if (request.method !== "GET" && request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405, { Allow: "GET, POST" });
  }
  try {
    const incoming = request.method === "POST" ? await readMessage(request) : null;
    if (!env.DB) return json({ error: "State storage is not configured." }, 503);
    await ensureSchema(env.DB);
    // Each request starts at the primary, including reads after another cloud writes.
    const session = env.DB.withSession("first-primary");
    if (!incoming) {
      const { results } = await session.prepare(
        "SELECT id, text, provider, region, created_at FROM messages ORDER BY created_at DESC, id DESC LIMIT 50",
      ).all();
      return json({ messages: results });
    }
    const { id, text, provider, region } = incoming;
    // A transaction serializes concurrent retries without overwriting the original.
    const [insert, existing] = await session.batch([
      session.prepare(
        "INSERT INTO messages (id, text, provider, region, created_at) VALUES (?, ?, ?, ?, ?) ON CONFLICT(id) DO NOTHING",
      ).bind(id, text, provider, region, new Date().toISOString()),
      session.prepare(
        "SELECT id, text, provider, region, created_at FROM messages WHERE id = ?",
      ).bind(id),
    ]);
    const message = existing.results[0];
    if (!message) throw new Error("Inserted message is unavailable.");
    if (message.text !== text || message.provider !== provider || message.region !== region) {
      return json({ error: "Message id already belongs to a different payload." }, 409);
    }
    return json({ message }, insert.meta.changes === 1 ? 201 : 200);
  } catch (error) {
    if (error instanceof RequestError) return json({ error: error.message }, error.status);
    return json({ error: "State storage is unavailable." }, 503);
  }
}

function getCookie(request, name) {
  const cookies = request.headers.get("Cookie")?.split(";") ?? [];
  const prefix = `${name}=`;
  const entry = cookies.map((cookie) => cookie.trim()).find((cookie) => cookie.startsWith(prefix));
  try {
    return entry ? decodeURIComponent(entry.slice(prefix.length)) : null;
  } catch {
    return null;
  }
}

function routedResponse(response, origin, api) {
  const headers = new Headers(response.headers);
  headers.set("X-Lab-Origin", origin);
  if (api) headers.set("Cache-Control", "no-store");
  headers.append(
    "Set-Cookie",
    `${COOKIE_NAME}=${encodeURIComponent(origin)}; Path=/; Max-Age=${COOKIE_MAX_AGE}; Secure; HttpOnly; SameSite=Lax`,
  );
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

function originsFrom(binding) {
  // Wrangler --var supplies a string; Terraform's JSON binding supplies an object.
  const origins = typeof binding === "string" ? JSON.parse(binding) : (binding ?? {});
  if (!origins || typeof origins !== "object" || Array.isArray(origins)) throw new Error("Invalid origins.");
  const entries = Object.entries(origins);
  if (entries.length !== 0 && (entries.length !== 4 || entries.some(([name, address]) =>
    !PROVIDERS.includes(name) || typeof address !== "string"))) {
    throw new Error("Invalid origins.");
  }
  return entries.filter(([, address]) => address.trim());
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    // State is served locally even during bootstrap; never route it to Go again.
    if (url.pathname === "/state" || url.pathname.startsWith("/state/")) {
      return state(request, env, url.pathname);
    }
    let origins;
    try {
      origins = originsFrom(env.ORIGINS);
    } catch {
      return json({ error: "Router requires zero or exactly four valid cluster origins." }, 500);
    }
    if (!origins.length) {
      return json({ error: "Guestbook cluster endpoints are not configured yet." }, 503);
    }
    const pinnedOrigin = getCookie(request, COOKIE_NAME);
    const start = Math.floor(Math.random() * origins.length);
    const ordered = origins.slice(start).concat(origins.slice(0, start));
    const geographicOrigin = {
      NA: "aws", SA: "aws", EU: "azure", AF: "azure", AS: "gcp", OC: "digitalocean",
    }[request.cf?.continent];
    // Existing affinity wins; missing/unknown geolocation retains random selection.
    const preferredOrigin = origins.some(([name]) => name === pinnedOrigin) ? pinnedOrigin : geographicOrigin;
    const preferredIndex = ordered.findIndex(([name]) => name === preferredOrigin);
    if (preferredIndex > 0) ordered.unshift(...ordered.splice(preferredIndex, 1));
    const canFailOver = request.method === "GET" || request.method === "HEAD";
    for (const [name, address] of ordered) {
      try {
        const endpoint = new URL(`http://${address.trim()}`);
        const origin = new URL(request.url);
        origin.protocol = endpoint.protocol;
        origin.host = endpoint.host;
        // Only GET/HEAD can reach a second origin; mutations clone their body once.
        const response = await fetch(new Request(origin, request.clone()), {
          redirect: "manual",
          signal: canFailOver ? AbortSignal.timeout(READ_ORIGIN_TIMEOUT_MS) : request.signal,
        });
        if (canFailOver && response.status >= 500) continue;
        return routedResponse(response, name, url.pathname.startsWith("/api/"));
      } catch {
        if (!canFailOver) break;
      }
    }
    return json({ error: "Guestbook cluster endpoints are unavailable." }, 503);
  },
};
