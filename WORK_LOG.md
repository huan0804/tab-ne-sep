# Nhật ký làm việc — TAB: Né Sếp

> File này ghi lại trạng thái dự án để tiếp tục ở phiên làm việc sau. Cập nhật mỗi khi có tiến triển lớn, dọn bớt phần đã lỗi thời để tránh phình to.

## Trạng thái hiện tại (2026-09-19)

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

### ⏳ PENDING — cần làm tiếp khi mở lại phiên

1. **Nghi vấn lag ở guest khi test nhiều tab/cửa sổ trên CÙNG 1 máy** — đã thêm interpolation (nội suy vị trí Sếp phía guest, code đã giữ lại) nhưng vẫn thấy giật khi test bằng nhiều cửa sổ trình duyệt trên 1 máy, kể cả khi đặt cạnh nhau. Nghi ngờ chính: đây là do Chrome throttle timer/rAF của cửa sổ không giữ OS focus (hiện tượng này KHÔNG xảy ra ở ứng dụng native như LMHT vì nó không chạy trong tab trình duyệt) — chưa xác nhận 100%, còn 2 dòng debug log tạm thời trong code (`[debug boss_state gaps]` ở dòng ~1258, `[debug tick gaps]` ở dòng ~2399) để đo. **User sẽ test lại bằng thiết bị thật riêng biệt** (điện thoại + máy tính, hoặc nhiều máy khác nhau — không phải nhiều tab/cửa sổ trên 1 máy) để có phép thử phản ánh đúng trải nghiệm người chơi thật. Xoá 2 đoạn debug log sau khi xác nhận xong.
2. Test phòng ≥4 người (đã test tới 3, chưa test nhiều hơn).
3. Test guest vào muộn giữa trận (code có fallback về solo, chưa xác nhận qua browser thật).
4. `docs/GAME_SPEC.md` đã lạc hậu nhiều phiên (không phản ánh streak/challenge/room) — không urgent, chỉ cập nhật nếu cần tài liệu tham chiếu đầy đủ.

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
