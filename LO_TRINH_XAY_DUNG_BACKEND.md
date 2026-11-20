# LỘ TRÌNH XÂY DỰNG BACKEND — VETCLINIC (bám bộ tài liệu v4.0)

> **Mục đích:** chia việc xây dựng backend từ con số 0 thành các bước nhỏ, mỗi bước kiểm chứng được, có ghi kết quả. Claude đọc file này cùng `CLAUDE.md` trước mỗi phiên làm việc.
> **Cách dùng:** `/be-next` làm đúng một bước (bước `[~]` đang dở hoặc bước `[ ]` đầu tiên). Quy trình một bước: `CLAUDE.md` §4; Điều kiện xong: `CLAUDE.md` §5.
> **Ký hiệu:** `[ ]` chưa làm · `[~]` đang làm · `[x]` xong (có dòng **Kết quả**) · `[!]` bị chặn (ghi lý do).
> **Nguồn:** toàn bộ `docs/` v4.0 (18/11/2026). Mã Task `Tx.y` dưới đây là Task trong `docs/LICH_TRINH_XAY_DUNG_MA_NGUON_VA_HUONG_DAN_TEST.md`.

---

## ▶ TRẠNG THÁI HIỆN TẠI

**Bước tiếp theo: `P0.3`** · Cập nhật lần cuối: 21/11/2026 (xong P0.2)

| Giai đoạn | Nội dung | Số bước | Trạng thái | Kết quả giai đoạn |
| :---: | :--- | :---: | :---: | :--- |
| **P0** | Nền móng: môi trường, khung Maven, lược đồ 52 bảng, dữ liệu demo, Docker hạ tầng | 5 | `[~]` 2/5 | P0.1: 9 module build xanh, 8 test · P0.2: 52 bảng / 40 FK / 4 VIEW / 0 ENUM, nạp MySQL 8.0 không lỗi |
| **P1** | `common-library`: API envelope, 49 mã lỗi, auto-config servlet, enum, 17 sự kiện, Outbox | 4 | `[ ]` | – |
| **P2** | `service-registry` (Eureka) & `api-gateway` (JWT, 401/403, CORS) | 2 | `[ ]` | – |
| **P3** | `auth-service`: đăng nhập, JWT, refresh xoay vòng, nhân sự, hồ sơ, API nội bộ | 5 | `[ ]` | – |
| **P4** | `clinical-service` nền: 24 entity, danh mục, bảng giá có lịch sử, thú cưng | 3 | `[ ]` | – |
| **P5** | `appointment-service`: khung giờ động, đặt / duyệt / hủy lịch, NO_SHOW, listener | 3 | `[ ]` | – |
| **P6** | `clinical-service`: hàng đợi Redis, check-in, thu phí khám, điều phối, khám GĐ 1 | 5 | `[ ]` | – |
| **P7** | `clinical-service`: chỉ định CLS, hủy dịch vụ, Lab, CĐHA, hợp nhất kết quả | 5 | `[ ]` | – |
| **P8** | `billing-pharmacy-service` nền: thuốc, giá, kho, API nội bộ | 2 | `[ ]` | – |
| **P9** | `clinical-service`: kê đơn, GĐ 2, chốt ca, mở lại, thu tiền & hoàn tất ca | 3 | `[ ]` | – |
| **P10** | `billing-pharmacy-service`: hóa đơn thuốc nháp, thu tiền + trừ kho nguyên tử | 2 | `[ ]` | – |
| **P11** | `reporting-service` (CQRS read model) | 2 | `[ ]` | – |
| **P12** | `notification-service` (STOMP WebSocket, Email) | 2 | `[ ]` | – |
| **P13** | Tích hợp & nghiệm thu: full Docker, dựng lại hàng đợi, E2E happy path + 20 ngoại lệ, đồng bộ FE | 5 | `[ ]` | – |

**Tổng: 48 bước.** Tiến độ: 2/48.

---

## 1. Nguyên tắc của lộ trình

1. **Theo phụ thuộc thật, không theo thứ tự tài liệu.** Docs xếp auth → appointment → clinical → billing; nhưng đặt lịch cần `GET /internal/pets/{id}` (clinical), kê đơn cần `GET /internal/medicines` (billing), test chốt ca cần đơn thuốc. Vì vậy thú cưng (P4) làm trước lịch hẹn (P5), danh mục thuốc (P8) làm trước chốt ca (P9). Bảng truy vết ở mục 7.
2. **Mỗi bước để lại hệ thống chạy được:** build xanh, test xanh, các script e2e cũ vẫn xanh.
3. **Lược đồ trước, code sau:** entity phải khớp `db/schema_current.sql` (`ddl-auto: validate`). Sửa lược đồ = sửa `db/` + ghi `D-xx` + đồng bộ `docs/*.sql`.
4. **Kiểm thử bằng kịch bản của docs:** mỗi Task có "Hướng dẫn kiểm thử" → chuyển thành `e2e/<bước>_*.sh` dùng biến `$U_TIEN`, `$PET_LU`, `$S_EXAM`, `$TOKEN_VET`… (Lịch trình, phần Quy ước dùng chung).
5. **Ghi lại mọi lệch so với docs** ở mục 4 (quyết định) và dòng Kết quả của bước.

---

## 2. Điều kiện xong

Xem `CLAUDE.md` §5. Mỗi bước dưới đây có thêm mục **Kiểm tra** riêng — phải đạt cả hai.

---

## 3. Hiện trạng ban đầu (đo ngày 20/11/2026)

| Hạng mục | Hiện trạng |
| :--- | :--- |
| `vetclinic-backend/pom.xml` | Có: Boot 4.1.1, Spring Cloud 2025.1.3, MapStruct 1.6.3, jjwt 0.12.6 (gson), enforcer JDK 21+; khai báo 8 module (**thiếu `reporting-service`**); chưa có thư mục module nào |
| `vetclinic-backend/Dockerfile`, `docker-compose.yml`, `.env.example` | Rỗng |
| `docker-compose.dev.yml`, `docker-compose.db.yml` | Có (mở cổng mysql-server, rabbitmq-broker, mailpit, service-registry) |
| `db/schema_current.sql`, `db/seed_current.sql`, `docs/schema_init.sql`, `docs/seed_demo_data.sql` | **Rỗng** (0 byte) → phải dựng lại từ ERD |
| `fe/` | Có giao diện React (CRA, cổng 3000) + lớp API theo hợp đồng v3.0 |
| `e2e/` | Chưa có |
| Máy | JDK 22, Maven 3.9.9, Docker 28, Node 22; không có `jq`; remote `origin` = GitHub `napersau/DoanD22`, chỉ có nhánh `main` |

---

## 4. Quyết định đã chốt (D-xx)

> Thêm dòng mới khi docs mâu thuẫn / thiếu. Không xóa dòng cũ; nếu đổi, ghi dòng mới thay thế và đánh dấu dòng cũ "(thay bởi D-yy)".

