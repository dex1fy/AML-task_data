BEGIN;

-- EXTENSIONS
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;


-- SCHEMA
CREATE SCHEMA IF NOT EXISTS aml_task;


-- При повторном запуске старые audit-триггеры могут сработать до пересоздания audit_log.
-- Снимаем их в самом начале, если соответствующие таблицы уже существуют.
DO $$
    BEGIN
        IF to_regclass('aml_task.users') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_users_audit ON aml_task.users;
        END IF;
        IF to_regclass('aml_task.user_sessions') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_user_sessions_audit ON aml_task.user_sessions;
        END IF;
        IF to_regclass('aml_task.projects') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_projects_audit ON aml_task.projects;
        END IF;
        IF to_regclass('aml_task.project_members') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_project_members_audit ON aml_task.project_members;
        END IF;
        IF to_regclass('aml_task.project_invitations') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_project_invitations_audit ON aml_task.project_invitations;
        END IF;
        IF to_regclass('aml_task.statuses') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_statuses_audit ON aml_task.statuses;
        END IF;
        IF to_regclass('aml_task.sprints') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_sprints_audit ON aml_task.sprints;
        END IF;
        IF to_regclass('aml_task.issues') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_issues_audit ON aml_task.issues;
        END IF;
        IF to_regclass('aml_task.issue_watchers') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_issue_watchers_audit ON aml_task.issue_watchers;
        END IF;
        IF to_regclass('aml_task.issue_status_history') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_issue_status_history_audit ON aml_task.issue_status_history;
        END IF;
        IF to_regclass('aml_task.issue_relations') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_issue_relations_audit ON aml_task.issue_relations;
        END IF;
        IF to_regclass('aml_task.comments') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_comments_audit ON aml_task.comments;
        END IF;
        IF to_regclass('aml_task.attachments') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_attachments_audit ON aml_task.attachments;
        END IF;
        IF to_regclass('aml_task.time_logs') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_time_logs_audit ON aml_task.time_logs;
        END IF;
        IF to_regclass('aml_task.notifications') IS NOT NULL THEN
            DROP TRIGGER IF EXISTS trg_notifications_audit ON aml_task.notifications;
        END IF;
    END;
$$;
-- USERS
CREATE TABLE IF NOT EXISTS aml_task.users (
                                              id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                              email               citext NOT NULL UNIQUE,
                                              password_hash       text NOT NULL,
                                              full_name           varchar(200) NOT NULL,
                                              avatar_url          text,
                                              settings            jsonb NOT NULL DEFAULT '{}'::jsonb,
                                              is_active           boolean NOT NULL DEFAULT true,
                                              last_login_at       timestamptz,
                                              row_version         bigint NOT NULL DEFAULT 1,
                                              created_at          timestamptz NOT NULL DEFAULT now(),
                                              updated_at          timestamptz NOT NULL DEFAULT now(),
                                              deleted_at          timestamptz,

                                              CONSTRAINT chk_users_email_not_blank
                                                  CHECK (btrim(email::text) <> ''),
                                              CONSTRAINT chk_users_full_name_not_blank
                                                  CHECK (btrim(full_name) <> ''),
                                              CONSTRAINT chk_users_settings_is_object
                                                  CHECK (jsonb_typeof(settings) = 'object'),
                                              CONSTRAINT chk_users_row_version_positive
                                                  CHECK (row_version > 0)
);

ALTER TABLE aml_task.users
    ADD COLUMN IF NOT EXISTS first_name varchar(100),
    ADD COLUMN IF NOT EXISTS last_name varchar(100);



CREATE OR REPLACE FUNCTION aml_task.fn_set_user_full_name()
    RETURNS trigger
    LANGUAGE plpgsql
AS $$
BEGIN
    IF NULLIF(btrim(COALESCE(NEW.first_name, '')), '') IS NOT NULL
        OR NULLIF(btrim(COALESCE(NEW.last_name, '')), '') IS NOT NULL THEN
        NEW.full_name := btrim(
                concat_ws(
                        ' ',
                        NULLIF(btrim(NEW.last_name), ''),
                        NULLIF(btrim(NEW.first_name), '')
                )
                         );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_set_full_name ON aml_task.users;

CREATE TRIGGER trg_users_set_full_name
    BEFORE INSERT OR UPDATE OF first_name, last_name
    ON aml_task.users
    FOR EACH ROW
