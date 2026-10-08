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
  is_seed boolean not null default false,      -- đánh dấu 6 "đối thủ ảo" seed sẵn, để phân biệt với người chơi thật
  current_streak integer not null default 0,   -- số ngày chơi liên tiếp (giờ VN, UTC+7) tính đến last_visit
  longest_streak integer not null default 0    -- chuỗi dài nhất từng đạt, để hiện "kỷ lục cá nhân"
);

-- alter table ... add column if not exists để bảng đã tồn tại trên Supabase
-- (tạo trước khi có 2 cột streak) cũng nhận được cột mới khi chạy lại file này.
alter table players add column if not exists current_streak integer not null default 0;
alter table players add column if not exists longest_streak integer not null default 0;

-- Query chính của leaderboard: ORDER BY avg_score DESC — cần index để nhanh khi nhiều người chơi.
create index if not exists players_avg_score_idx on players (avg_score desc);

-- CHECK constraints — lưới an toàn cuối cùng ở tầng DB, độc lập với logic
-- RPC bên dưới: dù RPC có bug hay bị gọi sai cách nào, Postgres vẫn từ chối
-- giá trị vô lý (âm, hoặc vượt xa giới hạn game). "avg_score"/"best_score"
-- đến từ "correctTime" (docs/GAME_SPEC.md mục 2.7, đã lạc hậu về con số cụ
-- thể — xem game/TAB-Ne-Sep.html CONFIG.matchDuration=60 là nguồn thật):
-- TỔNG thời gian "chơi đúng" suốt trận (mode=work gần Sếp HOẶC mode=personal
-- xa Sếp), khác với ngưỡng targetPersonalTime=30s riêng của LUẬT THẮNG. Một
-- ván chơi giỏi có thể có correctTime gần hết matchDuration=60s — biên 65
-- (60s trận + 5s buffer) đủ rộng cho ván hợp lệ, vẫn chặn được giá trị vượt
-- xa thực tế game. Bọc trong DO block vì "add constraint" không có dạng
-- "if not exists" ở mọi phiên bản Postgres — cách này vẫn giữ được tính
-- idempotent khi chạy lại schema.sql nhiều lần.
do $$
begin
  alter table players add constraint players_avg_score_range check (avg_score >= 0 and avg_score <= 65);
exception when duplicate_object then null;
end $$;
do $$
begin
  alter table players add constraint players_best_score_range check (best_score >= 0 and best_score <= 65);
exception when duplicate_object then null;
end $$;
do $$
begin
  alter table players add constraint players_session_count_nonneg check (session_count >= 0);
exception when duplicate_object then null;
end $$;
do $$
begin
  alter table players add constraint players_total_correct_time_nonneg check (total_correct_time >= 0);
exception when duplicate_object then null;
end $$;
do $$
begin
  alter table players add constraint players_name_length check (char_length(name) <= 40);
exception when duplicate_object then null;
end $$;

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

-- CHECK constraints — biên rộng hơn "players" (mục 1, <=65) có chủ đích:
-- "sessions" lưu TỪNG VÁN riêng lẻ từ 2026-09-19 trở đi, gồm cả dữ liệu
-- thật từ giai đoạn CONFIG.matchDuration=120s (trước khi rút xuống 60s
-- cùng ngày 2026-09-19, xem WORK_LOG.md — "players" chỉ lưu số cộng dồn
-- nên không giữ dấu vết cấu hình cũ, còn "sessions" thì có). Từng phát
-- hiện 10 dòng play_time≈120.0x bị CHECK <=65 chặn khi chạy lại schema.sql
-- lần đầu — xác nhận là dữ liệu thật hợp lệ tại thời điểm ghi, không phải
-- rác, nên nới biên lên 125 (120s trận cũ + 5s buffer) thay vì xoá dữ liệu
-- lịch sử. Bảng này insert tự do (insert with check(true) bên dưới) nên
-- vẫn cần chặn giá trị vô lý ở tầng DB dù rủi ro thấp hơn (chỉ phục vụ A/B
-- testing nội bộ, không ảnh hưởng leaderboard hiển thị cho người chơi).
do $$
begin
  alter table sessions add constraint sessions_score_range check (score >= 0 and score <= 125);
exception when duplicate_object then null;
end $$;
do $$
begin
  alter table sessions add constraint sessions_play_time_range check (play_time >= 0 and play_time <= 125);
exception when duplicate_object then null;
end $$;
do $$
begin
  alter table sessions add constraint sessions_score_le_play_time check (score <= play_time);
exception when duplicate_object then null;
end $$;

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
-- Không còn policy UPDATE public — trước đây using(true) cho phép đổi
-- status/host_player_id của BẤT KỲ phòng nào (phá phòng người khác, cướp
-- quyền host). Chuyển status waiting->playing giờ đi qua RPC
-- start_room_match() (mục 2f) — chỉ host thật của phòng đó gọi được.
drop policy if exists "rooms: ai cũng update được" on rooms;

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
-- 2d. RPC tăng nguyên tử cho 3 bảng analytics — thay cho pattern
-- select-rồi-update phía client (đã dùng trước đây).
-- ============================================================
-- Lý do đổi: analytics_access_hours/analytics_screen_time chỉ có ĐÚNG 1
-- dòng cố định (id=1), analytics_heatmap chỉ có 2 dòng cố định (intro/game)
-- — nghĩa là MỌI người chơi cùng lúc đều ghi vào chung 1-2 dòng đó. Pattern
-- cũ (client SELECT giá trị hiện tại, cộng ở JS, rồi UPDATE giá trị mới)
-- có race condition kinh điển: nếu 2 người chơi SELECT gần như cùng lúc rồi
-- đều UPDATE, người ghi sau ĐÈ MẤT phần cộng của người ghi trước (mất dữ
-- liệu âm thầm, không báo lỗi) — càng đông người chơi cùng lúc, tỷ lệ mất
-- càng cao. RPC dưới đây làm phép cộng NGAY TRONG 1 câu UPDATE ở Postgres
-- (x = x + n), được Postgres tự khoá row trong lúc thực thi — đúng nghĩa
-- atomic, không còn khoảng hở giữa đọc và ghi để race condition xảy ra.
-- security definer: hàm chạy với quyền chủ sở hữu (bỏ qua RLS của chính
-- bảng analytics_* bên trong hàm), cho phép xoá hẳn policy UPDATE public ở
-- mục 3 bên dưới — client giờ chỉ được SELECT trực tiếp + gọi RPC qua
-- supabase-js .rpc(...), không còn được UPDATE tuỳ ý 2 bảng này nữa (thắt
-- chặt hơn so với trước, không chỉ là sửa race condition).
create or replace function increment_access_hour(p_hour int)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  col text := 'h' || p_hour::text;
begin
  if p_hour < 0 or p_hour > 23 then
    raise exception 'invalid hour: %', p_hour;
  end if;
  execute format('update analytics_access_hours set %I = %I + 1, total = total + 1 where id = 1', col, col);
