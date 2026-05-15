INSERT INTO aml_task.issue_types (code, name, description, icon, is_subtask_allowed)
VALUES
    ('task', 'Task', 'Стандартная рабочая задача', 'task', true),
    ('bug', 'Bug', 'Ошибка или дефект системы', 'bug_report', false),
    ('story', 'Story', 'Пользовательская история', 'menu_book', true),
    ('epic', 'Epic', 'Крупная бизнес-инициатива', 'bolt', true),
    ('subtask', 'Subtask', 'Подзадача', 'subdirectory_arrow_right', false)
ON CONFLICT (code) DO NOTHING;

INSERT INTO aml_task.users (
    id,
    email,
    password_hash,
    first_name,
    last_name,
    avatar_url,
    settings,
    is_active
)
VALUES
    (
        '11111111-1111-1111-1111-111111111111',
        'admin@aml-task.local',
        '$2b$12$demo_admin_hash',
        'Иван',
        'Петров',
        NULL,
        '{
          "theme": "dark",
          "language": "ru",
          "timezone": "Europe/Amsterdam",
          "notifications": {
            "email": true,
            "push": true
          }
        }'::jsonb,
        true
    ),
    (
        '22222222-2222-2222-2222-222222222222',
        'manager@aml-task.local',
        '$2b$12$demo_manager_hash',
        'Анна',
        'Смирнова',
        NULL,
        '{
          "theme": "light",
          "language": "ru",
          "timezone": "Europe/Amsterdam",
          "notifications": {
            "email": true,
            "push": false
          }
        }'::jsonb,
        true
    ),
    (
        '33333333-3333-3333-3333-333333333333',
        'employee@aml-task.local',
        '$2b$12$demo_employee_hash',
        'Дмитрий',
        'Кузнецов',
        NULL,
        '{
          "theme": "dark",
          "language": "ru",
          "timezone": "Europe/Amsterdam",
          "notifications": {
            "email": false,
            "push": true
          }
        }'::jsonb,
        true
    )
ON CONFLICT (email) DO NOTHING;

SELECT set_config('app.current_user_id', '11111111-1111-1111-1111-111111111111', false);

INSERT INTO aml_task.projects (
    id,
    name,
    project_key,
    description,
    owner_id,
    is_archived
)
VALUES
    (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'AML Task',
        'AMLTASK',
        'Система управления задачами предприятия с поддержкой аудита, версионирования и аналитики.',
        '11111111-1111-1111-1111-111111111111',
        false
    )
ON CONFLICT (project_key) DO NOTHING;

INSERT INTO aml_task.project_members (
    id,
    project_id,
    user_id,
    role,
    is_active
)
VALUES
    (
        gen_random_uuid(),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '11111111-1111-1111-1111-111111111111',
        'owner',
        true
    ),
    (
        gen_random_uuid(),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '22222222-2222-2222-2222-222222222222',
        'admin',
        true
    ),
    (
        gen_random_uuid(),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '33333333-3333-3333-3333-333333333333',
        'member',
        true
    )
ON CONFLICT (project_id, user_id) DO NOTHING;

INSERT INTO aml_task.statuses (
    id,
    project_id,
    name,
    category,
    position,
    color,
    is_default,
    is_final
)
VALUES
    (
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb001',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'To Do',
        'todo',
        1,
        'gray',
        true,
        false
    ),
    (
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb002',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'In Progress',
        'in_progress',
        2,
        'blue',
        false,
        false
    ),
    (
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb003',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'Code Review',
        'in_progress',
        3,
        'purple',
        false,
        false
    ),
    (
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb004',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'Done',
        'done',
        4,
        'green',
        false,
        true
    )
ON CONFLICT (project_id, name) DO NOTHING;

INSERT INTO aml_task.sprints (
    id,
    project_id,
    name,
    goal,
    status,
    start_date,
    end_date
)
VALUES
    (
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'Sprint 1',
        'Реализовать базовую модель данных и механизм аудита.',
        'active',
        CURRENT_DATE,
        CURRENT_DATE + 14
    )
ON CONFLICT (project_id, name) DO NOTHING;