EXECUTE FUNCTION aml_task.fn_set_user_full_name();

UPDATE aml_task.users
SET full_name = btrim(
        concat_ws(
                ' ',
                NULLIF(btrim(last_name), ''),
                NULLIF(btrim(first_name), '')
        )
                )
WHERE first_name IS NOT NULL
   OR last_name IS NOT NULL;

-- USER SESSIONS
-- JWT / refresh token sessions
CREATE TABLE IF NOT EXISTS aml_task.user_sessions (
                                                      id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                                      user_id             uuid NOT NULL,
                                                      refresh_token_hash  text NOT NULL,
                                                      device_info         text,
                                                      ip_address          inet,
                                                      user_agent          text,
                                                      is_revoked          boolean NOT NULL DEFAULT false,
                                                      revoked_at          timestamptz,
                                                      expires_at          timestamptz NOT NULL,
                                                      last_used_at        timestamptz,
                                                      created_at          timestamptz NOT NULL DEFAULT now(),
                                                      updated_at          timestamptz NOT NULL DEFAULT now(),

                                                      CONSTRAINT fk_user_sessions_user
                                                          FOREIGN KEY (user_id)
                                                              REFERENCES aml_task.users(id)
                                                              ON UPDATE RESTRICT
                                                              ON DELETE CASCADE,

                                                      CONSTRAINT uq_user_sessions_refresh_token_hash
                                                          UNIQUE (refresh_token_hash),

                                                      CONSTRAINT chk_user_sessions_expiry
                                                          CHECK (expires_at > created_at),

                                                      CONSTRAINT chk_user_sessions_revoked_state
                                                          CHECK (
                                                              (is_revoked = false AND revoked_at IS NULL)
                                                                  OR
                                                              (is_revoked = true AND revoked_at IS NOT NULL)
                                                              )
);


-- PROJECTS
CREATE TABLE IF NOT EXISTS aml_task.projects (
                                                 id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                                 name                varchar(200) NOT NULL,
                                                 project_key         varchar(20) NOT NULL,
                                                 description         text,
                                                 owner_id            uuid NOT NULL,
                                                 is_archived         boolean NOT NULL DEFAULT false,
                                                 row_version         bigint NOT NULL DEFAULT 1,
                                                 created_at          timestamptz NOT NULL DEFAULT now(),
                                                 updated_at          timestamptz NOT NULL DEFAULT now(),
                                                 deleted_at          timestamptz,

                                                 CONSTRAINT uq_projects_name UNIQUE (name),
                                                 CONSTRAINT uq_projects_project_key UNIQUE (project_key),

                                                 CONSTRAINT fk_projects_owner
                                                     FOREIGN KEY (owner_id)
                                                         REFERENCES aml_task.users(id)
                                                         ON UPDATE RESTRICT
                                                         ON DELETE RESTRICT,

                                                 CONSTRAINT chk_projects_name_not_blank
                                                     CHECK (btrim(name) <> ''),
                                                 CONSTRAINT chk_projects_key_format
                                                     CHECK (project_key ~ '^[A-Z][A-Z0-9_]{1,19}$'),
                                                 CONSTRAINT chk_projects_row_version_positive
                                                     CHECK (row_version > 0)
);

-- PROJECT MEMBERS
CREATE TABLE IF NOT EXISTS aml_task.project_members (
                                                        id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                                        project_id          uuid NOT NULL,
                                                        user_id             uuid NOT NULL,
                                                        role                varchar(20) NOT NULL,
                                                        is_active           boolean NOT NULL DEFAULT true,
                                                        joined_at           timestamptz NOT NULL DEFAULT now(),
                                                        left_at             timestamptz,
                                                        created_at          timestamptz NOT NULL DEFAULT now(),

                                                        CONSTRAINT fk_project_members_project
                                                            FOREIGN KEY (project_id)
                                                                REFERENCES aml_task.projects(id)
                                                                ON UPDATE RESTRICT
                                                                ON DELETE CASCADE,

                                                        CONSTRAINT fk_project_members_user
                                                            FOREIGN KEY (user_id)
                                                                REFERENCES aml_task.users(id)
                                                                ON UPDATE RESTRICT
                                                                ON DELETE CASCADE,

                                                        CONSTRAINT uq_project_members_project_user
                                                            UNIQUE (project_id, user_id),

                                                        CONSTRAINT chk_project_members_role
                                                            CHECK (role IN ('owner', 'admin', 'member', 'viewer')),

                                                        CONSTRAINT chk_project_members_left_after_join
                                                            CHECK (left_at IS NULL OR left_at >= joined_at)
);


