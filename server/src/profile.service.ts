import { BadRequestException, Injectable } from '@nestjs/common';
import { mkdir, writeFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import path from 'node:path';

import { InfrastructureService } from './infrastructure.service';
import { UpdatePreferencesDto, UpdateProfileDto } from './profile.dto';

type UploadedPhoto = {
  buffer: Buffer;
  mimetype: string;
  size: number;
  originalname: string;
};

@Injectable()
export class ProfileService {
  constructor(private readonly infra: InfrastructureService) {}

  async getMe(userId: string) {
    const user = await this.infra.db.query(
      `select u.id, u.phone_e164, u.status, u.created_at, u.last_seen_at,
              p.display_name, p.birth_date, p.gender, p.bio, p.city, p.country,
              p.latitude, p.longitude, p.profile_prompt, p.profile_answer,
              p.interests, p.photo_urls, coalesce(p.profile_completed, false) as profile_completed,
              mp.looking_for, mp.min_age, mp.max_age, mp.distance_km, mp.purpose
       from users u
       left join profiles p on p.user_id = u.id
       left join matching_preferences mp on mp.user_id = u.id
       where u.id = $1`,
      [userId],
    );
    return { ok: true, user: user.rows[0] ?? null };
  }

  async uploadPhotos(userId: string, files: UploadedPhoto[]) {
    if (files.length < 1 || files.length > 4) {
      throw new BadRequestException('1 ile 4 arasında fotoğraf yüklemelisin.');
    }

    const allowed: Record<string, string> = {
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
      'image/heic': 'heic',
      'image/heif': 'heif',
    };

    const root = process.env.UPLOAD_ROOT ?? '/var/www/meet6/uploads';
    const userDir = path.join(root, 'profile', userId);
    await mkdir(userDir, { recursive: true });

    const urls: string[] = [];
    for (finalFile of files) {
      const ext = allowed[finalFile.mimetype];
      if (!ext) throw new BadRequestException('Yalnızca JPG, PNG, WEBP veya HEIC fotoğraf yüklenebilir.');
      if (!finalFile.buffer?.length || finalFile.size > 8 * 1024 * 1024) {
        throw new BadRequestException('Fotoğraf boyutu en fazla 8 MB olabilir.');
      }
      const filename = `${Date.now()}-${randomUUID()}.${ext}`;
      await writeFile(path.join(userDir, filename), finalFile.buffer, { flag: 'wx' });
      urls.push(`/uploads/profile/${userId}/${filename}`);
    }

    return { ok: true, urls };
  }

  async updateProfile(userId: string, body: UpdateProfileDto) {
    if (body.photoUrls != null && body.photoUrls.length > 4) {
      throw new BadRequestException('En fazla 4 profil fotoğrafı olabilir.');
    }
    if (body.profileCompleted === true && (!body.photoUrls || body.photoUrls.length < 3)) {
      throw new BadRequestException('Profili tamamlamak için en az 3 fotoğraf gerekli.');
    }

    await this.infra.db.query(
      `insert into profiles(
         user_id, display_name, birth_date, gender, bio, city, country,
         latitude, longitude, profile_prompt, profile_answer, interests,
         photo_urls, profile_completed, updated_at
       ) values (
         $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,
         coalesce($12, '{}'::text[]),
         coalesce($13, '{}'::text[]),
         coalesce($14, false),
         now()
       )
       on conflict (user_id) do update set
         display_name = coalesce($2, profiles.display_name),
         birth_date = coalesce($3, profiles.birth_date),
         gender = coalesce($4, profiles.gender),
         bio = coalesce($5, profiles.bio),
         city = coalesce($6, profiles.city),
         country = coalesce($7, profiles.country),
         latitude = coalesce($8, profiles.latitude),
         longitude = coalesce($9, profiles.longitude),
         profile_prompt = coalesce($10, profiles.profile_prompt),
         profile_answer = coalesce($11, profiles.profile_answer),
         interests = coalesce($12, profiles.interests),
         photo_urls = coalesce($13, profiles.photo_urls),
         profile_completed = coalesce($14, profiles.profile_completed),
         updated_at = now()`,
      [
        userId,
        body.displayName ?? null,
        body.birthDate ?? null,
        body.gender ?? null,
        body.bio ?? null,
        body.city ?? null,
        body.country ?? null,
        body.latitude ?? null,
        body.longitude ?? null,
        body.profilePrompt ?? null,
        body.profileAnswer ?? null,
        body.interests ?? null,
        body.photoUrls ?? null,
        body.profileCompleted ?? null,
      ],
    );
    return this.getMe(userId);
  }

  async updatePreferences(userId: string, body: UpdatePreferencesDto) {
    if (body.minAge != null && body.maxAge != null && body.maxAge < body.minAge) {
      throw new BadRequestException('Maksimum yaş minimum yaştan küçük olamaz.');
    }

    await this.infra.db.query(
      `insert into matching_preferences(user_id, looking_for, min_age, max_age, distance_km, purpose)
       values ($1, coalesce($2,'Herkes'), coalesce($3,18), coalesce($4,65), coalesce($5,25), coalesce($6,'Yeni insanlarla tanışma'))
       on conflict (user_id) do update set
         looking_for = coalesce($2, matching_preferences.looking_for),
         min_age = coalesce($3, matching_preferences.min_age),
         max_age = coalesce($4, matching_preferences.max_age),
         distance_km = coalesce($5, matching_preferences.distance_km),
         purpose = coalesce($6, matching_preferences.purpose),
         updated_at = now()`,
      [
        userId,
        body.lookingFor ?? null,
        body.minAge ?? null,
        body.maxAge ?? null,
        body.distanceKm ?? null,
        body.purpose ?? null,
      ],
    );
    return this.getMe(userId);
  }
}