INSERT INTO aml_task.issues (
    id,
    project_id,
    issue_number,
    type_id,
    status_id,
    sprint_id,
    parent_issue_id,
    title,
    description,
    reporter_id,
    assignee_id,
    priority,
    story_points,
    due_date,
    rank_position,
    original_estimate_minutes,
    remaining_estimate_minutes
)
VALUES
    (
        'dddddddd-dddd-dddd-dddd-dddddddddd01',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        1,
        (SELECT id FROM aml_task.issue_types WHERE code = 'epic'),
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb002',
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        NULL,
        'Проектирование базы данных AML Task',
        'Создать логическую и физическую модель данных, включающую пользователей, проекты, задачи, аудит и сессии.',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        'highest',
        13,
        CURRENT_DATE + 7,
        1000,
        960,
        480
    ),
    (
        'dddddddd-dddd-dddd-dddd-dddddddddd02',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        2,
        (SELECT id FROM aml_task.issue_types WHERE code = 'task'),
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb001',
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'dddddddd-dddd-dddd-dddd-dddddddddd01',
        'Создать таблицу user_sessions',
        'Добавить хранение refresh token hash, срока действия сессии и признака отзыва.',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        'high',
        5,
        CURRENT_DATE + 3,
        2000,
        240,
        240
    ),
    (
        'dddddddd-dddd-dddd-dddd-dddddddddd03',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        3,
        (SELECT id FROM aml_task.issue_types WHERE code = 'bug'),
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb003',
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        NULL,
        'Исправить конфликт схемы при создании внешних ключей',
        'Проверить порядок создания таблиц и явное указание схемы aml_task в ссылках.',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        'critical',
        3,
        CURRENT_DATE + 1,
        3000,
        120,
        60
    )
ON CONFLICT (project_id, issue_number) DO NOTHING;

DELETE FROM aml_task.issue_status_history
WHERE issue_id IN (
                   'dddddddd-dddd-dddd-dddd-dddddddddd01',
                   'dddddddd-dddd-dddd-dddd-dddddddddd02',
                   'dddddddd-dddd-dddd-dddd-dddddddddd03'
    );

INSERT INTO aml_task.issue_status_history (
    id,
    issue_id,
    from_status_id,
    to_status_id,
    changed_by,
    entered_at,
    comment
)
VALUES
    (
        gen_random_uuid(),
        'dddddddd-dddd-dddd-dddd-dddddddddd01',
        NULL,
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb002',
        '22222222-2222-2222-2222-222222222222',
        now(),
        'Задача сразу переведена в работу.'
    ),
    (
        gen_random_uuid(),
        'dddddddd-dddd-dddd-dddd-dddddddddd02',
        NULL,
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb001',
        '22222222-2222-2222-2222-222222222222',
        now(),
        'Новая задача в бэклоге.'
    ),
    (
        gen_random_uuid(),
        'dddddddd-dddd-dddd-dddd-dddddddddd03',
        NULL,
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb003',
        '11111111-1111-1111-1111-111111111111',
        now(),
        'Ошибка уже находится на проверке.'
    );

INSERT INTO aml_task.issue_watchers (
    issue_id,
    user_id
)
VALUES
    ('dddddddd-dddd-dddd-dddd-dddddddddd01', '11111111-1111-1111-1111-111111111111'),
    ('dddddddd-dddd-dddd-dddd-dddddddddd01', '22222222-2222-2222-2222-222222222222'),
    ('dddddddd-dddd-dddd-dddd-dddddddddd02', '22222222-2222-2222-2222-222222222222')
ON CONFLICT (issue_id, user_id) DO NOTHING;

DELETE FROM aml_task.comments
WHERE (issue_id, author_id, content) IN (
                                         ('dddddddd-dddd-dddd-dddd-dddddddddd01', '22222222-2222-2222-2222-222222222222', 'Нужно подготовить SQL-скрипт так, чтобы его можно было запускать целиком с нуля.'),
                                         ('dddddddd-dddd-dddd-dddd-dddddddddd02', '33333333-3333-3333-3333-333333333333', 'Таблица user_sessions будет использоваться для хранения refresh token hash.')
    );