| Mã | Quyết định | Lý do / nguồn |
| :---: | :--- | :--- |
| **D-01** | Nguồn chuẩn là docs v4.0. Các file `docs/* (1).md` là v3.0 → bỏ qua. | So sánh nội dung: bản `(1)` ghi phiên bản 3.0, 27 bảng |
| **D-02** | `docs/schema_init.sql` rỗng → dựng lại lược đồ từ ERD mục 4 (từ điển dữ liệu: cột, kiểu, ràng buộc), mục 5 (index), mục 6 (VIEW) và Enum mục B (dữ liệu danh mục). Bản chạy thật: `db/schema_current.sql` + `db/seed_current.sql` (Docker nạp). `docs/schema_init.sql`, `docs/seed_demo_data.sql` là bản sao để nộp, đồng bộ bằng copy khi lược đồ đổi. | Docs tham chiếu `schema_init.sql` như nguồn nhưng file 0 byte |
| **D-03** | Giá trị seed docs đã nêu phải dùng đúng: `EXAM_GEN` 100.000 (VAT 0), `LAB_CBC` 250.000 (gói WBC, RBC, HGB, PLT), X-quang 180.000, tẩy giun 50.000, siêu âm 200.000; RBC Chó 5.50–8.50 / Mèo 5.00–10.00 (`10^12/L`); WBC Chó 6.00–17.00; Clavamox 250mg: "Hộp 10 vỉ x 10 viên", Amoxicillin 200 mg + Clavulanic acid 50 mg, đơn vị "Viên", giá 15.000, VAT 0.05, tồn 200; 4 thuốc tồn 200 / 50 / 40 / 100. Giá trị docs **không nêu** (2 dịch vụ còn lại, 3 thuốc còn lại, các khoảng tham chiếu còn lại, mã dịch vụ cụ thể) → chọn hợp lý ở bước P0.3 và **ghi bổ sung vào dòng này**. | Lịch trình Task 1.2, 3.1, 4.1; Nghiệp vụ mục 21; Ngoại lệ EX-20 |
| **D-04** | Mật khẩu: `admin` / `Admin@123` (theo `fe/README.md`); 7 tài khoản demo dùng chung `Demo@123`. UUID cố định: admin `019a9442-d800-7729-87cc-fbb1ceda8817`; demo `019a9442-d810-7000-8000-00000000000N` (N=2 bs_tien … 8 khach_lan theo bảng Task 1.2.3); thú cưng `019a9442-d820-7000-8000-00000000000N`. | Lịch trình Task 1.2.3 ghi `<mật khẩu demo>` |
| **D-05** | Phiên bản: giữ `pom.xml` hiện có (Spring Cloud 2025.1.3, MapStruct 1.6.3) — docs ghi "2025.1.2 trở lên", "MapStruct 1.5+". Biên dịch `release 21` trên JDK 22. | Quy chuẩn Ch.1 |
| **D-06** | Hợp đồng API: backend theo docs v4.0 (Quy chuẩn 3.2 + Lịch trình). `fe/src/api/endpoints.js` (v3.0) không quyết định tên endpoint; chỗ lệch ghi ở mục 5 để FE sửa. Endpoint FE cần mà docs **không có** được thêm trong bước tương ứng, theo đúng tiền tố service ở Quy chuẩn 3.2, và ghi vào mục 5. | Quy chuẩn là "tài liệu quy chuẩn bắt buộc" |
| **D-07** | CORS Gateway cho phép `http://localhost:3000` (FE thật) và `http://localhost:5173` (docs). | FE dùng CRA cổng 3000; docs viết cho Vite 5173 |
| **D-08** | WebSocket: hỗ trợ đủ topic docs (`/topic/lobby`, `/topic/doctor/{id}`, `/topic/lab`, `/topic/imaging`, `/topic/admin`, `/user/queue/notifications`) **và** `/topic/role/{role}` mà `fe/src/api/stomp.js` đang subscribe. Cách xác thực WebSocket chốt ở P12.1. | Lịch trình Task 5.1; `fe/src/api/stomp.js` |
| **D-09** | Một `vetclinic-backend/Dockerfile` multi-stage dùng chung, chọn module bằng `ARG MODULE`; image chạy JRE 21. | `Dockerfile` hiện rỗng, chỉ có một file |
| **D-10** | E2E: `e2e/lib.sh` (curl + đọc JSON bằng `node -e`), `e2e/env.sh` (UUID cố định D-04, cổng), mỗi bước một `e2e/<bước>_*.sh`, `e2e/run_all.sh` chạy tuần tự trên CSDL vừa dựng lại. | Máy không có `jq`; `fe/README.md` tham chiếu `../e2e/` |
| **D-11** | `notification-service` không có CSDL (Kiến trúc mục 3) nhưng Quy chuẩn 3.2 / FE cần `GET /api/v1/notifications`, `POST /{id}/read` → lưu thông báo **trong bộ nhớ** theo người dùng (giới hạn N mục, mất khi khởi động lại). Chốt lại ở P12.1 nếu người dùng muốn khác. | Mâu thuẫn Kiến trúc ↔ Quy chuẩn |
| **D-12** | URL ảnh ký tạm `/files/**` (Quy chuẩn 7.5) không có trong danh sách route Gateway (Task 1.5.2) → thêm route `/files/**` → `clinical-service`, công khai ở Gateway, `clinical-service` kiểm tra chữ ký + hạn. | Quy chuẩn 7.5 ↔ Lịch trình 1.5.2 |
| **D-13** | Thu ngân / Lễ tân tạo hồ sơ chủ nuôi tại quầy (FR-09, UC-18, `registered_channel = AT_CLINIC`) và tìm khách (FR-08) chưa có endpoint trong docs → thêm ở `auth-service` (P3.5) với tiền tố `/api/v1/users/**`, quyền `RECEPTIONIST`/`ADMIN`; tên cụ thể ghi vào mục 5 khi làm. | FR-08, FR-09 ↔ Quy chuẩn 3.2 |
| **D-14** | "Rate Limiting" ở Gateway (Kiến trúc mục 3) không có chi tiết và Gateway không kết nối Redis → hoãn sang P13 (tùy chọn, bộ đếm trong bộ nhớ). | Kiến trúc mục 3, 4.2 |
| **D-15** | Git: nhánh `develop`, mỗi bước một commit `be <bước>: …`, push `origin develop` sau mỗi bước, không `--force`. | Yêu cầu người dùng ghi trong `.claude/commands/v4-next.md` |
| **D-16** | Tên starter theo phiên bản thật: `spring-boot-starter-webmvc` (Boot 4 đổi tên, docs ghi `spring-boot-starter-web`) và `spring-cloud-starter-gateway-server-webflux` (Spring Cloud 2025.x, docs ghi `spring-cloud-starter-gateway`). | Quy chuẩn 11.1, Task 1.5.1 viết theo tên cũ (P0.1) |
| **D-17** | Starter chỉ được thêm vào service ở bước cấu hình nó (JPA + MySQL ở bước tầng dữ liệu, Security ở P1.2, AMQP ở P1.4, OpenFeign + Resilience4j ở bước có Feign client, Redis ở P4.1 / P6.1, WebSocket + Mail ở P12) — thêm sớm mà chưa cấu hình thì ứng dụng không khởi động được. | P0.1 |
| **D-18** | VIEW giá hiện hành (`v_current_service_prices`, `v_current_medicine_prices`) so sánh `effective_from/to` (DATETIME giờ phòng khám) với `DATE_ADD(UTC_TIMESTAMP(), INTERVAL 7 HOUR)` thay vì `NOW()`, để kết quả không phụ thuộc múi giờ phiên MySQL (server chạy +00:00; Việt Nam không có giờ mùa hè). Cột VIEW docs không quy định → chọn: `v_service_invoice_amounts` (`invoice_id, invoice_code, visit_service_detail_id, visit_id, service_id, category_code, quantity, unit_price, vat_rate, discount_amount, payment_status, amount_before_vat, vat_amount, gross_amount, payable_amount`), `v_medicine_invoice_amounts` (tương tự, kèm `prescription_id`), hai VIEW giá kèm `code, name, category_id, is_active`; mọi số tiền `ROUND(…, 2)`. | Task 1.2 bước 3 (`SELECT code, price FROM v_current_service_prices`), ERD mục 6 (P0.2) |
| **D-19** | `db/schema_current.sql` ghi chú cột bằng `COMMENT` MySQL ở các cột trạng thái / khóa ngoại logic (`LFK: <csdl>.<bảng>(id)`); đặt tên ràng buộc `uk_*`, `idx_*`, `fk_*`, `chk_*` (tên `idx_visits_doctor_status`, `idx_appointments_slot` theo docs; các tên còn lại tự đặt). Có thêm vài index hỗ trợ khóa ngoại ngoài mục 5 của ERD (ví dụ `user_roles(role_id)`, `lab_test_results(lab_test_item_id)`). | ERD mục 5 liệt kê index có chủ đích, không liệt kê tên (P0.2) |

---

## 5. Lệch hợp đồng API giữa `fe/src/api/endpoints.js` (v3.0) và docs v4.0

> Backend làm theo cột "docs v4.0" (D-06). Cột "Xử lý" cập nhật khi làm bước tương ứng. FE (Linh) sửa `endpoints.js` theo bảng này.

| Chức năng | FE đang gọi | docs v4.0 | Xử lý (bước) |
| :--- | :--- | :--- | :--- |
| Hồ sơ của tôi | `GET/PUT /api/v1/auth/me` | `GET /api/v1/users/me`, `PUT /api/v1/users/{id}/profile` | P3.4 |
| Đổi mật khẩu | `POST /api/v1/auth/change-password` | (không có) | Thêm (P3.5) |
| Quản lý tài khoản | `/api/v1/auth/users/**`, `…/status`, `…/role` (1 vai trò) | `/api/v1/staff/**`, `/api/v1/users/{id}/lock|unlock|deactivate`, `PUT /users/{id}/roles` (nhiều vai trò) | P3.4 |
| Danh mục dịch vụ | `/api/v1/clinical/services` | `/api/v1/catalog/services` (+ `/prices`) | P4.2 |
| Khoảng tham chiếu | `PUT …/lab-test-items/{id}/ranges/{speciesId}` | `…/lab-test-items/{code}/reference-ranges` | P4.2 |
| Sinh hiệu & hồ sơ khám | `PUT …/pet-visits/{id}/clinical-info` | `POST …/vital-signs`, `PUT …/medical-record` | P6.5 |
| Dịch vụ tại phòng | body `{services}` | body `{serviceIds}` | P7.1 |
| Đơn thuốc | `/api/v1/pharmacy/prescriptions/**`, tạo hóa đơn thuốc thủ công | `PUT /api/v1/clinical/pet-visits/{id}/prescription`; hóa đơn thuốc tự tạo từ sự kiện, `GET /api/v1/billing/medicine-invoices?visitId=` | P9.1, P10.1 |
| Nhập / cân chỉnh kho | `POST /api/v1/pharmacy/inventory/import|adjust` (body có `medicineId`) | `POST /api/v1/pharmacy/medicines/{id}/import|adjust` | P8.2 |
| Báo cáo | `/clinical/reports/*`, `/billing/reports/revenue`, `/appointments/reports/summary` | `/api/v1/reports/**` (`reporting-service`) | P11.2 |
| Ảnh CĐHA | `GET …/imaging-attachments/{id}/file` (blob) | `GET …/imaging-attachments/{id}/url` (URL ký tạm) + `/files/**` | P7.4 |
| Lịch hẹn | `…/{id}/history`, `…/{id}/reschedule`, `…/{id}/no-show` | không có (NO_SHOW do scheduler) | `history` thêm (P5.2); `reschedule`, `no-show` thủ công: không làm trừ khi người dùng yêu cầu |
| WebSocket | `/topic/role/{role}`, `/user/queue/notifications` | topic theo phòng / Bác sĩ | Hỗ trợ cả hai (D-08, P12.1) |

---

## 6. Lộ trình chi tiết

### GIAI ĐOẠN P0 — NỀN MÓNG

#### [x] P0.1 — Nhánh `develop`, khung Maven 9 module
- **Tham chiếu:** Quy chuẩn Ch.1, 2.1–2.3, 11.1; Task 1.1.
- **Làm:**
  - Tạo nhánh `develop` từ `main`.
  - `pom.xml` cha: thêm module `reporting-service`; `pluginManagement` cho `spring-boot-maven-plugin`; giữ thứ tự annotation processor lombok → binding → mapstruct.
  - 9 module với `pom.xml` con đúng starter (Gateway: webflux + gateway; servlet services: web, security, data-jpa, validation, actuator, eureka-client, openfeign, resilience4j, amqp theo nhu cầu; `common-library` là jar thường, phụ thuộc servlet `optional`); lớp `*Application` + `application.yml` tối thiểu (tên, cổng). Chưa cấu hình DB.
  - `.gitignore` đủ cho Maven/IDE.
