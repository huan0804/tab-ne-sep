# Nhật ký làm việc — TAB: Né Sếp

> File này ghi lại trạng thái dự án để tiếp tục ở phiên làm việc sau. Cập nhật mỗi khi có tiến triển lớn.

## Trạng thái hiện tại (2026-09-19, phiên "1 Sếp chung" hoàn thiện)

**Multiplayer room "1 Sếp chung" đã đi từ 1/4 (hạ tầng phòng) lên HOÀN CHỈNH và đã test thật 2 trình duyệt (Chrome + CocCoc) qua domain Vercel thật** — đây là tiến triển lớn nhất phiên này, thay thế hoàn toàn trạng thái "chưa bắt đầu" ghi ở mục cũ bên dưới (mục đó giờ đã lỗi thời, giữ lại chỉ để tham chiếu lịch sử).

### Việc đã làm xong và deploy (commit `2456ec8` → `9934caf`, đã push + test qua Vercel)

**"1 Sếp chung" — cơ chế multiplayer thật (nối tiếp hạ tầng phòng đã có từ `ac1920f`):**
- Host-authoritative: máy chủ phòng mô phỏng AI Sếp (tái dùng công thức solo, chỉ đổi từ "neo gốc (0,0)" sang "neo theo bàn 1 người"), Broadcast vị trí + target ~15Hz qua Supabase Realtime Broadcast.
- Layout bàn: host random 1 lần lúc bấm "Bắt đầu" (rejection sampling tránh chồng lấn), broadcast 1 lần cho cả phòng dùng chung.
- Target xoay vòng theo đúng nhịp forced-approach cũ; chỉ người đang bị nhắm mới có thể bị bắt, người khác an toàn tuyệt đối nhưng vẫn cộng dồn điểm bình thường.
- Đồng nghiệp hiển thị dạng **monitor mini thật** (không phải chấm tròn) trên cùng hệ vòng tròn elip, có tên + nội dung work/personal đồng bộ real-time (mỗi người tự broadcast mode của mình khi đổi, sự kiện `player_state`, không phải chỉ host).
- **"Kết quả phòng này"**: bảng so điểm riêng giữa người cùng phòng trong modal kết thúc ván (khác bảng xếp hạng chung toàn game), cập nhật dần khi từng người finish (sự kiện `player_finished`).
- Host rời phòng giữa trận → guest nhận thông báo "phòng ngắt kết nối", kết thúc nhẹ nhàng (không có host-migration, giới hạn đã biết).
- Responsive: fix bug monitor mini đồng nghiệp chồng lấn ở màn hẹp (scale theo đúng tỷ lệ mét→pixel thay vì px cố định), thêm favicon (hết lỗi console 404 vô hại), và **tự động xoay ngang bằng CSS khi mở trên điện thoại cầm dọc** (game thiết kế cho khung ngang, không bắt người chơi tự xoay máy).

**Bug thật đã gặp và sửa trong lúc test:**
- Bàn đồng nghiệp random ra ngoài phạm vi khung hiển thị (`roomDeskBoundsMin/Max` ±6m trong khi vòng tròn chỉ vẽ tới 3m) → không thấy đồng nghiệp. Đã siết lại ±2.6m.
- Guest's `roomPlayerIds` không được set từ `match_start` payload (chỉ host set) — không gây triệu chứng trực tiếp nhưng là lỗ hổng thật, đã vá.

**Đã test 2 trình duyệt thật (Chrome + CocCoc) qua domain Vercel** — xác nhận: đồng nghiệp hiện đúng, không overlap ở màn hẹp, xoay ngang đúng chiều, bảng "Kết quả phòng này" hoạt động.

**Chưa test:** trường hợp phòng >2 người, trường hợp guest vào muộn giữa trận (code có fallback về solo nhưng chưa xác nhận qua browser thật), độ lag/độ trễ mạng thực tế trong điều kiện xấu hơn (2 tab cùng máy = độ trễ gần như 0, chưa test 2 thiết bị khác mạng).

