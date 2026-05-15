BEGIN;

SET search_path TO aml_task, public;



DROP TRIGGER IF EXISTS trg_users_audit ON aml_task.users;
DROP TRIGGER IF EXISTS trg_user_sessions_audit ON aml_task.user_sessions;
DROP TRIGGER IF EXISTS trg_projects_audit ON aml_task.projects;
DROP TRIGGER IF EXISTS trg_project_members_audit ON aml_task.project_members;
DROP TRIGGER IF EXISTS trg_project_invitations_audit ON aml_task.project_invitations;
DROP TRIGGER IF EXISTS trg_statuses_audit ON aml_task.statuses;
DROP TRIGGER IF EXISTS trg_sprints_audit ON aml_task.sprints;
DROP TRIGGER IF EXISTS trg_issues_audit ON aml_task.issues;
DROP TRIGGER IF EXISTS trg_issue_watchers_audit ON aml_task.issue_watchers;
DROP TRIGGER IF EXISTS trg_issue_status_history_audit ON aml_task.issue_status_history;
DROP TRIGGER IF EXISTS trg_issue_relations_audit ON aml_task.issue_relations;
DROP TRIGGER IF EXISTS trg_comments_audit ON aml_task.comments;
DROP TRIGGER IF EXISTS trg_attachments_audit ON aml_task.attachments;
DROP TRIGGER IF EXISTS trg_time_logs_audit ON aml_task.time_logs;
DROP TRIGGER IF EXISTS trg_notifications_audit ON aml_task.notifications;

-- Function is recreated with CREATE OR REPLACE below; do not drop it because triggers may depend on it.
-- Function is recreated with CREATE OR REPLACE below; do not drop it because other functions may depend on it.
-- Function is recreated with CREATE OR REPLACE below; do not drop it because RLS helper functions may depend on it.
-- Function is recreated with CREATE OR REPLACE below; do not drop it because row_version triggers depend on it.
-- Function is recreated with CREATE OR REPLACE below; do not drop it because updated_at triggers depend on it.

DROP TABLE IF EXISTS aml_task.audit_log CASCADE;

CREATE TABLE IF NOT EXISTS aml_task.audit_log (
                                                  id                  bigserial PRIMARY KEY,
                                                  table_name          varchar(100) NOT NULL,
                                                  operation           varchar(10) NOT NULL,
                                                  record_pk           jsonb,
                                                  old_data            jsonb,
                                                  new_data            jsonb,
                                                  changed_by          uuid,
                                                  changed_at          timestamptz NOT NULL DEFAULT now(),
                                                  transaction_id      bigint NOT NULL DEFAULT txid_current(),

                                                  CONSTRAINT fk_audit_log_changed_by
                                                      FOREIGN KEY (changed_by)
                                                          REFERENCES aml_task.users(id)
                                                          ON UPDATE RESTRICT
                                                          ON DELETE SET NULL,

                                                  CONSTRAINT chk_audit_log_operation
                                                      CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),

                                                  CONSTRAINT chk_audit_log_table_name_not_blank
                                                      CHECK (btrim(table_name) <> ''),

                                                  CONSTRAINT chk_audit_log_record_pk_is_object
                                                      CHECK (
                                                          record_pk IS NULL
                                                              OR jsonb_typeof(record_pk) = 'object'
                                                          )
);

CREATE INDEX IF NOT EXISTS ix_audit_log_table_name
    ON aml_task.audit_log(table_name);

CREATE INDEX IF NOT EXISTS ix_audit_log_record_pk
    ON aml_task.audit_log
        USING gin (record_pk);

CREATE INDEX IF NOT EXISTS ix_audit_log_changed_by
    ON aml_task.audit_log(changed_by);

CREATE INDEX IF NOT EXISTS ix_audit_log_changed_at
    ON aml_task.audit_log(changed_at);

CREATE INDEX IF NOT EXISTS ix_audit_log_transaction_id
    ON aml_task.audit_log(transaction_id);


-- ФУНКЦИИ

CREATE OR REPLACE FUNCTION aml_task.fn_set_updated_at()
    RETURNS trigger
    LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION aml_task.fn_increment_row_version()
    RETURNS trigger
    LANGUAGE plpgsql