- **Kiểm tra:** `mvn -q clean verify` → BUILD SUCCESS cả 9 module.
- **Kết quả (20/11/2026):** Đã tạo nhánh `develop`. `mvn -q clean verify` BUILD SUCCESS (JDK 22, `release 21`), ra 9 jar. **8 test `contextLoads`** (8 module ứng dụng): 8 pass, 0 fail, 0 skip; Gateway khởi động dạng reactive, Eureka Server khởi động với cổng ngẫu nhiên. `common-library` là jar thường (chỉ có `package-info`, các phụ thuộc webmvc / security / openfeign để `optional`). Chưa có e2e (bước chưa có service chạy trong Docker). `pom.xml` cha: thêm module `reporting-service`, `maven.compiler.release=21`, `pluginManagement` cho `spring-boot-maven-plugin` (loại Lombok khỏi jar). Lệch docs: D-16, D-17. `.gitignore` sẵn có đã đủ (`target/`, IDE).

#### [x] P0.2 — Lược đồ v4.0: `db/schema_current.sql` (52 bảng, 40 khóa ngoại, 4 VIEW)
- **Tham chiếu:** ERD mục 1.2, 2, 4, 5, 6; Enum mục C; Kiến trúc 4.1; D-02.
- **Làm:** tạo 5 CSDL `utf8mb4_unicode_ci`; viết đủ 52 bảng đúng từng cột / kiểu / NULL / DEFAULT / UNIQUE / CHECK của từ điển dữ liệu; 40 khóa ngoại nội bộ (auth 7, appointment 1, clinical 24, billing 8, reporting 0) với `ON DELETE CASCADE` đúng chỗ; index mục 5 (tên `idx_…`); khóa ngoại logic ghi chú `-- LFK: db.bảng(id)`; 4 VIEW `v_service_invoice_amounts` (kèm `category_code`), `v_current_service_prices`, `v_medicine_invoice_amounts`, `v_current_medicine_prices`. Không có dữ liệu.
- **Kiểm tra:** nạp vào MySQL 8 tạm (Docker) → các truy vấn Task 1.2 bước 2: auth 9 · appointment 4 · clinical 24 + 2 VIEW · billing 10 + 2 VIEW · reporting 5; `fk_count = 40`; 0 cột `enum`.
- **Kết quả (21/11/2026):** `db/schema_current.sql` (5 CSDL, 52 bảng, 40 khóa ngoại, 4 VIEW), nạp bằng đúng cơ chế initdb vào `mysql:8.0` (8.0.46, `--default-time-zone=+00:00`) **không lỗi**. Số đếm bằng `db/verify_schema.sql` (file mới, P0.5 dùng lại): auth 9 · appointment 4 · clinical 24 + 2 VIEW · billing 10 + 2 VIEW · reporting 5 → **52 bảng, 4 VIEW**; khóa ngoại **1 / 7 / 8 / 24 = 40** (reporting 0); **0 cột ENUM**. Thử hành vi bằng dữ liệu giả rồi `ROLLBACK` (kịch bản tạm, không lưu): `v_current_service_prices` chỉ trả dòng giá đang hiệu lực (100000.00, bỏ dòng giá cũ đã đóng); `v_service_invoice_amounts` 2 × 250000 × 1.10 − 30000 = 520000.00; `v_medicine_invoice_amounts` 10 × 15000 × 1.05 = 157500.00, hóa đơn chưa có dòng ra 0.00 (không NULL); CHECK chặn giá âm / tồn âm (3819), UNIQUE `prescription_id` (1062), khóa ngoại vật lý (1452); `UPDATE … WHERE quantity_on_hand >= :qty` trừ 300 khi tồn 200 → 0 dòng bị đổi. Bất biến `quantity_on_hand = SUM(inventory_transactions.quantity)` **không có ràng buộc ở CSDL** — do ứng dụng giữ bằng giao dịch (P8.2, P10.2); kiểm bằng dữ liệu seed ở P0.3. `mvn -q clean verify` vẫn xanh (8 test, 0 fail). Chưa có e2e (bước chưa có service chạy). Image `mysql:8.0` đã tải về máy, container tạm đã xóa. Lệch docs: D-18, D-19. `docs/schema_init.sql` chưa đồng bộ (làm ở P0.5, D-02).

#### [ ] P0.3 — Dữ liệu danh mục khởi tạo trong lược đồ
- **Tham chiếu:** Task 1.2.2; Enum mục B (L1–L4); D-03, D-04.
- **Làm:** thêm vào cuối `db/schema_current.sql` (biến `@u_admin`, `@s_exam`, `@s_cbc`, `@s_xray`, `@s_deworm`, `@m_amox`… UUID cố định): 6 vai trò (`is_system`), tài khoản `admin` + `user_profiles` + `staff_profiles`, 2 loài, 9 nhóm dịch vụ (đúng `queue_type`, `requires_prepayment`), 7 dịch vụ + 7 dòng giá (`effective_from` = 2026-01-01), 4 chỉ số XN + khoảng tham chiếu 2 loài + gói CBC, 4 nhóm thuốc, 4 thuốc + thành phần + giá + `medicine_stocks` + dòng `IMPORT` đầu kỳ. Ghi giá trị tự chọn vào D-03.
- **Kiểm tra:** `SELECT code, price FROM v_current_service_prices` → 7 dòng (EXAM_GEN 100000.00…); bất biến kho `quantity_on_hand = SUM(inventory_transactions.quantity)` (200, 50, 40, 100); BCrypt của `Admin@123` đúng (kiểm bằng test nhỏ ở P3.2 nếu chưa có công cụ).
- **Kết quả:** –

#### [ ] P0.4 — Dữ liệu demo `db/seed_current.sql` + biến kiểm thử
- **Tham chiếu:** Task 1.2.3 (bảng 8 tài khoản, Lu & Milo); D-04, D-10.
- **Làm:** 7 tài khoản demo (users, user_roles, user_profiles, staff_profiles có phòng P101–P103/P201/P202, veterinarian_profiles cho 3 Bác sĩ, pet_owner_profiles cho `khach_lan`); thú cưng Lu (Mèo) và Milo (Chó, Poodle) của `khach_lan` với snapshot chủ nuôi. Tạo `e2e/env.sh` (biến `U_*`, `PET_*`, `S_*`, `M_*`, `GW=http://localhost:8080`) và `e2e/lib.sh` (login, gọi API, đọc JSON bằng node, `assert_eq`, `assert_status`, `sql`, `redis`).
- **Kiểm tra:** nạp schema + seed vào MySQL tạm: 8 tài khoản, 3 `veterinarian_profiles`, 2 `pets`; `bash -n e2e/*.sh` không lỗi cú pháp.
- **Kết quả:** –

#### [ ] P0.5 — Docker Compose hạ tầng + `.env.example`
- **Tham chiếu:** Kiến trúc mục 8; Task 1.2.1; `docker-compose.dev.yml`; D-09.
- **Làm:** `docker-compose.yml` với `mysql-server` (MySQL 8.0, nạp `db/schema_current.sql` rồi `db/seed_current.sql` qua `/docker-entrypoint-initdb.d`, `default-time-zone='+00:00'`, healthcheck), `redis` (`redis:7-alpine --appendonly yes --appendfsync everysec`, volume `redis-data`), `rabbitmq-broker` (management), `mailpit`, volume `imaging-uploads`, network chung; chừa chỗ cho service ứng dụng (thêm dần ở từng giai đoạn). `.env.example` đủ biến (DB, RabbitMQ, Redis, `JWT_SECRET`, `STORAGE_SECRET`, mail, cổng). Đồng bộ `docs/schema_init.sql`, `docs/seed_demo_data.sql` (D-02). Viết `e2e/run_all.sh` + `e2e/P0_infra.sh` (đếm bảng/FK/VIEW/ENUM, bất biến kho, `CONFIG GET appendonly`).
- **Kiểm tra:** `docker compose down -v && docker compose up -d` → 4 container healthy; `bash e2e/run_all.sh` xanh; RabbitMQ UI `:15672` mở được.
- **Kết quả:** –

> **Kết quả giai đoạn P0:** –

---

### GIAI ĐOẠN P1 — `common-library`

#### [ ] P1.1 — DTO, mã lỗi, tiện ích
- **Tham chiếu:** Quy chuẩn Ch.4, 5.1, 10.2 (SecurityUtils); Task 1.3.1–1.3.2.
- **Làm:** `ApiResponse<T>`, `PageResponse<T>`; `ErrorCode` đủ **49 mã** đúng chuỗi / thông điệp / HTTP status; `AppException`; `SecurityUtils.getCurrentUserId(): UUID`; `ClinicTime` (múi `Asia/Ho_Chi_Minh`); `RoleCodes`, `CategoryCodes`.
- **Kiểm tra:** `ApiResponseTest`; test đếm `ErrorCode.values().length == 49` và không trùng mã; `mvn -q -pl common-library verify`.
- **Kết quả:** –

