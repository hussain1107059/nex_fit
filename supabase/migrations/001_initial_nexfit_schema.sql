-- =============================================================================
-- NexFit — Initial Supabase Schema
-- =============================================================================
-- Migration : 001_initial_nexfit_schema.sql
-- Project   : NexFit (Flutter, offline-first, two-way sync)
-- Phase     : 02 — database schema + RLS + sync metadata (NO seed data yet)
--
-- Design notes
-- ------------
-- * Runs against a Supabase project (PostgreSQL 15+). Deterministic and
--   re-runnable: all objects use IF NOT EXISTS / OR REPLACE / drop-then-create
--   where required. It is still intended to run exactly once per environment.
-- * Timestamps are `timestamptz`, server-generated. `updated_at` and
--   `row_version` are maintained by a BEFORE trigger — the mobile app never
--   writes timestamps for every update.
-- * Syncable tables carry: id (uuid, client-generated), created_at, updated_at,
--   deleted_at (soft delete), row_version (server revision) and last_modified_by.
-- * User-owned tables are keyed to auth.users(id) via `user_id` and protected
--   by Row Level Security using auth.uid(). The service_role key is NEVER used
--   by the Flutter app.
-- * Master/reference data is global (user_id IS NULL or no user_id column),
--   readable by authenticated users, writable ONLY by privileged/admin paths
--   (service role / SQL). Clients pull it via master_data_versions.
-- * Change tracking: user-owned rows are recorded into `sync_changes` by
--   SECURITY DEFINER triggers (append-only, cursor = bigint identity `id`).
--   Master data uses `master_data_versions` + per-row `updated_at` instead of
--   flooding the change log on bulk uploads.
-- =============================================================================

-- =============================================================================
-- 1. EXTENSIONS / PREREQUISITES
-- =============================================================================
-- gen_random_uuid() is built into PostgreSQL 13+ (Supabase is 15+); no
-- extension required. The guard below is harmless on any modern Postgres.

