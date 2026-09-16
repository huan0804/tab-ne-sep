# Nhật ký làm việc — TAB: Né Sếp

> File này ghi lại trạng thái dự án để tiếp tục ở phiên làm việc sau. Cập nhật mỗi khi có tiến triển lớn.

## Trạng thái hiện tại (2026-09-16, phiên tối)

Migration Supabase + Vercel đã ổn định từ phiên trước. Phiên này tập trung vào 4 hạng mục người dùng yêu cầu: sửa 1 bug, đổi icon chia sẻ, tối ưu mobile, và bắt đầu xây multiplayer room ("1 Sếp chung"). Có plan chi tiết đã lưu tại `C:\Users\Huan\.claude\plans\goofy-imagining-hellman.md` (máy Windows của user) — đọc file đó để có toàn bộ thiết kế kỹ thuật nếu cần tiếp tục Việc 2.

### Việc ĐÃ XONG và đã push lên GitHub (commit `0bbaec9`)

1. **Bug bắt-khi-đổi-mode (Việc 0)** — nếu Sếp đã đứng trong catchRadius (≤1m) từ trước, và người chơi CHỦ ĐỘNG bấm Tab đổi sang "personal" ngay lúc đó, trước đây KHÔNG bị bắt (do cơ chế `wasClose` chỉ bắt cạnh-lên). Đã sửa: tách hàm `catchPlayer()` khỏi `tick()`, gọi nó cả trong `toggleMode()` dựa vào biến `bossDist` module-level. User đã tự test và xác nhận fix đúng. Áp dụng cả 2 file (`TAB-Ne-Sep.html` + `TAB-Ne-Sep_v1-radar.html`).

2. **Logo Facebook/Zalo thật (Việc 1)** — thay emoji 📘💬 bằng SVG brand mark inline (không load ảnh ngoài). Nút IG/TikTok đổi label từ "IG/TikTok" thành "Sao chép liên kết" (đúng bản chất hành động, giữ nguyên icon 🔗) theo yêu cầu user. Sửa thêm CSS `.shareBtn .lbl{min-height:2.5em}` để icon 4 nút thẳng hàng dù label 1 dòng hay 2 dòng (user phát hiện bug lệch icon, đã fix và xác nhận OK).

3. **Tối ưu mobile (Việc 3)** — thêm breakpoint `@media (max-width:480px)`: thu nhỏ HUD, ẩn `.mouse`/`.succulent` (dễ tràn ra ngoài ở màn hẹp), nút Tab tăng lên 44px + màu đỏ nổi bật + pulse animation + coachmark chỉ-1-lần lúc bắt đầu ván đầu (mobile không có phím Tab vật lý). **Quan trọng — user tự phát hiện thêm 1 vấn đề ngoài dự tính:** khung `#monitor` có sàn cứng `clamp(320px, ...)` chiếm gần hết màn hình mobile, che khuất vòng tròn khoảng cách (khó biết Sếp đang tới/đi). Đã hạ sàn xuống `clamp(200px, 48vw, 660px)` chỉ trong breakpoint mobile — user xác nhận OK sau khi sửa.

### Việc ĐANG LÀM — Multiplayer room "1 Sếp chung" (Việc 2, đã push commit `ac1920f`)

Đây là hạng mục lớn nhất, đã xác nhận với user qua nhiều câu hỏi rằng đây là bản đầy đủ nhất (không phải bản rút gọn):
- Host **vừa tự chơi vừa chạy boss AI**, không phải máy chủ ẩn đứng ngoài.
- Sếp phải **luân phiên/nhắm người gần nhất** trong phòng, không chỉ nhắm 1 người.
- Nhiều người chơi cần **1 hệ tọa độ chung**, mỗi người có "vị trí bàn" **tự động xếp vòng tròn quanh 1 tâm** theo thứ tự vào phòng.
- Có **màn hình chờ**, host bấm "Bắt đầu" cho cả phòng cùng lúc (không phải "vào là chơi ngay").