#### [ ] P1.2 — Auto-configuration servlet: lỗi, bảo mật, Feign
- **Tham chiếu:** Quy chuẩn 2.2, 5.2, 9.1, 10.2; Task 1.3.3.
- **Làm:** `GlobalExceptionHandler` (AppException, AccessDenied → 403, validation → `SYS_1001` + map lỗi trường, JSON hỏng, `ObjectOptimisticLockingFailureException` → `SYS_1005`, tham số sai kiểu → `SYS_1001`, còn lại → `SYS_1000` không lộ stacktrace), `FeignExceptionHandler`, `CommonSecurityConfig` (stateless, 401/403 JSON, `/internal/**` + actuator health permitAll), `HeaderAuthenticationFilter` (nhiều vai trò, thêm `ROLE_` một lần, không `@Component`), `FeignClientInterceptor` (chuyển tiếp `X-User-Id`, `X-User-Roles`), `CustomFeignErrorDecoder`, `CommonWebAutoConfiguration` + `AutoConfiguration.imports`.
- **Kiểm tra:** `GlobalExceptionHandlerTest` (`INVOICE_ALREADY_PAID` → 409 `BILL_1403`), test filter (`"VETERINARIAN,ADMIN"` → 2 authority, không `ROLE_ROLE_`), test auto-config không nạp trong ứng dụng reactive (`ApplicationContextRunner`).
- **Kết quả:** –

#### [ ] P1.3 — Enum, sự kiện, hằng định tuyến
- **Tham chiếu:** Enum mục C (18 enum + `LabEvaluation`); Kiến trúc 5.2; Quy chuẩn 9.2; Task 1.3.4.
- **Làm:** 18 enum + `LabEvaluation` (kèm hàm đánh giá từ giá trị và min/max); `BaseEvent` (`eventId` UUIDv7, `eventType`, `occurredAt`, `aggregateId`); **17 record sự kiện** với payload đúng Kiến trúc 5.2 (ví dụ `ServiceInvoicePaidEvent` có `visitId`, `cashierId`, `paidAt`, `emergency`, `doctorId`, tên thú cưng/chủ, danh sách dòng `invoiceId, serviceId, code, name, categoryCode, queueType, quantity, amount`); `EventRoutes` (exchange `clinic.events`, 17 routing key), `QueueNames` (queue `<service>.<listener>`); tiện ích sinh UUIDv7 cho `eventId`.
- **Kiểm tra:** test tuần tự hóa / giải tuần tự JSON mọi sự kiện bằng Jackson 3 (khứ hồi bằng nhau); test `LabEvaluation` (4.20 với 5.00–10.00 → `LOW`).
- **Kết quả:** –

#### [ ] P1.4 — Transactional Outbox, consumer idempotent, cấu hình RabbitMQ chung
- **Tham chiếu:** Quy chuẩn 9.2; Kiến trúc 5.2–5.3; ERD 2.6; Task 1.3.5.
- **Làm:** entity `OutboxEvent` + repository (`lockNextBatch` native `… FOR UPDATE SKIP LOCKED`, `deletePublishedBefore`), `OutboxWriter` (`MANDATORY`), `OutboxRelay` (`@Scheduled(fixedDelay=500)`, publisher confirm, lùi 1s→2s→4s… tối đa 5 phút, `FAILED` sau 10 lần, dừng lô khi lỗi để giữ thứ tự, dọn `PUBLISHED` > 7 ngày lúc 03:00); `ProcessedEvent` + `IdempotentConsumer`; cấu hình RabbitMQ chung (TopicExchange `clinic.events`, converter JSON Jackson 3, tiện ích khai báo queue + DLQ + binding, retry 3 lần rồi DLQ); `OutboxAutoConfiguration` có điều kiện (có JPA + RabbitTemplate).
- **Kiểm tra:** `OutboxRelayTest` (Testcontainers MySQL + RabbitMQ): rollback → 0 tin; commit 3 dòng → 3 tin đúng thứ tự, 3 dòng `PUBLISHED`; dừng RabbitMQ → giữ `PENDING`, `attempt_count` tăng; bật lại → gửi đủ. `IdempotentConsumerTest`: gọi 2 lần cùng `eventId` → action chạy 1 lần.
- **Kết quả:** –

> **Kết quả giai đoạn P1:** –

---

### GIAI ĐOẠN P2 — HẠ TẦNG SPRING CLOUD

#### [ ] P2.1 — `service-registry` + Dockerfile chung
- **Tham chiếu:** Task 1.4; D-09.
- **Làm:** Eureka Server `:8761` (`register-with-eureka=false`, `fetch-registry=false`), không dùng `common-library`; `vetclinic-backend/Dockerfile` multi-stage (`ARG MODULE`, cache Maven, JRE 21, healthcheck actuator); thêm `service-registry` vào `docker-compose.yml`.
- **Kiểm tra:** `docker compose up -d --build service-registry` → healthy; `curl :8761/actuator/health` UP; dashboard mở được.
- **Kết quả:** –

#### [ ] P2.2 — `api-gateway`: định tuyến, JWT, CORS
- **Tham chiếu:** Quy chuẩn 10.1; Kiến trúc 7; Task 1.5; D-07, D-12.
- **Làm:** route theo Task 1.5.2 (+ `/files/**` → clinical); `JwtValidator` (HMAC-SHA256, `JWT_SECRET` chung với auth); `JwtAuthenticationFilter` (order −100: chặn `/internal/**` 403 `SYS_1003`; xóa `X-User-*`; public paths login/refresh/register/slots/`/files/**`; thiếu/sai/hết hạn → 401 `SYS_1002` JSON; hợp lệ → gắn `X-User-Id`, `X-User-Roles`); CORS (D-07); thêm vào compose (cổng 8080 duy nhất mở ra ngoài).
- **Kiểm tra:** unit test filter bằng `WebTestClient` / token tự ký (thiếu token → 401, token hết hạn → 401, header giả bị xóa, `/internal/x` → 403, token hợp lệ → header đúng); e2e `P2_gateway.sh` (3 kiểm tra của Task 1.5 — phần cần token thật chạy lại ở P3.2).
- **Kết quả:** –

> **Kết quả giai đoạn P2:** –

---

### GIAI ĐOẠN P3 — `auth-service` (:8081)

#### [ ] P3.1 — Tầng dữ liệu auth
- **Tham chiếu:** Task 2.1; ERD 4.1.
- **Làm:** `application.yml` (DB `pet_clinic_auth_db`, `validate`, Eureka, RabbitMQ); entity `Role` (Short), `User` (UUIDv7, `@ManyToMany` qua `user_roles`, `@Version`), `UserProfile`, `StaffProfile`, `VeterinarianProfile`, `PetOwnerProfile` (`@MapsId`), `RefreshToken` (`token_hash`); repository (`findByUsername` nạp kèm vai trò + hồ sơ); thêm vào compose.
- **Kiểm tra:** `UserRepositoryTest` (Testcontainers + schema + seed): `bs_tien` có `VETERINARIAN`, phòng P101, chứng chỉ `CCHN-HN-0102`; context khởi động không lỗi validate; đăng ký Eureka `AUTH-SERVICE`.
- **Kết quả:** –

#### [ ] P3.2 — Đăng nhập, đăng ký khách, cấp JWT
- **Tham chiếu:** Task 2.2; Quy chuẩn 10.3 (bảng token); NFR-02.
- **Làm:** `JwtTokenProvider` (claims `sub`, `username`, `roles` danh sách không tiền tố, `fullName`, `roomNumber`; TTL 30 phút), `TokenHasher` (SHA-256, token ngẫu nhiên 256 bit Base64URL), `AuthService.login` (BCrypt, trạng thái `ACTIVE` → khác thì `AUTH_1107`, sai → `AUTH_1103`, cập nhật `last_login_at`), `POST /api/v1/auth/register` (users + PET_OWNER + profiles `ONLINE`, trùng SĐT → `AUTH_1102`).
- **Kiểm tra:** unit test login/register; e2e `P3_auth_login.sh` (Task 2.2 bước 1–5: lấy 7 token `$TOKEN_*`, JWT có `"roles":["VETERINARIAN"]`, DB chỉ có hash, sai mật khẩu → 401 `AUTH_1103`) + chạy lại phần token thật của Task 1.5.
- **Kết quả:** –

#### [ ] P3.3 — Refresh token xoay vòng, phát hiện dùng lại, đăng xuất
- **Tham chiếu:** Task 2.3; Quy chuẩn 10.3 mục 2–4.
- **Làm:** `RefreshTokenService.refresh` (không thấy → `AUTH_1104`; đã thu hồi → thu hồi toàn bộ phiên + `AUTH_1105`; hết hạn → `AUTH_1106`; tài khoản không ACTIVE → `AUTH_1107`), `POST /api/v1/auth/logout`.
- **Kiểm tra:** unit test 4 nhánh; e2e Task 2.3 (refresh → cặp mới; dùng lại token cũ → 401 `AUTH_1105`, mọi token của user `revoked = 1`).
- **Kết quả:** –

#### [ ] P3.4 — Nhân sự, hồ sơ, vai trò, khóa / ngừng + sự kiện
- **Tham chiếu:** Task 2.4.1–2.4.3; Quy chuẩn 3.2 (auth); BR-13, BR-37, BR-39, BR-41; Kiến trúc 5.2 (`UserProfileUpdatedEvent`, `UserStatusChangedEvent`).
- **Làm:** `POST /api/v1/staff` (1 giao dịch: users + roles + user_profiles + staff_profiles [+ veterinarian_profiles bắt buộc khi có `VETERINARIAN`, thiếu → `AUTH_1108`]); `GET /api/v1/staff`, `/staff/{id}`, `/staff/doctors`; `GET /api/v1/users/me`; `PUT /users/{id}/profile`, `/staff/{id}/vet-profile`, `/users/{id}/roles`; phòng làm việc; `POST /users/{id}/lock|unlock|deactivate`; `GET /api/v1/roles`; outbox `UserStatusChangedEvent` / `UserProfileUpdatedEvent` cùng giao dịch; `@PreAuthorize("hasRole('ADMIN')")`.
- **Kiểm tra:** unit test; e2e Task 2.4 bước 3–4 (VET tạo staff → 403 `SYS_1003`; Bác sĩ thiếu vetProfile → 400 `AUTH_1108`; khóa `bs_mai` → outbox `PUBLISHED` ≤ 1 s, `bs_mai` đăng nhập → 401 `AUTH_1107`; mở khóa lại).
- **Kết quả:** –