---

## Trạng thái trước đó (2026-09-19, phiên research/URL cleanup — đã lỗi thời, giữ để tham chiếu)

Phiên này là **research/Q&A để hiểu kiến trúc trước khi fine-tune plan** (không đụng vào các việc CHƯA XONG liệt kê ở phần dưới — schema Supabase, test streak/challenge, room, đo retention **vẫn y nguyên như phiên trước, chưa làm gì thêm**). Chỉ có đúng 1 thay đổi code thật phát sinh ngoài lề, đã deploy xong.

### Việc đã làm xong và deploy (commit `9934caf`, đã push + Vercel tự redeploy)

**Dọn URL game — bỏ đuôi `.html` khỏi link công khai:**
- Vấn đề phát hiện: link phòng/thách đấu được sinh từ `location.href`. Nếu user mở game bằng double-click file cục bộ thay vì qua domain thật, link share ra sẽ là `file:///D:/...` (chỉ chạy trên đúng máy đó, người khác không mở được). Ngoài ra ngay cả khi mở đúng domain, URL cũ vẫn lộ `/game/TAB-Ne-Sep.html` — trông như source code lộ ra ngoài, giảm cảm giác "sản phẩm thật".
- Fix: `vercel.json` thêm `rewrites` (`/play` → `/game/TAB-Ne-Sep.html`, giữ nguyên URL trên thanh địa chỉ, khác với `redirects` là sẽ lộ đích cuối) + đổi `redirects` gốc (`/` → `/play` thay vì thẳng vào file `.html`).
- Domain chính thức xác nhận lại: **`https://tab-ne-sep.vercel.app`** (Vercel team "Han", Hobby plan). Trang tổng quan Vercel gọi là "Overview" (không có nhãn "Dashboard" riêng, dễ gây bối rối khi tìm lại).
- Đã verify bằng `curl -I` sau khi deploy: `tab-ne-sep.vercel.app/` → 308 redirect đúng sang `/play`. User tự mở trình duyệt xác nhận OK.
- **Chưa làm:** rút gọn thêm domain (`.com`/`.app` riêng thay vì `.vercel.app`) — mới dừng ở mức research trong hội thoại, chưa quyết định mua domain nào, không phải việc cần làm ngay.

### Đã lưu vào Claude memory (không phải trong repo)
- `tab-ne-sep.vercel.app` là domain chính thức + cảnh báo pitfall `file://` — lưu tại `project_vercel_domain.md` trong memory Claude, để các phiên sau tự biết domain, khỏi phải tìm lại trong Vercel dashboard mỗi lần.

### Kiến thức nền đã thống nhất trong phiên (để tham chiếu, không phải quyết định mới)
- `playerId` sinh từ `crypto.randomUUID()`, lưu trong `localStorage` gắn với **từng cặp (trình duyệt, domain)** — đổi trình duyệt (vd Chrome ↔ CocCoc) trên cùng máy = 2 danh tính khác nhau hoàn toàn trên Supabase, dù cùng 1 người. Đây là rủi ro thật cho streak nếu người chơi đổi trình duyệt — **cần cân nhắc đưa vào phần rủi ro khi fine-tune plan retention**, hiện chưa có giải pháp (ví dụ: cho phép nhập lại playerId cũ bằng tay, hoặc chấp nhận giới hạn này).
- Giới hạn Supabase Free tier ước tính KHÔNG phải điểm nghẽn gần (database 500MB ≈ hàng triệu ván chơi mới chạm) — rủi ro gần nhất thực ra là **project tự pause sau 7 ngày không có traffic** (đặc thù side project ít người chơi giữa các đợt phát triển), cần nhớ vào Vercel/Supabase dashboard resume thủ công nếu gặp lỗi kết nối DB sau thời gian dài không ai mở game.

## Trạng thái hiện tại (2026-09-16, phiên khuya)

