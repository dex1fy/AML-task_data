-- INDEXES: USERS
CREATE INDEX IF NOT EXISTS ix_users_is_active
    ON aml_task.users(is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_users_deleted_at
    ON aml_task.users(deleted_at);


-- INDEXES: USER SESSIONS
CREATE INDEX IF NOT EXISTS ix_user_sessions_user_id
    ON aml_task.user_sessions(user_id);

CREATE INDEX IF NOT EXISTS ix_user_sessions_expires_at
    ON aml_task.user_sessions(expires_at);

CREATE INDEX IF NOT EXISTS ix_user_sessions_last_used_at
    ON aml_task.user_sessions(last_used_at);

CREATE INDEX IF NOT EXISTS ix_user_sessions_active
    ON aml_task.user_sessions(user_id, is_revoked, expires_at);

-- INDEXES: PROJECTS
CREATE INDEX IF NOT EXISTS ix_projects_owner_id
    ON aml_task.projects(owner_id);

CREATE INDEX IF NOT EXISTS ix_projects_is_archived
    ON aml_task.projects(is_archived)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_projects_deleted_at
    ON aml_task.projects(deleted_at);


-- INDEXES: PROJECT MEMBERS
CREATE INDEX IF NOT EXISTS ix_project_members_project_id
    ON aml_task.project_members(project_id);

CREATE INDEX IF NOT EXISTS ix_project_members_user_id
    ON aml_task.project_members(user_id);

CREATE INDEX IF NOT EXISTS ix_project_members_role
    ON aml_task.project_members(role);


-- INDEXES: PROJECT INVITATIONS
CREATE INDEX IF NOT EXISTS ix_project_invitations_project_id
    ON aml_task.project_invitations(project_id);

CREATE INDEX IF NOT EXISTS ix_project_invitations_email
    ON aml_task.project_invitations(email);

CREATE INDEX IF NOT EXISTS ix_project_invitations_status
    ON aml_task.project_invitations(status);

CREATE INDEX IF NOT EXISTS ix_project_invitations_expires_at
    ON aml_task.project_invitations(expires_at);


-- INDEXES: STATUSES
CREATE INDEX IF NOT EXISTS ix_statuses_project_id
    ON aml_task.statuses(project_id);

CREATE INDEX IF NOT EXISTS ix_statuses_project_category
    ON aml_task.statuses(project_id, category);


-- INDEXES: SPRINTS
CREATE INDEX IF NOT EXISTS ix_sprints_project_id
    ON aml_task.sprints(project_id);

CREATE INDEX IF NOT EXISTS ix_sprints_project_status
    ON aml_task.sprints(project_id, status);

CREATE INDEX IF NOT EXISTS ix_sprints_dates
    ON aml_task.sprints(project_id, start_date, end_date);


-- INDEXES: ISSUES
CREATE INDEX IF NOT EXISTS ix_issues_project_id
    ON aml_task.issues(project_id);

CREATE INDEX IF NOT EXISTS ix_issues_status_id
    ON aml_task.issues(status_id);

CREATE INDEX IF NOT EXISTS ix_issues_sprint_id
    ON aml_task.issues(sprint_id);

CREATE INDEX IF NOT EXISTS ix_issues_parent_issue_id
    ON aml_task.issues(parent_issue_id);

CREATE INDEX IF NOT EXISTS ix_issues_reporter_id
    ON aml_task.issues(reporter_id);

CREATE INDEX IF NOT EXISTS ix_issues_assignee_id
    ON aml_task.issues(assignee_id);

CREATE INDEX IF NOT EXISTS ix_issues_type_id
    ON aml_task.issues(type_id);

CREATE INDEX IF NOT EXISTS ix_issues_priority
    ON aml_task.issues(priority);

CREATE INDEX IF NOT EXISTS ix_issues_due_date
    ON aml_task.issues(due_date);

CREATE INDEX IF NOT EXISTS ix_issues_rank_position
    ON aml_task.issues(project_id, rank_position)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_issues_project_status_assignee
    ON aml_task.issues(project_id, status_id, assignee_id)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_issues_project_sprint_status
    ON aml_task.issues(project_id, sprint_id, status_id)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_issues_deleted_at
    ON aml_task.issues(deleted_at);

CREATE INDEX IF NOT EXISTS ix_issues_title_search
    ON aml_task.issues
        USING gin (
                   to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(description, ''))
            );


