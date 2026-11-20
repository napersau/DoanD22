---
description: Làm bước tiếp theo của lộ trình xây dựng backend (LO_TRINH_XAY_DUNG_BACKEND.md)
argument-hint: "[mã bước, vd P3.2 — bỏ trống để lấy bước [~] hoặc [ ] đầu tiên]"
---

Làm đúng MỘT bước của lộ trình xây dựng backend VetClinic, theo `CLAUDE.md`.

1. Đọc `CLAUDE.md` (§2 nguồn chuẩn, §3 luật code, §4 flow, §5 Điều kiện xong) và `LO_TRINH_XAY_DUNG_BACKEND.md` (mục ▶ TRẠNG THÁI HIỆN TẠI, mục 4 Quyết định đã chốt, mục 5 lệch hợp đồng FE).
2. Chọn bước: có tham số thì dùng bước `$ARGUMENTS`; không có thì lấy bước `[~]` đang dở, nếu không có thì bước `[ ]` đầu tiên theo thứ tự. Nếu bước đứng trước chưa `[x]` → dừng và báo người dùng.
3. Đọc các mục `docs/` mà bước trỏ tới (Task trong Lịch trình kèm "Hướng dẫn kiểm thử", bảng/cột trong ERD, mục Quy chuẩn, Kiến trúc, State Machine, Ngoại lệ liên quan) và đo phần mã nguồn sẽ đụng tới. Báo ngắn cho người dùng: bước này tạo/sửa gì, có mâu thuẫn docs nào (ghi thành `D-xx`).
4. Đánh dấu bước `[~]` trong lộ trình, rồi viết code + test theo `CLAUDE.md` §3.
5. Chạy đủ Điều kiện xong (`CLAUDE.md` §5 + mục **Kiểm tra** của bước): `mvn -q clean verify`; nếu bước có service chạy được thì `docker compose up -d --build <service>` (healthy) và `bash e2e/run_all.sh`. Không bỏ bước kiểm tra, không skip test. Đỏ thì sửa tới khi xanh; không sửa được thì giữ `[~]`, ghi lỗi vào lộ trình và dừng, báo rõ.
6. Cập nhật `LO_TRINH_XAY_DUNG_BACKEND.md`: `[x]`, dòng **Kết quả** (ngày, số test, số kiểm tra e2e, lệch docs, D-xx mới), bảng trạng thái + "Bước tiếp theo" + "Tiến độ x/48"; xong cả giai đoạn thì điền "Kết quả giai đoạn"; thêm dòng nhật ký nếu đổi lộ trình.
7. Commit một lần (code + lộ trình) trên nhánh `develop`: `be <bước>: <tóm tắt>`; rồi `git push origin develop`. Push bị từ chối → báo người dùng, không `--force`.
8. Dừng sau một bước và báo kết quả (số liệu thật). Không tự làm bước tiếp theo.
