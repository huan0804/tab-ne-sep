# Nhật ký làm việc — TAB: Né Sếp

> File này ghi lại trạng thái dự án để tiếp tục ở phiên làm việc sau. Cập nhật mỗi khi có tiến triển lớn, dọn bớt phần đã lỗi thời để tránh phình to.

## Trạng thái hiện tại (2026-09-23)

**⚠️ VIỆC QUAN TRỌNG NHẤT CẦN LÀM NGAY Ở PHIÊN SAU: chạy `schema.sql` trên Supabase SQL Editor production.** Code đã push (`ff94716`) nhưng RPC `ensure_player`/`submit_match_result`/`start_room_match` mới CHƯA tồn tại trên DB thật — cho tới khi chạy SQL, ghi điểm/tạo phòng trên production sẽ lỗi (fail gracefully, không crash UI, nhưng leaderboard/room không hoạt động). Sau khi chạy, verify bằng `select proname from pg_proc where proname in ('ensure_player','submit_match_result','start_room_match')` → phải ra đúng 3 dòng, rồi chơi thử 1 ván thật để xác nhận điểm lên leaderboard.

**Đã push lên GitHub, tất cả trên production tại `https://tab-ne-sep.vercel.app/play`:**

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
- Chạy `schema.sql` trên Supabase production cho RLS fix (mục 1 ở trên) — ưu tiên cao nhất, làm trước mọi việc khác ở phiên sau.
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
game/TAB-Ne-Sep.html            — bản chính: room "1 Sếp chung" + streak + challenge-link + mobile UX (portrait thật, không rotate) + ad slot trung lập + analytics ngày/tuần + tutorial ép ván đầu + monitor scale theo field + nhân vật Tom&Jerry/Pikachu
game/TAB-Ne-Sep_v1-radar.html   — bản radar, CHỈ có bug fix + icon + mobile cũ, lạc hậu nhiều phiên so với bản chính
supabase/schema.sql             — players/sessions/rooms + 6 RPC increment_* (analytics all-time + theo ngày/tuần) + RLS, đã verify chạy thành công trên Supabase production (2026-09-22)
vercel.json                     — root "/" redirect → "/play", rewrite "/play" → "/game/TAB-Ne-Sep.html"
```

**Branch riêng (chưa merge):** `canvas-poc` (commit `1efb0a3`) — POC vẽ vòng tròn khoảng cách bằng canvas thay DOM, xem mục "Việc dở" ở trên. `git checkout canvas-poc` để tự mở test.
