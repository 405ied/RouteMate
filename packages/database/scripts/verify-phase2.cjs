// Runs against the configured local database; ALL fixtures and dry-run DDL roll back.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { randomUUID, createHash } = require('node:crypto');
require('dotenv').config({path:path.join(__dirname,'../.env'), quiet:true});
const { Client } = require('pg');
const root = path.join(__dirname,'..');
const spatial = require('../phase2-spatial.json');
const baselineHash = '0372829fc09c576e64265d4e8848f8f7d0c98427d53aa4f140da7ac38ec90da6';
async function main() {
  assert.equal(createHash('sha256').update(fs.readFileSync(path.join(root,'prisma/migrations/0_init/migration.sql'))).digest('hex'), baselineHash);
  const url = new URL(process.env.DATABASE_URL);
  assert.ok(['localhost','127.0.0.1','[::1]'].includes(url.hostname));
  assert.equal(url.port || '5432','5432');
  assert.equal(url.pathname,'/routemate_db');
  const c = new Client({connectionString:process.env.DATABASE_URL});
  let stage = 'connect';
  const q = (sql, args) => c.query(sql,args);
  async function denied(sql, args, code='42501') {
    await q('SAVEPOINT expected_failure');
    let caught;
    try { await q(sql,args); } catch(e) { caught=e; }
    await q('ROLLBACK TO SAVEPOINT expected_failure');
    assert.equal(caught?.code,code,`Expected ${code} at ${stage}`);
  }
  try {
    await c.connect();
    stage = 'migration dry run';
    if (process.argv.includes('--dry-run')) {
      const sql = fs.readFileSync(path.join(root,'prisma/migrations/20260910150000_phase2_spatial_rls/migration.sql'),'utf8');
      assert.match(sql,/COMMIT;\s*$/);
      await q(sql.replace(/COMMIT;\s*$/,''));
      // Exercise the exact conversion function used by the migration, in this rollback.
      const converter = sql.slice(sql.indexOf('CREATE FUNCTION routemate_security.phase2_geojson'), sql.indexOf('ALTER TABLE public.administrative_areas'));
      await q(converter);
      assert.equal((await q(`SELECT GeometryType(routemate_security.phase2_geojson(
        '{"type":"Polygon","coordinates":[[[3,6],[4,6],[4,7],[3,6]]]}', 'MultiPolygon')) AS t`)).rows[0].t,'MULTIPOLYGON');
      assert.equal((await q(`SELECT routemate_security.phase2_geojson(NULL,'Point') IS NULL AS ok`)).rows[0].ok,true);
      for (const value of [
        {type:'Point',coordinates:[181,6]}, {type:'Point',coordinates:[3,91]},
        {type:'Point',coordinates:[3,6,1]}, {type:'Point',coordinates:[]},
        {type:'LineString',coordinates:[[3,6],[4,7]]}, null,
        {type:'Feature',geometry:{type:'Point',coordinates:[3,6]}},
        {type:'Point',coordinates:[3,6],crs:{type:'name',properties:{name:'EPSG:3857'}}}
      ]) await denied(`SELECT routemate_security.phase2_geojson($1::jsonb,'Point')`,[JSON.stringify(value)],'P0001');
      await q('DROP FUNCTION routemate_security.phase2_geojson(jsonb,text)');
    } else await q('BEGIN');
    stage = 'catalog coverage';
    for (const s of spatial) {
      const r = await q(`SELECT format_type(a.atttypid,a.atttypmod) AS t FROM pg_attribute a
        WHERE a.attrelid=$1::regclass AND a.attname=$2`,[`public.${s.table}`,s.column]);
      assert.equal(r.rows[0].t.toLowerCase(),s.type.toLowerCase());
      const i = await q('SELECT indexdef FROM pg_indexes WHERE schemaname=$1 AND indexname=$2',['public',`${s.table}_${s.column}_gist`]);
      assert.match(i.rows[0].indexdef,/USING gist/);
    }
    const tables = [...fs.readFileSync(path.join(root,'prisma/schema.prisma'),'utf8').matchAll(/@@map\("(.*?)"\)/g)].map(m=>m[1]);
    const covered = await q(`SELECT relname FROM pg_class WHERE relnamespace='public'::regnamespace AND relname=ANY($1) AND relrowsecurity AND relforcerowsecurity`,[tables]);
    assert.equal(covered.rowCount,tables.length);
    const roles = await q(`SELECT * FROM pg_roles WHERE rolname IN ('routemate_app','routemate_platform_admin')`);
    assert.equal(roles.rowCount,2);
    for(const r of roles.rows) for(const flag of ['rolsuper','rolbypassrls','rolcreaterole','rolcreatedb','rolreplication']) assert.equal(r[flag],false);
    assert.equal((await q(`SELECT pg_has_role('routemate_app','routemate_platform_admin','MEMBER') AS member`)).rows[0].member,false);
    stage = 'fixtures';
    const a=randomUUID(), b=randomUUID(), ua=randomUUID(), ub=randomUUID(), p=randomUUID(), other=randomUUID();
    for(const id of [a,b]) await q(`INSERT INTO organizations(id,organization_code,name,organization_type,updated_at) VALUES($1,$2,'Phase2 test','OTHER',now())`,[id,id.slice(0,20)]);
    for(const [id,org] of [[ua,a],[ub,b]]) await q(`INSERT INTO organization_units(id,organization_id,code,name,unit_type,updated_at,location) VALUES($1,$2,$3,'Test','BRANCH',now(),ST_SetSRID(ST_MakePoint(3,6),4326)::geography)`,[id,org,id]);
    for(const id of [p,other]) await q(`INSERT INTO passengers(id,updated_at) VALUES($1,now())`,[id]);
    await q(`SET LOCAL ROLE routemate_app`);
    stage = 'absent and malformed tenant context';
    assert.equal((await q('SELECT id FROM organization_units')).rowCount,0);
    await q(`SELECT set_config('app.organization_id','malformed',true)`);
    assert.equal((await q('SELECT id FROM organization_units')).rowCount,0);
    await denied(`INSERT INTO organization_units(organization_id,code,name,unit_type,updated_at) VALUES($1,'denied','Test','BRANCH',now())`,[a]);
    stage = 'tenant CRUD and cross-tenant denial';
    await q(`SELECT set_config('app.organization_id',$1,true)`,[a]);
    assert.deepEqual((await q('SELECT id FROM organization_units')).rows.map(r=>r.id),[ua]);
    assert.equal((await q(`UPDATE organization_units SET name='Allowed' WHERE id=$1`,[ua])).rowCount,1);
    assert.equal((await q(`UPDATE organization_units SET name='Denied' WHERE id=$1`,[ub])).rowCount,0);
    assert.equal((await q(`DELETE FROM organization_units WHERE id=$1`,[ub])).rowCount,0);
    await denied(`UPDATE organization_units SET organization_id=$1 WHERE id=$2`,[b,ua]);
    await denied(`INSERT INTO organization_units(organization_id,code,name,unit_type,updated_at) VALUES($1,'denied','Test','BRANCH',now())`,[b]);
    const inserted=await q(`INSERT INTO organization_units(organization_id,code,name,unit_type,updated_at) VALUES($1,'allowed','Test','BRANCH',now()) RETURNING id`,[a]);
    assert.equal((await q('DELETE FROM organization_units WHERE id=$1',[inserted.rows[0].id])).rowCount,1);
    stage = 'passenger privacy and platform spoofing';
    assert.equal((await q('SELECT id FROM passengers')).rowCount,0);
    await q(`SELECT set_config('app.passenger_id',$1,true)`,[p]);
    assert.deepEqual((await q('SELECT id FROM passengers')).rows.map(r=>r.id),[p]);
    await denied('UPDATE passengers SET id=$1 WHERE id=$2',[other,p]);
    await q(`SELECT set_config('app.is_platform_admin','true',true)`);
    assert.equal((await q('SELECT id FROM organizations')).rowCount,1);
    await denied('SELECT * FROM system_settings');
    await denied('SELECT * FROM _prisma_migrations');
    await denied(`DELETE FROM roles`);
    await denied(`DELETE FROM audit_logs`);
    // SET ROLE as a superuser connection would test the DBA, not runtime membership.
    await q('RESET ROLE');
    await q('SET SESSION AUTHORIZATION routemate_app');
    await denied('SET ROLE routemate_platform_admin');
    await q('RESET SESSION AUTHORIZATION');
    await q('SET LOCAL ROLE routemate_platform_admin');
    assert.ok((await q('SELECT id FROM organizations')).rowCount>=2);
    await q('SELECT * FROM system_settings');
    await q('RESET ROLE');
    stage = 'partial unique indexes';
    // Use temporary tables copied from real definitions to isolate index semantics from FKs.
    for(const [source,name,extra,predicate] of [
      ['driver_vehicle_assignments','driver_vehicle_assignments_one_active_primary',', assignment_type public."AssignmentType" NOT NULL',", 'PRIMARY'"],
      ['vehicle_qr_codes','vehicle_qr_codes_one_active','', '']
    ]) {
      const definition=(await q('SELECT indexdef FROM pg_indexes WHERE indexname=$1',[name])).rows[0].indexdef;
      await q(`CREATE TEMP TABLE index_fixture (organization_id uuid, vehicle_id uuid, status public.${source==='vehicle_qr_codes'?'"QrStatus"':'"AssignmentStatus"'} ${extra}) ON COMMIT DROP`);
      await q(definition.replace(`INDEX ${name}`,`INDEX test_unique`).replace(`ON public.${source}`,'ON index_fixture'));
      const vehicle=randomUUID();
      await q(`INSERT INTO index_fixture VALUES($1,$2,'ACTIVE'${predicate})`,[a,vehicle]);
      await denied(`INSERT INTO index_fixture VALUES($1,$2,'ACTIVE'${predicate})`,[a,vehicle],'23505');
      await q(`INSERT INTO index_fixture VALUES($1,$2,'${source==='vehicle_qr_codes'?'REVOKED':'ENDED'}'${predicate})`,[a,vehicle]);
      await q('DROP TABLE index_fixture');
    }
    await q('ROLLBACK');
    stage = 'pooled context cleanup';
    await q('BEGIN');
    assert.equal((await q(`SELECT nullif(current_setting('app.organization_id',true),'') IS NULL AS clean`)).rows[0].clean,true);
    await q('ROLLBACK');
    if (!process.argv.includes('--dry-run')) {
      stage = 'Prisma runtime rejects DBA impersonation';
      const { PrismaClient } = require('../generated/routemate-client');
      const { PrismaPg } = require('@prisma/adapter-pg');
      const { withRuntimeContext } = require('../runtime-context.cjs');
      // Phase 3 requires a real separate LOGIN principal, not DBA impersonation.
      const runtime = new PrismaClient({adapter:new PrismaPg({
        connectionString:process.env.DATABASE_URL, options:'-c role=routemate_app', max:1
      })});
      try {
        await assert.rejects(withRuntimeContext(runtime,{organizationId:a},async () => true), /Unsafe runtime database identity/);
      } finally { await runtime.$disconnect(); }
    }
    console.log(`PASS: baseline hash; 12 native types/GiST; ${tables.length} forced RLS tables; tenant CRUD isolation; owner privacy; platform separation; partial uniqueness; context cleanup. All fixtures rolled back.`);
  } catch(e) {
    await c.query('ROLLBACK').catch(()=>{});
    console.error(`FAIL at ${stage}: ${e.code || e.name}. ${e instanceof assert.AssertionError ? e.message : 'Database error details suppressed to protect data.'}`);
    process.exitCode=1;
  } finally { await c.end(); }
}
main().catch(()=>{console.error('Verification initialization failed; check local configuration.');process.exitCode=1;});
