# TAB: Né Sếp — Đặc tả game đầy đủ (v cuối cùng trong phiên làm việc)

> **Trạng thái tài liệu (cập nhật 2026-10-25):** phần luật chơi, AI Sếp, nội dung màn hình và UX bên dưới là đặc tả gốc; các con số đã được đối chiếu với `CONFIG` của bản chính `game/TAB-Ne-Sep_v2-perspective.html`. Phần lưu trữ/bảng xếp hạng/analytics (§8, §10) và nền tảng (§1, §12, §13) đã chuyển từ Claude Artifact `db` sang **Supabase** — xem các mục đó và `supabase/schema.sql`. Mã nguồn chính xác là các file trong `game/`. Tính năng sau đặc tả gốc (phòng nhóm, streak, thách đấu, tutorial ép hành động, ảnh Sếp tự chọn, xoay ngang trên điện thoại) được ghi ở §14.

---

## 1. Tổng quan

- **Tên:** TAB: Né Sếp
- **Định dạng:** 1 file HTML độc lập (CSS/JS inline; phụ thuộc ngoài chỉ có Google Fonts và supabase-js qua CDN), deploy trên Vercel (`https://tab-ne-sep.vercel.app/play`).
- **Thể loại:** Mini-game hài hước, mô phỏng "lén xem phim trong giờ làm, né sếp kiểm tra". Tối đa hoá thời gian "xem phim" (personal) mà không bị sếp bắt gặp.
- **Ngôn ngữ giao diện:** Tiếng Việt 100%.
- **Backend:** Supabase (Postgres + Realtime) cho bảng xếp hạng nhiều người chơi, phòng nhóm và analytics ẩn danh. Mở file bằng `file://` thì các phần này lùi về solo + `localStorage`.

---

## 2. Luật chơi cốt lõi

1. Người chơi mặc định đang ở chế độ **"personal"** (xem phim/meme trên màn hình) — thời gian ở chế độ này được cộng dồn làm điểm thắng.
2. Một "Sếp" di chuyển liên tục quanh văn phòng (toạ độ 2D ẩn; ở bản chính Sếp được vẽ trực tiếp trong scene với 3 vòng khoảng cách 1m/2m/3m, ở bản v1 thì hiện qua radar).
3. Người chơi bấm phím **Tab** (hoặc nút "⇆ Đổi màn hình") để chuyển đổi màn hình giữa **work** (bảng tính/dashboard/chứng khoán) và **personal** (video/meme).
4. **Luật thua:** nếu khoảng cách Sếp–người chơi ≤ **1.0** (đơn vị "mét") mà đang ở chế độ personal → bị bắt, mất 1 trong 3 mạng (❤️❤️❤️). Có "rearm radius" = 1.8 (phải lùi ra >1.8 mới có thể bị bắt lại lần nữa, tránh trừ liên tục).
5. **Luật thắng:** tích luỹ đủ **30 giây** ở chế độ personal trong vòng **60 giây** thời lượng trận đấu, mà chưa hết 3 mạng. *(Đặc tả gốc là 60s/120s; đã rút còn một nửa vì 120s quá dài, `CONFIG.targetPersonalTime`/`matchDuration`.)*
6. **Thua vì hết giờ:** hết 60s mà chưa đạt 30s personal → thua kiểu "hết giờ".
7. **Điểm số (khác với thắng/thua):** "thời gian chơi đúng" = tổng thời gian mà (mode=work VÀ dist≤1m) HOẶC (mode=personal VÀ dist>1m). Đây là điểm dùng cho bảng xếp hạng (không phải thời lượng personal).

---

## 3. AI của "Sếp" (di chuyển ngẫu nhiên, không cố định)

