import { BadRequestException, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { mkdir, rm, writeFile } from 'node:fs/promises';
import * as path from 'node:path';

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

  private detectImageType(buffer: Buffer): string | null {
    if (buffer.length < 12) return null;
    if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
      return 'image/jpeg';
    }
    if (
      buffer[0] === 0x89 &&
      buffer[1] === 0x50 &&
      buffer[2] === 0x4e &&
      buffer[3] === 0x47 &&
      buffer[4] === 0x0d &&
      buffer[5] === 0x0a &&
      buffer[6] === 0x1a &&
      buffer[7] === 0x0a
    ) {
      return 'image/png';
    }
    if (
      buffer.subarray(0, 4).toString('ascii') === 'RIFF' &&
      buffer.subarray(8, 12).toString('ascii') === 'WEBP'
    ) {
      return 'image/webp';
    }
    if (buffer.subarray(4, 8).toString('ascii') === 'ftyp') {
      const brand = buffer.subarray(8, 12).toString('ascii').toLowerCase();
      if (['heic', 'heix', 'hevc', 'hevx'].includes(brand)) return 'image/heic';
      if (['heif', 'mif1', 'msf1'].includes(brand)) return 'image/heif';
    }
    return null;
  }

  async uploadPhotos(userId: string, files: UploadedPhoto[]) {
    if (files.length < 1 || files.length > 4) {
      throw new BadRequestException('1 ile 4 arasında fotoğraf yüklemelisin.');
    }

    const extensions: Record<string, string> = {
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
    for (const finalFile of files) {
      if (!finalFile.buffer?.length || finalFile.size > 8 * 1024 * 1024) {
        throw new BadRequestException('Fotoğraf boyutu en fazla 8 MB olabilir.');
      }
      const detected = this.detectImageType(finalFile.buffer);
      const ext = detected ? extensions[detected] : null;
      if (!detected || !ext) {
        throw new BadRequestException(
          'Dosya gerçek bir JPG, PNG, WEBP veya HEIC görseli değil.',
        );
      }
      const filename = `${Date.now()}-${randomUUID()}.${ext}`;
      await writeFile(path.join(userDir, filename), finalFile.buffer, { flag: 'wx' });
      urls.push(`/uploads/profile/${userId}/${filename}`);
    }

    return { ok: true, urls };
  }

  private validateCompletedProfile(userId: string, body: UpdateProfileDto) {
    if (body.profileCompleted !== true) return;

    const requiredStrings: Array<[string | undefined, string]> = [
      [body.displayName, 'Ad'],
      [body.birthDate, 'Doğum tarihi'],
      [body.gender, 'Cinsiyet'],
      [body.bio, 'Bio'],
      [body.city, 'Şehir'],
      [body.country, 'Ülke'],
      [body.profilePrompt, 'Profil sorusu'],
      [body.profileAnswer, 'Profil cevabı'],
    ];
    for (const [value, label] of requiredStrings) {
      if (!value?.trim()) throw new BadRequestException(`${label} zorunlu.`);
    }
    if (body.latitude == null || body.longitude == null) {
      throw new BadRequestException('Gerçek konum zorunlu.');
    }
    if (!body.interests?.length) {
      throw new BadRequestException('En az 1 ilgi alanı zorunlu.');
    }
    if (!body.photoUrls || body.photoUrls.length < 3 || body.photoUrls.length > 4) {
      throw new BadRequestException('Profili tamamlamak için 3 veya 4 fotoğraf gerekli.');
    }
    const ownPrefix = `/uploads/profile/${userId}/`;
    if (body.photoUrls.some((url) => !url.startsWith(ownPrefix))) {
      throw new BadRequestException('Profil fotoğrafları kendi Meet6 yüklemelerin olmalı.');
    }

    const birth = new Date(body.birthDate!);
    if (Number.isNaN(birth.getTime())) {
      throw new BadRequestException('Doğum tarihi geçersiz.');
    }
    const now = new Date();
    let age = now.getUTCFullYear() - birth.getUTCFullYear();
    const monthDiff = now.getUTCMonth() - birth.getUTCMonth();
    if (monthDiff < 0 || (monthDiff === 0 && now.getUTCDate() < birth.getUTCDate())) age--;
    if (age < 18) throw new BadRequestException('Meet6 yalnızca 18 yaş ve üzeri kullanıcılar içindir.');
  }

  async updateProfile(userId: string, body: UpdateProfileDto) {
    if (body.photoUrls != null && body.photoUrls.length > 4) {
      throw new BadRequestException('En fazla 4 profil fotoğrafı olabilir.');
    }
    this.validateCompletedProfile(userId, body);

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

  async deleteAccount(userId: string) {
    const root = process.env.UPLOAD_ROOT ?? '/var/www/meet6/uploads';
    await this.infra.db.query('delete from users where id = $1', [userId]);
    await rm(path.join(root, 'profile', userId), { recursive: true, force: true });
    return { ok: true };
  }
}
