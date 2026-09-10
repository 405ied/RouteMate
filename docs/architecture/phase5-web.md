# Phase 5 — Local staff and passenger web interface

The interface lives in `C:\RouteMate\apps\web` and uses the existing NestJS API. No migrations, runtime roles, database credentials or existing records are changed by starting it. No dependency installation or build is required: it uses Node's HTTP server and native browser modules.

## Start and open

Keep the API running on port 3000, then use a separate PowerShell terminal:

```powershell
Set-Location C:\RouteMate\apps\web
npm start
```

- Staff: http://localhost:3001/
- Passenger verification: http://localhost:3001/verify

Sign in with the existing organization code, staff email and password. Bootstrap environment variables are not needed by the web app. Never paste credentials into source files or chat.

Optional process variables: `API_ORIGIN` (default `http://127.0.0.1:3000`) and `WEB_ORIGIN` (default `http://localhost:3001`). The server deliberately binds to loopback and validates the exact web Host and mutation Origin. Use the configured address consistently; switching between `localhost` and `127.0.0.1` is rejected. This phase is local development, not a public deployment. A phone cannot access the laptop's localhost URL.

## Staff workflow

1. Select an existing organization unit or add one.
2. Add a park and its operating routes. Park coordinates and a route's ordered longitude/latitude points are optional.
3. Register a driver and vehicle at the park. New registrations begin pending.
4. Activate approved registrations using their row actions. This does not change compliance status.
5. Open **Vehicles → Manage**, assign an active primary driver and a route operating from that park. End an existing primary assignment before replacing it.
6. Issue a QR with an expiry of 1–365 days. Issuance replaces the previous active QR. Download or print immediately; the original token cannot be retrieved again.
7. Use **Check result** to open public verification, or scan the printed QR from the passenger page. QR revocation and assignment endings require an explicit confirmation in the interface.

Organization units, parks, routes, drivers and vehicles have creation forms. Staff and roles are read-only lists. API permissions remain authoritative for every request; restricted users may see permission errors for unavailable lists or actions. Counts and search cover at most 100 accessible records per list, not organization-wide totals. The interface does not provide pagination beyond this API limit.

## Passenger verification

No staff login is required. The scanner uses the browser's native `BarcodeDetector` QR capability. Camera access starts only after clicking **Open camera**, stops after a scan, on request, or when leaving/hiding the page. If QR detection or camera permission is unavailable, enter the printed 43-character token instead. Camera compatibility has not been tested on physical devices.

The API's QR SVG encodes the raw opaque token. Ordinary camera applications may display that text rather than open a website; use the RouteMate passenger scanner. **Check result** carries the token in a URL fragment, immediately clears it from browser history, and submits it in a POST body. No token is put in a URL query or server request log.

A match shows organization, vehicle, reported vehicle/driver compliance, driver registration and authorized routes. Unknown compliance stays explicitly unknown. It is not a safety or roadworthiness certificate, does not identify a current journey, and displays no driver name, phone, documents or contact details. Known checks retain the backend's existing scan audit behavior.

## Session and gateway controls

- The browser receives a random opaque `HttpOnly; SameSite=Strict` cookie. Access and refresh tokens stay in the web server's memory; none are returned to the frontend or saved in local/session storage.
- Requests use the existing tenant-authenticated API, with a route allowlist. Browser-supplied authorization headers are never forwarded. Tenant identity still comes from the signed API identity and existing PostgreSQL RLS.
- Per-session request serialization prevents concurrent refresh attempts from replaying a rotated refresh token. Failed authentication clears the session. Successful sign-out revokes the upstream API session immediately.
- Sessions expire after eight hours, are process-local, and disappear on web-server restart. The API retains its own session expiry/revocation rules. A production rollout needs HTTPS, secure cookies, a bounded shared session store with refresh coordination, appropriate public rate limits and a deployment review. Do not expose this development server through a tunnel or bind it publicly.
- Exact mutation Origin checking, JSON content-type enforcement, a body-size limit, no-store responses, CSP, clickjacking protection and referrer suppression are enabled. Raw exception messages and credentials are not logged or sent to clients. No third-party scripts, fonts, analytics or services are loaded.

## Verification

```powershell
Set-Location C:\RouteMate\apps\web
npm run check
npm test
```

Gateway HTTP tests cover denied anonymous access, origin rejection, token secrecy, serialized refresh, public verification without credentials, route restriction, logout, response headers, Host rejection and sanitized upstream failures. They use a synthetic upstream, not real staff passwords. Live HTTP checks confirmed both pages load, the existing API is ready, and an unknown QR returns `UNAVAILABLE` through the gateway. The API's earlier isolated PostgreSQL tests cover registration, assignment and QR lifecycle. Browser interaction, print layout and physical camera scanning have not been manually verified.

## Files added in this phase

- `apps/web/package.json` — start and verification commands; no external dependencies.
- `apps/web/server.mjs` — local static server and session gateway.
- `apps/web/public/index.html` — accessible document entrypoint.
- `apps/web/public/app.js` — staff workflows and passenger verification.
- `apps/web/public/style.css` — responsive interface and QR print styles.
- `apps/web/test/gateway.test.mjs` — gateway security and behavior checks.
- `docs/architecture/phase5-web.md` — this setup, workflow and limits document.

Existing Phase 2–4 files and migrations are preserved. No commit or hosted deployment was made.
