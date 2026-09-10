import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { Client } from "pg";
import request from "supertest";
export async function checkOperations(
  http: ReturnType<typeof request>,
  fixture: Client,
  a: {
    organization: string;
    units: string[];
    park: string;
    roleIds: Record<string, string>;
  },
  accessA: string,
  accessB: string,
  scopedAccess: string,
) {
  const post = (url: string, body: object = {}, token = accessA) =>
    http
      .post(`/api/v1${url}`)
      .set("Authorization", `Bearer ${token}`)
      .send(body);
  const verify = (token: string) =>
    http.post("/api/v1/public/verify").send({ token });
  const park = (
    await post("/parks", {
      organizationUnitId: a.units[2],
      name: "Milestone Park",
      location: { longitude: 3.4, latitude: 6.5 },
    }).expect(201)
  ).body;
  await post("/parks", {
    organizationUnitId: a.units[2],
    name: "Bad coordinate",
    location: { longitude: 190, latitude: 6.5 },
  }).expect(400);
  const route = (
    await post("/routes", {
      parkId: park.id,
      name: "Milestone Route",
      originName: "Origin",
      destinationName: "Destination",
      points: [
        { longitude: 3.4, latitude: 6.5 },
        { longitude: 3.5, latitude: 6.6 },
      ],
    }).expect(201)
  ).body;
  const geometry = (
    await fixture.query(
      "SELECT GeometryType(route_geometry) AS kind,ST_SRID(route_geometry) AS srid,distance_km FROM routes WHERE id=$1",
      [route.id],
    )
  ).rows[0];
  assert.equal(geometry.kind, "LINESTRING");
  assert.equal(geometry.srid, 4326);
  assert.ok(Number(geometry.distance_km) > 0);
  const driver = (
    await post("/drivers", {
      parkId: park.id,
      firstName: "PrivateFirst",
      lastName: "PrivateLast",
      phone: "+2348000000000",
    }).expect(201)
  ).body;
  const vehicle = (
    await post("/vehicles", {
      parkId: park.id,
      plateNumber: "TEST-123",
      vehicleType: "BUS",
      passengerCapacity: 20,
      make: "TestMake",
      colour: "Blue",
    }).expect(201)
  ).body;
  assert.equal(driver.registrationStatus, "PENDING");
  assert.equal(vehicle.registrationStatus, "PENDING");
  assert.equal(vehicle.plateNumber, "TEST123");
  await post("/vehicles", {
    parkId: park.id,
    plateNumber: "test 123",
    vehicleType: "BUS",
    passengerCapacity: 20,
  }).expect(409);
  await post(`/vehicles/${vehicle.id}/qr`, {}).expect(409);
  await post(`/vehicles/${vehicle.id}/driver-assignments`, {
    driverId: driver.id,
  }).expect(409);
  await post(`/drivers/${driver.id}/activate`).expect(200);
  await post(`/vehicles/${vehicle.id}/activate`).expect(200);
  const assignment = (
    await post(`/vehicles/${vehicle.id}/driver-assignments`, {
      driverId: driver.id,
    }).expect(201)
  ).body;
  await post(`/vehicles/${vehicle.id}/driver-assignments`, {
    driverId: driver.id,
  }).expect(409);
  await post(`/vehicles/${vehicle.id}/route-assignments`, {
    routeId: route.id,
  }).expect(201);
  await post(`/vehicles/${vehicle.id}/route-assignments`, {
    routeId: route.id,
  }).expect(409);
  await post(`/vehicles/${vehicle.id}/qr`, {}, accessB).expect(404);
  await post(
    "/drivers",
    {
      parkId: park.id,
      firstName: "Other",
      lastName: "Tenant",
      phone: "+2348000000001",
    },
    accessB,
  ).expect(404);
  for (const resource of ["parks", "routes", "drivers", "vehicles"]) {
    const listed = await http
      .get(`/api/v1/${resource}`)
      .set("Authorization", `Bearer ${accessB}`)
      .expect(200);
    assert.ok(
      !listed.body.some((row: { id: string }) =>
        [park.id, route.id, driver.id, vehicle.id].includes(row.id),
      ),
    );
  }
  await fixture.query(
    `INSERT INTO role_permissions(role_id,permission_id,updated_at) SELECT $1,id,now() FROM permissions WHERE code='driver.create' ON CONFLICT DO NOTHING`,
    [a.roleIds.STATE_ADMIN],
  );
  await post(
    "/drivers",
    {
      parkId: a.park,
      firstName: "Scoped",
      lastName: "Allowed",
      phone: "+2348000000002",
    },
    scopedAccess,
  ).expect(201);
  await post(
    "/drivers",
    {
      parkId: park.id,
      firstName: "Scoped",
      lastName: "Denied",
      phone: "+2348000000002",
    },
    scopedAccess,
  ).expect(403);
  const secondRoute = (
    await post("/routes", {
      parkId: park.id,
      name: "Second authorized route",
      originName: "Central",
      destinationName: "Second destination",
    }).expect(201)
  ).body;
  await post(`/vehicles/${vehicle.id}/route-assignments`, {
    routeId: secondRoute.id,
  }).expect(201);
  const issued = (
    await post(`/vehicles/${vehicle.id}/qr`, { expiresInDays: 1 }).expect(201)
  ).body;
  assert.match(issued.svg, /<svg/);
  assert.equal(issued.token.length, 43);
  assert.ok(!("publicTokenHash" in issued));
  const checked = await verify(issued.token).expect(200);
  assert.equal(checked.body.status, "REGISTERED");
  assert.equal(checked.body.verificationScope, "REGISTRATION_AND_ASSIGNMENT");
  assert.equal(checked.body.routes.length, 2);
  assert.equal(
    (
      await fixture.query(
        "SELECT route_assignment_id FROM verification_scans WHERE qr_code_id=$1 ORDER BY scanned_at DESC LIMIT 1",
        [issued.id],
      )
    ).rows[0].route_assignment_id,
    null,
  );
  assert.equal(checked.body.driver.complianceStatus, "UNKNOWN");
  assert.deepEqual(Object.keys(checked.body).sort(), [
    "driver",
    "organization",
    "routes",
    "status",
    "vehicle",
    "verificationScope",
  ]);
  const publicText = JSON.stringify(checked.body);
  for (const privateValue of [
    "PrivateFirst",
    "PrivateLast",
    "+2348000000000",
    "password",
    "nationalId",
    "driverLicense",
    "organizationId",
    "publicTokenHash",
  ])
    assert.ok(!publicText.includes(privateValue));
  await post(`/drivers/${driver.id}/suspend`).expect(200);
  await post(`/vehicles/${vehicle.id}/qr`, {}).expect(409);
  assert.deepEqual((await verify(issued.token).expect(200)).body, {
    status: "UNAVAILABLE",
  });
  await post(`/drivers/${driver.id}/activate`).expect(200);
  const concurrent = await Promise.all([
    post(`/vehicles/${vehicle.id}/qr`, {}),
    post(`/vehicles/${vehicle.id}/qr`, {}),
  ]);
  concurrent.forEach((r) => assert.equal(r.status, 201));
  assert.equal(
    (
      await fixture.query(
        "SELECT count(*) AS count FROM vehicle_qr_codes WHERE vehicle_id=$1 AND status='ACTIVE'",
        [vehicle.id],
      )
    ).rows[0].count,
    "1",
  );
  assert.deepEqual((await verify(issued.token).expect(200)).body, {
    status: "UNAVAILABLE",
  });
  const statuses = await Promise.all(
    concurrent.map((r) => verify(r.body.token)),
  );
  assert.deepEqual(statuses.map((r) => r.body.status).sort(), [
    "REGISTERED",
    "UNAVAILABLE",
  ]);
  const current =
    concurrent[statuses.findIndex((r) => r.body.status === "REGISTERED")].body;
  await fixture.query(
    "UPDATE vehicle_qr_codes SET expires_at=now()-interval '1 second' WHERE id=$1",
    [current.id],
  );
  assert.deepEqual((await verify(current.token).expect(200)).body, {
    status: "UNAVAILABLE",
  });
  const final = (await post(`/vehicles/${vehicle.id}/qr`, {}).expect(201)).body;
  await post(
    `/vehicles/${vehicle.id}/driver-assignments/${assignment.id}/end`,
  ).expect(200);
  assert.deepEqual((await verify(final.token).expect(200)).body, {
    status: "UNAVAILABLE",
  });
  await post(`/vehicles/${vehicle.id}/qr/revoke`).expect(200);
  assert.deepEqual((await verify(final.token).expect(200)).body, {
    status: "UNAVAILABLE",
  });
  assert.deepEqual(
    (await verify(randomBytes(32).toString("base64url")).expect(200)).body,
    { status: "UNAVAILABLE" },
  );
  await verify("malformed").expect(400);
  assert.ok(
    Number(
      (
        await fixture.query(
          "SELECT count(*) AS count FROM verification_scans WHERE vehicle_id=$1",
          [vehicle.id],
        )
      ).rows[0].count,
    ) > 0,
  );
  assert.ok(
    Number(
      (
        await fixture.query(
          "SELECT count(*) AS count FROM audit_logs WHERE organization_id=$1",
          [a.organization],
        )
      ).rows[0].count,
    ) > 0,
  );
  const privacy = (
    await fixture.query(`SELECT has_column_privilege('routemate_verification_owner','public.drivers','phone','SELECT') AS phone,
    has_column_privilege('routemate_verification_owner','public.drivers','national_id_reference','SELECT') AS national_id,
    pg_has_role('routemate_app','routemate_verification_owner','MEMBER') AS member`)
  ).rows[0];
  assert.deepEqual(privacy, {
    phone: false,
    national_id: false,
    member: false,
  });
}
