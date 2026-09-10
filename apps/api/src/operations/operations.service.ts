import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { createHash, randomBytes } from "node:crypto";
import QRCode from "qrcode";
import { DatabaseService, Transaction } from "../database/database.service";
import { Identity } from "../auth/token.service";
import { RbacService } from "../rbac/rbac.service";
import {
  CreateDriverDto,
  CreateParkDto,
  CreateRouteDto,
  CreateVehicleDto,
} from "./operations.dto";
const code = (prefix: string) => `${prefix}_${randomBytes(13).toString("hex")}`;
const vehicleSelect = {
  id: true,
  vehicleCode: true,
  plateNumber: true,
  vehicleType: true,
  passengerCapacity: true,
  make: true,
  model: true,
  colour: true,
  registrationStatus: true,
  complianceStatus: true,
  primaryParkId: true,
} as const;
const driverSelect = {
  id: true,
  driverCode: true,
  firstName: true,
  lastName: true,
  registrationStatus: true,
  complianceStatus: true,
  disciplinaryStatus: true,
  primaryParkId: true,
} as const;
const parkSelect = {
  id: true,
  parkCode: true,
  name: true,
  parkType: true,
  status: true,
  organizationUnitId: true,
} as const;
@Injectable()
export class OperationsService {
  constructor(
    private readonly db: DatabaseService,
    private readonly rbac: RbacService,
  ) {}
  private async audit(
    tx: Transaction,
    who: Identity,
    action: string,
    entityType: string,
    entityId: string,
  ) {
    await tx.auditLog.create({
      data: {
        organizationId: who.organizationId,
        actorUserId: who.userId,
        action,
        entityType,
        entityId,
      },
    });
  }
  private async park(
    tx: Transaction,
    who: Identity,
    id: string,
    permission: string,
  ) {
    const park = await tx.park.findFirst({
      where: {
        id,
        organizationId: who.organizationId,
        deletedAt: null,
        status: "ACTIVE",
      },
      select: parkSelect,
    });
    if (!park) throw new NotFoundException("Park not found");
    await this.rbac.requirePark(tx, who, permission, id);
    return park;
  }
  private async vehicle(
    tx: Transaction,
    who: Identity,
    id: string,
    permission: string,
    lock = false,
  ) {
    if (lock)
      await tx.$queryRaw`SELECT id FROM vehicles WHERE id=${id}::uuid AND organization_id=${who.organizationId}::uuid FOR UPDATE`;
    const vehicle = await tx.vehicle.findFirst({
      where: { id, organizationId: who.organizationId, deletedAt: null },
      select: vehicleSelect,
    });
    if (!vehicle?.primaryParkId)
      throw new NotFoundException("Vehicle not found");
    await this.park(tx, who, vehicle.primaryParkId, permission);
    return vehicle;
  }
  parks(who: Identity) {
    return this.db.run(who, async (tx) => {
      const ids = await this.rbac.allowedParkIds(tx, who, "park.view");
      return tx.park.findMany({
        where: {
          organizationId: who.organizationId,
          deletedAt: null,
          ...(ids === null ? {} : { id: { in: ids } }),
        },
        select: parkSelect,
        take: 100,
        orderBy: { id: "asc" },
      });
    });
  }
  createPark(who: Identity, input: CreateParkDto) {
    return this.db.run(who, async (tx) => {
      await this.rbac.require(tx, who, "park.create", input.organizationUnitId);
      await tx.organizationUnit.findFirstOrThrow({
        where: {
          id: input.organizationUnitId,
          organizationId: who.organizationId,
          deletedAt: null,
          status: "ACTIVE",
        },
      });
      const { location, ...data } = input;
      const park = await tx.park.create({
        data: {
          ...data,
          organizationId: who.organizationId,
          parkCode: code("P"),
          createdById: who.userId,
        },
        select: parkSelect,
      });
      if (location)
        await tx.$executeRaw`UPDATE parks SET location=ST_SetSRID(ST_MakePoint(${location.longitude},${location.latitude}),4326)::geography WHERE id=${park.id}::uuid`;
      await this.audit(tx, who, "PARK_CREATED", "Park", park.id);
      return park;
    });
  }
  routes(who: Identity) {
    return this.db.run(who, async (tx) => {
      const parks = await this.rbac.allowedParkIds(tx, who, "route.view");
      const links =
        parks === null
          ? null
          : await tx.parkRoute.findMany({
              where: {
                organizationId: who.organizationId,
                parkId: { in: parks },
                status: "ACTIVE",
                deletedAt: null,
              },
              select: { routeId: true },
            });
      return tx.route.findMany({
        where: {
          organizationId: who.organizationId,
          deletedAt: null,
          ...(links === null
            ? {}
            : { id: { in: links.map((l) => l.routeId) } }),
        },
        select: {
          id: true,
          routeCode: true,
          name: true,
          originName: true,
          destinationName: true,
          status: true,
          distanceKm: true,
        },
        take: 100,
        orderBy: { id: "asc" },
      });
    });
  }
  createRoute(who: Identity, input: CreateRouteDto) {
    return this.db.run(who, async (tx) => {
      await this.park(tx, who, input.parkId, "route.create");
      const { parkId, points, ...data } = input;
      const route = await tx.route.create({
        data: {
          ...data,
          organizationId: who.organizationId,
          routeCode: code("R"),
          createdById: who.userId,
        },
        select: {
          id: true,
          routeCode: true,
          name: true,
          originName: true,
          destinationName: true,
        },
      });
      await tx.parkRoute.create({
        data: {
          organizationId: who.organizationId,
          parkId,
          routeId: route.id,
          routeRole: "OPERATING",
          createdById: who.userId,
        },
      });
      if (points) {
        const geojson = JSON.stringify({
          type: "LineString",
          coordinates: points.map((p) => [p.longitude, p.latitude]),
        });
        await tx.$executeRaw`UPDATE routes SET route_geometry=ST_GeomFromGeoJSON(${geojson})::geometry(LineString,4326),
        origin_location=ST_StartPoint(ST_GeomFromGeoJSON(${geojson}))::geography,
        destination_location=ST_EndPoint(ST_GeomFromGeoJSON(${geojson}))::geography,
        distance_km=ST_Length(ST_GeomFromGeoJSON(${geojson})::geography)/1000 WHERE id=${route.id}::uuid`;
      }
      await this.audit(tx, who, "ROUTE_CREATED", "Route", route.id);
      return route;
    });
  }
  drivers(who: Identity) {
    return this.db.run(who, async (tx) => {
      const parks = await this.rbac.allowedParkIds(tx, who, "driver.view");
      return tx.driver.findMany({
        where: {
          organizationId: who.organizationId,
          deletedAt: null,
          ...(parks === null ? {} : { primaryParkId: { in: parks } }),
        },
        select: driverSelect,
        take: 100,
        orderBy: { id: "asc" },
      });
    });
  }
  createDriver(who: Identity, input: CreateDriverDto) {
    return this.db.run(who, async (tx) => {
      const park = await this.park(tx, who, input.parkId, "driver.create");
      const { parkId, ...data } = input;
      const driver = await tx.driver.create({
        data: {
          ...data,
          organizationId: who.organizationId,
          primaryParkId: parkId,
          organizationUnitId: park.organizationUnitId,
          driverCode: code("D"),
          createdById: who.userId,
        },
        select: driverSelect,
      });
      await this.audit(tx, who, "DRIVER_CREATED", "Driver", driver.id);
      return driver;
    });
  }
  driverStatus(who: Identity, id: string, active: boolean) {
    return this.db.run(who, async (tx) => {
      const driver = await tx.driver.findFirst({
        where: { id, organizationId: who.organizationId, deletedAt: null },
        select: driverSelect,
      });
      if (!driver?.primaryParkId)
        throw new NotFoundException("Driver not found");
      await this.park(
        tx,
        who,
        driver.primaryParkId,
        active ? "driver.approve" : "driver.suspend",
      );
      if (
        active &&
        (["SUSPENDED", "BANNED"].includes(driver.disciplinaryStatus) ||
          ["BLACKLISTED", "DECEASED"].includes(driver.registrationStatus))
      )
        throw new ConflictException(
          "Resolve restricted driver status through administration first",
        );
      const result = await tx.driver.update({
        where: { id },
        data: {
          registrationStatus: active ? "ACTIVE" : "SUSPENDED",
          updatedById: who.userId,
        },
        select: driverSelect,
      });
      await this.audit(
        tx,
        who,
        active ? "DRIVER_ACTIVATED" : "DRIVER_SUSPENDED",
        "Driver",
        id,
      );
      return result;
    });
  }
  vehicles(who: Identity) {
    return this.db.run(who, async (tx) => {
      const parks = await this.rbac.allowedParkIds(tx, who, "vehicle.view");
      return tx.vehicle.findMany({
        where: {
          organizationId: who.organizationId,
          deletedAt: null,
          ...(parks === null ? {} : { primaryParkId: { in: parks } }),
        },
        select: vehicleSelect,
        take: 100,
        orderBy: { id: "asc" },
      });
    });
  }
  createVehicle(who: Identity, input: CreateVehicleDto) {
    return this.db.run(who, async (tx) => {
      await this.park(tx, who, input.parkId, "vehicle.create");
      const { parkId, ...data } = input;
      const plateNumber = data.plateNumber.replace(/[ -]/g, "").toUpperCase();
      if (plateNumber.length < 3)
        throw new BadRequestException(
          "Plate number needs at least three letters or digits",
        );
      const vehicle = await tx.vehicle.create({
        data: {
          ...data,
          plateNumber,
          organizationId: who.organizationId,
          primaryParkId: parkId,
          vehicleCode: code("V"),
          createdById: who.userId,
        },
        select: vehicleSelect,
      });
      await this.audit(tx, who, "VEHICLE_CREATED", "Vehicle", vehicle.id);
      return vehicle;
    });
  }
  vehicleStatus(who: Identity, id: string, active: boolean) {
    return this.db.run(who, async (tx) => {
      const existing = await this.vehicle(
        tx,
        who,
        id,
        active ? "vehicle.approve" : "vehicle.suspend",
        true,
      );
      if (
        active &&
        ["BLACKLISTED", "RETIRED"].includes(existing.registrationStatus)
      )
        throw new ConflictException(
          "Resolve restricted vehicle status through administration first",
        );
      const vehicle = await tx.vehicle.update({
        where: { id },
        data: {
          registrationStatus: active ? "ACTIVE" : "SUSPENDED",
          updatedById: who.userId,
        },
        select: vehicleSelect,
      });
      await this.audit(
        tx,
        who,
        active ? "VEHICLE_ACTIVATED" : "VEHICLE_SUSPENDED",
        "Vehicle",
        id,
      );
      return vehicle;
    });
  }
  assignDriver(who: Identity, vehicleId: string, driverId: string) {
    return this.db.run(who, async (tx) => {
      const vehicle = await this.vehicle(
        tx,
        who,
        vehicleId,
        "assignment.manage",
        true,
      );
      const driver = await tx.driver.findFirst({
        where: {
          id: driverId,
          organizationId: who.organizationId,
          deletedAt: null,
        },
        select: driverSelect,
      });
      if (!driver?.primaryParkId)
        throw new NotFoundException("Driver not found");
      await this.park(tx, who, driver.primaryParkId, "assignment.manage");
      if (
        vehicle.registrationStatus !== "ACTIVE" ||
        driver.registrationStatus !== "ACTIVE" ||
        ["SUSPENDED", "BANNED"].includes(driver.disciplinaryStatus)
      )
        throw new ConflictException(
          "Active registered driver and vehicle required",
        );
      if (
        await tx.driverVehicleAssignment.findFirst({
          where: {
            organizationId: who.organizationId,
            vehicleId,
            status: "ACTIVE",
            assignmentType: "PRIMARY",
          },
        })
      )
        throw new ConflictException("End the current primary assignment first");
      const row = await tx.driverVehicleAssignment.create({
        data: {
          organizationId: who.organizationId,
          vehicleId,
          driverId,
          assignedById: who.userId,
        },
      });
      await this.audit(
        tx,
        who,
        "DRIVER_ASSIGNED",
        "DriverVehicleAssignment",
        row.id,
      );
      return row;
    });
  }
  assignRoute(who: Identity, vehicleId: string, routeId: string) {
    return this.db.run(who, async (tx) => {
      const vehicle = await this.vehicle(
        tx,
        who,
        vehicleId,
        "assignment.manage",
        true,
      );
      if (vehicle.registrationStatus !== "ACTIVE")
        throw new ConflictException("Active vehicle required");
      await tx.route.findFirstOrThrow({
        where: {
          id: routeId,
          organizationId: who.organizationId,
          status: "ACTIVE",
          deletedAt: null,
        },
      });
      const link = await tx.parkRoute.findFirst({
        where: {
          organizationId: who.organizationId,
          routeId,
          parkId: vehicle.primaryParkId!,
          status: "ACTIVE",
          deletedAt: null,
        },
      });
      if (!link)
        throw new ConflictException("Route must operate from the vehicle park");
      const row = await tx.vehicleRouteAssignment.create({
        data: {
          organizationId: who.organizationId,
          vehicleId,
          routeId,
          parkId: vehicle.primaryParkId,
          assignedById: who.userId,
        },
      });
      await this.audit(
        tx,
        who,
        "ROUTE_ASSIGNED",
        "VehicleRouteAssignment",
        row.id,
      );
      return row;
    });
  }
  assignments(who: Identity, vehicleId: string) {
    return this.db.run(who, async (tx) => {
      await this.vehicle(tx, who, vehicleId, "assignment.view");
      return {
        drivers: await tx.driverVehicleAssignment.findMany({
          where: { organizationId: who.organizationId, vehicleId },
          take: 100,
          orderBy: { createdAt: "desc" },
        }),
        routes: await tx.vehicleRouteAssignment.findMany({
          where: { organizationId: who.organizationId, vehicleId },
          take: 100,
          orderBy: { createdAt: "desc" },
        }),
      };
    });
  }
  endAssignment(
    who: Identity,
    vehicleId: string,
    id: string,
    kind: "driver" | "route",
  ) {
    return this.db.run(who, async (tx) => {
      await this.vehicle(tx, who, vehicleId, "assignment.manage", true);
      const where = {
        id,
        organizationId: who.organizationId,
        vehicleId,
        status: "ACTIVE" as const,
      };
      const result =
        kind === "driver"
          ? await tx.driverVehicleAssignment.updateMany({
              where,
              data: { status: "ENDED", endAt: new Date() },
            })
          : await tx.vehicleRouteAssignment.updateMany({
              where,
              data: { status: "ENDED", endAt: new Date() },
            });
      if (!result.count)
        throw new NotFoundException("Active assignment not found");
      await this.audit(
        tx,
        who,
        "ASSIGNMENT_ENDED",
        kind === "driver"
          ? "DriverVehicleAssignment"
          : "VehicleRouteAssignment",
        id,
      );
      return { ended: true };
    });
  }
  issueQr(who: Identity, vehicleId: string, days: number) {
    return this.db.run(who, async (tx) => {
      const vehicle = await this.vehicle(tx, who, vehicleId, "qr.issue", true);
      if (vehicle.registrationStatus !== "ACTIVE")
        throw new ConflictException("Active vehicle required");
      const driver = await tx.driverVehicleAssignment.findFirst({
        where: {
          organizationId: who.organizationId,
          vehicleId,
          status: "ACTIVE",
          assignmentType: "PRIMARY",
          startAt: { lte: new Date() },
          OR: [{ endAt: null }, { endAt: { gt: new Date() } }],
        },
      });
      const driverRecord = driver
        ? await tx.driver.findFirst({
            where: {
              id: driver.driverId,
              organizationId: who.organizationId,
              registrationStatus: "ACTIVE",
              deletedAt: null,
              disciplinaryStatus: { notIn: ["SUSPENDED", "BANNED"] },
            },
            select: { id: true },
          })
        : null;
      const routes = await tx.$queryRaw<
        { id: string }[]
      >`SELECT a.id FROM vehicle_route_assignments a
      JOIN routes r ON r.id=a.route_id AND r.organization_id=a.organization_id
      JOIN parks p ON p.id=a.park_id AND p.organization_id=a.organization_id
      WHERE a.organization_id=${who.organizationId}::uuid AND a.vehicle_id=${vehicleId}::uuid AND a.status='ACTIVE'
        AND a.start_at<=now() AND (a.end_at IS NULL OR a.end_at>now()) AND r.status='ACTIVE' AND r.deleted_at IS NULL
        AND p.status='ACTIVE' AND p.deleted_at IS NULL AND EXISTS(SELECT 1 FROM park_routes pr WHERE pr.organization_id=a.organization_id
          AND pr.park_id=a.park_id AND pr.route_id=a.route_id AND pr.status='ACTIVE' AND pr.deleted_at IS NULL) LIMIT 1`;
      if (!driverRecord || !routes.length)
        throw new ConflictException(
          "Current active primary driver and route assignments required",
        );
      const token = randomBytes(32).toString("base64url");
      const svg = await QRCode.toString(token, {
        type: "svg",
        errorCorrectionLevel: "M",
        margin: 4,
      });
      await tx.vehicleQrCode.updateMany({
        where: {
          organizationId: who.organizationId,
          vehicleId,
          status: "ACTIVE",
        },
        data: { status: "REPLACED", revokedAt: new Date() },
      });
      const qr = await tx.vehicleQrCode.create({
        data: {
          organizationId: who.organizationId,
          vehicleId,
          publicTokenHash: createHash("sha256").update(token).digest("hex"),
          expiresAt: new Date(Date.now() + days * 86400000),
          issuedById: who.userId,
        },
        select: { id: true, expiresAt: true },
      });
      await this.audit(tx, who, "QR_ISSUED", "VehicleQrCode", qr.id);
      return { ...qr, token, svg };
    });
  }
  revokeQr(who: Identity, vehicleId: string) {
    return this.db.run(who, async (tx) => {
      await this.vehicle(tx, who, vehicleId, "qr.revoke", true);
      await tx.vehicleQrCode.updateMany({
        where: {
          organizationId: who.organizationId,
          vehicleId,
          status: "ACTIVE",
        },
        data: { status: "REVOKED", revokedAt: new Date() },
      });
      await this.audit(tx, who, "QR_REVOKED", "Vehicle", vehicleId);
      return { revoked: true };
    });
  }
  verify(token: string) {
    return this.db.run({}, async (tx) => {
      const hash = createHash("sha256").update(token).digest("hex");
      const [row] = await tx.$queryRaw<
        { result: unknown }[]
      >`SELECT routemate_security.verify_vehicle_qr(${hash}) AS result`;
      return row.result;
    });
  }
}
