# Changelog

## v2 — Vòng vây elip (hiện hành)

- Thay radar góc màn hình bằng hệ thống vòng tròn khoảng cách đồng tâm (1m/2m/3m, dạng elip tỷ lệ ~1.4:1) quanh bàn làm việc, vẽ trực tiếp trong scene văn phòng.
- Sếp có silhouette toàn thân (thân, cà vạt, bóng đổ) di chuyển vật lý thật giữa các vòng, thay vì chỉ là chấm đỏ trên radar tách biệt. Mặt biểu cảm SVG (calm/alert/angry) giữ nguyên, gắn trên đầu silhouette.
- Công thức khoảng cách đổi sang dạng elip (`hypot(x, y * ellipseRatio)`) để logic bắt/né khớp chính xác với vị trí hiển thị trên màn hình ở mọi hướng.
- Sửa nút chia sẻ Facebook: chuyển từ popup `sharer.php` sang copy-link + mở tab Facebook trống, vì popup bị chặn bởi `share_channel` redirect khi gọi từ domain preview động của claude.ai Artifact.
- Cập nhật toàn bộ copy hướng dẫn (intro steps, coachmark, modal thua) để không còn nhắc "radar"/"góc trên bên phải".

## v1 — Radar góc màn hình (bản gốc)

- Bản đầu tiên hoàn chỉnh: HUD, radar 360° góc trên phải, mặt Sếp biểu cảm 3 trạng thái, 3 kiểu màn hình work (Excel/Dashboard/Stock) + 4 kiểu màn hình personal (2 kiểu Dragon Ball gốc + 2 kiểu meme).
- Hệ thống điểm & bảng xếp hạng đa người chơi qua `db` capability, model sharded 40 document.
- Analytics ẩn danh gộp (giờ truy cập, thời gian mỗi màn hình, heatmap chuột).
- Flow trải nghiệm frictionless: coachmark just-in-time (dạy đúng lúc, nhớ vĩnh viễn qua localStorage), gợi ý tên hài hước, edge case đóng modal (X, backdrop click, Esc, replay FAB).
- Chia sẻ mạng xã hội: Facebook, Zalo, copy-link (IG/TikTok), native share sheet.

Xem đặc tả đầy đủ luật chơi, AI, config độ khó tại [`docs/GAME_SPEC.md`](docs/GAME_SPEC.md).
