-- Compatibilidade com a primeira versão do rateio de origem.
-- A origem passou a ser armazenada em payable_funding_allocations.
alter table if exists payables
  drop column if exists funding_revenue_type_id;

alter table if exists payable_funding_allocations
  add column if not exists payment_id uuid references payable_payments(id) on delete cascade;

alter table if exists payable_funding_allocations
  drop constraint if exists payable_funding_allocations_payable_id_revenue_type_code_key;

create index if not exists idx_payable_funding_allocations_payable
  on payable_funding_allocations(payable_id);

create index if not exists idx_payable_funding_allocations_payment
  on payable_funding_allocations(payment_id);
