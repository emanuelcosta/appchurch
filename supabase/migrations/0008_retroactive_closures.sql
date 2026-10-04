-- Fechamentos retroativos conferidos com a aba Dashboard da planilha.
insert into accountability_closures (
  congregation_id, period_start, period_end, status, notes, closed_at
)
select
  'f4f1212d-b728-4a42-8fee-fec6abab33f1',
  v.period_start,
  v.period_end,
  'CLOSED',
  'Fechamento retroativo importado da planilha.',
  now()
from (values
  ('2026-04-01'::date, '2026-05-10'::date),
  ('2026-05-11'::date, '2026-06-14'::date),
  ('2026-06-15'::date, '2026-07-12'::date),
  ('2026-07-13'::date, '2026-08-09'::date),
  ('2026-08-10'::date, '2026-09-13'::date),
  ('2026-09-14'::date, '2026-10-11'::date)
) as v(period_start, period_end)
on conflict (congregation_id, period_start, period_end)
do update set
  status = 'CLOSED',
  notes = excluded.notes,
  closed_at = now();

insert into accountability_closure_balances (
  closure_id, congregation_id, fund_code,
  opening_balance, revenue_total, expense_total, closing_balance
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
join (values
  ('2026-04-01'::date, '2026-05-10'::date, 'OFERTAS_CULTO', 100.00::numeric, 269.75::numeric, 350.75::numeric, 19.00::numeric),
  ('2026-04-01'::date, '2026-05-10'::date, 'DIZIMOS', 0.00::numeric, 2515.86::numeric, 298.04::numeric, 2217.82::numeric),
  ('2026-04-01'::date, '2026-05-10'::date, 'OFERTAS_ALCADAS', 0.00::numeric, 170.00::numeric, 44.00::numeric, 126.00::numeric),
  ('2026-05-11'::date, '2026-06-14'::date, 'OFERTAS_CULTO', 19.00::numeric, 90.30::numeric, 95.00::numeric, 14.30::numeric),
  ('2026-05-11'::date, '2026-06-14'::date, 'DIZIMOS', 0.00::numeric, 2059.09::numeric, 306.35::numeric, 1752.74::numeric),
  ('2026-05-11'::date, '2026-06-14'::date, 'OFERTAS_ALCADAS', 126.00::numeric, 241.00::numeric, 12.98::numeric, 354.02::numeric),
  ('2026-06-15'::date, '2026-07-12'::date, 'OFERTAS_CULTO', 14.30::numeric, 53.55::numeric, 49.74::numeric, 18.11::numeric),
  ('2026-06-15'::date, '2026-07-12'::date, 'DIZIMOS', 0.00::numeric, 878.59::numeric, 300.00::numeric, 578.59::numeric),
  ('2026-06-15'::date, '2026-07-12'::date, 'OFERTAS_ALCADAS', 354.02::numeric, 326.72::numeric, 494.80::numeric, 185.94::numeric),
  ('2026-07-13'::date, '2026-08-09'::date, 'OFERTAS_CULTO', 18.11::numeric, 74.25::numeric, 81.36::numeric, 11.00::numeric),
  ('2026-07-13'::date, '2026-08-09'::date, 'DIZIMOS', 0.00::numeric, 770.00::numeric, 422.72::numeric, 347.28::numeric),
  ('2026-07-13'::date, '2026-08-09'::date, 'OFERTAS_ALCADAS', 185.94::numeric, 310.00::numeric, 50.00::numeric, 445.94::numeric),
  ('2026-08-10'::date, '2026-09-13'::date, 'OFERTAS_CULTO', 11.00::numeric, 79.25::numeric, 54.98::numeric, 35.27::numeric),
  ('2026-08-10'::date, '2026-09-13'::date, 'DIZIMOS', 0.00::numeric, 887.00::numeric, 350.00::numeric, 537.00::numeric),
  ('2026-08-10'::date, '2026-09-13'::date, 'OFERTAS_ALCADAS', 445.94::numeric, 115.40::numeric, 0.00::numeric, 561.34::numeric),
  ('2026-09-14'::date, '2026-10-11'::date, 'OFERTAS_CULTO', 35.27::numeric, 19.10::numeric, 16.00::numeric, 38.37::numeric),
  ('2026-09-14'::date, '2026-10-11'::date, 'DIZIMOS', 0.00::numeric, 363.00::numeric, 0.00::numeric, 363.00::numeric),
  ('2026-09-14'::date, '2026-10-11'::date, 'OFERTAS_ALCADAS', 561.34::numeric, 430.74::numeric, 972.69::numeric, 19.39::numeric)
) as v(period_start, period_end, fund_code, opening_balance, revenue_total, expense_total, closing_balance)
  on c.period_start = v.period_start
 and c.period_end = v.period_end
where c.congregation_id = 'f4f1212d-b728-4a42-8fee-fec6abab33f1'
on conflict (closure_id, fund_code)
do update set
  opening_balance = excluded.opening_balance,
  revenue_total = excluded.revenue_total,
  expense_total = excluded.expense_total,
  closing_balance = excluded.closing_balance;

insert into accountability_closure_allocations (
  closure_id, congregation_id, fund_code, sequence, base_type,
  base_amount, percentage, amount, destination_code, destination_name
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
join (values
  ('2026-04-01'::date, '2026-05-10'::date, 1, 'GROSS_REVENUE', 2515.86::numeric, 20.00::numeric, 503.172::numeric, 'DIRIGENTE', 'Dirigente'),
  ('2026-04-01'::date, '2026-05-10'::date, 2, 'BALANCE_AFTER_EXPENSES', 2217.82::numeric, 80.00::numeric, 1714.648::numeric, 'SEDE', 'Igreja sede'),
  ('2026-05-11'::date, '2026-06-14'::date, 1, 'GROSS_REVENUE', 2059.09::numeric, 20.00::numeric, 411.818::numeric, 'DIRIGENTE', 'Dirigente'),
  ('2026-05-11'::date, '2026-06-14'::date, 2, 'BALANCE_AFTER_EXPENSES', 1752.74::numeric, 80.00::numeric, 1340.922::numeric, 'SEDE', 'Igreja sede'),
  ('2026-06-15'::date, '2026-07-12'::date, 1, 'GROSS_REVENUE', 878.59::numeric, 20.00::numeric, 175.718::numeric, 'DIRIGENTE', 'Dirigente'),
  ('2026-06-15'::date, '2026-07-12'::date, 2, 'BALANCE_AFTER_EXPENSES', 578.59::numeric, 80.00::numeric, 402.872::numeric, 'SEDE', 'Igreja sede'),
  ('2026-07-13'::date, '2026-08-09'::date, 1, 'GROSS_REVENUE', 770.00::numeric, 20.00::numeric, 154.00::numeric, 'DIRIGENTE', 'Dirigente'),
  ('2026-07-13'::date, '2026-08-09'::date, 2, 'BALANCE_AFTER_EXPENSES', 347.28::numeric, 80.00::numeric, 193.28::numeric, 'SEDE', 'Igreja sede'),
  ('2026-08-10'::date, '2026-09-13'::date, 1, 'GROSS_REVENUE', 887.00::numeric, 20.00::numeric, 177.40::numeric, 'DIRIGENTE', 'Dirigente'),
  ('2026-08-10'::date, '2026-09-13'::date, 2, 'BALANCE_AFTER_EXPENSES', 537.00::numeric, 80.00::numeric, 359.60::numeric, 'SEDE', 'Igreja sede'),
  ('2026-09-14'::date, '2026-10-11'::date, 1, 'GROSS_REVENUE', 363.00::numeric, 20.00::numeric, 72.60::numeric, 'DIRIGENTE', 'Dirigente'),
  ('2026-09-14'::date, '2026-10-11'::date, 2, 'BALANCE_AFTER_EXPENSES', 363.00::numeric, 80.00::numeric, 290.40::numeric, 'SEDE', 'Igreja sede')
) as v(period_start, period_end, sequence, base_type, base_amount, percentage, amount, destination_code, destination_name)
  on c.period_start = v.period_start
 and c.period_end = v.period_end
where c.congregation_id = 'f4f1212d-b728-4a42-8fee-fec6abab33f1'
  and not exists (
    select 1
    from accountability_closure_allocations a
    where a.closure_id = c.id
      and a.fund_code = 'DIZIMOS'
      and a.sequence = v.sequence
  );
