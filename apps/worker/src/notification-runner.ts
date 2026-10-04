import { planDueDateNotifications } from './due-date-notifications';
import { FcmSender } from './fcm-sender';
import { SupabaseNotificationRepository } from './supabase-notification-repository';

export class NotificationRunner {
  constructor(
    private readonly repository: SupabaseNotificationRepository,
    private readonly sender: FcmSender,
  ) {}

  async run(today = new Date().toISOString().slice(0, 10)): Promise<void> {
    if (!this.repository.enabled || !this.sender.isEnabled()) {
      console.log('[worker] notification run skipped: Supabase ou FCM não configurado');
      return;
    }

    const congregationIds = process.env.NOTIFICATION_CONGREGATION_IDS?.split(',')
      .map((id) => id.trim())
      .filter(Boolean) ?? [];
    if (congregationIds.length === 0) {
      throw new Error('NOTIFICATION_CONGREGATION_IDS não foi configurado.');
    }

    for (const congregationId of congregationIds) {
      const [payables, preferences, recipients] = await Promise.all([
        this.repository.listPayables(congregationId),
        this.repository.getPreferences(congregationId),
        this.repository.listTokens(congregationId),
      ]);
      const notifications = planDueDateNotifications(payables, preferences, today);

      for (const notification of notifications) {
        const delivery = await this.repository.reserveDelivery(notification);
        if (!delivery) continue;
        try {
          await this.sender.send(notification, recipients);
          await this.repository.markDelivery(delivery.id, 'SENT');
        } catch (error) {
          const message = error instanceof Error ? error.message : String(error);
          await this.repository.markDelivery(delivery.id, 'FAILED', message);
          throw error;
        }
      }
    }
  }
}
