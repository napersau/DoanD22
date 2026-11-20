# CLAUDE.md — VetClinic (Đồ án tốt nghiệp: Hệ thống quản lý phòng khám thú y)

> File này là **luật làm việc** của Claude trong repo. Đọc hết trước khi sửa code.
> Lộ trình xây dựng backend và tiến độ: [LO_TRINH_XAY_DUNG_BACKEND.md](LO_TRINH_XAY_DUNG_BACKEND.md).
> Làm bước kế tiếp của lộ trình: lệnh `/be-next` (hoặc `/be-next P3.2` để chỉ định bước).

---

## 0. Việc bắt buộc ở đầu mỗi phiên làm backend

1. Đọc `LO_TRINH_XAY_DUNG_BACKEND.md`: mục **▶ TRẠNG THÁI HIỆN TẠI**, mục **4 (Quyết định đã chốt)** và bước đang làm.
2. Chỉ làm **một bước** của lộ trình mỗi lần (trừ khi người dùng yêu cầu khác). Không nhảy bước khi bước trước chưa `[x]`.
3. Trước khi code, đọc đúng các mục `docs/` mà bước đó trỏ tới — không code theo trí nhớ.

---

## 1. Bối cảnh dự án

- **Nhóm 3 người:** Lưu Minh Hiển (trưởng nhóm, backend appointment + clinical khám), Nguyễn Đức Khởi (backend hạ tầng, auth, cận lâm sàng, notification, reporting), Vũ Hồng Linh (frontend React).
- **Kiến trúc:** Microservices + Event-Driven. Java 21, Spring Boot 4.1.1, Spring Cloud 2025.1.x, MySQL 8.0 (5 CSDL logic), Redis 7 (hàng đợi), RabbitMQ (exchange `clinic.events`), Docker Compose.
- **Thư mục:**
  - `docs/` — bộ tài liệu thiết kế **v4.0** (nguồn chuẩn). File có hậu tố ` (1)` là bản **v3.0 cũ → bỏ qua**.
  - `vetclinic-backend/` — Maven multi-module (9 module, xem bảng cổng ở §6).
  - `db/` — `schema_current.sql`, `seed_current.sql` được Docker nạp khi khởi tạo MySQL (nguồn chạy thật).
  - `fe/` — React (Create React App, cổng 3000), gọi backend qua Gateway `:8080`.
  - `e2e/` — kịch bản kiểm thử bash + curl chạy trên hệ thống Docker (tạo dần theo lộ trình).
- **Hiện trạng ban đầu (20/11/2026):** backend mới có `pom.xml` cha; các file SQL, `docker-compose.yml`, `.env.example`, `Dockerfile` đều **rỗng**; tài liệu ghi "ĐÃ XONG" ở Kế hoạch là kế hoạch, **không phản ánh mã nguồn** trong repo này.

---

## 2. Nguồn chuẩn & xử lý mâu thuẫn

**Thứ tự ưu tiên khi hai nguồn nói khác nhau** (cao → thấp):

1. Mục 4 "Quyết định đã chốt" trong `LO_TRINH_XAY_DUNG_BACKEND.md`.
2. `docs/THIET_KE_KIEN_TRUC_MICROSERVICES.md` — danh mục service, 17 sự kiện, lời gọi Feign, giao dịch.
3. `docs/QUY_CHUAN_THIET_KE_VA_LAP_TRINH_BACKEND_SPRINGBOOT.md` — cấu trúc code, API, 49 mã lỗi, mẫu code.
4. `docs/THIET_KE_CO_SO_DU_LIEU_ERD.md` — tên bảng / cột / kiểu / ràng buộc (mục 4), index (mục 5), giá trị tính (mục 6).
5. `docs/THIET_KE_SO_DO_TRANG_THAI_STATE_MACHINE.md` — chuyển trạng thái T01–T14, quy tắc hàng đợi Q1–Q6, guard.
6. `docs/TONG_HOP_NGOAI_LE_VA_XU_LY_HE_THONG.md` — EX-01 → EX-20.
7. `docs/LICH_TRINH_XAY_DUNG_MA_NGUON_VA_HUONG_DAN_TEST.md` — task, endpoint, **kết quả kiểm thử kỳ vọng**.
8. `docs/DANH_SACH_KIEU_ENUM_HE_THONG.md`, `docs/DAC_TA_USE_CASE_CORE.md` (BR-xx), `docs/YEU_CAU_CHUC_NANG_VA_PHI_CHUC_NANG.md` (FR/NFR), `docs/TAI_LIEU_MO_TA_NGHIEP_VU_PHONG_KHAM_THU_Y.md`, `docs/THIET_KE_SO_DO_HOAT_DONG_ACTIVITY.md`.