**Đã xong (giai đoạn 1/4 theo plan — chỉ hạ tầng phòng, CHƯA đụng boss AI thật):**
- Bảng `rooms` mới trong `supabase/schema.sql` (id/host_player_id/status waiting|playing, bật Realtime qua publication).
- Proof-of-concept riêng (2 tab, file tạm đã xóa sau khi xác nhận) — **đã xác nhận Supabase Realtime Broadcast hoạt động đúng, đủ mượt** cho việc phát vị trí Sếp real-time.
- UI: nút "👥 Chơi cùng bạn (tạo phòng)" ở intro, màn hình chờ mới (`#roomWaitScreen`) hiện room code, nút copy link, danh sách người chơi live qua Supabase Presence, nút "Bắt Đầu" chỉ host thấy.
- Logic JS: `createRoom()`, `joinExistingRoom()` (đọc `?room=` trên URL), `joinRoomChannel()` (Presence + subscribe `postgres_changes` trên `rooms.status`), `startRoomMatchForEveryone()` (mọi client đồng loạt chuyển từ chờ sang chơi khi host bấm bắt đầu).
- Đã tự rà soát và sửa 2 bug logic trước khi push: (a) `createRoom()` quên gọi `joinRoomChannel()` khiến host không join channel của chính mình; (b) `startRoomMatchForEveryone()` có race condition nếu `state` chưa được tạo bởi `resetState()` (chạy cuối file) — đã thêm guard `setTimeout` retry.
- **Chỉ áp dụng cho `TAB-Ne-Sep.html` (bản elip)** — bản radar CHƯA có room UI này, theo đúng plan (làm 1 bản ổn định trước khi đồng bộ sang bản radar).

**CHƯA XONG — cần làm tiếp theo (giai đoạn 2-4/4):**

1. **CHẶN ĐẦU TIÊN — User cần tự chạy lại `supabase/schema.sql` đã cập nhật** trong Supabase SQL Editor để tạo bảng `rooms`. Đã verify qua API: bảng `rooms` **chưa tồn tại** trên Supabase (lỗi "Could not find the table 'public.rooms'"). Toàn bộ tính năng phòng sẽ không hoạt động (không lỗi crash, chỉ im lặng fail) cho tới khi bảng này được tạo.

2. **Chưa test end-to-end** — vì thiếu bảng ở mục 1, chưa thể mở 2 tab thật để xác nhận: tạo phòng → copy link → tab khác vào bằng link → thấy tên nhau trong danh sách chờ → host bấm bắt đầu → cả 2 tab đồng loạt vào game.

3. **"1 Sếp chung" thật CHƯA làm** (đây là phần lớn/khó nhất, giai đoạn 2/4 theo plan) — hiện tại dù vào phòng và bấm "Bắt đầu", boss AI vẫn chạy solo 100% như cũ (mỗi người tự tính Sếp riêng theo gốc tọa độ của chính họ) — **phòng mới chỉ đồng bộ được "cùng lúc bắt đầu", chưa đồng bộ được "cùng nhìn thấy 1 Sếp"**. Việc cần làm tiếp:
   - Hệ tọa độ chung: gán `deskPos` cố định cho mỗi người theo vòng tròn quanh tâm phòng, dựa theo thứ tự vào (đếm qua Presence).
   - Mỗi client broadcast trạng thái của mình (`{playerId, deskPos, mode}`) mỗi ~200-300ms — không chỉ 1 chiều Host→Client như hiện tại.
   - Host tính boss AI dựa trên danh sách người chơi thật (ambient wander quanh tâm phòng; forced approach chọn người "personal" gần nhất hoặc ngẫu nhiên nếu ai cũng "work") — cần viết lại state machine `pickAmbientTarget`/`forceCloseApproach` để nhận tham số danh sách người chơi.
   - Host broadcast vị trí Sếp ~20 lần/giây qua `channel.send({type:'broadcast', event:'boss_pos',...})` — đã xác nhận cơ chế này hoạt động qua POC.
   - Client (không phải host) nhận vị trí Sếp, tự tính `dist(deskPos, boss)`, chạy toàn bộ logic bắt/né/điểm dựa trên dist đó — không tự chạy boss AI.
   - Vẽ silhouette người chơi khác trong scene tại đúng góc `deskPos` tương đối.
   - Xử lý host rời phòng (Presence tự báo disconnect) — dừng game, báo "Chủ phòng đã rời".