#### [ ] P3.5 — API nội bộ + bổ sung cho quầy và FE
- **Tham chiếu:** Task 2.4.4; Kiến trúc 5.1; D-13; mục 5.
- **Làm:** `GET /internal/users/active-doctors/count`, `/internal/users/{id}` (họ tên, SĐT, vai trò, phòng, trạng thái), `/internal/users/doctors?status=ACTIVE`; tạo + tìm hồ sơ chủ nuôi tại quầy (D-13, `AT_CLINIC`, mật khẩu tạm); đổi mật khẩu của tôi. Ghi tên endpoint mới vào mục 5.
- **Kiểm tra:** e2e Task 2.4 bước 1–2 (`:8081/internal/users/active-doctors/count` → 3; qua Gateway → 403); test tạo khách tại quầy (trùng SĐT → `AUTH_1102`).
- **Kết quả:** –

> **Kết quả giai đoạn P3:** –

---

### GIAI ĐOẠN P4 — `clinical-service` NỀN (:8083)

#### [ ] P4.1 — Cấu hình + 24 entity clinical
- **Tham chiếu:** Task 3.1.1; ERD 4.3; Quy chuẩn 7.2, 11.2 (mẫu entity).
- **Làm:** `application.yml` (DB clinical, Redis `timeout: 1s`, RabbitMQ, `app.storage.root`, `app.storage.secret`, multipart); entity cho đủ 24 bảng (danh mục, giá, thú cưng, đợt khám, sinh hiệu, hồ sơ khám, lịch sử, chỉ định, kết quả XN/CĐHA, ảnh, hóa đơn dịch vụ, đơn thuốc, lịch sử phiếu, outbox, processed) với `@Version` đúng chỗ; repository cơ bản; thêm vào compose (gắn volume `imaging-uploads`).
- **Kiểm tra:** context khởi động với Testcontainers (validate qua cả 24 bảng); đăng ký Eureka `CLINICAL-SERVICE`.
- **Kết quả:** –

#### [ ] P4.2 — Danh mục & bảng giá có lịch sử
- **Tham chiếu:** Task 3.1.3–3.1.4; Quy chuẩn 7.4; FR-03 → FR-07; EX-20 (phần dịch vụ).
- **Làm:** CRUD `species`, `service_categories`, `services` (xóa mềm), `lab_test_items`, khoảng tham chiếu, gói XN; `ServicePriceBook` (`current` → `CLIN_1315`; `changePrice` → `BILL_1410`); `GET /api/v1/catalog/services?categoryCode=` (kèm giá hiện hành từ VIEW), `GET/POST /api/v1/catalog/services/{id}/prices`; quyền ADMIN cho ghi, nhân viên cho đọc.
- **Kiểm tra:** unit test `ServicePriceBook`; e2e Task 3.1 (RBC 2 khoảng; gói CBC 4 chỉ số; đổi giá ngày mai → 2 dòng, hôm nay vẫn 100000; `effectiveFrom` sớm hơn → 400 `BILL_1410`; dọn dòng thử).
- **Kết quả:** –

#### [ ] P4.3 — Thú cưng, API nội bộ, cập nhật snapshot
- **Tham chiếu:** Task 3.1.2; Kiến trúc 5.1 (`GET /internal/pets/{id}`), 5.2 (`PetUpdatedEvent`, `UserProfileUpdatedEvent`); FR-10, FR-11.
- **Làm:** CRUD `/api/v1/pets` (chủ nuôi chỉ thấy / sửa thú của mình; Lễ tân tạo cho khách); tìm theo `ownerId`, `ownerPhone` (snapshot, không gọi auth); snapshot chủ nuôi lấy qua Feign `GET /internal/users/{id}` lúc tạo (không fallback); xóa mềm `deleted_at`; sửa tên / chủ → outbox `PetUpdatedEvent`; `GET /internal/pets/{id}`; listener `clinical.snapshot-updater` (`UserProfileUpdatedEvent` → `pets.owner_*_snapshot`, `pet_visits.doctor_name_snapshot`).
- **Kiểm tra:** unit + Testcontainers listener (nhận 2 lần → 1 lần cập nhật); e2e: `khach_lan` thấy Lu, Milo; `GET :8083/internal/pets/$PET_LU` trả tên + chủ.
- **Kết quả:** –

> **Kết quả giai đoạn P4:** –

---

### GIAI ĐOẠN P5 — `appointment-service` (:8082)

#### [ ] P5.1 — Tầng dữ liệu, Feign, khung giờ động
- **Tham chiếu:** Task 2.5, 2.6; FR-13; BR-04, BR-05; Nghiệp vụ mục 5 (khung giờ).
- **Làm:** entity `Appointment` (14 trường, `@Version`), `AppointmentStatusHistory`; repository (`findByOwnerIdOrderByAppointmentDateDesc`, đếm theo khung); `AuthClient` (`active-doctors/count`), `ClinicalClient` (`/internal/pets/{id}`) có Circuit Breaker; `GET /api/v1/appointments/slots?date=` công khai: 14 khung (08:00–11:00, 13:30–16:30), sức chứa `N_active × 2`, đếm `PENDING, CONFIRMED, CHECKED_IN`; thêm vào compose.
- **Kiểm tra:** unit test tính khung; e2e Task 2.6 (14 khung, `maxCapacity 6`, `availableCount 6`, không cần token).
- **Kết quả:** –

#### [ ] P5.2 — Đặt, duyệt, hủy lịch + lịch sử
- **Tham chiếu:** Task 2.7; SM-04; FR-12, FR-14 → FR-16; UC-14 → UC-17; EX-01 (giải phóng chỗ).
- **Làm:** `POST /api/v1/appointments` (PET_OWNER; Feign kiểm tra thú thuộc chủ; còn chỗ → `APPT_1203`; mã `APT-YYYYMMDD-XXX`; snapshot; outbox `AppointmentBookedEvent`); `POST /by-receptionist` (`CONFIRMED`, `PHONE`/`WALK_IN`); `/{id}/confirm` (RECEPTIONIST); `/{id}/cancel` (lý do bắt buộc vào `notes`; chủ nuôi chỉ hủy trước ≥ 2 giờ → `APPT_1204`); `GET` danh sách (chủ nuôi: của mình; Lễ tân: theo ngày/trạng thái), chi tiết, `/{id}/history` (mục 5); mọi đổi trạng thái ghi lịch sử + outbox `AppointmentStatusChangedEvent`.
- **Kiểm tra:** unit test guard SM-04; e2e Task 2.7 (201, mã `APT-…-001`, snapshot `Lu`; confirm; lịch sử 2 dòng `NULL→PENDING` ($U_LAN), `PENDING→CONFIRMED` ($U_HOA)).
- **Kết quả:** –

#### [ ] P5.3 — Quét NO_SHOW + listener sự kiện
- **Tham chiếu:** Task 2.8, 3.2.5; Quy chuẩn 11.3; EX-01.
- **Làm:** `AppointmentNoShowScheduler` (cron `0 */5 7-21 * * *` múi VN; quá `date + start_time + 30'`; lịch sử `changed_by_user_id = NULL`; outbox `AppointmentNoShowEvent`); listener `appointment.visit-checked-in` (`CONFIRMED → CHECKED_IN` + lịch sử; nếu đã `NO_SHOW` thì log cảnh báo), `appointment.snapshot-updater` (`UserProfileUpdatedEvent`, `PetUpdatedEvent`); tất cả idempotent + DLQ.
- **Kiểm tra:** test scheduler (40 phút trước → NO_SHOW, 20 phút trước → giữ); Testcontainers listener nhận trùng → 1 dòng lịch sử. (Luồng check-in thật kiểm ở P6.2.)
- **Kết quả:** –

> **Kết quả giai đoạn P5:** –

---

### GIAI ĐOẠN P6 — `clinical-service`: HÀNG ĐỢI REDIS, TIẾP ĐÓN, THU PHÍ KHÁM, KHÁM GĐ 1

#### [ ] P6.1 — Hạ tầng hàng đợi Redis
- **Tham chiếu:** Quy chuẩn 9.3; ERD mục 3; SM-07; Q1–Q6.
- **Làm:** `QueueRedisRepository` + 4 Lua script (`issue_ticket` dedupe theo khóa sự kiện + `INCR` số phiếu theo ngày/loại, `start_ticket` kiểm `WAITING` + khóa `queue:busy:{doctorId}`, `finish_ticket`, `move_ticket` giữ `score` và số phiếu); `QueueTicketView`; đọc hàng đợi (`ZRANGE`, `ZCARD`, peek head); `markCalled`; ánh xạ lỗi Redis → `CLIN_1318`; công thức `score`.
- **Kiểm tra:** Testcontainers Redis: phát trùng `eventId` → 1 phiếu; thứ tự cấp cứu → ưu tiên 1 → thường theo giờ thu; 10 lệnh `start` song song cùng phiếu → đúng 1 thành công (NFR-10); `move` giữ số phiếu.
- **Kết quả:** –

