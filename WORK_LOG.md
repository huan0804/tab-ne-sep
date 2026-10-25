# Nhật ký làm việc — TAB: Né Sếp

> File này ghi lại trạng thái dự án để tiếp tục ở phiên làm việc sau. Cập nhật mỗi khi có tiến triển lớn, dọn bớt phần đã lỗi thời để tránh phình to (lịch sử chi tiết xem `git log`).

## Trạng thái hiện tại (cập nhật 2026-10-25)

- **Giai đoạn:** đang build, chưa publish, chưa có người chơi thật (23 người chơi trong DB chủ yếu là người test).
- `/play` (alias `/play-3d`) = `game/TAB-Ne-Sep_v2-perspective.html` — **bản chính duy nhất nhận tính năng mới**. Route `/play-2d` đã gỡ; `TAB-Ne-Sep.html` còn trong repo (không còn route, nhưng vẫn truy cập được ở `/game/TAB-Ne-Sep.html`). `v1-radar` không deploy (`.vercelignore`).
- `supabase/schema.sql` (gồm mục 5 hardening) **đã chạy trên production** (xác nhận 2026-10-08). Client và schema phải deploy cùng nhau.
- Production = `master`, đã push đến `3df9a95`. Notion: project "Né Sếp (TAB)" chỉ còn task "Đo retention thật" (deadline 2026-11-01).

## Phiên 2026-10-25 — dọn việc tồn đọng

- Gỡ route `/play-2d` khỏi `vercel.json`.
- Viết lại README.md và docs/GAME_SPEC.md theo Supabase + bản v2 (luật 30s/60s, `CONFIG`, thêm mục §14 tính năng sau đặc tả gốc). CLAUDE.md sửa đường dẫn file Supabase, thêm ghi chú CSP hard-code host.
- Xoá 2 dòng debug log (`[debug boss_state gaps]`, `[debug tick gaps]`) khỏi v2-perspective, kèm mảng `window.__*Gaps` vốn tăng không giới hạn. Bản `TAB-Ne-Sep.html` vẫn còn.
- Đo thử retention bằng SQL: D0=23, D3=3, D14=1 người — chỉ là dữ liệu người test, không phản ánh retention thật. Khi đo lại sau publish, nên dùng query chỉ tính người đã đủ thời gian và đếm "quay lại ít nhất 1 lần trong N ngày".
- Dọn Notion: xoá các task test/quyết định không cần thiết (đã chuyển vào mục dưới).
- Token Supabase `sbp_...` từng bị dán trong chat ở project khác (SupGam): chủ dự án quyết định không xử lý; token vẫn dùng được đến khi thu hồi ở Supabase → Account preferences → Access Tokens.

### Hạng mục CHƯA làm có chủ đích — chỉ để tra cứu khi có issue
Chủ dự án xác nhận hiện tại game đã ổn, nên KHÔNG làm các mục dưới đây. Nếu sau này có lỗi liên quan, quay lại đây trước.

**Test tay chưa làm:**
- Phòng nhóm trên production: tạo phòng, chơi lại, chuyển host bằng RPC có secret; Sếp mượt ở guest; phòng 5 người.
- Tutorial làm tối, nhãn Sếp, `orientation.lock` trên Android Chrome (mở trực tiếp), nhắc xoay trong Zalo/Facebook, popup/HUD ở chế độ `html.fl`.
- Streak: dùng SQL Editor chỉnh `last_visit` giả lập mốc ngày, xác nhận cảnh báo giữ chuỗi + mốc thưởng.
- Thách đấu `?challenge=<id>`: mở `/play?challenge=seed_a3`, xác nhận banner + nút thách đấu.
- Guest vào muộn giữa trận (code có fallback về solo, chưa xác nhận trên trình duyệt thật).
- UI chặn người thứ 7 vào phòng (`roomMaxPlayers: 6`, chặn ở `joinRoomChannel()`).

