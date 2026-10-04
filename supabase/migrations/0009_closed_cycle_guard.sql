-- 1) A policy de membros usava o papel 'SECRETARIA', mas o papel cadastrado
--    em memberships.role_code é 'SECRETARY'.
drop policy if exists congregation_members_write on congregation_members;
create policy congregation_members_write on congregation_members
  for all using (has_congregation_role(congregation_id, array['ADMIN','SECRETARY']::text[]))
  with check (has_congregation_role(congregation_id, array['ADMIN','SECRETARY']::text[]));

-- 2) Ciclo fechado é imutável: o banco recusa incluir, alterar ou excluir
--    lançamentos (receitas, pagamentos e rateios) com data dentro de um
--    ciclo fechado. Correções entram como ajuste no ciclo aberto.
--    Manutenção excepcional (script com backup): dentro da transação,
--    `set local app.allow_closed_cycle_edit = 'on';`.

create or replace function date_in_closed_cycle(p_congregation_id uuid, p_date date)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
    from accountability_closures
    where congregation_id = p_congregation_id
      and status = 'CLOSED'
      and p_date between period_start and period_end
  );
$$;

create or replace function guard_closed_cycle_date(
  p_congregation_id uuid,
  p_date date
) returns void
language plpgsql
as $$
begin
  if p_date is null or p_congregation_id is null then
    return;
  end if;
  if coalesce(current_setting('app.allow_closed_cycle_edit', true), '') = 'on' then
    return;
  end if;
  if date_in_closed_cycle(p_congregation_id, p_date) then
    raise exception 'A data % pertence a um ciclo já fechado. Use uma data do ciclo atual.',
      to_char(p_date, 'DD/MM/YYYY')
      using errcode = 'P0001', hint = 'Correções entram como lançamento de ajuste no ciclo aberto.';
  end if;
end;
$$;

-- Receitas: protege a data antiga e a nova (mudar a data não tira do ciclo fechado).
create or replace function trg_financial_entries_closed_cycle()
returns trigger
language plpgsql
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform guard_closed_cycle_date(old.congregation_id, old.entry_date);
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    perform guard_closed_cycle_date(new.congregation_id, new.entry_date);
    return new;
  end if;
  return old;
end;
$$;

drop trigger if exists financial_entries_closed_cycle on financial_entries;
create trigger financial_entries_closed_cycle
  before insert or update or delete on financial_entries
  for each row execute function trg_financial_entries_closed_cycle();

-- Linhas PIX/dinheiro seguem a data da receita.
create or replace function trg_financial_entry_lines_closed_cycle()
returns trigger
language plpgsql
as $$
declare
  v_entry_id uuid := case when tg_op = 'DELETE' then old.financial_entry_id else new.financial_entry_id end;
  v_congregation_id uuid;
  v_date date;
begin
  select congregation_id, entry_date into v_congregation_id, v_date
  from financial_entries where id = v_entry_id;
  perform guard_closed_cycle_date(v_congregation_id, v_date);
  if tg_op = 'UPDATE' and old.financial_entry_id <> new.financial_entry_id then
    select congregation_id, entry_date into v_congregation_id, v_date
    from financial_entries where id = old.financial_entry_id;
    perform guard_closed_cycle_date(v_congregation_id, v_date);
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists financial_entry_lines_closed_cycle on financial_entry_lines;
create trigger financial_entry_lines_closed_cycle
  before insert or update or delete on financial_entry_lines
  for each row execute function trg_financial_entry_lines_closed_cycle();

-- Pagamentos de contas.
create or replace function trg_payable_payments_closed_cycle()
returns trigger
language plpgsql
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform guard_closed_cycle_date(old.congregation_id, old.payment_date);
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    perform guard_closed_cycle_date(new.congregation_id, new.payment_date);
    return new;
  end if;
  return old;
end;
$$;

drop trigger if exists payable_payments_closed_cycle on payable_payments;
create trigger payable_payments_closed_cycle
  before insert or update or delete on payable_payments
  for each row execute function trg_payable_payments_closed_cycle();

-- Rateio entre fundos segue a data do pagamento.
create or replace function trg_payable_funding_allocations_closed_cycle()
returns trigger
language plpgsql
as $$
declare
  v_date date;
begin
  if tg_op in ('UPDATE', 'DELETE') and old.payment_id is not null then
    select payment_date into v_date from payable_payments where id = old.payment_id;
    perform guard_closed_cycle_date(old.congregation_id, v_date);
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  if new.payment_id is not null then
    select payment_date into v_date from payable_payments where id = new.payment_id;
    perform guard_closed_cycle_date(new.congregation_id, v_date);
  end if;
  return new;
end;
$$;

drop trigger if exists payable_funding_allocations_closed_cycle on payable_funding_allocations;
create trigger payable_funding_allocations_closed_cycle
  before insert or update or delete on payable_funding_allocations
  for each row execute function trg_payable_funding_allocations_closed_cycle();
