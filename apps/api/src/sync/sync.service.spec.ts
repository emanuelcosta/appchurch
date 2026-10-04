import { ConflictException } from '@nestjs/common';
import { PushOperationDto } from './dto/push-operation.dto';
import { SyncService } from './sync.service';

const operation = (payload: Record<string, unknown>): PushOperationDto => ({
  operationId: '11111111-1111-4111-8111-111111111111',
  idempotencyKey: '22222222-2222-4222-8222-222222222222',
  scopeId: '33333333-3333-4333-8333-333333333333',
  operationType: 'CREATE',
  entityType: 'financial_entry',
  entityId: '44444444-4444-4444-8444-444444444444',
  payload,
});

describe('SyncService', () => {
  it('is idempotent for the same payload', () => {
    const service = new SyncService();
    const first = service.push(operation({ amount: 10 }));
    const second = service.push(operation({ amount: 10 }));

    expect(second).toEqual(first);
    expect(service.pull(operation({}).scopeId)).toHaveProperty('operations', [first]);
  });

  it('rejects reuse of an idempotency key with another payload', () => {
    const service = new SyncService();
    service.push(operation({ amount: 10 }));

    expect(() => service.push(operation({ amount: 20 }))).toThrow(ConflictException);
  });
});
