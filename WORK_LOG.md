# Nhật ký làm việc — TAB: Né Sếp

> File này ghi lại trạng thái dự án để tiếp tục ở phiên làm việc sau. Cập nhật mỗi khi có tiến triển lớn, dọn bớt phần đã lỗi thời để tránh phình to.

## Cập nhật 2026-10-08 (cuối phiên) — phòng nhóm & tutorial, đã push

**✅ Đã xác nhận trên production:** schema.sql mục 5 đã chạy thành công; ghi điểm solo qua secret hoạt động (người dùng xác nhận bảng xếp hạng cập nhật). **Chưa xác nhận trên production:** tạo phòng/chơi lại bằng RPC có secret (đã test bằng Supabase giả + PGlite).

Đã làm (commit `b5e4ca0` → `99a8006`, đều đã push, chỉ bản `TAB-Ne-Sep_v2-perspective.html`):
- Nút "Chơi lại cả phòng" màu đỏ (CTA chính).
- Nhãn dưới Sếp trong phòng: "👀 Đang kiểm tra <tên>" / "🎯 Đang nhắm BẠN!" — giữ nguyên số mét/viền đỏ cho cả phòng (cố ý, để cả phòng cùng căng thẳng). Việc Sếp <1m mà không bắt người không bị nhắm là THIẾT KẾ, không phải lỗi.
- Chọn mục tiêu bằng shuffle-bag (`pickNextTargetPlayerId`): mỗi vòng mọi người bị nhắm đúng 1 lần. Cũ (random độc lập) chênh tới 6/7/9; mới 7/7/7.
- Tutorial: làm tối phần không cần thiết (#tutorialDim, `setTutorialFocus`): bước 1 sáng màn hình + nút Tab, bước 2 thêm Sếp + vòng; tắt khi Tab lần 2/bị bắt/hết ván/14s. Sửa banner "SẾP ĐANG LẠI GẦN" hiện sớm.
- Nội suy Sếp phía guest (snapshot interpolation), nút ❓ Hướng dẫn, "Về trang chủ", xin chơi lại tới host + chuyển host (xem các mục trước).

**Việc còn mở:**
- Test tay trên điện thoại/nhiều máy thật: tutorial làm tối, nhãn Sếp, phòng nhiều người, snapshot interpolation.
- `modalBtn` ("Chơi lại") gọi thêm `requestAnimationFrame(tick)` mỗi lần dù `tick()` luôn tự lặp → có thể nhân đôi vòng lặp theo số lần chơi lại (chưa kiểm chứng có gây lỗi thật).
- `/play-2d` (bản elip) chỉ nhận bản vá bảo mật + sửa tutorial, KHÔNG có tính năng phòng/hướng dẫn mới.

---

## Cập nhật 2026-10-08 (phiên tối) — RÀ SOÁT & TĂNG CƯỜNG BẢO MẬT

**⚠️ VIỆC BẮT BUỘC SAU KHI PUSH: chạy lại `supabase/schema.sql` (mục 5 mới) trong Supabase SQL Editor ngay sau khi Vercel deploy xong.** Chữ ký RPC cũ bị xoá nên client mới và schema mới phải đi cùng nhau; chưa chạy SQL thì tạo phòng/ghi điểm sẽ lỗi (graceful, không crash). Schema đã chạy thử 2 lần liên tiếp trên Postgres thật (PGlite) + 50 test, nhưng CHƯA chạy trên Supabase production.

Đã phát hiện & vá:
- **XSS giữa người chơi** qua broadcast `player_state` (workData đồng đội nối thẳng innerHTML): dựng exploit thật → bản cũ chạy được mã trong trình duyệt nạn nhân, bản vá = 0. Mọi payload nhận qua mạng giờ qua `sanitize*`/`isSafeId`.
- **Không có xác thực chủ playerId** (id công khai trên leaderboard): ai cũng đổi tên/đẩy điểm/cướp host người khác → thêm secret 256-bit/người (`player_secrets`, lưu SHA-256), mọi RPC ghi yêu cầu `p_secret`.
- **Ghi trực tiếp**: bỏ INSERT của `sessions`/`rooms` (chuyển RPC `create_room`, `submit_match_result` tự ghi sessions), thu hồi quyền ghi của anon, ẩn đọc `sessions`.
- **Analytics RPC**: validate date_key/week_key (trước đây tạo được vô hạn dòng), heatmap JSON (giới hạn khoá/giá trị), duration (âm/NaN/khổng lồ).
- **Rate-limit** theo IP + theo người chơi; điểm bị chặn theo thời gian thật; streak kẹp ở server; tên bỏ `<>`.
- **Triển khai**: `vercel.json` thêm CSP/X-Frame-Options/nosniff/Referrer/Permissions/COOP; `.vercelignore` (trước đó schema.sql, WORK_LOG, CLAUDE.md, docs đang public trên domain); supabase-js ghim 2.117.3 + SRI; `window.open` thêm noopener.
- Bản `v1-radar` không còn được deploy (mã cũ, chưa tương thích RPC mới). `/play-2d` đã cập nhật cùng client.

Rủi ro còn lại (đã biết, chưa giải quyết): (1) dòng `players` CŨ chưa có chủ — ai gọi RPC với id đó trước chủ thật sẽ chiếm (người chơi bị chiếm sẽ bị "forbidden", cần xoá localStorage để tạo id mới); (2) kênh Realtime không xác thực → kẻ biết mã phòng giả được tin nhắn host (không chạy được mã, không đụng điểm); (3) điểm vẫn do client tự tính → cheat "hoàn hảo theo thời gian thật" không chặn được nếu không có server mô phỏng; (4) CSP còn `'unsafe-inline'` vì game là 1 file inline.

---

## Cập nhật 2026-10-08 (phiên chiều)

**✅ v2-perspective là bản chính.** `/play` (và alias `/play-3d`) → `game/TAB-Ne-Sep_v2-perspective.html` (phép chiếu pinhole thật, `UI_VARIANT='perspective'`); bản elip cũ `game/TAB-Ne-Sep.html` giữ ở `/play-2d` làm dự phòng. User đã test `/play-3d` và xác nhận ổn. Lưu ý: góc nhìn ngẫu nhiên mỗi ván (`pickViewAngle`) chỉ có ở bản elip, bản v2 dùng camera cố định. **Chưa test phòng nhiều máy trên v2.**

**✅ Vá thuật toán Sếp (`b17ca9b`, áp dụng cả 2 bản, CHƯA test tay trong trình duyệt)** — user báo tần suất Sếp lại gần thấp. Mô phỏng Node cho thấy: (1) ~40% lần áp sát không tạo "lần vào 1m" mới vì Sếp bị kéo vào lần áp sát kế tiếp trước khi ra tới `rearmRadius` 1.8m nên `wasClose` không nạp lại; (2) ~7% đích áp sát nằm ngoài 1m do `checkTarget*` tính theo toạ độ game còn `dist` nhân y với `ellipseRatio`. Fix: nạp lại `wasClose` khi Sếp bắt đầu áp sát mới mà đang ngoài `catchRadius` (biến `prevBossForced` trong `tick()`), và chia đích cho `hypot(cos, sin·ellipseRatio)`. Kết quả mô phỏng: lần vào 1m/ván 60s tăng ~12.9 → ~17.8. Nếu quá gắt, chỉnh `checkGapStart/End`.

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
game/TAB-Ne-Sep_v2-perspective.html — BẢN CHÍNH hiện tại (`/play`, `/play-3d`): bản dưới nhưng vòng khoảng cách phối cảnh thật
game/TAB-Ne-Sep.html            — bản elip cũ (`/play-2d`, dự phòng): room "1 Sếp chung" + streak + challenge-link + mobile UX (portrait thật, không rotate) + ad slot trung lập + analytics ngày/tuần + tutorial ép ván đầu + monitor scale theo field + nhân vật Tom&Jerry/Pikachu
game/TAB-Ne-Sep_v1-radar.html   — bản radar, CHỈ có bug fix + icon + mobile cũ, lạc hậu nhiều phiên so với bản chính
supabase/schema.sql             — players/sessions/rooms + 6 RPC increment_* (analytics all-time + theo ngày/tuần) + RLS, đã verify chạy thành công trên Supabase production (2026-09-22)
vercel.json                     — root "/" redirect → "/play"; rewrite "/play" và "/play-3d" → v2-perspective, "/play-2d" → TAB-Ne-Sep.html
```

**Branch riêng (chưa merge):** `canvas-poc` (commit `1efb0a3`) — POC vẽ vòng tròn khoảng cách bằng canvas thay DOM, xem mục "Việc dở" ở trên. `git checkout canvas-poc` để tự mở test.
