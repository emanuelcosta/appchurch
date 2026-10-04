create table if not exists tithe_distribution_settings (
  congregation_id uuid primary key references congregations(id) on delete cascade,
  leader_percentage numeric(7,4) not null default 20
    check (leader_percentage >= 0 and leader_percentage <= 100),
  updated_at timestamptz not null default now()
);

alter table tithe_distribution_settings enable row level security;

create policy tithe_distribution_settings_select
  on tithe_distribution_settings for select
  using (is_congregation_member(congregation_id));

create policy tithe_distribution_settings_write
  on tithe_distribution_settings for all
  using (has_congregation_role(congregation_id, array['ADMIN','TREASURER']::text[]))
  with check (has_congregation_role(congregation_id, array['ADMIN','TREASURER']::text[]));
