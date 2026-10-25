# Nhật ký làm việc — TAB: Né Sếp

> File này ghi lại trạng thái dự án để tiếp tục ở phiên làm việc sau. Cập nhật mỗi khi có tiến triển lớn, dọn bớt phần đã lỗi thời để tránh phình to.

## Tổng kết phiên 2026-10-08 — 20 commit (`3451efa` → `f2dff55`), TOÀN BỘ đã push, production = `master`

### Trạng thái cuối phiên
- `/play` (alias `/play-3d`) = `game/TAB-Ne-Sep_v2-perspective.html` — **bản chính duy nhất nhận tính năng mới**. `/play-2d` = `TAB-Ne-Sep.html` (bản elip cũ, chỉ nhận bản vá bảo mật + sửa lỗi tutorial/tick, KHÔNG có phòng-xin-chơi-lại/hướng dẫn/xoay ngang/dead reckoning). `v1-radar` không còn được deploy (`.vercelignore`).
- **`supabase/schema.sql` mục 5 (hardening) ĐÃ chạy trên production** (người dùng xác nhận "Success"); curl xác nhận: ghi trực tiếp bị từ chối, RPC cũ biến mất, `schema.sql`/WORK_LOG/CLAUDE.md/docs trả 404, header bảo mật đủ.
- **Đã xác nhận trên production:** ghi điểm solo qua secret; bảng xếp hạng; tải/hiện ảnh Sếp; nút Về trang chủ; nút Hướng dẫn; xoay giao diện CSS trên máy thật (ảnh người dùng gửi).
- **CHƯA xác nhận trên máy/mạng thật:** tạo phòng + chơi lại + chuyển host bằng RPC có secret trên production (chỉ test bằng Supabase giả + PGlite); snapshot/dead reckoning trên mạng thật; tutorial làm tối + nhãn Sếp + phòng 5 người trên điện thoại; `orientation.lock` trên Android Chrome thật.

### Đã làm (theo chủ đề)
1. **Bản chính = v2-perspective**: route `/play` → v2; tài liệu cập nhật.
2. **Thuật toán Sếp ít lại gần** (`b17ca9b`): ~40% lần áp sát không thành "lần vào 1m" vì `wasClose` chỉ nạp lại khi ra >1.8m, ~7% đích áp sát nằm ngoài 1m do trục y nhân `ellipseRatio`. Fix: nạp lại khi bắt đầu áp sát mới (`prevBossForced`) + chia đích cho `hypot(cos, sin·ellipseRatio)` → lần vào 1m/ván 12.9 → 17.8 (mô phỏng).
3. **Tính năng người chơi**: ảnh Sếp tự chọn (localStorage, JPEG 192px, không upload); nút ❓ Hướng dẫn trên HUD (đóng băng ván solo, "Chơi lại hướng dẫn từng bước"); Về trang chủ ở popup kết quả; tutorial **làm tối** phần không cần thiết (`#tutorialDim`, `setTutorialFocus`: bước 1 sáng màn hình + Tab, bước 2 thêm Sếp + vòng; tắt khi Tab lần 2/bị bắt/hết ván/14s).
4. **Phòng nhóm**: "Xin chơi lại" gửi tới host (không rời phòng), host chỉ bấm "Chơi lại cả phòng" khi mọi người xong; **chuyển host** khi host rời (người có `playerId` nhỏ nhất, mọi máy tự tính cùng kết quả; RPC `claim_room_host` best-effort, thiếu RPC vẫn chạy bằng broadcast `match_start`); nhãn "👀 Đang kiểm tra <tên>" / "🎯 Đang nhắm BẠN!" (giữ nguyên số mét/viền đỏ cho cả phòng — Sếp <1m mà không bắt người không bị nhắm là THIẾT KẾ); chọn mục tiêu bằng **shuffle-bag** (cũ chênh 6/7/9, mới 7/7/7); nút "Chơi lại cả phòng" màu đỏ.
5. **Tải Realtime** (gói free Supabase = **100 tin/giây CẢ project, tính cả gửi lẫn nhận**): host từng phát vị trí Sếp 15Hz → phòng 5 người ~66 tin/giây. Qua 2 bước: (a) snapshot interpolation phía guest (trễ cố định 100ms, độ lệch đồng hồ min()+làm mượt); (b) **dead reckoning**: host chỉ gửi khi đích/tốc độ/mục tiêu đổi + heartbeat 1s (`CONFIG.bossHeartbeatMs`), guest tự tính ở giữa + hiệu chỉnh tắt dần ~150ms → **66 → 6,7 tin/giây**, độ giật P95 ~1,05 → ~0,43px (mạng giả lập giật, 7 cặp xen kẽ). Host cũ (stream 15Hz) vẫn được guest mới hỗ trợ.
6. **Bảo mật** (schema.sql mục 5 + client + vercel.json):
   - XSS giữa người chơi qua broadcast `player_state` (workData nối thẳng innerHTML) — dựng exploit thật: bản cũ chạy mã (8 lần/nạn nhân), bản vá 0. Mọi payload mạng qua `sanitize*`/`isSafeId`/`remote*`.
   - Xác thực chủ `playerId` bằng secret 256-bit (`player_secrets`, lưu SHA-256; mọi RPC ghi nhận `p_secret`; CÓ THỂ DÙNG LẠI mẫu `player_auth()` cho RPC mới).
   - Bỏ INSERT trực tiếp `sessions`/`rooms` (RPC `create_room`; `submit_match_result` tự ghi sessions), thu hồi quyền ghi của anon, rate-limit IP + người chơi, điểm bị chặn theo thời gian thật, streak kẹp ở server, validate RPC analytics.
   - `vercel.json` CSP/X-Frame-Options/nosniff/Referrer/Permissions/COOP; `.vercelignore`; supabase-js ghim 2.117.3 + SRI; `window.open` noopener.
