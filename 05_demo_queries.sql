-- показывает основные данные по задачам внутри проекта
SELECT
    p.project_key || '-' || i.issue_number AS issue_code,
    i.title,
    it.name AS issue_type,
    s.name AS status,
    i.priority,
    u.full_name AS assignee,
    i.created_at,
    i.due_date
FROM aml_task.issues i
         JOIN aml_task.projects p ON p.id = i.project_id
         JOIN aml_task.issue_types it ON it.id = i.type_id
         JOIN aml_task.statuses s ON s.id = i.status_id
         LEFT JOIN aml_task.users u ON u.id = i.assignee_id
WHERE i.deleted_at IS NULL
  AND p.project_key = 'AMLTASK'
ORDER BY i.issue_number;

-- количество задач по статусам
SELECT
    s.name AS status,
    COUNT(i.id) AS task_count
FROM aml_task.statuses s
         LEFT JOIN aml_task.issues i
                   ON i.status_id = s.id
                       AND i.deleted_at IS NULL
WHERE s.project_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
GROUP BY s.name, s.position
ORDER BY s.position;

-- нагрузка на сотрудников
SELECT
    COALESCE(u.full_name, 'Не назначено') AS assignee,
    COUNT(i.id) AS task_count
FROM aml_task.issues i
         LEFT JOIN aml_task.users u ON u.id = i.assignee_id
WHERE i.deleted_at IS NULL
GROUP BY COALESCE(u.full_name, 'Не назначено')
ORDER BY task_count DESC, assignee;

--количество задач по приоритетам
SELECT
    i.priority,
    COUNT(*) AS task_count
FROM aml_task.issues i
WHERE i.deleted_at IS NULL
GROUP BY i.priority
ORDER BY task_count DESC;

-- просроченные задачи
SELECT
    p.project_key || '-' || i.issue_number AS issue_code,
    i.title,
    s.name AS status,
    u.full_name AS assignee,
    i.due_date,
    CURRENT_DATE - i.due_date AS days_overdue
FROM aml_task.issues i
         JOIN aml_task.projects p ON p.id = i.project_id
         JOIN aml_task.statuses s ON s.id = i.status_id
         LEFT JOIN aml_task.users u ON u.id = i.assignee_id
WHERE i.deleted_at IS NULL
  AND i.due_date IS NOT NULL
  AND i.due_date < CURRENT_DATE
  AND s.category <> 'done'
ORDER BY days_overdue DESC, i.due_date;

-- задачи активного спринта
SELECT
    sp.name AS sprint_name,
    p.project_key || '-' || i.issue_number AS issue_code,
    i.title,
    s.name AS status,
    i.priority,
    u.full_name AS assignee
FROM aml_task.issues i
         JOIN aml_task.sprints sp ON sp.id = i.sprint_id
         JOIN aml_task.projects p ON p.id = i.project_id
         JOIN aml_task.statuses s ON s.id = i.status_id
         LEFT JOIN aml_task.users u ON u.id = i.assignee_id
WHERE i.deleted_at IS NULL
  AND sp.status = 'active'
ORDER BY s.position, i.priority;

-- задачи по спринтам
SELECT
    sp.name AS sprint_name,
    COUNT(i.id) AS task_count
FROM aml_task.sprints sp
         LEFT JOIN aml_task.issues i
                   ON i.sprint_id = sp.id
                       AND i.deleted_at IS NULL
GROUP BY sp.name, sp.start_date
ORDER BY sp.start_date NULLS LAST, sp.name;

-- затраченное время на задачи
SELECT
    p.project_key || '-' || i.issue_number AS issue_code,
    i.title,
    COALESCE(SUM(tl.time_spent_minutes), 0) AS total_minutes,
    ROUND(COALESCE(SUM(tl.time_spent_minutes), 0) / 60.0, 2) AS total_hours
FROM aml_task.issues i
         JOIN aml_task.projects p ON p.id = i.project_id
         LEFT JOIN aml_task.time_logs tl ON tl.issue_id = i.id
WHERE i.deleted_at IS NULL
GROUP BY p.project_key, i.issue_number, i.title
ORDER BY total_minutes DESC, issue_code;

