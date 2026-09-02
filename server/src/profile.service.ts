import { BadRequestException, Injectable } from '@nestjs/common';

import { InfrastructureService } from './infrastructure.service';
import { UpdatePreferencesDto, UpdateProfileDto } from './profile.dto';

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

  async updateProfile(userId: string, body: UpdateProfileDto) {
    await this.infra.db.query(
      `insert into profiles(
         user_id, display_name, birth_date, gender, bio, city, country,
         latitude, longitude, profile_prompt, profile_answer, interests,
         photo_urls, profile_completed, updated_at
       ) values (
         $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,now()
       )
       on conflict (user_id) do update set
         display_name = coalesce(excluded.display_name, profiles.display_name),
         birth_date = coalesce(excluded.birth_date, profiles.birth_date),
         gender = coalesce(excluded.gender, profiles.gender),
         bio = coalesce(excluded.bio, profiles.bio),
         city = coalesce(excluded.city, profiles.city),
         country = coalesce(excluded.country, profiles.country),
         latitude = coalesce(excluded.latitude, profiles.latitude),
         longitude = coalesce(excluded.longitude, profiles.longitude),
         profile_prompt = coalesce(excluded.profile_prompt, profiles.profile_prompt),
         profile_answer = coalesce(excluded.profile_answer, profiles.profile_answer),
         interests = coalesce(excluded.interests, profiles.interests),
         photo_urls = coalesce(excluded.photo_urls, profiles.photo_urls),
         profile_completed = coalesce(excluded.profile_completed, profiles.profile_completed),
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