**Quyết định chưa chốt (mặc định = giữ nguyên hiện trạng):**
- Nhánh `canvas-poc` (`1efb0a3`, chưa merge): vẽ vòng khoảng cách bằng canvas. Benchmark không cải thiện frame time gameplay (16.58ms vs 16.64ms); muốn giải dứt điểm lớp bug "đồng bộ tay nhiều nguồn toạ độ" phải chuyển cả Sếp + bàn đồng nghiệp sang canvas, chi phí lớn. Khuyến nghị: không merge.
- Dòng `players` cũ chưa có chủ: ai gọi RPC với id đó trước chủ thật sẽ chiếm; người bị chiếm gặp "forbidden" và phải xoá `localStorage`. Chấp nhận rủi ro.
- Có chặn hẳn `/game/TAB-Ne-Sep.html` bằng `.vercelignore` hay không.
- Ad slot `#adSlot` chưa gắn network; Facebook Share Dialog vẫn bỏ qua (cần App ID, dùng `sharer.php`).

## Tóm tắt phiên 2026-10-08 (20 commit, `3451efa` → `f2dff55`)

**Đã xác nhận trên production:** ghi điểm solo qua secret; bảng xếp hạng; tải/hiện ảnh Sếp; nút Về trang chủ; nút Hướng dẫn; xoay giao diện CSS trên máy thật. Header bảo mật đủ; `schema.sql`/WORK_LOG/CLAUDE.md/docs trả 404.

