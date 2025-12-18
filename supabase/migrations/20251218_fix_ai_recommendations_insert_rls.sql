-- Allow inserting recommendations only when the referenced session belongs to the current user
-- (Rust API inserts with user's JWT, so this must pass RLS)

drop policy if exists "ai_recommendations_insert_own" on public.ai_recommendations;

create policy "ai_recommendations_insert_own" on public.ai_recommendations
  for insert
  with check (
    exists (
      select 1
      from public.ai_sessions s
      where s.id = ai_recommendations.session_id
        and s.user_id = auth.uid()
    )
  );


