# TAB: Né Sếp — Đặc tả game đầy đủ (v cuối cùng trong phiên làm việc)

> **Cách dùng file này:** đưa file này (và file `TAB-Ne-Sep_SOURCE.html` đính kèm — đây mới là mã nguồn gốc chính xác 100%) cho Claude, yêu cầu: *"Đây là đặc tả + mã nguồn gốc của 1 game HTML tôi đã làm trước đó, hãy tái tạo lại y hệt / hoặc dùng làm nền để chỉnh tiếp."* Nếu chỉ cần y hệt, có thể bảo Claude copy nguyên file `.html` — đó là cách chắc chắn nhất, không lệch chi tiết.

---

## 1. Tổng quan

- **Tên:** TAB: Né Sếp
- **Định dạng:** 1 file HTML độc lập (không phụ thuộc file ngoài trừ Google Fonts + 1 vài host script CDN được whitelist), publish dưới dạng Claude Artifact (claude.ai/artifact).
- **Thể loại:** Mini-game hài hước, mô phỏng "lén xem phim trong giờ làm, né sếp kiểm tra". Tối đa hoá thời gian "xem phim" (personal) mà không bị sếp bắt gặp.
- **Ngôn ngữ giao diện:** Tiếng Việt 100%.
- **Nền tảng kỹ thuật đặc biệt:** dùng runtime capability `db` của Claude Artifact (kho dữ liệu JSON dùng chung, đồng bộ giữa mọi người mở cùng link) để làm bảng xếp hạng thật nhiều người chơi + analytics ẩn danh. Khi publish lại, PHẢI khai báo `capabilities: {"db": {}}`.

---

## 2. Luật chơi cốt lõi

1. Người chơi mặc định đang ở chế độ **"personal"** (xem phim/meme trên màn hình) — thời gian ở chế độ này được cộng dồn làm điểm thắng.
2. Một "Sếp" di chuyển liên tục quanh văn phòng (mô phỏng bằng toạ độ 2D ẩn, không hiển thị bản đồ thật — chỉ hiện qua radar).
3. Người chơi bấm phím **Tab** (hoặc nút "⇆ Đổi màn hình") để chuyển đổi màn hình giữa **work** (bảng tính/dashboard/chứng khoán) và **personal** (video/meme).
4. **Luật thua:** nếu khoảng cách Sếp–người chơi ≤ **1.0** (đơn vị "mét") mà đang ở chế độ personal → bị bắt, mất 1 trong 3 mạng (❤️❤️❤️). Có "rearm radius" = 1.8 (phải lùi ra >1.8 mới có thể bị bắt lại lần nữa, tránh trừ liên tục).
5. **Luật thắng:** tích luỹ đủ **60 giây** ở chế độ personal trong vòng **120 giây** thời lượng trận đấu, mà chưa hết 3 mạng.
6. **Thua vì hết giờ:** hết 120s mà chưa đạt 60s personal → thua kiểu "hết giờ".
7. **Điểm số (khác với thắng/thua):** "thời gian chơi đúng" = tổng thời gian mà (mode=work VÀ dist≤1m) HOẶC (mode=personal VÀ dist>1m). Đây là điểm dùng cho bảng xếp hạng (không phải thời lượng personal).

---

## 3. AI của "Sếp" (di chuyển ngẫu nhiên, không cố định)

- Toạ độ Sếp là 1 điểm 2D `(x,y)`, người chơi luôn ở gốc `(0,0)`.
- Sếp di chuyển liên tục theo waypoint ngẫu nhiên (không phải spawn/despawn rời rạc):
  - **Ambient wander** (đi lượn thường): chọn điểm đích ngẫu nhiên cách gốc 2.5–6.5 (hoặc 1.2–3.2 nếu trúng "near bias", xác suất 15%→28% tăng theo thời gian).
  - **Forced close approach** (bắt buộc áp sát thật): cứ sau mỗi 5–7 giây (đầu trận) → rút dần còn 1.4–2.4 giây (cuối trận), Sếp buộc phải đi tới 1 điểm cách gốc 0.15–0.85 (tức chắc chắn xuyên qua ngưỡng bắt 1m) — đây là nguồn đe doạ chính, không phụ thuộc may rủi ambient.
  - Tốc độ mỗi đoạn di chuyển ngẫu nhiên trong khoảng tăng dần theo độ khó (ramp trong 80 giây đầu): ambient 0.5–1.3 → 0.8–1.9 (đơn vị/giây); forced 0.6–2.0 → 1.2–3.4.
