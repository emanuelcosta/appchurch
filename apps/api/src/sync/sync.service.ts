import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PushOperationDto } from './dto/push-operation.dto';
import { ResolveConflictDto } from './dto/resolve-conflict.dto';

type OperationStatus = 'SYNCED' | 'CONFLICT' | 'DISCARDED';

export interface StoredOperation {
  operationId: string;
  idempotencyKey: string;
  scopeId: string;
  operationType: string;
  entityType: string;
  entityId: string;
  payload: Record<string, unknown>;
  baseVersion?: number;
  status: OperationStatus;
  cursor: number;
  createdAt: string;
}

@Injectable()
export class SyncService {
  private readonly operationsByIdempotency = new Map<string, StoredOperation>();
  private readonly operationsByCursor: StoredOperation[] = [];
  private cursor = 0;

  push(operation: PushOperationDto): StoredOperation {
    const existing = this.operationsByIdempotency.get(operation.idempotencyKey);
    if (existing) {
      if (JSON.stringify(existing.payload) !== JSON.stringify(operation.payload)) {
        throw new ConflictException({
          code: 'IDEMPOTENCY_CONFLICT',
          message: 'A chave de idempotência já foi usada com outro payload.',
        });
      }
      return existing;
    }

    if (operation.dependsOn && !this.hasOperation(operation.dependsOn)) {
      throw new ConflictException({
        code: 'DEPENDENCY_NOT_SYNCED',
        message: 'A operação depende de outra operação ainda não sincronizada.',
      });
    }

    const status: OperationStatus =
      operation.baseVersion !== undefined && operation.baseVersion < 0
        ? 'CONFLICT'
        : 'SYNCED';
    const stored: StoredOperation = {
      ...operation,
      status,
      cursor: ++this.cursor,
      createdAt: new Date().toISOString(),
    };
    this.operationsByIdempotency.set(operation.idempotencyKey, stored);
    this.operationsByCursor.push(stored);
    return stored;
  }

  pull(scopeId: string, cursor = 0): { cursor: number; operations: StoredOperation[] } {
    const operations = this.operationsByCursor.filter(
      (operation) => operation.scopeId === scopeId && operation.cursor > cursor,
    );
    return { cursor: this.cursor, operations };
  }

  resolveConflict(dto: ResolveConflictDto): StoredOperation {
    const operation = this.operationsByCursor.find(
      (candidate) =>
        candidate.operationId === dto.operationId && candidate.scopeId === dto.scopeId,
    );
    if (!operation) {
      throw new NotFoundException({
        code: 'SYNC_OPERATION_NOT_FOUND',
        message: 'Operação de sincronização não encontrada.',
      });
    }
    if (operation.status !== 'CONFLICT') {
      throw new ConflictException({
        code: 'OPERATION_NOT_IN_CONFLICT',
        message: 'A operação não está aguardando resolução.',
      });
    }
    operation.payload = dto.payload;
    operation.status = dto.resolution === 'DISCARD' ? 'DISCARDED' : 'SYNCED';
    return operation;
  }

  private hasOperation(operationId: string): boolean {
    return this.operationsByCursor.some(
      (operation) => operation.operationId === operationId && operation.status === 'SYNCED',
    );
  }
}
