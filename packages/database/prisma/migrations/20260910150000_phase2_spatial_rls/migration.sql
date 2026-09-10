-- Phase 2: additive migration history; never edit 0_init.
-- Atomic: malformed GeoJSON, duplicate active records or unsafe existing roles abort.
BEGIN;
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '5min';
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA routemate_security;
REVOKE ALL ON SCHEMA routemate_security FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Fresh NOLOGIN roles: provision credentials separately, never in source control.
-- Existing roles deliberately cause failure for DBA review (no silent privilege reuse).
CREATE ROLE routemate_app NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
  NOINHERIT NOREPLICATION NOBYPASSRLS;
CREATE ROLE routemate_platform_admin NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
  NOINHERIT NOREPLICATION NOBYPASSRLS;
GRANT USAGE ON SCHEMA public, routemate_security TO routemate_app, routemate_platform_admin;

CREATE FUNCTION routemate_security.context_uuid(setting_name text) RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = pg_catalog AS $$
BEGIN
  RETURN nullif(current_setting(setting_name, true), '')::uuid;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION routemate_security.context_uuid(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION routemate_security.context_uuid(text) TO routemate_app, routemate_platform_admin;

-- Reject wrong SRID, dimensions, shape, invalid topology and out-of-range coordinates.
-- SQL NULL stays NULL. JSON null and Feature wrappers are rejected, never discarded.
CREATE FUNCTION routemate_security.phase2_geojson(value jsonb, expected text)
RETURNS public.geometry LANGUAGE plpgsql IMMUTABLE STRICT
SET search_path = pg_catalog, public AS $$
DECLARE g public.geometry;
BEGIN
  IF jsonb_typeof(value) <> 'object' OR NOT (value ? 'coordinates') THEN
    RAISE EXCEPTION 'Spatial value must be a GeoJSON geometry object';
  END IF;
  g := public.ST_GeomFromGeoJSON(value::text);
  IF g IS NULL OR public.ST_SRID(g) <> 4326 OR public.ST_NDims(g) <> 2
     OR public.ST_IsEmpty(g) OR NOT public.ST_IsValid(g) THEN
    RAISE EXCEPTION 'Spatial value must be nonempty, valid, 2D WGS84 (SRID 4326)';
  END IF;
  IF (expected = 'MultiPolygon' AND public.GeometryType(g) NOT IN ('POLYGON','MULTIPOLYGON'))
     OR (expected <> 'MultiPolygon' AND public.GeometryType(g) <> upper(expected)) THEN
    RAISE EXCEPTION 'Unexpected spatial geometry type; expected %', expected;
  END IF;
  IF EXISTS (SELECT 1 FROM public.ST_DumpPoints(g) AS p
    WHERE NOT (public.ST_X(p.geom) BETWEEN -180 AND 180)
       OR NOT (public.ST_Y(p.geom) BETWEEN -90 AND 90)) THEN
    RAISE EXCEPTION 'Spatial longitude/latitude out of range';
  END IF;
  IF expected = 'MultiPolygon' THEN RETURN public.ST_Multi(g); END IF;
  RETURN g;
END $$;
REVOKE ALL ON FUNCTION routemate_security.phase2_geojson(jsonb,text) FROM PUBLIC;

ALTER TABLE public.administrative_areas ALTER COLUMN geometry TYPE public.geometry(MultiPolygon,4326)
  USING routemate_security.phase2_geojson(geometry, 'MultiPolygon')::public.geometry(MultiPolygon,4326);
CREATE INDEX administrative_areas_geometry_gist ON public.administrative_areas USING gist (geometry);
ALTER TABLE public.organization_units ALTER COLUMN location TYPE public.geography(Point,4326)
  USING routemate_security.phase2_geojson(location, 'Point')::public.geography(Point,4326);
CREATE INDEX organization_units_location_gist ON public.organization_units USING gist (location);
ALTER TABLE public.parks ALTER COLUMN location TYPE public.geography(Point,4326)
  USING routemate_security.phase2_geojson(location, 'Point')::public.geography(Point,4326);
CREATE INDEX parks_location_gist ON public.parks USING gist (location);
ALTER TABLE public.routes ALTER COLUMN origin_location TYPE public.geography(Point,4326)
  USING routemate_security.phase2_geojson(origin_location, 'Point')::public.geography(Point,4326);
CREATE INDEX routes_origin_location_gist ON public.routes USING gist (origin_location);
ALTER TABLE public.routes ALTER COLUMN destination_location TYPE public.geography(Point,4326)
  USING routemate_security.phase2_geojson(destination_location, 'Point')::public.geography(Point,4326);
CREATE INDEX routes_destination_location_gist ON public.routes USING gist (destination_location);
ALTER TABLE public.routes ALTER COLUMN route_geometry TYPE public.geometry(LineString,4326)
  USING routemate_security.phase2_geojson(route_geometry, 'LineString')::public.geometry(LineString,4326);
CREATE INDEX routes_route_geometry_gist ON public.routes USING gist (route_geometry);
ALTER TABLE public.route_stops ALTER COLUMN location TYPE public.geography(Point,4326)
  USING routemate_security.phase2_geojson(location, 'Point')::public.geography(Point,4326);
CREATE INDEX route_stops_location_gist ON public.route_stops USING gist (location);
ALTER TABLE public.verification_scans ALTER COLUMN location TYPE public.geography(Point,4326)
  USING routemate_security.phase2_geojson(location, 'Point')::public.geography(Point,4326);
CREATE INDEX verification_scans_location_gist ON public.verification_scans USING gist (location);
ALTER TABLE public.journeys ALTER COLUMN boarding_location TYPE public.geography(Point,4326)
  USING routemate_security.phase2_geojson(boarding_location, 'Point')::public.geography(Point,4326);
CREATE INDEX journeys_boarding_location_gist ON public.journeys USING gist (boarding_location);
ALTER TABLE public.journeys ALTER COLUMN ending_location TYPE public.geography(Point,4326)
  USING routemate_security.phase2_geojson(ending_location, 'Point')::public.geography(Point,4326);
CREATE INDEX journeys_ending_location_gist ON public.journeys USING gist (ending_location);
ALTER TABLE public.journey_events ALTER COLUMN location TYPE public.geography(Point,4326)
  USING routemate_security.phase2_geojson(location, 'Point')::public.geography(Point,4326);
CREATE INDEX journey_events_location_gist ON public.journey_events USING gist (location);
ALTER TABLE public.incidents ALTER COLUMN location TYPE public.geography(Point,4326)
  USING routemate_security.phase2_geojson(location, 'Point')::public.geography(Point,4326);
CREATE INDEX incidents_location_gist ON public.incidents USING gist (location);
DROP FUNCTION routemate_security.phase2_geojson(jsonb,text);

-- ACTIVE alone defines reservation: end/revocation timestamps do not release it.
CREATE UNIQUE INDEX driver_vehicle_assignments_one_active_primary
  ON public.driver_vehicle_assignments (organization_id, vehicle_id)
  WHERE status = 'ACTIVE' AND assignment_type = 'PRIMARY';
CREATE UNIQUE INDEX vehicle_qr_codes_one_active
  ON public.vehicle_qr_codes (organization_id, vehicle_id) WHERE status = 'ACTIVE';

-- organizations
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.organizations FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.organizations TO routemate_platform_admin;
CREATE POLICY platform_access ON public.organizations TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT ON TABLE public.organizations TO routemate_app;
CREATE POLICY runtime_read ON public.organizations FOR SELECT TO routemate_app USING (id = routemate_security.context_uuid('app.organization_id'));

-- organization_settings
ALTER TABLE public.organization_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_settings FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.organization_settings FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.organization_settings TO routemate_platform_admin;
CREATE POLICY platform_access ON public.organization_settings TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.organization_settings TO routemate_app;
CREATE POLICY runtime_scope ON public.organization_settings TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- administrative_areas
ALTER TABLE public.administrative_areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.administrative_areas FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.administrative_areas FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.administrative_areas TO routemate_platform_admin;
CREATE POLICY platform_access ON public.administrative_areas TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT ON TABLE public.administrative_areas TO routemate_app;
CREATE POLICY runtime_read ON public.administrative_areas FOR SELECT TO routemate_app USING (true);

-- organization_units
ALTER TABLE public.organization_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_units FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.organization_units FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.organization_units TO routemate_platform_admin;
CREATE POLICY platform_access ON public.organization_units TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.organization_units TO routemate_app;
CREATE POLICY runtime_scope ON public.organization_units TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- parks
ALTER TABLE public.parks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parks FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.parks FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.parks TO routemate_platform_admin;
CREATE POLICY platform_access ON public.parks TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.parks TO routemate_app;
CREATE POLICY runtime_scope ON public.parks TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.users FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.users TO routemate_platform_admin;
CREATE POLICY platform_access ON public.users TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT ON TABLE public.users TO routemate_app;
CREATE POLICY runtime_read ON public.users FOR SELECT TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id'));

-- roles
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.roles FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.roles TO routemate_platform_admin;
CREATE POLICY platform_access ON public.roles TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT ON TABLE public.roles TO routemate_app;
CREATE POLICY runtime_read ON public.roles FOR SELECT TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id'));

-- permissions
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.permissions FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.permissions TO routemate_platform_admin;
CREATE POLICY platform_access ON public.permissions TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT ON TABLE public.permissions TO routemate_app;
CREATE POLICY runtime_read ON public.permissions FOR SELECT TO routemate_app USING (true);

-- user_roles
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.user_roles FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.user_roles TO routemate_platform_admin;
CREATE POLICY platform_access ON public.user_roles TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT ON TABLE public.user_roles TO routemate_app;
CREATE POLICY runtime_read ON public.user_roles FOR SELECT TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id'));

-- role_permissions
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.role_permissions FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.role_permissions TO routemate_platform_admin;
CREATE POLICY platform_access ON public.role_permissions TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT ON TABLE public.role_permissions TO routemate_app;
CREATE POLICY runtime_read ON public.role_permissions FOR SELECT TO routemate_app USING (EXISTS (SELECT 1 FROM public.roles r WHERE r.id = role_id));

-- drivers
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.drivers FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.drivers TO routemate_platform_admin;
CREATE POLICY platform_access ON public.drivers TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.drivers TO routemate_app;
CREATE POLICY runtime_scope ON public.drivers TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- driver_contacts
ALTER TABLE public.driver_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_contacts FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.driver_contacts FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.driver_contacts TO routemate_platform_admin;
CREATE POLICY platform_access ON public.driver_contacts TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.driver_contacts TO routemate_app;
CREATE POLICY runtime_scope ON public.driver_contacts TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- driver_documents
ALTER TABLE public.driver_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_documents FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.driver_documents FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.driver_documents TO routemate_platform_admin;
CREATE POLICY platform_access ON public.driver_documents TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.driver_documents TO routemate_app;
CREATE POLICY runtime_scope ON public.driver_documents TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- driver_status_history
ALTER TABLE public.driver_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_status_history FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.driver_status_history FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.driver_status_history TO routemate_platform_admin;
CREATE POLICY platform_access ON public.driver_status_history TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT ON TABLE public.driver_status_history TO routemate_app;
CREATE POLICY runtime_scope ON public.driver_status_history TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- driver_disciplinary_actions
ALTER TABLE public.driver_disciplinary_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_disciplinary_actions FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.driver_disciplinary_actions FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.driver_disciplinary_actions TO routemate_platform_admin;
CREATE POLICY platform_access ON public.driver_disciplinary_actions TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.driver_disciplinary_actions TO routemate_app;
CREATE POLICY runtime_scope ON public.driver_disciplinary_actions TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- conductors
ALTER TABLE public.conductors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conductors FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.conductors FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.conductors TO routemate_platform_admin;
CREATE POLICY platform_access ON public.conductors TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.conductors TO routemate_app;
CREATE POLICY runtime_scope ON public.conductors TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- vehicle_owners
ALTER TABLE public.vehicle_owners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_owners FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.vehicle_owners FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicle_owners TO routemate_platform_admin;
CREATE POLICY platform_access ON public.vehicle_owners TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicle_owners TO routemate_app;
CREATE POLICY runtime_scope ON public.vehicle_owners TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- vehicles
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.vehicles FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicles TO routemate_platform_admin;
CREATE POLICY platform_access ON public.vehicles TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicles TO routemate_app;
CREATE POLICY runtime_scope ON public.vehicles TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- vehicle_documents
ALTER TABLE public.vehicle_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_documents FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.vehicle_documents FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicle_documents TO routemate_platform_admin;
CREATE POLICY platform_access ON public.vehicle_documents TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicle_documents TO routemate_app;
CREATE POLICY runtime_scope ON public.vehicle_documents TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- vehicle_ownership_history
ALTER TABLE public.vehicle_ownership_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_ownership_history FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.vehicle_ownership_history FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicle_ownership_history TO routemate_platform_admin;
CREATE POLICY platform_access ON public.vehicle_ownership_history TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicle_ownership_history TO routemate_app;
CREATE POLICY runtime_scope ON public.vehicle_ownership_history TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- driver_vehicle_assignments
ALTER TABLE public.driver_vehicle_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_vehicle_assignments FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.driver_vehicle_assignments FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.driver_vehicle_assignments TO routemate_platform_admin;
CREATE POLICY platform_access ON public.driver_vehicle_assignments TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.driver_vehicle_assignments TO routemate_app;
CREATE POLICY runtime_scope ON public.driver_vehicle_assignments TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- vehicle_crew_assignments
ALTER TABLE public.vehicle_crew_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_crew_assignments FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.vehicle_crew_assignments FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicle_crew_assignments TO routemate_platform_admin;
CREATE POLICY platform_access ON public.vehicle_crew_assignments TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicle_crew_assignments TO routemate_app;
CREATE POLICY runtime_scope ON public.vehicle_crew_assignments TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- routes
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routes FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.routes FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.routes TO routemate_platform_admin;
CREATE POLICY platform_access ON public.routes TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.routes TO routemate_app;
CREATE POLICY runtime_scope ON public.routes TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- route_stops
ALTER TABLE public.route_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_stops FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.route_stops FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_stops TO routemate_platform_admin;
CREATE POLICY platform_access ON public.route_stops TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_stops TO routemate_app;
CREATE POLICY runtime_scope ON public.route_stops TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- park_routes
ALTER TABLE public.park_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.park_routes FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.park_routes FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.park_routes TO routemate_platform_admin;
CREATE POLICY platform_access ON public.park_routes TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.park_routes TO routemate_app;
CREATE POLICY runtime_scope ON public.park_routes TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- vehicle_route_assignments
ALTER TABLE public.vehicle_route_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_route_assignments FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.vehicle_route_assignments FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicle_route_assignments TO routemate_platform_admin;
CREATE POLICY platform_access ON public.vehicle_route_assignments TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicle_route_assignments TO routemate_app;
CREATE POLICY runtime_scope ON public.vehicle_route_assignments TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- vehicle_qr_codes
ALTER TABLE public.vehicle_qr_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_qr_codes FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.vehicle_qr_codes FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicle_qr_codes TO routemate_platform_admin;
CREATE POLICY platform_access ON public.vehicle_qr_codes TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicle_qr_codes TO routemate_app;
CREATE POLICY runtime_scope ON public.vehicle_qr_codes TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- passenger_sessions
ALTER TABLE public.passenger_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.passenger_sessions FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.passenger_sessions FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.passenger_sessions TO routemate_platform_admin;
CREATE POLICY platform_access ON public.passenger_sessions TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.passenger_sessions TO routemate_app;
CREATE POLICY runtime_scope ON public.passenger_sessions TO routemate_app USING ((passenger_id = routemate_security.context_uuid('app.passenger_id') OR
    (id = routemate_security.context_uuid('app.passenger_session_id') AND
     (passenger_id IS NULL OR passenger_id = routemate_security.context_uuid('app.passenger_id'))))) WITH CHECK ((passenger_id = routemate_security.context_uuid('app.passenger_id') OR
    (id = routemate_security.context_uuid('app.passenger_session_id') AND
     (passenger_id IS NULL OR passenger_id = routemate_security.context_uuid('app.passenger_id')))));

-- passengers
ALTER TABLE public.passengers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.passengers FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.passengers FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.passengers TO routemate_platform_admin;
CREATE POLICY platform_access ON public.passengers TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.passengers TO routemate_app;
CREATE POLICY runtime_scope ON public.passengers TO routemate_app USING (id = routemate_security.context_uuid('app.passenger_id')) WITH CHECK (id = routemate_security.context_uuid('app.passenger_id'));

-- trusted_contacts
ALTER TABLE public.trusted_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trusted_contacts FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.trusted_contacts FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.trusted_contacts TO routemate_platform_admin;
CREATE POLICY platform_access ON public.trusted_contacts TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.trusted_contacts TO routemate_app;
CREATE POLICY runtime_scope ON public.trusted_contacts TO routemate_app USING (passenger_id = routemate_security.context_uuid('app.passenger_id')) WITH CHECK (passenger_id = routemate_security.context_uuid('app.passenger_id'));

-- verification_scans
ALTER TABLE public.verification_scans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_scans FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.verification_scans FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.verification_scans TO routemate_platform_admin;
CREATE POLICY platform_access ON public.verification_scans TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT ON TABLE public.verification_scans TO routemate_app;
CREATE POLICY runtime_scope ON public.verification_scans TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- journeys
ALTER TABLE public.journeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journeys FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.journeys FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.journeys TO routemate_platform_admin;
CREATE POLICY platform_access ON public.journeys TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.journeys TO routemate_app;
CREATE POLICY runtime_scope ON public.journeys TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- journey_events
ALTER TABLE public.journey_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_events FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.journey_events FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.journey_events TO routemate_platform_admin;
CREATE POLICY platform_access ON public.journey_events TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT ON TABLE public.journey_events TO routemate_app;
CREATE POLICY runtime_scope ON public.journey_events TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- journey_shares
ALTER TABLE public.journey_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_shares FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.journey_shares FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.journey_shares TO routemate_platform_admin;
CREATE POLICY platform_access ON public.journey_shares TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.journey_shares TO routemate_app;
CREATE POLICY runtime_scope ON public.journey_shares TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- complaints
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaints FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.complaints FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.complaints TO routemate_platform_admin;
CREATE POLICY platform_access ON public.complaints TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.complaints TO routemate_app;
CREATE POLICY runtime_scope ON public.complaints TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- complaint_updates
ALTER TABLE public.complaint_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaint_updates FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.complaint_updates FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.complaint_updates TO routemate_platform_admin;
CREATE POLICY platform_access ON public.complaint_updates TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT ON TABLE public.complaint_updates TO routemate_app;
CREATE POLICY runtime_scope ON public.complaint_updates TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- incidents
ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incidents FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.incidents FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.incidents TO routemate_platform_admin;
CREATE POLICY platform_access ON public.incidents TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.incidents TO routemate_app;
CREATE POLICY runtime_scope ON public.incidents TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- incident_evidence
ALTER TABLE public.incident_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incident_evidence FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.incident_evidence FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.incident_evidence TO routemate_platform_admin;
CREATE POLICY platform_access ON public.incident_evidence TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT ON TABLE public.incident_evidence TO routemate_app;
CREATE POLICY runtime_scope ON public.incident_evidence TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- incident_updates
ALTER TABLE public.incident_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incident_updates FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.incident_updates FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.incident_updates TO routemate_platform_admin;
CREATE POLICY platform_access ON public.incident_updates TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT ON TABLE public.incident_updates TO routemate_app;
CREATE POLICY runtime_scope ON public.incident_updates TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- lost_property_cases
ALTER TABLE public.lost_property_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lost_property_cases FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.lost_property_cases FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.lost_property_cases TO routemate_platform_admin;
CREATE POLICY platform_access ON public.lost_property_cases TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.lost_property_cases TO routemate_app;
CREATE POLICY runtime_scope ON public.lost_property_cases TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- lost_property_updates
ALTER TABLE public.lost_property_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lost_property_updates FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.lost_property_updates FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.lost_property_updates TO routemate_platform_admin;
CREATE POLICY platform_access ON public.lost_property_updates TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT ON TABLE public.lost_property_updates TO routemate_app;
CREATE POLICY runtime_scope ON public.lost_property_updates TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.notifications FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.notifications TO routemate_platform_admin;
CREATE POLICY platform_access ON public.notifications TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.notifications TO routemate_app;
CREATE POLICY runtime_scope ON public.notifications TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- audit_logs
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.audit_logs FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.audit_logs TO routemate_platform_admin;
CREATE POLICY platform_access ON public.audit_logs TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT ON TABLE public.audit_logs TO routemate_app;
CREATE POLICY runtime_scope ON public.audit_logs TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- security_events
ALTER TABLE public.security_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_events FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.security_events FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.security_events TO routemate_platform_admin;
CREATE POLICY platform_access ON public.security_events TO routemate_platform_admin USING (true) WITH CHECK (true);
GRANT SELECT, INSERT ON TABLE public.security_events TO routemate_app;
CREATE POLICY runtime_scope ON public.security_events TO routemate_app USING (organization_id = routemate_security.context_uuid('app.organization_id')) WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id'));

-- system_settings
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.system_settings FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.system_settings TO routemate_platform_admin;
CREATE POLICY platform_access ON public.system_settings TO routemate_platform_admin USING (true) WITH CHECK (true);

-- No runtime access to migration history or extension metadata writes.
REVOKE ALL ON TABLE public._prisma_migrations FROM PUBLIC, routemate_app, routemate_platform_admin;
COMMIT;