end;
$$;

create or replace function increment_screen_time(p_phase text, p_duration_ms double precision)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  sum_col text := p_phase || '_sum';
  count_col text := p_phase || '_count';
begin
  if p_phase not in ('intro', 'game', 'result') then
    raise exception 'invalid phase: %', p_phase;
  end if;
  execute format(
    'update analytics_screen_time set %I = %I + $1, %I = %I + 1 where id = 1',
    sum_col, sum_col, count_col, count_col
  ) using p_duration_ms;
end;
$$;

-- Heatmap cộng dồn từng bucket vào JSONB — merge nguyên tử bằng jsonb ||
-- (khoá row trong UPDATE) thay vì merge ở JS rồi ghi đè cả object, tránh
-- mất bucket của người chơi khác ghi cùng lúc. p_buckets là JSONB dạng
-- {"col_row": count, ...} do client gửi lên (số lần chuột/tay chạm bucket
-- đó trong phiên vừa xong của riêng client này).
create or replace function increment_heatmap(p_screen text, p_buckets jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_screen not in ('intro', 'game') then
    raise exception 'invalid screen: %', p_screen;
  end if;
  update analytics_heatmap
  set buckets = (
    select jsonb_object_agg(
      key,
      coalesce((buckets->key)::int, 0) + coalesce((p_buckets->key)::int, 0)
    )
    from jsonb_object_keys(buckets || p_buckets) as key
  )
  where screen = p_screen;
end;
$$;

-- Client (publishable key = role "anon") gọi các RPC trên qua supabase-js
-- .rpc(...) — cần GRANT EXECUTE rõ ràng, Postgres không tự cho phép.
grant execute on function increment_access_hour(int) to anon, authenticated;
grant execute on function increment_screen_time(text, double precision) to anon, authenticated;
grant execute on function increment_heatmap(text, jsonb) to anon, authenticated;

-- ============================================================
-- 2e. Analytics THEO NGÀY/TUẦN — bổ sung bên cạnh 3 bảng cộng-dồn-mãi-mãi
-- ở mục 2, KHÔNG thay thế. 3 bảng analytics_* cũ giữ nguyên nguyên vẹn,
-- coi như tổng số all-time (đã có dữ liệu tích luỹ từ trước, không nỡ vứt).
-- ============================================================
-- Lý do tách bảng mới thay vì sửa bảng cũ: analytics_access_hours/
-- screen_time chỉ có ĐÚNG 1 dòng, cộng dồn từ lúc tạo tới giờ — không có
-- chiều thời gian, nên không trả lời được "giờ vàng tuần này có khác tuần
-- trước không" hay "funnel drop-off có cải thiện sau khi sửa UI không".
-- Khoá theo ngày/tuần THẬT theo giờ Việt Nam (UTC+7) — tính SẴN Ở CLIENT
-- bằng vnDateKey()/vnWeekKey() (xem <script>, cùng logic với streak) rồi
-- truyền vào RPC dưới dạng text, KHÔNG để Postgres tự suy ra từ timestamp
-- server — tránh lệch múi giờ nếu server Postgres không chạy ở UTC+7.
create table if not exists analytics_access_hours_daily (
  date_key text primary key,   -- 'YYYY-MM-DD' theo giờ VN, vd '2026-09-22'
  h0 integer not null default 0, h1 integer not null default 0, h2 integer not null default 0,
  h3 integer not null default 0, h4 integer not null default 0, h5 integer not null default 0,
  h6 integer not null default 0, h7 integer not null default 0, h8 integer not null default 0,
  h9 integer not null default 0, h10 integer not null default 0, h11 integer not null default 0,
  h12 integer not null default 0, h13 integer not null default 0, h14 integer not null default 0,
  h15 integer not null default 0, h16 integer not null default 0, h17 integer not null default 0,
  h18 integer not null default 0, h19 integer not null default 0, h20 integer not null default 0,
  h21 integer not null default 0, h22 integer not null default 0, h23 integer not null default 0,
  total integer not null default 0
);

create table if not exists analytics_screen_time_daily (
  date_key text primary key,   -- 'YYYY-MM-DD' theo giờ VN
  intro_sum double precision not null default 0, intro_count integer not null default 0,
  game_sum double precision not null default 0, game_count integer not null default 0,
  result_sum double precision not null default 0, result_count integer not null default 0
);

-- Heatmap theo TUẦN (không phải ngày) — độ phân giải thô hơn 2 bảng trên có
-- chủ đích: heatmap chỉ phục vụ tối ưu vị trí UI/ad, xu hướng theo tuần đã
-- đủ, không cần mịn tới từng ngày (tránh phình số dòng quá nhanh nếu
-- traffic cao, vì đây là 2 dòng/tuần thay vì 2 dòng/ngày).
create table if not exists analytics_heatmap_weekly (
  week_key text not null,      -- 'YYYY-Www' ISO week theo giờ VN, vd '2026-W39'
  screen text not null,        -- 'intro' hoặc 'game'
  buckets jsonb not null default '{}'::jsonb,
  primary key (week_key, screen)
);

-- RPC tăng nguyên tử, cùng lý do/cơ chế atomic như mục 2d — chỉ khác là tự
-- tạo dòng mới cho ngày/tuần chưa từng thấy (insert ... on conflict) thay
-- vì luôn có sẵn 1 dòng cố định để update thẳng.
create or replace function increment_access_hour_daily(p_date_key text, p_hour int)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  col text := 'h' || p_hour::text;
begin
  if p_hour < 0 or p_hour > 23 then
    raise exception 'invalid hour: %', p_hour;
  end if;
  insert into analytics_access_hours_daily (date_key) values (p_date_key)
  on conflict (date_key) do nothing;
  execute format(
    'update analytics_access_hours_daily set %I = %I + 1, total = total + 1 where date_key = $1',
    col, col
  ) using p_date_key;
end;
$$;

create or replace function increment_screen_time_daily(p_date_key text, p_phase text, p_duration_ms double precision)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  sum_col text := p_phase || '_sum';
  count_col text := p_phase || '_count';
begin
  if p_phase not in ('intro', 'game', 'result') then
    raise exception 'invalid phase: %', p_phase;
  end if;
  insert into analytics_screen_time_daily (date_key) values (p_date_key)
  on conflict (date_key) do nothing;
  execute format(
    'update analytics_screen_time_daily set %I = %I + $1, %I = %I + 1 where date_key = $2',
    sum_col, sum_col, count_col, count_col
  ) using p_duration_ms, p_date_key;
end;
$$;

create or replace function increment_heatmap_weekly(p_week_key text, p_screen text, p_buckets jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_screen not in ('intro', 'game') then
    raise exception 'invalid screen: %', p_screen;
  end if;
  insert into analytics_heatmap_weekly (week_key, screen) values (p_week_key, p_screen)
  on conflict (week_key, screen) do nothing;
  update analytics_heatmap_weekly
  set buckets = (
    select jsonb_object_agg(
      key,
      coalesce((buckets->key)::int, 0) + coalesce((p_buckets->key)::int, 0)
    )
    from jsonb_object_keys(buckets || p_buckets) as key
  )
  where week_key = p_week_key and screen = p_screen;
end;
$$;

grant execute on function increment_access_hour_daily(text, int) to anon, authenticated;
grant execute on function increment_screen_time_daily(text, text, double precision) to anon, authenticated;
grant execute on function increment_heatmap_weekly(text, text, jsonb) to anon, authenticated;

-- ============================================================
-- 2f. RPC ghi player qua server — thay cho upsert/update trực tiếp từ
-- client vào bảng "players"/"rooms" (mục 3 xoá hẳn 2 policy đó bên dưới).
-- ============================================================
-- Lý do đổi: trước đây client tự tính avg_score/best_score/session_count ở
-- JS rồi upsert thẳng, và policy UPDATE dùng using(true) không giới hạn
-- theo id — nghĩa là AI CŨNG sửa được điểm của BẤT KỲ người chơi nào khác
-- (không chỉ chính mình) chỉ bằng cách gọi thẳng REST API với publishable
-- key có sẵn trong HTML, không cần chơi game. Không có Supabase Auth ở đây
-- (playerId là UUID client tự sinh, không phải danh tính có thể xác thực),
-- nên RLS kiểu auth.uid() = id không dùng được — giải pháp thực tế là
-- chuyển toàn bộ ghi vào "players"/"rooms" qua RPC security definer, để:
-- (a) client không còn gọi UPDATE/INSERT trực tiếp được nữa (xem mục 3),
-- (b) điểm số được SERVER cộng dồn từ delta 1 ván (score/play_time), không
-- nhận thẳng avg_score/total_correct_time đã tính sẵn từ client,
-- (c) CHECK constraint ở mục 1 + validate trong RPC chặn giá trị vượt biên
-- hợp lý của game (score/play_time trong [0,65]s, score <= play_time —
-- xem giải thích chi tiết ở constraint players_avg_score_range).
-- Vẫn còn hạn chế: không phân biệt được "chủ playerId X thật" với "ai đó
-- giả mạo gửi playerId X" (không có auth) — RPC chỉ chặn được sửa điểm
-- SAI LỆCH XA giới hạn game hoặc sửa THẲNG người khác qua REST, không chặn
-- được 100% việc gọi RPC lặp lại để "cày" điểm hợp lệ nhanh hơn chơi thật.
-- Việc đó cần rate-limit hoặc xác thực server-side đầy đủ (giai đoạn sau).

-- Lớp phòng thủ thứ 2 cho tên người chơi (lớp 1 là escapeHtml() ở client):
-- bỏ control character (C0/C1), zero-width và ký tự đảo chiều bidi (dùng để
-- giả mạo/ẩn tên trên leaderboard), rồi cắt khoảng trắng đầu/cuối.
create or replace function sanitize_player_name(p_name text)
returns text
language sql
immutable
as $$
  select btrim(regexp_replace(coalesce(p_name, ''),
    '[\u0001-\u001f\u007f-\u009f\u200b-\u200f\u202a-\u202e\u2060-\u2069\ufeff]', '', 'g'));
$$;

-- Khởi tạo player lần đầu / chỉ đổi tên — KHÔNG cộng điểm (khác với
-- submit_match_result). Tách riêng để không nhầm "vào game lần đầu" với
-- "vừa chơi xong 1 ván 0 điểm" (2 việc khác nhau: cái trước không tăng
-- session_count, cái sau có).
create or replace function ensure_player(p_player_id text, p_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  p_name := sanitize_player_name(p_name);
  if char_length(p_name) > 40 then
    raise exception 'name too long';
  end if;

  insert into players (id, name, last_visit)
  values (p_player_id, coalesce(nullif(p_name, ''), 'Người chơi ẩn danh'), now())
  on conflict (id) do update set
    name = excluded.name,
    last_visit = excluded.last_visit;
end;
$$;

grant execute on function ensure_player(text, text) to anon, authenticated;

-- Ghi kết quả 1 ván chơi thật — nhận DELTA (score/play_time của riêng ván
-- này), server tự cộng dồn total_correct_time/session_count và tự tính lại
-- avg_score bên trong transaction (for update khoá row, cùng lý do chống
-- race condition như các RPC increment_* ở trên). Trả về giá trị đã tính ở
-- server để client cập nhật UI, thay vì tin giá trị client tự tính.
create or replace function submit_match_result(
  p_player_id text,
  p_name text,
  p_score double precision,      -- correctTime của ván vừa xong
  p_play_time double precision,  -- elapsedTime của ván vừa xong
  p_current_streak int,
  p_longest_streak int
)
returns table(avg_score double precision, session_count int, best_score double precision)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prev players%rowtype;
  v_session_count int;
  v_total_correct double precision;
  v_best double precision;
  v_total_play double precision;
  v_avg double precision;
begin
  -- score = "correctTime": tổng thời gian chơi đúng suốt trận (không phải
  -- targetPersonalTime=30s riêng của luật thắng) — biên khớp
  -- CONFIG.matchDuration=60s trong game/TAB-Ne-Sep.html + 5s buffer.
  if p_score < 0 or p_score > 65 then
    raise exception 'invalid score: %', p_score;
  end if;
  if p_play_time < 0 or p_play_time > 65 then
    raise exception 'invalid play_time: %', p_play_time;
  end if;
  if p_score > p_play_time then
    raise exception 'score cannot exceed play_time: score=%, play_time=%', p_score, p_play_time;
  end if;
  p_name := sanitize_player_name(p_name);
  if char_length(p_name) > 40 then
    raise exception 'name too long';
  end if;

  select * into v_prev from players where id = p_player_id for update;

  if not found then
    v_session_count := 1;
    v_total_correct := p_score;
    v_total_play := p_play_time;
    v_best := p_score;
  else
    v_session_count := v_prev.session_count + 1;
    v_total_correct := v_prev.total_correct_time + p_score;
    v_total_play := v_prev.total_play_time + p_play_time;
    v_best := greatest(v_prev.best_score, p_score);
  end if;
  v_avg := v_total_correct / v_session_count;

  insert into players (id, name, session_count, total_correct_time, avg_score, best_score, total_play_time, current_streak, longest_streak, last_visit)
  values (p_player_id, coalesce(nullif(p_name, ''), 'Người chơi ẩn danh'), v_session_count, v_total_correct, v_avg, v_best, v_total_play, p_current_streak, p_longest_streak, now())
  on conflict (id) do update set
    name = excluded.name,
    session_count = excluded.session_count,
    total_correct_time = excluded.total_correct_time,
    avg_score = excluded.avg_score,
    best_score = excluded.best_score,
    total_play_time = excluded.total_play_time,
    current_streak = excluded.current_streak,
    longest_streak = excluded.longest_streak,
    last_visit = excluded.last_visit;

  return query select v_avg, v_session_count, v_best;
end;
$$;

grant execute on function submit_match_result(text, text, double precision, double precision, int, int) to anon, authenticated;

-- Chuyển phòng waiting -> playing — CHỈ cho phép nếu người gọi đúng là
-- host_player_id của phòng đó, thay cho update using(true) cũ (ai cũng đổi
-- được status/host của phòng người khác).
create or replace function start_room_match(p_room_id text, p_requester_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update rooms set status = 'playing'
  where id = p_room_id and host_player_id = p_requester_id and status = 'waiting';

  if not found then
    raise exception 'not authorized or invalid room state';
  end if;
end;
$$;

grant execute on function start_room_match(text, text) to anon, authenticated;

-- Chuyển quyền host khi host cũ rời phòng (host-migration phía client: các
-- thành viên còn lại tự đồng thuận người có playerId nhỏ nhất). CHỈ đổi được
-- nếu người gọi biết đúng host_player_id hiện tại của phòng — không có
-- Supabase Auth nên đây là mức kiểm tra tối đa khả thi; tradeoff đã biết: ai
-- biết cả mã phòng lẫn playerId của host cũ đều có thể gọi hàm này.
create or replace function claim_room_host(p_room_id text, p_new_host_id text, p_old_host_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update rooms set host_player_id = p_new_host_id
  where id = p_room_id and host_player_id = p_old_host_id
    and exists (select 1 from players where id = p_new_host_id);

  if not found then
    raise exception 'not authorized or invalid room state';
  end if;
end;
$$;

grant execute on function claim_room_host(text, text, text) to anon, authenticated;

alter table analytics_access_hours_daily enable row level security;
alter table analytics_screen_time_daily enable row level security;
alter table analytics_heatmap_weekly enable row level security;

drop policy if exists "access_hours_daily: đọc" on analytics_access_hours_daily;
create policy "access_hours_daily: đọc" on analytics_access_hours_daily for select using (true);

drop policy if exists "screen_time_daily: đọc" on analytics_screen_time_daily;
create policy "screen_time_daily: đọc" on analytics_screen_time_daily for select using (true);

drop policy if exists "heatmap_weekly: đọc" on analytics_heatmap_weekly;
create policy "heatmap_weekly: đọc" on analytics_heatmap_weekly for select using (true);

-- ============================================================
-- 3. Row Level Security — cho phép mọi người đọc, ghi player qua RPC only
-- ============================================================
-- Game chạy hoàn toàn phía client (không có backend riêng, không có
-- Supabase Auth — playerId chỉ là UUID tự sinh ở client, không phải danh
-- tính xác thực được), nên viewer cần đọc tự do bằng publishable key. Đây
-- là đánh đổi chấp nhận được cho 1 mini-game công khai, không có dữ liệu
-- nhạy cảm — giống hệt mô hình "mọi người dùng chung 1 kho db" mà bản
-- Claude Artifact cũ đã dùng.
--
-- KHÔNG còn policy INSERT/UPDATE trực tiếp cho "players" (khác các bảng
-- analytics_*/sessions/rooms bên trên — bảng này giữ điểm số/leaderboard,
-- rủi ro cao nhất nếu bị ghi tuỳ tiện). Trước đây "update using(true)"
-- cho phép SỬA ĐIỂM CỦA BẤT KỲ NGƯỜI CHƠI NÀO KHÁC qua REST API trực tiếp
-- (PATCH .../players?id=eq.<id_bất_kỳ>), không cần chơi game — đã xác nhận
-- là lỗ hổng thật, không phải lý thuyết. Toàn bộ ghi vào players giờ đi
-- qua RPC security definer (ensure_player/submit_match_result, mục 2f),
-- validate delta điểm ở server thay vì tin giá trị đã tính sẵn từ client.

alter table players enable row level security;
alter table analytics_access_hours enable row level security;
alter table analytics_screen_time enable row level security;
alter table analytics_heatmap enable row level security;

drop policy if exists "players: ai cũng đọc được" on players;
create policy "players: ai cũng đọc được" on players for select using (true);
drop policy if exists "players: ai cũng ghi được (upsert điểm của chính mình)" on players;
drop policy if exists "players: ai cũng update được" on players;

-- Không còn policy UPDATE public cho 3 bảng analytics — client ghi qua RPC
-- security definer (increment_access_hour/increment_screen_time/
-- increment_heatmap ở mục 2d), không update thẳng bảng nữa. Nếu nâng cấp từ
-- Supabase cũ (đã tạo policy "...: ghi" kiểu update using(true) trước đây),
-- xoá luôn để tránh còn đường ghi trực tiếp song song với RPC.
drop policy if exists "access_hours: ghi" on analytics_access_hours;
drop policy if exists "screen_time: ghi" on analytics_screen_time;
drop policy if exists "heatmap: ghi" on analytics_heatmap;

drop policy if exists "access_hours: đọc" on analytics_access_hours;
create policy "access_hours: đọc" on analytics_access_hours for select using (true);

drop policy if exists "screen_time: đọc" on analytics_screen_time;
create policy "screen_time: đọc" on analytics_screen_time for select using (true);

drop policy if exists "heatmap: đọc" on analytics_heatmap;
create policy "heatmap: đọc" on analytics_heatmap for select using (true);

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

-- ============================================================
-- 5. HARDENING (2026-10) — xác thực chủ sở hữu, rate-limit, validate đầu vào
-- ============================================================
-- Bối cảnh: không có Supabase Auth, publishable key nằm công khai trong HTML,
-- và cột players.id hiển thị công khai (leaderboard) → mô hình cũ "playerId là
-- danh tính" cho phép BẤT KỲ AI chỉ cần biết id của người khác là đổi được
-- tên, đẩy điểm, cướp quyền host phòng của họ. Mục này đóng các lỗ hổng đó:
--   5.1 Secret theo từng người chơi: client sinh chuỗi ngẫu nhiên 256-bit lưu
--       trong localStorage, gửi kèm mỗi RPC ghi; server chỉ lưu SHA-256 của nó
--       (bảng player_secrets, không ai đọc được qua API). Người đầu tiên gửi
--       secret cho 1 id sẽ "chiếm" id đó; từ đó chỉ đúng secret mới ghi được.
--       Hạn chế đã biết: các dòng players CŨ (trước khi có secret) chưa có chủ —
--       ai gọi RPC với id đó TRƯỚC khi chủ thật quay lại sẽ chiếm được.
--   5.2 Rate-limit theo IP (header của PostgREST) và theo người chơi.
--   5.3 Validate chặt đầu vào các RPC analytics (trước đây nhận text/jsonb tự
--       do → tạo vô hạn dòng, JSON phình vô hạn, đầu độc số liệu trung bình).
--   5.4 Điểm số bị chặn theo THỜI GIAN THỰC (play_time ≤ thời gian thật đã
--       trôi qua kể từ lần ghi trước/lần vào game) → không "cày" điểm bằng
--       cách gọi RPC dồn dập; streak do server kẹp, không tin client.
--   5.5 Đóng đường ghi trực tiếp: bỏ policy INSERT của sessions/rooms (chuyển
--       sang RPC), thu hồi quyền ghi bảng của anon/authenticated.

alter table players add column if not exists last_submit_at timestamptz;

-- Bảng bí mật: bật RLS và KHÔNG có policy nào → anon/authenticated không đọc
-- hay ghi được; chỉ hàm security definer bên dưới truy cập.
create table if not exists player_secrets (
  player_id text primary key references players(id) on delete cascade,
  secret_hash text not null,
  created_at timestamptz not null default now()
);
alter table player_secrets enable row level security;
revoke all on player_secrets from anon, authenticated;

-- Bộ đếm rate-limit. unlogged: không cần bền, nhanh hơn, mất khi crash cũng không sao.
create unlogged table if not exists rate_limits (
  key text primary key,
  window_start timestamptz not null,
  hits integer not null
);
alter table rate_limits enable row level security;
revoke all on rate_limits from anon, authenticated;

-- ---------- helper nội bộ (KHÔNG cấp quyền cho anon) ----------
create or replace function client_ip()
returns text
language plpgsql
stable
as $$
declare
  h json;
  ip text;
begin
  begin
    h := current_setting('request.headers', true)::json;
  exception when others then
    return null;
  end;
  if h is null then return null; end if;
  ip := coalesce(nullif(h->>'cf-connecting-ip', ''), nullif(split_part(coalesce(h->>'x-forwarded-for', ''), ',', 1), ''));
  return nullif(btrim(ip), '');
end;
$$;

-- Tăng bộ đếm cho khoá p_key; vượt p_max trong cửa sổ p_window thì từ chối.
-- Lưu ý: khi RAISE, cả transaction rollback nên lần bị từ chối không làm tăng
-- bộ đếm — số lần được chấp nhận trong 1 cửa sổ không bao giờ vượt p_max.
create or replace function rate_limit(p_key text, p_max integer, p_window interval)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hits integer;
begin
  if random() < 0.02 then
    delete from rate_limits where window_start < now() - interval '1 day';
  end if;
  insert into rate_limits (key, window_start, hits) values (p_key, now(), 1)
  on conflict (key) do update set
    hits = case when rate_limits.window_start < now() - p_window then 1 else rate_limits.hits + 1 end,
    window_start = case when rate_limits.window_start < now() - p_window then now() else rate_limits.window_start end
  returning hits into v_hits;
  if v_hits > p_max then
    raise exception 'rate limit exceeded' using errcode = 'P0001';
  end if;
end;
$$;

-- Rate-limit theo IP — bỏ qua nếu không đọc được IP (tránh nhốt chung mọi người
-- vào 1 bộ đếm 'unknown').
create or replace function rate_limit_ip(p_fn text, p_max integer, p_window interval)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ip text := client_ip();
begin
  if v_ip is not null then
    perform rate_limit('ip:' || v_ip || ':' || p_fn, p_max, p_window);
  end if;
end;
$$;

-- Xác thực chủ sở hữu playerId bằng secret (xem 5.1). Dòng players PHẢI đã
-- tồn tại (khoá ngoại) — các RPC gọi hàm này sau khi đã đảm bảo có dòng.
create or replace function player_auth(p_id text, p_secret text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hash text;
  v_stored text;
begin
  if p_id is null or p_id !~ '^[A-Za-z0-9_-]{6,64}$' or p_id like 'seed\_%' then
    raise exception 'invalid player id' using errcode = '22023';
  end if;
  if p_secret is null or p_secret !~ '^[A-Za-z0-9]{32,128}$' then
    raise exception 'invalid secret' using errcode = '22023';
  end if;
  if exists (select 1 from players where id = p_id and is_seed) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  v_hash := encode(sha256(convert_to(p_secret, 'UTF8')), 'hex');
  insert into player_secrets (player_id, secret_hash) values (p_id, v_hash)
  on conflict (player_id) do nothing;
  select secret_hash into v_stored from player_secrets where player_id = p_id;
  if v_stored is distinct from v_hash then
    raise exception 'forbidden' using errcode = '42501';
  end if;
end;
$$;

-- Tên người chơi: ngoài control/zero-width/bidi, bỏ luôn < > — lớp phòng thủ
-- sâu thứ 3 chống HTML injection ngay từ nguồn (lớp 1 là escapeHtml() ở client).
create or replace function sanitize_player_name(p_name text)
returns text
language sql
immutable
as $$
  select btrim(regexp_replace(coalesce(p_name, ''),
    '[\u0001-\u001f\u007f-\u009f​-‏‪-‮⁠-⁩﻿<>]', '', 'g'));
$$;

-- Kiểm tra JSON heatmap: lưới 10x10 nên khoá chỉ dạng "c_r" với c,r ∈ 0..9,
-- tối đa 100 khoá, mỗi giá trị là số nguyên không âm ≤ 6 chữ số.
create or replace function validate_heatmap_buckets(p_buckets jsonb)
returns void
language plpgsql
immutable
as $$
declare
  r record;
begin
  if p_buckets is null or jsonb_typeof(p_buckets) <> 'object' then
    raise exception 'invalid buckets' using errcode = '22023';
  end if;
  if (select count(*) from jsonb_object_keys(p_buckets)) > 100 then
    raise exception 'too many buckets' using errcode = '22023';
  end if;
  for r in select key, value from jsonb_each(p_buckets) loop
    if r.key !~ '^[0-9]_[0-9]$' or jsonb_typeof(r.value) <> 'number' or r.value::text !~ '^[0-9]{1,6}$' then
      raise exception 'invalid bucket entry' using errcode = '22023';
    end if;
  end loop;
end;
$$;

-- Khoá ngày/tuần phải đúng định dạng VÀ nằm sát thời điểm hiện tại (giờ VN) —
-- không cho tạo dòng cho ngày/tuần tuỳ ý.
create or replace function validate_date_key(p_key text)
returns void
language plpgsql
stable
as $$
declare
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  if p_key is null or p_key !~ '^\d{4}-\d{2}-\d{2}$' then
    raise exception 'invalid date_key' using errcode = '22023';
  end if;
  begin
    if abs(p_key::date - v_today) > 1 then
      raise exception 'date_key out of range' using errcode = '22023';
    end if;
  exception when datetime_field_overflow or invalid_datetime_format then
    raise exception 'invalid date_key' using errcode = '22023';
  end;
end;
$$;

create or replace function validate_week_key(p_key text)
returns void
language plpgsql
stable
as $$
declare
  v_year integer := extract(year from (now() at time zone 'Asia/Ho_Chi_Minh'))::integer;
begin
  if p_key is null or p_key !~ '^\d{4}-W\d{2}$' then
    raise exception 'invalid week_key' using errcode = '22023';
  end if;
  if abs(substr(p_key, 1, 4)::integer - v_year) > 1 or substr(p_key, 7, 2)::integer not between 1 and 53 then
    raise exception 'week_key out of range' using errcode = '22023';
  end if;
end;
$$;

create or replace function validate_duration_ms(p_ms double precision)
returns void
language plpgsql
immutable
as $$
begin
  if p_ms is null or p_ms = 'NaN'::double precision or p_ms < 0 or p_ms > 3600000 then
    raise exception 'invalid duration' using errcode = '22023';
  end if;
end;
$$;

-- ---------- 5.3 RPC analytics: cùng chữ ký cũ, thêm validate + rate-limit ----------
create or replace function increment_access_hour(p_hour int)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  col text := 'h' || p_hour::text;
begin
  perform rate_limit_ip('analytics', 600, interval '1 minute');
  if p_hour is null or p_hour < 0 or p_hour > 23 then
    raise exception 'invalid hour: %', p_hour;
  end if;
  execute format('update analytics_access_hours set %I = %I + 1, total = total + 1 where id = 1', col, col);
end;
$$;

create or replace function increment_screen_time(p_phase text, p_duration_ms double precision)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  sum_col text := p_phase || '_sum';
  count_col text := p_phase || '_count';
begin
  perform rate_limit_ip('analytics', 600, interval '1 minute');
  if p_phase is null or p_phase not in ('intro', 'game', 'result') then
    raise exception 'invalid phase: %', p_phase;
  end if;
  perform validate_duration_ms(p_duration_ms);
  execute format(
    'update analytics_screen_time set %I = %I + $1, %I = %I + 1 where id = 1',
    sum_col, sum_col, count_col, count_col
  ) using p_duration_ms;
end;
$$;

create or replace function increment_heatmap(p_screen text, p_buckets jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform rate_limit_ip('analytics', 600, interval '1 minute');
  if p_screen is null or p_screen not in ('intro', 'game') then
    raise exception 'invalid screen: %', p_screen;
  end if;
  perform validate_heatmap_buckets(p_buckets);
  update analytics_heatmap
  set buckets = (
    select jsonb_object_agg(
      key,
      coalesce((buckets->key)::int, 0) + coalesce((p_buckets->key)::int, 0)
    )
    from jsonb_object_keys(buckets || p_buckets) as key
  )
  where screen = p_screen;
end;
$$;

create or replace function increment_access_hour_daily(p_date_key text, p_hour int)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  col text := 'h' || p_hour::text;
begin
  perform rate_limit_ip('analytics', 600, interval '1 minute');
  perform validate_date_key(p_date_key);
  if p_hour is null or p_hour < 0 or p_hour > 23 then
    raise exception 'invalid hour: %', p_hour;
  end if;
  insert into analytics_access_hours_daily (date_key) values (p_date_key)
  on conflict (date_key) do nothing;
  execute format(
    'update analytics_access_hours_daily set %I = %I + 1, total = total + 1 where date_key = $1',
    col, col
  ) using p_date_key;
end;
$$;

create or replace function increment_screen_time_daily(p_date_key text, p_phase text, p_duration_ms double precision)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  sum_col text := p_phase || '_sum';
  count_col text := p_phase || '_count';
begin
  perform rate_limit_ip('analytics', 600, interval '1 minute');
  perform validate_date_key(p_date_key);
  if p_phase is null or p_phase not in ('intro', 'game', 'result') then
    raise exception 'invalid phase: %', p_phase;
  end if;
  perform validate_duration_ms(p_duration_ms);
  insert into analytics_screen_time_daily (date_key) values (p_date_key)
  on conflict (date_key) do nothing;
  execute format(
    'update analytics_screen_time_daily set %I = %I + $1, %I = %I + 1 where date_key = $2',
    sum_col, sum_col, count_col, count_col
  ) using p_duration_ms, p_date_key;
end;
$$;

create or replace function increment_heatmap_weekly(p_week_key text, p_screen text, p_buckets jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform rate_limit_ip('analytics', 600, interval '1 minute');
  perform validate_week_key(p_week_key);
  if p_screen is null or p_screen not in ('intro', 'game') then
    raise exception 'invalid screen: %', p_screen;
  end if;
  perform validate_heatmap_buckets(p_buckets);
  insert into analytics_heatmap_weekly (week_key, screen) values (p_week_key, p_screen)
  on conflict (week_key, screen) do nothing;
  update analytics_heatmap_weekly
  set buckets = (
    select jsonb_object_agg(
      key,
      coalesce((buckets->key)::int, 0) + coalesce((p_buckets->key)::int, 0)
    )
    from jsonb_object_keys(buckets || p_buckets) as key
  )
  where week_key = p_week_key and screen = p_screen;
end;
$$;

-- ---------- 5.1/5.2/5.4 RPC ghi người chơi — thêm p_secret ----------
-- Chữ ký CŨ (không có p_secret) bị xoá ở cuối mục này để đóng hẳn đường cũ.
create or replace function ensure_player(p_player_id text, p_name text, p_secret text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform rate_limit_ip('ensure_player', 120, interval '1 minute');
  p_name := sanitize_player_name(p_name);
  if char_length(p_name) > 40 then
    raise exception 'name too long';
  end if;
  if not exists (select 1 from players where id = p_player_id) then
    perform rate_limit_ip('new_player', 40, interval '1 hour'); -- chặn spam tạo hàng loạt người chơi
    insert into players (id, name) values (p_player_id, coalesce(nullif(p_name, ''), 'Người chơi ẩn danh'))
    on conflict (id) do nothing;
  end if;
  perform player_auth(p_player_id, p_secret); -- sai secret → rollback cả lệnh insert ở trên
  perform rate_limit('pl:' || p_player_id || ':ensure', 30, interval '1 minute');
  update players
  set name = coalesce(nullif(p_name, ''), 'Người chơi ẩn danh'), last_visit = now()
  where id = p_player_id;
end;
$$;

create or replace function submit_match_result(
  p_player_id text,
  p_name text,
  p_secret text,
  p_score double precision,
  p_play_time double precision,
  p_current_streak int,
  p_longest_streak int,
  p_variant text default null
)
returns table(avg_score double precision, session_count int, best_score double precision)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prev players%rowtype;
  v_existed boolean;
  v_session_count int;
  v_total_correct double precision;
  v_best double precision;
  v_total_play double precision;
  v_avg double precision;
  v_cur int;
  v_long int;
  v_base timestamptz;
  v_elapsed double precision;
begin
  perform rate_limit_ip('submit', 90, interval '1 minute');
  if p_score is null or p_play_time is null or p_score = 'NaN'::double precision or p_play_time = 'NaN'::double precision
     or p_score < 0 or p_score > 65 or p_play_time < 0 or p_play_time > 65 then
    raise exception 'invalid score/play_time';
  end if;
  if p_score > p_play_time then
    raise exception 'score cannot exceed play_time: score=%, play_time=%', p_score, p_play_time;
  end if;
  p_name := sanitize_player_name(p_name);
  if char_length(p_name) > 40 then
    raise exception 'name too long';
  end if;

  select exists (select 1 from players where id = p_player_id) into v_existed;
  if not v_existed then
    perform rate_limit_ip('new_player', 40, interval '1 hour');
    insert into players (id, name) values (p_player_id, coalesce(nullif(p_name, ''), 'Người chơi ẩn danh'))
    on conflict (id) do nothing;
  end if;
  perform player_auth(p_player_id, p_secret);
  perform rate_limit('pl:' || p_player_id || ':submit', 12, interval '1 minute');

  select * into v_prev from players where id = p_player_id for update;

  -- 5.4: play_time không được vượt thời gian thật đã trôi qua kể từ lần ghi
  -- kết quả trước (hoặc lần vào game gần nhất, nếu mới hơn) + 5s dung sai.
  -- Chơi thật không bao giờ vượt thời gian thật (dt mỗi frame bị chặn ≤ 0.05s),
  -- còn gọi RPC dồn dập để cày điểm thì bị chặn ở đây.
  if v_existed then
    v_base := greatest(coalesce(v_prev.last_submit_at, '-infinity'::timestamptz), v_prev.last_visit);
    v_elapsed := extract(epoch from (now() - v_base));
    if p_play_time > v_elapsed + 5 then
      raise exception 'play_time exceeds elapsed real time' using errcode = 'P0001';
    end if;
  end if;

  v_session_count := v_prev.session_count + 1;
  v_total_correct := v_prev.total_correct_time + p_score;
  v_total_play := v_prev.total_play_time + p_play_time;
  v_best := greatest(v_prev.best_score, p_score);
  v_avg := v_total_correct / v_session_count;

  -- Streak: client chỉ ĐỀ XUẤT; server kẹp để không nhảy vọt (tối đa +1 mỗi
  -- ván) và tự suy ra kỷ lục.
  v_cur := least(greatest(coalesce(p_current_streak, 0), 0), coalesce(v_prev.current_streak, 0) + 1, 3650);
  v_long := greatest(coalesce(v_prev.longest_streak, 0), v_cur);

  update players set
    name = coalesce(nullif(p_name, ''), v_prev.name),
    session_count = v_session_count,
    total_correct_time = v_total_correct,
    avg_score = v_avg,
    best_score = v_best,
    total_play_time = v_total_play,
    current_streak = v_cur,
    longest_streak = v_long,
    last_visit = now(),
    last_submit_at = now()
  where id = p_player_id;

  if p_variant in ('ellipse', 'radar', 'perspective') then
    insert into sessions (player_id, variant, score, play_time)
    values (p_player_id, p_variant, p_score, p_play_time);
  end if;

  return query select v_avg, v_session_count, v_best;
end;
$$;

-- ---------- Phòng chơi nhóm ----------
create or replace function create_room(p_room_id text, p_player_id text, p_secret text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform rate_limit_ip('create_room', 30, interval '10 minutes');
  if p_room_id is null or p_room_id !~ '^[A-HJ-NP-Z2-9]{6,8}$' then
    raise exception 'invalid room id' using errcode = '22023';
  end if;
  perform player_auth(p_player_id, p_secret);
  perform rate_limit('pl:' || p_player_id || ':room', 5, interval '10 minutes');
  delete from rooms where created_at < now() - interval '1 day';
  insert into rooms (id, host_player_id, status) values (p_room_id, p_player_id, 'waiting');
end;
$$;

create or replace function start_room_match(p_room_id text, p_requester_id text, p_secret text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform player_auth(p_requester_id, p_secret);
  update rooms set status = 'playing'
  where id = p_room_id and host_player_id = p_requester_id and status = 'waiting';
  if not found then
    raise exception 'not authorized or invalid room state';
  end if;
end;
$$;

create or replace function claim_room_host(p_room_id text, p_new_host_id text, p_old_host_id text, p_secret text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform player_auth(p_new_host_id, p_secret);
  update rooms set host_player_id = p_new_host_id
  where id = p_room_id and host_player_id = p_old_host_id;
  if not found then
    raise exception 'not authorized or invalid room state';
  end if;
end;
$$;

-- ---------- 5.5 Đóng đường cũ ----------
drop function if exists ensure_player(text, text);
drop function if exists submit_match_result(text, text, double precision, double precision, int, int);
drop function if exists start_room_match(text, text);
drop function if exists claim_room_host(text, text, text);

drop policy if exists "sessions: ai cũng ghi được" on sessions;
drop policy if exists "sessions: ai cũng đọc được" on sessions; -- client không đọc sessions; không lộ lịch sử từng ván của từng người
drop policy if exists "rooms: ai cũng tạo được" on rooms;

-- Thu hồi quyền ghi trực tiếp mọi bảng public của anon/authenticated (RLS đã
-- chặn, đây là lớp thứ 2). Chỉ còn đọc theo policy + gọi RPC security definer.
revoke insert, update, delete, truncate on all tables in schema public from anon, authenticated;

-- Quyền EXECUTE: mặc định Postgres cấp cho PUBLIC mọi hàm mới. Thu hồi hết,
-- rồi chỉ cấp lại cho các RPC mà client thật sự gọi; helper nội bộ không cấp.
revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function ensure_player(text, text, text) to anon, authenticated;
grant execute on function submit_match_result(text, text, text, double precision, double precision, int, int, text) to anon, authenticated;
grant execute on function create_room(text, text, text) to anon, authenticated;
grant execute on function start_room_match(text, text, text) to anon, authenticated;
grant execute on function claim_room_host(text, text, text, text) to anon, authenticated;
grant execute on function increment_access_hour(int) to anon, authenticated;
grant execute on function increment_screen_time(text, double precision) to anon, authenticated;
grant execute on function increment_heatmap(text, jsonb) to anon, authenticated;
grant execute on function increment_access_hour_daily(text, int) to anon, authenticated;
grant execute on function increment_screen_time_daily(text, text, double precision) to anon, authenticated;
grant execute on function increment_heatmap_weekly(text, text, jsonb) to anon, authenticated;
