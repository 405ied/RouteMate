# Phase 3 API

Base path: `/api/v1`. Protected endpoints require `Authorization: Bearer <access token>`. No endpoint accepts an organization selector to override the authenticated tenant.

| Method and path | Access | Result |
|---|---|---|
| GET /health | Public | Liveness |
| GET /health/ready | Public | Readiness using restricted DB identity |
| POST /auth/login | Public, throttled | Organization code + email + password → access/refresh token pair |
| POST /auth/refresh | Public, throttled | refreshToken → rotated pair |
| POST /auth/logout | Authenticated | Revoke current session |
| GET /auth/me | Authenticated | Authenticated IDs, no credential data |
| GET /users | user.view, ORGANIZATION scope | Up to 100 staff summaries; no password hashes or security counters |
| GET /roles | role.view, ORGANIZATION scope | Tenant roles and granular permission strings |
| GET /roles/permissions | role.view, ORGANIZATION scope | Permission catalogue |
| GET /organizations/current | organization.view, ORGANIZATION scope | Current organization summary |
| GET /organization-units | organization_unit.view | Up to 100 units filtered by authorized organization/unit scope; empty if no grants |
| GET /organization-units/:id | organization_unit.view | One unit within authorized scope |
| POST /organization-units | organization_unit.create, ORGANIZATION scope | Create a unit within the current tenant |

Login body fields: `organizationCode`, `email`, `password`. Refresh body: `refreshToken`. Unit create body: `code`, `name`, `unitType`, optional `parentUnitId`; unknown properties, including organizationId, are rejected. Valid unit types follow the existing database enum. Parent units must belong to the same tenant. This foundation does not expose hierarchy reparenting.

Errors have the shape `{ "error": { "status": 403, "message": "Permission or resource scope denied", "requestId": "…" } }`. Invalid DTOs return 400, invalid/unavailable identities 401, insufficient permissions 403, invisible/missing resources 404, and record conflicts 409. Internal database details are suppressed. All responses include a generated X-Request-Id and no-store caching policy.

There are no user/grant mutation endpoints, platform administration endpoints, driver/vehicle/route/QR/passenger endpoints or public PII projections in this phase. Their implementation must preserve the [authentication and RLS contract](../architecture/phase3-backend.md).
