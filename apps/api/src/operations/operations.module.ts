import {
  Body,
  Controller,
  Get,
  HttpCode,
  Module,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
} from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { StaffRequest, Public } from "../auth/auth.guard";
import { OperationsService } from "./operations.service";
import {
  CreateParkDto,
  CreateRouteDto,
  CreateDriverDto,
  CreateVehicleDto,
  DriverAssignmentDto,
  RouteAssignmentDto,
  IssueQrDto,
  VerifyQrDto,
} from "./operations.dto";
@Controller("parks")
class ParksController {
  constructor(private readonly operations: OperationsService) {}
  @Get() list(@Req() r: StaffRequest) {
    return this.operations.parks(r.identity);
  }
  @Post() create(@Req() r: StaffRequest, @Body() body: CreateParkDto) {
    return this.operations.createPark(r.identity, body);
  }
}
@Controller("routes")
class RoutesController {
  constructor(private readonly operations: OperationsService) {}
  @Get() list(@Req() r: StaffRequest) {
    return this.operations.routes(r.identity);
  }
  @Post() create(@Req() r: StaffRequest, @Body() body: CreateRouteDto) {
    return this.operations.createRoute(r.identity, body);
  }
}
@Controller("drivers")
class DriversController {
  constructor(private readonly operations: OperationsService) {}
  @Get() list(@Req() r: StaffRequest) {
    return this.operations.drivers(r.identity);
  }
  @Post() create(@Req() r: StaffRequest, @Body() body: CreateDriverDto) {
    return this.operations.createDriver(r.identity, body);
  }
  @Post(":id/activate") @HttpCode(200) activate(
    @Req() r: StaffRequest,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.operations.driverStatus(r.identity, id, true);
  }
  @Post(":id/suspend") @HttpCode(200) suspend(
    @Req() r: StaffRequest,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.operations.driverStatus(r.identity, id, false);
  }
}
@Controller("vehicles")
class VehiclesController {
  constructor(private readonly operations: OperationsService) {}
  @Get() list(@Req() r: StaffRequest) {
    return this.operations.vehicles(r.identity);
  }
  @Post() create(@Req() r: StaffRequest, @Body() body: CreateVehicleDto) {
    return this.operations.createVehicle(r.identity, body);
  }
  @Post(":id/activate") @HttpCode(200) activate(
    @Req() r: StaffRequest,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.operations.vehicleStatus(r.identity, id, true);
  }
  @Post(":id/suspend") @HttpCode(200) suspend(
    @Req() r: StaffRequest,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.operations.vehicleStatus(r.identity, id, false);
  }
  @Get(":id/assignments") assignments(
    @Req() r: StaffRequest,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.operations.assignments(r.identity, id);
  }
  @Post(":id/driver-assignments") driver(
    @Req() r: StaffRequest,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() body: DriverAssignmentDto,
  ) {
    return this.operations.assignDriver(r.identity, id, body.driverId);
  }
  @Post(":id/route-assignments") route(
    @Req() r: StaffRequest,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() body: RouteAssignmentDto,
  ) {
    return this.operations.assignRoute(r.identity, id, body.routeId);
  }
  @Post(":id/driver-assignments/:assignmentId/end") @HttpCode(200) endDriver(
    @Req() r: StaffRequest,
    @Param("id", ParseUUIDPipe) id: string,
    @Param("assignmentId", ParseUUIDPipe) assignmentId: string,
  ) {
    return this.operations.endAssignment(
      r.identity,
      id,
      assignmentId,
      "driver",
    );
  }
  @Post(":id/route-assignments/:assignmentId/end") @HttpCode(200) endRoute(
    @Req() r: StaffRequest,
    @Param("id", ParseUUIDPipe) id: string,
    @Param("assignmentId", ParseUUIDPipe) assignmentId: string,
  ) {
    return this.operations.endAssignment(r.identity, id, assignmentId, "route");
  }
  @Post(":id/qr") issue(
    @Req() r: StaffRequest,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() body: IssueQrDto,
  ) {
    return this.operations.issueQr(r.identity, id, body.expiresInDays);
  }
  @Post(":id/qr/revoke") @HttpCode(200) revoke(
    @Req() r: StaffRequest,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.operations.revokeQr(r.identity, id);
  }
}
@Controller("public")
class PublicVerificationController {
  constructor(private readonly operations: OperationsService) {}
  @Public()
  @Post("verify")
  @HttpCode(200)
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  verify(@Body() body: VerifyQrDto) {
    return this.operations.verify(body.token);
  }
}
@Module({
  controllers: [
    ParksController,
    RoutesController,
    DriversController,
    VehiclesController,
    PublicVerificationController,
  ],
  providers: [OperationsService],
})
export class OperationsModule {}