**Quy tắc:**
- Chỉ dùng thông tin **v4.0**. Bỏ mọi chi tiết v3.0 còn sót trong phụ lục lịch sử (bảng `queue_tickets`, khóa `Long`, header `X-User-Role` số ít, `AFTER_COMMIT`, đơn thuốc ở billing, `skip`…).
- Gặp mâu thuẫn / thiếu thông tin: **không đoán im lặng**. Chọn theo thứ tự trên, ghi thành một dòng `D-xx` ở mục 4 của lộ trình (nội dung, lý do, nguồn), và báo người dùng trong tin nhắn cuối.
- **Không sửa `docs/*.md`** (tài liệu nộp GVHD) trừ khi người dùng yêu cầu. Ngoại lệ: `docs/schema_init.sql`, `docs/seed_demo_data.sql` được đồng bộ bằng cách sao chép từ `db/` (D-02).
- Không thêm bảng / cột / sự kiện / mã lỗi ngoài docs. Endpoint ngoài docs chỉ thêm khi có quyết định `D-xx` (ví dụ endpoint Frontend cần).

---

## 3. Luật viết code bắt buộc (rút từ Quy chuẩn v4.0 — vi phạm là sai, phải sửa)

### 3.1. Module & package
- Mỗi service chỉ quét package của mình (`@SpringBootApplication` mặc định). **Cấm** `scanBasePackages = "com.vetclinic"`.
- `common-library`: phần thuần (`com.vetclinic.common.dto | exception | event | util | constant`) không có `@Component`; phần servlet (`com.vetclinic.common.web`) nạp bằng `CommonWebAutoConfiguration` (`@ConditionalOnWebApplication(SERVLET)`) qua file `AutoConfiguration.imports`; phần outbox (`com.vetclinic.common.outbox`) nạp có điều kiện khi service có JPA + RabbitMQ. Phụ thuộc web/security/openfeign của `common-library` là `<optional>true</optional>`.
- `service-registry` **không** phụ thuộc `common-library`. `api-gateway` là WebFlux, chỉ dùng phần thuần.
- Package trong service: `config, controller, service(+impl), repository, entity, dto/request, dto/response, mapper, client, event, outbox, queue (chỉ clinical), constant, scheduler`.

