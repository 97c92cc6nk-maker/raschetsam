-- Supabase schema for the self-employed shifts app.
-- Run this in Supabase SQL Editor after every schema update.

create or replace function public.app_all_sections()
returns text[]
language sql
immutable
as $$
  select array[
    'schedule',
    'summary',
    'requisites',
    'documents',
    'checks',
    'log',
    'admin'
  ]::text[];
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.user_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  is_admin boolean not null default false,
  sections text[] not null default '{}'::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_access enable row level security;

create or replace function public.normalize_user_access()
returns trigger
language plpgsql
as $$
begin
  new.email = lower(coalesce(new.email, ''));
  new.sections = coalesce(new.sections, '{}'::text[]);

  if new.is_admin then
    new.sections = public.app_all_sections();
  else
    select coalesce(array_agg(distinct section_id order by section_id), '{}'::text[])
      into new.sections
    from unnest(new.sections) as section_id
    where section_id = any(public.app_all_sections());
  end if;

  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists user_access_normalize on public.user_access;
create trigger user_access_normalize
before insert or update on public.user_access
for each row
execute function public.normalize_user_access();

drop trigger if exists user_access_set_updated_at on public.user_access;
create trigger user_access_set_updated_at
before update on public.user_access
for each row
execute function public.set_updated_at();

create or replace function public.is_access_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select lower(coalesce(auth.jwt() ->> 'email', '')) = 'amankz2015@gmail.com'
    or exists (
      select 1
      from public.user_access ua
      where ua.user_id = auth.uid()
        and ua.is_admin = true
    );
$$;

create or replace function public.has_any_app_access()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select lower(coalesce(auth.jwt() ->> 'email', '')) = 'amankz2015@gmail.com'
    or exists (
      select 1
      from public.user_access ua
      where ua.user_id = auth.uid()
        and (
          ua.is_admin = true
          or coalesce(array_length(ua.sections, 1), 0) > 0
        )
    );
$$;

create or replace function public.has_app_section(section_name text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select lower(coalesce(auth.jwt() ->> 'email', '')) = 'amankz2015@gmail.com'
    or exists (
      select 1
      from public.user_access ua
      where ua.user_id = auth.uid()
        and (
          ua.is_admin = true
          or section_name = any(ua.sections)
        )
    );
$$;

create or replace function public.handle_auth_user_access()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_email text := lower(coalesce(new.email, ''));
  bootstrap_admin boolean := lower(coalesce(new.email, '')) = 'amankz2015@gmail.com';
begin
  insert into public.user_access (user_id, email, is_admin, sections)
  values (
    new.id,
    normalized_email,
    bootstrap_admin,
    case when bootstrap_admin then public.app_all_sections() else '{}'::text[] end
  )
  on conflict (user_id) do update
    set email = excluded.email,
        is_admin = user_access.is_admin or excluded.is_admin,
        sections = case
          when user_access.is_admin or excluded.is_admin then public.app_all_sections()
          else user_access.sections
        end,
        updated_at = now();

  return new;
end;
$$;

drop trigger if exists auth_user_access_created on auth.users;
create trigger auth_user_access_created
after insert or update of email on auth.users
for each row
execute function public.handle_auth_user_access();

insert into public.user_access (user_id, email, is_admin, sections)
select id, lower(email), true, public.app_all_sections()
from auth.users
where lower(email) = 'amankz2015@gmail.com'
on conflict (user_id) do update
  set email = excluded.email,
      is_admin = true,
      sections = public.app_all_sections(),
      updated_at = now();

drop policy if exists "user_access_select_own_or_admin" on public.user_access;
drop policy if exists "user_access_insert_admin" on public.user_access;
drop policy if exists "user_access_update_admin" on public.user_access;
drop policy if exists "user_access_delete_admin" on public.user_access;

create policy "user_access_select_own_or_admin"
  on public.user_access
  for select
  to authenticated
  using (auth.uid() = user_id or public.is_access_admin());

create policy "user_access_insert_admin"
  on public.user_access
  for insert
  to authenticated
  with check (public.is_access_admin());

create policy "user_access_update_admin"
  on public.user_access
  for update
  to authenticated
  using (public.is_access_admin())
  with check (public.is_access_admin());

create policy "user_access_delete_admin"
  on public.user_access
  for delete
  to authenticated
  using (public.is_access_admin());

create table if not exists public.workspace_states (
  workspace_key text primary key default 'main',
  data jsonb not null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.workspace_states enable row level security;

drop trigger if exists workspace_states_set_updated_at on public.workspace_states;
create trigger workspace_states_set_updated_at
before update on public.workspace_states
for each row
execute function public.set_updated_at();

drop policy if exists "workspace_states_select_allowed" on public.workspace_states;
drop policy if exists "workspace_states_insert_allowed" on public.workspace_states;
drop policy if exists "workspace_states_update_allowed" on public.workspace_states;
drop policy if exists "workspace_states_delete_admin" on public.workspace_states;

create policy "workspace_states_select_allowed"
  on public.workspace_states
  for select
  to authenticated
  using (public.has_any_app_access());

create policy "workspace_states_insert_allowed"
  on public.workspace_states
  for insert
  to authenticated
  with check (public.has_any_app_access());

create policy "workspace_states_update_allowed"
  on public.workspace_states
  for update
  to authenticated
  using (public.has_any_app_access())
  with check (public.has_any_app_access());

create policy "workspace_states_delete_admin"
  on public.workspace_states
  for delete
  to authenticated
  using (public.is_access_admin());

-- Legacy per-user table. It is kept so old cloud data can be migrated into workspace_states.
create table if not exists public.app_states (
  user_id uuid not null references auth.users(id) on delete cascade,
  state_key text not null default 'main',
  data jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, state_key)
);

alter table public.app_states enable row level security;

drop trigger if exists app_states_set_updated_at on public.app_states;
create trigger app_states_set_updated_at
before update on public.app_states
for each row
execute function public.set_updated_at();

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

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.user_access to authenticated;
grant select, insert, update, delete on public.workspace_states to authenticated;
grant select, insert, update, delete on public.app_states to authenticated;
