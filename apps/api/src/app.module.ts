import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { APP_GUARD } from "@nestjs/core";
import { ThrottlerGuard, ThrottlerModule } from "@nestjs/throttler";
import { validateEnvironment } from "./config/environment";
import { DatabaseModule } from "./database/database.module";
import { AuthModule } from "./auth/auth.module";
import { AuthGuard } from "./auth/auth.guard";
import { RbacModule } from "./rbac/rbac.module";
import { PermissionGuard } from "./rbac/permission.guard";
import { HealthModule } from "./health/health.module";
import { UsersModule } from "./users/users.module";
import { RolesModule } from "./roles/roles.module";
import { OrganizationsModule } from "./organizations/organizations.module";
import { OrganizationUnitsModule } from "./organization-units/organization-units.module";
@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate: validateEnvironment }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }]),
    DatabaseModule,
    AuthModule,
    RbacModule,
    HealthModule,
    UsersModule,
    RolesModule,
    OrganizationsModule,
    OrganizationUnitsModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: AuthGuard },
    { provide: APP_GUARD, useClass: PermissionGuard },
  ],
})
export class AppModule {}
