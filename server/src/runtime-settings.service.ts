import { Injectable, ServiceUnavailableException } from '@nestjs/common';

import { InfrastructureService } from './infrastructure.service';

export type RuntimeSettings = {
  roomDurationMinutes: number;
  extensionMinutes: number;
  selectionSeconds: number;
  roomRepeatHours: number;
  recentMatchDays: number;
  minimumRoomUsers: number;
  maintenanceMode: boolean;
  maintenanceMessage: string;
  announcementEnabled: boolean;
  announcementTitle: string | null;
  announcementMessage: string | null;
  updatedAt: Date;
  updatedByAdminId: string | null;
};

@Injectable()
export class RuntimeSettingsService {
  constructor(private readonly infra: InfrastructureService) {}

  async get(): Promise<RuntimeSettings> {
    const result = await this.infra.db.query<{
      room_duration_minutes: number;
      extension_minutes: number;
      selection_seconds: number;
      room_repeat_hours: number;
      recent_match_days: number;
      minimum_room_users: number;
      maintenance_mode: boolean;
      maintenance_message: string;
      announcement_enabled: boolean;
      announcement_title: string | null;
      announcement_message: string | null;
      updated_at: Date;
      updated_by_admin_id: string | null;
    }>(
      `select room_duration_minutes, extension_minutes, selection_seconds,
              room_repeat_hours, recent_match_days, minimum_room_users,
              maintenance_mode, maintenance_message,
              announcement_enabled, announcement_title, announcement_message,
              updated_at, updated_by_admin_id::text
       from app_runtime_settings where id=1`,
    );

    const row = result.rows[0];
    if (!row) {
      throw new Error('Runtime settings row is missing. Run database migrations.');
    }
    return {
      roomDurationMinutes: Number(row.room_duration_minutes),
      extensionMinutes: Number(row.extension_minutes),
      selectionSeconds: Number(row.selection_seconds),
      roomRepeatHours: Number(row.room_repeat_hours),
      recentMatchDays: Number(row.recent_match_days),
      minimumRoomUsers: Number(row.minimum_room_users),
      maintenanceMode: row.maintenance_mode === true,
      maintenanceMessage: row.maintenance_message,
      announcementEnabled: row.announcement_enabled === true,
      announcementTitle: row.announcement_title,
      announcementMessage: row.announcement_message,
      updatedAt: row.updated_at,
      updatedByAdminId: row.updated_by_admin_id,
    };
  }

  async publicConfig() {
    const settings = await this.get();
    return {
      ok: true,
      maintenance: {
        enabled: settings.maintenanceMode,
        message: settings.maintenanceMessage,
      },
      announcement: {
        enabled: settings.announcementEnabled,
        title: settings.announcementTitle,
        message: settings.announcementMessage,
      },
      room: {
        durationMinutes: settings.roomDurationMinutes,
        extensionMinutes: settings.extensionMinutes,
        selectionSeconds: settings.selectionSeconds,
        minimumUsers: settings.minimumRoomUsers,
      },
    };
  }

  async assertOperational() {
    const settings = await this.get();
    if (settings.maintenanceMode) {
      throw new ServiceUnavailableException({
        message: settings.maintenanceMessage,
        code: 'maintenance_mode',
      });
    }
    return settings;
  }
}
