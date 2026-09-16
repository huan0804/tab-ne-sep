# Nhật ký làm việc — TAB: Né Sếp

> File này ghi lại trạng thái dự án để tiếp tục ở phiên làm việc sau. Cập nhật mỗi khi có tiến triển lớn.

## Trạng thái hiện tại (2026-09-16)

Đang giữa chừng migrate game từ Claude Artifact (`db` capability) sang **Supabase + Vercel** để có domain riêng, phục vụ mục tiêu xây personal brand.

### Việc đã xong

1. **Cơ chế hiển thị vị trí Sếp** — thay radar góc màn hình bằng vòng vây elip đồng tâm (1m/2m/3m) quanh bàn làm việc, Sếp có silhouette đi lại thật. Cả 2 bản được giữ lại để A/B test sau này:
   - `game/TAB-Ne-Sep.html` — bản hiện hành (vòng vây elip)
   - `game/TAB-Ne-Sep_v1-radar.html` — bản gốc (radar)

2. **Sửa nút chia sẻ Facebook** — đổi từ popup `sharer.php` (bị Facebook chặn qua `share_channel` redirect khi gọi từ domain preview claude.ai) sang copy-link + mở tab Facebook trống. Áp dụng cho cả 2 file.

3. **Tạo GitHub repo** — `https://github.com/huan0804/tab-ne-sep` (public), đã push commit đầu tiên với cấu trúc:
   ```
   game/           — 2 file HTML
   docs/GAME_SPEC.md — đặc tả gốc đầy đủ
   README.md, CHANGELOG.md
   ```
   **Lưu ý quan trọng:** user yêu cầu **luôn hỏi xác nhận trước khi `git push`** — đã lưu vào memory, không tự động push.

4. **Đã tạo tài khoản Supabase** — project `huan0804's Project`:
   - Project ID: `vznqblibuviqywgvyybg`
   - Region: `ap-northeast-1` (Tokyo)
   - Project URL: `https://vznqblibuviqywgvyybg.supabase.co`
   - Publishable key: `sb_publishable_a91I3H0gcOSEZMiyAUGeww_skfkc4l9` (đã hardcode vào code — key này an toàn public theo thiết kế của Supabase, bảo mật thật nằm ở RLS policy)

5. **Đã viết schema SQL** — `supabase/schema.sql`, gồm:
   - Bảng `players` (thay thế mô hình sharded 40-document cũ — Postgres không giới hạn document nên mỗi người chơi là 1 row thật, `ORDER BY avg_score DESC` server-side thật)
   - Bảng `analytics_access_hours`, `analytics_screen_time`, `analytics_heatmap` (giữ nguyên ý tưởng cũ: vài row cố định, không log từng event)
   - RLS policies cho phép đọc/ghi công khai (game chạy hoàn toàn client-side, không có backend riêng)
   - Seed sẵn 6 "đối thủ ảo" (Long Lươn, Vy Vui Vẻ, Khánh Đụt, Bánh Bèo Vlog, Sếp Tưởng Em Ngoan, Chíp Lười Biếng)

6. **Đã viết lại toàn bộ code JS trong `game/TAB-Ne-Sep.html`** để gọi Supabase JS SDK (load qua CDN `jsdelivr`) thay vì `window.claude.use('db')`:
   - Xóa hoàn toàn: `NUM_SHARDS`, `hashStr`, `shardIdFor`, `playerShardRef`, `getAllPlayersFlat`, `FAKE_PLAYERS`/`maybeSeedFakePlayers` (seed giờ nằm trong SQL)
   - Biến `dbNS` → `sb` (Supabase client instance)
   - Thêm hàm mới: `playerRowToRecord` (map snake_case DB row → camelCase code cũ dùng), `getTopPlayers`, `getPlayerRank` (dùng `count` query thật thay vì đọc hết rồi sort)
   - Đã kiểm tra cú pháp JS hợp lệ (`node -e "new Function(...)"` pass)

### Việc CHƯA xong — cần làm tiếp

1. **User CHƯA chạy `supabase/schema.sql`** trong Supabase SQL Editor — đây là bước chặn đầu tiên, nếu chưa chạy thì game sẽ lỗi "relation does not exist" khi gọi bất kỳ bảng nào. Đã gửi hướng dẫn từng bước, đang chờ user thực hiện.