INSERT INTO aml_task.comments (
    id,
    issue_id,
    author_id,
    content
)
VALUES
    (
        gen_random_uuid(),
        'dddddddd-dddd-dddd-dddd-dddddddddd01',
        '22222222-2222-2222-2222-222222222222',
        'Нужно подготовить SQL-скрипт так, чтобы его можно было запускать целиком с нуля.'
    ),
    (
        gen_random_uuid(),
        'dddddddd-dddd-dddd-dddd-dddddddddd02',
        '33333333-3333-3333-3333-333333333333',
        'Таблица user_sessions будет использоваться для хранения refresh token hash.'
    );

DELETE FROM aml_task.notifications
WHERE (user_id, notification_type, title) IN (
                                              ('33333333-3333-3333-3333-333333333333', 'task_assigned', 'Вам назначена задача AMLTASK-2'),
                                              ('22222222-2222-2222-2222-222222222222', 'comment_added', 'Добавлен комментарий к задаче AMLTASK-1')
    );

INSERT INTO aml_task.notifications (
    id,
    user_id,
    notification_type,
    title,
    payload,
    is_read
)
VALUES
    (
        gen_random_uuid(),
        '33333333-3333-3333-3333-333333333333',
        'task_assigned',
        'Вам назначена задача AMLTASK-2',
        '{
          "issue_id": "dddddddd-dddd-dddd-dddd-dddddddddd02",
          "project_key": "AMLTASK",
          "issue_number": 2
        }'::jsonb,
        false
    ),
    (
        gen_random_uuid(),
        '22222222-2222-2222-2222-222222222222',
        'comment_added',
        'Добавлен комментарий к задаче AMLTASK-1',
        '{
          "issue_id": "dddddddd-dddd-dddd-dddd-dddddddddd01",
          "project_key": "AMLTASK",
          "issue_number": 1
        }'::jsonb,
        false
    );

INSERT INTO aml_task.user_sessions (
    id,
    user_id,
    refresh_token_hash,
    device_info,
    ip_address,
    user_agent,
    is_revoked,
    expires_at,
    last_used_at
)
VALUES
    (
        gen_random_uuid(),
        '11111111-1111-1111-1111-111111111111',
        'demo_refresh_hash_admin_001',
        'Windows 11 / Chrome',
        '192.168.1.10',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/123.0',
        false,
        now() + interval '30 days',
        now()
    ),
    (
        gen_random_uuid(),
        '33333333-3333-3333-3333-333333333333',
        'demo_refresh_hash_employee_001',
        'Android / Mobile App',
        '192.168.1.20',
        'AMLTaskMobile/1.0 Android',
        false,
        now() + interval '30 days',
        now()
    )
ON CONFLICT (refresh_token_hash) DO NOTHING;

DELETE FROM aml_task.activity_log
WHERE project_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  AND (entity_type, entity_id, action) IN (
                                           ('project', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'project_created'),
                                           ('issue', 'dddddddd-dddd-dddd-dddd-dddddddddd01', 'issue_created'),
                                           ('issue', 'dddddddd-dddd-dddd-dddd-dddddddddd03', 'status_changed')
    );

INSERT INTO aml_task.activity_log (
    id,
    project_id,
    entity_type,
    entity_id,
    action,
    actor_user_id,
    details
)
VALUES
    (
        gen_random_uuid(),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'project',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'project_created',
        '11111111-1111-1111-1111-111111111111',
        '{"name": "AML Task"}'::jsonb
    ),
    (
        gen_random_uuid(),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'issue',
        'dddddddd-dddd-dddd-dddd-dddddddddd01',
        'issue_created',
        '22222222-2222-2222-2222-222222222222',
        '{"issue_number": 1, "title": "Проектирование базы данных AML Task"}'::jsonb
    ),
    (
        gen_random_uuid(),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'issue',
        'dddddddd-dddd-dddd-dddd-dddddddddd03',
        'status_changed',
        '11111111-1111-1111-1111-111111111111',
        '{"from": null, "to": "Code Review"}'::jsonb
    );

COMMIT;

