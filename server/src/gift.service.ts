import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

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
};

type WalletRow = {
  coin_balance: number;
  gift_xp: number;
  generosity_xp: number;
  gifts_received: number;
  gifts_sent: number;
};

@Injectable()
export class GiftService {
  private static readonly giftsPerRoomLimit = 20;

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
    return Math.min(20, 1 + Math.floor(Math.sqrt(xp / 50)));
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
    const value: Record<string, unknown> = {
      giftXp: Number(wallet.gift_xp),
      generosityXp: Number(wallet.generosity_xp),
      giftLevel: this.levelFromXp(Number(wallet.gift_xp)),
      generosityLevel: this.levelFromXp(Number(wallet.generosity_xp)),
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
      `select coin_balance,gift_xp,generosity_xp,gifts_received,gifts_sent
       from user_wallets where user_id=$1`,
      [userId],
    );
    return result.rows[0] ?? {
      coin_balance: 0,
      gift_xp: 0,
      generosity_xp: 0,
      gifts_received: 0,
      gifts_sent: 0,
    };
  }

  async catalog(userId: string) {
    const [wallet, gifts] = await Promise.all([
      this.wallet(userId),
      this.infra.db.query<GiftCatalogRow>(
        `select id::text,code,name,emoji,coin_cost,gift_xp,generosity_xp
         from gift_catalog
         where active=true
         order by sort_order asc,id asc`,
      ),
    ]);
    return {
      ok: true,
      wallet: this.serializeWallet(wallet, true),
      gifts: gifts.rows.map((gift) => ({
        id: gift.id,
        code: gift.code,
        name: gift.name,
        emoji: gift.emoji,
        coinCost: Number(gift.coin_cost),
        giftXp: Number(gift.gift_xp),
        generosityXp: Number(gift.generosity_xp),
      })),
      rules: {
        roomOnly: true,
        textRoomsOnly: true,
        affectsMatching: false,
        maxGiftsPerSenderPerRoom: GiftService.giftsPerRoomLimit,
      },
    };
  }

  async mySummary(userId: string) {
    const wallet = await this.wallet(userId);
    return { ok: true, summary: this.serializeWallet(wallet, true) };
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
          `select id::text,code,name,emoji,coin_cost,gift_xp,generosity_xp
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
    const [gift, senderWallet, recipientWallet] = await Promise.all([
      this.giftById(giftId),
      this.wallet(userId),
      this.wallet(recipientUserId),
    ]);
    return {
      ok: true,
      deduplicated,
      gift,
      wallet: this.serializeWallet(senderWallet, true),
      recipientSummary: this.serializeWallet(recipientWallet, false),
    };
  }
}
