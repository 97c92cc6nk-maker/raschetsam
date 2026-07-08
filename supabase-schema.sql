-- Supabase schema for the self-employed shifts app.
-- Run this in Supabase SQL Editor once for the project.

create table if not exists public.app_states (
  user_id uuid not null references auth.users(id) on delete cascade,
  state_key text not null default 'main',
  data jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, state_key)
);

alter table public.app_states enable row level security;

drop policy if exists "app_states_select_own" on public.app_states;
drop policy if exists "app_states_insert_own" on public.app_states;
drop policy if exists "app_states_update_own" on public.app_states;
drop policy if exists "app_states_delete_own" on public.app_states;

create policy "app_states_select_own"
  on public.app_states
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "app_states_insert_own"
  on public.app_states
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "app_states_update_own"
  on public.app_states
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "app_states_delete_own"
  on public.app_states
  for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists app_states_set_updated_at on public.app_states;

create trigger app_states_set_updated_at
before update on public.app_states
for each row
execute function public.set_updated_at();