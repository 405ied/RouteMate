-- Staff sessions and constrained pre-authentication access. Existing RLS stays enabled.
BEGIN;
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '5min';
CREATE TABLE public.staff_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  user_id uuid NOT NULL,
  refresh_token_hash varchar(64) NOT NULL,
  expires_at timestamptz(6) NOT NULL,
  revoked_at timestamptz(6),
  created_at timestamptz(6) NOT NULL DEFAULT now(),
  updated_at timestamptz(6) NOT NULL DEFAULT now(),
  CONSTRAINT staff_sessions_user_fk FOREIGN KEY (organization_id,user_id)
    REFERENCES public.users(organization_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT staff_sessions_organization_fk FOREIGN KEY (organization_id)
    REFERENCES public.organizations(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT staff_sessions_expiry CHECK (expires_at > created_at),
  CONSTRAINT staff_sessions_hash CHECK (refresh_token_hash ~ '^[a-f0-9]{64}$')
);
CREATE INDEX staff_sessions_organization_id_user_id_idx ON public.staff_sessions(organization_id,user_id);
CREATE INDEX staff_sessions_expires_at_idx ON public.staff_sessions(expires_at);
ALTER TABLE public.staff_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_sessions FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.staff_sessions FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE ON public.staff_sessions TO routemate_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.staff_sessions TO routemate_platform_admin;
CREATE POLICY staff_session_owner ON public.staff_sessions TO routemate_app
  USING (organization_id = routemate_security.context_uuid('app.organization_id')
    AND user_id = routemate_security.context_uuid('app.user_id'))
  WITH CHECK (organization_id = routemate_security.context_uuid('app.organization_id')
    AND user_id = routemate_security.context_uuid('app.user_id'));
CREATE POLICY platform_access ON public.staff_sessions TO routemate_platform_admin USING (true) WITH CHECK (true);
CREATE UNIQUE INDEX users_organization_email_normalized
  ON public.users(organization_id, lower(btrim(email)))
  WHERE organization_id IS NOT NULL AND email IS NOT NULL;

-- Function owner has no login, membership grants, table ownership or RLS bypass.
CREATE ROLE routemate_auth_owner NOLOGIN NOINHERIT NOSUPERUSER NOBYPASSRLS
  NOCREATEDB NOCREATEROLE NOREPLICATION;
GRANT USAGE ON SCHEMA public, routemate_security TO routemate_auth_owner;
GRANT SELECT ON public.users, public.organizations TO routemate_auth_owner;
GRANT UPDATE(failed_login_attempts, locked_until, last_login_at, updated_at)
  ON public.users TO routemate_auth_owner;
CREATE POLICY authentication_lookup ON public.users FOR SELECT TO routemate_auth_owner USING (organization_id IS NOT NULL);
CREATE POLICY authentication_organization ON public.organizations FOR SELECT TO routemate_auth_owner USING (true);
CREATE POLICY authentication_counters ON public.users FOR UPDATE TO routemate_auth_owner
  USING (organization_id IS NOT NULL) WITH CHECK (organization_id IS NOT NULL);
CREATE FUNCTION routemate_security.staff_login_candidate(org_code text, login_email text)
RETURNS TABLE(id uuid, organization_id uuid, password_hash text, status text,
  locked_until timestamptz, mfa_enabled boolean, organization_status text)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT u.id,u.organization_id,u.password_hash,u.status::text,u.locked_until,
         u.mfa_enabled,o.status::text
  FROM public.users u JOIN public.organizations o ON o.id=u.organization_id
  WHERE o.organization_code=org_code AND lower(btrim(u.email))=lower(btrim(login_email))
    AND u.deleted_at IS NULL AND o.deleted_at IS NULL
  FOR UPDATE OF u
$$;
CREATE FUNCTION routemate_security.staff_login_result(staff_id uuid, successful boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF successful THEN
    UPDATE public.users SET failed_login_attempts=0, locked_until=NULL,
      last_login_at=now(), updated_at=now() WHERE id=staff_id AND organization_id IS NOT NULL;
  ELSE
    UPDATE public.users SET
      failed_login_attempts=CASE WHEN locked_until <= now() THEN 1 ELSE least(failed_login_attempts+1,5) END,
      locked_until=CASE
        WHEN locked_until > now() THEN locked_until
        WHEN (CASE WHEN locked_until <= now() THEN 1 ELSE failed_login_attempts+1 END) >= 5
          THEN now()+interval '15 minutes' ELSE NULL END,
      updated_at=now()
    WHERE id=staff_id AND organization_id IS NOT NULL;
  END IF;
END $$;
ALTER FUNCTION routemate_security.staff_login_candidate(text,text) OWNER TO routemate_auth_owner;
ALTER FUNCTION routemate_security.staff_login_result(uuid,boolean) OWNER TO routemate_auth_owner;
REVOKE ALL ON FUNCTION routemate_security.staff_login_candidate(text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION routemate_security.staff_login_result(uuid,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION routemate_security.staff_login_candidate(text,text) TO routemate_app;
GRANT EXECUTE ON FUNCTION routemate_security.staff_login_result(uuid,boolean) TO routemate_app;
COMMIT;
