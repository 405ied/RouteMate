import http from "node:http";
import { randomBytes } from "node:crypto";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

// Local web gateway: API credentials remain in process memory, never in browser storage.
export function createWebServer({
  apiOrigin = "http://127.0.0.1:3000",
  webOrigin = "http://localhost:3001",
  fetchImpl = fetch,
} = {}) {
  const origin = new URL(webOrigin);
  if (!["localhost", "127.0.0.1", "[::1]"].includes(origin.hostname))
    throw new Error("This development server requires a loopback web origin");
  const upstream = new URL(apiOrigin);
  if (!["localhost", "127.0.0.1", "[::1]"].includes(upstream.hostname))
    throw new Error("A loopback API origin is required");
  const sessions = new Map();
  const cookieName = "routemate_session";
  const cookie = (value) =>
    `${cookieName}=${value}; HttpOnly; SameSite=Strict; Path=/; ${origin.protocol === "https:" ? "Secure; " : ""}Max-Age=${value ? 28800 : 0}`;
  const send = (res, status, data) => {
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(JSON.stringify(data));
  };
  const call = async (path, method, body, token) => {
    const response = await fetchImpl(`${upstream.origin}/api/v1/${path}`, {
      method,
      redirect: "error",
      signal: AbortSignal.timeout(15000),
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      ...(method === "POST" ? { body: JSON.stringify(body) } : {}),
    });
    const data = await response.json();
    return { status: response.status, data };
  };
  const staffPath =
    /^(auth\/me|organizations\/current|organization-units|roles(?:\/permissions)?|users|parks|routes|drivers(?:\/[a-f0-9-]{36}\/(?:activate|suspend))?|vehicles(?:\/[a-f0-9-]{36}\/(?:activate|suspend|assignments|qr(?:\/revoke)?|(?:driver|route)-assignments(?:\/[a-f0-9-]{36}\/end)?))?)$/;
  const publicFiles = new Map([
    ["/", ["index.html", "text/html"]],
    ["/verify", ["index.html", "text/html"]],
    ["/app.js", ["app.js", "text/javascript"]],
    ["/style.css", ["style.css", "text/css"]],
  ]);
  const server = http.createServer(async (req, res) => {
    res.setHeader("Cache-Control", "no-store");
    res.setHeader("X-Content-Type-Options", "nosniff");
    res.setHeader("Referrer-Policy", "no-referrer");
    res.setHeader(
      "Content-Security-Policy",
      "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' blob:; media-src 'self' blob:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'",
    );
    res.setHeader(
      "Permissions-Policy",
      "camera=(self), microphone=(), geolocation=()",
    );
    try {
      if (req.headers.host !== origin.host)
        return send(res, 403, {
          message: `Open RouteMate at ${origin.origin}`,
        });
      const path = new URL(req.url, origin).pathname;
      if (req.method === "GET" && publicFiles.has(path)) {
        const [name, type] = publicFiles.get(path);
        res.setHeader("Content-Type", `${type}; charset=utf-8`);
        return res.end(
          await readFile(new URL(`./public/${name}`, import.meta.url)),
        );
      }
      if (
        !path.startsWith("/gateway/") ||
        !["GET", "POST"].includes(req.method)
      )
        return send(res, 404, { message: "Not found" });
      if (
        req.method === "POST" &&
        (req.headers.origin !== origin.origin ||
          !req.headers["content-type"]?.startsWith("application/json"))
      )
        return send(res, 403, { message: "Request origin rejected" });
      let body = {};
      if (req.method === "POST") {
        let raw = "";
        for await (const chunk of req) {
          raw += chunk;
          if (Buffer.byteLength(raw) > 65536)
            return send(res, 413, { message: "Request too large" });
        }
        try {
          body = JSON.parse(raw);
        } catch {
          return send(res, 400, { message: "Invalid request" });
        }
      }
      const route = path.slice("/gateway/".length);
      const id = req.headers.cookie
        ?.split(";")
        .map((v) => v.trim())
        .find((v) => v.startsWith(`${cookieName}=`))
        ?.slice(cookieName.length + 1);
      const session = sessions.get(id);
      for (const [key, value] of sessions)
        if (value.deadline <= Date.now()) sessions.delete(key);
      if (route === "public/verify" && req.method === "POST") {
        const result = await call(route, "POST", body);
        return send(res, result.status, result.data);
      }
      if (route === "auth/login" && req.method === "POST") {
        if (session)
          return send(res, 409, {
            message: "Sign out before changing accounts",
          });
        if (sessions.size >= 500)
          return send(res, 503, { message: "Please try again later" });
        const result = await call(route, "POST", body);
        if (result.status !== 200)
          return send(res, result.status, {
            message:
              "Sign-in failed. Check your organization, email and password.",
          });
        const key = randomBytes(32).toString("base64url");
        sessions.set(key, {
          ...result.data,
          deadline: Date.now() + 28800000,
          tail: Promise.resolve(),
        });
        res.setHeader("Set-Cookie", cookie(key));
        return send(res, 200, { signedIn: true });
      }
      if (!session || !sessions.has(id)) {
        res.setHeader("Set-Cookie", cookie(""));
        return send(res, 401, { message: "Please sign in to continue" });
      }
      if (route !== "auth/logout" && !staffPath.test(route))
        return send(res, 404, { message: "Not found" });
      // Serialize each session's requests so concurrent expiry cannot replay a rotated refresh token.
      const run = session.tail.then(async () => {
        if (!sessions.has(id))
          return send(res, 401, { message: "Please sign in to continue" });
        let result = await call(route, req.method, body, session.accessToken);
        if (result.status === 401) {
          const refresh = await call("auth/refresh", "POST", {
            refreshToken: session.refreshToken,
          });
          if (refresh.status === 200) {
            Object.assign(session, refresh.data);
            result = await call(route, req.method, body, session.accessToken);
          }
        }
        if (
          result.status === 401 ||
          (route === "auth/logout" && result.status === 200)
        ) {
          sessions.delete(id);
          res.setHeader("Set-Cookie", cookie(""));
        }
        send(
          res,
          result.status,
          result.status >= 500
            ? { message: "The service could not complete this request" }
            : result.data,
        );
      });
      session.tail = run.catch(() => {});
      await run;
    } catch {
      if (!res.headersSent)
        send(res, 502, {
          message:
            "RouteMate API is unavailable. Check that it is running and retry.",
        });
      else res.end();
    }
  });
  return server;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const webOrigin = process.env.WEB_ORIGIN || "http://localhost:3001";
  const server = createWebServer({
    webOrigin,
    apiOrigin: process.env.API_ORIGIN || "http://127.0.0.1:3000",
  });
  server.listen(Number(new URL(webOrigin).port || 80), "127.0.0.1", () =>
    console.log(`RouteMate web ready at ${webOrigin}`),
  );
}