### 3.2. Dữ liệu & JPA
- `spring.jpa.open-in-view=false`, `ddl-auto: validate` (lược đồ do `db/schema_current.sql` quyết định, không để Hibernate tạo bảng).
- Khóa: thực thể nghiệp vụ `UUID` + `@UuidGenerator(style = VERSION_7)` + `columnDefinition = "BINARY(16)"`; dữ liệu chỉ thêm `Long IDENTITY`; danh mục `Short IDENTITY` (code tham chiếu bằng cột `code`, hằng trong `RoleCodes`, `CategoryCodes` — không dùng id). Quan hệ 1–1 mở rộng dùng `@MapsId`. **Cấm** `UUID.randomUUID()` làm khóa.
- SQL thủ công: `UUID_TO_BIN('…')` / `BIN_TO_UUID(col)` **không dùng cờ swap** (Hibernate lưu đúng thứ tự byte).
- Khóa ngoại logic sang service khác là `UUID` thuần (không `@ManyToOne`). Cột `*_snapshot` chỉ ghi lúc tạo và bởi listener cập nhật tên; **không dùng snapshot để quyết định nghiệp vụ** (kiểm tra Bác sĩ `ACTIVE` phải gọi Feign).
- Trạng thái: enum Java `@Enumerated(EnumType.STRING)` trên cột `VARCHAR`. **Cấm** kiểu `ENUM` của MySQL.
- `@Version` bắt buộc trên: `PetVisit, MedicalRecord, VisitServiceDetail, ServiceInvoice, MedicineInvoice, MedicineStock, Appointment, User`. Xung đột → `SYS_1005`.
- Tiền: `BigDecimal` (cấm `double/float`). **Không lưu tổng tiền** — tính bằng VIEW (`v_service_invoice_amounts`, `v_medicine_invoice_amounts`) hoặc trong code.
- Thời gian: cột `TIMESTAMP` ↔ `Instant` (UTC, `hibernate.jdbc.time_zone=UTC`); cột `DATETIME` (`effective_from/to` của bảng giá) ↔ `LocalDateTime` giờ phòng khám; ngày nghiệp vụ, khung giờ, số phiếu theo ngày tính bằng múi `Asia/Ho_Chi_Minh` (một hằng `ClinicTime.ZONE`).
- Bảng giá (`service_prices`, `medicine_prices`): không bao giờ sửa số tiền hay xóa dòng; đổi giá = đóng dòng mở + thêm dòng mới (`ServicePriceBook` / `MedicinePriceBook`, Quy chuẩn 7.4). Hóa đơn chụp `unit_price`, `vat_rate`.
- Xóa mềm: tài khoản (`LOCKED/INACTIVE`), dịch vụ / thuốc / danh mục (`is_active=false`), thú cưng (`deleted_at`). Không xóa cứng.
- Ảnh CĐHA: lưu `file_key` tương đối (`imaging/yyyy/MM/<uuidv7>.<ext>`), trả URL ký HMAC hạn 1 giờ. Không lưu URL tuyệt đối.
- Mọi đổi trạng thái lịch hẹn / đợt khám / chỉ định ghi **1 dòng lịch sử cùng giao dịch** (`*_status_histories`, `visit_service_detail_histories`); `changed_by_user_id = NULL` nghĩa là hệ thống. Lý do hủy nằm ở `notes`/`reason` của dòng lịch sử, thời điểm lấy từ `created_at` của lịch sử.

### 3.3. Giao dịch
- Mỗi nghiệp vụ tiền / kho nằm trọn trong **một** `@Transactional(rollbackFor = Exception.class)` của **một** service. Không Saga.
- **Không gọi Feign bên trong `@Transactional`** — kiểm tra liên service ở lớp Facade trước khi gọi phương thức giao dịch.
- **Không thay đổi phiếu Redis bên trong `@Transactional`** — chạy ở `TransactionSynchronization.afterCommit` hoặc trong listener sự kiện.
- Trừ kho: `UPDATE medicine_stocks … WHERE quantity_on_hand >= :qty` (0 dòng → `PHARM_1406` → rollback toàn bộ); sắp dòng theo `medicineId` trước khi trừ; luôn ghi `inventory_transactions` cùng giao dịch (bất biến `quantity_on_hand = SUM(quantity)`).

