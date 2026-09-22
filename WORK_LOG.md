# Nhật ký làm việc — TAB: Né Sếp

> File này ghi lại trạng thái dự án để tiếp tục ở phiên làm việc sau. Cập nhật mỗi khi có tiến triển lớn, dọn bớt phần đã lỗi thời để tránh phình to.

## Trạng thái hiện tại (2026-09-22)

**Đã push lên GitHub (2 commit): thuật toán rải bàn phòng đông người (`c7a9739`) + sửa database scalability (`289e410`).**

**Đang giữa vòng sửa mobile UX (lag + tràn màn hình + bàn phím) — CHƯA COMMIT, CHƯA TEST.** Đã sửa xong trong working tree của `game/TAB-Ne-Sep.html`, chờ user test lại bằng điện thoại thật (hôm sau) rồi mới quyết commit/push hay sửa tiếp.

### ✅ Đã xong + push — Database scalability cho traffic tăng đột biến (commit `289e410`)

User yêu cầu đảm bảo game chịu được traffic tăng đột biến + đánh giá khả năng chèn quảng cáo. Rà lại toàn bộ cách client ghi vào Supabase, phát hiện 2 điểm nghẽn thật:

1. **Race condition ở 3 bảng analytics** (`analytics_access_hours`, `analytics_screen_time`, `analytics_heatmap`) — mỗi bảng chỉ có 1-2 dòng CỐ ĐỊNH mà MỌI người chơi cùng ghi đè. Code cũ: client SELECT giá trị hiện tại → cộng ở JS → UPDATE giá trị mới. Nhiều người ghi gần đồng thời → người ghi sau đè mất phần cộng của người ghi trước, mất dữ liệu âm thầm không báo lỗi — càng đông người chơi cùng lúc càng mất nhiều. Đã sửa: 3 RPC function Postgres (`increment_access_hour`, `increment_screen_time`, `increment_heatmap`, khai báo `security definer` trong `supabase/schema.sql` mục 2d) làm phép cộng NGAY trong 1 câu `UPDATE` — Postgres tự khoá row, atomic thật sự. Xoá luôn quyền UPDATE trực tiếp public trên 3 bảng này (client giờ chỉ SELECT + gọi RPC).
2. **`getPlayerRank()` dùng `count:'exact'` cho tổng số người chơi** — quét toàn bảng, chậm dần khi `players` phình to theo traffic. Đổi sang `count:'estimated'` cho phần này (chỉ cần hiển thị gần đúng); giữ `exact` cho phần quyết định thứ hạng thật vì có điều kiện khớp index `players_avg_score_idx` nên vẫn nhanh.

**⚠️ CẦN LÀM THỦ CÔNG TRƯỚC KHI RPC HOẠT ĐỘNG TRÊN PRODUCTION**: chạy lại `supabase/schema.sql` trên Supabase SQL Editor thật — nếu không chạy, code gọi `sb.rpc('increment_access_hour', ...)` sẽ lỗi vì function chưa tồn tại trên DB (analytics sẽ ngừng ghi nhưng không crash UI, vì có try/catch best-effort).

**Chưa sửa, cần user quyết định (không phải bug, là chi phí thật):** đang dùng **Supabase Free tier** — giới hạn cứng connection đồng thời, bandwidth 5GB/tháng, DB size 500MB, tự pause sau 7 ngày không traffic. Game có sẵn tính năng chia sẻ mạng xã hội nên traffic viral tăng đột biến là rủi ro thật. Nếu traffic tăng thật, cần nâng **Pro tier** ($25/tháng).

**Quảng cáo — đánh giá, chưa làm gì:** hiện chưa có tích hợp ad network nào (không AdSense, không SDK). Kiến trúc 1-file-HTML + Vercel thuận lợi để chèn — có sẵn điểm chuyển màn hình tự nhiên (`#introScreen`, `#modal` kết quả ván, `#lbModal` bảng xếp hạng) phù hợp cho interstitial/banner kiểu game casual. Cần thiết kế riêng (chọn network, luồng UX, đo hiệu quả) khi user muốn triển khai thật.

### ⏳ PENDING ƯU TIÊN NHẤT — test lại trên điện thoại thật, báo kết quả theo từng mục

Bối cảnh: user test bằng thiết bị thật riêng biệt (điện thoại làm guest, máy tính làm host) → xác nhận giật thật (không phải do throttle đa-tab như nghi vấn cũ), đồng thời phát hiện thêm 2 bug UI mới qua ảnh chụp thực tế: (1) bàn phím ảo lệch trục dọc trong khi trang bị CSS ép xoay ngang lúc nhập tên, (2) `#monitor` (màn hình giả lập) tràn gần hết bề ngang màn hình lúc đang chơi ở portrait.