- Toạ độ Sếp là 1 điểm 2D `(x,y)`, người chơi luôn ở gốc `(0,0)`.
- Sếp di chuyển liên tục theo waypoint ngẫu nhiên (không phải spawn/despawn rời rạc):
  - **Ambient wander** (đi lượn thường): chọn điểm đích ngẫu nhiên cách gốc 2.5–6.5 (hoặc 1.2–3.2 nếu trúng "near bias", xác suất 15%→28% tăng theo thời gian).
  - **Forced close approach** (bắt buộc áp sát thật): cứ sau mỗi 5–7 giây (đầu trận) → rút dần còn 1.4–2.4 giây (cuối trận), Sếp buộc phải đi tới 1 điểm cách gốc 0.15–0.85 (tức chắc chắn xuyên qua ngưỡng bắt 1m) — đây là nguồn đe doạ chính, không phụ thuộc may rủi ambient.
  - Tốc độ mỗi đoạn di chuyển ngẫu nhiên trong khoảng tăng dần theo độ khó (ramp trong 40 giây đầu ở bản chính; gốc là 80s): ambient 0.5–1.3 → 0.8–1.9 (đơn vị/giây); forced 0.6–2.0 → 1.2–3.4.
  - Khoảng cách tính theo elip: `dist = hypot(x, y * ellipseRatio)` với `ellipseRatio = 1.4`; điểm đích áp sát được chia lại cho `hypot(cos, sin·ellipseRatio)` để lần áp sát nào cũng thật sự vào trong 1m.
- **Radar 360° (chỉ bản v1)**: hiển thị góc trên bên phải, đường kính 168px, 3 vòng tròn đồng tâm, chấm đỏ = Sếp (đổi màu xanh lá/vàng/đỏ theo khoảng cách: >3m xanh, 1.5–3m vàng, ≤1.5m đỏ), có số mét hiển thị trực tiếp, quét radar xoay liên tục (tắt khi `prefers-reduced-motion`).
- **Mặt Sếp biểu cảm** (132px, gần bằng kích thước radar) với 3 trạng thái: `calm` (đang lượn xa, mắt chớp nhẹ, có cổ áo sơ mi xanh), `alert` (đang trong pha forced-approach, mắt nheo + giọt mồ hôi, rung nhẹ), `angry` (vừa bắt được, mặt đỏ, gân nổi, rung mạnh, có bong bóng thoại với 1 trong 9 câu mắng ngẫu nhiên tiếng Việt hài hước).

---

## 4. Nội dung màn hình (random mỗi ván, để tạo cảm giác mới mẻ)

### Màn hình "Work" — random 1 trong 3 kiểu, số liệu random mỗi ván:
1. **Excel**: bảng 5 dòng (Doanh thu/Chi phí/Lợi nhuận/Marketing...) + biểu đồ cột mini bên cạnh + tab sheet giả (T1–T4).
2. **Dashboard**: 4 thẻ KPI (2×2 grid) + biểu đồ đường xu hướng (SVG polyline) + biểu đồ donut (CSS `conic-gradient`) + biểu đồ cột mini theo khu vực.
3. **Stock**: mã chứng khoán ngẫu nhiên (VNM/FPT/HPG/MWG/VIC/VCB/MSN/GAS) + giá + %, biểu đồ đường giá + biểu đồ khối lượng giao dịch + bảng theo dõi 3 mã khác kèm màu xanh/đỏ.

### Màn hình "Personal" — random 1 trong 4 kiểu mỗi ván:
*(Đặc tả gốc dùng SVG nhân vật gốc để tránh bản quyền. Từ 2026-09 bản chính đổi sang nhân vật có tên thật như **Tom & Jerry**, **Pikachu** theo yêu cầu của chủ dự án, đã được cảnh báo và chấp nhận rủi ro DMCA. Danh sách đầy đủ các kiểu màn hình personal: xem hàm `buildPersonalHTML` trong `game/TAB-Ne-Sep_v2-perspective.html`.)*
- Các kiểu còn lại là meme hài tự vẽ, ví dụ mèo tổng giám đốc phê duyệt nghỉ ngơi; "Vẫn Ổn Thôi" khi sếp đi vòng vòng.
- Khung hiển thị dạng player video giả: thanh "🔴 LIVE", tiến trình thanh đỏ chạy, số lượt thích/bình luận ngẫu nhiên.

