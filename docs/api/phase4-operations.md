# Phase 4 operational API

This implements the backend milestone: organization/unit → park → route → driver → vehicle → primary-driver/route assignments → QR SVG → public registration verification. It builds on Phase 3 staff authentication and uses the existing Prisma database package and PostGIS types. No UI, public website or mobile scanner is deployed by this phase.

## Endpoint sequence

All paths start with `/api/v1`. Staff requests use an access-token Authorization header. The authenticated session determines the organization; body/query tenant overrides are never accepted. List responses are bounded to 100 records and filtered by park scope.

| Method/path | Permission | Purpose |
|---|---|---|
| GET /parks | park.view | Visible parks |
| POST /parks | park.create (organization or parent-unit scope) | Create park under an active unit |
| GET /routes | route.view | Routes linked to visible parks |
| POST /routes | route.create | Create a route and its OPERATING park link |
| GET /drivers | driver.view | Staff driver summaries, no phone/identity/document fields |
| POST /drivers | driver.create | Register a driver, initially PENDING |
| POST /drivers/:id/activate | driver.approve | Activate registration; does not change compliance |
| POST /drivers/:id/suspend | driver.suspend | Suspend registration |
| GET /vehicles | vehicle.view | Visible vehicle summaries |
| POST /vehicles | vehicle.create | Register a vehicle, initially PENDING |
| POST /vehicles/:id/activate | vehicle.approve | Activate registration; does not change compliance |
| POST /vehicles/:id/suspend | vehicle.suspend | Suspend registration |
| GET /vehicles/:id/assignments | assignment.view | Driver/route assignment history |
| POST /vehicles/:id/driver-assignments | assignment.manage | Assign an active PRIMARY driver |
| POST /vehicles/:id/route-assignments | assignment.manage | Assign a route operating from the vehicle's park |
| POST /vehicles/:id/driver-assignments/:assignmentId/end | assignment.manage | End primary assignment without deleting history |
| POST /vehicles/:id/route-assignments/:assignmentId/end | assignment.manage | End route assignment without deleting history |
| POST /vehicles/:id/qr | qr.issue | Issue/rotate QR; returns token and SVG once |
| POST /vehicles/:id/qr/revoke | qr.revoke | Revoke active QR |
| POST /public/verify | Public, rate limited | Verify the scanned token through a narrow database function |

New permissions are granted to existing tenant `ORGANIZATION_ADMIN` role templates by the new migration and included by future development seeds. No extra grants are automatically assigned to other roles. Their scope can be configured by the existing privileged grant-management path; normal runtime cannot modify role grants. A PARK grant permits only that park; UNIT grants cover parks in the unit and descendants; ORGANIZATION grants cover the tenant. Both vehicle and driver parks must be authorized when assigning a driver. Park-scoped staff cannot create arbitrary parks or operate in another tenant.

## Request bodies

```json
{
  "organizationUnitId": "<unit UUID>",
  "name": "Central Park",
  "parkType": "MOTOR_PARK",
  "capacity": 100,
  "location": { "longitude": 3.4, "latitude": 6.5 }
}
```

Park type, capacity and location are optional. Longitude/latitude are finite numbers validated to WGS84 bounds; capacity must be positive. Route creation accepts optional 2–1000 validated points. Geometry is written using parameterized SQL as geometry(LineString,4326); endpoint locations are geography(Point,4326), and distance uses the geography length in meters divided by 1000.

```json
{
  "parkId": "<park UUID>",
  "name": "Central to Market",
  "originName": "Central",
  "destinationName": "Market",
  "points": [
    { "longitude": 3.4, "latitude": 6.5 },
    { "longitude": 3.5, "latitude": 6.6 }
  ]
}
```

```json
{
  "parkId": "<park UUID>",
  "firstName": "<driver first name>",
  "lastName": "<driver last name>",
  "phone": "<7–15 digits with optional leading +>"
}
```

```json
{
  "parkId": "<park UUID>",
  "plateNumber": "ABC-123",
  "vehicleType": "BUS",
  "passengerCapacity": 20,
  "make": "<optional make>",
  "model": "<optional model>",
  "colour": "<optional colour>"
}
```

Use the existing VehicleType enum. Plates are normalized to uppercase without spaces/hyphens and must contain at least three letters/digits. Codes are cryptographically random, never MAX+1. Registration activation and suspension take no body; blacklisted/deceased drivers and blacklisted/retired vehicles cannot be reactivated through this shortcut. Driver disciplinary suspension/bans also block activation/assignment.

