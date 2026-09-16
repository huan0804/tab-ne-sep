-- TAB: Né Sếp — Supabase schema
-- Thay thế cho model sharded (players_shard/{0..39}) từng dùng với Claude
-- Artifact's db capability. Postgres không có trần 5.000-document nên mỗi
-- người chơi là 1 dòng thật — không cần sharding, ORDER BY hoạt động thật.

-- ============================================================
-- 1. Bảng người chơi / leaderboard
-- ============================================================
create table if not exists players (
  id text primary key,                        -- playerId ngẫu nhiên theo trình duyệt (giữ nguyên từ localStorage cũ)
  name text not null default 'Người chơi ẩn danh',
  session_count integer not null default 0,
  total_correct_time double precision not null default 0,
  avg_score double precision not null default 0,   -- total_correct_time / session_count, dùng để xếp hạng
  best_score double precision not null default 0,
  total_play_time double precision not null default 0,
  created_at timestamptz not null default now(),
  last_visit timestamptz not null default now(),
  is_seed boolean not null default false       -- đánh dấu 6 "đối thủ ảo" seed sẵn, để phân biệt với người chơi thật
);

-- Query chính của leaderboard: ORDER BY avg_score DESC — cần index để nhanh khi nhiều người chơi.
create index if not exists players_avg_score_idx on players (avg_score desc);

-- ============================================================
-- 2. Analytics ẩn danh gộp (4 "document" cũ → giờ là 4 dòng cố định)
-- ============================================================

-- Giờ truy cập trong ngày: 1 dòng, các cột h0..h23 đếm dồn.
create table if not exists analytics_access_hours (
  id integer primary key default 1,
  h0 integer not null default 0, h1 integer not null default 0, h2 integer not null default 0,
  h3 integer not null default 0, h4 integer not null default 0, h5 integer not null default 0,
  h6 integer not null default 0, h7 integer not null default 0, h8 integer not null default 0,
  h9 integer not null default 0, h10 integer not null default 0, h11 integer not null default 0,
  h12 integer not null default 0, h13 integer not null default 0, h14 integer not null default 0,
  h15 integer not null default 0, h16 integer not null default 0, h17 integer not null default 0,
  h18 integer not null default 0, h19 integer not null default 0, h20 integer not null default 0,
  h21 integer not null default 0, h22 integer not null default 0, h23 integer not null default 0,
  total integer not null default 0,
  constraint single_row check (id = 1)
);
insert into analytics_access_hours (id) values (1) on conflict (id) do nothing;

-- Thời gian mỗi phase (intro/game/result): tổng + số lần, để tính trung bình.
create table if not exists analytics_screen_time (
  id integer primary key default 1,
  intro_sum double precision not null default 0, intro_count integer not null default 0,
  game_sum double precision not null default 0, game_count integer not null default 0,
  result_sum double precision not null default 0, result_count integer not null default 0,
  constraint single_row check (id = 1)
);
insert into analytics_screen_time (id) values (1) on conflict (id) do nothing;

-- Heatmap chuột 10x10, lưu dạng JSONB {"col_row": count}, gộp cho cả intro và game.
create table if not exists analytics_heatmap (
  screen text primary key,   -- 'intro' hoặc 'game'
  buckets jsonb not null default '{}'::jsonb
);
insert into analytics_heatmap (screen) values ('intro'), ('game') on conflict (screen) do nothing;

-- ============================================================
-- 3. Row Level Security — cho phép mọi người đọc, và ghi có kiểm soát
-- ============================================================
-- Game chạy hoàn toàn phía client (không có backend riêng), nên viewer cần
-- quyền insert/update trực tiếp bằng publishable key. Đây là đánh đổi chấp
-- nhận được cho 1 mini-game công khai, không có dữ liệu nhạy cảm — giống
-- hệt mô hình "mọi người dùng chung 1 kho db" mà bản Claude Artifact cũ đã
-- dùng.

alter table players enable row level security;
alter table analytics_access_hours enable row level security;
alter table analytics_screen_time enable row level security;
alter table analytics_heatmap enable row level security;

create policy "players: ai cũng đọc được" on players for select using (true);
create policy "players: ai cũng ghi được (upsert điểm của chính mình)" on players for insert with check (true);
create policy "players: ai cũng update được" on players for update using (true);

create policy "access_hours: đọc" on analytics_access_hours for select using (true);
create policy "access_hours: ghi" on analytics_access_hours for update using (true);

create policy "screen_time: đọc" on analytics_screen_time for select using (true);
create policy "screen_time: ghi" on analytics_screen_time for update using (true);

create policy "heatmap: đọc" on analytics_heatmap for select using (true);
create policy "heatmap: ghi" on analytics_heatmap for update using (true);

-- ============================================================
-- 4. Seed 6 "đối thủ ảo" — idempotent, chạy lại không tạo trùng
-- ============================================================
insert into players (id, name, session_count, total_correct_time, avg_score, best_score, total_play_time, is_seed)
values
  ('seed_a1', 'Long Lươn', 14, 592.2, 592.2/14, 55.2, 592.2*2, true),
  ('seed_a2', 'Vy Vui Vẻ', 9, 348.3, 348.3/9, 47.1, 348.3*2, true),
  ('seed_a3', 'Khánh Đụt', 22, 1141.8, 1141.8/22, 63.4, 1141.8*2, true),
  ('seed_a4', 'Bánh Bèo Vlog', 5, 147.0, 147.0/5, 34.0, 147.0*2, true),
  ('seed_a5', 'Sếp Tưởng Em Ngoan', 17, 765.0, 765.0/17, 58.8, 765.0*2, true),
  ('seed_a6', 'Chíp Lười Biếng', 7, 235.2, 235.2/7, 40.2, 235.2*2, true)
on conflict (id) do update set
  name = excluded.name,
  session_count = excluded.session_count,
  total_correct_time = excluded.total_correct_time,
  avg_score = excluded.avg_score,
  best_score = excluded.best_score,
  total_play_time = excluded.total_play_time;
