import { Injectable } from '@nestjs/common';
import { InfrastructureService } from './infrastructure.service';

export type TabuCard = {
  id: string;
  word: string;
  category: string;
  difficulty: string;
  forbidden: string[];
};

@Injectable()
export class TabuWordRepository {
  constructor(private readonly infra: InfrastructureService) {}

  async nextCard(userIds: string[], excludeIds: string[] = []): Promise<TabuCard> {
    const select = async (avoidRecent: boolean) => this.infra.db.query<{
      id: string; word: string; category: string; difficulty: string; forbidden: string[];
    }>(
      `select w.id::text,w.word,w.category,w.difficulty,
              coalesce(array_agg(f.word order by f.id) filter(where f.id is not null),'{}') forbidden
       from tabu_words w
       left join tabu_forbidden_words f on f.tabu_word_id=w.id
       where w.enabled=true
         and not (w.id=any($2::bigint[]))
         and ($3::boolean=false or not exists(
           select 1 from tabu_word_history h
           where h.tabu_word_id=w.id and h.user_id=any($1::bigint[])
             and h.seen_at>now()-interval '14 days'))
       group by w.id
       having count(f.id)=4
       order by random()
       limit 1`,
      [userIds, excludeIds.length ? excludeIds : ['0'], avoidRecent],
    );

    let row = (await select(true)).rows[0];
    if (!row) row = (await select(false)).rows[0];
    if (!row) throw new Error('Aktif Tabu kelimesi bulunamadı. Seed/import çalıştırılmalı.');

    await this.infra.db.query(
      `insert into tabu_word_history(user_id,tabu_word_id,seen_at)
       select unnest($1::bigint[]),$2,now()
       on conflict(user_id,tabu_word_id) do update set seen_at=excluded.seen_at`,
      [userIds, row.id],
    );
    return { ...row, forbidden: row.forbidden.slice(0, 4) };
  }
}
