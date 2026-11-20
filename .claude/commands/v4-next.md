---
description: Làm bước tiếp theo của lộ trình nâng mã nguồn lên v4.0 (LO_TRINH_SUA_CODE_V4.md)
argument-hint: "[mã bước, vd 0.1 — bỏ trống để lấy bước [ ] đầu tiên]"
---

Làm đúng MỘT bước của lộ trình nâng mã nguồn VetClinic từ v3.0 lên v4.0.

1. Đọc `LO_TRINH_SUA_CODE_V4.md`: mục "▶ TRẠNG THÁI HIỆN TẠI", mục 1 (nguyên tắc), mục 2 (Điều kiện xong), mục 4 (Quyết định đã chốt).
2. Chọn bước: nếu có tham số thì dùng bước `$ARGUMENTS`; nếu không, lấy bước `[ ]` (hoặc `[~]` đang dở) đầu tiên theo thứ tự. Nếu bước trước nó chưa `[x]` thì dừng và báo người dùng.
3. Đọc phần `docs/` v4.0 mà bước đó trỏ tới (bảng trong `docs/schema_init.sql`, Task trong `docs/LICH_TRINH_XAY_DUNG_MA_NGUON_VA_HUONG_DAN_TEST.md`, mục Quy chuẩn / Kiến trúc / State Machine / Ngoại lệ liên quan) và đo phần mã nguồn sẽ đụng tới trước khi sửa. Nói ngắn cho người dùng biết bước này sẽ đổi những gì.
4. Thực hiện bước theo nguyên tắc: lược đồ chép đúng từng chữ từ docs vào `db/schema_current.sql`; đổi id kèm mọi chỗ tham chiếu ở mọi service, FE và e2e trong cùng bước; thêm trước xóa sau; luôn `mvn -o clean`.
5. Chạy đủ "Điều kiện xong" (unit test, build + test FE, `docker compose down -v && up -d --build`, mọi container healthy, `bash e2e/run_all.sh`). Không bỏ qua bước nào; nếu đỏ thì sửa đến khi xanh hoặc dừng và báo rõ lỗi.
6. Cập nhật `LO_TRINH_SUA_CODE_V4.md`: đánh `[x]`, thêm dòng "Kết quả:" (số unit test, số kiểm tra e2e, điều chỉnh khác docs), sửa bảng trạng thái và "Bước tiếp theo". Nếu phát sinh quyết định mới (docs mâu thuẫn), thêm vào mục 4 và báo người dùng.
7. Commit một lần (code + lộ trình) với thông điệp `v4 <bước>: <tóm tắt>` (không đưa `update.md` vào commit), rồi **push lên GitHub**: `git push origin develop` (người dùng yêu cầu push sau mỗi bước, 20/11/2026). Push bị từ chối thì báo người dùng, không `--force`.
8. Dừng sau một bước và báo kết quả cho người dùng; không tự làm bước tiếp theo.
