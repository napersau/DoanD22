-- Kiểm tra dữ liệu danh mục khởi tạo (P0.3). Mỗi dòng: check_name, ok (1 = đạt, 0 = lỗi). Không nằm trong initdb.
-- Chạy sau db/schema_current.sql: mysql ... --default-character-set=utf8mb4 < db/verify_seed.sql ; mọi dòng phải có ok = 1.
-- Lưu ý: (1) VIEW giá hiện hành so với giờ hiện tại (UTC+7) nên cần đồng hồ máy từ 01/01/2026 trở đi.
--        (2) Chỉ chạy trên CSDL VỪA DỰNG (trước khi chạy kịch bản e2e có giao dịch): các kiểm tra "tồn đầu kỳ" và "giá khởi tạo"
--            sẽ sai sau khi e2e bán thuốc / đổi giá. Riêng kiểm tra BẤT BIẾN KHO luôn đúng ở mọi thời điểm.

SET NAMES utf8mb4;

-- ===== auth =====
SELECT '6 vai trò hệ thống' AS check_name,
       (SELECT COUNT(*) = 6 AND SUM(is_system) = 6 FROM pet_clinic_auth_db.roles) AS ok
UNION ALL SELECT 'đủ mã vai trò',
       (SELECT GROUP_CONCAT(code ORDER BY id) = 'ADMIN,VETERINARIAN,RECEPTIONIST,LAB_TECHNICIAN,IMAGING_TECHNICIAN,PET_OWNER'
          FROM pet_clinic_auth_db.roles)
UNION ALL SELECT 'admin: UUID cố định, ACTIVE, vai trò ADMIN',
       (SELECT COUNT(*) = 1 FROM pet_clinic_auth_db.users u
          JOIN pet_clinic_auth_db.user_roles ur ON ur.user_id = u.id
          JOIN pet_clinic_auth_db.roles r ON r.id = ur.role_id
         WHERE u.username = 'admin' AND u.status = 'ACTIVE' AND r.code = 'ADMIN'
           AND BIN_TO_UUID(u.id) = '019a9442-d800-7729-87cc-fbb1ceda8817')
UNION ALL SELECT 'admin: hash BCrypt $2a$10$ dài 60',
       (SELECT password_hash REGEXP '^\\$2a\\$10\\$.{53}$' FROM pet_clinic_auth_db.users WHERE username = 'admin')
UNION ALL SELECT 'admin: có user_profiles và staff_profiles',
       (SELECT COUNT(*) = 1 FROM pet_clinic_auth_db.user_profiles p
          JOIN pet_clinic_auth_db.staff_profiles s ON s.user_id = p.user_id
         WHERE p.user_id = UUID_TO_BIN('019a9442-d800-7729-87cc-fbb1ceda8817'))

-- ===== clinical: loài, nhóm dịch vụ =====
UNION ALL SELECT '2 loài DOG, CAT',
       (SELECT GROUP_CONCAT(code ORDER BY id) = 'DOG,CAT' FROM pet_clinic_clinical_db.species)
UNION ALL SELECT '9 nhóm dịch vụ',
       (SELECT COUNT(*) = 9 FROM pet_clinic_clinical_db.service_categories)
UNION ALL SELECT 'nhóm thu trước + hàng đợi (EXAMINATION/LABORATORY/IMAGING) đúng, 6 nhóm còn lại làm tại phòng',
       (SELECT SUM(requires_prepayment) = 3
           AND SUM(code = 'EXAMINATION' AND queue_type = 'DOCTOR'     AND requires_prepayment) = 1
           AND SUM(code = 'LABORATORY'  AND queue_type = 'LABORATORY' AND requires_prepayment) = 1
           AND SUM(code = 'IMAGING'     AND queue_type = 'IMAGING'    AND requires_prepayment) = 1
           AND SUM(queue_type IS NULL AND NOT requires_prepayment) = 6
          FROM pet_clinic_clinical_db.service_categories)

-- ===== clinical: dịch vụ + giá (Task 1.2.2: 7 dịch vụ, 7 dòng giá) =====
UNION ALL SELECT '7 dịch vụ, 7 dòng giá, 7 dòng giá hiện hành',
       (SELECT (SELECT COUNT(*) FROM pet_clinic_clinical_db.services) = 7
           AND (SELECT COUNT(*) FROM pet_clinic_clinical_db.service_prices) = 7
           AND (SELECT COUNT(*) FROM pet_clinic_clinical_db.v_current_service_prices) = 7)