Cả 2 nội dung dùng chung 1 màn hình vật lý duy nhất (không phải 2-3 màn hình như bản đầu) — Tab chỉ đổi NỘI DUNG hiển thị trên cùng 1 monitor, đúng tinh thần Alt-Tab thật (chuyển cửa sổ, không chuyển màn hình vật lý).

---

## 5. Giao diện / Thiết kế hình ảnh

### Font (đã đổi từ bản đầu vì "nhìn ra AI"):
- Tiêu đề: **Baloo 2** (Google Fonts, trọng lượng 600/700/800) — tròn trịa, có hồn.
- Nội dung chung: **Be Vietnam Pro** (Google Fonts) — thiết kế riêng cho tiếng Việt, đọc tự nhiên.
- Số liệu/HUD/dữ liệu màn hình work: **JetBrains Mono** — tạo cảm giác "màn hình số" tương phản có chủ đích.
- Load qua `<link href="https://fonts.googleapis.com/css2?family=Baloo+2:wght@600;700;800&family=Be+Vietnam+Pro:ital,wght@0,400;0,500;0,600;0,700;1,500&family=JetBrains+Mono:wght@500;700&display=swap" rel="stylesheet">`.

### Bảng màu văn phòng (sáng sủa, VN hiện đại — theo ảnh tham khảo văn phòng SonHa Group):
- Tường/nền: trắng-xám nhạt gradient `#fbfcfd → #f2f4f6 → #dfe3e7 → #c7ccd2` (trên sáng, dưới sàn xám).
- Cột trụ: trắng-kem `linear-gradient(90deg,#e4e7ea,#ffffff,#e4e7ea)`.
- Đèn thả trần: trắng hiện đại (không còn vàng ấm như bản study-cafe cũ), quầng sáng trắng nhẹ.
- Cửa sổ ánh sáng ban ngày bên phải + cây xanh mờ ngoài trời.
- Tủ dưới bàn đồng nghiệp: vàng `--accent-yellow:#f2b705`; thân người/ghế: xanh lá `--accent-green:#8bc34a` (theo màu thương hiệu văn phòng tham khảo).
- Đồng nghiệp: silhouette với đầu da thịt thật (không phải bóng đen hoàn toàn), có tủ vàng dưới bàn.

### Bàn làm việc: **1 màn hình cong duy nhất trên tay đỡ (monitor arm)**, không còn 2 monitor + laptop như thiết kế gốc:
- Kích thước màn hình: `width: clamp(320px, 48vw, 660px); height: clamp(200px, 33vh, 420px)` — chiếm tỉ lệ lớn màn hình chơi (~1/4 diện tích) theo yêu cầu.
- Có tay đỡ đen (arm-pole, arm-joint, arm-horiz, arm-clamp), bàn phím cơ, chuột, ly cà phê, sổ tay, cây sen đá mini.

---

## 6. Flow trải nghiệm (Invisible Design / Frictionless UX — bản mới nhất)

**Nguyên tắc:** không bắt đọc luật dài trước khi chơi — dạy đúng lúc cần (just-in-time), nhớ vĩnh viễn qua localStorage để không lặp lại.

