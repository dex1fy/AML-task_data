BEGIN;


DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'aml_owner') THEN
            CREATE ROLE aml_owner NOLOGIN;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'aml_admin') THEN
            CREATE ROLE aml_admin NOLOGIN;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'aml_app') THEN
            CREATE ROLE aml_app NOLOGIN;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'aml_readonly') THEN
            CREATE ROLE aml_readonly NOLOGIN;
        END IF;
    END;
$$;


-- LOGIN-роли и пароли создаются в локальном 06_security.local.sql.
-- Этот файл не коммитится, см. 06_security.local.example.sql.
REVOKE ALL ON SCHEMA aml_task FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA aml_task FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA aml_task FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA aml_task FROM PUBLIC;

ALTER ROLE aml_admin SET search_path = aml_task, public;
ALTER ROLE aml_app SET search_path = aml_task, public;
ALTER ROLE aml_readonly SET search_path = aml_task, public;

ALTER DEFAULT PRIVILEGES IN SCHEMA aml_task REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA aml_task REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA aml_task REVOKE ALL ON FUNCTIONS FROM PUBLIC;

GRANT USAGE ON SCHEMA aml_task TO aml_admin, aml_app, aml_readonly;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA aml_task TO aml_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA aml_task TO aml_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA aml_task TO aml_admin;

GRANT SELECT ON ALL TABLES IN SCHEMA aml_task TO aml_readonly;
REVOKE SELECT ON aml_task.users FROM aml_readonly;
REVOKE SELECT ON aml_task.user_sessions FROM aml_readonly;
REVOKE SELECT ON aml_task.audit_log FROM aml_readonly;
GRANT SELECT (id, email, full_name, first_name, last_name, avatar_url, is_active, last_login_at, row_version, created_at, updated_at, deleted_at) ON aml_task.users TO aml_readonly;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA aml_task TO aml_readonly;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA aml_task TO aml_app;
GRANT EXECUTE ON FUNCTION aml_task.fn_get_current_user_id() TO aml_app, aml_readonly;

-- Дополнительные ограничения данных, которых не хватало в базовой DDL.
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_users_password_hash_not_blank') THEN
            ALTER TABLE aml_task.users
                ADD CONSTRAINT chk_users_password_hash_not_blank
                    CHECK (btrim(password_hash) <> '');
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_users_avatar_url_not_blank') THEN
            ALTER TABLE aml_task.users
                ADD CONSTRAINT chk_users_avatar_url_not_blank
                    CHECK (avatar_url IS NULL OR btrim(avatar_url) <> '');
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_user_sessions_refresh_token_hash_not_blank') THEN
            ALTER TABLE aml_task.user_sessions
                ADD CONSTRAINT chk_user_sessions_refresh_token_hash_not_blank
                    CHECK (btrim(refresh_token_hash) <> '');
        END IF;
    END;
$$;

CREATE OR REPLACE FUNCTION aml_task.fn_is_project_member(p_project_id uuid)
    RETURNS boolean
    LANGUAGE sql
    SECURITY DEFINER
    STABLE
    SET search_path = aml_task, public
AS $$
SELECT EXISTS (
    SELECT 1
    FROM aml_task.project_members pm
    WHERE pm.project_id = p_project_id
      AND pm.user_id = aml_task.fn_get_current_user_id()
      AND pm.is_active = true
      AND pm.left_at IS NULL
)
           OR EXISTS (
        SELECT 1
        FROM aml_task.projects p
        WHERE p.id = p_project_id
          AND p.owner_id = aml_task.fn_get_current_user_id()
          AND p.deleted_at IS NULL
    );
$$;

CREATE OR REPLACE FUNCTION aml_task.fn_is_project_admin(p_project_id uuid)
    RETURNS boolean
    LANGUAGE sql
    SECURITY DEFINER
    STABLE
    SET search_path = aml_task, public
