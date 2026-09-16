# Nhật ký làm việc — TAB: Né Sếp

> File này ghi lại trạng thái dự án để tiếp tục ở phiên làm việc sau. Cập nhật mỗi khi có tiến triển lớn.

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
game/TAB-Ne-Sep.html            — bản chính, có: bug fix + icon + mobile + room-infra(1/4) + streak + challenge-link
game/TAB-Ne-Sep_v1-radar.html   — bản radar, CHỈ có: bug fix + icon + mobile (chưa có room, streak, challenge)
supabase/schema.sql             — có bảng "rooms" + 2 cột streak, CHƯA được user chạy lại lần này
docs/GAME_SPEC.md               — đặc tả gốc, CHƯA cập nhật để phản ánh streak/challenge/room
C:\Users\Huan\.claude\plans\goofy-imagining-hellman.md — plan HIỆN TẠI là plan retention (Việc A/B), plan room chi tiết gốc đã bị ghi đè, xem commit ac1920f/0bbaec9 trên GitHub nếu cần
```

## Việc cần làm tiếp khi mở lại phiên mới

1. Hỏi user: đã chạy lại `schema.sql` (có cả bảng `rooms` VÀ 2 cột streak) chưa?
2. Nếu rồi → test Việc B trước (nhanh, ít rủi ro): mở `TAB-Ne-Sep.html?challenge=seed_a3`, xác nhận banner + nút thách đấu hoạt động.
3. Test Việc A (streak): dùng SQL Editor tự chỉnh `last_visit` của chính playerId mình để giả lập các mốc ngày, xác nhận cảnh báo giữ chuỗi + mốc thưởng hiện đúng.
4. Sau khi cả 2 chạy ổn → hỏi user có muốn đồng bộ sang bản radar không, và có muốn đo retention thật (query `sessions`) trước khi tiếp tục multiplayer room không.
5. Nếu user muốn tiếp tục multiplayer room — cảnh báo trước: phần thiết kế "1 Sếp chung" chi tiết (hệ tọa độ chung, target-selection) không còn trong plan file hiện tại, cần đọc lại commit `ac1920f` để khôi phục context hoặc hỏi lại user để thiết kế mới.