-- время, которые потратил пользователь
SELECT
    u.full_name,
    COALESCE(SUM(tl.time_spent_minutes), 0) AS total_minutes,
    ROUND(COALESCE(SUM(tl.time_spent_minutes), 0) / 60.0, 2) AS total_hours
FROM aml_task.users u
         LEFT JOIN aml_task.time_logs tl ON tl.user_id = u.id
WHERE u.deleted_at IS NULL
GROUP BY u.full_name
ORDER BY total_minutes DESC, u.full_name;


-- история смены статусов по задаче
SELECT
    p.project_key || '-' || i.issue_number AS issue_code,
    fs.name AS from_status,
    ts.name AS to_status,
    u.full_name AS changed_by,
    ish.entered_at,
    ish.left_at,
    ish.comment
FROM aml_task.issue_status_history ish
         JOIN aml_task.issues i ON i.id = ish.issue_id
         JOIN aml_task.projects p ON p.id = i.project_id
         LEFT JOIN aml_task.statuses fs ON fs.id = ish.from_status_id
         JOIN aml_task.statuses ts ON ts.id = ish.to_status_id
         JOIN aml_task.users u ON u.id = ish.changed_by
WHERE p.project_key = 'AMLTASK'
  AND i.issue_number = 1
ORDER BY ish.entered_at;

-- аудит одной задачи
SELECT
    al.id,
    al.operation,
    al.record_pk,
    al.changed_by,
    u.full_name AS changed_by_name,
    al.changed_at,
    al.old_data,
    al.new_data
FROM aml_task.audit_log al
         LEFT JOIN aml_task.users u ON u.id = al.changed_by
WHERE al.table_name = 'issues'
  AND al.record_pk @> '{"id": "dddddddd-dddd-dddd-dddd-dddddddddd01"}'::jsonb
ORDER BY al.changed_at DESC;

-- последние действия в системе
SELECT
    al.entity_type,
    al.action,
    u.full_name AS actor,
    al.created_at,
    al.details
FROM aml_task.activity_log al
         LEFT JOIN aml_task.users u ON u.id = al.actor_user_id
ORDER BY al.created_at DESC
LIMIT 20;

-- активные сессии пользователя
SELECT
    u.full_name,
    us.device_info,
    us.ip_address,
    us.user_agent,
    us.last_used_at,
    us.expires_at
FROM aml_task.user_sessions us
         JOIN aml_task.users u ON u.id = us.user_id
WHERE us.is_revoked = false
  AND us.expires_at > now()
ORDER BY us.last_used_at DESC NULLS LAST;

-- количество активных сессий по пользователям
SELECT
    u.full_name,
    COUNT(us.id) AS active_sessions
FROM aml_task.users u
         LEFT JOIN aml_task.user_sessions us
                   ON us.user_id = u.id
                       AND us.is_revoked = false
                       AND us.expires_at > now()
GROUP BY u.full_name
ORDER BY active_sessions DESC, u.full_name;

-- непрочитанные уведомления пользователя
SELECT
    u.full_name,
    COUNT(n.id) AS unread_notifications
FROM aml_task.users u
         LEFT JOIN aml_task.notifications n
                   ON n.user_id = u.id
                       AND n.is_read = false
GROUP BY u.full_name
ORDER BY unread_notifications DESC, u.full_name;

-- подзадачи и их родительские задачи
SELECT
    p.project_key || '-' || parent.issue_number AS parent_issue_code,
    parent.title AS parent_title,
    p.project_key || '-' || child.issue_number AS child_issue_code,
    child.title AS child_title
FROM aml_task.issues child
         JOIN aml_task.issues parent ON parent.id = child.parent_issue_id
         JOIN aml_task.projects p ON p.id = child.project_id
WHERE child.deleted_at IS NULL
ORDER BY parent.issue_number, child.issue_number;

-- количество комментариев по задачам
SELECT
    p.project_key || '-' || i.issue_number AS issue_code,
    i.title,
    COUNT(c.id) AS comments_count
FROM aml_task.issues i
         JOIN aml_task.projects p ON p.id = i.project_id
         LEFT JOIN aml_task.comments c
                   ON c.issue_id = i.id
                       AND c.deleted_at IS NULL
WHERE i.deleted_at IS NULL
GROUP BY p.project_key, i.issue_number, i.title
ORDER BY comments_count DESC, issue_code;
