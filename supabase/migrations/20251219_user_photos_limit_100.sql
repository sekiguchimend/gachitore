-- Enforce "max 100 photos per user" at the DB layer (race-safe)
--
-- This prevents bypass via direct REST calls or concurrent uploads.
-- Uses an advisory transaction lock keyed by user_id to serialize inserts per user.

create or replace function public.enforce_user_photos_limit_100()
returns trigger
language plpgsql
as $$
declare
  cnt integer;
begin
  -- Serialize inserts per user to avoid race conditions
  perform pg_advisory_xact_lock(hashtext(new.user_id::text));

  select count(*) into cnt
  from public.user_photos
  where user_id = new.user_id;

  if cnt >= 100 then
    raise exception '写真は1人100枚までです。不要な写真を削除してください。';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_user_photos_limit_100 on public.user_photos;
create trigger trg_user_photos_limit_100
before insert on public.user_photos
for each row
execute function public.enforce_user_photos_limit_100();