#### [ ] P6.2 — Check-in, khách vãng lai, hủy tiếp nhận
- **Tham chiếu:** Task 3.2.1, 3.2.2, 3.2.4; SM-01 T01, T03; Kiến trúc 5.4; EX-02, EX-03.
- **Làm:** `POST /api/v1/clinical/pet-visits/check-in` (Facade: Feign đọc lịch hẹn → `APPT_1205`; giao dịch: `CLIN_1306`, `pet_visits` `WAITING` mã `VISIT-YYYY-XXXX`, lịch sử, dịch vụ `EXAM_GEN` + history `ORDERED`, `service_invoices` `PENDING` giá từ `ServicePriceBook` mã `SINV-YYYY-XXXX`, outbox `VisitCheckedInEvent`); `POST …/{id}/cancel` (T03: phiếu chờ hủy, dịch vụ hủy, hóa đơn chưa thu hủy / đã thu giữ `PAID`, `VisitCancelledEvent`); `GET` danh sách / chi tiết / `…/{id}/history`.
- **Kiểm tra:** unit test guard T01/T03; e2e Task 3.2 bước 1–4 (201 `WAITING`, 1 hóa đơn 100000 `PENDING`, Redis chưa có phiếu, lịch hẹn → `CHECKED_IN` ≤ 1 s; check-in lại → 409 `CLIN_1306`; vãng lai Milo).
- **Kết quả:** –

#### [ ] P6.3 — Thu phí khám → phát phiếu (outbox → listener → Redis)
- **Tham chiếu:** Task 3.2.3b; Quy chuẩn 8.3, 9.3 mục 4; Kiến trúc 5.5; BR-35; EX-04, EX-19.
- **Làm:** `GET /api/v1/clinical/cashier/pending?section=EXAM_FEE`; `POST …/pet-visits/{id}/service-invoices/confirm-payment` (bản đầy đủ theo Quy chuẩn 8.3: `BILL_1401/1403/1408/1409`, `@Version`, outbox `ServiceInvoicePaidEvent` một lần thu); `QueueIssuerListener` (`clinical.queue-issuer.invoice-paid`: gom theo `queueType`, phiếu `DOCTOR` vào Bác sĩ của ca hoặc `UNASSIGNED`, `score` theo `paidAt`; `clinical.queue-issuer.checked-in`: ca cấp cứu → `priority 2`); gửi trực tiếp `QueueTicketIssuedEvent`.
- **Kiểm tra:** e2e Task 3.2 bước 5 (2 hóa đơn `PAID`, phiếu số 1 và 2 trong `UNASSIGNED`, thứ tự đúng; đặt lại outbox `PENDING` → không có phiếu thứ ba — EX-19); EX-04 (cấp cứu có phiếu ngay, đứng đầu).
- **Kết quả:** –

#### [ ] P6.4 — Điều phối: bảng hàng đợi, trạng thái Bác sĩ, phân công
- **Tham chiếu:** Task 3.2.3, 3.3.1, 3.3.2, 3.3.2b; SM-02; Q3; BR-11; EX-05, EX-17.
- **Làm:** `GET …/pet-visits/queue` (danh sách chờ phân công + hàng đợi từng Bác sĩ + `waitingCount` + `suggestedDoctorId`), `GET …/pet-visits/my-queue`; `GET /api/v1/clinical/doctors/status` (Feign danh sách Bác sĩ có cache + fallback; `BUSY` nếu có ca `IN_PROGRESS`); `POST …/{id}/assign-doctor` (Feign không fallback → `CLIN_1316`; không kiểm Bác sĩ rảnh; afterCommit `move_ticket`), `…/unassign-doctor`; listener `clinical.doctor-status` (`UserStatusChangedEvent` LOCKED/INACTIVE → phiếu chờ về `UNASSIGNED`, gỡ `doctor_id` ca `WAITING`).
- **Kiểm tra:** e2e Task 3.3 bước 1–2 (xếp `$VISIT_1`, `$VISIT_2` cho `bs_tien`, `my-queue` = [1, 2], `waitingCount 1→2`); EX-17 (khóa `bs_mai` có 2 phiếu → về `UNASSIGNED`; xếp ca cho `bs_mai` → 409 `CLIN_1316`).
- **Kết quả:** –

#### [ ] P6.5 — Gọi số, bắt đầu khám GĐ 1, sinh hiệu, hồ sơ khám
- **Tham chiếu:** Task 3.3.2c, 3.3.3, 3.3.4; Quy chuẩn 11.2 (lát cắt chuẩn), 6b; SM-01 T02; BR-12, BR-34; EX-10.
- **Làm:** `POST /api/v1/clinical/queue-tickets/{id}/call`, `…/call-next?queueType=` (`CLIN_1311`, `CLIN_1313`, `CLIN_1303`, `CLIN_1302`; chỉ tăng `calledCount`; gửi `PatientCalledEvent`); `POST …/pet-visits/{id}/start-exam` đúng mẫu 11.2 (`CLIN_1314`, tạo `medical_records`, sinh hiệu tùy chọn, afterCommit `start_ticket`); `POST …/vital-signs`, `GET …/vital-signs`; `PUT/GET …/medical-record` (`@Version`, khóa → `CLIN_1317`); `GET /api/v1/pets/{id}/medical-history` (FR-28, FR-67).
- **Kiểm tra:** unit test `startExamination` theo từng guard; e2e Task 3.3 bước 2b–4 (gọi không đổi thứ tự, `calledCount = 1`; `IN_PROGRESS`, phiếu `IN_SERVICE`, 1 dòng sinh hiệu 4.6 kg; `bs_an` → 403 `CLIN_1311`; ca chưa nộp phí → 400 `CLIN_1314`; gọi khi đang khám → 409 `CLIN_1302`).
- **Kết quả:** –

> **Kết quả giai đoạn P6:** –

---

### GIAI ĐOẠN P7 — `clinical-service`: CẬN LÂM SÀNG

#### [ ] P7.1 — Chỉ định CLS, dịch vụ tại phòng, thu tiền CLS → phiếu phòng
- **Tham chiếu:** Task 3.4.1–3.4.3, 3.4.6; SM-01 T04; SM-03; SM-05; BR-19, BR-25, BR-33; Q1(b).
- **Làm:** `POST …/pet-visits/{id}/paraclinical-orders` (chỉ `LABORATORY`/`IMAGING`; `CLIN_1308`, `CLIN_1309`; một giao dịch: chỉ định + hóa đơn snapshot giá, dịch vụ khám `COMPLETED`, phiếu `DOCTOR` → `DONE` + `queue_ticket_histories`, ca → `WAITING_RESULTS`; afterCommit `finish_ticket`; cấp cứu → phát phiếu phòng `priority 2` ngay); `POST …/in-room-services` + `POST /service-details/{id}/perform`; `cashier/pending?section=PARACLINIC`; listener phát phiếu `LABORATORY`/`IMAGING` (gộp dịch vụ cùng phòng của lần thu, `vsdIds`).
- **Kiểm tra:** e2e Task 3.4 (ca → `WAITING_RESULTS`, Bác sĩ `AVAILABLE`; tổng `v_service_invoice_amounts` = 530000; lab/imaging queue trống trước khi thu; thu → 2 phiếu phòng số 1; thu dịch vụ tại phòng khi chưa chốt → 400 `BILL_1409`; thiếu cân nặng → 400 `CLIN_1308`).
- **Kết quả:** –

#### [ ] P7.2 — Hủy dịch vụ, hủy ca GĐ 1
- **Tham chiếu:** Task 3.4.4, 3.4.5; SM-01 T11; SM-03 (hủy); SM-05 (`REFUNDED`); BR-36; EX-08.
- **Làm:** `POST /api/v1/clinical/service-details/{id}/cancel` (`reasonType` CUSTOMER/CLINIC: chưa thu → `CANCELLED`; đã thu + CUSTOMER → giữ `PAID`; đã thu + CLINIC → `REFUNDED` + outbox `ServiceInvoiceRefundedEvent`; phí khám không hoàn → `CLIN_1310`; dịch vụ rời phiếu, phiếu hết dịch vụ → `CANCELLED`; kiểm T06); `POST …/pet-visits/{id}/cancel-exam` (T11, `CLIN_1305` nếu đã có dịch vụ tại phòng `COMPLETED`).
- **Kiểm tra:** unit test ma trận hủy × trạng thái hóa đơn; e2e EX-08 (3 nhánh hóa đơn).
- **Kết quả:** –

#### [ ] P7.3 — Phòng Xét nghiệm
- **Tham chiếu:** Task 3.5; SM-03 trạng thái con; BR-23, BR-24, BR-34; EX-06, EX-07.
- **Làm:** `GET /api/v1/clinical/lab-queue`; `POST /queue-tickets/{id}/start` (phòng: mọi dịch vụ của phiếu `IN_PROGRESS`, `START_PROCESSING`); `POST /service-details/{id}/sample-collected`; `GET /service-details/{id}/lab-form` (mục 5); `POST /lab-results/{detailId}` (đủ chỉ số của gói, snapshot min/max theo loài, `COMPLETED`, dịch vụ cuối của phiếu → phiếu `DONE`); `GET /lab-results/{detailId}` kèm `evaluation`.
- **Kiểm tra:** e2e Task 3.5 (4 dòng kết quả, RBC `LOW`, lịch sử đủ 4 action, phiếu `DONE`; thiếu PLT → 400 `SYS_1001`); EX-06/07 (gọi phiếu khác, gọi lại, start).
- **Kết quả:** –

#### [ ] P7.4 — Phòng CĐHA, tệp ảnh, URL ký tạm
- **Tham chiếu:** Task 3.6; Quy chuẩn 7.5; EX-09; D-12.
- **Làm:** `GET /api/v1/clinical/imaging-queue` (huy hiệu `labStatus` SAMPLING / SAMPLE_COLLECTED); `POST /imaging-results/{detailId}` multipart (một giao dịch: `imaging_results` → ghi tệp `file_key` → `imaging_attachments` → `COMPLETED`; lỗi thì rollback + xóa tệp; chỉ `image/jpeg`, `image/png`, `application/dicom`); `GET /imaging-attachments/{id}/url` (HMAC, 1 giờ) + endpoint `/files/**` kiểm chữ ký và hạn.
- **Kiểm tra:** unit test ký / kiểm URL (hết hạn, sai chữ ký → từ chối); e2e Task 3.6 (dùng `docs/demo-images/xq-*.png`); EX-09 (`labStatus: "SAMPLING"` trước khi lấy mẫu).
- **Kết quả:** –

