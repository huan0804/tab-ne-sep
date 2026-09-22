# Nhật ký làm việc — TAB: Né Sếp

> File này ghi lại trạng thái dự án để tiếp tục ở phiên làm việc sau. Cập nhật mỗi khi có tiến triển lớn, dọn bớt phần đã lỗi thời để tránh phình to.

## Trạng thái hiện tại (2026-09-22)

**Đã push lên GitHub, tất cả trên production tại `https://tab-ne-sep.vercel.app/play`:**

1. **Rải bàn phòng đông người** — xếp đều vành tròn + bù jitter (verify bằng mô phỏng 5000 lần/N: N=2-6 đạt 0% chồng lấn), trần cứng `roomMaxPlayers: 6` chặn ở `joinRoomChannel()`.
2. **Database scalability** — 3 RPC `increment_*` nguyên tử thay pattern select-rồi-update cũ (từng có race condition mất dữ liệu khi đông người ghi cùng lúc), tối ưu `getPlayerRank()` dùng `count:'estimated'` cho phần không cần chính xác tuyệt đối. **Đã chạy `schema.sql` trên Supabase production, verify xong** (`select proname from pg_proc where proname like 'increment_%'` → đúng 3 dòng).
3. **Analytics theo ngày/tuần** — thêm 3 bảng mới (`analytics_access_hours_daily`, `analytics_screen_time_daily`, `analytics_heatmap_weekly`) song song 3 bảng cộng-dồn all-time cũ (giữ nguyên, không xoá). Khoá theo giờ VN cố định (UTC+7), tính sẵn ở client bằng `vnDateKeyPadded()`/`vnWeekKey()`. **⚠️ CẦN CHẠY LẠI `supabase/schema.sql` TRÊN SUPABASE** để 3 bảng + 3 RPC mới này hoạt động — chưa làm, y hệt bước đã làm cho RPC cũ trước đó.
4. **Mobile UX** — bỏ ép xoay ngang CSS (portrait hiển thị dọc thật), sửa `#monitor` tràn màn hình (đổi `dvw/dvh` → `cqw/cqh` container query), tối ưu render (`will-change`, bỏ `calc()` khỏi hot path), nút "Dừng ván" luôn hiện chữ ở mọi kích thước màn hình, bỏ hẳn banner gợi ý xoay ngang (test thật: nghiêng máy thật vẫn không xoay được trên 1 số cấu hình Android, banner vô dụng).
5. **Ad slot trung lập** trong modal kết quả ván (`#adSlot`, hàm `renderAdSlot(html)`) — chưa gắn network nào, sẵn sàng khi chọn AdSense/brand deal.

**Đã xác nhận qua test thật trên điện thoại**: không còn tràn màn hình, nút Dừng rõ ràng, banner xoay ngang đã gỡ. **Chưa xác nhận**: lag khi chơi thật (vòng test trước có cải thiện nhưng chưa test lại sau các thay đổi mới nhất), bàn phím ở màn nhập tên.

**Việc dở, chưa hoàn thành**:
- Tích hợp Facebook Share Dialog (menu Messenger/WhatsApp/Nhóm...) — cần Facebook App ID, user bị lỗi xác minh số điện thoại đã gắn tài khoản Facebook chính, quyết định **bỏ qua**, giữ nguyên `sharer.php` hiện tại (vẫn hoạt động bình thường).
- 2 dòng debug log cũ vẫn còn trong code (`[debug boss_state gaps]` ~dòng 1258, `[debug tick gaps]` ~dòng 2399) — chưa xoá, chờ xác nhận hết lag mới xoá.

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
game/TAB-Ne-Sep.html            — bản chính, có đầy đủ: bug fix + icon + mobile + room "1 Sếp chung" hoàn chỉnh + streak + challenge-link + rotate-mobile
game/TAB-Ne-Sep_v1-radar.html   — bản radar, CHỈ có bug fix + icon + mobile, lạc hậu so với bản chính
supabase/schema.sql             — có bảng "rooms" + 2 cột streak, đã verify chạy thành công trên Supabase thật (phiên trước)
vercel.json                     — root "/" redirect → "/play", rewrite "/play" → "/game/TAB-Ne-Sep.html"
```
