-- Operational permissions, route uniqueness and a narrow public QR projection.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='5min';
INSERT INTO public.permissions(code,name,updated_at)
SELECT code,code,now() FROM unnest(ARRAY['park.view','park.create','route.view','route.create',
  'driver.approve','vehicle.approve','vehicle.suspend','assignment.view','assignment.manage','qr.issue','qr.revoke']) AS code
ON CONFLICT(code) DO NOTHING;
INSERT INTO public.role_permissions(role_id,permission_id,updated_at)
SELECT r.id,p.id,now() FROM public.roles r CROSS JOIN public.permissions p
WHERE r.organization_id IS NOT NULL AND r.code='ORGANIZATION_ADMIN'
  AND p.code IN ('park.view','park.create','route.view','route.create','driver.approve','vehicle.approve',
    'vehicle.suspend','assignment.view','assignment.manage','qr.issue','qr.revoke')
ON CONFLICT DO NOTHING;
CREATE UNIQUE INDEX vehicle_route_assignments_one_active_route_park
  ON public.vehicle_route_assignments(organization_id,vehicle_id,route_id,park_id)
  NULLS NOT DISTINCT WHERE status='ACTIVE';

CREATE ROLE routemate_verification_owner NOLOGIN NOINHERIT NOSUPERUSER NOBYPASSRLS
  NOCREATEDB NOCREATEROLE NOREPLICATION;
GRANT USAGE ON SCHEMA public,routemate_security TO routemate_verification_owner;
-- Column-level privileges deliberately exclude driver names, phone, ID and documents.
GRANT SELECT(id,organization_id,vehicle_id,public_token_hash,status,revoked_at,expires_at) ON public.vehicle_qr_codes TO routemate_verification_owner;
GRANT SELECT(id,name,status,deleted_at) ON public.organizations TO routemate_verification_owner;
GRANT SELECT(id,organization_id,vehicle_code,plate_number,make,model,colour,registration_status,compliance_status,deleted_at,primary_park_id) ON public.vehicles TO routemate_verification_owner;
GRANT SELECT(id,organization_id,registration_status,compliance_status,disciplinary_status,deleted_at) ON public.drivers TO routemate_verification_owner;
GRANT SELECT(id,organization_id,vehicle_id,driver_id,assignment_type,status,start_at,end_at) ON public.driver_vehicle_assignments TO routemate_verification_owner;
GRANT SELECT(id,organization_id,vehicle_id,route_id,park_id,status,start_at,end_at) ON public.vehicle_route_assignments TO routemate_verification_owner;
GRANT SELECT(id,organization_id,name,origin_name,destination_name,status,deleted_at) ON public.routes TO routemate_verification_owner;
GRANT SELECT(id,organization_id,status,deleted_at) ON public.parks TO routemate_verification_owner;
GRANT SELECT(organization_id,park_id,route_id,status,deleted_at) ON public.park_routes TO routemate_verification_owner;
GRANT INSERT(organization_id,vehicle_id,qr_code_id,driver_assignment_id,route_assignment_id,verification_result) ON public.verification_scans TO routemate_verification_owner;
CREATE POLICY public_projection ON public.vehicle_qr_codes FOR SELECT TO routemate_verification_owner USING(true);
CREATE POLICY public_projection ON public.organizations FOR SELECT TO routemate_verification_owner USING(true);
CREATE POLICY public_projection ON public.vehicles FOR SELECT TO routemate_verification_owner USING(true);
CREATE POLICY public_projection ON public.drivers FOR SELECT TO routemate_verification_owner USING(true);
CREATE POLICY public_projection ON public.driver_vehicle_assignments FOR SELECT TO routemate_verification_owner USING(true);
CREATE POLICY public_projection ON public.vehicle_route_assignments FOR SELECT TO routemate_verification_owner USING(true);
CREATE POLICY public_projection ON public.routes FOR SELECT TO routemate_verification_owner USING(true);
CREATE POLICY public_projection ON public.parks FOR SELECT TO routemate_verification_owner USING(true);
CREATE POLICY public_projection ON public.park_routes FOR SELECT TO routemate_verification_owner USING(true);
CREATE POLICY public_scan ON public.verification_scans FOR INSERT TO routemate_verification_owner WITH CHECK(true);

