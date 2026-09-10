import { test } from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import { createWebServer } from "../server.mjs";

// Native HTTP allows explicit Host headers, unlike Node fetch's browser-compatible handling.
function fetchLocal(url, options = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request(url, options, (res) => {
      let raw = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => (raw += chunk));
      res.on("end", () =>
        resolve({
          status: res.statusCode,
          headers: {
            get: (key) =>
              Array.isArray(res.headers[key])
                ? res.headers[key].join(", ")
                : res.headers[key],
          },
          json: async () => JSON.parse(raw),
          text: async () => raw,
        }),
      );
    });
    req.on("error", reject);
    req.end(options.body);
  });
}

test("gateway keeps tokens server-side, rotates once, enforces origin and revokes sessions", async (t) => {
  let refreshed = 0;
  let loggedOut = false;
  const reply = (status, data) => ({ status, json: async () => data });
  const server = createWebServer({
    webOrigin: "http://localhost:3001",
    fetchImpl: async (url, options) => {
      const path = new URL(url).pathname;
      if (path.endsWith("/auth/login"))
        return reply(200, {
          accessToken: "old-secret-access",
          refreshToken: "secret-refresh",
          expiresIn: 1,
        });
      if (path.endsWith("/auth/refresh")) {
        refreshed++;
        assert.equal(JSON.parse(options.body).refreshToken, "secret-refresh");
        return reply(200, {
          accessToken: "new-secret-access",
          refreshToken: "new-refresh",
        });
      }
      if (path.endsWith("/public/verify")) {
        assert.equal(options.headers.Authorization, undefined);
        return reply(200, { status: "UNAVAILABLE" });
      }
      if (path.endsWith("/auth/logout")) {
        loggedOut = true;
        return reply(200, { revoked: true });
      }
      if (options.headers.Authorization === "Bearer old-secret-access")
        return reply(401, { message: "Expired" });
      assert.equal(options.headers.Authorization, "Bearer new-secret-access");
      return reply(200, [{ name: "Tenant-scoped result" }]);
    },
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;
  const request = (
    path,
    { body, cookie, origin = "http://localhost:3001" } = {},
  ) =>
    fetchLocal(`${base}${path}`, {
      method: body === undefined ? "GET" : "POST",
      headers: {
        Host: "localhost:3001",
        Origin: origin,
        "Content-Type": "application/json",
        ...(cookie ? { Cookie: cookie } : {}),
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
  assert.equal((await request("/gateway/vehicles")).status, 401);
  assert.equal(
    (
      await request("/gateway/auth/login", {
        body: {},
        origin: "https://evil.example",
      })
    ).status,
    403,
  );
  const login = await request("/gateway/auth/login", {
    body: {
      organizationCode: "TEST",
      email: "test@example.invalid",
      password: "test-only-password",
    },
  });
  assert.deepEqual(await login.json(), { signedIn: true });
  const header = login.headers.get("set-cookie");
  assert.match(header, /HttpOnly/);
  assert.match(header, /SameSite=Strict/);
  assert.doesNotMatch(header, /secret|refresh/);
  const cookie = header.split(";")[0];
  const results = await Promise.all([
    request("/gateway/vehicles", { cookie }),
    request("/gateway/drivers", { cookie }),
  ]);
  assert.deepEqual(
    results.map((r) => r.status),
    [200, 200],
  );
  assert.equal(refreshed, 1);
  assert.equal(
    (await request("/gateway/private-secret", { cookie })).status,
    404,
  );
  assert.equal(
    (
      await request("/gateway/vehicles", {
        body: {},
        cookie,
        origin: "https://evil.example",
      })
    ).status,
    403,
  );
  assert.deepEqual(
    await (
      await request("/gateway/public/verify", {
        body: { token: "x".repeat(43) },
      })
    ).json(),
    { status: "UNAVAILABLE" },
  );
  assert.equal(
    (await request("/gateway/auth/logout", { body: {}, cookie })).status,
    200,
  );
  assert.equal(loggedOut, true);
  assert.equal((await request("/gateway/vehicles", { cookie })).status, 401);
  for (const path of ["/", "/verify", "/app.js", "/style.css"]) {
    const response = await request(path);
    assert.equal(response.status, 200);
    assert.match(
      response.headers.get("content-security-policy"),
      /frame-ancestors 'none'/,
    );
    assert.equal(response.headers.get("cache-control"), "no-store");
  }
  assert.equal(
    (await fetchLocal(base, { headers: { Host: "evil.example" } })).status,
    403,
  );
});

test("upstream exceptions cannot disclose credentials", async (t) => {
  const server = createWebServer({
    fetchImpl: async () => {
      throw new Error("password=must-never-be-displayed");
    },
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const response = await fetchLocal(
    `http://127.0.0.1:${server.address().port}/gateway/auth/login`,
    {
      method: "POST",
      headers: {
        Host: "localhost:3001",
        Origin: "http://localhost:3001",
        "Content-Type": "application/json",
      },
      body: "{}",
    },
  );
  assert.equal(response.status, 502);
  assert.doesNotMatch(await response.text(), /password|must-never/);
});