### 3.4. Sự kiện (RabbitMQ + Transactional Outbox)
- Sự kiện làm đổi dữ liệu ở service khác **phải** ghi bằng `OutboxWriter` (`Propagation.MANDATORY`) cùng giao dịch nghiệp vụ; `OutboxRelay` gửi đi. **Cấm** gọi `rabbitTemplate` trong nghiệp vụ, **cấm** `@TransactionalEventListener(AFTER_COMMIT)` để gửi sự kiện.
- Ngoại lệ duy nhất gửi trực tiếp: `QueueTicketIssuedEvent`, `PatientCalledEvent` (chỉ làm mới màn hình).
- Mọi listener idempotent: `IdempotentConsumer.run(eventId, "<service>.<listener>", action)` (hoặc khóa dedupe Redis cho listener phát phiếu). Mỗi listener một queue `<service>.<listener>` + DLQ `<queue>.dlq`, retry 3 lần (1s/2s/4s).
- Tên sự kiện, routing key, producer, consumer, payload: **đúng bảng 17 sự kiện** ở Kiến trúc 5.2 / Quy chuẩn 9.2. Payload chung: `eventId` (UUIDv7), `eventType`, `occurredAt`, `aggregateId`.

### 3.5. Feign
- **Chỉ để đọc**, chỉ gọi `/internal/**`, chỉ các lời gọi trong bảng Kiến trúc 5.1. Timeout 2 s + Circuit Breaker (Resilience4j).
- Lời gọi để **hiển thị** được có fallback (trả snapshot); lời gọi để **kiểm tra điều kiện ghi** không fallback → lỗi thì `SYS_1004`, không ghi dữ liệu.
- `CustomFeignErrorDecoder` khôi phục `ErrorCode` từ phản hồi service con.

### 3.6. Hàng đợi Redis (chỉ clinical-service)
- Khóa và cấu trúc đúng ERD mục 3; `score = (2 − priority) × 10^13 + epochMillis(thời điểm thu tiền / tiếp đón / có kết quả)`.
- Mọi thao tác đổi phiếu bằng Lua script (`issue_ticket`, `start_ticket`, `finish_ticket`, `move_ticket`); "Gọi" chỉ `HINCRBY calledCount` + `HSET lastCalledAt`, không đổi trạng thái / thứ tự, không ghi CSDL.
- MySQL là nguồn sự thật của trạng thái nghiệp vụ; phiếu kết thúc ghi `queue_ticket_histories` cùng giao dịch nghiệp vụ, xóa khỏi Redis sau commit. Redis lỗi khi đọc hàng đợi → `CLIN_1318`.

### 3.7. API & bảo mật
- URI đúng tiền tố Quy chuẩn 3.2; thao tác chuyển trạng thái là `POST …/{id}/<động-từ>`, tầng service chống bấm trùng (kiểm tra trạng thái nguồn + `@Version`).
- Phản hồi luôn bọc `ApiResponse<T>` (`status`, `errorCode`, `message`, `data`, `timestamp`); tạo mới trả HTTP **201** thật (`ResponseEntity.status(CREATED)`); phân trang `PageResponse<T>`.
- Lỗi nghiệp vụ: `throw new AppException(ErrorCode.X)` — chỉ dùng 49 mã ở Quy chuẩn 5.1, đúng HTTP status của mã đó. Không tự bịa mã.
- **Không bao giờ trả Entity** ra API: Request DTO có Jakarta Validation (`@Valid`), Response DTO qua MapStruct (`unmappedTargetPolicy = WARN`).
- Mọi endpoint không công khai có `@PreAuthorize("hasRole('…')")` (vai trò không tiền tố trong JWT; `HeaderAuthenticationFilter` thêm `ROLE_` đúng một lần). Thiếu/sai token → 401 `SYS_1002`; sai vai trò → 403 `SYS_1003`. Người dùng hiện tại: `SecurityUtils.getCurrentUserId()` (UUID).
- Gateway xóa `X-User-Id`, `X-User-Roles` từ client rồi gắn lại từ JWT; chặn `/internal/**` (403). JWT HMAC-SHA256 tự triển khai (không OAuth2 server); refresh token chỉ lưu SHA-256, xoay vòng, phát hiện dùng lại.
- Bí mật (mật khẩu DB, `JWT_SECRET`, khóa ký URL ảnh) lấy từ biến môi trường / `.env`; không hard-code, không commit `.env`.