Sau khi làm xong 4 việc kỹ thuật (bug fix, icon, mobile, hạ tầng multiplayer room — xem phần dưới), user yêu cầu chạy skill `personatwin` để phản biện game bằng Mom Test. Kết quả phản biện dẫn tới 1 hướng đi mới: **retention loop** — hiện đang code dở, CHƯA test bằng browser (user đi ngủ giữa lúc đang làm).

### Bối cảnh phản biện (để hiểu TẠI SAO 2 feature mới này tồn tại)

Chạy `personatwin` với persona "Ngọc, 24t, nhân viên marketing, hay lén xem TikTok giờ làm". Verdict Mom Test:
- Pain có thật (sợ bị bắt, chán giờ làm) nhưng game chỉ giải quyết pain đó theo kiểu **ẩn dụ/giải trí 1 lần** — không có lý do quay lại lần 2-3-4. Đúng mẫu "viral game mở 1 lần rồi bỏ".
- Leaderboard ẩn danh (6 seed ảo + người lạ) không đủ động lực — thứ khiến người Việt quay lại là thi đấu với **người quen cụ thể**.
- Root cause: `players.last_visit` đã có sẵn nhưng **không được dùng cho bất kỳ retention mechanic nào**.

User quyết định làm cả 2 hướng, ưu tiên retention trước. Plan chi tiết đầy đủ ở `C:\Users\Huan\.claude\plans\goofy-imagining-hellman.md` (máy Windows user) — đọc lại nếu cần thiết kế kỹ thuật gốc.

### Việc ĐÃ XONG và đã push (commit `47a4b7f`) — CHƯA TEST BẰNG BROWSER

**Việc A — Streak ngày chơi liên tiếp ("🔥 Chuỗi Né Sếp"):**
- Schema: thêm cột `current_streak`, `longest_streak` vào bảng `players` (`alter table add column if not exists`, an toàn chạy lại nhiều lần).
- Logic tính streak trong `recordSharedSession()` (`game/TAB-Ne-Sep.html`): so sánh `last_visit` CŨ với "hôm nay", **chuẩn hóa theo giờ Việt Nam UTC+7** bất kể múi giờ máy người chơi (hàm `vnDateKey`/`vnDaysBetween`/`computeStreak`). Đã tự viết 5 test case bằng Node script riêng (không phải browser) xác nhận đúng 3 nhánh: cùng ngày (giữ nguyên), đúng hôm sau (nối chuỗi +1), cách >1 ngày (reset về 1) — kể cả case biên "chỉ cách 20 phút thật nhưng qua mốc nửa đêm VN" tính đúng là sang ngày mới.
- UI: `showRecordLine()` (màn intro) — nếu streak ≥2 và **chưa chơi hôm nay**, hiện cảnh báo loss-aversion "⚠️ Chơi 1 ván hôm nay để giữ chuỗi N ngày!" thay dòng trung bình thường. Modal kết quả — nếu streak tăng, hiện 1 trong 4 dòng mốc đặc biệt (3/7/14/30 ngày) hoặc dòng chung.

**Việc B — Thách đấu người quen (`?challenge=<playerId>`):**
- KHÔNG phải multiplayer room thật — không real-time, không đồng bộ. Chỉ là lớp mỏng phủ lên link chia sẻ: mở link có `?challenge=<id>` → màn intro hiện banner "⚔️ [Tên] vừa đạt Xs — thử vượt qua chưa?" (đọc thẳng `getPlayerRecord` đã có).
- Sau khi chơi xong, nút mới trong modal kết quả: nếu vượt điểm người thách đấu → nút đổi thành "⚔️ Bạn vừa vượt qua [Tên]! Thách đấu ngược lại"; nếu không → nút mặc định "⚔️ Thách đấu bạn bè bằng điểm này". Bấm nút = copy link `?challenge=<playerId của mình>`.

**Chỉ áp dụng cho `TAB-Ne-Sep.html` (bản elip)** — CHƯA đồng bộ sang `TAB-Ne-Sep_v1-radar.html` (theo đúng thói quen: ổn định 1 bản trước).

