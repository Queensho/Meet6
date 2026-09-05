import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { PoolClient } from 'pg';

import { InfrastructureService } from './infrastructure.service';
import { RoomService } from './room.service';
import { RuntimeSettingsService } from './runtime-settings.service';

type GiftCatalogRow = {
  id: string;
  code: string;
  name: string;
  emoji: string;
  coin_cost: number;
  gift_xp: number;
  generosity_xp: number;
  profile_xp: number;
  is_daily_free: boolean;
};

type WalletRow = {
  coin_balance: number;
  gift_xp: number;
  generosity_xp: number;
  profile_xp: number;
  gifts_received: number;
  gifts_sent: number;
};

type RewardRow = {
  reward_key: string;
  level: number;
  reward_type: 'coins' | 'premium_days' | 'badge' | 'frame' | 'effect';
  amount: number;
  title: string;
  cosmetic_code: string | null;
  claimed?: boolean;
};

@Injectable()
export class GiftService {
  private static readonly giftsPerRoomLimit = 20;
  private static readonly freeGiftsPerDay = 3;
  private static readonly giftProfileXpDailyCap = 100;
  private static readonly maxProfileLevel = 30;

  constructor(
    private readonly infra: InfrastructureService,
    private readonly rooms: RoomService,
    private readonly runtimeSettings: RuntimeSettingsService,
  ) {}

  private normalizeClientGiftId(value: string) {
    const id = value.trim();
    if (!/^[A-Za-z0-9._:-]{8,96}$/.test(id)) {
      throw new BadRequestException('Geçersiz hediye işlem kimliği.');
    }
    return id;
  }

  private normalizeGiftCode(value: string) {
    const code = value.trim().toLowerCase();
    if (!/^[a-z0-9_-]{1,40}$/.test(code)) {
      throw new BadRequestException('Geçersiz hediye.');
    }
    return code;
  }

  private levelFromXp(value: number) {
    const xp = Math.max(0, Number(value) || 0);
    return Math.min(
      GiftService.maxProfileLevel,
      1 + Math.floor(Math.sqrt(xp / 50)),
    );
  }

  private nextLevelXp(level: number) {
    if (level >= GiftService.maxProfileLevel) return null;
    return 50 * level * level;
  }

  private badges(wallet: WalletRow) {
    const earned: string[] = [];
    if (Number(wallet.gifts_received) >= 1) earned.push('İlk Hediye');
    if (Number(wallet.gifts_received) >= 10) earned.push('Sevilen');
    if (Number(wallet.gifts_received) >= 50) earned.push('Parlayan');
    if (Number(wallet.gifts_sent) >= 1) earned.push('İlk Jest');
    if (Number(wallet.gifts_sent) >= 10) earned.push('Cömert');
    if (Number(wallet.gifts_sent) >= 50) earned.push('Hediye Ustası');
    return earned;
  }

  private serializeWallet(wallet: WalletRow, includeBalance: boolean) {
    const profileXp = Number(wallet.profile_xp);
    const profileLevel = this.levelFromXp(profileXp);
    const value: Record<string, unknown> = {
      giftXp: Number(wallet.gift_xp),
      generosityXp: Number(wallet.generosity_xp),
      giftLevel: this.levelFromXp(Number(wallet.gift_xp)),
      generosityLevel: this.levelFromXp(Number(wallet.generosity_xp)),
      profileXp,
      profileLevel,
      nextLevelXp: this.nextLevelXp(profileLevel),
      giftsReceived: Number(wallet.gifts_received),
      giftsSent: Number(wallet.gifts_sent),
      badges: this.badges(wallet),
    };
    if (includeBalance) value.coinBalance = Number(wallet.coin_balance);
    return value;
  }

  private async ensureWallet(userId: string | number) {
    await this.infra.db.query(
      `insert into user_wallets(user_id) values($1)
       on conflict(user_id) do nothing`,
      [userId],
    );
  }

  private async wallet(userId: string | number) {
    await this.ensureWallet(userId);
    const result = await this.infra.db.query<WalletRow>(
      `select coin_balance,gift_xp,generosity_xp,profile_xp,gifts_received,gifts_sent
       from user_wallets where user_id=$1`,
      [userId],
    );
    return result.rows[0] ?? {
      coin_balance: 0,
      gift_xp: 0,
      generosity_xp: 0,
      profile_xp: 0,
      gifts_received: 0,
      gifts_sent: 0,
    };
  }