-- PROJECT INVITATIONS
CREATE TABLE IF NOT EXISTS aml_task.project_invitations (
                                                            id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                                            project_id          uuid NOT NULL,
                                                            email               citext NOT NULL,
                                                            invited_by          uuid NOT NULL,
                                                            role                varchar(20) NOT NULL DEFAULT 'member',
                                                            token               uuid NOT NULL DEFAULT gen_random_uuid(),
                                                            status              varchar(20) NOT NULL DEFAULT 'pending',
                                                            expires_at          timestamptz NOT NULL,
                                                            accepted_at         timestamptz,
                                                            created_at          timestamptz NOT NULL DEFAULT now(),

                                                            CONSTRAINT fk_project_invitations_project
                                                                FOREIGN KEY (project_id)
                                                                    REFERENCES aml_task.projects(id)
                                                                    ON UPDATE RESTRICT
                                                                    ON DELETE CASCADE,

                                                            CONSTRAINT fk_project_invitations_invited_by
                                                                FOREIGN KEY (invited_by)
                                                                    REFERENCES aml_task.users(id)
                                                                    ON UPDATE RESTRICT
                                                                    ON DELETE RESTRICT,

                                                            CONSTRAINT uq_project_invitations_token
                                                                UNIQUE (token),

                                                            CONSTRAINT uq_project_invitations_project_email
                                                                UNIQUE (project_id, email),

                                                            CONSTRAINT chk_project_invitations_email_not_blank
                                                                CHECK (btrim(email::text) <> ''),

                                                            CONSTRAINT chk_project_invitations_role
                                                                CHECK (role IN ('admin', 'member', 'viewer')),

                                                            CONSTRAINT chk_project_invitations_status
                                                                CHECK (status IN ('pending', 'accepted', 'declined', 'expired', 'revoked')),

                                                            CONSTRAINT chk_project_invitations_expiry
                                                                CHECK (expires_at > created_at),

                                                            CONSTRAINT chk_project_invitations_accepted_at
                                                                CHECK (
                                                                    accepted_at IS NULL
                                                                        OR status = 'accepted'
                                                                    )
);


-- ISSUE TYPES
CREATE TABLE IF NOT EXISTS aml_task.issue_types (
                                                    id                  smallint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                                                    code                varchar(30) NOT NULL UNIQUE,
                                                    name                varchar(100) NOT NULL UNIQUE,
                                                    description         text,
                                                    icon                varchar(100),
                                                    is_subtask_allowed  boolean NOT NULL DEFAULT true,

                                                    CONSTRAINT chk_issue_types_code_format
                                                        CHECK (code ~ '^[a-z][a-z0-9_]{1,29}$'),
                                                    CONSTRAINT chk_issue_types_name_not_blank
                                                        CHECK (btrim(name) <> '')
);

-- STATUSES
CREATE TABLE IF NOT EXISTS aml_task.statuses (
                                                 id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                                 project_id          uuid NOT NULL,
                                                 name                varchar(100) NOT NULL,
                                                 category            varchar(20) NOT NULL,
                                                 position            integer NOT NULL,
                                                 color               varchar(20),
                                                 is_default          boolean NOT NULL DEFAULT false,
                                                 is_final            boolean NOT NULL DEFAULT false,
                                                 row_version         bigint NOT NULL DEFAULT 1,
                                                 created_at          timestamptz NOT NULL DEFAULT now(),
                                                 updated_at          timestamptz NOT NULL DEFAULT now(),

                                                 CONSTRAINT fk_statuses_project
                                                     FOREIGN KEY (project_id)
                                                         REFERENCES aml_task.projects(id)
                                                         ON UPDATE RESTRICT
                                                         ON DELETE CASCADE,

                                                 CONSTRAINT uq_statuses_project_name
                                                     UNIQUE (project_id, name),

                                                 CONSTRAINT uq_statuses_project_position
                                                     UNIQUE (project_id, position),

                                                 CONSTRAINT chk_statuses_category
                                                     CHECK (category IN ('todo', 'in_progress', 'done')),

                                                 CONSTRAINT chk_statuses_position_positive
                                                     CHECK (position > 0),

                                                 CONSTRAINT chk_statuses_row_version_positive
                                                     CHECK (row_version > 0)
);


