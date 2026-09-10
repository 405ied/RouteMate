import { Controller, Get, Module, Req } from "@nestjs/common";
import { StaffRequest } from "../auth/auth.guard";
import { DatabaseService } from "../database/database.service";
import { RequirePermission } from "../rbac/permission.guard";
import { RbacService } from "../rbac/rbac.service";
@Controller("users")
class UsersController {
  constructor(
    private readonly db: DatabaseService,
    private readonly rbac: RbacService,
  ) {}
  @Get()
  @RequirePermission("user.view")
  list(@Req() request: StaffRequest) {
    return this.db.run(request.identity, async (tx) => {
      await this.rbac.require(tx, request.identity, "user.view");
      return tx.user.findMany({
        where: {
          organizationId: request.identity.organizationId,
          deletedAt: null,
        },
        select: {
          id: true,
          firstName: true,
          lastName: true,
          email: true,
          status: true,
        },
        take: 100,
        orderBy: { id: "asc" },
      });
    });
  }
}
@Module({ controllers: [UsersController] })
export class UsersModule {}