- **Radar 360°**: hiển thị góc trên bên phải, đường kính 168px, 3 vòng tròn đồng tâm, chấm đỏ = Sếp (đổi màu xanh lá/vàng/đỏ theo khoảng cách: >3m xanh, 1.5–3m vàng, ≤1.5m đỏ), có số mét hiển thị trực tiếp, quét radar xoay liên tục (tắt khi `prefers-reduced-motion`).
- **Mặt Sếp biểu cảm** (132px, gần bằng kích thước radar) với 3 trạng thái: `calm` (đang lượn xa, mắt chớp nhẹ, có cổ áo sơ mi xanh), `alert` (đang trong pha forced-approach, mắt nheo + giọt mồ hôi, rung nhẹ), `angry` (vừa bắt được, mặt đỏ, gân nổi, rung mạnh, có bong bóng thoại với 1 trong 9 câu mắng ngẫu nhiên tiếng Việt hài hước).

---

## 4. Nội dung màn hình (random mỗi ván, để tạo cảm giác mới mẻ)

### Màn hình "Work" — random 1 trong 3 kiểu, số liệu random mỗi ván:
1. **Excel**: bảng 5 dòng (Doanh thu/Chi phí/Lợi nhuận/Marketing...) + biểu đồ cột mini bên cạnh + tab sheet giả (T1–T4).
2. **Dashboard**: 4 thẻ KPI (2×2 grid) + biểu đồ đường xu hướng (SVG polyline) + biểu đồ donut (CSS `conic-gradient`) + biểu đồ cột mini theo khu vực.
3. **Stock**: mã chứng khoán ngẫu nhiên (VNM/FPT/HPG/MWG/VIC/VCB/MSN/GAS) + giá + %, biểu đồ đường giá + biểu đồ khối lượng giao dịch + bảng theo dõi 3 mã khác kèm màu xanh/đỏ.

### Màn hình "Personal" — random 1 trong 4 kiểu mỗi ván:
1–2. **2 kiểu lấy cảm hứng Dragon Ball** — nhân vật minh hoạ **gốc do vẽ bằng SVG tay** (tóc dựng đứng, hào quang pulse quanh đầu), KHÔNG sao chép thiết kế nhân vật Songoku thật (tránh vướng bản quyền hình ảnh nhân vật), chỉ chơi chữ bằng caption kiểu "Kamehameha", "Genki Dama", "Cực Phẩm Tăng Ca Saiyan".
3–4. **2 kiểu meme hài tự vẽ**: mèo tổng giám đốc phê duyệt nghỉ ngơi; "Vẫn Ổn Thôi" khi sếp đi vòng vòng.
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

### Model lưu trữ — **Sharded (Phương án B)**, KHÔNG dùng 1-document-per-player:
- Lý do: `db` capability giới hạn cứng **5.000 document/artifact tính tổng mọi collection**. 1 người chơi = 1 doc sẽ cạn khi đủ 5.000 người từng ghé.
- Giải pháp: **40 "ngăn" (shard) cố định** tại `players_shard/{0..39}`. Mỗi ngăn là 1 document dạng object `{ playerId: {record}, playerId2: {record}, ... }`.
- Người chơi rơi vào ngăn nào = hash cố định trên playerId mod 40 (hàm djb2 hash đơn giản).
- Sức chứa: mỗi ngăn ~1.000-1.400 người (dưới trần 256KB/doc) × 40 ngăn ≈ **40.000-56.000 người chơi**, chỉ tốn đúng 40 document.
- Ghi dữ liệu: `update({[playerId]: record})`, nếu ngăn chưa tồn tại thì fallback `set({[playerId]: record})`.
- **Đánh đổi đã chấp nhận**: mất `orderBy` phía server → đọc cả 40 ngăn, gộp mảng, `sort()` bằng JS phía client mỗi lần cần xếp hạng (chi phí cố định, không tăng theo số người chơi).

### Schema mỗi player record:
```json
{
  "name": "string",
  "sessionCount": 0,
  "totalCorrectTime": 0,
  "avgScore": 0,
  "bestScore": 0,
  "totalPlayTime": 0,
  "createdAt": 0,
  "lastVisit": 0
}
```
`avgScore = totalCorrectTime / sessionCount` — đây là chỉ số dùng để xếp hạng.