-- SPRINTS
CREATE TABLE IF NOT EXISTS aml_task.sprints (
                                                id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                                project_id          uuid NOT NULL,
                                                name                varchar(150) NOT NULL,
                                                goal                text,
                                                status              varchar(20) NOT NULL DEFAULT 'planned',
                                                start_date          date,
                                                end_date            date,
                                                completed_at        timestamptz,
                                                row_version         bigint NOT NULL DEFAULT 1,
                                                created_at          timestamptz NOT NULL DEFAULT now(),
                                                updated_at          timestamptz NOT NULL DEFAULT now(),

                                                CONSTRAINT fk_sprints_project
                                                    FOREIGN KEY (project_id)
                                                        REFERENCES aml_task.projects(id)
                                                        ON UPDATE RESTRICT
                                                        ON DELETE CASCADE,

                                                CONSTRAINT uq_sprints_project_name
                                                    UNIQUE (project_id, name),

                                                CONSTRAINT chk_sprints_status
                                                    CHECK (status IN ('planned', 'active', 'completed', 'cancelled')),

                                                CONSTRAINT chk_sprints_dates
                                                    CHECK (
                                                        start_date IS NULL
                                                            OR end_date IS NULL
                                                            OR start_date <= end_date
                                                        ),

                                                CONSTRAINT chk_sprints_completed_at
                                                    CHECK (
                                                        completed_at IS NULL
                                                            OR status IN ('completed', 'cancelled')
                                                        ),

                                                CONSTRAINT chk_sprints_row_version_positive
                                                    CHECK (row_version > 0)
);


-- ISSUES
CREATE TABLE IF NOT EXISTS aml_task.issues (
                                               id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                               project_id                  uuid NOT NULL,
                                               issue_number                bigint NOT NULL,
                                               type_id                     smallint NOT NULL,
                                               status_id                   uuid NOT NULL,
                                               sprint_id                   uuid,
                                               parent_issue_id             uuid,
                                               title                       varchar(500) NOT NULL,
                                               description                 text,
                                               reporter_id                 uuid NOT NULL,
                                               assignee_id                 uuid,
                                               priority                    varchar(20) NOT NULL DEFAULT 'medium',
                                               story_points                numeric(5,2),
                                               due_date                    date,
                                               rank_position               numeric(20,10),
                                               original_estimate_minutes   integer,
                                               remaining_estimate_minutes  integer,
                                               row_version                 bigint NOT NULL DEFAULT 1,
                                               created_at                  timestamptz NOT NULL DEFAULT now(),
                                               updated_at                  timestamptz NOT NULL DEFAULT now(),
                                               deleted_at                  timestamptz,

                                               CONSTRAINT fk_issues_project
                                                   FOREIGN KEY (project_id)
                                                       REFERENCES aml_task.projects(id)
                                                       ON UPDATE RESTRICT
                                                       ON DELETE CASCADE,

                                               CONSTRAINT fk_issues_type
                                                   FOREIGN KEY (type_id)
                                                       REFERENCES aml_task.issue_types(id)
                                                       ON UPDATE RESTRICT
                                                       ON DELETE RESTRICT,

                                               CONSTRAINT fk_issues_status
                                                   FOREIGN KEY (status_id)
                                                       REFERENCES aml_task.statuses(id)
                                                       ON UPDATE RESTRICT
                                                       ON DELETE RESTRICT,

                                               CONSTRAINT fk_issues_sprint
                                                   FOREIGN KEY (sprint_id)
                                                       REFERENCES aml_task.sprints(id)
                                                       ON UPDATE RESTRICT
                                                       ON DELETE SET NULL,

                                               CONSTRAINT fk_issues_parent
                                                   FOREIGN KEY (parent_issue_id)
                                                       REFERENCES aml_task.issues(id)
                                                       ON UPDATE RESTRICT
                                                       ON DELETE RESTRICT,

                                               CONSTRAINT fk_issues_reporter
                                                   FOREIGN KEY (reporter_id)
                                                       REFERENCES aml_task.users(id)
                                                       ON UPDATE RESTRICT
                                                       ON DELETE RESTRICT,

                                               CONSTRAINT fk_issues_assignee
                                                   FOREIGN KEY (assignee_id)
                                                       REFERENCES aml_task.users(id)
                                                       ON UPDATE RESTRICT
                                                       ON DELETE SET NULL,

                                               CONSTRAINT uq_issues_project_issue_number
                                                   UNIQUE (project_id, issue_number),

                                               CONSTRAINT chk_issues_number_positive
                                                   CHECK (issue_number > 0),

                                               CONSTRAINT chk_issues_title_not_blank
                                                   CHECK (btrim(title) <> ''),

                                               CONSTRAINT chk_issues_priority
                                                   CHECK (priority IN ('lowest', 'low', 'medium', 'high', 'highest', 'critical')),

                                               CONSTRAINT chk_issues_story_points_nonnegative
                                                   CHECK (story_points IS NULL OR story_points >= 0),

                                               CONSTRAINT chk_issues_estimates_nonnegative
                                                   CHECK (
                                                       (original_estimate_minutes IS NULL OR original_estimate_minutes >= 0)
                                                           AND
                                                       (remaining_estimate_minutes IS NULL OR remaining_estimate_minutes >= 0)
                                                       ),

                                               CONSTRAINT chk_issues_parent_not_self
                                                   CHECK (parent_issue_id IS NULL OR parent_issue_id <> id),

                                               CONSTRAINT chk_issues_row_version_positive
                                                   CHECK (row_version > 0)
);