**Đã làm:**
1. **Thuật toán Sếp ít lại gần** (`b17ca9b`): ~40% lần áp sát không thành "lần vào 1m" vì `wasClose` chỉ nạp lại khi ra >1.8m, và ~7% đích áp sát nằm ngoài 1m do trục y nhân `ellipseRatio`. Fix: nạp lại khi bắt đầu áp sát mới (`prevBossForced`) + chia đích cho `hypot(cos, sin·ellipseRatio)`.
2. **Tính năng người chơi**: ảnh Sếp tự chọn (localStorage, JPEG 192px, không upload); nút ❓ Hướng dẫn trên HUD; tutorial **làm tối** phần không cần thiết (`#tutorialDim`, `setTutorialFocus`).
3. **Phòng nhóm**: "Xin chơi lại" gửi tới host, host bấm "Chơi lại cả phòng" khi mọi người xong; **chuyển host** khi host rời (người có `playerId` nhỏ nhất, RPC `claim_room_host` best-effort); nhãn "👀 Đang kiểm tra <tên>" / "🎯 Đang nhắm BẠN!" (Sếp <1m mà không bắt người không bị nhắm là THIẾT KẾ); chọn mục tiêu bằng shuffle-bag.
4. **Tải Realtime** (gói free = **100 tin/giây CẢ project, tính cả gửi và nhận**): snapshot interpolation phía guest rồi **dead reckoning** (host chỉ gửi khi đích/tốc độ/mục tiêu đổi + heartbeat 1s, `CONFIG.bossHeartbeatMs`) → 66 → 6,7 tin/giây cho phòng 5 người. Host cũ (stream 15Hz) vẫn được guest mới hỗ trợ.
5. **Bảo mật** (chi tiết mô hình trong CLAUDE.md): vá XSS qua broadcast `player_state`; xác thực chủ `playerId` bằng secret 256-bit (mẫu `player_auth()` dùng lại được cho RPC mới); bỏ INSERT trực tiếp, thu hồi quyền ghi của anon; rate-limit; `vercel.json` CSP + header bảo mật; supabase-js ghim 2.117.3 + SRI.
6. **Điện thoại**: bấm Bắt đầu/Tạo phòng → toàn màn hình + `screen.orientation.lock('landscape')`; không khoá được → `#rotatePrompt` với nút **"↻ Xoay giao diện sang ngang"** (`html.fl` xoay #stage 90° bằng CSS, nhớ trong sessionStorage `atd_fl`); bố cục nằm ngang gọn (`@media (orientation:landscape) and (max-height:520px)`).
7. **Lỗi có sẵn tìm thấy & sửa**: `tick()` nhân đôi mỗi lần "Chơi lại" (nay `queueTick()`); coachmark tutorial bước 1 bị bước 2 ghi đè; guest không tự vào ván mới khi host "Chơi lại cả phòng"; Sếp bị phóng 5,6 lần che màn hình khi lang thang phía camera (chặn depth ở mép vòng 3m).

**Quyết định & bài học cần nhớ:**
- **KHÔNG làm PWA** để ép ngang (chủ dự án chọn giữ khoá-hướng + nút xoay CSS). Web chỉ xin khoá hướng được sau thao tác người dùng, và trình duyệt trong app (Zalo/Facebook) / iOS thường từ chối.
- CSS-rotate từng bị bỏ (bàn phím ảo không xoay theo, đo kích thước sai), nay quay lại có chọn lọc, chỉ khi người chơi tự bấm. Rủi ro còn: bàn phím ảo (chỉ ô nhập tên), toạ độ heatmap analytics lệch.
- 8 repo lag-compensation/party-game đã xem xét: **không dùng thư viện nào** (server-rewind là cho game bắn súng; ở đây mỗi client tự chấm "bị bắt" theo vị trí Sếp mình thấy). Chỉ lấy ý "lịch sử có timestamp + nội suy".
- Test kiểu "Supabase giả (hub trong Node, định tuyến realtime giữa nhiều Chrome headless) + PGlite (Postgres thật bằng WASM)" bắt được nhiều lỗi mà test đơn lẻ không thấy. **Bộ test này KHÔNG có trong repo** — dựng lại nếu cần.
- Đo trước, kết luận sau: phép đo giật rất nhiễu → chạy xen kẽ cũ/mới nhiều cặp, tách "rơi khung hình" khỏi "Sếp nhảy thật".

**Rủi ro còn lại:** kênh Realtime không xác thực (kẻ biết mã phòng giả được tin nhắn host, không chạy được mã/không đụng điểm); điểm do client tính (cheat "hoàn hảo theo thời gian thật" không chặn được nếu thiếu server mô phỏng); CSP còn `'unsafe-inline'`; `claim_room_host` ai biết mã phòng + id host cũ + có tài khoản hợp lệ đều gọi được; trần Realtime free ~100 tin/giây cả project (nay ~1,3 tin/giây/người trong phòng).

## Quyết định/ràng buộc quan trọng cần nhớ

- **Luôn hỏi xác nhận trước khi `git push`** — trừ khi chủ dự án rõ ràng cho phép trong phiên đó.
- **Streak dùng giờ Việt Nam cố định (UTC+7)**, không dùng giờ máy khách.
- **Thách đấu (`?challenge=`) KHÔNG phải phòng nhóm** — 2 tính năng khác nhau hoàn toàn.
- Mọi thay đổi Supabase (Broadcast/Presence/Postgres Changes/cột mới) phải fail gracefully (try/catch, không crash UI) nếu bảng/cột chưa tồn tại.
- `playerId` gắn với từng cặp (trình duyệt, domain) qua `localStorage` — đổi trình duyệt = danh tính khác. Chưa có giải pháp, ảnh hưởng độ chính xác streak và retention.
- Supabase Free tier tự pause sau 7 ngày không traffic — gặp lỗi kết nối DB sau thời gian dài thì vào dashboard resume trước.
- Nội dung màn hình personal dùng nhân vật có bản quyền thật (Tom & Jerry, Pikachu) theo yêu cầu chủ dự án, đã cảnh báo và chấp nhận rủi ro DMCA.
- Khi làm song song thay đổi đã verify và chưa test, tách commit theo mức độ tin cậy (`git show HEAD:file > scratch`, áp từng phần, so diff) để phần đã verify lên production không kéo theo phần chưa test.

## File liên quan

```
game/TAB-Ne-Sep_v2-perspective.html — BẢN CHÍNH (`/play`, `/play-3d`)
game/TAB-Ne-Sep.html            — bản elip cũ, không còn route (vẫn truy cập ở /game/TAB-Ne-Sep.html)
game/TAB-Ne-Sep_v1-radar.html   — bản radar cũ, không deploy, chưa tương thích RPC mới
supabase/schema.sql             — bảng + RPC + RLS; mục 5 (cuối file) = hardening; idempotent, chạy lại toàn bộ khi sửa
vercel.json                     — redirect "/" → "/play"; rewrite /play + /play-3d → v2; header bảo mật
.vercelignore                   — loại supabase/, docs/, *.md, .claude/, v1-radar khỏi bản deploy công khai
CLAUDE.md                       — kiến trúc, mô hình bảo mật, quy tắc dữ liệu mạng không tin cậy
```

**Branch riêng (chưa merge):** `canvas-poc` (`1efb0a3`), xem mục quyết định chưa chốt ở trên.