INSERT INTO aml_task.issues (
    id,
    project_id,
    issue_number,
    type_id,
    status_id,
    sprint_id,
    parent_issue_id,
    title,
    description,
    reporter_id,
    assignee_id,
    priority,
    story_points,
    due_date,
    rank_position,
    original_estimate_minutes,
    remaining_estimate_minutes
)
VALUES
    (
        gen_random_uuid(),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        4,
        (SELECT id FROM aml_task.issue_types WHERE code = 'task'),
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb001', -- To Do
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        NULL,
        'Подготовить отчёт по просроченным задачам',
        'Нужно сформировать аналитический отчёт по всем просроченным задачам проекта.',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        'high',
        3,
        CURRENT_DATE - 10,
        4000,
        180,
        120
    ),
    (
        gen_random_uuid(),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        5,
        (SELECT id FROM aml_task.issue_types WHERE code = 'bug'),
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb002', -- In Progress
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        NULL,
        'Исправить ошибку авторизации по refresh token',
        'При обновлении токена возникает ошибка проверки сессии.',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        'critical',
        5,
        CURRENT_DATE - 5,
        5000,
        240,
        90
    ),
    (
        gen_random_uuid(),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        6,
        (SELECT id FROM aml_task.issue_types WHERE code = 'story'),
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb003', -- Code Review, category = in_progress
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        NULL,
        'Реализовать экран аналитики задач',
        'Нужно подготовить экран с визуализацией просроченных и активных задач.',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        'medium',
        8,
        CURRENT_DATE - 2,
        6000,
        480,
        240
    )
ON CONFLICT (project_id, issue_number) DO NOTHING;

DELETE FROM aml_task.time_logs
WHERE user_id IN (
                  '22222222-2222-2222-2222-222222222222',
                  '33333333-3333-3333-3333-333333333333'
    )
  AND issue_id IN (
                   'dddddddd-dddd-dddd-dddd-dddddddddd01',
                   'dddddddd-dddd-dddd-dddd-dddddddddd02',
                   'dddddddd-dddd-dddd-dddd-dddddddddd03',
                   (SELECT id FROM aml_task.issues WHERE issue_number = 4 LIMIT 1),
                   (SELECT id FROM aml_task.issues WHERE issue_number = 5 LIMIT 1),
                   (SELECT id FROM aml_task.issues WHERE issue_number = 6 LIMIT 1)
    );

INSERT INTO aml_task.time_logs (
    id,
    issue_id,
    user_id,
    time_spent_minutes,
    work_date,
    created_at
)
VALUES
    -- Задача 1 (эпик)
    (
        gen_random_uuid(),
        'dddddddd-dddd-dddd-dddd-dddddddddd01',
        '33333333-3333-3333-3333-333333333333',
        120,
        CURRENT_DATE - 10,
        now()
    ),
    (
        gen_random_uuid(),
        'dddddddd-dddd-dddd-dddd-dddddddddd01',
        '22222222-2222-2222-2222-222222222222',
        180,
        CURRENT_DATE - 9,
        now()
    ),

    -- Задача 2 (task)
    (
        gen_random_uuid(),
        'dddddddd-dddd-dddd-dddd-dddddddddd02',
        '33333333-3333-3333-3333-333333333333',
        60,
        CURRENT_DATE - 5,
        now()
    ),
    (
        gen_random_uuid(),
        'dddddddd-dddd-dddd-dddd-dddddddddd02',
        '33333333-3333-3333-3333-333333333333',
        90,
        CURRENT_DATE - 4,
        now()
    ),

    -- Задача 3 (bug)
    (
        gen_random_uuid(),
        'dddddddd-dddd-dddd-dddd-dddddddddd03',
        '22222222-2222-2222-2222-222222222222',
        45,
        CURRENT_DATE - 2,
        now()
    ),

    -- Новые задачи (просроченные)
    (
        gen_random_uuid(),
        (SELECT id FROM aml_task.issues WHERE issue_number = 4 LIMIT 1),
        '33333333-3333-3333-3333-333333333333',
        200,
        CURRENT_DATE - 8,
        now()
    ),
    (
        gen_random_uuid(),
        (SELECT id FROM aml_task.issues WHERE issue_number = 5 LIMIT 1),
        '22222222-2222-2222-2222-222222222222',
        150,
        CURRENT_DATE - 6,
        now()
    ),
    (
        gen_random_uuid(),
        (SELECT id FROM aml_task.issues WHERE issue_number = 6 LIMIT 1),
        '33333333-3333-3333-3333-333333333333',
        300,
        CURRENT_DATE - 3,
        now()
    );