### 6 "đối thủ ảo" seed sẵn (để bảng không trống lúc đầu, kích thích cạnh tranh — id cố định nên ghi đè idempotent, sửa tên trong code là áp dụng ngay không cần xoá dữ liệu cũ):
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

Vì cùng chung giới hạn 5.000 document, tuyệt đối không tạo 1 document/sự kiện. Thay vào đó dùng đúng **4 document cố định**, luôn ghi đè (đọc → cộng → ghi):

| Document | Nội dung |
|---|---|
| `analytics/accessHours` | Đếm dồn theo giờ trong ngày (`h0`..`h23` + `total`) |
| `analytics/screenTime` | Tổng + số lần mỗi phase (`introSum/introCount`, `gameSum/gameCount`, `resultSum/resultCount`) → tính trung bình thời gian mỗi màn hình |
| `analytics/heatmap_intro` | Lưới toạ độ chuột 10×10 (key `"col_row"` → count) trong lúc ở màn hình giới thiệu |
| `analytics/heatmap_game` | Tương tự, trong lúc đang chơi (và cả lúc xem kết quả, gộp chung) |

- Mouse/touch tracking: throttle 150ms, bucket toạ độ theo % chiều rộng/cao cửa sổ vào lưới 10×10.
- Chuyển phase ghi nhận tại các mốc: mở game (intro) → bấm Bắt Đầu (→ game) → kết thúc ván (→ result) → bấm Chơi lại (→ game mới). Có `beforeunload` để cố gắng flush nốt phase đang dở khi đóng tab.
- Ẩn danh 100%: chỉ gắn với `playerId` ngẫu nhiên theo trình duyệt, có dòng minh bạch nhỏ ở màn hình giới thiệu: *"Game ghi nhận ẩn danh thời gian chơi & thao tác để cải thiện trải nghiệm."*
- **Chưa có:** dashboard trực quan (heatmap màu, biểu đồ giờ truy cập) để XEM lại các số liệu này — mới chỉ có phần THU THẬP. Nếu cần, đây là việc tiếp theo (1 màn hình admin đọc lại 4 document trên và vẽ ra).

---

## 11. Các thông số cấu hình chính (copy chính xác từ code, để tái tạo đúng độ khó)

```js
const CONFIG = {
  targetPersonalTime: 60, matchDuration: 120, maxLives: 3,
  catchRadius: 1.0, rearmRadius: 1.8, radarRangeMeters: 6,
  ambientBoundsMin: 2.5, ambientBoundsMax: 6.5,
  ambientNearBiasProbStart: 0.15, ambientNearBiasProbEnd: 0.28,
  ambientNearMin: 1.2, ambientNearMax: 3.2,
  speedAmbientStart: [0.5, 1.3], speedAmbientEnd: [0.8, 1.9],
  speedCheckStart: [0.6, 2.0], speedCheckEnd: [1.2, 3.4],
  checkGapStart: [5.0, 7.0], checkGapEnd: [1.4, 2.4],
  checkTargetMin: 0.15, checkTargetMax: 0.85,
  difficultyRampSeconds: 80
};
const NUM_SHARDS = 40;
```

---

## 12. Ràng buộc kỹ thuật quan trọng khi tái tạo trên môi trường khác

- Đây là **1 file HTML duy nhất**, toàn bộ CSS/JS inline, không dùng framework (vanilla JS + CSS thuần, chỉ Google Fonts qua `<link>`).
- Nếu tái tạo trong Claude Desktop / môi trường **không phải** claude.ai Artifact publish: **sẽ không có** `window.claude.use('db')` — cần code fallback (bản gốc đã có sẵn: nếu `dbNS` null, toàn bộ tính năng xếp hạng/chia sẻ tự chuyển về `localStorage` cục bộ, không crash).
- Nếu muốn publish lại y hệt lên claude.ai làm Artifact: nhớ khai báo `capabilities: {"db": {}}` khi gọi publish, nếu không bảng xếp hạng sẽ không hoạt động dù code không lỗi.
- Toàn bộ chữ, tên biến, comment trong code đều bằng tiếng Việt/tiếng Anh trộn lẫn tự nhiên (giữ nguyên để dễ đọc lại sau này).

---

## 13. File đính kèm

- `TAB-Ne-Sep_SOURCE.html` — **mã nguồn đầy đủ, chính xác 100%** của bản game hiện tại. Đây là nguồn tham chiếu chắc chắn nhất; nếu chỉ cần "y hệt", dùng thẳng file này (mở bằng trình duyệt là chạy được ngay, không cần build gì thêm).
