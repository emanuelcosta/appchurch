create or replace function public.is_congregation_member(target_congregation_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.congregation_id = target_congregation_id
      and m.active = true
  );
$$;

create or replace function public.has_congregation_role(
  target_congregation_id uuid,
  allowed_roles text[]
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.congregation_id = target_congregation_id
      and m.active = true
      and m.role_code = any(allowed_roles)
  );
$$;

revoke all on function public.is_congregation_member(uuid) from public;
revoke all on function public.has_congregation_role(uuid, text[]) from public;
grant execute on function public.is_congregation_member(uuid) to authenticated;
grant execute on function public.has_congregation_role(uuid, text[]) to authenticated;

create policy profiles_self_or_member_select on profiles
  for select to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1 from memberships m
      where m.user_id = profiles.id
        and public.is_congregation_member(m.congregation_id)
    )
  );

create policy memberships_member_select on memberships
  for select to authenticated
  using (public.is_congregation_member(congregation_id));

create policy memberships_admin_manage on memberships
  for all to authenticated
  using (public.has_congregation_role(congregation_id, array['ADMIN']))
  with check (public.has_congregation_role(congregation_id, array['ADMIN']));

create policy congregations_member_select on congregations
  for select to authenticated
  using (public.is_congregation_member(id));

create policy congregations_admin_update on congregations
  for update to authenticated
  using (public.has_congregation_role(id, array['ADMIN']))
  with check (public.has_congregation_role(id, array['ADMIN']));

create policy cycles_member_select on accountability_cycles
  for select to authenticated
  using (public.is_congregation_member(congregation_id));

create policy cycles_treasury_manage on accountability_cycles
  for insert to authenticated
  with check (public.has_congregation_role(congregation_id, array['ADMIN', 'TREASURER']));

create policy cycles_treasury_update on accountability_cycles
  for update to authenticated
  using (public.has_congregation_role(congregation_id, array['ADMIN', 'TREASURER']))
  with check (public.has_congregation_role(congregation_id, array['ADMIN', 'TREASURER']));

create policy entry_types_member_select on entry_types
  for select to authenticated
  using (public.is_congregation_member(congregation_id));

create policy entry_types_admin_manage on entry_types
  for all to authenticated
  using (public.has_congregation_role(congregation_id, array['ADMIN']))
  with check (public.has_congregation_role(congregation_id, array['ADMIN']));

create policy revenue_categories_member_select on revenue_categories
  for select to authenticated
  using (public.is_congregation_member(congregation_id));

create policy revenue_categories_admin_manage on revenue_categories
  for all to authenticated
  using (public.has_congregation_role(congregation_id, array['ADMIN']))
  with check (public.has_congregation_role(congregation_id, array['ADMIN']));

create policy categories_member_select on expense_categories
  for select to authenticated
  using (public.is_congregation_member(congregation_id));

create policy categories_admin_manage on expense_categories
  for all to authenticated
  using (public.has_congregation_role(congregation_id, array['ADMIN']))
  with check (public.has_congregation_role(congregation_id, array['ADMIN']));

create policy payables_member_select on payables
  for select to authenticated
  using (public.is_congregation_member(congregation_id));

create policy payables_treasury_insert on payables
  for insert to authenticated
  with check (public.has_congregation_role(congregation_id, array['ADMIN', 'TREASURER', 'ASSISTANT']));

create policy payables_treasury_update on payables
  for update to authenticated
  using (public.has_congregation_role(congregation_id, array['ADMIN', 'TREASURER', 'ASSISTANT']))
  with check (public.has_congregation_role(congregation_id, array['ADMIN', 'TREASURER', 'ASSISTANT']));

create policy payable_payments_member_select on payable_payments
  for select to authenticated
  using (public.is_congregation_member(congregation_id));

create policy payable_payments_treasury_insert on payable_payments
  for insert to authenticated
  with check (public.has_congregation_role(congregation_id, array['ADMIN', 'TREASURER', 'ASSISTANT']));

create policy funding_allocations_member_select on payable_funding_allocations
  for select to authenticated
  using (public.is_congregation_member(congregation_id));

create policy funding_allocations_treasury_insert on payable_funding_allocations
  for insert to authenticated
  with check (public.has_congregation_role(congregation_id, array['ADMIN', 'TREASURER', 'ASSISTANT']));

create policy preferences_member_select on notification_preferences
  for select to authenticated
  using (public.is_congregation_member(congregation_id));

create policy preferences_admin_manage on notification_preferences
  for all to authenticated
  using (public.has_congregation_role(congregation_id, array['ADMIN']))
  with check (public.has_congregation_role(congregation_id, array['ADMIN']));

create policy push_tokens_owner_manage on device_push_tokens
  for all to authenticated
  using (user_id = auth.uid() and public.is_congregation_member(congregation_id))
  with check (user_id = auth.uid() and public.is_congregation_member(congregation_id));

create policy deliveries_recipient_select on notification_deliveries
  for select to authenticated
  using (
    recipient_user_id = auth.uid()
    or public.has_congregation_role(congregation_id, array['ADMIN'])
  );

create policy financial_entries_member_select on financial_entries
  for select to authenticated
  using (public.is_congregation_member(congregation_id));

create policy financial_entries_treasury_insert on financial_entries
  for insert to authenticated
  with check (public.has_congregation_role(congregation_id, array['ADMIN', 'TREASURER', 'ASSISTANT']));

create policy financial_entries_treasury_update on financial_entries
  for update to authenticated
  using (public.has_congregation_role(congregation_id, array['ADMIN', 'TREASURER', 'ASSISTANT']))
  with check (public.has_congregation_role(congregation_id, array['ADMIN', 'TREASURER', 'ASSISTANT']));

create policy financial_lines_member_select on financial_entry_lines
  for select to authenticated
  using (
    exists (
      select 1 from financial_entries e
      where e.id = financial_entry_id
        and public.is_congregation_member(e.congregation_id)
    )
  );

create policy movements_member_select on financial_movements
  for select to authenticated
  using (public.is_congregation_member(congregation_id));

create policy sync_member_select on sync_operations
  for select to authenticated
  using (public.is_congregation_member(congregation_id));

create policy sync_member_insert on sync_operations
  for insert to authenticated
  with check (public.is_congregation_member(congregation_id));

create policy audit_member_select on audit_events
  for select to authenticated
  using (
    congregation_id is null
    or public.is_congregation_member(congregation_id)
  );
