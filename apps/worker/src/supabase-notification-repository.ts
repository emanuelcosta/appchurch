import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type {
  NotificationPreferences,
  PayableForNotification,
} from './due-date-notifications';
import type { PushToken } from './fcm-sender';

type Delivery = {
  id: string;
  deduplicationKey: string;
};

export class SupabaseNotificationRepository {
  readonly enabled: boolean;
  private readonly client: SupabaseClient | null;

  constructor() {
    const url = process.env.SUPABASE_URL;
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    this.enabled = Boolean(url && serviceKey);
    this.client = this.enabled ? createClient(url!, serviceKey!) : null;
  }

  async listPayables(congregationId: string): Promise<PayableForNotification[]> {
    const client = this.requireClient();
    const { data, error } = await client
      .from('payables')
      .select('id, congregation_id, description, due_date, notification_days_before, status')
      .eq('congregation_id', congregationId)
      .in('status', ['OPEN', 'OVERDUE', 'PARTIALLY_PAID']);
    if (error) throw new Error(`Falha ao buscar contas a pagar: ${error.message}`);
    return (data ?? []).map((row) => ({
      id: row.id as string,
      congregationId: row.congregation_id as string,
      description: row.description as string,
      dueDate: row.due_date as string,
      notificationDaysBefore: row.notification_days_before as number,
      status: row.status as PayableForNotification['status'],
    }));
  }

  async getPreferences(congregationId: string): Promise<NotificationPreferences> {
    const client = this.requireClient();
    const { data, error } = await client
      .from('notification_preferences')
      .select('notify_on_due_date, repeat_after_due')
      .eq('congregation_id', congregationId)
      .maybeSingle();
    if (error) throw new Error(`Falha ao buscar preferências: ${error.message}`);
    return {
      notifyOnDueDate: data?.notify_on_due_date ?? true,
      repeatAfterDue: data?.repeat_after_due ?? false,
    };
  }

  async listTokens(congregationId: string): Promise<PushToken[]> {
    const client = this.requireClient();
    const { data, error } = await client
      .from('device_push_tokens')
      .select('token, user_id')
      .eq('congregation_id', congregationId)
      .eq('active', true);
    if (error) throw new Error(`Falha ao buscar tokens: ${error.message}`);
    return (data ?? []).map((row) => ({
      token: row.token as string,
      userId: row.user_id as string,
    }));
  }

  async reserveDelivery(
    notification: {
      congregationId: string;
      payableId: string;
      deduplicationKey: string;
      kind: string;
      scheduledFor: string;
      title: string;
      body: string;
    },
  ): Promise<Delivery | null> {
    const client = this.requireClient();
    const { data, error } = await client
      .from('notification_deliveries')
      .insert({
        congregation_id: notification.congregationId,
        payable_id: notification.payableId,
        deduplication_key: notification.deduplicationKey,
        notification_type: notification.kind,
        payload: { title: notification.title, body: notification.body },
        scheduled_for: `${notification.scheduledFor}T00:00:00Z`,
        status: 'PROCESSING',
      })
      .select('id, deduplication_key')
      .maybeSingle();
    if (error?.code === '23505') return null;
    if (error) throw new Error(`Falha ao reservar notificação: ${error.message}`);
    return data ? { id: data.id as string, deduplicationKey: data.deduplication_key as string } : null;
  }

  async markDelivery(
    id: string,
    status: 'SENT' | 'FAILED',
    error?: string,
  ): Promise<void> {
    const client = this.requireClient();
    const { error: updateError } = await client
      .from('notification_deliveries')
      .update({
        status,
        sent_at: status === 'SENT' ? new Date().toISOString() : null,
        last_error: error ?? null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id);
    if (updateError) throw new Error(`Falha ao atualizar notificação: ${updateError.message}`);
  }

  private requireClient(): SupabaseClient {
    if (!this.client) {
      throw new Error('Supabase não está configurado para o worker.');
    }
    return this.client;
  }
}
