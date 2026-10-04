create table if not exists financial_funds (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null references congregations(id) on delete cascade,
  code text not null,
  name text not null,
  active boolean not null default true,
  allows_revenue boolean not null default true,
  allows_expense boolean not null default true,
  allows_distribution boolean not null default false,
  created_at timestamptz not null default now(),
  unique (congregation_id, code)
);

create table if not exists distribution_rules (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null references congregations(id) on delete cascade,
  fund_code text not null,
  sequence integer not null check (sequence > 0),
  base_type text not null check (
    base_type in ('GROSS_REVENUE', 'BALANCE_AFTER_EXPENSES', 'CLOSING_BALANCE')
  ),
  percentage numeric(7,4) check (percentage >= 0 and percentage <= 100),
  fixed_amount numeric(19,4) check (fixed_amount is null or fixed_amount >= 0),
  destination_code text not null,
  destination_name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  check (percentage is not null or fixed_amount is not null),
  unique (congregation_id, fund_code, sequence)
);

create table if not exists accountability_closures (
  id uuid primary key default gen_random_uuid(),
  congregation_id uuid not null references congregations(id) on delete cascade,
  period_start date not null,
  period_end date,
  status text not null default 'OPEN'
    check (status in (
      'OPEN', 'IN_REVIEW', 'PENDING_APPROVAL', 'APPROVED',
      'CLOSED', 'REOPENED', 'CANCELLED'
    )),
  notes text,
  created_by uuid references profiles(id),
  approved_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  closed_at timestamptz,
  check (period_start <= period_end),
  unique (congregation_id, period_start, period_end)
);

create table if not exists accountability_closure_balances (
  id uuid primary key default gen_random_uuid(),
  closure_id uuid not null references accountability_closures(id) on delete cascade,
  congregation_id uuid not null references congregations(id) on delete cascade,
  fund_code text not null,
  opening_balance numeric(19,4) not null default 0,
  revenue_total numeric(19,4) not null default 0,
  expense_total numeric(19,4) not null default 0,
  closing_balance numeric(19,4) not null default 0,
  created_at timestamptz not null default now(),
  unique (closure_id, fund_code)
);

create table if not exists accountability_closure_allocations (
  id uuid primary key default gen_random_uuid(),
  closure_id uuid not null references accountability_closures(id) on delete cascade,
  congregation_id uuid not null references congregations(id) on delete cascade,
  fund_code text not null,
  rule_id uuid references distribution_rules(id),
  sequence integer not null check (sequence > 0),
  base_type text not null check (
    base_type in ('GROSS_REVENUE', 'BALANCE_AFTER_EXPENSES', 'CLOSING_BALANCE')
  ),
  base_amount numeric(19,4) not null default 0,
  percentage numeric(7,4),
  amount numeric(19,4) not null check (amount >= 0),
  destination_code text not null,
  destination_name text not null,
  created_at timestamptz not null default now()
);

create table if not exists accountability_closure_transfers (
  id uuid primary key default gen_random_uuid(),
  allocation_id uuid not null references accountability_closure_allocations(id) on delete cascade,
  closure_id uuid not null references accountability_closures(id) on delete cascade,
  congregation_id uuid not null references congregations(id) on delete cascade,
  destination_code text not null,
  destination_name text not null,
  amount numeric(19,4) not null check (amount > 0),
  transfer_date date,
  payment_method text check (payment_method is null or payment_method in ('CASH', 'PIX', 'TRANSFER')),
  status text not null default 'PLANNED'
    check (status in ('PLANNED', 'PAID', 'CANCELLED')),
  receipt_attachment_id uuid,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_distribution_rules_fund
  on distribution_rules (congregation_id, fund_code, sequence);

create index if not exists idx_closures_period
  on accountability_closures (congregation_id, period_start, period_end);

create unique index if not exists idx_one_open_closure_per_congregation
  on accountability_closures (congregation_id)
  where status in ('OPEN', 'IN_REVIEW', 'PENDING_APPROVAL', 'APPROVED');

create index if not exists idx_closure_balances_fund
  on accountability_closure_balances (closure_id, fund_code);

create index if not exists idx_closure_transfers_status
  on accountability_closure_transfers (closure_id, status);

alter table financial_funds enable row level security;
alter table distribution_rules enable row level security;
alter table accountability_closures enable row level security;
alter table accountability_closure_balances enable row level security;
alter table accountability_closure_allocations enable row level security;
alter table accountability_closure_transfers enable row level security;

create policy financial_funds_select on financial_funds for select
  using (is_congregation_member(congregation_id));
create policy financial_funds_write on financial_funds for all
  using (has_congregation_role(congregation_id, array['ADMIN','TREASURER']::text[]))
  with check (has_congregation_role(congregation_id, array['ADMIN','TREASURER']::text[]));

create policy distribution_rules_select on distribution_rules for select
  using (is_congregation_member(congregation_id));
create policy distribution_rules_write on distribution_rules for all
  using (has_congregation_role(congregation_id, array['ADMIN','TREASURER']::text[]))
  with check (has_congregation_role(congregation_id, array['ADMIN','TREASURER']::text[]));

create policy closures_select on accountability_closures for select
  using (is_congregation_member(congregation_id));
create policy closures_write on accountability_closures for all
  using (has_congregation_role(congregation_id, array['ADMIN','TREASURER']::text[]))
  with check (has_congregation_role(congregation_id, array['ADMIN','TREASURER']::text[]));

create policy closure_balances_select on accountability_closure_balances for select
  using (is_congregation_member(congregation_id));
create policy closure_balances_write on accountability_closure_balances for all
  using (has_congregation_role(congregation_id, array['ADMIN','TREASURER']::text[]))
  with check (has_congregation_role(congregation_id, array['ADMIN','TREASURER']::text[]));

create policy closure_allocations_select on accountability_closure_allocations for select
  using (is_congregation_member(congregation_id));
create policy closure_allocations_write on accountability_closure_allocations for all
  using (has_congregation_role(congregation_id, array['ADMIN','TREASURER']::text[]))
  with check (has_congregation_role(congregation_id, array['ADMIN','TREASURER']::text[]));

create policy closure_transfers_select on accountability_closure_transfers for select
  using (is_congregation_member(congregation_id));
create policy closure_transfers_write on accountability_closure_transfers for all
  using (has_congregation_role(congregation_id, array['ADMIN','TREASURER']::text[]))
  with check (has_congregation_role(congregation_id, array['ADMIN','TREASURER']::text[]));

insert into financial_funds
  (congregation_id, code, name, allows_distribution)
values
  ('f4f1212d-b728-4a42-8fee-fec6abab33f1', 'DIZIMOS', 'Dízimos', true),
  ('f4f1212d-b728-4a42-8fee-fec6abab33f1', 'OFERTAS_CULTO', 'Ofertas de culto', false),
  ('f4f1212d-b728-4a42-8fee-fec6abab33f1', 'OFERTAS_ALCADAS', 'Ofertas alçadas', false)
on conflict (congregation_id, code) do nothing;

insert into distribution_rules
  (congregation_id, fund_code, sequence, base_type, percentage, destination_code, destination_name)
values
  ('f4f1212d-b728-4a42-8fee-fec6abab33f1', 'DIZIMOS', 1, 'GROSS_REVENUE', 20, 'DIRIGENTE', 'Dirigente'),
  ('f4f1212d-b728-4a42-8fee-fec6abab33f1', 'DIZIMOS', 2, 'BALANCE_AFTER_EXPENSES', 80, 'SEDE', 'Igreja sede')
on conflict (congregation_id, fund_code, sequence) do nothing;