7. **Điện thoại**: bấm Bắt đầu/Tạo phòng → toàn màn hình + `screen.orientation.lock('landscape')` (`requestLandscape()`); không khoá được → `#rotatePrompt` (đóng băng ván solo, không áp dụng trong phòng) với nút **"↻ Xoay giao diện sang ngang"** (cũng ở ❓ Hướng dẫn) = `html.fl` xoay #stage 90° bằng CSS, luật landscape SINH LẠI dưới tiền tố `html.fl` + reset luật màn hẹp; nghiêng máy sang TRÁI; tự bỏ khi máy xoay ngang thật; nhớ trong sessionStorage `atd_fl`; `#rotateDiag` in lý do khoá thất bại. Bố cục điện thoại nằm ngang (`@media (orientation:landscape) and (max-height:520px)`): HUD 1 hàng, nút Tab nổi góc dưới phải, cảnh cao 350px (trước ~265px).
8. **Lỗi có sẵn tìm thấy & sửa**: `tick()` nhân đôi mỗi lần "Chơi lại" (1→2→3→4 vòng/khung hình; nay `queueTick()`, cả 2 bản); coachmark tutorial bước 1 bị bước 2 ghi đè ngay + banner "SẾP ĐANG LẠI GẦN" hiện sớm (cả 2 bản); guest không tự vào ván mới khi host "Chơi lại cả phòng" (`state.gameStarted` vẫn true sau `endGame`); Sếp bị phóng 5,6 lần che màn hình khi lang thang phía camera (chặn depth ở mép vòng 3m, tối đa ~3 lần).

