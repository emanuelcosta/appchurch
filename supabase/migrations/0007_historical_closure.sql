-- Fechamento histórico conferido com a planilha:
-- 14/09/2026 a 11/10/2026.
insert into accountability_closures (
  congregation_id,
  period_start,
  period_end,
  status,
  notes
)
values (
  'f4f1212d-b728-4a42-8fee-fec6abab33f1',
  '2026-09-14',
  '2026-10-11',
  'CLOSED',
  'Fechamento histórico importado e conferido com a planilha da tesouraria.'
)
on conflict (congregation_id, period_start, period_end)
do update set
  status = excluded.status,
  notes = excluded.notes,
  closed_at = now();

insert into accountability_closure_balances (
  closure_id,
  congregation_id,
  fund_code,
  opening_balance,
  revenue_total,
  expense_total,
  closing_balance
)
select
  c.id,
  c.congregation_id,
  v.fund_code,
  v.opening_balance,
  v.revenue_total,
  v.expense_total,
  v.closing_balance
from accountability_closures c
cross join (
  values
    ('OFERTAS_CULTO', 35.27::numeric, 19.10::numeric, 16.00::numeric, 38.37::numeric),
    ('DIZIMOS', 0.00::numeric, 363.00::numeric, 0.00::numeric, 363.00::numeric),
    ('OFERTAS_ALCADAS', 561.34::numeric, 430.74::numeric, 972.69::numeric, 19.39::numeric)
) as v(fund_code, opening_balance, revenue_total, expense_total, closing_balance)
where c.congregation_id = 'f4f1212d-b728-4a42-8fee-fec6abab33f1'
  and c.period_start = '2026-09-14'
  and c.period_end = '2026-10-11'
on conflict (closure_id, fund_code)
do update set
  opening_balance = excluded.opening_balance,
  revenue_total = excluded.revenue_total,
  expense_total = excluded.expense_total,
  closing_balance = excluded.closing_balance;

insert into accountability_closure_allocations (
  closure_id,
  congregation_id,
  fund_code,
  sequence,
  base_type,
  base_amount,
  percentage,
  amount,
  destination_code,
  destination_name
)
select
  c.id,
  c.congregation_id,
  'DIZIMOS',
  v.sequence,
  v.base_type,
  v.base_amount,
  v.percentage,
  v.amount,
  v.destination_code,
  v.destination_name
from accountability_closures c
cross join (
  values
    (1, 'GROSS_REVENUE', 363.00::numeric, 20.00::numeric, 72.60::numeric, 'DIRIGENTE', 'Dirigente'),
    (2, 'BALANCE_AFTER_EXPENSES', 363.00::numeric, 80.00::numeric, 290.40::numeric, 'SEDE', 'Igreja sede')
) as v(sequence, base_type, base_amount, percentage, amount, destination_code, destination_name)
where c.congregation_id = 'f4f1212d-b728-4a42-8fee-fec6abab33f1'
  and c.period_start = '2026-09-14'
  and c.period_end = '2026-10-11'
  and not exists (
    select 1
    from accountability_closure_allocations a
    where a.closure_id = c.id
      and a.fund_code = 'DIZIMOS'
      and a.sequence = v.sequence
  );