4. **Đồng bộ bản radar (`TAB-Ne-Sep_v1-radar.html`) sang có room UI** — chưa làm, đợi bản elip ổn định trước (theo plan, giảm rủi ro).

5. **Đã dặn user (nhắc lại nếu quên):** RLS của bảng `rooms` cho phép ai cũng đọc/ghi (giống các bảng khác) — chấp nhận được vì không có dữ liệu nhạy cảm, nhất quán với thiết kế cũ.

## Quyết định/ràng buộc quan trọng cần nhớ

- **Luôn hỏi xác nhận trước khi `git push`** (trừ khi user rõ ràng trao quyền tự quyết trong 1 phiên cụ thể như tối nay — không phải quy tắc lâu dài, quy tắc mặc định vẫn là hỏi trước).
- **Chọn Supabase Realtime (Broadcast + Presence + Postgres Changes)** cho multiplayer, không thêm backend riêng — giữ đúng triết lý "1 file HTML độc lập" của dự án. Broadcast cho vị trí Sếp tần suất cao (không ghi DB liên tục), Postgres Changes cho sự kiện hiếm/quan trọng (bắt đầu ván), Presence cho danh sách người online (không cần persist).
- **"1 Sếp chung" là quyết định đã chốt với user qua nhiều câu hỏi rõ ràng** — không phải giả định của Claude: host vừa chơi vừa chạy AI, Sếp luân phiên nhắm người gần nhất, nhiều bàn xếp vòng tròn tự động, có màn chờ trước khi bắt đầu. Nếu tiếp tục làm giai đoạn 2-4, bám đúng các quyết định này, không tự đổi sang phương án đơn giản hơn mà chưa hỏi lại.
- **File test POC không commit vào git** — mọi thử nghiệm kỹ thuật nhanh nên tạo file tạm (`_` tiền tố) và xóa sau khi xác nhận, không để lẫn vào code chính thức.

## File liên quan

```
game/TAB-Ne-Sep.html            — bản chính, có room infra (giai đoạn 1/4), CHƯA có "1 Sếp chung" thật
game/TAB-Ne-Sep_v1-radar.html   — bản radar, CHƯA có room UI, vẫn dùng Supabase leaderboard bình thường
supabase/schema.sql             — có bảng "rooms" mới, CHƯA được user chạy lại trên Supabase thật
docs/GAME_SPEC.md               — đặc tả gốc (chưa cập nhật để phản ánh room feature — cần làm khi Việc 2 hoàn thiện)
C:\Users\Huan\.claude\plans\goofy-imagining-hellman.md — plan chi tiết đầy đủ cho 4 việc, đọc lại nếu cần thiết kế kỹ thuật
```

## Việc cần làm tiếp khi mở lại phiên mới

1. Hỏi user: đã chạy lại `schema.sql` (bản có bảng `rooms`) trong Supabase chưa? Nếu chưa, hướng dẫn chạy (giống các lần trước — copy toàn bộ file vào SQL Editor, Run).
2. Nếu rồi → mở `game/TAB-Ne-Sep.html`, test end-to-end 2 tab: tạo phòng, copy link, tab khác vào, xác nhận danh sách người chơi hiện đúng, host bấm bắt đầu, cả 2 chuyển màn đồng thời.
3. Nếu hạ tầng phòng chạy đúng → bắt đầu giai đoạn 2/4: hệ tọa độ chung + target-selection luân phiên (phần lớn và khó nhất còn lại, xem chi tiết thiết kế trong plan file).
4. Sau khi "1 Sếp chung" hoạt động ổn trên bản elip → hỏi user có muốn đồng bộ sang bản radar không.
5. Nhắc user cập nhật `docs/GAME_SPEC.md` để phản ánh tính năng phòng mới, nếu muốn giữ tài liệu đồng bộ với code.
