import { FcmSender } from './fcm-sender';
import { NotificationRunner } from './notification-runner';
import { SupabaseNotificationRepository } from './supabase-notification-repository';

const intervalMs = 5 * 60 * 1000;
const fcmSender = new FcmSender();
const notificationRunner = new NotificationRunner(
  new SupabaseNotificationRepository(),
  fcmSender,
);

async function runNotificationScheduler(): Promise<void> {
  console.log(
    `[worker] due-date scheduler ready; interval=${intervalMs}ms; fcm=${
      fcmSender.isEnabled() ? 'enabled' : 'disabled'
    }`,
  );
  await notificationRunner.run();
}

void runNotificationScheduler().catch((error: unknown) => {
  console.error('[worker] notification run failed', error);
});
setInterval(() => {
  void runNotificationScheduler().catch((error: unknown) => {
    console.error('[worker] notification run failed', error);
  });
}, intervalMs);