### 3.8. Phong cách
- Tên lớp / biến / endpoint tiếng Anh; thông điệp lỗi, log nghiệp vụ, comment tiếng Việt như mẫu docs. Comment chỉ khi giải thích "vì sao".
- Ưu tiên `record` cho DTO và sự kiện; Lombok cho entity. Không thêm thư viện ngoài danh sách Quy chuẩn Ch.1 khi chưa có quyết định `D-xx`.
- Spring Boot 4 dùng **Jackson 3** (`tools.jackson.*`; annotation vẫn là `com.fasterxml.jackson.annotation`) và Spring AMQP 4 — mẫu code trong docs viết theo API cũ, phải điều chỉnh cho đúng phiên bản thật (kiểm chứng bằng biên dịch, không đoán).

### 3.9. Kiểm thử
- Logic service: JUnit 5 + Mockito. Repository / outbox / hàng đợi / listener: **Testcontainers** (MySQL 8.0 nạp `db/schema_current.sql` + seed, RabbitMQ, Redis) — test không phụ thuộc trạng thái `docker compose` đang chạy.
- Mỗi guard của State Machine và mỗi mã lỗi được dùng trong bước phải có ít nhất một test chạm tới.
- Kịch bản "Hướng dẫn kiểm thử" của Lịch trình docs được chuyển thành script trong `e2e/` (curl; đọc JSON bằng `node`, máy không có `jq`) và chạy được bằng `bash e2e/run_all.sh`.

---

## 4. Flow làm một bước của lộ trình

1. **Chọn bước:** bước được chỉ định, hoặc bước `[~]` đang dở, hoặc bước `[ ]` đầu tiên. Bước trước chưa `[x]` → dừng, báo người dùng.
2. **Đọc:** phần docs mà bước trỏ tới + mã nguồn hiện có sẽ bị đụng tới. Đối chiếu tên bảng/cột/endpoint/sự kiện/mã lỗi với docs.
3. **Báo trước ngắn gọn** cho người dùng: bước này tạo/sửa những gì, có mâu thuẫn docs nào cần chốt.
4. **Đánh dấu `[~]`** cho bước trong lộ trình, rồi viết code + test.
5. **Chạy Điều kiện xong (§5).** Đỏ thì sửa tới khi xanh; không sửa được thì dừng, giữ `[~]`, ghi rõ lỗi vào lộ trình và báo người dùng. **Không bỏ qua bước kiểm tra, không tắt/skip test để cho xanh.**
6. **Cập nhật lộ trình:** đổi `[~]` → `[x]`; điền dòng **Kết quả** (ngày, số test, số kiểm tra e2e, lệch so với docs, quyết định mới); cập nhật bảng ▶ TRẠNG THÁI HIỆN TẠI và "Bước tiếp theo"; xong cả giai đoạn thì ghi kết quả giai đoạn.
7. **Commit một lần** (code + lộ trình) theo §7.
8. **Dừng** và báo cáo: đã làm gì, kết quả kiểm tra (số liệu thật), quyết định mới cần người dùng biết. Không tự làm bước tiếp theo.

---

## 5. Điều kiện xong (Definition of Done) cho mỗi bước

Áp dụng tất cả mục phù hợp với bước:

1. `cd vetclinic-backend && mvn -q clean verify` → BUILD SUCCESS, **0 test fail/skip ngoài ý muốn** (ghi số test vào Kết quả).
2. Test mới cho phần vừa viết (unit + Testcontainers nếu chạm CSDL/RabbitMQ/Redis).
3. Bước có lược đồ: các truy vấn kiểm tra của Lịch trình Task 1.2 trả đúng số bảng / khóa ngoại / VIEW / 0 cột ENUM.
4. Bước có service chạy được: `docker compose up -d --build <các service liên quan>` → container `healthy`, đăng ký Eureka; chạy script e2e của bước và **toàn bộ** `bash e2e/run_all.sh` (không hồi quy bước cũ).
5. Kết quả khớp "Kết quả kỳ vọng" của task tương ứng trong Lịch trình docs (mã HTTP, `errorCode`, dữ liệu CSDL/Redis, sự kiện). Lệch có chủ đích phải có `D-xx`.
6. Lộ trình đã cập nhật (§4 bước 6).