Đã sửa (chưa verify bằng thiết bị thật):
1. `will-change:transform` cho `#bossUnit`/`#stage` + bỏ `calc()` khỏi transform mỗi frame của boss (dòng ~2270) — nhắm vào chi phí render/composite trên mobile yếu.
2. **Bỏ hẳn CSS ép `rotate(90deg)`** ở portrait (từng ở khối `@media (max-width:600px) and (orientation:portrait)`) — portrait giờ hiển thị dọc thật, không giả lập ngang nữa. Thay bằng banner gợi ý `#rotateHint` ("🔄 Xoay ngang máy để chơi mượt hơn"), có nút đóng, tự nhớ lựa chọn qua `localStorage` (dùng lại helper `hasSeenHint`/`markHintSeen` có sẵn), không ép buộc.
3. `vh`/`vw` → `dvh`/`dvw` ở toàn bộ modal/card (`#monitor`, `#modalCard`, `#introCard`, `#lbCard`, `#roomWaitCard`) — tránh lệch kích thước khi thanh địa chỉ Chrome Android ẩn/hiện.
4. `#monitor` đổi từ đo theo `dvw`/`dvh` (viewport toàn trang) sang `cqw`/`cqh` (CSS container query units, container = `#scene`, khai báo `container-type:size` ở `#scene` dòng ~43) — sửa đúng gốc bug tràn màn hình: trước đó size monitor tính theo cả trang bao gồm cả phần `#hud`+`#controls` không thuộc scene, nên luôn thổi phồng so với chỗ trống thật.

**Checklist test lại (điện thoại thật, KHÔNG phải nhiều tab 1 máy):**
- [ ] **Lag**: chơi vài phút ở cả 2 vai (host và guest trên điện thoại) — còn giật/khựng không so với trước.
- [ ] **Tràn màn hình**: vào màn đang chơi (portrait, không xoay máy) — `#monitor` còn chiếm quá nhiều diện tích, che vòng tròn/Sếp như ảnh cũ không.
- [ ] **Bàn phím**: màn hình nhập tên (`#nameInput`) — bàn phím ảo hiện đúng chiều, không lệch trục nữa không.
- [ ] **Banner gợi ý xoay**: portrait có hiện banner không; bấm ✕ đóng, F5 lại — banner phải KHÔNG tự hiện lại (đã lưu lựa chọn).
- [ ] **Landscape cũ**: xoay ngang máy thật — game vẫn như trước, không đổi gì ở landscape.
- [ ] Nếu còn chỗ nào rối/chật trên portrait — chụp ảnh cụ thể + mô tả đang ở bước nào (intro/đang chơi/phòng chờ).

Sau khi user xác nhận kết quả từng mục trên mới quyết định: commit + xoá 2 dòng debug log cũ (`[debug boss_state gaps]` ~dòng 1258, `[debug tick gaps]` ~dòng 2399, xem mục dưới), hay cần sửa tiếp.

### ✅ Đã xong bằng mô phỏng số học (KHÔNG cần điện thoại) — sửa thuật toán rải bàn phòng đông người

Phát hiện qua mô phỏng offline (không phải test tay): thuật toán rải bàn cũ (`generateDeskLayout`, random rejection-sampling) có tỷ lệ chồng lấn tăng nhanh theo số người — 0% ở N=4, nhưng 33% số ván có ít nhất 1 cặp chồng bàn ở N=6, 99%+ ở N=8. Đây lẽ ra sẽ là bug thật nếu test tay phòng đông mà không sửa trước.

Đã sửa:
- **`generateDeskLayout`** đổi từ random rejection-sampling sang **xếp đều trên vành tròn** (góc = i×2π/n + jitter nhỏ), bán kính vành tính động theo N với biên bù jitter — đảm bảo khoảng cách tối thiểu giữa MỌI cặp người bằng hình học, không phải may rủi. Đã verify bằng mô phỏng 5000 lần/N: N=2-6 đạt 0% lỗi, N=7 đã lên 29.56% lỗi (đúng dự đoán, xác nhận giới hạn hình học thật của field 3m/bán kính 1.4m).
- Thêm **`CONFIG.roomMaxPlayers: 6`** — trần cứng, chặn ở `joinRoomChannel()` (dòng ~1264): kiểm tra `presenceState()` NGAY TRƯỚC khi tự track presence, nếu phòng đã đủ 6 người thì từ chối join (rời channel, `joinExistingRoom` hiện `alert` báo phòng đầy). Chỉ chặn người join SAU khi đã đủ 6, không ảnh hưởng người đã ở trong phòng.
- `joinRoomChannel()` giờ trả về `Promise<boolean>` (trước đó không trả gì) — `true` = vào thành công, `false` = bị từ chối vì đầy phòng.

**Việc này CHƯA cần test bằng điện thoại thật** — logic core đã verify bằng mô phỏng số học độc lập với thiết bị. Vẫn nên test tay 1 lần cho chắc (mở nhiều tab trình duyệt cùng join 1 link phòng, thử tới người thứ 7 xem có bị chặn đúng như kỳ vọng), nhưng không nằm trong nhóm phụ thuộc "test điện thoại thật" ở trên — có thể làm bất cứ lúc nào kể cả trên máy tính.

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
