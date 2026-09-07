create table if not exists red_flag_questions (
  id bigserial primary key,
  prompt text not null unique,
  category text not null check (category in ('relationship','messaging','jealousy','social_media','first_date','friendship','boundaries','daily_habits')),
  difficulty text not null check (difficulty in ('light','medium','debate')),
  min_age integer not null default 18 check (min_age >= 18),
  max_age integer,
  relationship_intent text,
  active boolean not null default true,
  admin_approved boolean not null default true,
  safe boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists red_flag_question_history (
  user_id bigint not null references users(id) on delete cascade,
  question_id bigint not null references red_flag_questions(id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key(user_id, question_id)
);

create index if not exists idx_red_flag_questions_active_category
  on red_flag_questions(active, admin_approved, safe, category, difficulty);
create index if not exists idx_red_flag_question_history_recent
  on red_flag_question_history(user_id, seen_at desc);

insert into red_flag_questions(prompt, category, difficulty) values
('Mesajlara 8 saat sonra dönmek.', 'messaging', 'light'),
('Mesajı görüp cevap vermemek.', 'messaging', 'medium'),
('Her sabah günaydın mesajı beklemek.', 'messaging', 'light'),
('Günde onlarca kez nerede olduğunu sormak.', 'messaging', 'debate'),
('Tartışınca mesajları tamamen kesmek.', 'messaging', 'medium'),
('Mesajlarda tek kelimelik cevaplar vermek.', 'messaging', 'light'),
('Eski sevgiliyle yakın arkadaş kalmak.', 'relationship', 'debate'),
('Partnerinin her planına dahil olmak istemek.', 'relationship', 'medium'),
('Özel günleri önemsememek.', 'relationship', 'light'),
('İlişkide sorunları arkadaşlara anlatmak.', 'relationship', 'medium'),
('Her şeyi birlikte yapmak istemek.', 'relationship', 'medium'),
('İlişkide sık sık kıyaslama yapmak.', 'relationship', 'debate'),
('Partnerinin şifresini bilmek istemek.', 'boundaries', 'debate'),
('Telefonunu habersiz kontrol etmek.', 'boundaries', 'debate'),
('Tek başına vakit geçirmek istemesine alınmak.', 'boundaries', 'medium'),
('Arkadaşlarıyla görüşmesine karışmak.', 'boundaries', 'debate'),
('Konum paylaşımını sürekli açık tutmasını istemek.', 'boundaries', 'debate'),
('Kişisel eşyalarını izinsiz kullanmak.', 'boundaries', 'medium'),
('İlk buluşmada telefonu sık sık kontrol etmek.', 'first_date', 'light'),
('İlk buluşmada hesabı paylaşmak.', 'first_date', 'light'),
('İlk buluşmaya 30 dakika geç kalmak.', 'first_date', 'medium'),
('İlk buluşmada eski ilişkilerden uzun uzun bahsetmek.', 'first_date', 'medium'),
('İlk buluşmada sürekli kendinden bahsetmek.', 'first_date', 'medium'),
('İlk buluşmada planı son dakika değiştirmek.', 'first_date', 'light'),
('Partnerinin eski fotoğraflarını sosyal medyada tutması.', 'social_media', 'medium'),
('İlişkiyi sosyal medyada paylaşmak istememek.', 'social_media', 'medium'),
('Partnerinin takip ettiği kişileri kontrol etmek.', 'social_media', 'debate'),
('Her paylaşımına yorum yapmasını beklemek.', 'social_media', 'light'),
('Çift fotoğraflarını kaldırınca açıklama istemek.', 'social_media', 'medium'),
('Sosyal medyada eski sevgiliyi takip etmeye devam etmek.', 'social_media', 'debate'),
('Yakın arkadaşlarından birini kıskanmak.', 'jealousy', 'medium'),
('Karşı cins arkadaşlarıyla yalnız buluşmasına rahatsız olmak.', 'jealousy', 'debate'),
('Eski sevgilinin adını duyunca gerilmek.', 'jealousy', 'light'),
('Partnerinin beğenilerini sık sık kontrol etmek.', 'jealousy', 'debate'),
('Birinin partnerine iltifat etmesine bozulmak.', 'jealousy', 'light'),
('Partnerinin iş arkadaşlarıyla eğlenmesine alınmak.', 'jealousy', 'medium'),
('En yakın arkadaşının fikrini ilişkide çok önemsemek.', 'friendship', 'medium'),
('Partnerini arkadaş grubuna hemen dahil etmek istemek.', 'friendship', 'light'),
('Arkadaş planını partner için sürekli iptal etmek.', 'friendship', 'medium'),
('Partneri sevmeyen arkadaşla görüşmeye devam etmek.', 'friendship', 'debate'),
('Arkadaşların ilişki kararlarına karışması.', 'friendship', 'debate'),
('Hafta sonunu arkadaşlarla geçirmek istemek.', 'friendship', 'light'),
('Her gün mesajlaşmak istemek.', 'daily_habits', 'light'),
('Hafta sonları geç uyanmak.', 'daily_habits', 'light'),
('Plan yapmadan spontane yaşamak.', 'daily_habits', 'light'),
('Ev işlerini sürekli ertelemek.', 'daily_habits', 'medium'),
('Tatilde tüm programı önceden yapmak istemek.', 'daily_habits', 'light'),
('Her yere geç kalmayı normal görmek.', 'daily_habits', 'medium')
on conflict(prompt) do update set
  category=excluded.category,
  difficulty=excluded.difficulty,
  active=true,
  admin_approved=true,
  safe=true,
  updated_at=now();