1. **Màn hình giới thiệu tối giản**: tiêu đề + 1 câu hook ngắn + ô nhập tên (**chỉ hỏi lần đầu tiên truy cập**, có sẵn) + nút "▶️ Bắt Đầu Chơi" to + nút phụ "❓ Xem cách chơi chi tiết" (collapse/expand, ẩn mặc định — 4 bước luật cũ nằm trong này, không ép đọc).
2. **Gợi ý tên hài hước** khi nhập lần đầu: 4 chip ngẫu nhiên trong kho `['Heo Mập Mập','Rắn 2 Đuôi','Gấu Trúc Lười','Cú Đêm Văn Phòng','Vịt Xàm Xí','Mèo Béo IT','Ninja Trốn Việc','Sói Cô Đơn KPI']`, bấm là điền thẳng vào ô.
3. **Coachmark tại chỗ (chỉ 1 lần duy nhất trong đời trình duyệt)**: lần đầu tiên Sếp thật sự bước vào pha "forced approach", tốc độ được cố tình làm chậm (dùng mức thấp nhất của dải tốc độ) + hiện bong bóng nhỏ cạnh nút Tab: "👀 Sếp lại gần! Bấm Tab ngay khi số dưới ra-đa ≤ 1m" — tự ẩn khi bấm Tab hoặc sau 5s. Lưu cờ `localStorage['atd_hintApproachSeen']='1'`, không bao giờ hiện lại.
4. **Mẹo sửa lỗi (Poka-Yoke) khi bị bắt lần đầu tiên trong đời**: thêm dòng "💡 Mẹo: bấm Tab NGAY khi số chạm 1m, đừng đợi số về 0", cờ `localStorage['atd_hintCatchSeen']`.
5. **Phản hồi tức thời ("juice")**: khi bị bắt — màn hình rung (CSS keyframes shake trên khung monitor), chữ "😱 BỊ BẮT RỒI!" bật to giữa màn hình, viền đỏ flash; khi né đẹp — chữ xanh ngẫu nhiên ("✓ Né đẹp!"/"✓ Sát nút!"/...). Nền văn phòng tối dần nhẹ (giảm `brightness` CSS filter) khi Sếp đến gần để dồn chú ý.
6. **Tôn trọng `prefers-reduced-motion`**: tắt hết animation xoay/rung/pulse, giữ lại phản hồi dạng chữ.

---

## 7. Kết thúc ván & Bảng xếp hạng

- Modal kết quả có: tiêu đề (thắng/thua/hết giờ), lý do, box thống kê (điểm ván này, trung bình của bạn), **top 5→(hạng+10) người chơi kèm highlight vị trí của bạn** (xem mục 8), 4 nút chia sẻ, nút "Chơi lại".
- **Edge case UX đã xử lý** (modal không ép buộc):
  - Nút ✕ đóng góc trên phải (cả modal kết quả lẫn bảng xếp hạng).
  - Click ra ngoài nền tối (backdrop click) cũng đóng được.
  - Phím **Esc** đóng modal đang mở.
  - Đóng modal KHÔNG tự chơi lại — game đứng yên ở trạng thái vừa kết thúc, xuất hiện **nút tròn nổi ▶️** góc dưới phải để chơi lại bất cứ lúc nào (không cần refresh trang).

---

## 8. Hệ thống điểm & bảng xếp hạng thật nhiều người chơi

### Model lưu trữ — Supabase (Postgres)
*(Đặc tả gốc dùng Claude Artifact `db` với 40 shard `players_shard/{0..39}`; đã thay hoàn toàn. Không còn trần 5.000 document, xếp hạng dùng `ORDER BY avg_score DESC` thật.)*
- `players`: 1 dòng/người chơi (id = `playerId` ngẫu nhiên theo trình duyệt, lưu `localStorage`). Cột chính: `name`, `session_count`, `total_correct_time`, `avg_score`, `best_score`, `total_play_time`, `last_visit`, streak. Xem `supabase/schema.sql`.
- `sessions`: 1 dòng/ván, để phân tích A/B giữa các biến thể UI. Client không đọc được bảng này.
- Mọi ghi dữ liệu đi qua RPC `security definer` (`ensure_player`, `submit_match_result`, `create_room`, ...), mỗi RPC nhận `p_secret` (secret 256-bit của người chơi, server chỉ lưu SHA-256). Điểm bị chặn theo thời gian thật đã trôi qua; streak bị kẹp phía server; tên được `sanitize_player_name()`.
- `avg_score = total_correct_time / session_count` — chỉ số dùng để xếp hạng.

