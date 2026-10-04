import { HealthController } from './health.controller';

describe('HealthController', () => {
  it('returns a healthy status', () => {
    expect(new HealthController().getHealth()).toEqual({
      status: 'ok',
      service: 'tesouraria-api',
    });
  });
});
