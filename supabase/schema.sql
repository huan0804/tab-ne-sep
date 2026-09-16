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
-- 2b. Sessions — 1 dòng mỗi ván, để phân tích A/B test theo UI variant
-- ============================================================
-- "players" chỉ lưu số liệu TỔNG HỢP (avg/best) nên không thể tách theo
-- variant UI (radar vs elip) sau khi đã cộng dồn. Bảng này lưu từng ván riêng
-- lẻ kèm variant, phục vụ so sánh A/B (win rate, avg score theo từng bản UI)
-- mà không ảnh hưởng logic leaderboard hiện tại (vẫn đọc từ "players").
create table if not exists sessions (
  id bigint generated always as identity primary key,
  player_id text not null references players(id),
  variant text not null,              -- 'ellipse' (TAB-Ne-Sep.html) hoặc 'radar' (TAB-Ne-Sep_v1-radar.html)
  score double precision not null,    -- correctTime của ván đó
  play_time double precision not null,-- elapsedTime của ván đó
  created_at timestamptz not null default now()
);
create index if not exists sessions_variant_idx on sessions (variant);
create index if not exists sessions_player_id_idx on sessions (player_id);

alter table sessions enable row level security;
drop policy if exists "sessions: ai cũng đọc được" on sessions;
create policy "sessions: ai cũng đọc được" on sessions for select using (true);
drop policy if exists "sessions: ai cũng ghi được" on sessions;
create policy "sessions: ai cũng ghi được" on sessions for insert with check (true);

-- ============================================================
-- 2c. Rooms — phòng chơi nhóm, 1 Sếp chung cho cả phòng
-- ============================================================
-- Vị trí Sếp KHÔNG lưu ở đây — Host tính và phát (Broadcast) trực tiếp cho
-- các client trong phòng qua Supabase Realtime, không ghi liên tục vào DB
-- (tần suất ~20 lần/giây sẽ làm nghẽn database nếu ghi mỗi frame). Bảng này
-- chỉ giữ thông tin ít thay đổi: ai là host, phòng đang chờ hay đang chơi —
-- dùng Postgres Changes (không phải Broadcast) để đảm bảo mọi client nhận
-- được sự kiện "bắt đầu" dù subscribe muộn, khác với vị trí Sếp (mất vài
-- frame không sao).
create table if not exists rooms (
  id text primary key,                 -- room code, 6 ký tự dễ đọc (vd: "AB12CD")
  host_player_id text not null references players(id),
  status text not null default 'waiting', -- 'waiting' | 'playing'
  created_at timestamptz not null default now()
);

alter table rooms enable row level security;
drop policy if exists "rooms: ai cũng đọc được" on rooms;
create policy "rooms: ai cũng đọc được" on rooms for select using (true);
drop policy if exists "rooms: ai cũng tạo được" on rooms;
create policy "rooms: ai cũng tạo được" on rooms for insert with check (true);
drop policy if exists "rooms: ai cũng update được" on rooms;
create policy "rooms: ai cũng update được" on rooms for update using (true);

-- Postgres Changes (client subscribe sb.channel(...).on('postgres_changes',...))
-- chỉ nhận được sự kiện nếu bảng được thêm vào publication này. Bọc kiểm tra
-- tồn tại để chạy lại schema.sql nhiều lần không lỗi "already member of".
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'rooms'
  ) then
    alter publication supabase_realtime add table rooms;
  end if;
end $$;

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

drop policy if exists "players: ai cũng đọc được" on players;
create policy "players: ai cũng đọc được" on players for select using (true);
drop policy if exists "players: ai cũng ghi được (upsert điểm của chính mình)" on players;
create policy "players: ai cũng ghi được (upsert điểm của chính mình)" on players for insert with check (true);
drop policy if exists "players: ai cũng update được" on players;
create policy "players: ai cũng update được" on players for update using (true);

drop policy if exists "access_hours: đọc" on analytics_access_hours;
create policy "access_hours: đọc" on analytics_access_hours for select using (true);
drop policy if exists "access_hours: ghi" on analytics_access_hours;
create policy "access_hours: ghi" on analytics_access_hours for update using (true);

drop policy if exists "screen_time: đọc" on analytics_screen_time;
create policy "screen_time: đọc" on analytics_screen_time for select using (true);
drop policy if exists "screen_time: ghi" on analytics_screen_time;
create policy "screen_time: ghi" on analytics_screen_time for update using (true);

drop policy if exists "heatmap: đọc" on analytics_heatmap;
create policy "heatmap: đọc" on analytics_heatmap for select using (true);
drop policy if exists "heatmap: ghi" on analytics_heatmap;
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