### 6 "đối thủ ảo" seed sẵn trong `supabase/schema.sql` (để bảng không trống lúc đầu; id cố định nên chạy lại schema là ghi đè idempotent):
```
seed_a1  Long Lươn            14 ván, best 55.2s
seed_a2  Vy Vui Vẻ             9 ván, best 47.1s
seed_a3  Khánh Đụt            22 ván, best 63.4s
seed_a4  Bánh Bèo Vlog         5 ván, best 34.0s
seed_a5  Sếp Tưởng Em Ngoan   17 ván, best 58.8s
seed_a6  Chíp Lười Biếng       7 ván, best 40.2s
```
*(Lưu ý minh bạch: đây là dữ liệu giả tạo cảm giác cạnh tranh ban đầu, sẽ tự nhiên bị người chơi thật vượt qua.)*

### Hiển thị bảng xếp hạng — logic "top-N-to-rank+10":
- Nếu hạng của bạn ≤ 5 → chỉ hiện top 5.
- Nếu hạng của bạn = n > 5 → hiện toàn bộ từ #1 đến #(n+10), dòng của bạn tô vàng nổi bật (`.lbRow.me { background:#fff3d6; }`), danh sách **tự động cuộn tới đúng vị trí** khi mở (`scrollIntoView({block:'center'})`).
- Danh sách nằm trong khung cuộn riêng (`max-height:280px; overflow-y:auto`) để không phá layout.
- 2 nơi hiển thị: (a) ngay trong modal kết quả sau mỗi ván (không cần bấm gì thêm), (b) modal "🏆 Bảng Xếp Hạng" đầy đủ mở qua nút cúp ở HUD, có 2 tab **"Top người chơi"** / **"Hạng của tôi"** (switch).

---

## 9. Chia sẻ mạng xã hội (mời bạn bè)

4 nút trong cả modal kết quả lẫn modal bảng xếp hạng:
- **📘 Facebook**: mở `https://www.facebook.com/sharer/sharer.php?u=<link_hiện_tại>`.
- **💬 Zalo**: mở `https://sp.zalo.me/share?u=<link>&d=<text>`.
- **🔗 IG/TikTok**: copy link vào clipboard + toast hướng dẫn dán vào bio/story (2 nền tảng này không hỗ trợ share-link trực tiếp).
- **📱 Khác**: `navigator.share()` (mở share sheet gốc của thiết bị — Messenger/WhatsApp/Telegram tuỳ máy), fallback copy link nếu trình duyệt không hỗ trợ.
- Vì mọi người dùng chung 1 kho `db` gắn với đúng link artifact đã publish, "mời bạn bè" = gửi link → bạn bè mở link là tự động vào chung bảng xếp hạng, không cần server riêng.

---

## 10. Analytics hành vi (ẩn danh, gộp số liệu — KHÔNG log từng sự kiện)

- Lưu trong các bảng đếm cố định của Supabase, cập nhật bằng RPC `increment_*` nguyên tử (`x = x + n` trong 1 `UPDATE`), không còn kiểu đọc-cộng-ghi từ client (từng gây mất số liệu khi nhiều người ghi cùng lúc).
- Có hai tầng song song: **cộng dồn toàn thời gian** (`analytics_access_hours`, `analytics_screen_time`, `analytics_heatmap`) và **theo ngày/tuần** (`analytics_access_hours_daily`, `analytics_screen_time_daily`, `analytics_heatmap_weekly`) để trả lời DAU/MAU/cohort/funnel. Khoá ngày/tuần tính ở client theo giờ Việt Nam cố định (UTC+7).
- Nội dung: đếm theo giờ truy cập, tổng + số lần thời gian mỗi màn hình (intro/game/result), heatmap chuột lưới 10×10 (throttle 150ms).
- RPC analytics có rate-limit và validate đầu vào (khoá ngày/tuần, JSON heatmap, thời lượng).
- Ẩn danh: chỉ gắn với `playerId` ngẫu nhiên theo trình duyệt; màn hình giới thiệu có dòng minh bạch về việc ghi nhận ẩn danh.
- **Chưa có:** dashboard trực quan để xem lại các số liệu này; mới chỉ có phần thu thập.

---

## 11. Các thông số cấu hình chính (copy chính xác từ code, để tái tạo đúng độ khó)

Các giá trị luật chơi/độ khó trong `CONFIG` của bản chính (nguồn đúng là `game/TAB-Ne-Sep_v2-perspective.html`, tìm `const CONFIG`):