  private async freeGiftAllowance(userId: string | number) {
    const result = await this.infra.db.query<{ free_gifts_used: number }>(
      `select free_gifts_used
       from user_daily_gift_usage
       where user_id=$1
         and usage_date=(now() at time zone 'Europe/Istanbul')::date`,
      [userId],
    );
    const used = Number(result.rows[0]?.free_gifts_used ?? 0);
    return {
      dailyLimit: GiftService.freeGiftsPerDay,
      used,
      remaining: Math.max(0, GiftService.freeGiftsPerDay - used),
    };
  }

  private async rewardSummary(userId: string) {
    const wallet = await this.wallet(userId);
    const profileXp = Number(wallet.profile_xp);
    const profileLevel = this.levelFromXp(profileXp);
    const result = await this.infra.db.query<RewardRow & { claimed: boolean }>(
      `select r.reward_key,r.level,r.reward_type,r.amount,r.title,r.cosmetic_code,
              (c.user_id is not null) as claimed
       from xp_reward_catalog r
       left join user_xp_reward_claims c
         on c.reward_key=r.reward_key and c.user_id=$1
       where r.active=true
       order by r.level asc,r.sort_order asc,r.reward_key asc`,
      [userId],
    );
    const rewards = result.rows.map((reward) => ({
      rewardKey: reward.reward_key,
      level: Number(reward.level),
      rewardType: reward.reward_type,
      amount: Number(reward.amount),
      title: reward.title,
      cosmeticCode: reward.cosmetic_code,
      unlocked: profileLevel >= Number(reward.level),
      claimed: reward.claimed === true,
    }));
    return {
      profileXp,
      profileLevel,
      nextLevelXp: this.nextLevelXp(profileLevel),
      dailyGiftXpCap: GiftService.giftProfileXpDailyCap,
      rewards,
      nextReward: rewards.find((reward) => reward.level > profileLevel) ?? null,
      unlockedCosmetics: rewards
        .filter((reward) => reward.claimed && reward.cosmeticCode)
        .map((reward) => reward.cosmeticCode),
    };
  }