AS $$
SELECT EXISTS (
    SELECT 1
    FROM aml_task.project_members pm
    WHERE pm.project_id = p_project_id
      AND pm.user_id = aml_task.fn_get_current_user_id()
      AND pm.role IN ('owner', 'admin')
      AND pm.is_active = true
      AND pm.left_at IS NULL
)
           OR EXISTS (
        SELECT 1
        FROM aml_task.projects p
        WHERE p.id = p_project_id
          AND p.owner_id = aml_task.fn_get_current_user_id()
          AND p.deleted_at IS NULL
    );
$$;

CREATE OR REPLACE FUNCTION aml_task.fn_can_access_issue(p_issue_id uuid)
    RETURNS boolean
    LANGUAGE sql
    SECURITY DEFINER
    STABLE
    SET search_path = aml_task, public
AS $$
SELECT EXISTS (
    SELECT 1
    FROM aml_task.issues i
    WHERE i.id = p_issue_id
      AND i.deleted_at IS NULL
      AND aml_task.fn_is_project_member(i.project_id)
);
$$;

ALTER FUNCTION aml_task.fn_set_user_full_name() SET search_path = aml_task, public;
ALTER FUNCTION aml_task.fn_set_updated_at() SET search_path = aml_task, public;
ALTER FUNCTION aml_task.fn_increment_row_version() SET search_path = aml_task, public;
ALTER FUNCTION aml_task.fn_get_current_user_id() SET search_path = aml_task, public;
ALTER FUNCTION aml_task.fn_build_record_pk(text, jsonb) SET search_path = aml_task, public;
ALTER FUNCTION aml_task.fn_audit_trigger() SET search_path = aml_task, public;

