export type PayableStatus = 'OPEN' | 'OVERDUE' | 'PARTIALLY_PAID' | 'PAID' | 'CANCELLED';

export type PayableForNotification = {
  id: string;
  congregationId: string;
  description: string;
  dueDate: string;
  notificationDaysBefore: number;
  status: PayableStatus;
};

export type NotificationPreferences = {
  notifyOnDueDate: boolean;
  repeatAfterDue: boolean;
};

export type DueDateNotification = {
  deduplicationKey: string;
  payableId: string;
  congregationId: string;
  kind: 'BEFORE_DUE' | 'DUE_TODAY' | 'OVERDUE';
  scheduledFor: string;
  title: string;
  body: string;
};

function parseDate(date: string): Date {
  const parsed = new Date(`${date}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`Data inválida: ${date}`);
  }
  return parsed;
}

function dateOnly(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function addDays(date: Date, days: number): Date {
  const result = new Date(date);
  result.setUTCDate(result.getUTCDate() + days);
  return result;
}

export function planDueDateNotifications(
  payables: PayableForNotification[],
  preferences: NotificationPreferences,
  today: string,
): DueDateNotification[] {
  const currentDate = parseDate(today);
  const notifications: DueDateNotification[] = [];

  for (const payable of payables) {
    if (payable.status === 'PAID' || payable.status === 'CANCELLED') continue;
    const dueDate = parseDate(payable.dueDate);
    const daysBefore = Math.max(0, Math.min(365, payable.notificationDaysBefore));
    const notificationDate = dateOnly(addDays(dueDate, -daysBefore));

    if (notificationDate === today && daysBefore > 0) {
      notifications.push({
        deduplicationKey: `${payable.congregationId}:${payable.id}:BEFORE_DUE:${notificationDate}`,
        payableId: payable.id,
        congregationId: payable.congregationId,
        kind: 'BEFORE_DUE',
        scheduledFor: notificationDate,
        title: 'Conta próxima do vencimento',
        body: `${payable.description} vence em ${daysBefore} dia(s).`,
      });
      continue;
    }

    if (payable.dueDate === today && preferences.notifyOnDueDate) {
      notifications.push({
        deduplicationKey: `${payable.congregationId}:${payable.id}:DUE_TODAY:${today}`,
        payableId: payable.id,
        congregationId: payable.congregationId,
        kind: 'DUE_TODAY',
        scheduledFor: today,
        title: 'Conta vence hoje',
        body: payable.description,
      });
      continue;
    }

    if (dueDate < currentDate && preferences.repeatAfterDue) {
      notifications.push({
        deduplicationKey: `${payable.congregationId}:${payable.id}:OVERDUE:${today}`,
        payableId: payable.id,
        congregationId: payable.congregationId,
        kind: 'OVERDUE',
        scheduledFor: today,
        title: 'Conta vencida',
        body: `${payable.description} está vencida desde ${payable.dueDate}.`,
      });
    }
  }

  return notifications;
}
