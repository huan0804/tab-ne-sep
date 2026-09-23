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
  if char_length(coalesce(p_name, '')) > 40 then
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
  if char_length(coalesce(p_name, '')) > 40 then
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