REVOKE ALL ON FUNCTION aml_task.fn_set_user_full_name() FROM PUBLIC;
REVOKE ALL ON FUNCTION aml_task.fn_set_updated_at() FROM PUBLIC;
REVOKE ALL ON FUNCTION aml_task.fn_increment_row_version() FROM PUBLIC;
REVOKE ALL ON FUNCTION aml_task.fn_build_record_pk(text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION aml_task.fn_audit_trigger() FROM PUBLIC;
REVOKE ALL ON FUNCTION aml_task.fn_is_project_member(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION aml_task.fn_is_project_admin(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION aml_task.fn_can_access_issue(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION aml_task.fn_is_project_member(uuid) TO aml_app, aml_readonly;
GRANT EXECUTE ON FUNCTION aml_task.fn_is_project_admin(uuid) TO aml_app, aml_readonly;
GRANT EXECUTE ON FUNCTION aml_task.fn_can_access_issue(uuid) TO aml_app, aml_readonly;

-- Представления для приложения: без password_hash, refresh_token_hash и удаленных записей.
CREATE OR REPLACE VIEW aml_task.v_users_public WITH (security_invoker = true) AS
SELECT
    id,
    email,
    full_name,
    first_name,
    last_name,
    avatar_url,
    is_active,
    created_at,
    updated_at
FROM aml_task.users
WHERE deleted_at IS NULL;

CREATE OR REPLACE VIEW aml_task.v_active_projects WITH (security_invoker = true) AS
SELECT
    p.id,
    p.name,
    p.project_key,
    p.description,
    p.owner_id,
    p.is_archived,
    p.created_at,
    p.updated_at
FROM aml_task.projects p
WHERE p.deleted_at IS NULL;

CREATE OR REPLACE VIEW aml_task.v_project_issues WITH (security_invoker = true) AS
SELECT
    i.id,
    i.project_id,
    p.project_key,
    i.issue_number,
    p.project_key || '-' || i.issue_number AS issue_code,
    i.type_id,
    it.name AS issue_type,
    i.status_id,
    s.name AS status,
    s.category AS status_category,
    i.sprint_id,
    i.parent_issue_id,
    i.title,
    i.description,
    i.reporter_id,
    i.assignee_id,
    i.priority,
    i.story_points,
    i.due_date,
    i.rank_position,
    i.original_estimate_minutes,
    i.remaining_estimate_minutes,
    i.created_at,
    i.updated_at
FROM aml_task.issues i
         JOIN aml_task.projects p ON p.id = i.project_id
         JOIN aml_task.issue_types it ON it.id = i.type_id
         JOIN aml_task.statuses s ON s.id = i.status_id
WHERE i.deleted_at IS NULL
  AND p.deleted_at IS NULL;

CREATE OR REPLACE VIEW aml_task.v_my_notifications WITH (security_invoker = true) AS
SELECT
    id,
    user_id,
    notification_type,
    title,
    payload,
    is_read,
    read_at,
    created_at
FROM aml_task.notifications
WHERE user_id = aml_task.fn_get_current_user_id();

CREATE OR REPLACE VIEW aml_task.v_active_sessions WITH (security_invoker = true) AS
SELECT
    id,
    user_id,
    device_info,
    ip_address,
    user_agent,
    is_revoked,
    expires_at,
    last_used_at,
    created_at,
    updated_at
FROM aml_task.user_sessions
WHERE is_revoked = false
  AND expires_at > now();

GRANT SELECT ON aml_task.v_users_public TO aml_app, aml_readonly;
GRANT SELECT ON aml_task.v_active_projects TO aml_app, aml_readonly;
GRANT SELECT ON aml_task.v_project_issues TO aml_app, aml_readonly;
GRANT SELECT ON aml_task.v_my_notifications TO aml_app;
GRANT SELECT ON aml_task.v_active_sessions TO aml_app;
GRANT ALL PRIVILEGES ON aml_task.v_users_public TO aml_admin;
GRANT ALL PRIVILEGES ON aml_task.v_active_projects TO aml_admin;
GRANT ALL PRIVILEGES ON aml_task.v_project_issues TO aml_admin;
GRANT ALL PRIVILEGES ON aml_task.v_my_notifications TO aml_admin;
GRANT ALL PRIVILEGES ON aml_task.v_active_sessions TO aml_admin;

-- Табличные права для приложения. Доступ к строкам ниже ограничивает RLS.
GRANT SELECT, INSERT, UPDATE ON aml_task.projects TO aml_app;
GRANT SELECT, INSERT, UPDATE ON aml_task.project_members TO aml_app;
GRANT SELECT, INSERT, UPDATE ON aml_task.project_invitations TO aml_app;
GRANT SELECT ON aml_task.issue_types TO aml_app;
GRANT SELECT, INSERT, UPDATE ON aml_task.statuses TO aml_app;
GRANT SELECT, INSERT, UPDATE ON aml_task.sprints TO aml_app;
GRANT SELECT, INSERT, UPDATE ON aml_task.issues TO aml_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON aml_task.issue_watchers TO aml_app;
GRANT SELECT, INSERT, UPDATE ON aml_task.issue_status_history TO aml_app;
GRANT SELECT, INSERT, UPDATE ON aml_task.issue_relations TO aml_app;
GRANT SELECT, INSERT, UPDATE ON aml_task.comments TO aml_app;
GRANT SELECT, INSERT, UPDATE ON aml_task.attachments TO aml_app;
GRANT SELECT, INSERT, UPDATE ON aml_task.time_logs TO aml_app;
GRANT SELECT, INSERT, UPDATE ON aml_task.notifications TO aml_app;
GRANT SELECT, INSERT ON aml_task.activity_log TO aml_app;
GRANT INSERT, UPDATE ON aml_task.user_sessions TO aml_app;
GRANT SELECT (id, user_id, device_info, ip_address, user_agent, is_revoked, revoked_at, expires_at, last_used_at, created_at, updated_at) ON aml_task.user_sessions TO aml_app;
GRANT SELECT (id, email, full_name, first_name, last_name, avatar_url, settings, is_active, last_login_at, row_version, created_at, updated_at, deleted_at) ON aml_task.users TO aml_app;
GRANT UPDATE (email, full_name, first_name, last_name, avatar_url, settings, last_login_at, updated_at) ON aml_task.users TO aml_app;

-- audit_log только читается администраторами/readonly; приложение не получает прямой доступ к нему.
REVOKE ALL ON aml_task.audit_log FROM aml_app;
GRANT SELECT ON aml_task.audit_log TO aml_admin;

ALTER TABLE aml_task.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.project_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.sprints ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.issue_watchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.issue_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.issue_relations ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.time_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE aml_task.audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pol_users_self_select ON aml_task.users;
DROP POLICY IF EXISTS pol_users_public_select ON aml_task.users;
CREATE POLICY pol_users_public_select ON aml_task.users
    FOR SELECT TO aml_app, aml_readonly
    USING (deleted_at IS NULL);

DROP POLICY IF EXISTS pol_users_self_update ON aml_task.users;
CREATE POLICY pol_users_self_update ON aml_task.users
    FOR UPDATE TO aml_app
    USING (id = aml_task.fn_get_current_user_id() AND deleted_at IS NULL)
    WITH CHECK (id = aml_task.fn_get_current_user_id());

DROP POLICY IF EXISTS pol_user_sessions_self ON aml_task.user_sessions;
CREATE POLICY pol_user_sessions_self ON aml_task.user_sessions
    FOR ALL TO aml_app
    USING (user_id = aml_task.fn_get_current_user_id())
    WITH CHECK (user_id = aml_task.fn_get_current_user_id());

DROP POLICY IF EXISTS pol_projects_member_select ON aml_task.projects;
CREATE POLICY pol_projects_member_select ON aml_task.projects
    FOR SELECT TO aml_app, aml_readonly
    USING (deleted_at IS NULL AND aml_task.fn_is_project_member(id));

DROP POLICY IF EXISTS pol_projects_owner_insert ON aml_task.projects;
CREATE POLICY pol_projects_owner_insert ON aml_task.projects
    FOR INSERT TO aml_app
    WITH CHECK (owner_id = aml_task.fn_get_current_user_id());

DROP POLICY IF EXISTS pol_projects_admin_update ON aml_task.projects;
CREATE POLICY pol_projects_admin_update ON aml_task.projects
    FOR UPDATE TO aml_app
    USING (aml_task.fn_is_project_admin(id))
    WITH CHECK (aml_task.fn_is_project_admin(id));

DROP POLICY IF EXISTS pol_project_members_select ON aml_task.project_members;
CREATE POLICY pol_project_members_select ON aml_task.project_members
    FOR SELECT TO aml_app, aml_readonly
    USING (aml_task.fn_is_project_member(project_id));

DROP POLICY IF EXISTS pol_project_members_admin_write ON aml_task.project_members;
CREATE POLICY pol_project_members_admin_write ON aml_task.project_members
    FOR ALL TO aml_app
    USING (aml_task.fn_is_project_admin(project_id))
    WITH CHECK (aml_task.fn_is_project_admin(project_id));

DROP POLICY IF EXISTS pol_project_invitations_project_admin ON aml_task.project_invitations;
CREATE POLICY pol_project_invitations_project_admin ON aml_task.project_invitations
    FOR ALL TO aml_app
    USING (aml_task.fn_is_project_admin(project_id))
    WITH CHECK (aml_task.fn_is_project_admin(project_id));

DROP POLICY IF EXISTS pol_statuses_project_member ON aml_task.statuses;
CREATE POLICY pol_statuses_project_member ON aml_task.statuses
    FOR SELECT TO aml_app, aml_readonly
    USING (aml_task.fn_is_project_member(project_id));

DROP POLICY IF EXISTS pol_statuses_project_admin ON aml_task.statuses;
CREATE POLICY pol_statuses_project_admin ON aml_task.statuses
    FOR ALL TO aml_app
    USING (aml_task.fn_is_project_admin(project_id))
    WITH CHECK (aml_task.fn_is_project_admin(project_id));

DROP POLICY IF EXISTS pol_sprints_project_member ON aml_task.sprints;
CREATE POLICY pol_sprints_project_member ON aml_task.sprints
    FOR SELECT TO aml_app, aml_readonly
    USING (aml_task.fn_is_project_member(project_id));

DROP POLICY IF EXISTS pol_sprints_project_admin ON aml_task.sprints;
CREATE POLICY pol_sprints_project_admin ON aml_task.sprints
    FOR ALL TO aml_app
    USING (aml_task.fn_is_project_admin(project_id))
    WITH CHECK (aml_task.fn_is_project_admin(project_id));

DROP POLICY IF EXISTS pol_issues_project_member ON aml_task.issues;
CREATE POLICY pol_issues_project_member ON aml_task.issues
    FOR SELECT TO aml_app, aml_readonly
    USING (deleted_at IS NULL AND aml_task.fn_is_project_member(project_id));

DROP POLICY IF EXISTS pol_issues_project_member_insert ON aml_task.issues;
CREATE POLICY pol_issues_project_member_insert ON aml_task.issues
    FOR INSERT TO aml_app
    WITH CHECK (aml_task.fn_is_project_member(project_id));

DROP POLICY IF EXISTS pol_issues_project_member_update ON aml_task.issues;
CREATE POLICY pol_issues_project_member_update ON aml_task.issues
    FOR UPDATE TO aml_app
    USING (aml_task.fn_is_project_member(project_id))
    WITH CHECK (aml_task.fn_is_project_member(project_id));

DROP POLICY IF EXISTS pol_issue_watchers_accessible_issue ON aml_task.issue_watchers;
CREATE POLICY pol_issue_watchers_accessible_issue ON aml_task.issue_watchers
    FOR ALL TO aml_app
    USING (aml_task.fn_can_access_issue(issue_id))
    WITH CHECK (aml_task.fn_can_access_issue(issue_id));

DROP POLICY IF EXISTS pol_issue_status_history_accessible_issue ON aml_task.issue_status_history;
CREATE POLICY pol_issue_status_history_accessible_issue ON aml_task.issue_status_history
    FOR ALL TO aml_app, aml_readonly
    USING (aml_task.fn_can_access_issue(issue_id))
    WITH CHECK (aml_task.fn_can_access_issue(issue_id));

DROP POLICY IF EXISTS pol_issue_relations_accessible_issue ON aml_task.issue_relations;
CREATE POLICY pol_issue_relations_accessible_issue ON aml_task.issue_relations
    FOR ALL TO aml_app, aml_readonly
    USING (aml_task.fn_can_access_issue(source_issue_id) AND aml_task.fn_can_access_issue(target_issue_id))
    WITH CHECK (aml_task.fn_can_access_issue(source_issue_id) AND aml_task.fn_can_access_issue(target_issue_id));

DROP POLICY IF EXISTS pol_comments_accessible_issue ON aml_task.comments;
CREATE POLICY pol_comments_accessible_issue ON aml_task.comments
    FOR SELECT TO aml_app, aml_readonly
    USING (deleted_at IS NULL AND aml_task.fn_can_access_issue(issue_id));

DROP POLICY IF EXISTS pol_comments_project_member_write ON aml_task.comments;
DROP POLICY IF EXISTS pol_comments_project_member_insert ON aml_task.comments;
CREATE POLICY pol_comments_project_member_insert ON aml_task.comments
    FOR INSERT TO aml_app
    WITH CHECK (aml_task.fn_can_access_issue(issue_id) AND author_id = aml_task.fn_get_current_user_id());

DROP POLICY IF EXISTS pol_comments_project_member_update ON aml_task.comments;
CREATE POLICY pol_comments_project_member_update ON aml_task.comments
    FOR UPDATE TO aml_app
    USING (aml_task.fn_can_access_issue(issue_id) AND author_id = aml_task.fn_get_current_user_id())
    WITH CHECK (aml_task.fn_can_access_issue(issue_id) AND author_id = aml_task.fn_get_current_user_id());

DROP POLICY IF EXISTS pol_attachments_accessible_issue ON aml_task.attachments;
CREATE POLICY pol_attachments_accessible_issue ON aml_task.attachments
    FOR SELECT TO aml_app, aml_readonly
    USING (aml_task.fn_can_access_issue(issue_id));

DROP POLICY IF EXISTS pol_attachments_project_member_write ON aml_task.attachments;
CREATE POLICY pol_attachments_project_member_write ON aml_task.attachments
    FOR ALL TO aml_app
    USING (aml_task.fn_can_access_issue(issue_id))
    WITH CHECK (aml_task.fn_can_access_issue(issue_id) AND uploaded_by = aml_task.fn_get_current_user_id());

DROP POLICY IF EXISTS pol_time_logs_accessible_issue ON aml_task.time_logs;
CREATE POLICY pol_time_logs_accessible_issue ON aml_task.time_logs
    FOR SELECT TO aml_app, aml_readonly
    USING (aml_task.fn_can_access_issue(issue_id));

DROP POLICY IF EXISTS pol_time_logs_self_write ON aml_task.time_logs;
CREATE POLICY pol_time_logs_self_write ON aml_task.time_logs
    FOR ALL TO aml_app
    USING (aml_task.fn_can_access_issue(issue_id) AND user_id = aml_task.fn_get_current_user_id())
    WITH CHECK (aml_task.fn_can_access_issue(issue_id) AND user_id = aml_task.fn_get_current_user_id());

DROP POLICY IF EXISTS pol_notifications_self ON aml_task.notifications;
CREATE POLICY pol_notifications_self ON aml_task.notifications
    FOR ALL TO aml_app
    USING (user_id = aml_task.fn_get_current_user_id())
    WITH CHECK (user_id = aml_task.fn_get_current_user_id());

DROP POLICY IF EXISTS pol_activity_log_project_member ON aml_task.activity_log;
CREATE POLICY pol_activity_log_project_member ON aml_task.activity_log
    FOR SELECT TO aml_app, aml_readonly
    USING (project_id IS NOT NULL AND aml_task.fn_is_project_member(project_id));

DROP POLICY IF EXISTS pol_activity_log_project_member_insert ON aml_task.activity_log;
CREATE POLICY pol_activity_log_project_member_insert ON aml_task.activity_log
    FOR INSERT TO aml_app
    WITH CHECK (actor_user_id = aml_task.fn_get_current_user_id());

DROP POLICY IF EXISTS pol_users_admin_all ON aml_task.users;
CREATE POLICY pol_users_admin_all ON aml_task.users
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_user_sessions_admin_all ON aml_task.user_sessions;
CREATE POLICY pol_user_sessions_admin_all ON aml_task.user_sessions
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_projects_admin_all ON aml_task.projects;
CREATE POLICY pol_projects_admin_all ON aml_task.projects
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_project_members_admin_all ON aml_task.project_members;
CREATE POLICY pol_project_members_admin_all ON aml_task.project_members
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_project_invitations_admin_all ON aml_task.project_invitations;
CREATE POLICY pol_project_invitations_admin_all ON aml_task.project_invitations
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_statuses_admin_all ON aml_task.statuses;
CREATE POLICY pol_statuses_admin_all ON aml_task.statuses
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_sprints_admin_all ON aml_task.sprints;
CREATE POLICY pol_sprints_admin_all ON aml_task.sprints
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_issues_admin_all ON aml_task.issues;
CREATE POLICY pol_issues_admin_all ON aml_task.issues
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_issue_watchers_admin_all ON aml_task.issue_watchers;
CREATE POLICY pol_issue_watchers_admin_all ON aml_task.issue_watchers
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_issue_status_history_admin_all ON aml_task.issue_status_history;
CREATE POLICY pol_issue_status_history_admin_all ON aml_task.issue_status_history
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_issue_relations_admin_all ON aml_task.issue_relations;
CREATE POLICY pol_issue_relations_admin_all ON aml_task.issue_relations
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_comments_admin_all ON aml_task.comments;
CREATE POLICY pol_comments_admin_all ON aml_task.comments
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_attachments_admin_all ON aml_task.attachments;
CREATE POLICY pol_attachments_admin_all ON aml_task.attachments
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_time_logs_admin_all ON aml_task.time_logs;
CREATE POLICY pol_time_logs_admin_all ON aml_task.time_logs
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_notifications_admin_all ON aml_task.notifications;
CREATE POLICY pol_notifications_admin_all ON aml_task.notifications
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_activity_log_admin_all ON aml_task.activity_log;
CREATE POLICY pol_activity_log_admin_all ON aml_task.activity_log
    FOR ALL TO aml_admin
    USING (true)
    WITH CHECK (true);
DROP POLICY IF EXISTS pol_audit_log_admin_read ON aml_task.audit_log;
CREATE POLICY pol_audit_log_admin_read ON aml_task.audit_log
    FOR SELECT TO aml_admin
    USING (true);


COMMIT;
