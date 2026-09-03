import { Controller, Get } from '@nestjs/common';

import { RuntimeSettingsService } from './runtime-settings.service';

@Controller('app-config')
export class AppConfigController {
  constructor(private readonly runtimeSettings: RuntimeSettingsService) {}

  @Get()
  async get() {
    return this.runtimeSettings.publicConfig();
  }
}
