import { BadRequestException, Injectable, Logger, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export type SupabaseRow = Record<string, unknown>;

/** Acesso ao Supabase (PostgREST) com a service role, compartilhado pelos serviços. */
@Injectable()
export class SupabaseRestService {
  private readonly logger = new Logger(SupabaseRestService.name);

  constructor(private readonly config: ConfigService) {}

  credentials() {
    const url = this.config.get<string>('SUPABASE_URL');
    const key = this.config.get<string>('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !key) throw new ServiceUnavailableException('Supabase não configurado no backend.');
    return { url: url.replace(/\/$/, ''), key };
  }

  async query(table: string, query: string): Promise<SupabaseRow[]> {
    const { url, key } = this.credentials();
    const response = await fetch(`${url}/rest/v1/${table}?${query}`, {
      headers: { apikey: key, Authorization: `Bearer ${key}` },
    }).catch(() => {
      throw new ServiceUnavailableException('Sem conexão com o banco de dados. Tente novamente em instantes.');
    });
    if (!response.ok) throw new ServiceUnavailableException(`Falha ao consultar o Supabase (${response.status}).`);
    return (await response.json()) as SupabaseRow[];
  }

  /** Como `query`, mas tabela inexistente (404) retorna lista vazia. */
  async queryOptional(table: string, query: string): Promise<SupabaseRow[]> {
    try {
      return await this.query(table, query);
    } catch (error) {
      if (error instanceof ServiceUnavailableException && error.message.includes('404')) return [];
      throw error;
    }
  }

  async mutate(path: string, method: string, body?: SupabaseRow, prefer = '') {
    await this.send(path, method, body, prefer);
  }

  async mutateReturning(path: string, method: string, body: SupabaseRow, prefer = '') {
    const response = await this.send(path, method, body, prefer);
    const rows = (await response.json()) as SupabaseRow[];
    return rows[0] ?? body;
  }

  /** Usuário dono do token (valida a sessão no Supabase Auth). */
  async authUser(authorization?: string): Promise<{ id: string; email?: string }> {
    const token = authorization?.replace(/^Bearer\s+/i, '');
    if (!token) throw new UnauthorizedException('Sessão não informada.');
    const { url, key } = this.credentials();
    const response = await fetch(`${url}/auth/v1/user`, {
      headers: { apikey: key, Authorization: `Bearer ${token}` },
    });
    if (!response.ok) throw new UnauthorizedException('Sessão inválida ou expirada.');
    return (await response.json()) as { id: string; email?: string };
  }

  private async send(path: string, method: string, body: SupabaseRow | undefined, prefer: string) {
    const { url, key } = this.credentials();
    let response: Response;
    try {
      response = await fetch(`${url}/rest/v1/${path}`, {
        method,
        headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json', Prefer: prefer },
        body: body === undefined ? undefined : JSON.stringify(body),
      });
    } catch {
      // Sem internet no servidor: o app mantém o lançamento na fila e reenvia.
      throw new ServiceUnavailableException('Sem conexão com o banco de dados. Tente novamente em instantes.');
    }
    if (response.ok) return response;
    // Só código e mensagem do Postgres: `details` traz a linha (dados pessoais).
    const error = (await response.json().catch(() => ({}))) as { code?: string; message?: string };
    this.logger.warn(`Supabase recusou ${method} ${path.split('?')[0]} (${response.status} ${error.code ?? ''}): ${error.message ?? ''}`);
    // P0001: regra do próprio banco (ex.: ciclo fechado), mensagem já pronta para o usuário.
    if (error.code === 'P0001' && error.message) throw new BadRequestException(error.message);
    if (response.status >= 400 && response.status < 500) {
      throw new BadRequestException(`O banco de dados recusou o lançamento (${error.code ?? response.status}). Confira os dados.`);
    }
    throw new ServiceUnavailableException(`Falha ao salvar no Supabase (${response.status}).`);
  }
}