Driver assignment body: `{ "driverId": "<driver UUID>" }`. Route assignment body: `{ "routeId": "<route UUID>" }`. Both require an active registered vehicle; primary driver assignment requires an active registered driver. End the existing primary assignment first; duplicate active primary assignments return 409. Route assignments preserve the schema's support for multiple authorized routes; exact duplicate active vehicle/route/park assignments are rejected. These routes are authorizations, not evidence of the passenger's current journey.

QR issuance body: `{ "expiresInDays": 30 }`, with 1–365 days allowed and a default of 30. Current active driver and route assignments are required. The response includes `{ id, expiresAt, token, svg }`. Save/print the returned SVG through the trusted staff client; do not log the token or SVG. The SVG encodes a 256-bit random base64url token, not a URL. A scanner client submits the decoded token to the verification endpoint. There is no browser landing page yet. Reissuing is rotation: old active codes become REPLACED before the new one is inserted. Only the SHA-256 token hash is stored in PostgreSQL.

## Public response and privacy

Send `{ "token": "<scanned token>" }` to POST `/api/v1/public/verify`; no staff login is required. POST keeps token values out of request URLs and route logs. Invalid token syntax returns 400. Unknown, revoked, expired, inactive or no-longer-assigned records return the same `{ "status": "UNAVAILABLE" }` without disclosing vehicle data or the internal reason.

An eligible response contains exactly: `status`, `verificationScope`, `organization`, `vehicle`, `driver`, and `routes`. `status` is REGISTERED and `verificationScope` is REGISTRATION_AND_ASSIGNMENT. Vehicle fields are public code, plate, make/model/colour and compliance status. Driver fields are registration and compliance status only. Routes lists all active authorized routes; when more than one exists, scan records do not invent a selected route assignment.

Registration activation does **not** verify documents, change UNKNOWN compliance to VALID, certify roadworthiness, guarantee passenger safety, or prove who is physically driving. Compliance remains a separately displayed state; the existing document-verification workflow/settings still require later implementation before compliance certification. Public verification never returns driver names, phone/email, address, DOB, national identity references, licenses, documents, photos, passenger data, internal tenant/user IDs or raw token hashes. A future public photo policy must explicitly enforce consent/organization settings.

`routemate_security.verify_vehicle_qr` is SECURITY DEFINER with a fixed trusted search_path and fully qualified SQL. Its owner, `routemate_verification_owner`, is NOLOGIN/NOBYPASSRLS and has only explicit column SELECT grants plus scan INSERT privileges and dedicated RLS policies. It cannot select driver PII columns. PUBLIC execution and role membership are not granted. The API can execute only the narrow function without choosing a tenant. Normal staff RLS policies remain unchanged, and the runtime identity checker rejects verification-owner membership.

Recognized-token attempts insert a scan with the actual tenant and matching FK IDs; unknown tokens do not invent a tenant. No passenger identifier, device/IP fingerprint or location is collected by this endpoint. Operational mutations create append-only audit entries containing action and entity IDs, never submitted PII or tokens. Rate limits remain per-instance; deploy shared throttling before horizontal scaling.

## Migration, checks and deployment

New migration: `20260911100000_phase4_operations`. It adds permissions/grants, an active route-assignment partial unique index with NULLS NOT DISTINCT, and the public verification function/owner/policies. No Prisma model change or regeneration is necessary; native spatial features and all prior migrations are preserved. Duplicate existing active route assignments stop migration atomically; records are not silently deleted.

```powershell
cd C:\RouteMate\apps\api
npm ci
npm run build
npm run lint
npm run format:check
npm test
npm run test:integration
cd C:\RouteMate\packages\database
npx --no-install prisma migrate deploy
npx --no-install prisma migrate status
```

Restart the API after migration. Integration tests replay all four migrations in an isolated temporary database, create synthetic records, exercise the full operational sequence through HTTP, and remove their own resources. Coverage includes coordinate validation/PostGIS route distance, pending/active transitions, permission and park isolation, normalized plate duplicates, assignment uniqueness, concurrent QR rotations, suspension/expiry/end/revocation, public projection privacy and owner privilege checks. No synthetic operational records are added to routemate_db.

Source references: [PostgreSQL SECURITY DEFINER rules](https://www.postgresql.org/docs/18/sql-createfunction.html), [node-qrcode](https://www.npmjs.com/package/qrcode?activeTab=readme).