-- ISSUE WATCHERS
CREATE TABLE IF NOT EXISTS aml_task.issue_watchers (
                                                       issue_id             uuid NOT NULL,
                                                       user_id              uuid NOT NULL,
                                                       created_at           timestamptz NOT NULL DEFAULT now(),

                                                       CONSTRAINT pk_issue_watchers
                                                           PRIMARY KEY (issue_id, user_id),

                                                       CONSTRAINT fk_issue_watchers_issue
                                                           FOREIGN KEY (issue_id)
                                                               REFERENCES aml_task.issues(id)
                                                               ON UPDATE RESTRICT
                                                               ON DELETE CASCADE,

                                                       CONSTRAINT fk_issue_watchers_user
                                                           FOREIGN KEY (user_id)
                                                               REFERENCES aml_task.users(id)
                                                               ON UPDATE RESTRICT
                                                               ON DELETE CASCADE
);


-- ISSUE STATUS HISTORY
CREATE TABLE IF NOT EXISTS aml_task.issue_status_history (
                                                             id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                                             issue_id            uuid NOT NULL,
                                                             from_status_id      uuid,
                                                             to_status_id        uuid NOT NULL,
                                                             changed_by          uuid NOT NULL,
                                                             entered_at          timestamptz NOT NULL DEFAULT now(),
                                                             left_at             timestamptz,
                                                             comment             text,

                                                             CONSTRAINT fk_issue_status_history_issue
                                                                 FOREIGN KEY (issue_id)
                                                                     REFERENCES aml_task.issues(id)
                                                                     ON UPDATE RESTRICT
                                                                     ON DELETE CASCADE,

                                                             CONSTRAINT fk_issue_status_history_from_status
                                                                 FOREIGN KEY (from_status_id)
                                                                     REFERENCES aml_task.statuses(id)
                                                                     ON UPDATE RESTRICT
                                                                     ON DELETE RESTRICT,

                                                             CONSTRAINT fk_issue_status_history_to_status
                                                                 FOREIGN KEY (to_status_id)
                                                                     REFERENCES aml_task.statuses(id)
                                                                     ON UPDATE RESTRICT
                                                                     ON DELETE RESTRICT,

                                                             CONSTRAINT fk_issue_status_history_changed_by
                                                                 FOREIGN KEY (changed_by)
                                                                     REFERENCES aml_task.users(id)
                                                                     ON UPDATE RESTRICT
                                                                     ON DELETE RESTRICT,

                                                             CONSTRAINT chk_issue_status_history_range
                                                                 CHECK (left_at IS NULL OR left_at >= entered_at),

                                                             CONSTRAINT chk_issue_status_history_diff_status
                                                                 CHECK (from_status_id IS NULL OR from_status_id <> to_status_id)
);


