import assert from 'node:assert/strict';
import test from 'node:test';
import { planDueDateNotifications } from './due-date-notifications';

const basePayable = {
  id: 'payable-1',
  congregationId: 'congregation-1',
  description: 'Conta de energia',
  dueDate: '2026-10-10',
  notificationDaysBefore: 3,
  status: 'OPEN' as const,
};

test('plans one notification before the due date', () => {
  const result = planDueDateNotifications(
    [basePayable],
    { notifyOnDueDate: true, repeatAfterDue: false },
    '2026-10-07',
  );

  assert.equal(result.length, 1);
  assert.equal(result[0].kind, 'BEFORE_DUE');
  assert.match(result[0].body, /3 dia/);
});

test('does not notify paid payables and deduplicates by stable key', () => {
  const result = planDueDateNotifications(
    [
      { ...basePayable, status: 'PAID' },
      { ...basePayable, id: 'payable-2' },
    ],
    { notifyOnDueDate: true, repeatAfterDue: false },
    '2026-10-07',
  );

  assert.equal(result.length, 1);
  assert.equal(result[0].deduplicationKey, 'congregation-1:payable-2:BEFORE_DUE:2026-10-07');
});

test('plans due-today and overdue notifications according to preferences', () => {
  const result = planDueDateNotifications(
    [
      { ...basePayable, id: 'today', dueDate: '2026-10-10' },
      { ...basePayable, id: 'late', dueDate: '2026-10-09' },
    ],
    { notifyOnDueDate: true, repeatAfterDue: true },
    '2026-10-10',
  );

  assert.deepEqual(
    result.map((notification) => notification.kind),
    ['DUE_TODAY', 'OVERDUE'],
  );
});