2. **Chưa test thực tế trên trình duyệt** sau khi đổi sang Supabase — đã mở file bằng `Start-Process` nhưng chưa nhận được phản hồi kết quả (user có việc bận giữa chừng). Cần kiểm tra:
   - Console (F12) có lỗi kết nối Supabase không
   - Bảng xếp hạng có hiện đúng 6 người seed + điểm người chơi thật không
   - `upsert` vào bảng `players` có hoạt động không (RLS có chặn ngầm không)

3. **Chưa deploy lên Vercel** — bước tiếp theo sau khi Supabase chạy ổn:
   - User chưa có tài khoản Vercel — cần hướng dẫn tạo (khuyên đăng nhập bằng GitHub, liên kết luôn với repo `tab-ne-sep` để auto-deploy mỗi lần push)
   - Sau khi deploy sẽ có domain dạng `*.vercel.app` miễn phí ngay
   - Domain riêng (.com/.vn) sẽ gắn sau, khi user đã sẵn sàng mua

4. **File `game/TAB-Ne-Sep_v1-radar.html` (bản radar cũ) CHƯA được migrate sang Supabase** — vẫn đang dùng code `db` capability cũ của Claude Artifact. Cần quyết định: có migrate bản này luôn không (để giữ khả năng A/B test 2 bản UI trên cùng hạ tầng Supabase), hay tạm để nguyên vì ưu tiên bản chính trước.

5. **Kế hoạch A/B test đã bàn trước đó (radar vs elip)** — tạm gác lại, chưa triển khai:
   - Đã có kế hoạch chi tiết dạng artifact: https://claude.ai/artifact/Me3vzsBbDrtZcaLpFnkGgX
   - Ý tưởng: 1 link duy nhất, random 50/50 gán variant A/B khi mở lần đầu, sticky theo localStorage, hỏi feedback 1 câu sau ván đầu
   - Cần quay lại sau khi hạ tầng Supabase + Vercel ổn định

6. **Chưa xóa/archive artifact cũ trên claude.ai** — `https://claude.ai/artifact/66FP1RpVHw6K5jvD6jWWfX` vẫn đang publish bản Claude Artifact gốc (dùng `db` capability cũ). Cần quyết định giữ song song hay ngừng dùng sau khi Vercel deploy ổn.

## Quyết định/ràng buộc quan trọng cần nhớ

- **Luôn hỏi xác nhận trước khi `git push`** (user yêu cầu rõ, đã lưu vào memory `feedback_git_push_confirm.md`).
- **Lý do đổi sang Supabase+Vercel**: user muốn xây personal brand, domain gắn với claude.ai bị coi là rủi ro thương hiệu.
- **Chọn Supabase (không phải Firebase)**: ưu tiên chất lượng dữ liệu lâu dài, ORDER BY server-side thật, dễ phân tích SQL cho A/B test sau này — dù tốn công chuyển đổi hơn Firebase.
- **Chọn Vercel (không phải Netlify/Cloudflare Pages)**: tích hợp GitHub tốt, tự động deploy lại mỗi lần push.
- **RLS policy hiện tại cho phép ai cũng đọc/ghi** — chấp nhận được cho mini-game công khai không có dữ liệu nhạy cảm, giống hệt mô hình cũ.
- **Publishable key Supabase an toàn để hardcode trong code** — không phải secret, đừng nhầm với `service_role` key (không bao giờ được đưa vào code/nơi công khai).

## File liên quan

```
game/TAB-Ne-Sep.html            — bản chính, ĐÃ migrate sang Supabase, CHƯA test xong
game/TAB-Ne-Sep_v1-radar.html   — bản gốc, CHƯA migrate (vẫn dùng Claude db capability cũ)
supabase/schema.sql             — schema đầy đủ, CHƯA được user chạy trong Supabase
docs/GAME_SPEC.md               — đặc tả gốc đầy đủ (luật chơi, AI, config)
README.md                       — tổng quan dự án
CHANGELOG.md                    — lịch sử v1 → v2
```

## Việc cần làm tiếp khi mở lại phiên mới

1. Hỏi user: đã chạy `schema.sql` trong Supabase chưa?
2. Nếu rồi → mở lại `game/TAB-Ne-Sep.html`, kiểm tra Console lỗi, xác nhận leaderboard hoạt động.
3. Nếu game chạy ổn với Supabase → hướng dẫn tạo tài khoản Vercel, deploy.
4. Sau khi có domain Vercel → hỏi user có muốn quay lại kế hoạch A/B test đã lên (mục 5 ở trên) không.
5. Hỏi user về việc migrate nốt `TAB-Ne-Sep_v1-radar.html` sang Supabase (đồng bộ 2 bản) hay bỏ luôn bản này.
