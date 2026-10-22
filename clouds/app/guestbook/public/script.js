"use strict";

(() => {
  const $ = (id) => document.getElementById(id);
  const providers = { aws: "AWS", azure: "Azure", gcp: "Google Cloud", digitalocean: "DigitalOcean" };
  // Approximate points for actual configured provider regions, never inferred from IP or provider.
  const regions = {
    "us-east-1": [105, 75], "us-east-2": [100, 70], "us-west-2": [65, 66], "us-west-1": [63, 78],
    "eu-west-1": [192, 56], "eu-central-1": [210, 59], "eu-west-2": [198, 58],
    "ap-southeast-2": [380, 177],
    "westeurope": [206, 55], "northeurope": [196, 52], "eastus": [105, 75], "westus2": [65, 66],
    "asia-northeast1-a": [365, 83], "asia-northeast1": [365, 83], "us-central1": [91, 74], "us-central1-a": [91, 74],
    "europe-west1": [204, 58], "europe-west1-b": [204, 58], "syd1": [380, 177], "nyc1": [108, 70],
    "nyc3": [108, 70], "sfo3": [63, 78], "ams3": [206, 55], "fra1": [210, 59], "lon1": [198, 58], "sgp1": [318, 133]
  };
  let deployment = null;
  let sending = false;
  let refreshing = false;
  let pending = null;
  try {
    const saved = JSON.parse(sessionStorage.getItem("cloud-guestbook-pending"));
    if (saved && typeof saved.id === "string" && typeof saved.text === "string") {
      pending = saved;
      $("message-text").value = saved.text;
    }
  } catch (_) { /* Storage may be disabled; the current page still retains retry identity. */ }

  function status(id, text, error = false) {
    $(id).textContent = text;
    $(id).classList.toggle("error", error);
  }

  async function request(path, options = {}) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 16000);
    try {
      const response = await fetch(path, { ...options, cache: "no-store", signal: controller.signal, headers: { Accept: "application/json", ...options.headers } });
      let data;
      try { data = await response.json(); } catch (_) { throw new Error("The server returned an unreadable response."); }
      if (!response.ok) {
        const error = new Error(typeof data.error === "string" ? data.error : `Request failed (${response.status}).`);
        error.status = response.status;
        throw error;
      }
      return data;
    } catch (error) {
      if (error.name === "AbortError") throw new Error("The request timed out. Its result is uncertain; retry the same message to avoid duplicates.");
      if (error instanceof TypeError) throw new Error("Unable to reach the app. Check your connection and try again.");
      throw error;
    } finally { clearTimeout(timeout); }
  }

  function applyDeployment(data) {
    if (!Object.hasOwn(providers, data.provider) || !data.region || !data.continent || !["local", "shared"].includes(data.mode) || data.storage !== (data.mode === "local" ? "redis" : "d1")) {
      throw new Error("The deployment returned incomplete metadata.");
    }
    deployment = data;
    document.body.dataset.provider = data.provider;
    $("provider-name").textContent = providers[data.provider];
    $("region-name").textContent = data.region;
    $("continent-name").textContent = data.continent;
    $("pod-name").textContent = data.pod || "Not provided";
    $("map-status").textContent = "METADATA LOADED";
    $("map-caption").textContent = `${data.region} · ${data.continent}`;
    const local = data.mode === "local";
    const modeLabel = local ? "Local datastore" : "Shared datastore";
    document.title = `${providers[data.provider]} · Global Guestbook · ${modeLabel}`;
    const point = regions[data.region];
    $("region-marker").toggleAttribute("hidden", !point);
    // SVG uses presentation attributes, not inline CSS; the point is selected only from the region table.
    if (point) $("region-marker").setAttribute("transform", `translate(${point[0]} ${point[1]})`);
    document.querySelectorAll("[data-cloud]").forEach((element) => element.classList.toggle("active", element.dataset.cloud === data.provider));
    $("messages-workspace").hidden = false;
    $("storage-mode").textContent = modeLabel;
    $("storage-title").textContent = local ? "Storage: cluster-local Redis" : "Storage: Cloudflare D1";
    $("storage-description").textContent = local ? "writes to this cluster's Redis." : "writes to the shared database.";
    $("storage-footer").textContent = local ? "CLUSTER-LOCAL REDIS" : "SHARED D1 DATABASE";
    document.querySelector(".topbar-note").lastChild.textContent = ` ${modeLabel} · ${local ? "Cluster Redis" : "Cloudflare D1"}`;
    document.querySelector(".deployment-description").textContent = local ? "Messages stay in this cluster and are not shared with other providers." : "Messages are shared across all providers through Cloudflare D1.";
    $("deployment-error").hidden = true;
    updateCount();
  }

  function updateCount() {
    const count = Array.from($("message-text").value.trim()).length;
    $("character-count").textContent = `${count} / 500`;
    $("character-count").classList.toggle("over-limit", count > 500);
    $("send-button").disabled = sending || !deployment || count < 1 || count > 500;
  }

  function renderMessages(messages) {
    if (!Array.isArray(messages)) throw new Error("The storage service returned an invalid message list.");
    const fragment = document.createDocumentFragment();
    for (const message of messages) {
      if (!message || typeof message.text !== "string" || !Object.hasOwn(providers, message.provider) || typeof message.region !== "string" || !Number.isFinite(Date.parse(message.created_at))) {
        throw new Error("The storage service returned an invalid message.");
      }
      const item = document.createElement("li");
      item.className = "message-item";
      item.dataset.provider = message.provider;
      const meta = document.createElement("div");
      meta.className = "message-meta";
      const origin = document.createElement("span");
      origin.className = "origin-badge";
      origin.dataset.provider = message.provider;
      origin.textContent = providers[message.provider];
      const region = document.createElement("span");
      region.className = "message-region";
      region.textContent = `Region: ${message.region}`;
      const timestamp = document.createElement("time");
      timestamp.className = "message-time";
      timestamp.dateTime = message.created_at;
      const date = new Date(message.created_at);
      timestamp.textContent = new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" }).format(date);
      timestamp.title = date.toLocaleString();
      meta.append("Writer: ", origin, region, timestamp);
      const text = document.createElement("p");
      text.className = "message-text";
      text.textContent = message.text;
      item.append(meta, text);
      fragment.append(item);
    }
    $("messages").replaceChildren(fragment);
    $("message-count").textContent = String(messages.length);
    $("empty-state").hidden = messages.length !== 0;
    $("last-updated").textContent = `Updated ${new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" })}`;
  }

  async function loadMessages() {
    $("messages-panel").setAttribute("aria-busy", "true");
    status("feed-status", "Loading messages…");
    try {
      const data = await request("/api/messages");
      renderMessages(data.messages);
      status("feed-status", "");
      return true;
    } catch (error) {
      $("empty-state").hidden = true;
      status("feed-status", `${error.message} Any messages shown below are from the last successful refresh.`, true);
      $("last-updated").textContent = "Refresh failed · storage unavailable";
      return false;
    } finally { $("messages-panel").setAttribute("aria-busy", "false"); }
  }

  async function refresh() {
    if (refreshing) return;
    refreshing = true;
    $("refresh-button").disabled = true;
    try {
      applyDeployment(await request("/api/deployment"));
      await loadMessages();
    } catch (error) {
      $("deployment-error").hidden = false;
      status("deployment-error", `${error.message} Reload the page to retry.`, true);
      $("map-status").textContent = "UNAVAILABLE";
    } finally {
      refreshing = false;
      $("refresh-button").disabled = false;
    }
  }

  function savePending() {
    try {
      if (pending) sessionStorage.setItem("cloud-guestbook-pending", JSON.stringify(pending));
      else sessionStorage.removeItem("cloud-guestbook-pending");
    } catch (_) { /* Retry identity remains in this page when storage is unavailable. */ }
  }

  $("guestbook-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    if (sending || !deployment) return;
    const text = $("message-text").value.trim();
    if (Array.from(text).length < 1 || Array.from(text).length > 500) {
      status("form-status", "Enter a message between 1 and 500 characters.", true);
      return;
    }
    if (!pending || pending.text !== text) {
      if (!globalThis.crypto || !crypto.getRandomValues) {
        status("form-status", "Secure random generation is unavailable in this browser.", true);
        return;
      }
      // getRandomValues also works on plain HTTP demo Services; randomUUID requires HTTPS.
      const bytes = crypto.getRandomValues(new Uint8Array(16));
      bytes[6] = (bytes[6] & 0x0f) | 0x40;
      bytes[8] = (bytes[8] & 0x3f) | 0x80;
      const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
      const id = `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
      pending = { id, text };
      savePending();
    }
    sending = true;
    $("message-text").disabled = true;
    $("send-label").textContent = "Sending…";
    status("form-status", "Saving message…");
    updateCount();
    try {
      const data = await request("/api/messages", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(pending) });
      if (!data.message || data.message.id !== pending.id) throw new Error("The server did not confirm this message. Retry to confirm its result.");
      pending = null;
      savePending();
      $("message-text").value = "";
      status("form-status", "Message saved.");
      await loadMessages();
    } catch (error) {
      const guidance = error.status === 409 ? "Refresh the feed to check whether it was already saved. Edit the text before sending a new message." : "Your text and retry identity are kept. Send the same text again to retry safely.";
      status("form-status", `${error.message} ${guidance}`, true);
    } finally {
      sending = false;
      $("message-text").disabled = false;
      $("send-label").textContent = "Save message";
      updateCount();
    }
  });

  $("message-text").addEventListener("input", updateCount);
  $("refresh-button").addEventListener("click", refresh);
  updateCount();
  refresh();
})();
