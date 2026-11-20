-- =====================================================================================================================
-- LƯỢC ĐỒ CƠ SỞ DỮ LIỆU VETCLINIC v4.0 (52 bảng, 40 khóa ngoại nội bộ, 4 VIEW, 5 CSDL logic trên một MySQL 8.0)
-- Nguồn: docs/THIET_KE_CO_SO_DU_LIEU_ERD.md (mục 1.2, 4 từ điển dữ liệu, 5 index, 6 giá trị tính), docs/DANH_SACH_KIEU_ENUM_HE_THONG.md
-- Dựng lại từ ERD vì docs/schema_init.sql rỗng (quyết định D-02 trong LO_TRINH_XAY_DUNG_BACKEND.md).
--
-- Quy ước:
--   * Khóa thực thể: BINARY(16) = UUIDv7 sinh ở ứng dụng. Dữ liệu chỉ thêm: BIGINT AUTO_INCREMENT. Danh mục: SMALLINT + cột code.
--   * Không dùng kiểu ENUM của MySQL: trạng thái lưu VARCHAR, giá trị hợp lệ ghi ở COMMENT cột và kiểm bằng enum Java.
--   * Khóa ngoại logic sang CSDL khác (không có FOREIGN KEY vật lý) ghi chú dạng  -- LFK: <csdl>.<bảng>(id)
--   * TIMESTAMP lưu UTC (server chạy múi +00:00). DATETIME (effective_from / effective_to của bảng giá) là giờ phòng khám (UTC+7).
--   * Không lưu giá trị dẫn xuất (tổng tiền, nhãn xét nghiệm...): dùng 4 VIEW ở cuối mỗi CSDL liên quan.
--   * Dữ liệu danh mục khởi tạo nằm ở cuối file (bước P0.3); dữ liệu demo ở db/seed_current.sql (bước P0.4).
-- =====================================================================================================================

SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS pet_clinic_auth_db             CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS pet_clinic_appointment_db      CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS pet_clinic_clinical_db         CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS pet_clinic_billing_pharmacy_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS pet_clinic_reporting_db        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;


-- =====================================================================================================================
-- 1. pet_clinic_auth_db (auth-service) — 9 bảng, 7 khóa ngoại
-- =====================================================================================================================
USE pet_clinic_auth_db;

CREATE TABLE roles (
    id          SMALLINT     NOT NULL AUTO_INCREMENT,
    code        VARCHAR(30)  NOT NULL COMMENT 'Mã vai trò (ADMIN, VETERINARIAN...)',
    name        VARCHAR(100) NOT NULL,
    description VARCHAR(255) NULL,
    is_system   BOOLEAN      NOT NULL DEFAULT FALSE COMMENT 'Vai trò lõi, không cho xóa',
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    UNIQUE KEY uk_roles_code (code)
) ENGINE = InnoDB COMMENT = 'Danh mục vai trò (thay ENUM)';

CREATE TABLE users (
    id            BINARY(16)   NOT NULL COMMENT 'UUIDv7',
    username      VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL COMMENT 'BCrypt',
    status        VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE' COMMENT 'ACTIVE / LOCKED / INACTIVE (không xóa cứng)',
    last_login_at TIMESTAMP    NULL,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    version       BIGINT       NOT NULL DEFAULT 0 COMMENT '@Version',
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_username (username),
    KEY idx_users_status (status)
) ENGINE = InnoDB COMMENT = 'Tài khoản đăng nhập (chỉ thông tin xác thực)';

CREATE TABLE user_roles (
    user_id     BINARY(16) NOT NULL,
    role_id     SMALLINT   NOT NULL,
    assigned_at TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id),
    KEY idx_user_roles_role (role_id),
    CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id) REFERENCES roles (id)
) ENGINE = InnoDB COMMENT = 'Gán vai trò cho tài khoản (N-N)';

