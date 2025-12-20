-- Replace HTTP-based cron invocation with an in-DB function call.
-- This avoids exposing a public Edge Function endpoint that writes directly to DB.

create or replace function public.run_meal_reminder(meal_type text)
returns void
language plpgsql
as $$
declare
  reminder_text text;
begin
  if meal_type not in ('breakfast', 'lunch', 'dinner') then
    raise exception 'invalid meal_type: %', meal_type;
  end if;

  reminder_text :=
    case meal_type
      when 'breakfast' then
        'おはようございます。朝食の記録がまだのようです。' || E'\n' ||
        '食べた場合は、食事ページからサッと入力してみてくださいね。' || E'\n' ||
        'もし朝食を抜いた場合も、無理せず体調優先でOKです。'
      when 'lunch' then
        'こんにちは。お昼の記録がまだ見当たりません。' || E'\n' ||
        '今日はお昼は抜きでしたか？' || E'\n' ||
        '食べた場合は、あとからでも大丈夫なので食事記録に入れてみてください。'
      when 'dinner' then
        'こんばんは。夕食の記録がまだのようです。' || E'\n' ||
        '食べたら忘れないうちに入力してみましょう。' || E'\n' ||
        'もしこれから夕食なら、食べる予定が決まったらメモ代わりに入れておくのもおすすめです。'
    end;

  -- Insert reminders (idempotent via unique constraint).
  with t as (
    select (now() at time zone 'Asia/Tokyo')::date as today
  )
  insert into public.ai_inbox_messages (user_id, date, kind, meal_type, content)
  select
    up.user_id,
    t.today,
    'meal_reminder',
    meal_type::text,
    reminder_text::text
  from public.user_profiles up
  cross join t
  left join public.meals m
    on m.user_id = up.user_id
    and m.date = t.today
    and m.meal_type = meal_type::text
  where
    up.onboarding_completed = true
    and m.id is null
  on conflict (user_id, date, kind, meal_type)
  do nothing;
end;
$$;

-- Unschedule legacy jobs if they exist (from earlier migration).
select cron.unschedule(jobid) from cron.job where jobname = 'meal-reminder-breakfast';
select cron.unschedule(jobid) from cron.job where jobname = 'meal-reminder-lunch';
select cron.unschedule(jobid) from cron.job where jobname = 'meal-reminder-dinner';

-- Schedule jobs (DB timezone is typically UTC on Supabase)
-- 09:00 JST = 00:00 UTC
-- 13:00 JST = 04:00 UTC
-- 21:00 JST = 12:00 UTC
select cron.schedule(
  'meal-reminder-breakfast',
  '0 0 * * *',
  $$ select public.run_meal_reminder('breakfast'); $$
);
select cron.schedule(
  'meal-reminder-lunch',
  '0 4 * * *',
  $$ select public.run_meal_reminder('lunch'); $$
);
select cron.schedule(
  'meal-reminder-dinner',
  '0 12 * * *',
  $$ select public.run_meal_reminder('dinner'); $$
);


