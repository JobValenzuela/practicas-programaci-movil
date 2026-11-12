-- Ejecutar con una cuenta administradora en SQL Editor; nunca desde el cliente.
begin;
create table public.tasks (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id),
  title text not null check (length(trim(title)) between 1 and 160),
  description text not null default '' check (length(description) <= 4000),
  completed boolean not null default false,
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index tasks_owner_updated on public.tasks(user_id, updated_at, id);
alter table public.tasks enable row level security;
revoke all on public.tasks from anon;
grant select, insert, update on public.tasks to authenticated;
create policy tasks_select_own on public.tasks for select to authenticated using ((select auth.uid()) = user_id);
create policy tasks_insert_own on public.tasks for insert to authenticated with check ((select auth.uid()) = user_id);
create policy tasks_update_own on public.tasks for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
-- No DELETE: conservar tombstones evita resurrecciones al descargar otros dispositivos.
create function public.synclab_task_timestamp() returns trigger language plpgsql set search_path = '' as $$
begin
  if TG_OP = 'UPDATE' then
    new.created_at := old.created_at;
    new.user_id := old.user_id;
  end if;
  new.updated_at := clock_timestamp();
  return new;
end;
$$;
create trigger synclab_task_timestamp before insert or update on public.tasks for each row execute function public.synclab_task_timestamp();
commit;
