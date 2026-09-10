import { Controller, Get, Module, Req } from "@nestjs/common";
import { StaffRequest } from "../auth/auth.guard";
import { DatabaseService } from "../database/database.service";
import { RequirePermission } from "../rbac/permission.guard";
import { RbacService } from "../rbac/rbac.service";
@Controller("organizations")
class OrganizationsController {
  constructor(
    private readonly db: DatabaseService,
    private readonly rbac: RbacService,
  ) {}
  @Get("current")
  @RequirePermission("organization.view")
  current(@Req() request: StaffRequest) {
    return this.db.run(request.identity, async (tx) => {
      await this.rbac.require(tx, request.identity, "organization.view");
      return tx.organization.findUnique({
        where: { id: request.identity.organizationId },
        select: { id: true, organizationCode: true, name: true, status: true },
      });
    });
  }
}
@Module({ controllers: [OrganizationsController] })
export class OrganizationsModule {}
