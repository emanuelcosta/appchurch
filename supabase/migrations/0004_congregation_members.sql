create table if not exists congregation_members (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null references congregations(id) on delete cascade,
  full_name text not null,
  birth_date date,
  rg text,
  marital_status text,
  cpf text,
  mother_name text,
  father_name text,
  spouse_name text,
  address text,
  nationality text,
  birthplace text,
  ministry_role text,
  ministry_role_since date,
  holy_spirit_baptism boolean,
  holy_spirit_baptism_date date,
  education text,
  children_count integer check (children_count is null or children_count >= 0),
  phone text,
  email text,
  import_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (congregation_id, import_key)
);

alter table congregation_members enable row level security;
create policy congregation_members_select on congregation_members
  for select using (is_congregation_member(congregation_id));
create policy congregation_members_write on congregation_members
  for all using (has_congregation_role(congregation_id, array['ADMIN','SECRETARIA']::text[]))
  with check (has_congregation_role(congregation_id, array['ADMIN','SECRETARIA']::text[]));