#### [ ] P7.5 — Hợp nhất kết quả (T06) + phiếu ưu tiên, đóng ca khách bỏ về
- **Tham chiếu:** Task 3.7, 3.8.3; SM-01 T06, T08, T12; Q6; EX-05, EX-11.
- **Làm:** sau lưu kết quả / hủy dịch vụ: hết CLS dở → `RESULTS_READY` (lịch sử `NULL` user) + outbox `ParaclinicalResultsReadyEvent` cùng giao dịch; listener `clinical.queue-issuer.results-ready` phát phiếu `DOCTOR` `priority 1` cho Bác sĩ khám chính; `POST …/pet-visits/{id}/abandon` (T08/T12: hủy dịch vụ `PENDING` theo luật hóa đơn, phiếu chờ `CANCELLED`, công nợ giữ `PENDING`, ca `COMPLETED` + `VisitCompletedEvent`).
- **Kiểm tra:** e2e Task 3.7 (ca `RESULTS_READY`, phiếu ưu tiên đứng đầu `my-queue`, ca mới xếp sau — EX-05); EX-11.
- **Kết quả:** –

> **Kết quả giai đoạn P7:** –

---

### GIAI ĐOẠN P8 — `billing-pharmacy-service` NỀN (:8084)

#### [ ] P8.1 — Tầng dữ liệu, danh mục thuốc, bảng giá thuốc
- **Tham chiếu:** Task 4.1.1–4.1.4; ERD 4.4; Quy chuẩn 7.2 (mẫu `Medicine`, `MedicineStock`), 7.4; FR-04.
- **Làm:** `application.yml`; 10 entity (không có `Prescription`); `POST /api/v1/pharmacy/medicines` (thuốc + thành phần + giá đầu + dòng tồn 0), `GET` danh sách / chi tiết (kèm giá hiện hành, tồn), sửa, ngừng kinh doanh; `MedicinePriceBook` (`PHARM_1412`, `BILL_1410`) + `GET/POST /medicines/{id}/prices`; thêm vào compose.
- **Kiểm tra:** context + validate 10 bảng; unit test `MedicinePriceBook`; e2e danh sách thuốc trả Clavamox giá 15000, tồn 200.
- **Kết quả:** –

#### [ ] P8.2 — API nội bộ cho clinical, nhập / cân chỉnh kho
- **Tham chiếu:** Task 4.1.4, 4.4.6; Kiến trúc 5.1; FR-66.
- **Làm:** `GET /internal/medicines?keyword=&active=true`, `/internal/medicines/{id}` (tên, đơn vị, tồn tham khảo), `/internal/medicine-invoices/status?prescriptionId=`; `POST /api/v1/pharmacy/medicines/{id}/import` (`IMPORT` +, `unit_cost`), `/adjust` (`ADJUSTMENT` ±, không âm kho) cùng giao dịch với `medicine_stocks`; `GET /medicines/{id}/transactions` (mục 5).
- **Kiểm tra:** e2e Task 4.1 bước 2 (`:8084/internal/medicines?keyword=clava`); nhập + chỉnh kho giữ bất biến tồn = tổng nhật ký.
- **Kết quả:** –

> **Kết quả giai đoạn P8:** –

---

### GIAI ĐOẠN P9 — `clinical-service`: KÊ ĐƠN, GĐ 2, CHỐT CA, THU TIỀN

#### [ ] P9.1 — Kê đơn thuốc
- **Tham chiếu:** Task 4.2; UC-31; BR-18, BR-30, BR-32; EX-13.
- **Làm:** `PUT /api/v1/clinical/pet-visits/{id}/prescription` (Facade gọi Feign billing ngoài giao dịch: thuốc tồn tại + đang bán, chụp `medicine_name_snapshot`, `unit_snapshot`; giao dịch: ca `IN_PROGRESS` + đúng Bác sĩ, khóa → `PHARM_1411`; tối đa 1 đơn; mỗi thuốc 1 dòng; trường bắt buộc); phản hồi `stockWarnings`, `allergyWarning` (không chặn); `GET …/prescription`, `GET …/prescription/print`.
- **Kiểm tra:** e2e Task 4.2 (snapshot `Clavamox 250mg`/`Viên`; 300 viên → `stockWarnings`; thiếu `frequency` → 400 `SYS_1001`).
- **Kết quả:** –

#### [ ] P9.2 — Bắt đầu GĐ 2, chốt ca, mở lại hồ sơ
- **Tham chiếu:** Task 3.8.1, 3.8.2, 3.8.4, 3.8.5, 4.2.4; SM-01 T05, T07, T09, T14; Kiến trúc 5.6; EX-10, EX-12.
- **Làm:** `POST …/{id}/start-phase2` (T07); `POST …/{id}/close-visit` (`CLIN_1307`, `CLIN_1308`, `CLIN_1309`; ghi `final_diagnosis`, `treatment_plan`, `doctor_advice`, `follow_up_date`; phiếu `DONE` + lịch sử phiếu; `WAITING_PAYMENT`; khóa hồ sơ + đơn; outbox `PrescriptionCreatedEvent` nếu có đơn); `POST …/{id}/reopen` (T14: Bác sĩ phụ trách hoặc ADMIN, lý do bắt buộc, Feign trạng thái hóa đơn thuốc → `PAID` thì không cho sửa đơn).
- **Kiểm tra:** e2e Task 3.8 (đón ca bằng `call-next` + `start-phase2`; tẩy giun tại phòng; chốt khi thiếu chẩn đoán → 400 `CLIN_1307`; chốt → `WAITING_PAYMENT`, sửa sau chốt → `CLIN_1305`/`CLIN_1317`/`PHARM_1411`; outbox `PrescriptionCreatedEvent` `PUBLISHED`).
- **Kết quả:** –

#### [ ] P9.3 — Bảng kê, giảm giá, thu tiền cuối ca, công nợ, phiếu in
- **Tham chiếu:** Task 3.9; SM-01 T10; SM-05; BR-27, BR-28; EX-14.
- **Làm:** `GET …/pet-visits/{id}/service-invoices` (VIEW, tổng cần thu); `POST /service-invoices/{id}/discount` (`BILL_1402`); `confirm-payment` nhánh cuối ca (hết `PENDING` + `WAITING_PAYMENT` → `COMPLETED` + lịch sử + outbox `VisitCompletedEvent`); `cashier/pending?section=FINAL`; `GET …/pet-visits/with-debt`; phiếu tạm tính / phiếu thu (FR-58).
- **Kiểm tra:** e2e Task 3.9 (4 hóa đơn, cần thu 50000; giảm 300000 → 400 `BILL_1402`; thu → `COMPLETED` ngay; gửi lại → 409 `BILL_1403`).
- **Kết quả:** –

> **Kết quả giai đoạn P9:** –

---

### GIAI ĐOẠN P10 — `billing-pharmacy-service`: HÓA ĐƠN THUỐC

#### [ ] P10.1 — Hóa đơn thuốc nháp từ `PrescriptionCreatedEvent`
- **Tham chiếu:** Task 4.3; Quy chuẩn 8.2 (bước 1–2); SM-06; BR-26, BR-31, BR-32; EX-19.
- **Làm:** listener `billing.prescription-created` (`IdempotentConsumer`; tạo `PENDING` mã `MINV-YYYY-XXXX` + dòng theo đơn, giá hiện hành; đã có `PENDING` → dựng lại dòng; đã `PAID`/`CANCELLED` → log `PHARM_1407`); `GET /api/v1/billing/medicine-invoices?visitId=`, `GET /{id}`; `PUT /{id}/items` (`BILL_1403/1408`, `PHARM_1406`, ≥ 1 dòng, `BILL_1402`); `POST /{id}/cancel`.
- **Kiểm tra:** e2e Task 4.3 (1 hóa đơn nháp, `payable_amount` 157500; phát lại sự kiện → vẫn 1 hóa đơn, `processed_events` 1 dòng; sửa 12 viên → 200; 0 dòng → 400; vượt tồn → 409 `PHARM_1406`).
- **Kết quả:** –

#### [ ] P10.2 — Thu tiền thuốc + trừ kho nguyên tử
- **Tham chiếu:** Task 4.4.1–4.4.5; Quy chuẩn 8.1, 8.2 (bước 3); BR-29, BR-30; EX-15, EX-16, EX-20.
- **Làm:** `POST /api/v1/billing/medicine-invoices/{id}/confirm-payment` (cập nhật giá hiện hành; sắp theo `medicineId`; `deduct` 0 dòng → `PHARM_1406` rollback; `EXPORT_SALE` âm; `PAID`, `cashier_id`; outbox `MedicineInvoicePaidEvent` + `MedicineLowStockEvent` khi chạm ngưỡng).
- **Kiểm tra:** Testcontainers: 2 lệnh thu song song cùng hóa đơn → 1 thành công, 1 `SYS_1005`/`BILL_1403`; e2e Task 4.4 (tồn 200 → 190, bất biến; thu lại → 409 `BILL_1403`; EX-15 còn 5 viên mua 10 → 409, tồn giữ 5; EX-20 đổi giá khi nháp → thu theo giá mới).
- **Kết quả:** –

> **Kết quả giai đoạn P10:** –

---

### GIAI ĐOẠN P11 — `reporting-service` (:8086)

