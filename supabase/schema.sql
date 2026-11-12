create table if not exists public.exercises (
  id text not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  name_hu text,
  category text not null,
  lift text,
  equipment text,
  variation integer not null default 0,
  is_custom integer not null default 0,
  archived integer not null default 0,
  updated_at bigint not null,
  deleted_at bigint,
  primary key (user_id, id)
);

create table if not exists public.workouts (
  id text not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text,
  date bigint not null,
  started_at bigint not null,
  ended_at bigint,
  tag text,
  notes text,
  stress integer,
  fatigue_sq integer,
  fatigue_bp integer,
  fatigue_dl integer,
  status text not null,
  block_id text,
  updated_at bigint not null,
  deleted_at bigint,
  primary key (user_id, id)
);

create table if not exists public.workout_exercises (
  id text not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  workout_id text not null,
  exercise_id text not null,
  position integer not null,
  notes text,
  tempo text,
  primary key (user_id, id),
  foreign key (user_id, workout_id) references public.workouts(user_id, id) on delete cascade
);

create table if not exists public.workout_sets (
  id text not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  workout_exercise_id text not null,
  position integer not null,
  set_type text not null,
  presc_text text,
  presc_reps integer,
  presc_weight double precision,
  target_rpe double precision,
  reps integer,
  weight double precision,
  rpe double precision,
  completed integer not null default 0,
  note text,
  primary key (user_id, id),
  foreign key (user_id, workout_exercise_id) references public.workout_exercises(user_id, id) on delete cascade
);

create table if not exists public.programs (
  id text not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  description text,
  is_sample integer not null default 0,
  updated_at bigint not null,
  deleted_at bigint,
  primary key (user_id, id)
);

create table if not exists public.program_blocks (
  id text not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  program_id text not null,
  name text not null,
  start_date bigint,
  week_count integer not null,
  position integer not null,
  primary key (user_id, id),
  foreign key (user_id, program_id) references public.programs(user_id, id) on delete cascade
);

create table if not exists public.program_days (
  id text not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  block_id text not null,
  name text not null,
  weekday integer not null,
  tag text,
  position integer not null,
  primary key (user_id, id),
  foreign key (user_id, block_id) references public.program_blocks(user_id, id) on delete cascade
);

create table if not exists public.program_exercises (
  id text not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day_id text not null,
  exercise_id text not null,
  position integer not null,
  primary key (user_id, id),
  foreign key (user_id, day_id) references public.program_days(user_id, id) on delete cascade
);

create table if not exists public.program_sets (
  id text not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  program_exercise_id text not null,
  week_index integer not null,
  position integer not null,
  sets integer not null,
  reps_min integer,
  reps_max integer,
  load_type text not null,
  weight double precision,
  weight_max double precision,
  rpe_min double precision,
  rpe_max double precision,
  rest_sec integer,
  tempo text,
  note text,
  amrap integer not null default 0,
  constant_load integer not null default 0,
  repeat_until integer not null default 0,
  primary key (user_id, id),
  foreign key (user_id, program_exercise_id) references public.program_exercises(user_id, id) on delete cascade
);

create table if not exists public.personal_records (
  id text not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  exercise_id text not null,
  exercise_name text,
  kind text not null,
  value double precision not null,
  previous double precision,
  reps integer,
  weight double precision,
  date bigint not null,
  workout_id text not null,
  primary key (user_id, id),
  foreign key (user_id, workout_id) references public.workouts(user_id, id) on delete cascade
);

create table if not exists public.bodyweight (
  id text not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date bigint not null,
  kg double precision not null,
  updated_at bigint not null,
  primary key (user_id, id)
);

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'exercises', 'workouts', 'workout_exercises', 'workout_sets', 'programs',
    'program_blocks', 'program_days', 'program_exercises', 'program_sets',
    'personal_records', 'bodyweight'
  ]
  loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('drop policy if exists %I on public.%I', table_name || '_owner_policy', table_name);
    execute format(
      'create policy %I on public.%I for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id)',
      table_name || '_owner_policy',
      table_name
    );
  end loop;
end
$$;