-- ISSUE RELATIONS
CREATE TABLE IF NOT EXISTS aml_task.issue_relations (
                                                        id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                                        source_issue_id     uuid NOT NULL,
                                                        target_issue_id     uuid NOT NULL,
                                                        relation_type       varchar(30) NOT NULL,
                                                        created_by          uuid NOT NULL,
                                                        created_at          timestamptz NOT NULL DEFAULT now(),

                                                        CONSTRAINT fk_issue_relations_source
                                                            FOREIGN KEY (source_issue_id)
                                                                REFERENCES aml_task.issues(id)
                                                                ON UPDATE RESTRICT
                                                                ON DELETE CASCADE,

                                                        CONSTRAINT fk_issue_relations_target
                                                            FOREIGN KEY (target_issue_id)
                                                                REFERENCES aml_task.issues(id)
                                                                ON UPDATE RESTRICT
                                                                ON DELETE CASCADE,

                                                        CONSTRAINT fk_issue_relations_created_by
                                                            FOREIGN KEY (created_by)
                                                                REFERENCES aml_task.users(id)
                                                                ON UPDATE RESTRICT
                                                                ON DELETE RESTRICT,

                                                        CONSTRAINT uq_issue_relations_pair_type
                                                            UNIQUE (source_issue_id, target_issue_id, relation_type),

                                                        CONSTRAINT chk_issue_relations_no_self
                                                            CHECK (source_issue_id <> target_issue_id),

                                                        CONSTRAINT chk_issue_relations_type
                                                            CHECK (
                                                                relation_type IN (
                                                                                  'blocks',
                                                                                  'is_blocked_by',
                                                                                  'relates_to',
                                                                                  'duplicates',
                                                                                  'is_duplicated_by',
                                                                                  'depends_on',
                                                                                  'is_dependency_for',
                                                                                  'clones',
                                                                                  'is_cloned_by'
                                                                    )
                                                                )
);


-- COMMENTS
CREATE TABLE IF NOT EXISTS aml_task.comments (
                                                 id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                                 issue_id            uuid NOT NULL,
                                                 author_id           uuid NOT NULL,
                                                 content             text NOT NULL,
                                                 row_version         bigint NOT NULL DEFAULT 1,
                                                 created_at          timestamptz NOT NULL DEFAULT now(),
                                                 updated_at          timestamptz NOT NULL DEFAULT now(),
                                                 deleted_at          timestamptz,

                                                 CONSTRAINT fk_comments_issue
                                                     FOREIGN KEY (issue_id)
                                                         REFERENCES aml_task.issues(id)
                                                         ON UPDATE RESTRICT
                                                         ON DELETE CASCADE,

                                                 CONSTRAINT fk_comments_author
                                                     FOREIGN KEY (author_id)
                                                         REFERENCES aml_task.users(id)
                                                         ON UPDATE RESTRICT
                                                         ON DELETE RESTRICT,

                                                 CONSTRAINT chk_comments_content_not_blank
                                                     CHECK (btrim(content) <> ''),

                                                 CONSTRAINT chk_comments_row_version_positive
                                                     CHECK (row_version > 0)
);


-- ATTACHMENTS
CREATE TABLE IF NOT EXISTS aml_task.attachments (
                                                    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                                    issue_id            uuid NOT NULL,
                                                    uploaded_by         uuid NOT NULL,
                                                    file_name           varchar(255) NOT NULL,
                                                    file_url            text NOT NULL,
                                                    mime_type           varchar(150),
                                                    file_size_bytes     bigint NOT NULL,
                                                    checksum_sha256     char(64),
                                                    created_at          timestamptz NOT NULL DEFAULT now(),

                                                    CONSTRAINT fk_attachments_issue
                                                        FOREIGN KEY (issue_id)
                                                            REFERENCES aml_task.issues(id)
                                                            ON UPDATE RESTRICT
                                                            ON DELETE CASCADE,

                                                    CONSTRAINT fk_attachments_uploaded_by
                                                        FOREIGN KEY (uploaded_by)
                                                            REFERENCES aml_task.users(id)
                                                            ON UPDATE RESTRICT
                                                            ON DELETE RESTRICT,

                                                    CONSTRAINT chk_attachments_file_name_not_blank
                                                        CHECK (btrim(file_name) <> ''),

                                                    CONSTRAINT chk_attachments_file_url_not_blank
                                                        CHECK (btrim(file_url) <> ''),

                                                    CONSTRAINT chk_attachments_file_size_positive
                                                        CHECK (file_size_bytes > 0),

                                                    CONSTRAINT chk_attachments_checksum_format
                                                        CHECK (
                                                            checksum_sha256 IS NULL
                                                                OR checksum_sha256 ~ '^[0-9a-fA-F]{64}$'
                                                            )
);