---

## 6. Môi trường & lệnh thường dùng (Windows 11, Git Bash / PowerShell)

- Máy hiện có: JDK 22 (`JAVA_HOME`), Maven 3.9.9, Docker 28 + Compose v2, Node 22. Biên dịch với `release 21`. Không có `jq`.
- **Cổng:** registry 8761 · gateway 8080 (cổng duy nhất mở cho FE) · auth 8081 · appointment 8082 · clinical 8083 · billing-pharmacy 8084 · notification 8085 · reporting 8086 · MySQL 3306 (máy có MySQL riêng thì `MYSQL_HOST_PORT=3307`) · Redis 6379 · RabbitMQ 5672/15672 · Mailpit 1025/8025 · FE 3000.
- **CSDL:** `pet_clinic_auth_db`, `pet_clinic_appointment_db`, `pet_clinic_clinical_db`, `pet_clinic_billing_pharmacy_db`, `pet_clinic_reporting_db`.

```bash
# Build + test toàn bộ backend
cd vetclinic-backend && mvn -q clean verify
# Test một module (kèm module phụ thuộc)
mvn -q -pl clinical-service -am verify
# Hạ tầng cho dev (mở cổng ra host) — chạy service trong IDE
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d mysql-server redis rabbitmq-broker mailpit service-registry
# Toàn hệ thống
docker compose up -d --build && docker compose ps
# Dựng lại CSDL từ đầu (mất dữ liệu)
docker compose down -v && docker compose up -d --build
# Kiểm thử e2e
bash e2e/run_all.sh
```

---

## 7. Git

- Làm trên nhánh `develop` (tạo từ `main` ở bước P0.1). `main` chỉ nhận merge khi người dùng yêu cầu.
- Mỗi bước lộ trình = **một commit** gồm code + cập nhật lộ trình, thông điệp: `be <mã bước>: <tóm tắt tiếng Việt>` (ví dụ `be P3.2: đăng nhập, đăng ký và cấp JWT`).
- Sau commit: `git push origin develop` (người dùng yêu cầu push sau mỗi bước — ghi trong `.claude/commands/v4-next.md`, 20/11/2026). Push bị từ chối → báo người dùng, **không `--force`**.
- Không commit: `.env`, `target/`, `node_modules/`, `uploads/`, `update.md`, file bí mật.
- `.claude/commands/v4-next.md` thuộc lộ trình "nâng v3 → v4" của một bản mã khác (file `LO_TRINH_SUA_CODE_V4.md` không tồn tại ở đây) → **không dùng**; dùng `/be-next`.

---

## 8. Frontend (tóm tắt — chi tiết trong `fe/README.md`)

- React 19 + Create React App (`react-scripts`), cổng 3000; `REACT_APP_API_URL=http://localhost:8080`. Lớp gọi API: `fe/src/api/` (`client.js` đọc `ApiResponse.data`, tự refresh một lần khi 401; `endpoints.js` liệt kê endpoint; `stomp.js` WebSocket).
- `fe/src/api/endpoints.js` hiện theo hợp đồng **v3.0**, lệch docs v4.0 ở nhiều chỗ — danh sách ở mục 5 của lộ trình. Backend làm theo docs v4.0 (D-06); khi đổi hợp đồng thì cập nhật danh sách lệch để FE sửa.
- `fe/legacy-mock/` là bản giao diện cũ dùng dữ liệu giả, không build, chỉ tham khảo.
- Tài khoản mẫu: `admin` / `Admin@123`.