CREATE FUNCTION routemate_security.verify_vehicle_qr(token_hash text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE qr record; vehicle record; driver_assignment record; route_assignment record;
  result public."VerificationResult" := 'UNKNOWN'; payload jsonb := '{"status":"UNAVAILABLE"}';
BEGIN
  IF token_hash IS NULL OR token_hash !~ '^[a-f0-9]{64}$' THEN RETURN payload; END IF;
  SELECT q.id,q.organization_id,q.vehicle_id,q.status,q.revoked_at,q.expires_at INTO qr
    FROM public.vehicle_qr_codes q WHERE q.public_token_hash=token_hash;
  IF NOT FOUND THEN RETURN payload; END IF;
  SELECT v.id,v.vehicle_code,v.plate_number,v.make,v.model,v.colour,v.registration_status,v.compliance_status,
    o.name AS organization_name,o.status AS organization_status,p.status AS park_status
    INTO vehicle FROM public.vehicles v JOIN public.organizations o ON o.id=v.organization_id
      JOIN public.parks p ON p.id=v.primary_park_id AND p.organization_id=v.organization_id
    WHERE v.id=qr.vehicle_id AND v.organization_id=qr.organization_id
      AND v.deleted_at IS NULL AND o.deleted_at IS NULL AND p.deleted_at IS NULL;
  SELECT a.id,d.registration_status,d.compliance_status,d.disciplinary_status INTO driver_assignment
    FROM public.driver_vehicle_assignments a JOIN public.drivers d ON d.id=a.driver_id AND d.organization_id=a.organization_id
    WHERE a.organization_id=qr.organization_id AND a.vehicle_id=qr.vehicle_id AND a.status='ACTIVE'
      AND a.assignment_type='PRIMARY' AND a.start_at<=now() AND (a.end_at IS NULL OR a.end_at>now()) AND d.deleted_at IS NULL;
  SELECT CASE WHEN count(*)=1 THEN (array_agg(a.id))[1] ELSE NULL END AS id,
    jsonb_agg(jsonb_build_object('name',r.name,'origin',r.origin_name,'destination',r.destination_name) ORDER BY a.id) AS options INTO route_assignment
    FROM public.vehicle_route_assignments a JOIN public.routes r ON r.id=a.route_id AND r.organization_id=a.organization_id
      JOIN public.parks p ON p.id=a.park_id AND p.organization_id=a.organization_id
    WHERE a.organization_id=qr.organization_id AND a.vehicle_id=qr.vehicle_id AND a.status='ACTIVE'
      AND a.start_at<=now() AND (a.end_at IS NULL OR a.end_at>now()) AND r.status='ACTIVE' AND r.deleted_at IS NULL
      AND p.status='ACTIVE' AND p.deleted_at IS NULL AND EXISTS (SELECT 1 FROM public.park_routes pr
        WHERE pr.organization_id=a.organization_id AND pr.park_id=a.park_id AND pr.route_id=a.route_id AND pr.status='ACTIVE' AND pr.deleted_at IS NULL)
    ;
  IF qr.status<>'ACTIVE' OR qr.revoked_at IS NOT NULL THEN result:='QR_REVOKED';
  ELSIF qr.expires_at IS NOT NULL AND qr.expires_at<=now() THEN result:='QR_EXPIRED';
  ELSIF vehicle.id IS NULL OR vehicle.registration_status<>'ACTIVE' OR vehicle.organization_status<>'ACTIVE' OR vehicle.park_status<>'ACTIVE' THEN result:='VEHICLE_SUSPENDED';
  ELSIF driver_assignment.id IS NULL OR driver_assignment.registration_status<>'ACTIVE' OR driver_assignment.disciplinary_status IN ('SUSPENDED','BANNED') THEN result:='DRIVER_SUSPENDED';
  ELSIF route_assignment.options IS NULL THEN result:='UNKNOWN';
  ELSE
    result:='VALID';
    payload:=jsonb_build_object('status','REGISTERED','verificationScope','REGISTRATION_AND_ASSIGNMENT',
      'organization',vehicle.organization_name,
      'vehicle',jsonb_build_object('code',vehicle.vehicle_code,'plateNumber',vehicle.plate_number,'make',vehicle.make,'model',vehicle.model,'colour',vehicle.colour,'complianceStatus',vehicle.compliance_status),
      'driver',jsonb_build_object('registrationStatus',driver_assignment.registration_status,'complianceStatus',driver_assignment.compliance_status),
      'routes',route_assignment.options);
  END IF;
  INSERT INTO public.verification_scans(organization_id,vehicle_id,qr_code_id,driver_assignment_id,route_assignment_id,verification_result)
    VALUES(qr.organization_id,qr.vehicle_id,qr.id,driver_assignment.id,route_assignment.id,result);
  RETURN payload;
END $$;
ALTER FUNCTION routemate_security.verify_vehicle_qr(text) OWNER TO routemate_verification_owner;
REVOKE ALL ON FUNCTION routemate_security.verify_vehicle_qr(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION routemate_security.verify_vehicle_qr(text) TO routemate_app;
COMMIT;
