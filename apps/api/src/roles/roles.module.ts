import { Controller, Get, Module, Req } from "@nestjs/common";
import { StaffRequest } from "../auth/auth.guard";
import { DatabaseService } from "../database/database.service";
import { RequirePermission } from "../rbac/permission.guard";
import { RbacService } from "../rbac/rbac.service";
@Controller("roles")
class RolesController {
  constructor(
    private readonly db: DatabaseService,
    private readonly rbac: RbacService,
  ) {}
  @Get()
  @RequirePermission("role.view")
  list(@Req() request: StaffRequest) {
    return this.db.run(request.identity, async (tx) => {
      await this.rbac.require(tx, request.identity, "role.view");
      return tx.$queryRaw`SELECT r.id,r.code,r.name,coalesce(array_agg(p.code) FILTER (WHERE p.code IS NOT NULL),'{}') AS permissions
        FROM roles r LEFT JOIN role_permissions rp ON rp.role_id=r.id LEFT JOIN permissions p ON p.id=rp.permission_id
        WHERE r.organization_id=${request.identity.organizationId}::uuid AND r.deleted_at IS NULL GROUP BY r.id ORDER BY r.code LIMIT 100`;
    });
  }
  @Get("permissions")
  @RequirePermission("role.view")
  permissions(@Req() request: StaffRequest) {
    return this.db.run(request.identity, async (tx) => {
      await this.rbac.require(tx, request.identity, "role.view");
      return tx.permission.findMany({
        select: { code: true, name: true },
        orderBy: { code: "asc" },
        take: 200,
      });
    });
  }
}
@Module({ controllers: [RolesController] })
export class RolesModule {}
