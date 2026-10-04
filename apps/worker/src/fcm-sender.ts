import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import type { DueDateNotification } from './due-date-notifications';

export type PushToken = {
  token: string;
  userId: string;
};

export class FcmSender {
  private readonly enabled: boolean;

  constructor() {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
    this.enabled = Boolean(projectId && clientEmail && privateKey);

    if (this.enabled && getApps().length === 0) {
      initializeApp({
        credential: cert({ projectId, clientEmail, privateKey }),
        databaseURL: process.env.FIREBASE_DATABASE_URL,
      });
    }
  }

  isEnabled(): boolean {
    return this.enabled;
  }

  async send(
    notification: DueDateNotification,
    recipients: PushToken[],
  ): Promise<{ sent: number; failed: number }> {
    if (!this.enabled) {
      throw new Error('Firebase Admin não está configurado para o worker.');
    }
    if (recipients.length === 0) {
      return { sent: 0, failed: 0 };
    }

    const response = await getMessaging().sendEachForMulticast({
      tokens: recipients.map((recipient) => recipient.token),
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        type: 'PAYABLE_DUE_DATE',
        payableId: notification.payableId,
        notificationType: notification.kind,
      },
    });

    return {
      sent: response.successCount,
      failed: response.failureCount,
    };
  }
}
