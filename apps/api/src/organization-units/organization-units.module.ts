import {
  Body,
  Controller,
  Get,
  Module,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
} from "@nestjs/common";
import { IsEnum, IsOptional, IsString, IsUUID, Length } from "class-validator";
import { OrganizationUnitType } from "../../../../packages/database/generated/routemate-client";
import { StaffRequest } from "../auth/auth.guard";
import { DatabaseService } from "../database/database.service";
import { RbacService } from "../rbac/rbac.service";
import { RequirePermission } from "../rbac/permission.guard";
class CreateUnitDto {
  @IsString() @Length(1, 40) code!: string;
  @IsString() @Length(1, 255) name!: string;
  @IsEnum(OrganizationUnitType) unitType!: OrganizationUnitType;
  @IsOptional() @IsUUID() parentUnitId?: string;
}
const projection = {
  id: true,
  code: true,
  name: true,
  unitType: true,
  parentUnitId: true,
  status: true,
} as const;
@Controller("organization-units")
class OrganizationUnitsController {
  constructor(
    private readonly db: DatabaseService,
    private readonly rbac: RbacService,
  ) {}
  @Get()
  list(@Req() request: StaffRequest) {
    return this.db.run(request.identity, async (tx) => {
      const ids = await this.rbac.allowedUnitIds(
        tx,
        request.identity,
        "organization_unit.view",
      );
      return tx.organizationUnit.findMany({
        where: {
          organizationId: request.identity.organizationId,
          deletedAt: null,
          ...(ids === null ? {} : { id: { in: ids } }),
        },
        select: projection,
        take: 100,
        orderBy: { id: "asc" },
      });
    });
  }
  @Get(":id")
  @RequirePermission("organization_unit.view", "id")
  get(@Req() request: StaffRequest, @Param("id", ParseUUIDPipe) id: string) {
    return this.db.run(request.identity, async (tx) => {
      await this.rbac.require(
        tx,
        request.identity,
        "organization_unit.view",
        id,
      );
      return tx.organizationUnit.findFirstOrThrow({
        where: {
          id,
          organizationId: request.identity.organizationId,
          deletedAt: null,
        },
        select: projection,
      });
    });
  }
  @Post()
  @RequirePermission("organization_unit.create")
  create(@Req() request: StaffRequest, @Body() input: CreateUnitDto) {
    return this.db.run(request.identity, async (tx) => {
      await this.rbac.require(tx, request.identity, "organization_unit.create");
      if (input.parentUnitId)
        await tx.organizationUnit.findFirstOrThrow({
          where: {
            id: input.parentUnitId,
            organizationId: request.identity.organizationId,
            deletedAt: null,
          },
        });
      return tx.organizationUnit.create({
        data: {
          ...input,
          organizationId: request.identity.organizationId,
          createdById: request.identity.userId,
        },
        select: projection,
      });
    });
  }
}
@Module({ controllers: [OrganizationUnitsController] })
export class OrganizationUnitsModule {}