  private async syncXpRewards(userId: string) {
    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(hashtext($1))', [
        `xp-reward:${userId}`,
      ]);
      await client.query(
        `insert into user_wallets(user_id) values($1)
         on conflict(user_id) do nothing`,
        [userId],
      );
      const walletResult = await client.query<{ profile_xp: number }>(
        `select profile_xp from user_wallets where user_id=$1 for update`,
        [userId],
      );
      const level = this.levelFromXp(Number(walletResult.rows[0]?.profile_xp ?? 0));
      const rewards = await client.query<RewardRow>(
        `select reward_key,level,reward_type,amount,title,cosmetic_code
         from xp_reward_catalog
         where active=true and level<=$2
         order by level asc,sort_order asc,reward_key asc`,
        [userId, level],
      );

      for (const reward of rewards.rows) {
        const claimed = await client.query(
          `insert into user_xp_reward_claims(user_id,reward_key)
           values($1,$2)
           on conflict(user_id,reward_key) do nothing
           returning reward_key`,
          [userId, reward.reward_key],
        );
        if (claimed.rowCount === 0) continue;

        if (reward.reward_type === 'coins' && Number(reward.amount) > 0) {
          const balance = await client.query<{ coin_balance: number }>(
            `update user_wallets
             set coin_balance=coin_balance+$2,updated_at=now()
             where user_id=$1
             returning coin_balance`,
            [userId, Number(reward.amount)],
          );
          await client.query(
            `insert into wallet_transactions(
               user_id,transaction_type,coin_delta,balance_after,
               reference_type,idempotency_key,metadata
             ) values($1,'xp_reward',$2,$3,'xp_reward',$4,
                      jsonb_build_object('rewardKey',$5::text,'level',$6::int))
             on conflict(user_id,idempotency_key) where idempotency_key is not null do nothing`,
            [
              userId,
              Number(reward.amount),
              Number(balance.rows[0]?.coin_balance ?? 0),
              `xp-reward:${reward.reward_key}`,
              reward.reward_key,
              Number(reward.level),
            ],
          );
        }

        if (reward.reward_type === 'premium_days' && Number(reward.amount) > 0) {
          const grantBase = await client.query<{ base_at: Date }>(
            `select greatest(
               now(),
               coalesce((select max(expires_at) from premium_grants where user_id=$1),now()),
               coalesce((
                 select expires_at from user_subscriptions
                 where user_id=$1
                   and status in ('active','grace_period','billing_issue')
                   and expires_at>now()
                 limit 1
               ),now())
             ) as base_at`,
            [userId],
          );
          const startsAt = new Date(grantBase.rows[0]?.base_at ?? new Date());
          const expiresAt = new Date(
            startsAt.getTime() + Number(reward.amount) * 24 * 60 * 60 * 1000,
          );
          await client.query(
            `insert into premium_grants(user_id,source,source_key,starts_at,expires_at)
             values($1,'xp_reward',$2,$3,$4)
             on conflict(user_id,source,source_key) do nothing`,
            [userId, reward.reward_key, startsAt, expiresAt],
          );
        }
      }
      await client.query('commit');
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }

  private async consumeDailyFreeGift(client: PoolClient, userId: string) {
    await client.query(
      `insert into user_daily_gift_usage(user_id,usage_date)
       values($1,(now() at time zone 'Europe/Istanbul')::date)
       on conflict(user_id,usage_date) do nothing`,
      [userId],
    );
    const result = await client.query<{ free_gifts_used: number }>(
      `update user_daily_gift_usage
       set free_gifts_used=free_gifts_used+1,updated_at=now()
       where user_id=$1
         and usage_date=(now() at time zone 'Europe/Istanbul')::date
         and free_gifts_used<$2
       returning free_gifts_used`,
      [userId, GiftService.freeGiftsPerDay],
    );
    if (!result.rows[0]) {
      throw new BadRequestException('Bugünkü 3 ücretsiz hediyeni kullandın.');
    }
  }

  private async grantGiftProfileXp(
    client: PoolClient,
    userId: string | number,
    requestedXp: number,
  ) {
    const requested = Math.max(0, Number(requestedXp) || 0);
    if (requested === 0) return 0;
    await client.query(
      `insert into user_daily_gift_usage(user_id,usage_date)
       values($1,(now() at time zone 'Europe/Istanbul')::date)
       on conflict(user_id,usage_date) do nothing`,
      [userId],
    );
    const usage = await client.query<{ gift_profile_xp_earned: number }>(
      `select gift_profile_xp_earned
       from user_daily_gift_usage
       where user_id=$1
         and usage_date=(now() at time zone 'Europe/Istanbul')::date
       for update`,
      [userId],
    );
    const earned = Number(usage.rows[0]?.gift_profile_xp_earned ?? 0);
    const granted = Math.min(
      requested,
      Math.max(0, GiftService.giftProfileXpDailyCap - earned),
    );
    if (granted <= 0) return 0;
    await client.query(
      `update user_daily_gift_usage
       set gift_profile_xp_earned=gift_profile_xp_earned+$2,updated_at=now()
       where user_id=$1
         and usage_date=(now() at time zone 'Europe/Istanbul')::date`,
      [userId, granted],
    );
    await client.query(
      `update user_wallets
       set profile_xp=profile_xp+$2,updated_at=now()
       where user_id=$1`,
      [userId, granted],
    );
    return granted;
  }

  async catalog(userId: string) {
    await this.syncXpRewards(userId);
    const [wallet, gifts, freeGiftAllowance] = await Promise.all([
      this.wallet(userId),
      this.infra.db.query<GiftCatalogRow>(
        `select id::text,code,name,emoji,coin_cost,gift_xp,generosity_xp,profile_xp,is_daily_free
         from gift_catalog
         where active=true
         order by sort_order asc,id asc`,
      ),
      this.freeGiftAllowance(userId),
    ]);
    return {
      ok: true,
      wallet: this.serializeWallet(wallet, true),
      freeGiftAllowance,
      gifts: gifts.rows.map((gift) => ({
        id: gift.id,
        code: gift.code,
        name: gift.name,
        emoji: gift.emoji,
        coinCost: Number(gift.coin_cost),
        giftXp: Number(gift.gift_xp),
        generosityXp: Number(gift.generosity_xp),
        profileXp: Number(gift.profile_xp),
        dailyFree: gift.is_daily_free === true,
      })),
      rules: {
        roomOnly: true,
        textRoomsOnly: true,
        affectsMatching: false,
        maxGiftsPerSenderPerRoom: GiftService.giftsPerRoomLimit,
        freeGiftsPerDay: GiftService.freeGiftsPerDay,
        giftProfileXpDailyCap: GiftService.giftProfileXpDailyCap,
      },
    };
  }

  async mySummary(userId: string) {
    await this.syncXpRewards(userId);
    const [wallet, xpRewards, freeGiftAllowance] = await Promise.all([
      this.wallet(userId),
      this.rewardSummary(userId),
      this.freeGiftAllowance(userId),
    ]);
    return {
      ok: true,
      summary: this.serializeWallet(wallet, true),
      xpRewards,
      freeGiftAllowance,
    };
  }

  async publicSummary(requesterUserId: string, targetUserId: string) {
    const active = await this.infra.db.query<{ exists: boolean }>(
      `select exists(select 1 from users where id=$1 and status='active') as exists`,
      [targetUserId],
    );
    if (!active.rows[0]?.exists) throw new NotFoundException('Kullanıcı bulunamadı.');
    const wallet = await this.wallet(targetUserId);
    return {
      ok: true,
      userId: targetUserId,
      summary: this.serializeWallet(wallet, String(requesterUserId) === String(targetUserId)),
    };
  }

  private async assertRoomAccess(userId: string, roomId: string | number) {
    const result = await this.infra.db.query<{ exists: boolean }>(
      `select exists(
         select 1 from room_members
         where room_id=$1 and user_id=$2 and admin_removed_at is null
       ) as exists`,
      [roomId, userId],
    );
    if (!result.rows[0]?.exists) throw new ForbiddenException('Bu odanın hediyelerine erişimin yok.');
  }

  async roomHistory(userId: string, roomId: string | number, afterId = 0) {
    await this.assertRoomAccess(userId, roomId);
    const result = await this.infra.db.query(
      `select
         rg.id::text as gift_id,
         rg.sender_user_id::text,
         rg.recipient_user_id::text,
         sender.display_name,
         sender.photo_urls,
         recipient.display_name as recipient_display_name,
         recipient.photo_urls as recipient_photo_urls,
         gc.code as gift_code,
         gc.name as gift_name,
         gc.emoji,
         rg.coin_cost,
         rg.gift_xp,
         rg.generosity_xp,
         rg.created_at
       from room_gifts rg
       join gift_catalog gc on gc.id=rg.gift_id
       left join profiles sender on sender.user_id=rg.sender_user_id
       left join profiles recipient on recipient.user_id=rg.recipient_user_id
       where rg.room_id=$1 and rg.id>$2
       order by rg.id asc
       limit 200`,
      [roomId, Math.max(0, afterId)],
    );
    return { ok: true, gifts: result.rows.map((row) => this.giftEnvelope(row)) };
  }

  private giftEnvelope(row: Record<string, any>) {
    const senderName = row.display_name?.toString().trim() || 'Meet6';
    const recipientName = row.recipient_display_name?.toString().trim() || 'Meet6';
    const emoji = row.emoji?.toString() || '🎁';
    const giftName = row.gift_name?.toString() || 'Hediye';
    return {
      _kind: 'gift',
      id: `gift:${row.gift_id}`,
      gift_id: row.gift_id?.toString(),
      sender_user_id: row.sender_user_id?.toString(),
      recipient_user_id: row.recipient_user_id?.toString(),
      display_name: senderName,
      photo_urls: row.photo_urls ?? [],
      recipient_display_name: recipientName,
      recipient_photo_urls: row.recipient_photo_urls ?? [],
      gift_code: row.gift_code,
      gift_name: giftName,
      emoji,
      coin_cost: Number(row.coin_cost ?? 0),
      gift_xp: Number(row.gift_xp ?? 0),
      generosity_xp: Number(row.generosity_xp ?? 0),
      body: `🎁 ${senderName}, ${recipientName} kişisine ${emoji} ${giftName} gönderdi`,
      created_at: row.created_at,
    };
  }

  private async giftById(giftId: string | number) {
    const result = await this.infra.db.query(
      `select
         rg.id::text as gift_id,
         rg.sender_user_id::text,
         rg.recipient_user_id::text,
         sender.display_name,
         sender.photo_urls,
         recipient.display_name as recipient_display_name,
         recipient.photo_urls as recipient_photo_urls,
         gc.code as gift_code,
         gc.name as gift_name,
         gc.emoji,
         rg.coin_cost,
         rg.gift_xp,
         rg.generosity_xp,
         rg.created_at
       from room_gifts rg
       join gift_catalog gc on gc.id=rg.gift_id
       left join profiles sender on sender.user_id=rg.sender_user_id
       left join profiles recipient on recipient.user_id=rg.recipient_user_id
       where rg.id=$1`,
      [giftId],
    );
    return result.rows[0] ? this.giftEnvelope(result.rows[0]) : null;
  }

  async sendRoomGift(
    userId: string,
    roomId: string | number,
    recipientUserId: string | number,
    giftCodeInput: string,
    clientGiftIdInput: string,
  ) {
    await this.runtimeSettings.assertOperational();
    if (String(userId) === String(recipientUserId)) {
      throw new BadRequestException('Kendine hediye gönderemezsin.');
    }

    const giftCode = this.normalizeGiftCode(giftCodeInput);
    const clientGiftId = this.normalizeClientGiftId(clientGiftIdInput);
    await this.rooms.syncExpiredRooms();

    const client = await this.infra.db.connect();
    let giftId: string | null = null;
    let deduplicated = false;
    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(hashtext($1))', [
        `room-gift:${userId}:${clientGiftId}`,
      ]);

      const existing = await client.query<{ id: string }>(
        `select id::text from room_gifts
         where sender_user_id=$1 and client_gift_id=$2
         limit 1`,
        [userId, clientGiftId],
      );
      if (existing.rows[0]?.id) {
        giftId = existing.rows[0].id;
        deduplicated = true;
        await client.query('commit');
      } else {
        const access = await client.query<{
          status: string;
          room_mode: string;
          sender_member: boolean;
          recipient_member: boolean;
        }>(
          `select r.status,r.room_mode,
                  exists(
                    select 1 from room_members rm
                    where rm.room_id=r.id and rm.user_id=$2
                      and rm.left_at is null and rm.admin_removed_at is null
                  ) as sender_member,
                  exists(
                    select 1 from room_members rm
                    where rm.room_id=r.id and rm.user_id=$3
                      and rm.left_at is null and rm.admin_removed_at is null
                  ) as recipient_member
           from rooms r where r.id=$1
           for update`,
          [roomId, userId, recipientUserId],
        );
        const room = access.rows[0];
        if (!room || !room.sender_member) throw new ForbiddenException('Bu odaya erişimin yok.');
        if (room.room_mode !== 'text') {
          throw new BadRequestException('Hediyeler yalnız grup yazılı sohbetinde gönderilebilir.');
        }
        if (room.status !== 'active') throw new BadRequestException('Oda sohbeti kapandı.');
        if (!room.recipient_member) throw new BadRequestException('Hediye alacak kişi artık odada değil.');

        const giftResult = await client.query<GiftCatalogRow>(
          `select id::text,code,name,emoji,coin_cost,gift_xp,generosity_xp,profile_xp,is_daily_free
           from gift_catalog where code=$1 and active=true
           limit 1`,
          [giftCode],
        );
        const gift = giftResult.rows[0];
        if (!gift) throw new NotFoundException('Hediye bulunamadı.');

        const sentCount = await client.query<{ count: string }>(
          `select count(*)::text as count
           from room_gifts where room_id=$1 and sender_user_id=$2`,
          [roomId, userId],
        );
        if (Number(sentCount.rows[0]?.count ?? 0) >= GiftService.giftsPerRoomLimit) {
          throw new BadRequestException('Bu odada hediye gönderme sınırına ulaştın.');
        }

        await client.query(
          `insert into user_wallets(user_id) values($1),($2)
           on conflict(user_id) do nothing`,
          [userId, recipientUserId],
        );

        const rateKey = `room-gift:${roomId}:${userId}`;
        const allowed = await this.infra.redis.set(rateKey, '1', 'EX', 2, 'NX');
        if (!allowed) throw new BadRequestException('Çok hızlı hediye gönderiyorsun.');

        if (gift.is_daily_free) {
          await this.consumeDailyFreeGift(client, userId);
        }

        const debit = await client.query<{ coin_balance: number }>(
          `update user_wallets
           set coin_balance=coin_balance-$2,
               generosity_xp=generosity_xp+$3,
               gifts_sent=gifts_sent+1,
               updated_at=now()
           where user_id=$1 and coin_balance >= $2
           returning coin_balance`,
          [userId, Number(gift.coin_cost), Number(gift.generosity_xp)],
        );
        if (!debit.rows[0]) throw new BadRequestException('Yeterli jetonun yok.');

        await client.query(
          `update user_wallets
           set gift_xp=gift_xp+$2,
               gifts_received=gifts_received+1,
               updated_at=now()
           where user_id=$1`,
          [recipientUserId, Number(gift.gift_xp)],
        );

        await this.grantGiftProfileXp(client, userId, Number(gift.profile_xp));
        await this.grantGiftProfileXp(client, recipientUserId, Number(gift.profile_xp));

        const inserted = await client.query<{ id: string }>(
          `insert into room_gifts(
             room_id,sender_user_id,recipient_user_id,gift_id,
             coin_cost,gift_xp,generosity_xp,client_gift_id
           )
           values($1,$2,$3,$4,$5,$6,$7,$8)
           returning id::text`,
          [
            roomId,
            userId,
            recipientUserId,
            gift.id,
            Number(gift.coin_cost),
            Number(gift.gift_xp),
            Number(gift.generosity_xp),
            clientGiftId,
          ],
        );
        giftId = inserted.rows[0]?.id ?? null;
        if (!giftId) throw new Error('Hediye kaydedilemedi.');

        await client.query(
          `insert into wallet_transactions(
             user_id,transaction_type,coin_delta,balance_after,
             reference_type,reference_id,idempotency_key,metadata
           )
           values($1,'gift_send',$2,$3,'room_gift',$4,$5,
                  jsonb_build_object('roomId',$6::text,'recipientUserId',$7::text,'giftCode',$8::text))`,
          [
            userId,
            -Number(gift.coin_cost),
            Number(debit.rows[0].coin_balance),
            giftId,
            `gift:${clientGiftId}`,
            roomId,
            recipientUserId,
            gift.code,
          ],
        );

        const sender = await client.query<{ display_name: string | null }>(
          'select display_name from profiles where user_id=$1',
          [userId],
        );
        const senderName = sender.rows[0]?.display_name?.trim() || 'Meet6';
        await client.query(
          `insert into notifications(user_id,type,title,body,data)
           values(
             $1,'room_gift','Yeni hediye 🎁',$2,
             jsonb_build_object(
               'roomId',$3::text,
               'giftId',$4::text,
               'senderUserId',$5::text,
               'giftCode',$6::text
             )
           )`,
          [
            recipientUserId,
            `${senderName} sana ${gift.emoji} ${gift.name} gönderdi.`,
            roomId,
            giftId,
            userId,
            gift.code,
          ],
        );

        await client.query('commit');
      }
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }

    if (!giftId) throw new Error('Hediye işlemi tamamlanamadı.');
    if (!deduplicated) {
      await Promise.allSettled([
        this.syncXpRewards(userId),
        this.syncXpRewards(String(recipientUserId)),
      ]);
    }
    const [gift, senderWallet, recipientWallet, freeGiftAllowance, xpRewards] = await Promise.all([
      this.giftById(giftId),
      this.wallet(userId),
      this.wallet(recipientUserId),
      this.freeGiftAllowance(userId),
      this.rewardSummary(userId),
    ]);
    return {
      ok: true,
      deduplicated,
      gift,
      wallet: this.serializeWallet(senderWallet, true),
      recipientSummary: this.serializeWallet(recipientWallet, false),
      freeGiftAllowance,
      xpRewards,
    };
  }
}
