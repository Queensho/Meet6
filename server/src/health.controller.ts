import { Controller, Get } from '@nestjs/common';

import { InfrastructureService } from './infrastructure.service';

@Controller('health')
export class HealthController {
  constructor(private readonly infrastructure: InfrastructureService) {}

  @Get()
  async health() {
    const infrastructure = await this.infrastructure.health();

    return {
      ok: true,
      service: 'meet6-api',
      version: '0.1.0',
      timestamp: new Date().toISOString(),
      ...infrastructure,
    };
  }
}
