import { ForbiddenException, Injectable } from "@nestjs/common";
import { Transaction, DatabaseService } from "../database/database.service";
import { Identity } from "../auth/token.service";
type Grant = {
  scope: "ORGANIZATION" | "UNIT" | "PARK";
  organization_unit_id: string | null;
  park_id: string | null;
};
@Injectable()
export class RbacService {
  constructor(private readonly db: DatabaseService) {}
  grants(tx: Transaction, identity: Identity, permission: string) {
    return tx.$queryRaw<Grant[]>`
      SELECT DISTINCT ur.scope,ur.organization_unit_id,ur.park_id
      FROM user_roles ur JOIN roles r ON r.id=ur.role_id AND r.organization_id=ur.organization_id
      JOIN role_permissions rp ON rp.role_id=r.id JOIN permissions p ON p.id=rp.permission_id
      WHERE ur.user_id=${identity.userId}::uuid AND ur.organization_id=${identity.organizationId}::uuid
        AND p.code=${permission} AND r.status='ACTIVE' AND r.deleted_at IS NULL
        AND ur.revoked_at IS NULL AND ur.valid_from<=now() AND (ur.valid_until IS NULL OR ur.valid_until>now())
        AND ((ur.scope='ORGANIZATION' AND ur.organization_unit_id IS NULL AND ur.park_id IS NULL)
          OR (ur.scope='UNIT' AND ur.organization_unit_id IS NOT NULL AND ur.park_id IS NULL)
          OR (ur.scope='PARK' AND ur.park_id IS NOT NULL AND ur.organization_unit_id IS NULL))`;
  }
  async allowedUnitIds(
    tx: Transaction,
    identity: Identity,
    permission: string,
  ): Promise<string[] | null> {
    const grants = await this.grants(tx, identity, permission);
    if (grants.some((g) => g.scope === "ORGANIZATION")) return null;
    const ids: string[] = [];
    for (const grant of grants) {
      if (grant.scope === "UNIT") {
        const descendants = await tx.$queryRaw<{ id: string }[]>`
          WITH RECURSIVE units AS (
            SELECT id FROM organization_units WHERE id=${grant.organization_unit_id}::uuid AND organization_id=${identity.organizationId}::uuid
            UNION SELECT child.id FROM organization_units child JOIN units parent ON child.parent_unit_id=parent.id
              WHERE child.organization_id=${identity.organizationId}::uuid
          ) SELECT id FROM units`;
        ids.push(...descendants.map((row) => row.id));
      }
      // PARK grants do not confer unit-wide management rights. Park resources come later.
    }
    return [...new Set(ids)];
  }
  async require(
    tx: Transaction,
    identity: Identity,
    permission: string,
    unitId?: string,
  ) {
    const grants = await this.grants(tx, identity, permission);
    if (grants.some((g) => g.scope === "ORGANIZATION")) return;
    if (
      unitId &&
      (await this.allowedUnitIds(tx, identity, permission))?.includes(unitId)
    )
      return;
    throw new ForbiddenException("Permission or resource scope denied");
  }
  check(identity: Identity, permission: string, unitId?: string) {
    return this.db.run(identity, (tx) =>
      this.require(tx, identity, permission, unitId),
    );
  }
}
