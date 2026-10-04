create extension if not exists "pgcrypto";

create table if not exists organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  timezone text not null default 'America/Fortaleza',
  currency_code text not null default 'BRL',
  created_at timestamptz not null default now()
);

create table if not exists congregations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, name)
);

create table if not exists profiles (
  id uuid primary key,
  full_name text not null,
  email text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists congregation_accounts (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null unique references congregations(id),
  auth_user_id uuid not null unique,
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'RESTRICTED', 'DISABLED')),
  first_access_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id),
  congregation_id uuid not null references congregations(id),
  role_code text not null check (role_code in ('ADMIN', 'TREASURER', 'ASSISTANT', 'REVIEWER', 'SECRETARY', 'VIEWER', 'AUDITOR')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (user_id, congregation_id, role_code)
);

create table if not exists accountability_cycles (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null references congregations(id),
  name text not null,
  start_date date not null,
  end_date date not null,
  opening_balance numeric(19,4) not null default 0,
  status text not null default 'DRAFT' check (status in ('DRAFT', 'OPEN', 'IN_REVIEW', 'PENDING_APPROVAL', 'CLOSED', 'REOPENED', 'CANCELLED')),
  created_at timestamptz not null default now(),
  check (start_date <= end_date)
);

create index if not exists idx_cycles_congregation_dates on accountability_cycles (congregation_id, start_date, end_date);

create table if not exists sync_operations (
  id uuid primary key,
  organization_id uuid not null references organizations(id),
  congregation_id uuid not null references congregations(id),
  operation_type text not null,
  entity_type text not null,
  entity_id uuid not null,
  payload jsonb not null,
  depends_on uuid references sync_operations(id),
  base_version integer,
  status text not null default 'PENDING' check (status in ('PENDING', 'SYNCED', 'CONFLICT', 'DISCARDED')),
  cursor bigint generated always as identity unique,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (congregation_id, id)
);

create index if not exists idx_sync_operations_pull
  on sync_operations (congregation_id, cursor);

create table if not exists entry_types (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null references congregations(id),
  code text not null,
  name text not null,
  active boolean not null default true,
  requires_contributor boolean not null default false,
  allows_anonymous boolean not null default true,
  created_at timestamptz not null default now(),
  unique (congregation_id, code)
);

create table if not exists revenue_categories (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null references congregations(id),
  entry_type_id uuid not null references entry_types(id),
  code text not null,
  name text not null,
  purpose text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (congregation_id, entry_type_id, code)
);