-- INDEXES: ISSUE WATCHERS
CREATE INDEX IF NOT EXISTS ix_issue_watchers_user_id
    ON aml_task.issue_watchers(user_id);

-- INDEXES: ISSUE STATUS HISTORY
CREATE INDEX IF NOT EXISTS ix_issue_status_history_issue_id
    ON aml_task.issue_status_history(issue_id);

CREATE INDEX IF NOT EXISTS ix_issue_status_history_to_status_id
    ON aml_task.issue_status_history(to_status_id);

CREATE INDEX IF NOT EXISTS ix_issue_status_history_changed_by
    ON aml_task.issue_status_history(changed_by);

CREATE INDEX IF NOT EXISTS ix_issue_status_history_entered_at
    ON aml_task.issue_status_history(entered_at);


-- INDEXES: ISSUE RELATIONS
CREATE INDEX IF NOT EXISTS ix_issue_relations_source_issue_id
    ON aml_task.issue_relations(source_issue_id);

CREATE INDEX IF NOT EXISTS ix_issue_relations_target_issue_id
    ON aml_task.issue_relations(target_issue_id);

CREATE INDEX IF NOT EXISTS ix_issue_relations_relation_type
    ON aml_task.issue_relations(relation_type);


-- INDEXES: COMMENTS
CREATE INDEX IF NOT EXISTS ix_comments_issue_id
    ON aml_task.comments(issue_id);

CREATE INDEX IF NOT EXISTS ix_comments_author_id
    ON aml_task.comments(author_id);

CREATE INDEX IF NOT EXISTS ix_comments_deleted_at
    ON aml_task.comments(deleted_at);


-- INDEXES: ATTACHMENTS
CREATE INDEX IF NOT EXISTS ix_attachments_issue_id
    ON aml_task.attachments(issue_id);

CREATE INDEX IF NOT EXISTS ix_attachments_uploaded_by
    ON aml_task.attachments(uploaded_by);


-- INDEXES: TIME LOGS
CREATE INDEX IF NOT EXISTS ix_time_logs_issue_id
    ON aml_task.time_logs(issue_id);

CREATE INDEX IF NOT EXISTS ix_time_logs_user_id
    ON aml_task.time_logs(user_id);

CREATE INDEX IF NOT EXISTS ix_time_logs_work_date
    ON aml_task.time_logs(work_date);


-- INDEXES: NOTIFICATIONS
CREATE INDEX IF NOT EXISTS ix_notifications_user_id
    ON aml_task.notifications(user_id);

CREATE INDEX IF NOT EXISTS ix_notifications_user_is_read
    ON aml_task.notifications(user_id, is_read);

CREATE INDEX IF NOT EXISTS ix_notifications_created_at
    ON aml_task.notifications(created_at);


-- INDEXES: ACTIVITY LOG
CREATE INDEX IF NOT EXISTS ix_activity_log_project_id
    ON aml_task.activity_log(project_id);

CREATE INDEX IF NOT EXISTS ix_activity_log_entity
    ON aml_task.activity_log(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS ix_activity_log_actor_user_id
    ON aml_task.activity_log(actor_user_id);

CREATE INDEX IF NOT EXISTS ix_activity_log_created_at
    ON aml_task.activity_log(created_at);


-- INDEXES: AUDIT LOG
CREATE INDEX IF NOT EXISTS ix_audit_log_table_record
    ON aml_task.audit_log(table_name);

CREATE INDEX IF NOT EXISTS ix_audit_log_changed_by
    ON aml_task.audit_log(changed_by);

CREATE INDEX IF NOT EXISTS ix_audit_log_changed_at
    ON aml_task.audit_log(changed_at);

CREATE INDEX IF NOT EXISTS ix_audit_log_transaction_id
    ON aml_task.audit_log(transaction_id);

COMMIT;