UNION ALL SELECT 'giá docs nêu: EXAM_GEN 100000, LAB_CBC 250000, IMG_XRAY 180000, DEWORM 50000, IMG_US 200000, VAT 0',
       (SELECT SUM(code = 'EXAM_GEN' AND price = 100000 AND vat_rate = 0) = 1
           AND SUM(code = 'LAB_CBC'  AND price = 250000 AND vat_rate = 0) = 1
           AND SUM(code = 'IMG_XRAY' AND price = 180000 AND vat_rate = 0) = 1
           AND SUM(code = 'DEWORM'   AND price = 50000  AND vat_rate = 0) = 1
           AND SUM(code = 'IMG_US'   AND price = 200000 AND vat_rate = 0) = 1
          FROM pet_clinic_clinical_db.v_current_service_prices)
UNION ALL SELECT 'UUID dịch vụ cố định (EXAM_GEN = …0001, LAB_CBC = …0005, IMG_XRAY = …0007)',
       (SELECT SUM(code = 'EXAM_GEN' AND BIN_TO_UUID(id) = '019a9442-d830-7000-8000-000000000001') = 1
           AND SUM(code = 'LAB_CBC'  AND BIN_TO_UUID(id) = '019a9442-d830-7000-8000-000000000005') = 1
           AND SUM(code = 'IMG_XRAY' AND BIN_TO_UUID(id) = '019a9442-d830-7000-8000-000000000007') = 1
          FROM pet_clinic_clinical_db.services)
UNION ALL SELECT 'dịch vụ đúng nhóm (EXAM_GEN→EXAMINATION, LAB_CBC→LABORATORY, IMG_*→IMAGING, DEWORM→DEWORMING)',
       (SELECT SUM(s.code = 'EXAM_GEN' AND c.code = 'EXAMINATION') = 1
           AND SUM(s.code = 'LAB_CBC' AND c.code = 'LABORATORY') = 1
           AND SUM(s.code IN ('IMG_US', 'IMG_XRAY') AND c.code = 'IMAGING') = 2
           AND SUM(s.code = 'DEWORM' AND c.code = 'DEWORMING') = 1
          FROM pet_clinic_clinical_db.services s JOIN pet_clinic_clinical_db.service_categories c ON c.id = s.category_id)

-- ===== clinical: chỉ số xét nghiệm, khoảng tham chiếu, gói CBC =====
UNION ALL SELECT '4 chỉ số, id WBC=1 RBC=2 HGB=3 PLT=4 (Task 3.5 dùng id này)',
       (SELECT GROUP_CONCAT(CONCAT(id, ':', code) ORDER BY id) = '1:WBC,2:RBC,3:HGB,4:PLT' FROM pet_clinic_clinical_db.lab_test_items)
UNION ALL SELECT '8 khoảng tham chiếu (4 chỉ số x 2 loài)',
       (SELECT COUNT(*) = 8 FROM pet_clinic_clinical_db.lab_test_reference_ranges)
UNION ALL SELECT 'RBC Chó 5.50-8.50, Mèo 5.00-10.00 (10^12/L)',
       (SELECT SUM(sp.code = 'DOG' AND r.min_value = 5.50 AND r.max_value = 8.50) = 1
           AND SUM(sp.code = 'CAT' AND r.min_value = 5.00 AND r.max_value = 10.00) = 1
           AND MAX(i.unit) = '10^12/L'
          FROM pet_clinic_clinical_db.lab_test_reference_ranges r
          JOIN pet_clinic_clinical_db.lab_test_items i ON i.id = r.lab_test_item_id AND i.code = 'RBC'
          JOIN pet_clinic_clinical_db.species sp ON sp.id = r.species_id)
UNION ALL SELECT 'WBC Chó 6.00-17.00; PLT Chó 200-500 / Mèo 300-700 (Nghiệp vụ mục 22)',
       (SELECT SUM(i.code = 'WBC' AND sp.code = 'DOG' AND r.min_value = 6.00   AND r.max_value = 17.00) = 1
           AND SUM(i.code = 'PLT' AND sp.code = 'DOG' AND r.min_value = 200.00 AND r.max_value = 500.00) = 1
           AND SUM(i.code = 'PLT' AND sp.code = 'CAT' AND r.min_value = 300.00 AND r.max_value = 700.00) = 1
          FROM pet_clinic_clinical_db.lab_test_reference_ranges r
          JOIN pet_clinic_clinical_db.lab_test_items i ON i.id = r.lab_test_item_id
          JOIN pet_clinic_clinical_db.species sp ON sp.id = r.species_id)
UNION ALL SELECT 'min <= max ở mọi khoảng',
       (SELECT SUM(min_value > max_value) = 0 FROM pet_clinic_clinical_db.lab_test_reference_ranges)
