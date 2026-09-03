import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';

import { AdminRuntimeSettingsDto } from './admin.dto';
import { AdminService } from './admin.service';
import { InfrastructureService } from './infrastructure.service';
import { RoomsGateway } from './rooms.gateway';
import { RuntimeSettingsService } from './runtime-settings.service';

@Injectable()
export class AdminSettingsService {
  constructor(
    private readonly infra: InfrastructureService,
    private readonly adminService: AdminService,
    private readonly runtimeSettings: RuntimeSettingsService,
    private readonly roomsGateway: RoomsGateway,
  ) {}

  async get(adminUserId: string) {
    const admin = await this.adminService.requireAdmin(adminUserId);
    const settings = await this.runtimeSettings.get();
    return {
      ok: true,
      admin,
      editable: admin.role === 'super_admin',
      settings,
    };
  }

  async update(adminUserId: string, body: AdminRuntimeSettingsDto) {
    const admin = await this.adminService.requireAdmin(adminUserId);
    if (admin.role !== 'super_admin') {
      throw new ForbiddenException('Uygulama ayarlarını yalnızca super_admin değiştirebilir.');
    }

    const maintenanceMessage = body.maintenanceMessage.trim();
    if (maintenanceMessage.length < 3) {
      throw new BadRequestException('Bakım modu mesajı gerekli.');
    }
    const announcementTitle = body.announcementTitle?.trim() || null;
    const announcementMessage = body.announcementMessage?.trim() || null;
    if (body.announcementEnabled && !announcementMessage) {
      throw new BadRequestException('Duyuru açıkken duyuru mesajı gerekli.');
    }

    const previous = await this.runtimeSettings.get();
    await this.infra.db.query(
      `update app_runtime_settings
       set room_duration_minutes=$2,
           extension_minutes=$3,
           selection_seconds=$4,
           room_repeat_hours=$5,
           recent_match_days=$6,
           minimum_room_users=$7,
           maintenance_mode=$8,
           maintenance_message=$9,
           announcement_enabled=$10,
           announcement_title=$11,
           announcement_message=$12,
           updated_at=now(),
           updated_by_admin_id=$13
       where id=$1`,
      [
        1,
        body.roomDurationMinutes,
        body.extensionMinutes,
        body.selectionSeconds,
        body.roomRepeatHours,
        body.recentMatchDays,
        body.minimumRoomUsers,
        body.maintenanceMode,
        maintenanceMessage,
        body.announcementEnabled,
        announcementTitle,
        announcementMessage,
        adminUserId,
      ],
    );
    const current = await this.runtimeSettings.get();
    await this.infra.db.query(
      `insert into admin_audit_log(admin_user_id, action, target_type, target_id, detail)
       values($1,'update_runtime_settings','app_settings','1',$2::jsonb)`,
      [adminUserId, JSON.stringify({ previous, current })],
    );

    const publicConfig = await this.runtimeSettings.publicConfig();
    try {
      this.roomsGateway.server?.emit('app:config', publicConfig);
    } catch (_) {
      // WebSocket henüz hazır değilse HTTP config endpointi kaynak olmaya devam eder.
    }

    return { ok: true, admin, editable: true, settings: current };
  }
}
