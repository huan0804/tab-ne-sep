# TAB: Né Sếp

Mini-game hài hước mô phỏng "lén xem phim trong giờ làm, né sếp kiểm tra". Bấm **Tab** để chuyển màn hình giữa nội dung công việc (Excel/Dashboard/Stock giả) và nội dung cá nhân (video/meme giả), né một "Sếp" di chuyển ngẫu nhiên quanh văn phòng.

1 file HTML độc lập (vanilla JS/CSS, không framework), publish dưới dạng [Claude Artifact](https://claude.ai/artifact) để tận dụng bảng xếp hạng nhiều người chơi thật và analytics ẩn danh qua `db` capability.

## Chơi thử

- **Bản hiện hành (vòng vây elip):** xem [`game/TAB-Ne-Sep.html`](game/TAB-Ne-Sep.html) — mở link Artifact đã publish để có đầy đủ bảng xếp hạng + chia sẻ, hoặc mở file trực tiếp bằng trình duyệt để chơi offline (leaderboard sẽ tự chuyển sang lưu cục bộ).
- **Bản gốc (radar góc màn hình):** [`game/TAB-Ne-Sep_v1-radar.html`](game/TAB-Ne-Sep_v1-radar.html) — giữ lại để so sánh/A-B testing.

## Luật chơi cốt lõi

1. Mặc định ở chế độ **personal** (xem phim) — thời gian ở chế độ này cộng dồn làm điểm thắng.
2. "Sếp" di chuyển liên tục quanh văn phòng theo waypoint ngẫu nhiên, không spawn/despawn rời rạc.
3. Bấm **Tab** (hoặc nút "⇆ Đổi màn hình") để chuyển đổi màn hình.
4. Nếu khoảng cách Sếp–bạn ≤ **1.0m** mà đang ở chế độ personal → bị bắt, mất 1 trong 3 mạng.
5. Tích luỹ đủ **60 giây** personal trong **120 giây** thời lượng trận mà chưa hết mạng → thắng.

Chi tiết đầy đủ luật chơi, AI của Sếp, hệ thống điểm, bảng xếp hạng: xem [`docs/GAME_SPEC.md`](docs/GAME_SPEC.md).

## Hai phiên bản UI hiển thị vị trí Sếp

| | v1 — Radar | v2 — Vòng vây elip (hiện hành) |
|---|---|---|
| Cách hiển thị | Radar tròn 168px góc trên phải, chấm đỏ = Sếp, quét xoay liên tục | 3 vòng tròn elip đồng tâm (1m/2m/3m) quanh bàn làm việc, Sếp có silhouette đi lại thật trong scene |
| Vì sao đổi | Radar tách biệt khỏi scene gây khó hình dung khoảng cách thật | Vị trí Sếp gắn liền với không gian văn phòng, trực quan hơn theo phản hồi thiết kế ban đầu |
| File | `game/TAB-Ne-Sep_v1-radar.html` | `game/TAB-Ne-Sep.html` |

Cả hai giữ nguyên 100% phần còn lại: intro/đặt tên, leaderboard sharded, chia sẻ mạng xã hội, analytics ẩn danh, coachmark just-in-time.

## Kiến trúc kỹ thuật

- **1 file HTML duy nhất** mỗi bản, CSS/JS inline hoàn toàn — không build step, không dependency ngoài Google Fonts qua `<link>`.
- **Bảng xếp hạng đa người chơi** dùng `db` capability của Claude Artifact, model **sharded** (40 document cố định tại `players_shard/{0..39}`) để tránh trần 5.000 document/artifact — sức chứa ước tính 40.000–56.000 người chơi.
- **Analytics ẩn danh gộp** (không log từng sự kiện): 4 document cố định cho giờ truy cập, thời gian mỗi màn hình, heatmap chuột intro/game.
- **Fallback an toàn:** nếu mở ngoài môi trường Claude Artifact (`file://`, host riêng...), `window.claude.use('db')` không tồn tại → toàn bộ leaderboard/chia sẻ tự chuyển sang `localStorage`, không crash.

Xem đầy đủ config độ khó, schema dữ liệu, mô hình sharding: [`docs/GAME_SPEC.md`](docs/GAME_SPEC.md).

## Publish lại lên Claude Artifact

Khi publish, **bắt buộc khai báo** `capabilities: {"db": {}}` — nếu không, bảng xếp hạng/analytics sẽ không hoạt động dù code không lỗi (game vẫn chơi được bình thường, chỉ mất phần dữ liệu chia sẻ).

## Chia sẻ mạng xã hội — lưu ý về Facebook

Nút Facebook dùng flow **copy link + mở tab Facebook trống** thay vì popup `sharer.php` trực tiếp. Lý do: Facebook's `share_channel` redirect chặn popup gọi từ domain preview động của claude.ai Artifact (không xác thực được origin), bất kể cấu hình `noopener`/kích thước popup. Zalo, copy-link (IG/TikTok) và share sheet gốc (`navigator.share`) không gặp giới hạn này.

## Cấu trúc thư mục

```
.
├── game/
│   ├── TAB-Ne-Sep.html            # bản hiện hành — vòng vây elip
│   └── TAB-Ne-Sep_v1-radar.html   # bản gốc — radar góc màn hình
├── docs/
│   └── GAME_SPEC.md               # đặc tả đầy đủ: luật chơi, AI, config, schema dữ liệu
├── CHANGELOG.md
└── README.md
```