AS $$
BEGIN
    NEW.row_version := OLD.row_version + 1;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION aml_task.fn_get_current_user_id()
    RETURNS uuid
    LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id text;
BEGIN
    v_user_id := current_setting('app.current_user_id', true);

    IF v_user_id IS NULL OR btrim(v_user_id) = '' THEN
        RETURN NULL;
    END IF;

    RETURN v_user_id::uuid;
EXCEPTION
    WHEN others THEN
        RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION aml_task.fn_build_record_pk(
    p_table_name text,
    p_row jsonb
)
    RETURNS jsonb
    LANGUAGE plpgsql
AS $$
BEGIN
    IF p_row IS NULL THEN
        RETURN NULL;
    END IF;

    IF p_row ? 'id' THEN
        RETURN jsonb_build_object('id', p_row -> 'id');
    END IF;

    IF p_table_name = 'issue_watchers' THEN
        RETURN jsonb_build_object(
                'issue_id', p_row -> 'issue_id',
                'user_id', p_row -> 'user_id'
               );
    ELSIF p_table_name = 'project_members' THEN
        RETURN jsonb_build_object(
                'project_id', p_row -> 'project_id',
                'user_id', p_row -> 'user_id'
               );
    ELSIF p_table_name = 'project_invitations' THEN
        RETURN jsonb_build_object(
                'project_id', p_row -> 'project_id',
                'email', p_row -> 'email'
               );
    ELSIF p_table_name = 'issue_status_history' THEN
        RETURN jsonb_build_object(
                'issue_id', p_row -> 'issue_id',
                'entered_at', p_row -> 'entered_at'
               );
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION aml_task.fn_audit_trigger()
    RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = aml_task, public
AS $$
DECLARE
    v_changed_by uuid;
    v_old_data jsonb;
    v_new_data jsonb;
    v_record_pk jsonb;
BEGIN
    v_changed_by := aml_task.fn_get_current_user_id();

    IF TG_OP = 'INSERT' THEN
        v_old_data := NULL;
        v_new_data := to_jsonb(NEW);
        v_record_pk := aml_task.fn_build_record_pk(TG_TABLE_NAME, v_new_data);

        IF TG_TABLE_NAME = 'users' THEN
            v_new_data := v_new_data - 'password_hash';
        ELSIF TG_TABLE_NAME = 'user_sessions' THEN
            v_new_data := v_new_data - 'refresh_token_hash';
        END IF;

        INSERT INTO aml_task.audit_log (
            table_name,
            operation,
            record_pk,
            old_data,
            new_data,
            changed_by,
            changed_at
        )
        VALUES (
                   TG_TABLE_NAME,
                   'INSERT',
                   v_record_pk,
                   v_old_data,
                   v_new_data,
                   v_changed_by,
                   now()
               );

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        v_old_data := to_jsonb(OLD);
        v_new_data := to_jsonb(NEW);
        v_record_pk := aml_task.fn_build_record_pk(TG_TABLE_NAME, v_new_data);

        IF TG_TABLE_NAME = 'users' THEN
            v_old_data := v_old_data - 'password_hash';
            v_new_data := v_new_data - 'password_hash';
        ELSIF TG_TABLE_NAME = 'user_sessions' THEN
            v_old_data := v_old_data - 'refresh_token_hash';
            v_new_data := v_new_data - 'refresh_token_hash';
        END IF;

        INSERT INTO aml_task.audit_log (
            table_name,
            operation,
            record_pk,
            old_data,
            new_data,
            changed_by,
            changed_at
        )
        VALUES (
                   TG_TABLE_NAME,
                   'UPDATE',
                   v_record_pk,
                   v_old_data,
                   v_new_data,
                   v_changed_by,
                   now()
               );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        v_old_data := to_jsonb(OLD);
        v_new_data := NULL;
        v_record_pk := aml_task.fn_build_record_pk(TG_TABLE_NAME, v_old_data);

        IF TG_TABLE_NAME = 'users' THEN
            v_old_data := v_old_data - 'password_hash';
        ELSIF TG_TABLE_NAME = 'user_sessions' THEN
            v_old_data := v_old_data - 'refresh_token_hash';
        END IF;

        INSERT INTO aml_task.audit_log (
            table_name,
            operation,
            record_pk,
            old_data,
            new_data,
            changed_by,
            changed_at
        )
        VALUES (
                   TG_TABLE_NAME,
                   'DELETE',
                   v_record_pk,
                   v_old_data,
                   v_new_data,
                   v_changed_by,
                   now()
               );

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;