### CHƯA XONG — cần làm ngay khi mở lại phiên

1. **CHẶN ĐẦU TIÊN — User cần chạy lại `supabase/schema.sql` đã cập nhật** trong SQL Editor. Đã verify qua API: cột `current_streak` **chưa tồn tại** trên Supabase (lỗi "column players.current_streak does not exist"). File schema.sql hiện có SẴN 2 việc cần chạy cùng lúc: bảng `rooms` (từ phiên trước, multiplayer room) + 2 cột streak (phiên này) — chạy 1 lần cho cả 2.

2. **Chưa test bằng browser** — đã dừng ngay lúc đang chuẩn bị mở `TAB-Ne-Sep.html?challenge=seed_a3` để test banner thách đấu (dùng `seed_a3` = Khánh Đụt, best 63.4s, 1 trong 6 seed players có sẵn). Cần làm khi mở lại:
   - Mở link đó, xác nhận banner hiện đúng "⚔️ Khánh Đụt vừa đạt 63.4s — thử vượt qua chưa?"
   - Chơi 1 ván, xác nhận nút thách đấu xuất hiện trong modal kết quả, bấm thử xem có copy link đúng không.
   - Test streak: cần chạy schema trước, rồi có thể tự sửa `last_visit` qua SQL Editor (lùi ngày lại 1-2-10 ngày) để test cả 3 nhánh mà không cần chờ thật qua nhiều ngày — cách làm y hệt gợi ý trong plan file.

3. **Multiplayer room "1 Sếp chung" vẫn đang ở giai đoạn 1/4** (từ 2 phiên trước, chưa động vào lại phiên này) — hạ tầng phòng (tạo/vào/màn chờ) đã code nhưng chưa test được (cùng lý do: bảng `rooms` chưa tồn tại, phụ thuộc cùng 1 lần chạy schema ở mục 1). Phần "1 Sếp chung" thật (hệ tọa độ chung, target-selection luân phiên) hoàn toàn chưa bắt đầu — xem chi tiết thiết kế trong plan file cũ nếu cần tiếp tục (lưu ý: file plan đã bị **ghi đè** bởi plan retention phiên này — nội dung thiết kế room chi tiết gốc không còn trong plan file, chỉ còn tóm tắt ngắn ở đây và trong các commit message `ac1920f`/`0bbaec9` trên GitHub. Nếu cần thiết kế lại room, đọc lại diff của 2 commit đó).

4. **Chưa đo được retention thật** — đây là gợi ý cuối cùng của persona: sau khi có streak/challenge chạy 1 thời gian, nên đo % người chơi quay lại lần 2 (query `sessions` theo `player_id` group, đếm số ngày khác nhau mỗi người chơi) để biết retention loop có hiệu quả không, trước khi đầu tư tiếp vào room.

5. **Chưa đồng bộ Việc A/B sang bản radar** (`TAB-Ne-Sep_v1-radar.html`).

## Quyết định/ràng buộc quan trọng cần nhớ

- **Luôn hỏi xác nhận trước khi `git push`** — trừ khi user rõ ràng trao quyền tự quyết trong 1 phiên cụ thể (đã xảy ra 1 lần ở phiên trước "tôi trao toàn quyền bạn quyết định"), đó không phải quy tắc lâu dài.
- **Streak dùng giờ Việt Nam cố định (UTC+7)**, không dùng giờ máy khách — quyết định đã chốt với user, lý do: game 100% tiếng Việt/target VN, nhất quán quan trọng hơn tiện lợi code.
- **Chỉ chọn 1 cơ chế retention cốt lõi (streak), không feature-dump** thêm season pass/achievement/daily quest cùng lúc — áp dụng đúng nguyên tắc `@roast-roadmap` của skill personatwin: chọn tính năng giải quyết trực tiếp root cause, bỏ ý tưởng trang trí.
- **Thách đấu bạn bè KHÔNG phải multiplayer room** — cố ý làm phiên bản rẻ/không-realtime để giải quyết đúng insight "thi đấu người quen" mà không cần chờ room hoàn thiện. Đừng nhầm lẫn 2 tính năng này khi tiếp tục.
- Mọi thay đổi Supabase (Broadcast/Presence/Postgres Changes/cột mới) đều theo nguyên tắc: code luôn fail gracefully (try/catch, không crash UI) nếu bảng/cột chưa tồn tại trên Supabase thật — vì thường code được viết trước khi user chạy schema.