-- TIME LOGS
CREATE TABLE IF NOT EXISTS aml_task.time_logs (
                                                  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                                  issue_id            uuid NOT NULL,
                                                  user_id             uuid NOT NULL,
                                                  work_date           date NOT NULL DEFAULT CURRENT_DATE,
                                                  time_spent_minutes  integer NOT NULL,
                                                  description         text,
                                                  created_at          timestamptz NOT NULL DEFAULT now(),

                                                  CONSTRAINT fk_time_logs_issue
                                                      FOREIGN KEY (issue_id)
                                                          REFERENCES aml_task.issues(id)
                                                          ON UPDATE RESTRICT
                                                          ON DELETE CASCADE,

                                                  CONSTRAINT fk_time_logs_user
                                                      FOREIGN KEY (user_id)
                                                          REFERENCES aml_task.users(id)
                                                          ON UPDATE RESTRICT
                                                          ON DELETE RESTRICT,

                                                  CONSTRAINT chk_time_logs_spent_positive
                                                      CHECK (time_spent_minutes > 0)
);


-- NOTIFICATIONS
CREATE TABLE IF NOT EXISTS aml_task.notifications (
                                                      id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                                      user_id             uuid NOT NULL,
                                                      notification_type   varchar(50) NOT NULL,
                                                      title               varchar(200) NOT NULL,
                                                      payload             jsonb NOT NULL DEFAULT '{}'::jsonb,
                                                      is_read             boolean NOT NULL DEFAULT false,
                                                      read_at             timestamptz,
                                                      created_at          timestamptz NOT NULL DEFAULT now(),

                                                      CONSTRAINT fk_notifications_user
                                                          FOREIGN KEY (user_id)
                                                              REFERENCES aml_task.users(id)
                                                              ON UPDATE RESTRICT
                                                              ON DELETE CASCADE,

                                                      CONSTRAINT chk_notifications_type_not_blank
                                                          CHECK (btrim(notification_type) <> ''),

                                                      CONSTRAINT chk_notifications_title_not_blank
                                                          CHECK (btrim(title) <> ''),

                                                      CONSTRAINT chk_notifications_payload_is_object
                                                          CHECK (jsonb_typeof(payload) = 'object'),

                                                      CONSTRAINT chk_notifications_read_state
                                                          CHECK (
                                                              (is_read = false AND read_at IS NULL)
                                                                  OR
                                                              (is_read = true)
                                                              )
);


-- ACTIVITY LOG
-- Бизнес-события
CREATE TABLE IF NOT EXISTS aml_task.activity_log (
                                                     id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                                     project_id          uuid,
                                                     entity_type         varchar(50) NOT NULL,
                                                     entity_id           uuid NOT NULL,
                                                     action              varchar(50) NOT NULL,
                                                     actor_user_id       uuid,
                                                     details             jsonb NOT NULL DEFAULT '{}'::jsonb,
                                                     created_at          timestamptz NOT NULL DEFAULT now(),

                                                     CONSTRAINT fk_activity_log_project
                                                         FOREIGN KEY (project_id)
                                                             REFERENCES aml_task.projects(id)
                                                             ON UPDATE RESTRICT
                                                             ON DELETE SET NULL,

                                                     CONSTRAINT fk_activity_log_actor
                                                         FOREIGN KEY (actor_user_id)
                                                             REFERENCES aml_task.users(id)
                                                             ON UPDATE RESTRICT
                                                             ON DELETE SET NULL,

                                                     CONSTRAINT chk_activity_log_entity_type_not_blank
                                                         CHECK (btrim(entity_type) <> ''),

                                                     CONSTRAINT chk_activity_log_action_not_blank
                                                         CHECK (btrim(action) <> ''),

                                                     CONSTRAINT chk_activity_log_details_is_object
                                                         CHECK (jsonb_typeof(details) = 'object')
);


-- AUDIT LOG
-- Технический аудит изменений
DROP TABLE IF EXISTS aml_task.audit_log CASCADE;
CREATE TABLE IF NOT EXISTS aml_task.audit_log (
                                                  id                  bigserial PRIMARY KEY,
                                                  table_name          varchar(100) NOT NULL,
                                                  record_pk           jsonb,
                                                  operation           varchar(10) NOT NULL,
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
                                                      CHECK (btrim(table_name) <> '')
);