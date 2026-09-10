// Run in the PowerShell session holding the bootstrap credentials. Never prints tokens.
const fs = require("node:fs");
const path = require("node:path");
const dotenv = require("../../../packages/database/node_modules/dotenv");

async function main() {
  const keys = [
    "BOOTSTRAP_ORGANIZATION_CODE",
    "BOOTSTRAP_ADMIN_EMAIL",
    "BOOTSTRAP_ADMIN_PASSWORD",
  ];
  if (keys.some((key) => !process.env[key])) {
    console.error(
      "Run this check in the PowerShell window containing all three bootstrap variables. No credentials logged.",
    );
    process.exitCode = 1;
    return;
  }
  const config = dotenv.parse(fs.readFileSync(path.join(__dirname, "../.env")));
  const port = Number(config.PORT || 3000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("Invalid port");
  }
  const base = `http://127.0.0.1:${port}/api/v1`;
  let accessToken;
  let stage = "login";
  async function call(route, method = "GET", body, token) {
    const response = await fetch(`${base}${route}`, {
      method,
      redirect: "error",
      signal: AbortSignal.timeout(10000),
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  }
  try {
    const pair = await call("/auth/login", "POST", {
      organizationCode: process.env.BOOTSTRAP_ORGANIZATION_CODE,
      email: process.env.BOOTSTRAP_ADMIN_EMAIL,
      password: process.env.BOOTSTRAP_ADMIN_PASSWORD,
    });
    accessToken = pair.accessToken;
    if (typeof accessToken !== "string" || typeof pair.refreshToken !== "string")
      throw new Error("Invalid response");
    console.log("PASS: admin login");
    stage = "authenticated identity";
    const identity = await call("/auth/me", "GET", undefined, accessToken);
    stage = "organization access";
    const organization = await call(
      "/organizations/current",
      "GET",
      undefined,
      accessToken,
    );
    if (organization.id !== identity.organizationId)
      throw new Error("Tenant mismatch");
    console.log("PASS: authenticated organization matches staff identity");
    for (const route of ["/roles", "/users", "/organization-units"]) {
      stage = route;
      await call(route, "GET", undefined, accessToken);
      console.log(`PASS: ${route}`);
    }
    stage = "refresh rotation";
    const rotated = await call("/auth/refresh", "POST", {
      refreshToken: pair.refreshToken,
    });
    if (rotated.refreshToken === pair.refreshToken)
      throw new Error("Refresh did not rotate");
    accessToken = rotated.accessToken;
    await call("/auth/me", "GET", undefined, accessToken);
    console.log("PASS: refresh rotation");
    stage = "logout";
    await call("/auth/logout", "POST", undefined, accessToken);
    stage = "logout revocation";
    const response = await fetch(`${base}/auth/me`, {
      headers: { Authorization: `Bearer ${accessToken}` },
      signal: AbortSignal.timeout(10000),
      redirect: "error",
    });
    if (response.status !== 401) throw new Error("Session not revoked");
    accessToken = undefined;
    console.log("PASS: logout immediately revokes access");
    console.log("Admin API check passed. No passwords or tokens printed.");
  } catch (error) {
    const status = /^HTTP [0-9]{3}$/.test(error.message)
      ? ` (${error.message})`
      : "";
    console.error(`Check failed at ${stage}${status}. No credentials logged.`);
    process.exitCode = 1;
  } finally {
    if (accessToken) {
      try {
        await call("/auth/logout", "POST", undefined, accessToken);
      } catch {
        console.error("Could not confirm cleanup of the test login session.");
      }
    }
  }
}
main().catch(() => {
  console.error("Check could not start; verify the API .env. No credentials logged.");
  process.exitCode = 1;
});