### Quyết định & bài học cần nhớ
- **KHÔNG làm PWA** để ép ngang (người dùng chọn giữ nguyên cách khoá-hướng + nút xoay CSS). Lý do web không tự xoay "mặc định" như game app: app khai báo hướng với OS, web chỉ xin được sau thao tác người dùng và trình duyệt trong app (Zalo/Facebook) / iOS thường từ chối. Máy người dùng: vào được toàn màn hình nhưng lock thất bại, xoay máy không đổi viewport.
- Cách CSS-rotate từng bị bỏ (bàn phím ảo không xoay theo, đo kích thước sai) nay quay lại có chọn lọc, chỉ khi người chơi tự bấm; rủi ro còn: bàn phím ảo (chỉ ô nhập tên ở màn bắt đầu), toạ độ heatmap analytics lệch.
- 8 repo người dùng gửi (Open-Party-Lab, OpenParty, awesome-team-building, MultiplayerNetworkingResources, lightspeed, Vercidium/lag-compensation, ue5-server-side-rewind, player_lagcompensation.cpp): **không dùng thư viện nào**. Lag compensation/server-rewind là cho game bắn súng (cần server mô phỏng) — game này mỗi client tự chấm "bị bắt" theo đúng vị trí Sếp mình thấy nên không cần. Chỉ lấy ý "lịch sử có timestamp + nội suy".
- Test kiểu "Supabase giả (hub trong Node, định tuyến realtime giữa nhiều Chrome headless) + PGlite (Postgres thật bằng WASM)" bắt được nhiều lỗi mà test đơn lẻ không thấy, và tránh làm bẩn leaderboard production. **Bộ test này nằm ở thư mục tạm của phiên, KHÔNG có trong repo** — dựng lại nếu cần (hub: mô phỏng channel/presence/broadcast/postgres_changes + RPC rooms; đo giật bằng cách parse `translate3d` của #bossUnit mỗi khung hình).
- Đo trước, kết luận sau: phép đo giật rất nhiễu (đường đi Sếp ngẫu nhiên, 2–5 Chrome chung 1 máy) → chạy xen kẽ cũ/mới nhiều cặp và tách "rơi khung hình" khỏi "Sếp nhảy thật".

### Việc còn mở
- **Test tay trên điện thoại/nhiều máy thật** (ưu tiên): tạo phòng + chơi lại + chuyển host trên production; Sếp mượt ở guest; tutorial làm tối; nhãn Sếp; phòng 5 người; `orientation.lock` trên Android Chrome (mở trực tiếp) và nhắc xoay trong Zalo/Facebook; popup/HUD ở chế độ `html.fl`.
- Rủi ro bảo mật còn lại: (1) dòng `players` CŨ chưa có chủ — ai gọi RPC với id đó trước chủ thật sẽ chiếm (người bị chiếm gặp "forbidden", xoá localStorage để tạo id mới); (2) kênh Realtime không xác thực → kẻ biết mã phòng giả được tin nhắn host (không chạy được mã, không đụng điểm); (3) điểm vẫn do client tính → cheat "hoàn hảo theo thời gian thật" không chặn được nếu thiếu server mô phỏng; (4) CSP còn `'unsafe-inline'` (game là 1 file inline); (5) `claim_room_host` ai biết mã phòng + id host cũ + có tài khoản hợp lệ đều gọi được.
- Trần Realtime gói free vẫn là giới hạn quy mô: ~100 tin/giây cả project (nay ~1,3 tin/giây/người trong phòng → vài chục người phòng chung cùng lúc).
- 2026-10-25: đã gỡ route `/play-2d` khỏi `vercel.json` (file `TAB-Ne-Sep.html` vẫn còn và vẫn truy cập được ở `/game/TAB-Ne-Sep.html`; muốn chặn hẳn thì thêm vào `.vercelignore`). Đã cập nhật README.md và docs/GAME_SPEC.md theo Supabase + bản v2.
- Ad slot `#adSlot` chưa gắn network; Facebook Share Dialog vẫn bỏ qua (cần App ID).

---

## Trạng thái trước đó (2026-09-23, phiên chiều)

**✅ Đã chạy `schema.sql` thành công trên Supabase production** — việc ưu tiên cao nhất từ phiên trước đã xong. Verify: `select proname from pg_proc where proname in ('ensure_player','submit_match_result','start_room_match')` → đúng 3 dòng. Gặp 2 lỗi CHECK constraint chặn giữa chừng khi chạy, cả hai đã xử lý:
- `players_avg_score_range` bị chặn bởi 1 dòng rác thật (id `06d8871f-...`, tên "tunnDavaoDa"): `avg_score≈1 tỷ`, `total_correct_time≈100 tỷ`, `best_score=30` (hợp lệ). Đây là dấu vết khai thác lỗ hổng RLS cũ (mục 1 dưới đây, `ff94716`) — sửa điểm trực tiếp qua REST trước khi RPC tồn tại. Đã reset dòng này về 0 (giữ lại id/tên, không xoá hẳn, để không phá liên kết `sessions.player_id` nếu có).
- `sessions_score_range`/`sessions_play_time_range` (`<=65`) bị chặn bởi 10 dòng **thật, hợp lệ**: `play_time≈120s`, `created_at=2026-09-19` — đúng giai đoạn `CONFIG.matchDuration` còn là 120s trước khi rút xuống 60s cùng ngày. Khác hẳn trường hợp `players` (rác giả mạo) — đây là lịch sử thật, nên **nới biên lên 125** (120s + 5s buffer) thay vì xoá dữ liệu. Đã sửa trong `schema.sql`, đã push (`c22b732`).

**✅ Thêm coachmark bước 2 cho tutorial ép ván đầu** (`59c8cbe`, **CHƯA test tay thật**) — phát hiện qua test tay: coachmark bước 1 (lúc bắt đầu ván) tự ẩn sau 6s, thường trước khi Sếp thực sự lại gần; lúc đó người chơi chỉ còn `#hint` tĩnh ở cuối màn hình, quá xa tầm mắt đang dán vào Sếp/banner đỏ giữa màn hình. Thêm coachmark thứ 2 ngắn gọn ("🚨 Sếp lại gần rồi — bấm TAB ngay!"), hiện đúng 1 lần/ván tại đúng lúc banner "Sếp đang lại gần" bật lên, dùng lại hệ thống `#coachmark` có sẵn (gần đáy scene, trên nút Tab). **CẦN TEST Ở PHIÊN SAU**: xoá `localStorage.atd_tutorialDone`, chơi lại ván đầu, xác nhận coachmark hiện đúng lúc/đúng chỗ, không đè UI khác.

**✅ (2026-09-30, đã commit; phần góc nhìn CHƯA test tay) Góc nhìn riêng mỗi người + sanitize tên RPC**:
- `pickViewAngle()` (gọi đầu `resetState()`): mỗi ván bốc `viewRatio` ∈ [`viewTiltMin`,`viewTiltMax`]=[1.4,2.4] (độ dẹt vòng) và `viewRot` ∈ [0,2π) (hướng xoay Sếp/bàn đồng nghiệp quanh bàn mình). Ván tutorial đầu giữ góc gốc. Chỉ đổi cách VẼ (`worldToScreenPx`); `dist` vẫn = `hypot(bx, by*ellipseRatio)` nên bất biến theo góc nhìn, không cần đồng bộ giữa các máy.
- `generateDeskLayout` chia `y` cho `ellipseRatio` để bàn nằm trên vòng tròn THẬT (mét thật = `y*ellipseRatio`). Ở góc gốc, vị trí bàn trên màn hình y hệt cũ. **Hệ quả cần biết**: Sếp giờ vẽ đúng vòng ứng với số mét (trước đây `py=by*mPxY` nhưng `dist` nhân y thêm 1.4 nên Sếp tiến theo chiều dọc bị tính "1m" khi còn ở ~0.71 vòng 1m trên hình). Gameplay/dist không đổi, chỉ hình Sếp đi dọc xa hơn 1.4×.
- Verify: Playwright headless (ván tutorial vòng 1.4, ván thường ~2.0, không lỗi JS). **Chưa test room nhiều máy** — cần mở 2-3 tab kiểm tra bàn đồng nghiệp không chồng/không tràn màn ở mọi góc, đặc biệt mobile.
- `sanitize_player_name()` trong `schema.sql` (bỏ control char, zero-width, bidi; áp trong `ensure_player` + `submit_match_result`). **✅ Đã chạy schema.sql trên production (2026-09-30), verify `select sanitize_player_name(E'  A<U+200B>B<U+202E>C<U+0007>D  ')` → `ABCD`.**
- Vá thêm (cả `v1-radar`: leaderboard chưa escape tên): tên đồng nghiệp trong `renderTeammates()` (`tmName`) trước đây nối vào `innerHTML` không escape → đã bọc `escapeHtml()`.

**Việc dở, chưa hoàn thành thêm (tương lai)**:
- Rate-limit/xác thực server-side đầy đủ cho các RPC `submit_match_result` (hiện chỉ chặn giá trị vượt biên game, không chặn "cày điểm" bằng gọi RPC lặp lại hợp lệ).

---

**Vừa vá thêm: stored XSS qua tên người chơi.** Phát hiện qua review bảo mật (đối chiếu OWASP Top 10, không dùng lại toàn bộ Playwright).

**Đã push lên GitHub, tất cả trên production tại `https://tab-ne-sep.vercel.app/play`:**

0. **Vá stored XSS qua tên người chơi** — `players.name` (ghi qua RPC `ensure_player`/`submit_match_result`, chỉ giới hạn ≤40 ký tự ở server, không lọc HTML; `<input maxlength="18">` chỉ chặn ở UI, ai gọi thẳng RPC qua REST đều bỏ qua được) từng được nối thẳng vào `innerHTML` không escape ở 5 chỗ: leaderboard (top + "của tôi"), danh sách người chơi trong phòng, banner mời vào phòng, banner thách đấu, kết quả phòng cuối ván. RLS `players: ai cũng đọc được` khiến bất kỳ ai cũng thấy tên này — một người chơi đặt tên chứa `<img src=x onerror=...>` sẽ chạy script trong trình duyệt của MỌI người chơi khác mở leaderboard/phòng chung, không cần họ tương tác gì thêm. Fix: thêm hàm `escapeHtml()` dùng chung (tạo `<div>`, gán `textContent`, đọc lại `innerHTML` — nhờ trình duyệt tự escape, không tự viết regex) và bọc quanh mọi chỗ nối tên vào `innerHTML`. Đã kiểm tra cú pháp JS hợp lệ (`node --check`) và rà lại toàn file để xác nhận không còn chỗ nào sót; 2 chỗ dùng `textContent` (không phải `innerHTML`) vốn đã an toàn nên không cần sửa. **Còn thiếu để hoàn thiện tuyệt đối**: nên sanitize/lọc control-character ở tầng RPC (`ensure_player`/`submit_match_result` trong `schema.sql`) làm lớp phòng thủ thứ hai, phòng trường hợp sau này có thêm nơi khác quên escape khi render tên.
1. **Đóng lỗ hổng RLS sửa điểm/phòng người khác** (`ff94716`) — phát hiện policy `players`/`rooms` UPDATE dùng `using(true)`, cho phép BẤT KỲ AI gọi thẳng REST API (publishable key có sẵn trong HTML) sửa điểm hoặc cướp quyền host phòng của người khác, không cần chơi game. Không có Supabase Auth (playerId là UUID client tự sinh) nên không dùng được RLS kiểu `auth.uid()=id`. Fix: chuyển toàn bộ ghi vào `players`/`rooms` qua RPC `security definer` (`ensure_player`, `submit_match_result` nhận DELTA rồi server tự cộng dồn, `start_room_match` xác thực requester=host), xoá 2 policy UPDATE public, thêm CHECK constraints tầng DB làm lưới an toàn cuối. Hạn chế còn lại: chưa chặn được việc lặp gọi RPC để "cày" điểm hợp lệ nhanh hơn chơi thật (cần rate-limit/auth đầy đủ sau). **CHƯA CHẠY trên Supabase production — xem cảnh báo đầu mục.**
2. **Forced-action tutorial ván solo đầu tiên** (`63a7102`) — thay tutorial dạng đọc (introSteps ẩn sau nút, hay bị lướt qua — xác nhận qua 2 phỏng vấn thật: Kiệt, Trubatgioi/Khánh) bằng dạy qua hành động: Sếp đứng yên + coachmark gộp giải thích màn "xem phim"+nút Tab lúc bắt đầu ván, thả Sếp chậm 0.5x sau khi bấm Tab lần đầu, message riêng phân biệt "bị bắt vì chưa kịp Tab" khác với "tự đổi màn hình" khi bị bắt trong tutorial. Chỉ chạy 1 lần/trình duyệt (`localStorage` `atd_tutorialDone`), chỉ áp dụng solo (không đụng room/multiplayer).
3. **Fix #monitor lệch tỉ lệ vòng tròn khoảng cách + đổi nhân vật màn xem phim** (`9f93b02`) — phỏng vấn phát hiện monitor CSS `clamp()` cố định độc lập với `metersToPxX` (biến JS tính vòng tròn mét), trên màn hẹp monitor có thể to hơn cả vòng 1m khiến người chơi bấm Tab sớm dù chưa thực sự nguy hiểm. Thêm `sizeMonitorToField()` neo trực tiếp theo đường kính vòng 1m (sàn 140px giữ chữ đọc được, đánh đổi có chủ đích). Đổi nội dung `buildPersonalHTML` từ SVG parody né bản quyền sang nhân vật thật có tên (Tom & Jerry, Pikachu) theo yêu cầu user — **đã cảnh báo rủi ro DMCA, user xác nhận chấp nhận** (xem file liên quan bên dưới).
4. **Rải bàn phòng đông người** — xếp đều vành tròn + bù jitter (verify bằng mô phỏng 5000 lần/N: N=2-6 đạt 0% chồng lấn), trần cứng `roomMaxPlayers: 6` chặn ở `joinRoomChannel()`.
5. **Database scalability** — 3 RPC `increment_*` nguyên tử thay pattern select-rồi-update cũ (từng có race condition mất dữ liệu khi đông người ghi cùng lúc), tối ưu `getPlayerRank()` dùng `count:'estimated'` cho phần không cần chính xác tuyệt đối. **Đã chạy `schema.sql` trên Supabase production, verify xong** (`select proname from pg_proc where proname like 'increment_%'` → đúng 3 dòng).
6. **Analytics theo ngày/tuần** — thêm 3 bảng mới (`analytics_access_hours_daily`, `analytics_screen_time_daily`, `analytics_heatmap_weekly`) song song 3 bảng cộng-dồn all-time cũ (giữ nguyên, không xoá). Khoá theo giờ VN cố định (UTC+7), tính sẵn ở client bằng `vnDateKeyPadded()`/`vnWeekKey()`. **✅ Đã chạy `schema.sql` trên Supabase production, verify xong** (2026-09-22) — `select proname from pg_proc where proname like 'increment_%' order by proname` → đúng 6 dòng (3 RPC cũ + 3 RPC mới `_daily`/`_weekly`). Toàn bộ analytics theo ngày/tuần đã hoạt động trên production, sẵn sàng cho DAU/MAU/cohort/funnel query.
7. **Mobile UX** — bỏ ép xoay ngang CSS (portrait hiển thị dọc thật), sửa `#monitor` tràn màn hình (đổi `dvw/dvh` → `cqw/cqh` container query), tối ưu render (`will-change`, bỏ `calc()` khỏi hot path), nút "Dừng ván" luôn hiện chữ ở mọi kích thước màn hình, bỏ hẳn banner gợi ý xoay ngang (test thật: nghiêng máy thật vẫn không xoay được trên 1 số cấu hình Android, banner vô dụng).
8. **Ad slot trung lập** trong modal kết quả ván (`#adSlot`, hàm `renderAdSlot(html)`) — chưa gắn network nào, sẵn sàng khi chọn AdSense/brand deal.

**Đã xác nhận qua test thật trên điện thoại**: không còn tràn màn hình, nút Dừng rõ ràng, banner xoay ngang đã gỡ. **Chưa xác nhận**: lag khi chơi thật (vòng test trước có cải thiện nhưng chưa test lại sau các thay đổi mới nhất), bàn phím ở màn nhập tên, tutorial ép + monitor scale + RLS fix mới (2026-09-23) chưa có ai test tay thật trên điện thoại/production ngoài Playwright headless.

**Việc dở, chưa hoàn thành**:
- Tích hợp Facebook Share Dialog (menu Messenger/WhatsApp/Nhóm...) — cần Facebook App ID, user bị lỗi xác minh số điện thoại đã gắn tài khoản Facebook chính, quyết định **bỏ qua**, giữ nguyên `sharer.php` hiện tại (vẫn hoạt động bình thường).
- 2 dòng debug log cũ vẫn còn trong code (`[debug boss_state gaps]` ~dòng 1258, `[debug tick gaps]` ~dòng 2399) — chưa xoá, chờ xác nhận hết lag mới xoá.
- **Canvas POC cho vùng field (vòng tròn khoảng cách)** — branch `canvas-poc` (commit `1efb0a3`, KHÔNG merge vào master). Đã chuyển 3 ring 1/2/3m từ DOM (`buildProxRings()`) sang `<canvas id="fieldCanvas">`, verify qua Playwright (render đúng desktop+mobile, không lỗi, room creation vẫn hoạt động). Benchmark đo được: frame time gameplay bình thường KHÔNG đổi (16.58ms vs 16.64ms, vì ring không vẽ lại mỗi frame) — chỉ nhanh hơn ở resize-storm (~0.27ms vs ~0.46ms, không đáng kể). **Khuyến nghị: không đáng merge ở scope hiện tại** — làm nửa vời (chỉ ring) không giải quyết dứt điểm lớp bug "đồng bộ tay nhiều nguồn toạ độ" (đã xảy ra 2 lần: `#monitor` và `.teammateUnit`), muốn giải quyết triệt để phải chuyển cả Sếp + bàn đồng nghiệp sang canvas, chi phí viết lại lớn hơn nhiều. Giữ branch lại để **user tự test tay các phiên tới** trước khi quyết định merge/xoá hẳn.

### Tổng kết phiên 2026-09-22 — 10 commit, toàn bộ đã push lên GitHub

Thứ tự thực hiện trong phiên (mới nhất ở trên): `4bbc4f0` xác nhận analytics RPC → `9bd11e8` gọn WORK_LOG → `8b2c93a` analytics ngày/tuần → `63265e7` bỏ rotate hint → `1f2cbd1` fix nút Dừng → `5307cf8` mobile UX (rotate/lag/tràn màn hình) → `2894dff` ad slot → `9086b77` cập nhật log → `289e410` database race condition → `c7a9739` rải bàn phòng đông.

Bắt đầu từ vấn đề lag multiplayer đã treo từ phiên trước (nghi vấn throttle đa-tab) — test bằng thiết bị thật riêng biệt xác nhận đây là bug render thật, không phải throttle. Trong lúc sửa, phát hiện thêm liên tiếp: bug rải bàn (mô phỏng số học lộ ra 33% ván chồng bàn ở 6 người), rồi theo yêu cầu user chuyển sang rà soát khả năng chịu traffic tăng đột biến + chèn quảng cáo — phát hiện race condition thật ở 3 bảng analytics, thiết kế lại thành phân tích theo ngày/tuần để trả lời được DAU/MAU/cohort/funnel. Xen giữa là loạt fix UX nhỏ phát hiện qua ảnh chụp thực tế từ user (nút Dừng vô hình trên mobile, banner xoay ngang vô dụng).

**Điểm học được, áp dụng lại lần sau**: khi làm việc song song 2 luồng chưa-test (mobile UX) và đã-verify (database/thuật toán), tách commit theo mức độ tin cậy — dùng `git show HEAD:file > scratch`, áp riêng từng phần lên bản HEAD sạch, so diff xác nhận không lẫn, rồi mới commit từng phần — để phần đã verify lên production ngay mà không kéo theo phần chưa test.

## Trạng thái trước đó (2026-09-19)

**Multiplayer room "1 Sếp chung" đã hoàn chỉnh và deploy** (commit `2456ec8` → `14befb2`, domain chính thức **`https://tab-ne-sep.vercel.app/play`** — KHÔNG dùng dạng `/game/TAB-Ne-Sep.html` khi đưa link cho user, dù route đó vẫn chạy).

### Đã có, đã test qua nhiều vòng với 2-3 trình duyệt thật
- Host-authoritative: host mô phỏng AI Sếp (tái dùng công thức solo, neo theo bàn người bị nhắm thay vì gốc), Broadcast ~15Hz qua Supabase Realtime.
- Layout bàn random không chồng lấn (toạ độ cực, bán kính ≤1.4m để đảm bảo mọi người luôn nằm trong field hiển thị 3m — từng có bug rải theo hình vuông làm 1 người biến mất khỏi màn hình người khác, đã sửa).
- Đồng nghiệp hiển thị monitor mini thật (tên + nội dung work/personal đồng bộ real-time qua `player_state` broadcast, mỗi người tự gửi).
- "Kết quả phòng này" — bảng so điểm riêng giữa người cùng phòng trong modal kết thúc ván.
- Nút "⏹ Dừng ván" giữa chừng (không tính điểm), nút "🔁 Chơi lại cả phòng" (chỉ host, chỉ hiện khi TẤT CẢ đã finish — tránh ép người đang chơi dở vào layout mới).
- Mời vào phòng qua link luôn dừng ở màn hỏi/sửa tên trước khi join (không tự động vào với tên mặc định).
- Trận đấu rút còn 60s (từ 120s), mục tiêu personal 30s (từ 60s), độ khó ramp 40s (từ 80s) — theo đúng tỉ lệ cũ.
- Tự động xoay ngang bằng CSS khi mở trên điện thoại cầm dọc.

### ⏳ PENDING khác — sau khi xong vòng test mobile UX ở trên

1. ~~Test phòng ≥4 người~~ → đã sửa thuật toán rải bàn + chặn ở 6 người (xem mục "Đã xong bằng mô phỏng số học" ở trên). Còn lại: test tay xác nhận UI chặn đúng khi người thứ 7 cố join (không cần điện thoại, làm trên máy tính bất cứ lúc nào).
2. Test guest vào muộn giữa trận (code có fallback về solo, chưa xác nhận qua browser thật).
3. `docs/GAME_SPEC.md` đã lạc hậu nhiều phiên (không phản ánh streak/challenge/room) — không urgent, chỉ cập nhật nếu cần tài liệu tham chiếu đầy đủ.

### Việc cũ hơn, vẫn treo — CHƯA test trong các phiên gần đây
- **Việc B (thách đấu bạn bè qua `?challenge=<id>`)**: mở `https://tab-ne-sep.vercel.app/play?challenge=seed_a3`, xác nhận banner + nút thách đấu.
- **Việc A (streak ngày chơi liên tiếp)**: dùng SQL Editor tự chỉnh `last_visit` để giả lập mốc ngày, xác nhận cảnh báo giữ chuỗi + mốc thưởng.
- Đo retention thật (query `sessions` theo `player_id`, đếm số ngày khác nhau mỗi người chơi) — chưa làm.
- Đồng bộ Việc A/B/room sang bản radar (`TAB-Ne-Sep_v1-radar.html`) — bản này vẫn chỉ có bug fix + icon + mobile cũ.

## Quyết định/ràng buộc quan trọng cần nhớ

- **Luôn hỏi xác nhận trước khi `git push`** — trừ khi user rõ ràng trao quyền tự quyết trong 1 phiên cụ thể.
- **Streak dùng giờ Việt Nam cố định (UTC+7)**, không dùng giờ máy khách.
- **Thách đấu bạn bè (`?challenge=`) KHÔNG phải multiplayer room** — 2 tính năng khác nhau hoàn toàn, đừng nhầm lẫn khi tiếp tục.
- Mọi thay đổi Supabase (Broadcast/Presence/Postgres Changes/cột mới) đều fail gracefully (try/catch, không crash UI) nếu bảng/cột chưa tồn tại trên Supabase thật.
- `playerId` gắn với từng cặp (trình duyệt, domain) qua `localStorage` — đổi trình duyệt trên cùng máy = danh tính khác hoàn toàn. Chưa có giải pháp, chỉ là rủi ro đã biết cho streak.
- Supabase Free tier: rủi ro gần nhất là **project tự pause sau 7 ngày không traffic** — nếu gặp lỗi kết nối DB sau thời gian dài không ai chơi, vào Supabase dashboard resume thủ công trước.

## File liên quan

```
game/TAB-Ne-Sep_v2-perspective.html — BẢN CHÍNH (`/play`, `/play-3d`): phối cảnh thật, phòng nhóm (xin chơi lại, chuyển host, shuffle-bag, dead reckoning), ảnh Sếp, ❓ Hướng dẫn, tutorial làm tối, xoay ngang, secret theo người chơi
game/TAB-Ne-Sep.html            — bản elip cũ (`/play-2d`, dự phòng): chỉ bản vá bảo mật + sửa tutorial/tick, thiếu tính năng mới
game/TAB-Ne-Sep_v1-radar.html   — bản radar cũ, KHÔNG còn deploy (.vercelignore), chưa tương thích RPC mới
supabase/schema.sql             — bảng + RPC + RLS; MỤC 5 (cuối file) = hardening: player_secrets, rate_limits, player_auth(), create_room, validate_*, thu hồi quyền ghi; idempotent; chạy lại toàn bộ khi sửa; ĐÃ chạy trên production (2026-10-08)
vercel.json                     — redirect "/" → "/play"; rewrite /play + /play-3d → v2 (không còn /play-2d); header bảo mật (CSP, X-Frame-Options, nosniff, Referrer, Permissions, COOP)
.vercelignore                   — loại supabase/, docs/, *.md, .claude/, v1-radar khỏi bản deploy công khai
CLAUDE.md                       — mô hình bảo mật + quy tắc dữ liệu mạng không tin cậy + bề mặt deploy (cập nhật 2026-10-08)
```

**Branch riêng (chưa merge):** `canvas-poc` (commit `1efb0a3`) — POC vẽ vòng tròn khoảng cách bằng canvas thay DOM, xem mục "Việc dở" ở trên. `git checkout canvas-poc` để tự mở test.