DELETE FROM aml_task.issue_status_history
WHERE issue_id = 'dddddddd-dddd-dddd-dddd-dddddddddd01';

INSERT INTO aml_task.issue_status_history (
    id,
    issue_id,
    from_status_id,
    to_status_id,
    changed_by,
    entered_at,
    left_at,
    comment
)
VALUES
    (
        gen_random_uuid(),
        'dddddddd-dddd-dddd-dddd-dddddddddd01',
        NULL,
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb001', -- To Do
        '22222222-2222-2222-2222-222222222222',
        now() - interval '8 days',
        now() - interval '6 days',
        'Задача создана и помещена в бэклог.'
    ),
    (
        gen_random_uuid(),
        'dddddddd-dddd-dddd-dddd-dddddddddd01',
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb001', -- To Do
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb002', -- In Progress
        '33333333-3333-3333-3333-333333333333',
        now() - interval '6 days',
        now() - interval '3 days',
        'Исполнитель приступил к работе над задачей.'
    ),
    (
        gen_random_uuid(),
        'dddddddd-dddd-dddd-dddd-dddddddddd01',
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb002', -- In Progress
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb003', -- Code Review
        '33333333-3333-3333-3333-333333333333',
        now() - interval '3 days',
        NULL,
        'Основная реализация завершена, задача передана на проверку.'
    );

INSERT INTO aml_task.issues (
    id,
    project_id,
    issue_number,
    type_id,
    status_id,
    sprint_id,
    parent_issue_id,
    title,
    description,
    reporter_id,
    assignee_id,
    priority,
    story_points,
    due_date,
    rank_position,
    original_estimate_minutes,
    remaining_estimate_minutes
)
VALUES
    (
        gen_random_uuid(),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        7,
        (SELECT id FROM aml_task.issue_types WHERE code = 'subtask'),
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb001', -- To Do
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'dddddddd-dddd-dddd-dddd-dddddddddd01', -- parent AMLTASK-1
        'Подготовить ER-диаграмму',
        'Нужно детализировать сущности и связи для основной модели данных.',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        'medium',
        2,
        CURRENT_DATE + 2,
        7000,
        120,
        120
    ),
    (
        gen_random_uuid(),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        8,
        (SELECT id FROM aml_task.issue_types WHERE code = 'subtask'),
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb002', -- In Progress
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'dddddddd-dddd-dddd-dddd-dddddddddd01', -- parent AMLTASK-1
        'Описать ограничения целостности',
        'Нужно подготовить список ограничений, внешних ключей и check-условий.',
        '22222222-2222-2222-2222-222222222222',
        '22222222-2222-2222-2222-222222222222',
        'high',
        3,
        CURRENT_DATE + 4,
        8000,
        180,
        90
    ),
    (
        gen_random_uuid(),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        9,
        (SELECT id FROM aml_task.issue_types WHERE code = 'subtask'),
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb003', -- Code Review
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'dddddddd-dddd-dddd-dddd-dddddddddd01', -- parent AMLTASK-1
        'Подготовить триггеры аудита',
        'Нужно реализовать автоматическую запись изменений в журнал аудита.',
        '11111111-1111-1111-1111-111111111111',
        '33333333-3333-3333-3333-333333333333',
        'high',
        5,
        CURRENT_DATE + 5,
        9000,
        240,
        120
    )
ON CONFLICT (project_id, issue_number) DO NOTHING;

UPDATE aml_task.issue_types SET name = 'Задача' WHERE code = 'task';
UPDATE aml_task.issue_types SET name = 'Ошибка' WHERE code = 'bug';
UPDATE aml_task.issue_types SET name = 'История' WHERE code = 'story';
UPDATE aml_task.issue_types SET name = 'Эпик' WHERE code = 'epic';
UPDATE aml_task.issue_types SET name = 'Подзадача' WHERE code = 'subtask';


UPDATE aml_task.projects
SET description = 'Проверка updated_at, row_version и audit №2'
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  AND description IS DISTINCT FROM 'Проверка updated_at, row_version и audit №2';


SELECT id, description, updated_at, row_version
FROM aml_task.projects
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT table_name, operation, record_pk, changed_at
FROM aml_task.audit_log
ORDER BY id DESC
LIMIT 10;