-- =============================================================================
-- 2. MASTER / REFERENCE DATA TABLES (global, read-only for app users)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 2.1 workout_categories — 21 global workout categories (slug-unique)
-- -----------------------------------------------------------------------------
create table if not exists public.workout_categories (
    id            uuid primary key default gen_random_uuid(),
    name          text not null,
    slug          text not null unique,
    description   text,
    icon          text,
    color         integer,
    sort_order    integer not null default 0,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 2.2 meal_categories — 6 global meal slots (slug-unique)
-- -----------------------------------------------------------------------------
create table if not exists public.meal_categories (
    id            uuid primary key default gen_random_uuid(),
    name          text not null,
    slug          text not null unique,
    icon          text,
    sort_order    integer not null default 0,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 2.3 goal_templates — global fitness-goal templates (weight_loss, etc.)
-- -----------------------------------------------------------------------------
create table if not exists public.goal_templates (
    id            uuid primary key default gen_random_uuid(),
    goal_type     text not null unique,
    title         text not null,
    description   text,
    status        text not null default 'active'
                  check (status in ('active', 'inactive')),
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 2.4 exercises — HYBRID table.
--   * user_id IS NULL    -> global/master exercise (bulk-uploaded by developer)
--   * user_id = auth.uid() -> user-created custom exercise
--   Mirrors the existing SQFlite `exercise` table (user_id IS NULL = built-in).
-- -----------------------------------------------------------------------------
create table if not exists public.exercises (
    id                  uuid primary key default gen_random_uuid(),
    user_id             uuid references auth.users(id) on delete cascade,
    name                text not null,
    scientific_name     text,
    description         text,
    instructions        text,
    body_part           text,
    secondary_muscle    text,
    equipment           text,
    difficulty          text,
    category            text,
    image_url           text,
    gif_url             text,          -- animated exercise GIFs (was gif_path)
    calories_per_minute double precision,
    estimated_calories  double precision,
    duration_seconds    integer not null default 30,
    sets                integer not null default 3,
    reps                integer not null default 12,
    rest_seconds        integer not null default 30,
    tips                text,
    common_mistakes     text,
    safety_instructions text,
    is_custom           boolean not null default false,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    deleted_at          timestamptz,
    row_version         bigint not null default 0,
    last_modified_by    uuid
);

-- -----------------------------------------------------------------------------
-- 2.5 foods — HYBRID table (same model as SQFlite `food_item`).
--   * user_id IS NULL    -> global/master food (bulk-uploaded by developer)
--   * user_id = auth.uid() -> user-created custom food
-- -----------------------------------------------------------------------------
create table if not exists public.foods (
    id                uuid primary key default gen_random_uuid(),
    user_id           uuid references auth.users(id) on delete cascade,
    name              text not null,
    brand             text,
    category          text,
    serving_size      text,
    serving_grams     double precision,
    calories          double precision not null default 0,
    protein           double precision not null default 0,
    carbs             double precision not null default 0,
    fat               double precision not null default 0,
    fiber             double precision not null default 0,
    sugar             double precision not null default 0,
    sodium            double precision,
    potassium         double precision,
    calcium           double precision,
    iron              double precision,
    vitamin_a         double precision,
    vitamin_c         double precision,
    water_percentage  double precision,
    barcode           text,
    image_url         text,
    is_custom         boolean not null default false,
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now(),
    deleted_at        timestamptz,
    row_version       bigint not null default 0,
    last_modified_by  uuid
);

-- -----------------------------------------------------------------------------
-- 2.6 workout_templates — global workout routines (was per-user is_custom=0)
-- -----------------------------------------------------------------------------
create table if not exists public.workout_templates (
    id               uuid primary key default gen_random_uuid(),
    category_id      uuid references public.workout_categories(id)
                     on delete set null,
    name             text not null,
    description      text,
    difficulty       text,
    duration_minutes integer,
    calories_burn    double precision,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    deleted_at       timestamptz,
    row_version      bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 2.7 workout_template_exercises — exercises within a global template
-- -----------------------------------------------------------------------------
create table if not exists public.workout_template_exercises (
    id               uuid primary key default gen_random_uuid(),
    template_id      uuid not null references public.workout_templates(id)
                     on delete cascade,
    exercise_id      uuid not null references public.exercises(id)
                     on delete restrict,
    sets             integer not null default 0,
    reps             integer not null default 0,
    duration_seconds integer not null default 0,
    rest_seconds     integer not null default 0,
    sort_order       integer not null default 0,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    deleted_at       timestamptz,
    row_version      bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 2.8 achievement_defs — global achievement catalog (developer-uploaded)
-- -----------------------------------------------------------------------------
create table if not exists public.achievement_defs (
    id               uuid primary key default gen_random_uuid(),
    achievement_type text not null unique,
    name             text not null,
    description      text,
    icon             text,
    xp_reward        integer not null default 0,
    sort_order       integer not null default 0,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    deleted_at       timestamptz,
    row_version      bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 2.9 badge_defs — global badge catalog (developer-uploaded)
-- -----------------------------------------------------------------------------
create table if not exists public.badge_defs (
    id               uuid primary key default gen_random_uuid(),
    badge_type       text not null unique,
    badge_name       text not null,
    icon             text,
    description      text,
    level            integer not null default 1,
    target           double precision not null default 0,
    sort_order       integer not null default 0,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    deleted_at       timestamptz,
    row_version      bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 2.10 challenge_defs — global challenge catalog (developer-uploaded)
-- -----------------------------------------------------------------------------
create table if not exists public.challenge_defs (
    id               uuid primary key default gen_random_uuid(),
    challenge_type   text not null unique,
    title            text not null,
    description      text,
    difficulty       text not null default 'medium',
    target           integer not null default 0,
    reward_xp        integer not null default 0,
    sort_order       integer not null default 0,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    deleted_at       timestamptz,
    row_version      bigint not null default 0,
    last_modified_by uuid
);

-- =============================================================================
-- 3. USER-OWNED DATA TABLES
-- =============================================================================
-- Conventions:
--   * user_id uuid not null references auth.users(id) on delete cascade
--   * id uuid (client-generated) so the same logical row can be inserted
--     idempotently from any device
--   * row_version + updated_at support conflict detection; deleted_at is the
--     soft-delete tombstone so offline devices learn about remote deletions.

-- -----------------------------------------------------------------------------
-- 3.1 profiles — app-level profile (id = auth.users.id). NO credentials here.
--     Deletion = account deletion (cascade from auth.users). No soft delete.
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
    id                uuid primary key references auth.users(id)
                      on delete cascade,
    display_name      text,
    avatar_url        text,             -- Supabase Storage object URL
    height_cm         double precision,
    weight_kg         double precision,
    gender            text,
    birth_date        date,
    activity_level    text,
    target_calories   double precision,
    target_protein    double precision,
    target_carbs      double precision,
    target_fat        double precision,
    target_water_ml   integer,
    target_steps      integer,
    target_weight_kg  double precision,
    fitness_goal      text,
    country           text,
    language          text,
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now(),
    row_version       bigint not null default 0,
    last_modified_by  uuid
);

-- -----------------------------------------------------------------------------
-- 3.2 user_settings — cloud-portable preferences (singleton per user).
--     Device-local security fields (pin_hash, biometric flags, encryption keys,
--     screenshot lock, session timeouts) stay in SQFlite only.
-- -----------------------------------------------------------------------------
create table if not exists public.user_settings (
    id                        uuid primary key default gen_random_uuid(),
    user_id                   uuid not null unique references auth.users(id)
                              on delete cascade,
    theme_mode                text not null default 'system',
    locale                    text not null default 'bn',
    units                     text not null default 'metric',
    week_start                text not null default 'sunday',
    daily_calorie_target      double precision,
    daily_water_target_ml     integer,
    daily_step_target         integer,
    protein_goal              double precision,
    carbs_goal                double precision,
    fat_goal                  double precision,
    notifications_enabled     boolean not null default true,
    reminder_enabled          boolean not null default true,
    workout_reminder_enabled  boolean not null default true,
    meal_reminder_enabled     boolean not null default true,
    water_reminder_enabled    boolean not null default true,
    weight_reminder_enabled   boolean not null default true,
    sleep_reminder_enabled    boolean not null default true,
    challenge_reminder_enabled boolean not null default true,
    achievement_reminder_enabled boolean not null default true,
    default_rest_time_seconds integer not null default 60,
    auto_start_timer          boolean not null default false,
    countdown_voice           boolean not null default true,
    exercise_animation        boolean not null default true,
    auto_next_exercise        boolean not null default true,
    data_sync_enabled         boolean not null default true,
    created_at                timestamptz not null default now(),
    updated_at                timestamptz not null default now(),
    deleted_at                timestamptz,
    row_version               bigint not null default 0,
    last_modified_by          uuid
);

-- -----------------------------------------------------------------------------
-- 3.3 fitness_goals — user's active goals (unique per goal_type)
-- -----------------------------------------------------------------------------
create table if not exists public.fitness_goals (
    id             uuid primary key default gen_random_uuid(),
    user_id        uuid not null references auth.users(id) on delete cascade,
    goal_type      text not null,
    title          text not null,
    description    text,
    target_value   double precision,
    current_value  double precision not null default 0,
    start_date     date,
    target_date    date,
    status         text not null default 'active'
                   check (status in ('active', 'completed', 'archived')),
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),
    deleted_at     timestamptz,
    row_version    bigint not null default 0,
    last_modified_by uuid,
    constraint uq_fitness_goals_user_type unique (user_id, goal_type)
);

-- -----------------------------------------------------------------------------
-- 3.4 workouts — user workouts (custom or saved routines)
-- -----------------------------------------------------------------------------
create table if not exists public.workouts (
    id               uuid primary key default gen_random_uuid(),
    user_id          uuid not null references auth.users(id) on delete cascade,
    category_id      uuid references public.workout_categories(id)
                     on delete set null,
    name             text not null,
    description      text,
    difficulty       text,
    duration_minutes integer,
    calories_burn    double precision,
    image_url        text,
    is_favorite      boolean not null default false,
    is_custom        boolean not null default false,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    deleted_at       timestamptz,
    row_version      bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.5 workout_exercises — exercises within a user workout
-- -----------------------------------------------------------------------------
create table if not exists public.workout_exercises (
    id               uuid primary key default gen_random_uuid(),
    user_id          uuid not null references auth.users(id) on delete cascade,
    workout_id       uuid not null references public.workouts(id)
                     on delete cascade,
    exercise_id      uuid references public.exercises(id) on delete set null,
    sets             integer not null default 0,
    reps             integer not null default 0,
    duration_seconds integer not null default 0,
    rest_seconds     integer not null default 0,
    sort_order       integer not null default 0,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    deleted_at       timestamptz,
    row_version      bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.6 workout_history — completed/started workout sessions (user record)
-- -----------------------------------------------------------------------------
create table if not exists public.workout_history (
    id               uuid primary key default gen_random_uuid(),
    user_id          uuid not null references auth.users(id) on delete cascade,
    workout_id       uuid references public.workouts(id) on delete set null,
    started_at       timestamptz not null,
    ended_at         timestamptz,
    duration_minutes integer,
    calories_burn    double precision,
    notes            text,
    is_completed     boolean not null default false,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    deleted_at       timestamptz,
    row_version      bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.7 exercise_history — per-exercise sets inside a workout session.
--     exercise_id SET NULL so historical entries survive catalog changes.
-- -----------------------------------------------------------------------------
create table if not exists public.exercise_history (
    id                 uuid primary key default gen_random_uuid(),
    user_id            uuid not null references auth.users(id) on delete cascade,
    workout_history_id uuid not null references public.workout_history(id)
                       on delete cascade,
    exercise_id        uuid references public.exercises(id) on delete set null,
    sets               integer not null default 0,
    reps               integer not null default 0,
    weight_kg          double precision,
    duration_seconds   integer,
    completed_at       timestamptz,
    created_at         timestamptz not null default now(),
    updated_at         timestamptz not null default now(),
    deleted_at         timestamptz,
    row_version        bigint not null default 0,
    last_modified_by   uuid
);

-- -----------------------------------------------------------------------------
-- 3.8 meals — user custom meals/templates
-- -----------------------------------------------------------------------------
create table if not exists public.meals (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null references auth.users(id) on delete cascade,
    category_id   uuid references public.meal_categories(id) on delete set null,
    name          text not null,
    description   text,
    calories      double precision not null default 0,
    protein       double precision not null default 0,
    carbs         double precision not null default 0,
    fat           double precision not null default 0,
    image_url     text,
    is_favorite   boolean not null default false,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.9 meal_items — foods within a user meal template
-- -----------------------------------------------------------------------------
create table if not exists public.meal_items (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null references auth.users(id) on delete cascade,
    meal_id       uuid not null references public.meals(id) on delete cascade,
    food_id       uuid references public.foods(id) on delete set null,
    quantity      double precision not null default 1,
    sort_order    integer not null default 0,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.10 food_logs — daily food logging. Macros are snapshotted inline so the
--      log is accurate even if the referenced food is later edited/removed.
-- -----------------------------------------------------------------------------
create table if not exists public.food_logs (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null references auth.users(id) on delete cascade,
    food_id       uuid references public.foods(id) on delete set null,
    meal_id       uuid references public.meals(id) on delete set null,
    meal_type_id  uuid references public.meal_categories(id) on delete set null,
    quantity      double precision not null default 1,
    serving_size  text,
    calories      double precision not null default 0,
    protein       double precision not null default 0,
    carbs         double precision not null default 0,
    fat           double precision not null default 0,
    fiber         double precision not null default 0,
    sugar         double precision not null default 0,
    logged_at     timestamptz not null,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.11 water_logs
-- -----------------------------------------------------------------------------
create table if not exists public.water_logs (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null references auth.users(id) on delete cascade,
    amount_ml     integer not null,
    logged_at     timestamptz not null,
    note          text,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.12 weight_logs
-- -----------------------------------------------------------------------------
create table if not exists public.weight_logs (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null references auth.users(id) on delete cascade,
    weight_kg     double precision not null,
    note          text,
    logged_at     timestamptz not null,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.13 bmi_logs
-- -----------------------------------------------------------------------------
create table if not exists public.bmi_logs (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null references auth.users(id) on delete cascade,
    bmi           double precision not null,
    weight_kg     double precision,
    height_cm     double precision,
    category      text,
    logged_at     timestamptz not null,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.14 body_measurements
-- -----------------------------------------------------------------------------
create table if not exists public.body_measurements (
    id             uuid primary key default gen_random_uuid(),
    user_id        uuid not null references auth.users(id) on delete cascade,
    chest_cm       double precision,
    waist_cm       double precision,
    hip_cm         double precision,
    arm_cm         double precision,
    thigh_cm       double precision,
    neck_cm        double precision,
    shoulder_cm    double precision,
    left_arm_cm    double precision,
    right_arm_cm   double precision,
    left_thigh_cm  double precision,
    right_thigh_cm double precision,
    left_calf_cm   double precision,
    right_calf_cm  double precision,
    note           text,
    measured_at    timestamptz not null,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),
    deleted_at     timestamptz,
    row_version    bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.15 sleep_logs
-- -----------------------------------------------------------------------------
create table if not exists public.sleep_logs (
    id               uuid primary key default gen_random_uuid(),
    user_id          uuid not null references auth.users(id) on delete cascade,
    sleep_date       date not null,
    duration_minutes integer not null,
    bedtime          timestamptz,
    wake_time        timestamptz,
    quality          integer not null default 0,
    note             text,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    deleted_at       timestamptz,
    row_version      bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.16 step_logs
-- -----------------------------------------------------------------------------
create table if not exists public.step_logs (
    id               uuid primary key default gen_random_uuid(),
    user_id          uuid not null references auth.users(id) on delete cascade,
    step_date        date not null,
    steps            integer not null default 0,
    distance_km      double precision not null default 0,
    calories_burned  double precision not null default 0,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    deleted_at       timestamptz,
    row_version      bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.17 reminders — local notification schedules (cloud-backed for multi-device)
-- -----------------------------------------------------------------------------
create table if not exists public.reminders (
    id                   uuid primary key default gen_random_uuid(),
    user_id              uuid not null references auth.users(id) on delete cascade,
    title                text not null,
    body                 text,
    reminder_type        text not null default 'custom',
    time                 text not null,          -- display time ("HH:mm")
    days_of_week         text,                   -- JSON array string
    is_enabled           boolean not null default true,
    last_triggered_at    timestamptz,
    schedule_type        text not null default 'daily',
    times                text,                   -- multiple times JSON string
    start_date           date,
    end_date             date,
    month_day            integer,
    icon                 text,
    color_value          integer,
    sound_enabled        boolean not null default true,
    vibration_enabled    boolean not null default true,
    silent_mode          boolean not null default false,
    show_action_buttons  boolean not null default true,
    related_screen       text,
    created_at           timestamptz not null default now(),
    updated_at           timestamptz not null default now(),
    deleted_at           timestamptz,
    row_version          bigint not null default 0,
    last_modified_by     uuid
);

-- -----------------------------------------------------------------------------
-- 3.18 reminder_history — completed/missed/skipped occurrences.
--      reminder_id SET NULL (deliberate change vs SQFlite CASCADE) so
--      statistics/history survive a reminder being deleted.
-- -----------------------------------------------------------------------------
create table if not exists public.reminder_history (
    id             uuid primary key default gen_random_uuid(),
    user_id        uuid not null references auth.users(id) on delete cascade,
    reminder_id    uuid references public.reminders(id) on delete set null,
    status         text not null default 'missed'
                   check (status in ('completed', 'missed', 'skipped')),
    scheduled_for  timestamptz not null,
    acted_at       timestamptz,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),
    deleted_at     timestamptz,
    row_version    bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.19 exercise_favorites — user<->exercise join
-- -----------------------------------------------------------------------------
create table if not exists public.exercise_favorites (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null references auth.users(id) on delete cascade,
    exercise_id   uuid not null references public.exercises(id)
                  on delete cascade,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid,
    constraint uq_exercise_favorites_user_exercise unique (user_id, exercise_id)
);

-- -----------------------------------------------------------------------------
-- 3.20 food_favorites — user<->food join
-- -----------------------------------------------------------------------------
create table if not exists public.food_favorites (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null references auth.users(id) on delete cascade,
    food_id       uuid not null references public.foods(id) on delete cascade,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid,
    constraint uq_food_favorites_user_food unique (user_id, food_id)
);

-- -----------------------------------------------------------------------------
-- 3.21 user_achievements — per-user unlock state over achievement_defs
-- -----------------------------------------------------------------------------
create table if not exists public.user_achievements (
    id             uuid primary key default gen_random_uuid(),
    user_id        uuid not null references auth.users(id) on delete cascade,
    achievement_id uuid not null references public.achievement_defs(id)
                   on delete restrict,
    is_unlocked    boolean not null default false,
    unlocked_at    timestamptz,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),
    deleted_at     timestamptz,
    row_version    bigint not null default 0,
    last_modified_by uuid,
    constraint uq_user_achievements_user_ach unique (user_id, achievement_id)
);

-- -----------------------------------------------------------------------------
-- 3.22 user_badges — per-user badge progress/earned state over badge_defs
-- -----------------------------------------------------------------------------
create table if not exists public.user_badges (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null references auth.users(id) on delete cascade,
    badge_id      uuid not null references public.badge_defs(id)
                  on delete restrict,
    level         integer not null default 1,
    progress      double precision not null default 0,
    target        double precision not null default 0,
    is_earned     boolean not null default false,
    earned_at     timestamptz,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid,
    constraint uq_user_badges_user_badge unique (user_id, badge_id)
);

-- -----------------------------------------------------------------------------
-- 3.23 streaks — per-user streak counters per type
-- -----------------------------------------------------------------------------
create table if not exists public.streaks (
    id               uuid primary key default gen_random_uuid(),
    user_id          uuid not null references auth.users(id) on delete cascade,
    streak_type      text not null,
    current_streak   integer not null default 0,
    longest_streak   integer not null default 0,
    last_active_date date,
    best_date        date,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    deleted_at       timestamptz,
    row_version      bigint not null default 0,
    last_modified_by uuid,
    constraint uq_streaks_user_type unique (user_id, streak_type)
);

-- -----------------------------------------------------------------------------
-- 3.24 daily_progress — per-user daily rollup (unique per date)
-- -----------------------------------------------------------------------------
create table if not exists public.daily_progress (
    id                uuid primary key default gen_random_uuid(),
    user_id           uuid not null references auth.users(id) on delete cascade,
    progress_date     date not null,
    steps             integer not null default 0,
    water_ml          integer not null default 0,
    calories_consumed double precision not null default 0,
    calories_burned   double precision not null default 0,
    workout_minutes   integer not null default 0,
    sleep_minutes     integer not null default 0,
    weight_kg         double precision,
    is_goal_met       boolean not null default false,
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now(),
    deleted_at        timestamptz,
    row_version       bigint not null default 0,
    last_modified_by  uuid,
    constraint uq_daily_progress_user_date unique (user_id, progress_date)
);

-- -----------------------------------------------------------------------------
-- 3.25 xp_history — append-only XP ledger. No unique(source,reason) constraint
--      (deliberate: the SQFlite unique index would block legit repeated awards).
-- -----------------------------------------------------------------------------
create table if not exists public.xp_history (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null references auth.users(id) on delete cascade,
    source        text not null,
    reason        text not null,
    xp            integer not null default 0,
    total_xp      integer not null default 0,
    metadata      jsonb,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.26 user_levels — singleton level/XP counters per user
-- -----------------------------------------------------------------------------
create table if not exists public.user_levels (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null unique references auth.users(id)
                  on delete cascade,
    level         integer not null default 1,
    current_xp    integer not null default 0,
    required_xp   integer not null default 100,
    total_xp      integer not null default 0,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid
);

-- -----------------------------------------------------------------------------
-- 3.27 user_challenges — per-user progress over challenge_defs
-- -----------------------------------------------------------------------------
create table if not exists public.user_challenges (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null references auth.users(id) on delete cascade,
    challenge_id  uuid not null references public.challenge_defs(id)
                  on delete restrict,
    progress      integer not null default 0,
    is_completed  boolean not null default false,
    completed_at  timestamptz,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid,
    constraint uq_user_challenges_user_chal unique (user_id, challenge_id)
);

-- -----------------------------------------------------------------------------
-- 3.28 challenge_milestones — per-user milestones within a user challenge
-- -----------------------------------------------------------------------------
create table if not exists public.challenge_milestones (
    id                uuid primary key default gen_random_uuid(),
    user_id           uuid not null references auth.users(id) on delete cascade,
    user_challenge_id uuid not null references public.user_challenges(id)
                      on delete cascade,
    title             text not null,
    target_value      integer not null default 0,
    current_value     integer not null default 0,
    is_reached        boolean not null default false,
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now(),
    deleted_at        timestamptz,
    row_version       bigint not null default 0,
    last_modified_by  uuid,
    constraint uq_challenge_milestones unique (user_id, user_challenge_id, title)
);

-- -----------------------------------------------------------------------------
-- 3.29 user_rewards — per-user reward claim state
-- -----------------------------------------------------------------------------
create table if not exists public.user_rewards (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null references auth.users(id) on delete cascade,
    type          text not null,
    title         text not null,
    amount        integer not null default 0,
    icon          text,
    is_claimed    boolean not null default false,
    claimed_at    timestamptz,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    row_version   bigint not null default 0,
    last_modified_by uuid,
    constraint uq_user_rewards unique (user_id, type, title)
);

-- =============================================================================
-- 4. SYNC METADATA TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 4.1 sync_changes — append-only change log for USER-OWNED rows.
--      cursor   = `id` (bigint identity, monotonic). Client asks:
--                 "give me everything changed after cursor X for my user_id".
--      payload  = full JSONB row snapshot so clients can apply without a
--                 second round-trip. Master rows (user_id IS NULL) are NOT
--                 logged here — they sync via master_data_versions.
--      Writable ONLY by the SECURITY DEFINER trigger functions below.
-- -----------------------------------------------------------------------------
create table if not exists public.sync_changes (
    id          bigint generated always as identity primary key,
    table_name  text not null,
    record_id   uuid not null,
    operation   text not null check (operation in ('INSERT', 'UPDATE', 'DELETE')),
    user_id     uuid,
    payload     jsonb,
    created_at  timestamptz not null default now()
);

create index if not exists idx_sync_changes_user_cursor
    on public.sync_changes (user_id, id);
create index if not exists idx_sync_changes_table_record
    on public.sync_changes (table_name, record_id);

-- -----------------------------------------------------------------------------
-- 4.2 master_data_versions — per-catalog version cursor for bulk master sync.
--      Developer bumps data_version after a bulk publish; clients compare the
--      version and download only changed rows (by updated_at) when it moves.
-- -----------------------------------------------------------------------------
create table if not exists public.master_data_versions (
    catalog        text primary key,
    data_version   bigint not null default 0,
    schema_version bigint not null default 1,
    updated_at     timestamptz not null default now()
);

-- =============================================================================
-- 5. INDEXES
-- =============================================================================
-- Rationale:
--   * (user_id, updated_at) on every user table serves incremental pull
--     ("rows for this user changed after X") and the most common dashboard/
--     history range queries in one index.
--   * FK columns are indexed because PostgreSQL does NOT auto-index FKs.
--   * Master tables get an updated_at index for version-based pull.
--   * Partial unique indexes prevent duplicate master foods/exercises by name
--     (NULL user_id rows are all treated as duplicates of each other).

-- 5.1 Per-user (user_id, updated_at) indexes
do $$
declare t text;
begin
    foreach t in array array[
        'user_settings','fitness_goals','workouts','workout_exercises',
        'workout_history','exercise_history','meals','meal_items','food_logs',
        'water_logs','weight_logs','bmi_logs','body_measurements','sleep_logs',
        'step_logs','reminders','reminder_history','exercise_favorites',
        'food_favorites','user_achievements','user_badges','streaks',
        'daily_progress','xp_history','user_levels','user_challenges',
        'challenge_milestones','user_rewards'
    ] loop
        execute format('create index if not exists idx_%s_user_updated on %s(user_id, updated_at)', t, t);
    end loop;
end $$;

-- 5.2 Hybrid tables (exercises, foods): user sync index + name uniqueness
create index if not exists idx_exercises_user_updated
    on public.exercises (user_id, updated_at);
create index if not exists idx_foods_user_updated
    on public.foods (user_id, updated_at);

-- master rows: unique by name; custom rows: unique per user
create unique index if not exists uq_exercises_master_name
    on public.exercises (name) where user_id is null;
create unique index if not exists uq_exercises_custom_name
    on public.exercises (user_id, name) where user_id is not null;
create unique index if not exists uq_foods_master_name
    on public.foods (name) where user_id is null;
create unique index if not exists uq_foods_custom_name
    on public.foods (user_id, name) where user_id is not null;

-- 5.3 Master tables: updated_at index for incremental catalog pulls
create index if not exists idx_workout_categories_updated
    on public.workout_categories (updated_at);
create index if not exists idx_meal_categories_updated
    on public.meal_categories (updated_at);
create index if not exists idx_goal_templates_updated
    on public.goal_templates (updated_at);
create index if not exists idx_workout_templates_updated
    on public.workout_templates (updated_at);
create index if not exists idx_workout_template_exercises_updated
    on public.workout_template_exercises (updated_at);
create index if not exists idx_achievement_defs_updated
    on public.achievement_defs (updated_at);
create index if not exists idx_badge_defs_updated
    on public.badge_defs (updated_at);
create index if not exists idx_challenge_defs_updated
    on public.challenge_defs (updated_at);

-- 5.4 FK indexes (PostgreSQL does not auto-index foreign keys)
create index if not exists idx_exercises_master_updated
    on public.exercises (updated_at) where user_id is null;
create index if not exists idx_foods_master_updated
    on public.foods (updated_at) where user_id is null;

create index if not exists idx_workout_templates_category
    on public.workout_templates (category_id);
create index if not exists idx_workout_template_exercises_template
    on public.workout_template_exercises (template_id);
create index if not exists idx_workout_template_exercises_exercise
    on public.workout_template_exercises (exercise_id);

create index if not exists idx_workouts_category on public.workouts (category_id);
create index if not exists idx_workout_exercises_workout
    on public.workout_exercises (workout_id);
create index if not exists idx_workout_exercises_exercise
    on public.workout_exercises (exercise_id);
create index if not exists idx_workout_history_workout
    on public.workout_history (workout_id);
create index if not exists idx_exercise_history_workout_history
    on public.exercise_history (workout_history_id);
create index if not exists idx_exercise_history_exercise
    on public.exercise_history (exercise_id);

create index if not exists idx_meals_category on public.meals (category_id);
create index if not exists idx_meal_items_meal on public.meal_items (meal_id);
create index if not exists idx_meal_items_food on public.meal_items (food_id);
create index if not exists idx_food_logs_food on public.food_logs (food_id);
create index if not exists idx_food_logs_meal on public.food_logs (meal_id);
create index if not exists idx_food_logs_meal_type on public.food_logs (meal_type_id);
create index if not exists idx_food_logs_logged_at on public.food_logs (logged_at);

create index if not exists idx_exercise_favorites_exercise
    on public.exercise_favorites (exercise_id);
create index if not exists idx_food_favorites_food
    on public.food_favorites (food_id);

create index if not exists idx_user_achievements_achievement
    on public.user_achievements (achievement_id);
create index if not exists idx_user_badges_badge on public.user_badges (badge_id);
create index if not exists idx_user_challenges_challenge
    on public.user_challenges (challenge_id);
create index if not exists idx_challenge_milestones_challenge
    on public.challenge_milestones (user_challenge_id);
create index if not exists idx_reminder_history_reminder
    on public.reminder_history (reminder_id);

-- =============================================================================
-- 6. TRIGGER FUNCTIONS (server-maintained metadata + change log)
-- =============================================================================
-- No recursive triggers: the change-log insert targets sync_changes, which has
-- no triggers of its own.

-- 6.1 Maintains updated_at, row_version and last_modified_by on every syncable
--     table. Runs BEFORE INSERT OR UPDATE.
--     created_at is deliberately left as supplied by the client (original
--     creation time must survive multi-device sync); updated_at is always the
--     server clock.
create or replace function public.set_row_metadata()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    new.updated_at := now();
    if tg_op = 'UPDATE' then
        new.row_version := coalesce(old.row_version, 0) + 1;
    end if;
    new.last_modified_by := auth.uid();
    return new;
end $$;

-- 6.2 Generic user-owned change logger (AFTER INSERT / AFTER UPDATE).
--     Detects soft-delete transitions and logs them as 'DELETE'.
--     Master rows (user_id IS NULL) are skipped — they are not change-logged.
create or replace function public.log_sync_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    op text;
begin
    if new.user_id is null then
        return new; -- master row; synced via master_data_versions
    end if;

    op := case
        when tg_op = 'UPDATE'
             and new.deleted_at is not null
             and (old.deleted_at is null or old.deleted_at < new.deleted_at)
            then 'DELETE'
        when tg_op = 'UPDATE' then 'UPDATE'
        else 'INSERT'
    end;

    insert into public.sync_changes (table_name, record_id, operation, user_id, payload)
    values (tg_table_name, new.id, op, new.user_id, to_jsonb(new));

    return new;
end $$;

-- 6.3 Physical-delete logger (AFTER DELETE) — captures the removed row as a
--     tombstone so other devices can reconcile.
create or replace function public.log_sync_change_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if old.user_id is null then
        return old; -- master row
    end if;
    insert into public.sync_changes (table_name, record_id, operation, user_id, payload)
    values (tg_table_name, old.id, 'DELETE', old.user_id, to_jsonb(old));
    return old;
end $$;

-- 6.4 Profile change logger — profiles have no user_id column; the owner is `id`.
create or replace function public.log_profile_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.sync_changes (table_name, record_id, operation, user_id, payload)
    values (tg_table_name, new.id, tg_op, new.id, to_jsonb(new));
    return new;
end $$;

-- 6.5 Helper: bumps the version cursor for a master catalog after a bulk
--     publish. Returns the new data_version.
create or replace function public.bump_master_data_version(p_catalog text)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
    v bigint;
begin
    insert into public.master_data_versions (catalog, data_version)
    values (p_catalog, 1)
    on conflict (catalog)
    do update set
        data_version = public.master_data_versions.data_version + 1,
        updated_at   = now()
    returning data_version into v;
    return v;
end $$;

-- =============================================================================
-- 7. TRIGGERS
-- =============================================================================

-- 7.1 Metadata trigger on every syncable table
do $$
declare t text;
begin
    foreach t in array array[
        -- user-owned
        'profiles','user_settings','fitness_goals','workouts','workout_exercises',
        'workout_history','exercise_history','meals','meal_items','food_logs',
        'water_logs','weight_logs','bmi_logs','body_measurements','sleep_logs',
        'step_logs','reminders','reminder_history','exercise_favorites',
        'food_favorites','user_achievements','user_badges','streaks',
        'daily_progress','xp_history','user_levels','user_challenges',
        'challenge_milestones','user_rewards',
        -- hybrid
        'exercises','foods',
        -- master
        'workout_categories','meal_categories','goal_templates',
        'workout_templates','workout_template_exercises',
        'achievement_defs','badge_defs','challenge_defs'
    ] loop
        execute format('drop trigger if exists trg_%s_metadata on %s', t, t);
        execute format(
            'create trigger trg_%s_metadata before insert or update on %s
             for each row execute function public.set_row_metadata()', t, t);
    end loop;
end $$;

-- 7.2 Change-log triggers on user-owned + hybrid tables (master rows skipped
--     inside the function). Sync metadata tables have no triggers (no recursion).
do $$
declare t text;
begin
    foreach t in array array[
        'user_settings','fitness_goals','workouts','workout_exercises',
        'workout_history','exercise_history','meals','meal_items','food_logs',
        'water_logs','weight_logs','bmi_logs','body_measurements','sleep_logs',
        'step_logs','reminders','reminder_history','exercise_favorites',
        'food_favorites','user_achievements','user_badges','streaks',
        'daily_progress','xp_history','user_levels','user_challenges',
        'challenge_milestones','user_rewards','exercises','foods'
    ] loop
        execute format('drop trigger if exists trg_%s_log on %s', t, t);
        execute format(
            'create trigger trg_%s_log after insert or update on %s
             for each row execute function public.log_sync_change()', t, t);
        execute format('drop trigger if exists trg_%s_log_delete on %s', t, t);
        execute format(
            'create trigger trg_%s_log_delete after delete on %s
             for each row execute function public.log_sync_change_delete()', t, t);
    end loop;
end $$;

-- 7.3 Profile change-log triggers (dedicated function)
drop trigger if exists trg_profiles_log on public.profiles;
create trigger trg_profiles_log
    after insert or update on public.profiles
    for each row execute function public.log_profile_change();

-- =============================================================================
-- 8. ROW LEVEL SECURITY
-- =============================================================================
-- All tables in the public schema are RLS-protected. Policies use auth.uid()
-- ONLY. The client-provided user_id is always re-validated server-side.

alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.fitness_goals enable row level security;
alter table public.workouts enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.workout_history enable row level security;
alter table public.exercise_history enable row level security;
alter table public.meals enable row level security;
alter table public.meal_items enable row level security;
alter table public.food_logs enable row level security;
alter table public.water_logs enable row level security;
alter table public.weight_logs enable row level security;
alter table public.bmi_logs enable row level security;
alter table public.body_measurements enable row level security;
alter table public.sleep_logs enable row level security;
alter table public.step_logs enable row level security;
alter table public.reminders enable row level security;
alter table public.reminder_history enable row level security;
alter table public.exercise_favorites enable row level security;
alter table public.food_favorites enable row level security;
alter table public.user_achievements enable row level security;
alter table public.user_badges enable row level security;
alter table public.streaks enable row level security;
alter table public.daily_progress enable row level security;
alter table public.xp_history enable row level security;
alter table public.user_levels enable row level security;
alter table public.user_challenges enable row level security;
alter table public.challenge_milestones enable row level security;
alter table public.user_rewards enable row level security;
alter table public.exercises enable row level security;
alter table public.foods enable row level security;
alter table public.workout_categories enable row level security;
alter table public.meal_categories enable row level security;
alter table public.goal_templates enable row level security;
alter table public.workout_templates enable row level security;
alter table public.workout_template_exercises enable row level security;
alter table public.achievement_defs enable row level security;
alter table public.badge_defs enable row level security;
alter table public.challenge_defs enable row level security;
alter table public.sync_changes enable row level security;
alter table public.master_data_versions enable row level security;

-- -----------------------------------------------------------------------------
-- 8.1 User-owned tables — generic ownership policies
-- -----------------------------------------------------------------------------
do $$
declare t text;
begin
    foreach t in array array[
        'user_settings','fitness_goals','workouts','workout_exercises',
        'workout_history','exercise_history','meals','meal_items','food_logs',
        'water_logs','weight_logs','bmi_logs','body_measurements','sleep_logs',
        'step_logs','reminders','reminder_history','exercise_favorites',
        'food_favorites','user_achievements','user_badges','streaks',
        'daily_progress','xp_history','user_levels','user_challenges',
        'challenge_milestones','user_rewards'
    ] loop
        execute format('drop policy if exists p_%s_select_own on %s', t, t);
        execute format('create policy p_%s_select_own on %s for select
                        using (user_id = auth.uid())', t, t);
        execute format('drop policy if exists p_%s_insert_own on %s', t, t);
        execute format('create policy p_%s_insert_own on %s for insert
                        with check (user_id = auth.uid())', t, t);
        execute format('drop policy if exists p_%s_update_own on %s', t, t);
        execute format('create policy p_%s_update_own on %s for update
                        using (user_id = auth.uid())
                        with check (user_id = auth.uid())', t, t);
        execute format('drop policy if exists p_%s_delete_own on %s', t, t);
        execute format('create policy p_%s_delete_own on %s for delete
                        using (user_id = auth.uid())', t, t);
    end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 8.2 profiles — owner is `id` (== auth.uid())
-- -----------------------------------------------------------------------------
drop policy if exists p_profiles_select_own on public.profiles;
create policy p_profiles_select_own on public.profiles for select
    using (id = auth.uid());
drop policy if exists p_profiles_insert_own on public.profiles;
create policy p_profiles_insert_own on public.profiles for insert
    with check (id = auth.uid());
drop policy if exists p_profiles_update_own on public.profiles;
create policy p_profiles_update_own on public.profiles for update
    using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists p_profiles_delete_own on public.profiles;
create policy p_profiles_delete_own on public.profiles for delete
    using (id = auth.uid());

-- -----------------------------------------------------------------------------
-- 8.3 Hybrid tables (exercises, foods):
--       SELECT  -> own rows OR master rows (user_id IS NULL)
--       WRITE   -> own rows only (master rows are immutable to the app)
-- -----------------------------------------------------------------------------
drop policy if exists p_exercises_select on public.exercises;
create policy p_exercises_select on public.exercises for select
    using (user_id = auth.uid() or user_id is null);
drop policy if exists p_exercises_insert on public.exercises;
create policy p_exercises_insert on public.exercises for insert
    with check (user_id = auth.uid());
drop policy if exists p_exercises_update on public.exercises;
create policy p_exercises_update on public.exercises for update
    using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists p_exercises_delete on public.exercises;
create policy p_exercises_delete on public.exercises for delete
    using (user_id = auth.uid());

drop policy if exists p_foods_select on public.foods;
create policy p_foods_select on public.foods for select
    using (user_id = auth.uid() or user_id is null);
drop policy if exists p_foods_insert on public.foods;
create policy p_foods_insert on public.foods for insert
    with check (user_id = auth.uid());
drop policy if exists p_foods_update on public.foods;
create policy p_foods_update on public.foods for update
    using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists p_foods_delete on public.foods;
create policy p_foods_delete on public.foods for delete
    using (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- 8.4 Master tables — authenticated users may read; no write policies.
--      (No anon policies => anon role has zero access.)
-- -----------------------------------------------------------------------------
do $$
declare t text;
begin
    foreach t in array array[
        'workout_categories','meal_categories','goal_templates',
        'workout_templates','workout_template_exercises',
        'achievement_defs','badge_defs','challenge_defs'
    ] loop
        execute format('drop policy if exists p_%s_select_auth on %s', t, t);
        execute format('create policy p_%s_select_auth on %s for select
                        to authenticated using (true)', t, t);
        execute format('drop policy if exists p_%s_insert_auth on %s', t, t);
        execute format('create policy p_%s_insert_auth on %s for insert
                        to authenticated with check (false)', t, t);
        execute format('drop policy if exists p_%s_update_auth on %s', t, t);
        execute format('create policy p_%s_update_auth on %s for update
                        to authenticated using (false) with check (false)', t, t);
        execute format('drop policy if exists p_%s_delete_auth on %s', t, t);
        execute format('create policy p_%s_delete_auth on %s for delete
                        to authenticated using (false)', t, t);
    end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 8.5 sync_changes — users may only read THEIR OWN change log entries.
--      No INSERT/UPDATE/DELETE policies; rows are written exclusively by the
--      SECURITY DEFINER trigger functions (which bypass RLS).
-- -----------------------------------------------------------------------------
drop policy if exists p_sync_changes_select_own on public.sync_changes;
create policy p_sync_changes_select_own on public.sync_changes for select
    to authenticated using (user_id = auth.uid() or user_id is null);

-- -----------------------------------------------------------------------------
-- 8.6 master_data_versions — authenticated users may read version cursors.
-- -----------------------------------------------------------------------------
drop policy if exists p_master_data_versions_select on public.master_data_versions;
create policy p_master_data_versions_select on public.master_data_versions for select
    to authenticated using (true);

-- -----------------------------------------------------------------------------
-- 8.7 Explicit grants (public schema already grants to authenticated by
--      default; these make intent explicit and safe).
-- -----------------------------------------------------------------------------
grant select on public.workout_categories, public.meal_categories,
    public.goal_templates, public.workout_templates,
    public.workout_template_exercises, public.achievement_defs,
    public.badge_defs, public.challenge_defs, public.master_data_versions
    to authenticated;

grant select on public.sync_changes to authenticated;

grant execute on function public.bump_master_data_version(text) to authenticated;

-- =============================================================================
-- 9. REALTIME PREPARATION
-- =============================================================================
-- Realtime is enabled ONLY on tables where live cross-device updates matter:
--   * daily_progress, food_logs, water_logs, weight_logs, workouts,
--     workout_history, reminders, sleep_logs, step_logs, body_measurements,
--     bmi_logs, streaks
-- Master catalogs and high-volume append-only logs (xp_history, exercise_history,
-- reminder_history) deliberately use cursor/version-based incremental sync and
-- are NOT realtime-enabled.
-- Supabase Realtime respects RLS, so subscriptions filter to the caller's rows.
do $$
declare t text;
begin
    foreach t in array array[
        'public.daily_progress','public.food_logs','public.water_logs',
        'public.weight_logs','public.workouts','public.workout_history',
        'public.reminders','public.sleep_logs','public.step_logs',
        'public.body_measurements','public.bmi_logs','public.streaks'
    ] loop
        begin
            execute format('alter publication supabase_realtime add table %s', t);
        exception when duplicate_object then
            null; -- already in the publication
        end;
    end loop;
end $$;

-- =============================================================================
-- 10. NOTES / FINAL CHECKS
-- =============================================================================
-- * No circular dependencies: master tables reference only other master tables;
--   user tables reference master tables + auth.users.
-- * auth.users(id) cascade ensures account deletion removes all user data.
-- * Historical records are protected via ON DELETE SET NULL on catalog
--   references (food_logs.food_id, exercise_history.exercise_id, ...).
-- * The Flutter app must NEVER use the service_role key; the anon key with RLS
--   is sufficient for all client operations.
-- * Seed data (212 foods, 83 exercises, 26 workouts, categories) is NOT part of
--   this migration; it is uploaded separately via bulk publish + bump_master_data_version().
-- =============================================================================