#### [ ] P11.1 — CSDL đọc + listener dựng bảng phẳng
- **Tham chiếu:** Task 4.5.1–4.5.2; ERD 4.5; Kiến trúc 5.7; NFR-09.
- **Làm:** module + 5 entity; listener (mỗi listener một queue, idempotent): `VisitCheckedInEvent` → `visit_facts`; `VisitCompletedEvent`/`VisitCancelledEvent` → cập nhật + `doctor_daily_performances`; `ServiceInvoicePaidEvent`/`MedicineInvoicePaidEvent` → `revenue_facts` `SALE` + `daily_revenue_summaries` (`INSERT … ON DUPLICATE KEY UPDATE`); `ServiceInvoiceRefundedEvent` → `REFUND` âm; `UserProfileUpdatedEvent`/`PetUpdatedEvent` → cập nhật tên; thêm vào compose.
- **Kiểm tra:** Testcontainers: nhận trùng sự kiện → tổng không đổi; hoàn tiền → tổng giảm đúng.
- **Kết quả:** –

#### [ ] P11.2 — API báo cáo + job dựng lại
- **Tham chiếu:** Task 4.5.3–4.5.4; FR-69, FR-70.
- **Làm:** `GET /api/v1/reports/revenue/daily?from=&to=&type=`, `/revenue/by-category?month=`, `/doctors/performance?from=&to=`, `/visits/summary?date=` (ADMIN, chỉ đọc CSDL reporting); job dựng lại chạy tay (xóa bảng, đặt lại `processed_events`, phát lại outbox ≤ 7 ngày của các service).
- **Kiểm tra:** e2e Task 4.5 (doanh thu dịch vụ + thuốc khớp hai VIEW; hoàn tiền → dòng âm; phát lại → không đổi; hiệu suất `bs_tien` không gọi auth).
- **Kết quả:** –

> **Kết quả giai đoạn P11:** –

---

### GIAI ĐOẠN P12 — `notification-service` (:8085)

#### [ ] P12.1 — STOMP broker, xác thực WebSocket, thông báo người dùng
- **Tham chiếu:** Task 5.1.1; Kiến trúc 3; D-08, D-11.
- **Làm:** endpoint `/ws` qua Gateway, simple broker các topic D-08; chốt cách xác thực (token ở frame CONNECT hoặc query) và ghi D-xx; kho thông báo trong bộ nhớ (D-11) + `GET /api/v1/notifications`, `POST /{id}/read`; thêm vào compose.
- **Kiểm tra:** script node kết nối `ws://localhost:8080/ws`, subscribe, nhận tin thử; không token → bị từ chối.
- **Kết quả:** –

#### [ ] P12.2 — Listener sự kiện → WebSocket / Email
- **Tham chiếu:** Task 5.1.2–5.1.5; bảng 17 sự kiện; EX-17.
- **Làm:** listener cho các sự kiện có consumer `notification` (lịch hẹn → email Mailpit + thông báo; check-in → mục chờ thu phí; phiếu phát / gọi số → sảnh + hàng đợi; kết quả CLS → `/topic/doctor/{id}`; chốt ca có đơn → mục hóa đơn nháp; hoàn tất / thu thuốc → phiếu thu điện tử; tồn thấp → `/topic/admin`; Bác sĩ bị khóa → cảnh báo Lễ tân). Sự kiện gửi mail dùng `IdempotentConsumer` (bộ nhớ hoặc khóa chống trùng — ghi D-xx).
- **Kiểm tra:** e2e Task 5.1 (subscribe `/topic/doctor/$U_TIEN`, hoàn tất CLS cuối → nhận "Ca khám VISIT-… của thú cưng Lu đã có đủ kết quả cận lâm sàng!"); Mailpit `:8025` có email đặt lịch.
- **Kết quả:** –

> **Kết quả giai đoạn P12:** –

---

### GIAI ĐOẠN P13 — TÍCH HỢP & NGHIỆM THU

#### [ ] P13.1 — Toàn hệ thống một lệnh Docker
- **Tham chiếu:** Kiến trúc 8; NFR-08.
- **Làm:** `docker-compose.yml` đủ 9 service backend + `fe` (Dockerfile có sẵn) với healthcheck, `depends_on: condition: service_healthy`, biến môi trường từ `.env`; chỉ mở 8080 (và 3000 cho FE); cập nhật `.env.example`.
- **Kiểm tra:** `docker compose down -v && docker compose up -d --build` → mọi container healthy; Eureka thấy 7 service; `bash e2e/run_all.sh` xanh.
- **Kết quả:** –

#### [ ] P13.2 — Dựng lại & đối soát hàng đợi, quản trị outbox
- **Tham chiếu:** Quy chuẩn 9.3 mục 6, 11.2 (ghi chú `QueueReconcileJob`); Kiến trúc 4.2, 5.3; EX-18.
- **Làm:** `QueueRebuildJob` (khởi động khi thiếu `queue:meta:{date}` + gọi tay ADMIN): dựng phiếu từ MySQL theo đúng thứ tự; `QueueReconcileJob` (mỗi phút: phiếu thiếu / trạng thái lệch so với đợt khám); API ADMIN xem dòng outbox `FAILED` và gửi lại (đặt `PENDING`); (tùy chọn D-14) rate limit Gateway.
- **Kiểm tra:** e2e EX-18 (dừng RabbitMQ khi thu phí → 200, outbox `PENDING`, bật lại → đúng 1 phiếu; dừng Redis → hàng đợi 503 `CLIN_1318`, check-in/thu tiền vẫn chạy; `FLUSHALL` + rebuild → hàng đợi đúng thứ tự).
- **Kết quả:** –

#### [ ] P13.3 — E2E luồng chuẩn (Happy Path)
- **Tham chiếu:** Task 5.4 (10 bước).
- **Làm:** `e2e/P13_happy_path.sh` chạy trọn 10 bước qua API, kiểm CSDL + Redis sau mỗi bước.
- **Kiểm tra:** không 500; doanh thu dịch vụ 580.000, thuốc 157.500 (hoặc 0 ở biến thể mua ngoài); `queue_ticket_histories` 5 phiếu `DONE`; báo cáo khớp.
- **Kết quả:** –

#### [ ] P13.4 — E2E 20 ngoại lệ EX-01 → EX-20
- **Tham chiếu:** Task 5.5; `docs/TONG_HOP_NGOAI_LE_VA_XU_LY_HE_THONG.md`.
- **Làm:** gom các kiểm tra ngoại lệ đã viết rải rác ở các bước thành `e2e/P13_exceptions.sh` (mỗi EX một hàm, in PASS/FAIL), bổ sung EX còn thiếu.
- **Kiểm tra:** 20/20 PASS, mã lỗi đúng, lịch sử đầy đủ, tiền / kho / hàng đợi / báo cáo toàn vẹn.
- **Kết quả:** –

#### [ ] P13.5 — Chốt hợp đồng với Frontend & bàn giao
- **Tham chiếu:** mục 5; `fe/src/api/endpoints.js`.
- **Làm:** rà toàn bộ endpoint backend thật → cập nhật mục 5 (đủ, chính xác) để FE sửa; đồng bộ `docs/schema_init.sql`, `docs/seed_demo_data.sql`; `vetclinic-backend/README.md` (chạy, cổng, tài khoản demo, e2e); tổng kết số liệu cuối (số test, số kiểm tra e2e, quyết định D-xx) vào bảng trạng thái.
- **Kiểm tra:** `mvn clean verify` + `docker compose down -v && up -d --build` + `bash e2e/run_all.sh` xanh trên CSDL mới.
- **Kết quả:** –

> **Kết quả giai đoạn P13:** –

---

## 7. Truy vết Task docs → bước lộ trình

| Task docs | Bước | Task docs | Bước |
| :--- | :--- | :--- | :--- |
| 1.1 | P0.1 | 3.4 | P7.1, P7.2 |
| 1.2 | P0.2–P0.5 | 3.5 | P7.3 |
| 1.3 | P1.1–P1.4 | 3.6 | P7.4 |
| 1.4 | P2.1 | 3.7 | P7.5 |
| 1.5 | P2.2 (+ P3.2) | 3.8 | P7.5 (abandon), P9.2 |
| 2.1 | P3.1 | 3.9 | P9.3 |
| 2.2 | P3.2 | 4.1 | P8.1, P8.2 |
| 2.3 | P3.3 | 4.2 | P9.1 (+ 4.2.4 ở P9.2) |
| 2.4 | P3.4, P3.5 | 4.3 | P10.1 |
| 2.5, 2.6 | P5.1 | 4.4 | P10.2 (+ 4.4.6 ở P8.2) |
| 2.7 | P5.2 | 4.5 | P11.1, P11.2 |
| 2.8 | P5.3 | 5.1 | P12.1, P12.2 |
| 3.1 | P4.1–P4.3 | 5.2, 5.3 (Frontend) | Ngoài phạm vi (Linh); P13.5 hỗ trợ |
| 3.2 | P6.2, P6.3, P6.4 (+ 3.2.5 ở P5.3) | 5.4 | P13.3 |
| 3.3 | P6.4, P6.5 | 5.5 | P13.4 (+ từng EX ở bước liên quan) |

---

## 8. Nhật ký lộ trình

| Ngày | Thay đổi |
| :--- | :--- |
| 20/11/2026 | Tạo lộ trình từ bộ tài liệu v4.0: 14 giai đoạn, 48 bước, quyết định D-01 → D-15, bảng lệch hợp đồng FE. |
| 20/11/2026 | Xong P0.1; thêm D-16 (tên starter Boot 4 / Cloud 2025), D-17 (starter thêm theo bước cấu hình). |
| 21/11/2026 | Xong P0.2 (lược đồ 52 bảng); thêm D-18 (VIEW giá theo giờ UTC+7, cột VIEW), D-19 (đặt tên ràng buộc); thêm `db/verify_schema.sql`. |