CREATE TABLE user_profiles (
    user_id       BINARY(16)   NOT NULL,
    full_name     VARCHAR(150) NOT NULL,
    phone_number  VARCHAR(20)  NOT NULL,
    email         VARCHAR(150) NULL,
    gender        VARCHAR(10)  NULL COMMENT 'MALE / FEMALE / OTHER',
    date_of_birth DATE         NULL,
    address       VARCHAR(255) NULL,
    avatar_key    VARCHAR(255) NULL COMMENT 'Đường dẫn tương đối ảnh đại diện',
    updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_user_profiles_phone (phone_number),
    UNIQUE KEY uk_user_profiles_email (email),
    CONSTRAINT fk_user_profiles_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE = InnoDB COMMENT = 'Thông tin cá nhân chung (1-1 users)';

CREATE TABLE staff_profiles (
    user_id                 BINARY(16)   NOT NULL,
    employee_code           VARCHAR(20)  NOT NULL,
    citizen_id              VARCHAR(20)  NULL,
    position_title          VARCHAR(100) NOT NULL,
    department              VARCHAR(100) NULL,
    room_number             VARCHAR(20)  NULL COMMENT 'Phòng làm việc cố định (Bác sĩ / KTV)',
    employment_type         VARCHAR(20)  NOT NULL DEFAULT 'FULL_TIME' COMMENT 'FULL_TIME / PART_TIME',
    hire_date               DATE         NOT NULL,
    termination_date        DATE         NULL COMMENT 'NULL = đang làm',
    emergency_contact_name  VARCHAR(150) NULL,
    emergency_contact_phone VARCHAR(20)  NULL,
    notes                   TEXT         NULL,
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_staff_employee_code (employee_code),
    UNIQUE KEY uk_staff_citizen_id (citizen_id),
    KEY idx_staff_room (room_number),
    CONSTRAINT fk_staff_profiles_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT chk_staff_termination CHECK (termination_date IS NULL OR termination_date >= hire_date)
) ENGINE = InnoDB COMMENT = 'Hồ sơ nhân sự phòng khám (1-1 users)';

CREATE TABLE veterinarian_profiles (
    user_id             BINARY(16)   NOT NULL,
    license_number      VARCHAR(50)  NOT NULL COMMENT 'Số chứng chỉ hành nghề thú y',
    license_issued_date DATE         NOT NULL,
    license_issued_by   VARCHAR(150) NOT NULL,
    license_expiry_date DATE         NULL,
    academic_degree     VARCHAR(50)  NOT NULL COMMENT 'Bác sĩ thú y, Thạc sĩ, Tiến sĩ',
    specialty           VARCHAR(150) NULL,
    graduated_from      VARCHAR(150) NULL,
    career_start_year   SMALLINT     NULL COMMENT 'Số năm kinh nghiệm = năm hiện tại - giá trị này (tính khi hiển thị)',
    biography           TEXT         NULL,
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_vet_license_number (license_number),
    CONSTRAINT fk_vet_profiles_staff FOREIGN KEY (user_id) REFERENCES staff_profiles (user_id),
    CONSTRAINT chk_vet_license_expiry CHECK (license_expiry_date IS NULL OR license_expiry_date > license_issued_date)
) ENGINE = InnoDB COMMENT = 'Hồ sơ chuyên môn thú y (1-1 staff_profiles)';

CREATE TABLE pet_owner_profiles (
    user_id            BINARY(16)  NOT NULL,
    customer_code      VARCHAR(20) NOT NULL,
    registered_channel VARCHAR(20) NOT NULL DEFAULT 'ONLINE' COMMENT 'ONLINE / AT_CLINIC',
    preferred_contact  VARCHAR(20) NOT NULL DEFAULT 'PHONE' COMMENT 'PHONE / EMAIL / APP',
    notes              TEXT        NULL,
    created_at         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_pet_owner_customer_code (customer_code),
    CONSTRAINT fk_pet_owner_profiles_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE = InnoDB COMMENT = 'Hồ sơ khách hàng / chủ nuôi (1-1 users)';

CREATE TABLE refresh_tokens (
    id          BIGINT    NOT NULL AUTO_INCREMENT,
    user_id     BINARY(16) NOT NULL,
    token_hash  CHAR(64)  NOT NULL COMMENT 'SHA-256 của refresh token (không lưu token gốc)',
    expiry_date TIMESTAMP NOT NULL COMMENT 'Hết hạn sau 7 ngày',
    revoked     BOOLEAN   NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_refresh_tokens_hash (token_hash),
    KEY idx_refresh_tokens_user (user_id),
    CONSTRAINT fk_refresh_tokens_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE = InnoDB COMMENT = 'Phiên đăng nhập, xoay vòng token';

CREATE TABLE outbox_events (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    event_id        BINARY(16)   NOT NULL COMMENT 'UUIDv7, bên nhận dùng để chống xử lý trùng',
    aggregate_type  VARCHAR(50)  NOT NULL COMMENT 'USER, VISIT, SERVICE_INVOICE...',
    aggregate_id    BINARY(16)   NOT NULL,
    event_type      VARCHAR(100) NOT NULL COMMENT 'Tên lớp sự kiện',
    routing_key     VARCHAR(100) NOT NULL COMMENT 'Routing key trên exchange clinic.events',
    payload         JSON         NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING / PUBLISHED / FAILED',
    attempt_count   INT          NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Lùi dần khi gửi lỗi',
    last_error      VARCHAR(500) NULL,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    published_at    TIMESTAMP    NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_outbox_event_id (event_id),
    KEY idx_outbox_relay (status, next_attempt_at, id)
) ENGINE = InnoDB COMMENT = 'Sự kiện chờ phát (Transactional Outbox)';


-- =====================================================================================================================
-- 2. pet_clinic_appointment_db (appointment-service) — 4 bảng, 1 khóa ngoại
-- =====================================================================================================================
USE pet_clinic_appointment_db;

CREATE TABLE appointments (
    id                   BINARY(16)   NOT NULL COMMENT 'UUIDv7',
    appointment_code     VARCHAR(50)  NOT NULL COMMENT 'APT-YYYYMMDD-XXX',
    pet_id               BINARY(16)   NOT NULL COMMENT 'LFK: pet_clinic_clinical_db.pets(id)',
    owner_id             BINARY(16)   NOT NULL COMMENT 'LFK: pet_clinic_auth_db.users(id)',
    pet_name_snapshot    VARCHAR(100) NOT NULL,
    owner_name_snapshot  VARCHAR(150) NOT NULL,
    owner_phone_snapshot VARCHAR(20)  NOT NULL,
    appointment_date     DATE         NOT NULL,
    start_time           TIME         NOT NULL COMMENT 'Giờ bắt đầu khung 30 phút',
    reason               TEXT         NOT NULL,
    booking_channel      VARCHAR(20)  NOT NULL DEFAULT 'ONLINE' COMMENT 'ONLINE / PHONE / WALK_IN',
    status               VARCHAR(20)  NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING / CONFIRMED / CHECKED_IN / CANCELLED / NO_SHOW',
    created_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version              BIGINT       NOT NULL DEFAULT 0 COMMENT '@Version',
    PRIMARY KEY (id),
    UNIQUE KEY uk_appointments_code (appointment_code),
    KEY idx_appointments_slot (appointment_date, start_time, status),
    KEY idx_appointments_owner (owner_id, appointment_date),
    KEY idx_appointments_pet (pet_id)
) ENGINE = InnoDB COMMENT = 'Lịch hẹn khám đặt trước';

CREATE TABLE appointment_status_histories (
    id                 BIGINT      NOT NULL AUTO_INCREMENT,
    appointment_id     BINARY(16)  NOT NULL,
    from_status        VARCHAR(20) NULL COMMENT 'NULL nếu mới tạo',
    to_status          VARCHAR(20) NOT NULL,
    changed_by_user_id BINARY(16)  NULL COMMENT 'LFK: pet_clinic_auth_db.users(id); NULL = hệ thống',
    notes              TEXT        NULL COMMENT 'Lý do hủy / từ chối / ghi chú',
    created_at         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_appt_hist_appointment (appointment_id),
    KEY idx_appt_hist_user (changed_by_user_id),
    CONSTRAINT fk_appt_hist_appointment FOREIGN KEY (appointment_id) REFERENCES appointments (id) ON DELETE CASCADE
) ENGINE = InnoDB COMMENT = 'Lịch sử chuyển trạng thái lịch hẹn';

CREATE TABLE outbox_events (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    event_id        BINARY(16)   NOT NULL COMMENT 'UUIDv7, bên nhận dùng để chống xử lý trùng',
    aggregate_type  VARCHAR(50)  NOT NULL,
    aggregate_id    BINARY(16)   NOT NULL,
    event_type      VARCHAR(100) NOT NULL,
    routing_key     VARCHAR(100) NOT NULL,
    payload         JSON         NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING / PUBLISHED / FAILED',
    attempt_count   INT          NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_error      VARCHAR(500) NULL,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    published_at    TIMESTAMP    NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_outbox_event_id (event_id),
    KEY idx_outbox_relay (status, next_attempt_at, id)
) ENGINE = InnoDB COMMENT = 'Sự kiện chờ phát (Transactional Outbox)';

CREATE TABLE processed_events (
    event_id     BINARY(16)   NOT NULL,
    consumer     VARCHAR(100) NOT NULL COMMENT 'Tên listener đã xử lý',
    processed_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (event_id, consumer)
) ENGINE = InnoDB COMMENT = 'Sự kiện đã xử lý (chống xử lý trùng)';


-- =====================================================================================================================
-- 3. pet_clinic_clinical_db (clinical-service) — 24 bảng, 24 khóa ngoại, 2 VIEW
-- =====================================================================================================================
USE pet_clinic_clinical_db;

-- ---- 3.1 Danh mục & bảng giá dịch vụ -------------------------------------------------------------------------------

CREATE TABLE species (
    id          SMALLINT     NOT NULL AUTO_INCREMENT,
    code        VARCHAR(30)  NOT NULL COMMENT 'DOG, CAT',
    name        VARCHAR(100) NOT NULL,
    description VARCHAR(255) NULL,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    UNIQUE KEY uk_species_code (code)
) ENGINE = InnoDB COMMENT = 'Danh mục loài thú cưng';

CREATE TABLE service_categories (
    id                  SMALLINT     NOT NULL AUTO_INCREMENT,
    code                VARCHAR(30)  NOT NULL COMMENT 'EXAMINATION, LABORATORY, IMAGING...',
    name                VARCHAR(100) NOT NULL,
    queue_type          VARCHAR(20)  NULL COMMENT 'DOCTOR / LABORATORY / IMAGING; NULL = làm tại phòng',
    requires_prepayment BOOLEAN      NOT NULL DEFAULT FALSE COMMENT 'TRUE: thu tiền xong mới phát phiếu xếp hàng',
    display_order       SMALLINT     NOT NULL DEFAULT 0,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    UNIQUE KEY uk_service_categories_code (code)
) ENGINE = InnoDB COMMENT = 'Nhóm dịch vụ (thay ENUM), chính sách thu trước và hàng đợi';

CREATE TABLE services (
    id                BINARY(16)   NOT NULL COMMENT 'UUIDv7',
    category_id       SMALLINT     NOT NULL,
    code              VARCHAR(50)  NOT NULL COMMENT 'EXAM_GEN, LAB_CBC...',
    name              VARCHAR(150) NOT NULL,
    description       TEXT         NULL,
    unit              VARCHAR(30)  NOT NULL DEFAULT 'Lần',
    estimated_minutes SMALLINT     NULL,
    preparation_notes VARCHAR(255) NULL,
    is_active         BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_services_code (code),
    KEY idx_services_category (category_id, is_active),
    CONSTRAINT fk_services_category FOREIGN KEY (category_id) REFERENCES service_categories (id)
) ENGINE = InnoDB COMMENT = 'Thông tin dịch vụ (không chứa giá)';

CREATE TABLE service_prices (
    id             BIGINT         NOT NULL AUTO_INCREMENT,
    service_id     BINARY(16)     NOT NULL,
    price          DECIMAL(12, 2) NOT NULL,
    vat_rate       DECIMAL(4, 2)  NOT NULL DEFAULT 0.00,
    effective_from DATETIME       NOT NULL COMMENT 'Giờ phòng khám (UTC+7)',
    effective_to   DATETIME       NULL COMMENT 'NULL = giá đang áp dụng',
    change_reason  VARCHAR(255)   NULL,
    created_by     BINARY(16)     NOT NULL COMMENT 'LFK: pet_clinic_auth_db.users(id) (ADMIN)',
    created_at     TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_service_prices_effective (service_id, effective_from),
    KEY idx_service_prices_lookup (service_id, effective_from, effective_to),
    CONSTRAINT fk_service_prices_service FOREIGN KEY (service_id) REFERENCES services (id),
    CONSTRAINT chk_service_prices_price CHECK (price >= 0),
    CONSTRAINT chk_service_prices_vat CHECK (vat_rate >= 0 AND vat_rate <= 1),
    CONSTRAINT chk_service_prices_period CHECK (effective_to IS NULL OR effective_to > effective_from)
) ENGINE = InnoDB COMMENT = 'Lịch sử giá dịch vụ theo thời gian hiệu lực (không sửa, không xóa)';

CREATE TABLE lab_test_items (
    id          SMALLINT     NOT NULL AUTO_INCREMENT,
    code        VARCHAR(50)  NOT NULL COMMENT 'WBC, RBC...',
    name        VARCHAR(100) NOT NULL,
    unit        VARCHAR(30)  NOT NULL,
    description VARCHAR(255) NULL COMMENT 'Ý nghĩa lâm sàng',
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    UNIQUE KEY uk_lab_test_items_code (code)
) ENGINE = InnoDB COMMENT = 'Danh mục chỉ số xét nghiệm';

CREATE TABLE service_lab_test_items (
    service_id       BINARY(16) NOT NULL,
    lab_test_item_id SMALLINT   NOT NULL,
    PRIMARY KEY (service_id, lab_test_item_id),
    KEY idx_service_lab_item (lab_test_item_id),
    CONSTRAINT fk_service_lab_items_service FOREIGN KEY (service_id) REFERENCES services (id),
    CONSTRAINT fk_service_lab_items_item FOREIGN KEY (lab_test_item_id) REFERENCES lab_test_items (id)
) ENGINE = InnoDB COMMENT = 'Gói xét nghiệm gồm những chỉ số nào (N-N)';

CREATE TABLE lab_test_reference_ranges (
    lab_test_item_id SMALLINT      NOT NULL,
    species_id       SMALLINT      NOT NULL,
    min_value        DECIMAL(8, 2) NOT NULL,
    max_value        DECIMAL(8, 2) NOT NULL,
    PRIMARY KEY (lab_test_item_id, species_id),
    KEY idx_lab_ranges_species (species_id),
    CONSTRAINT fk_lab_ranges_item FOREIGN KEY (lab_test_item_id) REFERENCES lab_test_items (id),
    CONSTRAINT fk_lab_ranges_species FOREIGN KEY (species_id) REFERENCES species (id),
    CONSTRAINT chk_lab_ranges_minmax CHECK (min_value <= max_value)
) ENGINE = InnoDB COMMENT = 'Khoảng tham chiếu bình thường theo loài';

-- ---- 3.2 Thú cưng, đợt khám, hồ sơ khám ----------------------------------------------------------------------------

CREATE TABLE pets (
    id                          BINARY(16)   NOT NULL COMMENT 'UUIDv7',
    owner_id                    BINARY(16)   NOT NULL COMMENT 'LFK: pet_clinic_auth_db.users(id)',
    owner_name_snapshot         VARCHAR(150) NOT NULL COMMENT 'Cập nhật qua UserProfileUpdatedEvent',
    owner_phone_snapshot        VARCHAR(20)  NOT NULL COMMENT 'Tìm nhanh khi tiếp đón',
    species_id                  SMALLINT     NOT NULL,
    pet_code                    VARCHAR(50)  NOT NULL,
    name                        VARCHAR(100) NOT NULL,
    breed                       VARCHAR(100) NULL,
    gender                      VARCHAR(10)  NOT NULL DEFAULT 'UNKNOWN' COMMENT 'MALE / FEMALE / UNKNOWN',
    date_of_birth               DATE         NULL,
    color                       VARCHAR(100) NULL,
    is_neutered                 BOOLEAN      NOT NULL DEFAULT FALSE,
    microchip_number            VARCHAR(30)  NULL,
    identifying_characteristics TEXT         NULL,
    allergies                   TEXT         NULL COMMENT 'Tiền sử dị ứng thuốc (cảnh báo khi kê đơn)',
    notes                       TEXT         NULL,
    created_at                  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at                  TIMESTAMP    NULL COMMENT 'Xóa mềm; NULL = còn theo dõi',
    PRIMARY KEY (id),
    UNIQUE KEY uk_pets_code (pet_code),
    UNIQUE KEY uk_pets_microchip (microchip_number),
    KEY idx_pets_owner (owner_id),
    KEY idx_pets_owner_phone (owner_phone_snapshot),
    KEY idx_pets_species (species_id),
    CONSTRAINT fk_pets_species FOREIGN KEY (species_id) REFERENCES species (id)
) ENGINE = InnoDB COMMENT = 'Hồ sơ thú cưng (bệnh nhân)';

CREATE TABLE pet_visits (
    id                   BINARY(16)   NOT NULL COMMENT 'UUIDv7',
    visit_code           VARCHAR(50)  NOT NULL COMMENT 'VISIT-YYYY-XXXX',
    pet_id               BINARY(16)   NOT NULL,
    appointment_id       BINARY(16)   NULL COMMENT 'LFK: pet_clinic_appointment_db.appointments(id); NULL = khách vãng lai',
    doctor_id            BINARY(16)   NULL COMMENT 'LFK: pet_clinic_auth_db.users(id); Bác sĩ được phân công',
    doctor_name_snapshot VARCHAR(150) NULL,
    receptionist_id      BINARY(16)   NOT NULL COMMENT 'LFK: pet_clinic_auth_db.users(id)',
    is_emergency         BOOLEAN      NOT NULL DEFAULT FALSE COMMENT 'Cấp cứu: phiếu ưu tiên 2, thu sau',
    reason_for_visit     TEXT         NULL,
    status               VARCHAR(20)  NOT NULL DEFAULT 'WAITING'
        COMMENT 'WAITING / IN_PROGRESS / WAITING_RESULTS / RESULTS_READY / WAITING_PAYMENT / COMPLETED / CANCELLED',
    checked_in_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version              BIGINT       NOT NULL DEFAULT 0 COMMENT '@Version',
    PRIMARY KEY (id),
    UNIQUE KEY uk_pet_visits_code (visit_code),
    UNIQUE KEY uk_pet_visits_appointment (appointment_id),
    KEY idx_visits_doctor_status (doctor_id, status),
    KEY idx_visits_status_checkin (status, checked_in_at),
    KEY idx_visits_pet (pet_id),
    KEY idx_visits_receptionist (receptionist_id),
    CONSTRAINT fk_pet_visits_pet FOREIGN KEY (pet_id) REFERENCES pets (id)
) ENGINE = InnoDB COMMENT = 'Đợt khám - thông tin hành chính (Lễ tân)';

CREATE TABLE vital_signs (
    id                    BIGINT        NOT NULL AUTO_INCREMENT,
    visit_id              BINARY(16)    NOT NULL,
    weight_kg             DECIMAL(5, 2) NULL,
    temperature_c         DECIMAL(4, 1) NULL,
    heart_rate_bpm        SMALLINT      NULL,
    respiratory_rate_bpm  SMALLINT      NULL,
    body_condition_score  TINYINT       NULL COMMENT 'BCS 1-9',
    mucous_membrane_color VARCHAR(30)   NULL,
    capillary_refill_sec  DECIMAL(3, 1) NULL,
    notes                 VARCHAR(255)  NULL,
    recorded_by           BINARY(16)    NOT NULL COMMENT 'LFK: pet_clinic_auth_db.users(id)',
    recorded_at           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_vital_signs_visit (visit_id, recorded_at),
    CONSTRAINT fk_vital_signs_visit FOREIGN KEY (visit_id) REFERENCES pet_visits (id),
    CONSTRAINT chk_vital_weight CHECK (weight_kg IS NULL OR weight_kg > 0),
    CONSTRAINT chk_vital_temperature CHECK (temperature_c IS NULL OR temperature_c BETWEEN 30 AND 45),
    CONSTRAINT chk_vital_bcs CHECK (body_condition_score IS NULL OR body_condition_score BETWEEN 1 AND 9)
) ENGINE = InnoDB COMMENT = 'Sinh hiệu / tiền trạm (đo được nhiều lần)';

CREATE TABLE medical_records (
    visit_id              BINARY(16) NOT NULL,
    anamnesis             TEXT       NULL COMMENT 'Bệnh sử, triệu chứng chủ nuôi kể',
    clinical_findings     TEXT       NULL,
    preliminary_diagnosis TEXT       NULL COMMENT 'Chẩn đoán sơ bộ (pha 1)',
    final_diagnosis       TEXT       NULL COMMENT 'Chẩn đoán xác định (pha 2)',
    treatment_plan        TEXT       NULL,
    doctor_advice         TEXT       NULL,
    follow_up_date        DATE       NULL,
    created_at            TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    version               BIGINT     NOT NULL DEFAULT 0 COMMENT '@Version',
    PRIMARY KEY (visit_id),
    CONSTRAINT fk_medical_records_visit FOREIGN KEY (visit_id) REFERENCES pet_visits (id)
) ENGINE = InnoDB COMMENT = 'Hồ sơ khám chuyên môn (Bác sĩ, 1-1 đợt khám)';

CREATE TABLE pet_visit_status_histories (
    id                 BIGINT      NOT NULL AUTO_INCREMENT,
    visit_id           BINARY(16)  NOT NULL,
    from_status        VARCHAR(20) NULL,
    to_status          VARCHAR(20) NOT NULL,
    changed_by_user_id BINARY(16)  NULL COMMENT 'LFK: pet_clinic_auth_db.users(id); NULL = hệ thống',
    notes              TEXT        NULL COMMENT 'Lý do hủy / ghi chú',
    created_at         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_visit_hist_visit (visit_id),
    KEY idx_visit_hist_user (changed_by_user_id),
    CONSTRAINT fk_visit_hist_visit FOREIGN KEY (visit_id) REFERENCES pet_visits (id) ON DELETE CASCADE
) ENGINE = InnoDB COMMENT = 'Lịch sử chuyển trạng thái đợt khám';

-- ---- 3.3 Chỉ định dịch vụ, kết quả, hóa đơn dịch vụ ----------------------------------------------------------------

CREATE TABLE visit_service_details (
    id         BINARY(16)  NOT NULL COMMENT 'UUIDv7',
    visit_id   BINARY(16)  NOT NULL,
    service_id BINARY(16)  NOT NULL,
    quantity   INT         NOT NULL DEFAULT 1,
    status     VARCHAR(20) NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING / IN_PROGRESS / COMPLETED / CANCELLED',
    notes      TEXT        NULL,
    created_at TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version    BIGINT      NOT NULL DEFAULT 0 COMMENT '@Version',
    PRIMARY KEY (id),
    KEY idx_vsd_visit (visit_id),
    KEY idx_vsd_service (service_id),
    CONSTRAINT fk_vsd_visit FOREIGN KEY (visit_id) REFERENCES pet_visits (id),
    CONSTRAINT fk_vsd_service FOREIGN KEY (service_id) REFERENCES services (id),
    CONSTRAINT chk_vsd_quantity CHECK (quantity > 0)
) ENGINE = InnoDB COMMENT = 'Dịch vụ được chỉ định trong đợt khám (không chứa giá)';

CREATE TABLE visit_service_detail_histories (
    id                      BIGINT      NOT NULL AUTO_INCREMENT,
    visit_service_detail_id BINARY(16)  NOT NULL,
    from_status             VARCHAR(20) NULL,
    to_status               VARCHAR(20) NOT NULL,
    action                  VARCHAR(30) NOT NULL COMMENT 'ORDERED / START_PROCESSING / SAMPLE_COLLECTED / COMPLETED / CANCELLED',
    changed_by_user_id      BINARY(16)  NOT NULL COMMENT 'LFK: pet_clinic_auth_db.users(id)',
    reason                  TEXT        NULL COMMENT 'Lý do hủy / ghi chú',
    created_at              TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_vsd_hist_detail (visit_service_detail_id),
    CONSTRAINT fk_vsd_hist_detail FOREIGN KEY (visit_service_detail_id) REFERENCES visit_service_details (id) ON DELETE CASCADE
) ENGINE = InnoDB COMMENT = 'Lịch sử tiến độ thực hiện dịch vụ';

CREATE TABLE lab_test_results (
    id                      BIGINT        NOT NULL AUTO_INCREMENT,
    visit_service_detail_id BINARY(16)    NOT NULL,
    lab_test_item_id        SMALLINT      NOT NULL,
    result_value            DECIMAL(8, 2) NOT NULL,
    min_value_snapshot      DECIMAL(8, 2) NOT NULL COMMENT 'Ngưỡng dưới tại thời điểm xét nghiệm',
    max_value_snapshot      DECIMAL(8, 2) NOT NULL COMMENT 'Ngưỡng trên tại thời điểm xét nghiệm',
    performed_by            BINARY(16)    NOT NULL COMMENT 'LFK: pet_clinic_auth_db.users(id) (KTV xét nghiệm)',
    notes                   TEXT          NULL,
    created_at              TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_lab_results_detail_item (visit_service_detail_id, lab_test_item_id),
    KEY idx_lab_results_item (lab_test_item_id),
    CONSTRAINT fk_lab_results_detail FOREIGN KEY (visit_service_detail_id) REFERENCES visit_service_details (id),
    CONSTRAINT fk_lab_results_item FOREIGN KEY (lab_test_item_id) REFERENCES lab_test_items (id)
) ENGINE = InnoDB COMMENT = 'Kết quả từng chỉ số xét nghiệm (nhãn LOW/NORMAL/HIGH tính khi hiển thị, không lưu)';

CREATE TABLE imaging_results (
    id                      BINARY(16) NOT NULL COMMENT 'UUIDv7',
    visit_service_detail_id BINARY(16) NOT NULL,
    description             TEXT       NOT NULL,
    conclusion              TEXT       NOT NULL,
    performed_by            BINARY(16) NOT NULL COMMENT 'LFK: pet_clinic_auth_db.users(id)',
    performed_at            TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_imaging_results_detail (visit_service_detail_id),
    CONSTRAINT fk_imaging_results_detail FOREIGN KEY (visit_service_detail_id) REFERENCES visit_service_details (id)
) ENGINE = InnoDB COMMENT = 'Kết quả chẩn đoán hình ảnh (1-1 dòng chỉ định)';

CREATE TABLE imaging_attachments (
    id                 BINARY(16)   NOT NULL COMMENT 'UUIDv7',
    imaging_result_id  BINARY(16)   NOT NULL,
    file_key           VARCHAR(255) NOT NULL COMMENT 'Đường dẫn tương đối trong kho lưu trữ (không lưu URL)',
    original_file_name VARCHAR(255) NOT NULL,
    content_type       VARCHAR(100) NOT NULL,
    file_size          BIGINT       NOT NULL COMMENT 'byte',
    uploaded_by        BINARY(16)   NOT NULL COMMENT 'LFK: pet_clinic_auth_db.users(id)',
    uploaded_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_imaging_attachments_file_key (file_key),
    KEY idx_imaging_attachments_result (imaging_result_id),
    CONSTRAINT fk_imaging_attachments_result FOREIGN KEY (imaging_result_id) REFERENCES imaging_results (id) ON DELETE CASCADE,
    CONSTRAINT chk_imaging_file_size CHECK (file_size > 0)
) ENGINE = InnoDB COMMENT = 'Tệp ảnh X-quang / siêu âm đính kèm';

CREATE TABLE service_invoices (
    id                      BINARY(16)     NOT NULL COMMENT 'UUIDv7',
    invoice_code            VARCHAR(50)    NOT NULL COMMENT 'SINV-YYYY-XXXX',
    visit_service_detail_id BINARY(16)     NOT NULL,
    unit_price              DECIMAL(12, 2) NOT NULL COMMENT 'Chụp từ service_prices lúc chỉ định',
    vat_rate                DECIMAL(4, 2)  NOT NULL DEFAULT 0.00 COMMENT 'Chụp từ service_prices lúc chỉ định',
    discount_amount         DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    payment_status          VARCHAR(20)    NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING / PAID / CANCELLED / REFUNDED',
    cashier_id              BINARY(16)     NULL COMMENT 'LFK: pet_clinic_auth_db.users(id)',
    paid_at                 TIMESTAMP      NULL,
    created_at              TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version                 BIGINT         NOT NULL DEFAULT 0 COMMENT '@Version',
    PRIMARY KEY (id),
    UNIQUE KEY uk_service_invoices_code (invoice_code),
    UNIQUE KEY uk_service_invoices_detail (visit_service_detail_id),
    KEY idx_service_invoices_status_paid (payment_status, paid_at),
    KEY idx_service_invoices_cashier (cashier_id),
    CONSTRAINT fk_service_invoices_detail FOREIGN KEY (visit_service_detail_id) REFERENCES visit_service_details (id),
    CONSTRAINT chk_service_invoices_price CHECK (unit_price >= 0),
    CONSTRAINT chk_service_invoices_vat CHECK (vat_rate >= 0 AND vat_rate <= 1),
    CONSTRAINT chk_service_invoices_discount CHECK (discount_amount >= 0)
) ENGINE = InnoDB COMMENT = 'Hóa đơn riêng cho từng dịch vụ (1-1); không lưu tổng tiền';

-- ---- 3.4 Đơn thuốc (chuyên môn, không giá, không trạng thái) -------------------------------------------------------

CREATE TABLE prescriptions (
    id           BINARY(16) NOT NULL COMMENT 'UUIDv7',
    visit_id     BINARY(16) NOT NULL,
    doctor_notes TEXT       NULL,
    created_at   TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_prescriptions_visit (visit_id),
    CONSTRAINT fk_prescriptions_visit FOREIGN KEY (visit_id) REFERENCES pet_visits (id)
) ENGINE = InnoDB COMMENT = 'Đơn thuốc Bác sĩ kê (tối đa 1 đơn / đợt khám)';

CREATE TABLE prescription_items (
    id                     BIGINT       NOT NULL AUTO_INCREMENT,
    prescription_id        BINARY(16)   NOT NULL,
    medicine_id            BINARY(16)   NOT NULL COMMENT 'LFK: pet_clinic_billing_pharmacy_db.medicines(id)',
    medicine_name_snapshot VARCHAR(150) NOT NULL,
    unit_snapshot          VARCHAR(30)  NOT NULL,
    quantity               INT          NOT NULL,
    dosage                 VARCHAR(100) NOT NULL,
    frequency              VARCHAR(100) NOT NULL,
    duration_days          INT          NOT NULL,
    instructions           TEXT         NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_prescription_items_medicine (prescription_id, medicine_id),
    KEY idx_prescription_items_medicine_id (medicine_id),
    CONSTRAINT fk_prescription_items_prescription FOREIGN KEY (prescription_id) REFERENCES prescriptions (id) ON DELETE CASCADE,
    CONSTRAINT chk_prescription_items_quantity CHECK (quantity > 0),
    CONSTRAINT chk_prescription_items_duration CHECK (duration_days > 0)
) ENGINE = InnoDB COMMENT = 'Từng thuốc được kê trong đơn';

-- ---- 3.5 Lịch sử phiếu xếp hàng (phiếu đang chạy nằm trên Redis) ---------------------------------------------------

CREATE TABLE queue_ticket_histories (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    ticket_id     BINARY(16)   NOT NULL COMMENT 'UUIDv7 sinh khi phát phiếu trên Redis',
    queue_type    VARCHAR(20)  NOT NULL COMMENT 'DOCTOR / LABORATORY / IMAGING',
    service_date  DATE         NOT NULL COMMENT 'Ngày phát phiếu (giờ phòng khám)',
    ticket_no     INT          NOT NULL COMMENT 'Số in trên phiếu (theo ngày, theo hàng đợi)',
    visit_id      BINARY(16)   NOT NULL,
    doctor_id     BINARY(16)   NULL COMMENT 'LFK: pet_clinic_auth_db.users(id) (chỉ phiếu DOCTOR)',
    priority      TINYINT      NOT NULL DEFAULT 0 COMMENT '2 cấp cứu / 1 quay lại có kết quả CLS / 0 thường',
    final_status  VARCHAR(20)  NOT NULL COMMENT 'DONE / CANCELLED',
    issued_at     TIMESTAMP    NOT NULL,
    issued_by     BINARY(16)   NULL COMMENT 'LFK: pet_clinic_auth_db.users(id); NULL = hệ thống tự phát',
    called_count  SMALLINT     NOT NULL DEFAULT 0,
    started_at    TIMESTAMP    NULL,
    ended_at      TIMESTAMP    NOT NULL,
    cancel_reason VARCHAR(255) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_queue_hist_ticket (ticket_id),
    UNIQUE KEY uk_queue_hist_no (queue_type, service_date, ticket_no),
    KEY idx_queue_hist_visit (visit_id),
    KEY idx_queue_hist_date_type (service_date, queue_type),
    CONSTRAINT fk_queue_hist_visit FOREIGN KEY (visit_id) REFERENCES pet_visits (id),
    CONSTRAINT chk_queue_hist_priority CHECK (priority BETWEEN 0 AND 2)
) ENGINE = InnoDB COMMENT = 'Lịch sử phiếu xếp hàng đã kết thúc';

CREATE TABLE queue_ticket_history_items (
    history_id              BIGINT     NOT NULL,
    visit_service_detail_id BINARY(16) NOT NULL,
    PRIMARY KEY (history_id, visit_service_detail_id),
    KEY idx_queue_hist_items_detail (visit_service_detail_id),
    CONSTRAINT fk_queue_hist_items_history FOREIGN KEY (history_id) REFERENCES queue_ticket_histories (id) ON DELETE CASCADE,
    CONSTRAINT fk_queue_hist_items_detail FOREIGN KEY (visit_service_detail_id) REFERENCES visit_service_details (id)
) ENGINE = InnoDB COMMENT = 'Dịch vụ XN / CĐHA thuộc phiếu đã kết thúc';

-- ---- 3.6 Hạ tầng sự kiện -------------------------------------------------------------------------------------------

CREATE TABLE outbox_events (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    event_id        BINARY(16)   NOT NULL COMMENT 'UUIDv7, bên nhận dùng để chống xử lý trùng',
    aggregate_type  VARCHAR(50)  NOT NULL,
    aggregate_id    BINARY(16)   NOT NULL,
    event_type      VARCHAR(100) NOT NULL,
    routing_key     VARCHAR(100) NOT NULL,
    payload         JSON         NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING / PUBLISHED / FAILED',
    attempt_count   INT          NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_error      VARCHAR(500) NULL,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    published_at    TIMESTAMP    NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_outbox_event_id (event_id),
    KEY idx_outbox_relay (status, next_attempt_at, id)
) ENGINE = InnoDB COMMENT = 'Sự kiện chờ phát (Transactional Outbox)';

CREATE TABLE processed_events (
    event_id     BINARY(16)   NOT NULL,
    consumer     VARCHAR(100) NOT NULL COMMENT 'Tên listener đã xử lý',
    processed_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (event_id, consumer)
) ENGINE = InnoDB COMMENT = 'Sự kiện đã xử lý (chống xử lý trùng)';

-- ---- 3.7 VIEW (giá trị tính, không lưu) ----------------------------------------------------------------------------
-- Giờ phòng khám = UTC + 7 (Việt Nam không có giờ mùa hè). Dùng UTC_TIMESTAMP() để kết quả không phụ thuộc múi giờ phiên.

CREATE VIEW v_current_service_prices AS
SELECT s.id AS service_id, s.code, s.name, s.category_id, s.is_active,
       sp.id AS price_id, sp.price, sp.vat_rate, sp.effective_from, sp.effective_to
FROM services s
         JOIN service_prices sp ON sp.service_id = s.id
WHERE sp.effective_from <= DATE_ADD(UTC_TIMESTAMP(), INTERVAL 7 HOUR)
  AND (sp.effective_to IS NULL OR sp.effective_to > DATE_ADD(UTC_TIMESTAMP(), INTERVAL 7 HOUR));

-- Tiền phải trả = quantity x unit_price x (1 + vat_rate) - discount_amount
CREATE VIEW v_service_invoice_amounts AS
SELECT si.id                                                                  AS invoice_id,
       si.invoice_code,
       si.visit_service_detail_id,
       vsd.visit_id,
       vsd.service_id,
       sc.code                                                                AS category_code,
       vsd.quantity,
       si.unit_price,
       si.vat_rate,
       si.discount_amount,
       si.payment_status,
       ROUND(vsd.quantity * si.unit_price, 2)                                 AS amount_before_vat,
       ROUND(vsd.quantity * si.unit_price * si.vat_rate, 2)                   AS vat_amount,
       ROUND(vsd.quantity * si.unit_price * (1 + si.vat_rate), 2)             AS gross_amount,
       ROUND(vsd.quantity * si.unit_price * (1 + si.vat_rate), 2) - si.discount_amount AS payable_amount
FROM service_invoices si
         JOIN visit_service_details vsd ON vsd.id = si.visit_service_detail_id
         JOIN services s ON s.id = vsd.service_id
         JOIN service_categories sc ON sc.id = s.category_id;


-- =====================================================================================================================
-- 4. pet_clinic_billing_pharmacy_db (billing-pharmacy-service) — 10 bảng, 8 khóa ngoại, 2 VIEW
-- =====================================================================================================================
USE pet_clinic_billing_pharmacy_db;

CREATE TABLE medicine_categories (
    id        SMALLINT     NOT NULL AUTO_INCREMENT,
    code      VARCHAR(30)  NOT NULL COMMENT 'ANTIBIOTIC, VACCINE...',
    name      VARCHAR(100) NOT NULL,
    is_active BOOLEAN      NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    UNIQUE KEY uk_medicine_categories_code (code)
) ENGINE = InnoDB COMMENT = 'Nhóm thuốc (danh mục)';

CREATE TABLE medicines (
    id                    BINARY(16)   NOT NULL COMMENT 'UUIDv7',
    category_id           SMALLINT     NOT NULL,
    code                  VARCHAR(50)  NOT NULL,
    name                  VARCHAR(150) NOT NULL COMMENT 'Tên thương mại',
    dosage_form           VARCHAR(50)  NOT NULL COMMENT 'Dạng bào chế',
    strength              VARCHAR(50)  NULL COMMENT 'Hàm lượng hiển thị (250mg)',
    base_unit             VARCHAR(30)  NOT NULL COMMENT 'Đơn vị bán nhỏ nhất (viên, lọ)',
    packaging_spec        VARCHAR(150) NOT NULL COMMENT 'Quy cách đóng gói (Hộp 10 vỉ x 10 viên)',
    manufacturer          VARCHAR(150) NULL,
    country_of_origin     VARCHAR(100) NULL,
    registration_number   VARCHAR(50)  NULL,
    storage_conditions    VARCHAR(255) NULL,
    requires_prescription BOOLEAN      NOT NULL DEFAULT TRUE,
    min_stock_alert       INT          NOT NULL DEFAULT 10 COMMENT 'Ngưỡng cảnh báo sắp hết',
    is_active             BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_medicines_code (code),
    KEY idx_medicines_category (category_id, is_active),
    CONSTRAINT fk_medicines_category FOREIGN KEY (category_id) REFERENCES medicine_categories (id),
    CONSTRAINT chk_medicines_min_stock CHECK (min_stock_alert >= 0)
) ENGINE = InnoDB COMMENT = 'Thông tin thuốc và quy cách (không giá, không tồn)';

CREATE TABLE medicine_ingredients (
    id              BIGINT         NOT NULL AUTO_INCREMENT,
    medicine_id     BINARY(16)     NOT NULL,
    ingredient_name VARCHAR(150)   NOT NULL,
    strength_value  DECIMAL(10, 3) NULL,
    strength_unit   VARCHAR(20)    NULL COMMENT 'mg, ml, IU...',
    PRIMARY KEY (id),
    UNIQUE KEY uk_medicine_ingredients (medicine_id, ingredient_name),
    CONSTRAINT fk_medicine_ingredients_medicine FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
) ENGINE = InnoDB COMMENT = 'Thành phần hoạt chất của thuốc';

CREATE TABLE medicine_prices (
    id             BIGINT         NOT NULL AUTO_INCREMENT,
    medicine_id    BINARY(16)     NOT NULL,
    sale_price     DECIMAL(12, 2) NOT NULL,
    vat_rate       DECIMAL(4, 2)  NOT NULL DEFAULT 0.05,
    effective_from DATETIME       NOT NULL COMMENT 'Giờ phòng khám (UTC+7)',
    effective_to   DATETIME       NULL COMMENT 'NULL = giá đang áp dụng',
    change_reason  VARCHAR(255)   NULL,
    created_by     BINARY(16)     NOT NULL COMMENT 'LFK: pet_clinic_auth_db.users(id) (ADMIN)',
    created_at     TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_medicine_prices_effective (medicine_id, effective_from),
    KEY idx_medicine_prices_lookup (medicine_id, effective_from, effective_to),
    CONSTRAINT fk_medicine_prices_medicine FOREIGN KEY (medicine_id) REFERENCES medicines (id),
    CONSTRAINT chk_medicine_prices_price CHECK (sale_price >= 0),
    CONSTRAINT chk_medicine_prices_vat CHECK (vat_rate >= 0 AND vat_rate <= 1),
    CONSTRAINT chk_medicine_prices_period CHECK (effective_to IS NULL OR effective_to > effective_from)
) ENGINE = InnoDB COMMENT = 'Lịch sử giá bán thuốc theo thời gian hiệu lực (không sửa, không xóa)';

CREATE TABLE medicine_stocks (
    medicine_id      BINARY(16) NOT NULL,
    quantity_on_hand INT        NOT NULL DEFAULT 0 COMMENT 'Bất biến: = SUM(inventory_transactions.quantity)',
    updated_at       TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    version          BIGINT     NOT NULL DEFAULT 0 COMMENT '@Version',
    PRIMARY KEY (medicine_id),
    CONSTRAINT fk_medicine_stocks_medicine FOREIGN KEY (medicine_id) REFERENCES medicines (id),
    CONSTRAINT chk_medicine_stocks_qty CHECK (quantity_on_hand >= 0)
) ENGINE = InnoDB COMMENT = 'Tồn kho hiện tại (1-1 medicines), trừ nguyên tử bằng UPDATE có điều kiện';

CREATE TABLE medicine_invoices (
    id                      BINARY(16)     NOT NULL COMMENT 'UUIDv7',
    invoice_code            VARCHAR(50)    NOT NULL COMMENT 'MINV-YYYY-XXXX',
    prescription_id         BINARY(16)     NOT NULL COMMENT 'LFK: pet_clinic_clinical_db.prescriptions(id)',
    visit_id                BINARY(16)     NOT NULL COMMENT 'LFK: pet_clinic_clinical_db.pet_visits(id)',
    customer_name_snapshot  VARCHAR(150)   NOT NULL,
    customer_phone_snapshot VARCHAR(20)    NOT NULL,
    pet_name_snapshot       VARCHAR(100)   NOT NULL,
    doctor_name_snapshot    VARCHAR(150)   NOT NULL,
    discount_amount         DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    payment_status          VARCHAR(20)    NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING (nháp) / PAID / CANCELLED',
    cashier_id              BINARY(16)     NULL COMMENT 'LFK: pet_clinic_auth_db.users(id)',
    paid_at                 TIMESTAMP      NULL,
    created_at              TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version                 BIGINT         NOT NULL DEFAULT 0 COMMENT '@Version',
    PRIMARY KEY (id),
    UNIQUE KEY uk_medicine_invoices_code (invoice_code),
    UNIQUE KEY uk_medicine_invoices_prescription (prescription_id),
    KEY idx_medicine_invoices_status_paid (payment_status, paid_at),
    KEY idx_medicine_invoices_visit (visit_id),
    KEY idx_medicine_invoices_cashier (cashier_id),
    CONSTRAINT chk_medicine_invoices_discount CHECK (discount_amount >= 0)
) ENGINE = InnoDB COMMENT = 'Hóa đơn thuốc (nháp tự tạo từ PrescriptionCreatedEvent)';

CREATE TABLE medicine_invoice_items (
    id                  BIGINT         NOT NULL AUTO_INCREMENT,
    medicine_invoice_id BINARY(16)     NOT NULL,
    medicine_id         BINARY(16)     NOT NULL,
    prescribed_quantity INT            NOT NULL COMMENT 'Số lượng kê (từ sự kiện), để đối chiếu',
    quantity            INT            NOT NULL COMMENT 'Số lượng khách mua (khác số kê được, <= tồn kho)',
    unit_price          DECIMAL(12, 2) NOT NULL COMMENT 'Chụp từ medicine_prices lúc thu',
    vat_rate            DECIMAL(4, 2)  NOT NULL COMMENT 'Chụp từ medicine_prices lúc thu',
    PRIMARY KEY (id),
    UNIQUE KEY uk_medicine_invoice_items (medicine_invoice_id, medicine_id),
    KEY idx_medicine_invoice_items_medicine (medicine_id),
    CONSTRAINT fk_medicine_invoice_items_invoice FOREIGN KEY (medicine_invoice_id) REFERENCES medicine_invoices (id) ON DELETE CASCADE,
    CONSTRAINT fk_medicine_invoice_items_medicine FOREIGN KEY (medicine_id) REFERENCES medicines (id),
    CONSTRAINT chk_medicine_invoice_items_qty CHECK (quantity > 0),
    CONSTRAINT chk_medicine_invoice_items_price CHECK (unit_price >= 0),
    CONSTRAINT chk_medicine_invoice_items_vat CHECK (vat_rate >= 0 AND vat_rate <= 1)
) ENGINE = InnoDB COMMENT = 'Từng thuốc trên hóa đơn (trỏ thẳng medicines)';

CREATE TABLE inventory_transactions (
    id                  BIGINT         NOT NULL AUTO_INCREMENT,
    medicine_id         BINARY(16)     NOT NULL,
    transaction_type    VARCHAR(20)    NOT NULL COMMENT 'IMPORT / EXPORT_SALE / ADJUSTMENT',
    quantity            INT            NOT NULL COMMENT 'Có dấu: + nhập, - xuất',
    unit_cost           DECIMAL(12, 2) NULL COMMENT 'Giá nhập (chỉ IMPORT)',
    medicine_invoice_id BINARY(16)     NULL COMMENT 'Hóa đơn thuốc khi xuất bán',
    notes               VARCHAR(255)   NULL,
    created_by          BINARY(16)     NOT NULL COMMENT 'LFK: pet_clinic_auth_db.users(id)',
    created_at          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_inventory_medicine_time (medicine_id, created_at),
    KEY idx_inventory_invoice (medicine_invoice_id),
    KEY idx_inventory_created_by (created_by),
    CONSTRAINT fk_inventory_medicine FOREIGN KEY (medicine_id) REFERENCES medicines (id),
    CONSTRAINT fk_inventory_invoice FOREIGN KEY (medicine_invoice_id) REFERENCES medicine_invoices (id),
    CONSTRAINT chk_inventory_quantity CHECK (quantity <> 0)
) ENGINE = InnoDB COMMENT = 'Nhật ký nhập / xuất / điều chỉnh kho (tồn sau giao dịch tính bằng tổng lũy kế)';

CREATE TABLE outbox_events (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    event_id        BINARY(16)   NOT NULL COMMENT 'UUIDv7, bên nhận dùng để chống xử lý trùng',
    aggregate_type  VARCHAR(50)  NOT NULL,
    aggregate_id    BINARY(16)   NOT NULL,
    event_type      VARCHAR(100) NOT NULL,
    routing_key     VARCHAR(100) NOT NULL,
    payload         JSON         NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING / PUBLISHED / FAILED',
    attempt_count   INT          NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_error      VARCHAR(500) NULL,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    published_at    TIMESTAMP    NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_outbox_event_id (event_id),
    KEY idx_outbox_relay (status, next_attempt_at, id)
) ENGINE = InnoDB COMMENT = 'Sự kiện chờ phát (Transactional Outbox)';

CREATE TABLE processed_events (
    event_id     BINARY(16)   NOT NULL,
    consumer     VARCHAR(100) NOT NULL COMMENT 'Tên listener đã xử lý',
    processed_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (event_id, consumer)
) ENGINE = InnoDB COMMENT = 'Sự kiện đã xử lý (chống xử lý trùng)';

CREATE VIEW v_current_medicine_prices AS
SELECT m.id AS medicine_id, m.code, m.name, m.category_id, m.is_active,
       mp.id AS price_id, mp.sale_price, mp.vat_rate, mp.effective_from, mp.effective_to
FROM medicines m
         JOIN medicine_prices mp ON mp.medicine_id = m.id
WHERE mp.effective_from <= DATE_ADD(UTC_TIMESTAMP(), INTERVAL 7 HOUR)
  AND (mp.effective_to IS NULL OR mp.effective_to > DATE_ADD(UTC_TIMESTAMP(), INTERVAL 7 HOUR));

-- Tiền phải trả = SUM(quantity x unit_price x (1 + vat_rate)) - discount_amount
CREATE VIEW v_medicine_invoice_amounts AS
SELECT mi.id AS invoice_id,
       mi.invoice_code,
       mi.visit_id,
       mi.prescription_id,
       mi.payment_status,
       mi.discount_amount,
       COALESCE(ROUND(SUM(it.quantity * it.unit_price), 2), 0)                         AS amount_before_vat,
       COALESCE(ROUND(SUM(it.quantity * it.unit_price * it.vat_rate), 2), 0)           AS vat_amount,
       COALESCE(ROUND(SUM(it.quantity * it.unit_price * (1 + it.vat_rate)), 2), 0)     AS gross_amount,
       COALESCE(ROUND(SUM(it.quantity * it.unit_price * (1 + it.vat_rate)), 2), 0) - mi.discount_amount AS payable_amount
FROM medicine_invoices mi
         LEFT JOIN medicine_invoice_items it ON it.medicine_invoice_id = mi.id
GROUP BY mi.id;


-- =====================================================================================================================
-- 5. pet_clinic_reporting_db (reporting-service) — 5 bảng, 0 khóa ngoại (mô hình đọc phi chuẩn hóa, chỉ ghi bằng sự kiện)
-- =====================================================================================================================
USE pet_clinic_reporting_db;

CREATE TABLE visit_facts (
    visit_id       BINARY(16)   NOT NULL COMMENT 'Cùng mã với clinical',
    visit_code     VARCHAR(50)  NOT NULL,
    business_date  DATE         NOT NULL,
    checked_in_at  TIMESTAMP    NOT NULL,
    completed_at   TIMESTAMP    NULL,
    current_status VARCHAR(20)  NOT NULL COMMENT 'Trạng thái mới nhất nhận được (VisitStatus)',
    is_emergency   BOOLEAN      NOT NULL,
    pet_id         BINARY(16)   NOT NULL,
    pet_name       VARCHAR(100) NOT NULL,
    species_code   VARCHAR(30)  NOT NULL,
    owner_id       BINARY(16)   NOT NULL,
    owner_name     VARCHAR(150) NOT NULL,
    doctor_id      BINARY(16)   NULL,
    doctor_name    VARCHAR(150) NULL,
    updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (visit_id),
    KEY idx_visit_facts_date_status (business_date, current_status),
    KEY idx_visit_facts_doctor_date (doctor_id, business_date)
) ENGINE = InnoDB COMMENT = 'Bảng phẳng lượt khám (1 dòng / đợt khám)';

CREATE TABLE revenue_facts (
    id                BIGINT         NOT NULL AUTO_INCREMENT,
    revenue_type      VARCHAR(20)    NOT NULL COMMENT 'SERVICE / MEDICINE',
    entry_type        VARCHAR(20)    NOT NULL COMMENT 'SALE / REFUND (REFUND số tiền âm)',
    source_invoice_id BINARY(16)     NOT NULL,
    invoice_code      VARCHAR(50)    NOT NULL,
    item_id           BINARY(16)     NOT NULL COMMENT 'Dịch vụ hoặc thuốc',
    item_code         VARCHAR(50)    NOT NULL,
    item_name         VARCHAR(150)   NOT NULL,
    category_code     VARCHAR(30)    NOT NULL,
    category_name     VARCHAR(100)   NOT NULL,
    visit_id          BINARY(16)     NOT NULL,
    doctor_id         BINARY(16)     NULL,
    doctor_name       VARCHAR(150)   NULL,
    cashier_id        BINARY(16)     NULL,
    business_date     DATE           NOT NULL,
    occurred_at       TIMESTAMP      NOT NULL,
    quantity          INT            NOT NULL,
    amount_before_vat DECIMAL(14, 2) NOT NULL,
    vat_amount        DECIMAL(14, 2) NOT NULL,
    discount_amount   DECIMAL(14, 2) NOT NULL,
    net_amount        DECIMAL(14, 2) NOT NULL COMMENT 'Thực thu (âm nếu hoàn)',
    PRIMARY KEY (id),
    UNIQUE KEY uk_revenue_facts_source (source_invoice_id, item_id, entry_type),
    KEY idx_revenue_facts_date_type (business_date, revenue_type, category_code),
    KEY idx_revenue_facts_doctor_date (doctor_id, business_date)
) ENGINE = InnoDB COMMENT = 'Bảng phẳng dòng doanh thu đã thu / đã hoàn';

CREATE TABLE daily_revenue_summaries (
    business_date     DATE           NOT NULL,
    revenue_type      VARCHAR(20)    NOT NULL COMMENT 'SERVICE / MEDICINE',
    category_code     VARCHAR(30)    NOT NULL,
    category_name     VARCHAR(100)   NOT NULL,
    line_count        INT            NOT NULL DEFAULT 0,
    amount_before_vat DECIMAL(16, 2) NOT NULL DEFAULT 0,
    vat_amount        DECIMAL(16, 2) NOT NULL DEFAULT 0,
    discount_amount   DECIMAL(16, 2) NOT NULL DEFAULT 0,
    net_amount        DECIMAL(16, 2) NOT NULL DEFAULT 0,
    updated_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (business_date, revenue_type, category_code)
) ENGINE = InnoDB COMMENT = 'Tổng hợp doanh thu theo ngày / loại / nhóm';

CREATE TABLE doctor_daily_performances (
    business_date       DATE           NOT NULL,
    doctor_id           BINARY(16)     NOT NULL,
    doctor_name         VARCHAR(150)   NOT NULL,
    completed_visits    INT            NOT NULL DEFAULT 0,
    cancelled_visits    INT            NOT NULL DEFAULT 0,
    emergency_visits    INT            NOT NULL DEFAULT 0,
    service_net_revenue DECIMAL(16, 2) NOT NULL DEFAULT 0,
    updated_at          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (business_date, doctor_id)
) ENGINE = InnoDB COMMENT = 'Hiệu suất Bác sĩ theo ngày';

CREATE TABLE processed_events (
    event_id     BINARY(16)   NOT NULL,
    consumer     VARCHAR(100) NOT NULL COMMENT 'Tên listener đã xử lý',
    processed_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (event_id, consumer)
) ENGINE = InnoDB COMMENT = 'Sự kiện đã xử lý (chống xử lý trùng)';

-- (Dữ liệu danh mục khởi tạo: thêm ở bước P0.3)