UNION ALL SELECT 'gói LAB_CBC gồm đúng WBC, RBC, HGB, PLT',
       (SELECT GROUP_CONCAT(i.code ORDER BY i.id) = 'WBC,RBC,HGB,PLT'
          FROM pet_clinic_clinical_db.service_lab_test_items sl
          JOIN pet_clinic_clinical_db.lab_test_items i ON i.id = sl.lab_test_item_id
         WHERE sl.service_id = UUID_TO_BIN('019a9442-d830-7000-8000-000000000005'))

-- ===== billing-pharmacy =====
UNION ALL SELECT '4 nhóm thuốc',
       (SELECT GROUP_CONCAT(code ORDER BY id) = 'ANTIBIOTIC,VACCINE,ANTIPARASITIC,SUPPLEMENT' FROM pet_clinic_billing_pharmacy_db.medicine_categories)
UNION ALL SELECT '4 thuốc, 4 dòng giá hiện hành, 4 dòng tồn kho',
       (SELECT (SELECT COUNT(*) FROM pet_clinic_billing_pharmacy_db.medicines) = 4
           AND (SELECT COUNT(*) FROM pet_clinic_billing_pharmacy_db.v_current_medicine_prices) = 4
           AND (SELECT COUNT(*) FROM pet_clinic_billing_pharmacy_db.medicine_stocks) = 4)
UNION ALL SELECT 'Clavamox 250mg: quy cách, đơn vị, giá 15000, VAT 0.05, tồn 200, UUID …0001',
       (SELECT COUNT(*) = 1
          FROM pet_clinic_billing_pharmacy_db.medicines m
          JOIN pet_clinic_billing_pharmacy_db.v_current_medicine_prices p ON p.medicine_id = m.id
          JOIN pet_clinic_billing_pharmacy_db.medicine_stocks s ON s.medicine_id = m.id
         WHERE m.name = 'Clavamox 250mg' AND m.packaging_spec = 'Hộp 10 vỉ x 10 viên' AND m.base_unit = 'Viên'
           AND p.sale_price = 15000 AND p.vat_rate = 0.05 AND s.quantity_on_hand = 200
           AND BIN_TO_UUID(m.id) = '019a9442-d870-7000-8000-000000000001')
UNION ALL SELECT 'Clavamox: Amoxicillin 200 mg + Clavulanic acid 50 mg',
       (SELECT SUM(ingredient_name = 'Amoxicillin' AND strength_value = 200 AND strength_unit = 'mg') = 1
           AND SUM(ingredient_name = 'Clavulanic acid' AND strength_value = 50 AND strength_unit = 'mg') = 1
           AND COUNT(*) = 2
          FROM pet_clinic_billing_pharmacy_db.medicine_ingredients
         WHERE medicine_id = UUID_TO_BIN('019a9442-d870-7000-8000-000000000001'))
UNION ALL SELECT 'tồn đầu kỳ: AMOX_CLAV_250 = 200, DRONTAL_PLUS = 50, NOBIVAC_DHPPI = 40, NUTRI_PLUS_GEL = 100',
       (SELECT SUM(m.code = 'AMOX_CLAV_250'  AND s.quantity_on_hand = 200) = 1
           AND SUM(m.code = 'DRONTAL_PLUS'   AND s.quantity_on_hand = 50)  = 1
           AND SUM(m.code = 'NOBIVAC_DHPPI'  AND s.quantity_on_hand = 40)  = 1
           AND SUM(m.code = 'NUTRI_PLUS_GEL' AND s.quantity_on_hand = 100) = 1
          FROM pet_clinic_billing_pharmacy_db.medicine_stocks s
          JOIN pet_clinic_billing_pharmacy_db.medicines m ON m.id = s.medicine_id)
UNION ALL SELECT 'BẤT BIẾN KHO: quantity_on_hand = SUM(inventory_transactions.quantity) ở cả 4 thuốc',
       (SELECT COUNT(*) = 4 AND SUM(s.quantity_on_hand = t.total) = 4
          FROM pet_clinic_billing_pharmacy_db.medicine_stocks s
          JOIN (SELECT medicine_id, SUM(quantity) AS total
                  FROM pet_clinic_billing_pharmacy_db.inventory_transactions GROUP BY medicine_id) t ON t.medicine_id = s.medicine_id)
UNION ALL SELECT 'nhật ký đầu kỳ: 4 dòng IMPORT, có giá nhập, không gắn hóa đơn',
       (SELECT COUNT(*) = 4 AND SUM(transaction_type = 'IMPORT' AND quantity > 0 AND unit_cost IS NOT NULL AND medicine_invoice_id IS NULL) = 4
          FROM pet_clinic_billing_pharmacy_db.inventory_transactions);
