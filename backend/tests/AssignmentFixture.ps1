# Used only by disposable PostgreSQL integration fixtures, never by app startup.
function Add-AssignmentFixture([Guid] $UserId, [Guid] $OtherUserId, [Guid] $TrainerId, [Guid] $DietitianId) {
    [void] (Invoke-CheckSql @"
INSERT INTO advisor_profiles (id, user_id, advisor_type, title, specialization, is_active, created_at)
VALUES ('10000000-0000-0000-0000-000000000001', '$TrainerId', 'Trainer', 'Kuvvet koçu', 'Kuvvet', true, now());
INSERT INTO user_advisors (id, user_id, advisor_id, advisor_type, start_date, status, created_at)
VALUES ('10000000-0000-0000-0000-000000000002', '$UserId', '$TrainerId', 'Trainer', '2026-01-01', 'Active', now()),
       ('10000000-0000-0000-0000-000000000003', '$UserId', '$DietitianId', 'Dietitian', '2026-01-01', 'Active', now());
INSERT INTO exercises (id, name, is_active, created_at)
VALUES ('10000000-0000-0000-0000-000000000004', 'Squat', true, now());
INSERT INTO workout_plans (id, user_id, trainer_id, name, start_date, is_active, created_at)
VALUES ('10000000-0000-0000-0000-000000000005', '$UserId', '$TrainerId', 'Atanmış kuvvet programı', '2026-01-01', true, now()),
       ('10000000-0000-0000-0000-000000000006', '$OtherUserId', '$TrainerId', 'Diğer kullanıcının programı', '2026-01-01', true, now()),
       ('10000000-0000-0000-0000-000000000007', '$UserId', '$TrainerId', 'Geçmiş program', '2025-01-01', false, now());
INSERT INTO workout_days (id, workout_plan_id, name, day_number, weekday)
VALUES ('10000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000005', 'Kuvvet', 1, 'Monday'),
       ('10000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000005', 'Kardiyo', 2, 'Wednesday');
INSERT INTO workout_exercises (id, workout_day_id, exercise_id, "order", sets, reps, rest_seconds, notes)
VALUES ('10000000-0000-0000-0000-000000000010', '10000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000004', 2, 4, 8, 60, 'İkinci egzersiz'),
       ('10000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000004', 1, 3, 10, 90, 'Kontrollü hareket');
INSERT INTO nutrition_goals (id, user_id, dietitian_id, daily_calories, protein_grams, carbohydrate_grams, fat_grams, water_ml, start_date, is_active, created_at)
VALUES ('10000000-0000-0000-0000-000000000012', '$UserId', '$DietitianId', 2300, 150, 260, 70, 2500, '2026-01-01', true, now()),
       ('10000000-0000-0000-0000-000000000013', '$UserId', '$DietitianId', 999, 1, 1, 1, 100, '2025-01-01', false, now()),
       ('10000000-0000-0000-0000-000000000014', '$OtherUserId', '$DietitianId', 1900, 100, 200, 50, 2000, '2026-01-01', true, now());
INSERT INTO user_tasks (id, user_id, advisor_id, title, description, due_date, status, completed_at, created_at)
VALUES ('10000000-0000-0000-0000-000000000015', '$UserId', '$TrainerId', 'Esneme yap', 'On dakika', '2026-12-01', 'Pending', null, now()),
       ('10000000-0000-0000-0000-000000000016', '$UserId', '$DietitianId', 'Tamamlanan görev', null, null, 'Completed', now(), now() - interval '1 day'),
       ('10000000-0000-0000-0000-000000000017', '$OtherUserId', '$TrainerId', 'Başkasının görevi', null, null, 'Pending', null, now());
INSERT INTO advisor_notes (id, user_id, advisor_id, title, content, created_at)
VALUES ('10000000-0000-0000-0000-000000000018', '$UserId', '$TrainerId', 'Koç notu', 'Hareketleri kontrollü yap.', now()),
       ('10000000-0000-0000-0000-000000000019', '$UserId', '$DietitianId', 'Diyetisyen notu', 'Hedeflerini takip et.', now() - interval '1 day'),
       ('10000000-0000-0000-0000-000000000020', '$OtherUserId', '$TrainerId', 'Başkasının notu', 'Özel içerik', now());
"@)
}