-- ТРИГГЕРЫ updated_at

DROP TRIGGER IF EXISTS trg_users_set_updated_at ON aml_task.users;
CREATE TRIGGER trg_users_set_updated_at
    BEFORE UPDATE ON aml_task.users
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_user_sessions_set_updated_at ON aml_task.user_sessions;
CREATE TRIGGER trg_user_sessions_set_updated_at
    BEFORE UPDATE ON aml_task.user_sessions
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_projects_set_updated_at ON aml_task.projects;
CREATE TRIGGER trg_projects_set_updated_at
    BEFORE UPDATE ON aml_task.projects
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_statuses_set_updated_at ON aml_task.statuses;
CREATE TRIGGER trg_statuses_set_updated_at
    BEFORE UPDATE ON aml_task.statuses
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_sprints_set_updated_at ON aml_task.sprints;
CREATE TRIGGER trg_sprints_set_updated_at
    BEFORE UPDATE ON aml_task.sprints
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_issues_set_updated_at ON aml_task.issues;
CREATE TRIGGER trg_issues_set_updated_at
    BEFORE UPDATE ON aml_task.issues
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_comments_set_updated_at ON aml_task.comments;
CREATE TRIGGER trg_comments_set_updated_at
    BEFORE UPDATE ON aml_task.comments
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_set_updated_at();



-- ТРИГГЕРЫ row_version
DROP TRIGGER IF EXISTS trg_users_increment_row_version ON aml_task.users;
CREATE TRIGGER trg_users_increment_row_version
    BEFORE UPDATE ON aml_task.users
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_increment_row_version();

DROP TRIGGER IF EXISTS trg_projects_increment_row_version ON aml_task.projects;
CREATE TRIGGER trg_projects_increment_row_version
    BEFORE UPDATE ON aml_task.projects
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_increment_row_version();

DROP TRIGGER IF EXISTS trg_statuses_increment_row_version ON aml_task.statuses;
CREATE TRIGGER trg_statuses_increment_row_version
    BEFORE UPDATE ON aml_task.statuses
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_increment_row_version();

DROP TRIGGER IF EXISTS trg_sprints_increment_row_version ON aml_task.sprints;
CREATE TRIGGER trg_sprints_increment_row_version
    BEFORE UPDATE ON aml_task.sprints
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_increment_row_version();

DROP TRIGGER IF EXISTS trg_issues_increment_row_version ON aml_task.issues;
CREATE TRIGGER trg_issues_increment_row_version
    BEFORE UPDATE ON aml_task.issues
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_increment_row_version();

DROP TRIGGER IF EXISTS trg_comments_increment_row_version ON aml_task.comments;
CREATE TRIGGER trg_comments_increment_row_version
    BEFORE UPDATE ON aml_task.comments
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_increment_row_version();


-- ТРИГГЕРЫ AUDIT

CREATE TRIGGER trg_users_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.users
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();

CREATE TRIGGER trg_user_sessions_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.user_sessions
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();

CREATE TRIGGER trg_projects_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.projects
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();

CREATE TRIGGER trg_project_members_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.project_members
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();

CREATE TRIGGER trg_project_invitations_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.project_invitations
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();

CREATE TRIGGER trg_statuses_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.statuses
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();

CREATE TRIGGER trg_sprints_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.sprints
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();

CREATE TRIGGER trg_issues_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.issues
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();

CREATE TRIGGER trg_issue_watchers_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.issue_watchers
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();

CREATE TRIGGER trg_issue_status_history_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.issue_status_history
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();

CREATE TRIGGER trg_issue_relations_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.issue_relations
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();

CREATE TRIGGER trg_comments_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.comments
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();

CREATE TRIGGER trg_attachments_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.attachments
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();

CREATE TRIGGER trg_time_logs_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.time_logs
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();

CREATE TRIGGER trg_notifications_audit
    AFTER INSERT OR UPDATE OR DELETE ON aml_task.notifications
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_audit_trigger();