## File liên quan

```
game/TAB-Ne-Sep.html            — bản chính, có: bug fix + icon + mobile + room "1 Sếp chung" HOÀN CHỈNH + streak + challenge-link + rotate-mobile
game/TAB-Ne-Sep_v1-radar.html   — bản radar, CHỈ có: bug fix + icon + mobile (chưa có room, streak, challenge — vẫn lạc hậu so với bản chính)
supabase/schema.sql             — có bảng "rooms" + 2 cột streak, TRẠNG THÁI CHẠY THẬT TRÊN SUPABASE CHƯA XÁC NHẬN LẠI trong phiên này (phiên trước báo đã chạy xong thành công qua verify API, giả định vẫn còn hiệu lực)
docs/GAME_SPEC.md               — đặc tả gốc, CHƯA cập nhật để phản ánh streak/challenge/room "1 Sếp chung" (nợ tài liệu tồn đọng nhiều phiên)
vercel.json                     — root "/" redirect sang "/play", rewrite "/play" → "/game/TAB-Ne-Sep.html" (đổi trong phiên URL cleanup, xem commit 9934caf)
Domain public chuẩn: https://tab-ne-sep.vercel.app/play (KHÔNG dùng dạng /game/TAB-Ne-Sep.html khi đưa link cho user nữa, dù route đó vẫn hoạt động)
C:\Users\Huan\.claude\plans\jolly-humming-dahl.md — plan thiết kế "1 Sếp chung" ĐÃ DÙNG XONG và đã triển khai đầy đủ trong phiên này (thay thế plan goofy-imagining-hellman cũ đã lỗi thời hoàn toàn về phần room)
```

## Việc cần làm tiếp khi mở lại phiên mới

1. Hỏi user: đã chạy lại `schema.sql` chưa (nếu chưa chắc — phiên trước báo đã verify qua API thành công, nhưng nên hỏi lại cho chắc nếu có dấu hiệu lỗi Supabase).
2. **Test Việc B (thách đấu bạn bè, KHÔNG phải room)**: mở `https://tab-ne-sep.vercel.app/play?challenge=seed_a3`, xác nhận banner + nút thách đấu hoạt động — CHƯA test trong các phiên gần đây, vẫn treo từ lâu.
3. Test Việc A (streak): dùng SQL Editor tự chỉnh `last_visit` để giả lập các mốc ngày, xác nhận cảnh báo giữ chuỗi + mốc thưởng hiện đúng — cũng CHƯA test.
4. Room "1 Sếp chung" đã hoàn chỉnh và test 2-người/2-trình-duyệt thành công — nếu tiếp tục, việc còn thiếu là: test phòng >2 người, test guest vào muộn giữa trận, đo độ lag thật với 2 thiết bị khác mạng (chưa làm — 2 tab cùng máy test trước đó độ trễ gần 0, không đại diện điều kiện mạng thật).
5. Sau khi Việc A/B/room đều ổn định → hỏi user có muốn đồng bộ sang bản radar không, và có muốn đo retention thật (query `sessions`) trước khi đầu tư thêm tính năng mới không.
6. `docs/GAME_SPEC.md` đã lạc hậu nhiều phiên (không phản ánh streak/challenge/room) — cân nhắc cập nhật nếu cần tài liệu tham chiếu đầy đủ, không urgent nếu chỉ tiếp tục code.