create table if not exists financial_entries (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null references congregations(id),
  cycle_id uuid not null references accountability_cycles(id),
  entry_type_id uuid not null references entry_types(id),
  revenue_category_id uuid references revenue_categories(id),
  entry_date date not null,
  description text not null,
  total_amount numeric(19,4) not null check (total_amount > 0),
  status text not null default 'DRAFT' check (status in ('DRAFT', 'CONFIRMED', 'CANCELLED', 'REVERSED')),
  version integer not null default 1 check (version > 0),
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists financial_entry_lines (
  id uuid primary key default gen_random_uuid(),
  financial_entry_id uuid not null references financial_entries(id),
  payment_method text not null check (payment_method in ('CASH', 'PIX')),
  amount numeric(19,4) not null check (amount > 0),
  created_at timestamptz not null default now()
);

create table if not exists financial_movements (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null references congregations(id),
  cycle_id uuid not null references accountability_cycles(id),
  source_type text not null,
  source_id uuid not null,
  direction text not null check (direction in ('IN', 'OUT')),
  amount numeric(19,4) not null check (amount > 0),
  occurred_at date not null,
  idempotency_key uuid not null unique,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  unique (source_type, source_id, direction)
);

create table if not exists expense_categories (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null references congregations(id),
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (congregation_id, name)
);

create table if not exists payables (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null references congregations(id),
  cycle_id uuid not null references accountability_cycles(id),
  category_id uuid not null references expense_categories(id),
  description text not null,
  issue_date date not null,
  due_date date not null,
  amount numeric(19,4) not null check (amount > 0),
  status text not null default 'OPEN' check (status in ('OPEN', 'OVERDUE', 'PARTIALLY_PAID', 'PAID', 'CANCELLED')),
  notification_days_before integer not null default 3 check (notification_days_before between 0 and 365),
  created_at timestamptz not null default now(),
  check (due_date >= issue_date)
);

create table if not exists payable_funding_allocations (
  id uuid primary key default gen_random_uuid(),
  payable_id uuid not null references payables(id),
  congregation_id uuid not null references congregations(id),
  revenue_type_code text not null check (revenue_type_code in ('DIZIMOS', 'OFERTAS_CULTO', 'OFERTAS_ALCADAS')),
  amount numeric(19,4) not null check (amount > 0),
  unique (payable_id, revenue_type_code)
);

create table if not exists payable_payments (
  id uuid primary key default gen_random_uuid(),
  payable_id uuid not null references payables(id),
  congregation_id uuid not null references congregations(id),
  payment_date date not null,
  amount numeric(19,4) not null check (amount > 0),
  payment_method text not null check (payment_method in ('CASH', 'PIX')),
  created_at timestamptz not null default now()
);

create table if not exists notification_preferences (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null unique references congregations(id),
  due_date_days_before integer not null default 3 check (due_date_days_before between 0 and 365),
  due_date_time time not null default '08:00',
  notify_on_due_date boolean not null default true,
  repeat_after_due boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null references congregations(id),
  user_id uuid not null references profiles(id),
  token text not null,
  platform text not null check (platform in ('ANDROID', 'IOS', 'WEB')),
  active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, token)
);

create table if not exists notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null references congregations(id),
  payable_id uuid references payables(id),
  recipient_user_id uuid references profiles(id),
  deduplication_key text not null unique,
  notification_type text not null check (notification_type in ('BEFORE_DUE', 'DUE_TODAY', 'OVERDUE', 'BIRTHDAY')),
  status text not null default 'PENDING' check (status in ('PENDING', 'PROCESSING', 'SENT', 'FAILED', 'SKIPPED')),
  payload jsonb not null,
  attempts integer not null default 0 check (attempts >= 0),
  scheduled_for timestamptz not null,
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_notification_deliveries_pending
  on notification_deliveries (status, scheduled_for);

create table if not exists outbox_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  congregation_id uuid not null references congregations(id),
  event_type text not null,
  aggregate_type text not null,
  aggregate_id uuid not null,
  payload jsonb not null,
  status text not null default 'PENDING' check (status in ('PENDING', 'PROCESSING', 'PROCESSED', 'FAILED')),
  attempts integer not null default 0 check (attempts >= 0),
  available_at timestamptz not null default now(),
  processed_at timestamptz,
  last_error text,
  created_at timestamptz not null default now()
);

create index if not exists idx_outbox_pending
  on outbox_events (status, available_at);

create table if not exists audit_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  congregation_id uuid references congregations(id),
  actor_id uuid references profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  reason text,
  before_data jsonb,
  after_data jsonb,
  request_id text,
  created_at timestamptz not null default now()
);

alter table organizations enable row level security;
alter table congregations enable row level security;
alter table accountability_cycles enable row level security;
alter table sync_operations enable row level security;
alter table financial_entries enable row level security;
alter table revenue_categories enable row level security;
alter table financial_entry_lines enable row level security;
alter table financial_movements enable row level security;
alter table expense_categories enable row level security;
alter table payables enable row level security;
alter table payable_payments enable row level security;
alter table payable_funding_allocations enable row level security;
alter table notification_preferences enable row level security;
alter table device_push_tokens enable row level security;
alter table notification_deliveries enable row level security;
alter table outbox_events enable row level security;
alter table audit_events enable row level security;