```js
const CONFIG = {
  targetPersonalTime: 30, matchDuration: 60, maxLives: 3,
  catchRadius: 1.0, rearmRadius: 1.8,
  ambientBoundsMin: 2.5, ambientBoundsMax: 6.5,
  ambientNearBiasProbStart: 0.15, ambientNearBiasProbEnd: 0.28,
  ambientNearMin: 1.2, ambientNearMax: 3.2,
  speedAmbientStart: [0.5, 1.3], speedAmbientEnd: [0.8, 1.9],
  speedCheckStart: [0.6, 2.0], speedCheckEnd: [1.2, 3.4],
  checkGapStart: [5.0, 7.0], checkGapEnd: [1.4, 2.4],
  checkTargetMin: 0.15, checkTargetMax: 0.85,
  difficultyRampSeconds: 40,
  fieldRangeMeters: 3, ellipseRatio: 1.4,
  roomMaxPlayers: 6
};
```
Ngoài ra `CONFIG` còn các tham số render phối cảnh (`cameraDist`, `cameraFH`), rải bàn phòng nhóm (`roomDesk*`) và đồng bộ Sếp qua Realtime (`bossHeartbeatMs`, `bossInterpDelayMs`); xem trực tiếp trong code.

---

## 12. Ràng buộc kỹ thuật quan trọng

- Mỗi bản là **1 file HTML duy nhất**, CSS/JS inline, vanilla JS. Vì vậy CSP trong `vercel.json` vẫn cho `'unsafe-inline'`; thư viện ngoài (supabase-js) ghim đúng phiên bản + SRI.
- Mọi dữ liệu nhận qua Realtime (Broadcast/Presence) là **không tin cậy** — phải qua các hàm `sanitize*`/`isSafeId`/`remote*`, không đưa chuỗi từ xa vào `innerHTML`. Tên người chơi luôn đi qua `escapeHtml()`.
- Mọi tính năng dùng Supabase phải lỗi nhẹ nhàng (try/catch, không làm hỏng UI) nếu bảng/cột chưa tồn tại hoặc mở bằng `file://`.
- Gói free của Supabase: trần ~100 tin Realtime/giây cho cả project (tính cả gửi và nhận), và project tự pause sau ~7 ngày không traffic.

---

## 13. Tệp liên quan

- `game/TAB-Ne-Sep_v2-perspective.html` — bản chính (`/play`).
- `game/TAB-Ne-Sep.html` — bản elip cũ, route `/play-2d` đã gỡ; giữ file để tham khảo.
- `game/TAB-Ne-Sep_v1-radar.html` — bản radar gốc, không còn deploy.
- `supabase/schema.sql` — bảng, RPC, RLS.
- `WORK_LOG.md` — nguồn cập nhật nhất về trạng thái và quyết định.

---

## 14. Tính năng thêm sau đặc tả gốc (tóm tắt, chi tiết trong `WORK_LOG.md`)

- **Phòng nhóm "1 Sếp chung"** (tối đa 6 người): host mô phỏng Sếp, đồng bộ qua Supabase Realtime (host chỉ gửi khi đích/tốc độ/mục tiêu đổi + heartbeat 1s, máy khách tự ngoại suy). Xin chơi lại → host bấm "Chơi lại cả phòng" khi mọi người xong; tự chuyển host khi host rời. Sếp chọn người bị nhắm theo shuffle-bag.
- **Streak** ngày chơi liên tiếp, tính theo giờ Việt Nam cố định.
- **Thách đấu bạn bè** qua `?challenge=<id>` (khác phòng nhóm).
- **Tutorial ép hành động** ở ván solo đầu tiên (cờ `localStorage` `atd_tutorialDone`), nút ❓ Hướng dẫn trên HUD.
- **Ảnh Sếp tự chọn** (lưu `localStorage`, không upload).
- **Điện thoại:** xin toàn màn hình + khoá ngang khi bấm Bắt đầu; nếu không khoá được thì có nút xoay giao diện bằng CSS.
