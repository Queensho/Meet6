import { Injectable } from '@nestjs/common';

import { InfrastructureService } from './infrastructure.service';

@Injectable()
export class SupportService {
  constructor(private readonly infra: InfrastructureService) {}

  async create(userId: string, topicInput: string, messageInput: string) {
    const topic = topicInput.trim();
    const message = messageInput.trim();
    const result = await this.infra.db.query(
      `insert into support_requests(user_id, topic, message)
       values($1,$2,$3)
       returning id::text, topic, message, status, created_at`,
      [userId, topic, message],
    );
    return { ok: true, request: result.rows[0] };
  }

  async list(userId: string) {
    const result = await this.infra.db.query(
      `select id::text, topic, message, status, created_at, updated_at
       from support_requests
       where user_id=$1
       order by created_at desc
       limit 50`,
      [userId],
    );
    return { ok: true, requests: result.rows };
  }
}
