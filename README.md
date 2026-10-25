# TAB: Né Sếp

Mini-game hài hước mô phỏng "lén xem phim trong giờ làm, né sếp kiểm tra". Bấm **Tab** để chuyển màn hình giữa nội dung công việc (Excel/Dashboard/Stock giả) và nội dung cá nhân (video/meme giả), né một "Sếp" di chuyển ngẫu nhiên quanh văn phòng.

Mỗi bản là 1 file HTML độc lập (vanilla JS/CSS, không framework, không build step), deploy trên Vercel. Bảng xếp hạng, phòng chơi nhóm và analytics ẩn danh dùng Supabase (Postgres + Realtime).

Production: <https://tab-ne-sep.vercel.app/play>

## Chơi thử

| Route | File | Ghi chú |
|---|---|---|
| `/play` (alias `/play-3d`) | [`game/TAB-Ne-Sep_v2-perspective.html`](game/TAB-Ne-Sep_v2-perspective.html) | **Bản chính**, vòng khoảng cách phối cảnh. Chỉ bản này nhận tính năng mới. |
| (không có route) | [`game/TAB-Ne-Sep.html`](game/TAB-Ne-Sep.html) | Bản elip cũ, route `/play-2d` đã gỡ (2026-10-25). Giữ file để tham khảo. |
| (không deploy) | [`game/TAB-Ne-Sep_v1-radar.html`](game/TAB-Ne-Sep_v1-radar.html) | Bản radar gốc, giữ để tham khảo. Không tương thích RPC mới. |

Mở trực tiếp file bằng trình duyệt (`file://`) vẫn chơi được: các phần dùng Supabase tự lùi về chế độ solo với `localStorage`.

## Luật chơi cốt lõi

1. Mặc định ở chế độ **personal** (xem phim) — thời gian ở chế độ này cộng dồn làm điểm thắng.
2. "Sếp" di chuyển liên tục quanh văn phòng theo waypoint ngẫu nhiên.
3. Bấm **Tab** (hoặc nút "⇆ Đổi màn hình") để chuyển đổi màn hình.
4. Nếu khoảng cách Sếp–bạn ≤ **1.0m** mà đang ở chế độ personal → bị bắt, mất 1 trong 3 mạng.
5. Tích luỹ đủ **30 giây** personal trong **60 giây** thời lượng trận mà chưa hết mạng → thắng.

Giá trị này lấy từ `CONFIG` trong bản chính (`targetPersonalTime`, `matchDuration`). Chi tiết AI của Sếp và hệ thống điểm: xem [`docs/GAME_SPEC.md`](docs/GAME_SPEC.md).

## Chế độ chơi

- **Solo:** có bảng xếp hạng toàn cục, streak ngày chơi liên tiếp (tính theo giờ Việt Nam UTC+7), tutorial ép hành động ở ván đầu tiên.
- **Thách đấu bạn bè:** link `?challenge=<id>`. Đây là tính năng riêng, không phải phòng nhóm.
- **Phòng nhóm "1 Sếp chung":** tối đa 6 người, host mô phỏng Sếp và phát qua Supabase Realtime. Có chơi lại cả phòng và tự chuyển host khi host rời.

## Kiến trúc kỹ thuật

- **Frontend:** mỗi bản là 1 file HTML, CSS/JS inline. Phụ thuộc ngoài chỉ có Google Fonts và supabase-js (CDN, ghim phiên bản + SRI).
- **Backend:** Supabase. Đọc công khai (bảng xếp hạng, phòng), nhưng mọi thao tác ghi đi qua RPC `security definer` và xác thực bằng secret theo từng người chơi. Không có quyền ghi trực tiếp vào bảng.
- **Analytics:** ẩn danh, gộp theo giờ/ngày/tuần, cập nhật bằng RPC `increment_*` nguyên tử.
- **Deploy:** push lên git remote, Vercel tự build. `vercel.json` cấu hình route và header bảo mật (CSP, X-Frame-Options...). `.vercelignore` giữ `supabase/`, `docs/`, `*.md` ra khỏi domain công khai.

Schema và RPC: [`supabase/schema.sql`](supabase/schema.sql) (idempotent, chạy lại toàn bộ trong Supabase SQL editor sau khi sửa). Trạng thái dự án và quyết định gần nhất: [`WORK_LOG.md`](WORK_LOG.md).

## Cấu trúc thư mục

```
.
├── game/
│   ├── TAB-Ne-Sep_v2-perspective.html # bản chính — vòng phối cảnh
│   ├── TAB-Ne-Sep.html                # bản elip cũ (không còn route)
│   └── TAB-Ne-Sep_v1-radar.html       # bản gốc — radar góc màn hình
├── supabase/
│   └── schema.sql                     # bảng, RPC, RLS
├── docs/
│   └── GAME_SPEC.md                   # đặc tả luật chơi, AI Sếp, UX
├── vercel.json
├── CHANGELOG.md
├── WORK_LOG.md
└── README.md
```
