import {
  CanActivate,
  ExecutionContext,
  Injectable,
  SetMetadata,
  BadRequestException,
} from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { StaffRequest } from "../auth/auth.guard";
import { RbacService } from "./rbac.service";
export const RequirePermission = (permission: string, unitParameter?: string) =>
  SetMetadata("permission", { permission, unitParameter });
@Injectable()
export class PermissionGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly rbac: RbacService,
  ) {}
  async canActivate(context: ExecutionContext) {
    const rule = this.reflector.getAllAndOverride<{
      permission: string;
      unitParameter?: string;
    }>("permission", [context.getHandler(), context.getClass()]);
    if (!rule) return true;
    const request = context.switchToHttp().getRequest<StaffRequest>();
    const unit = rule.unitParameter
      ? request.params[rule.unitParameter]
      : undefined;
    if (
      unit !== undefined &&
      (typeof unit !== "string" ||
        !/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(unit))
    )
      throw new BadRequestException("Invalid unit ID");
    await this.rbac.check(request.identity, rule.permission, unit);
    return true;
  }
}
