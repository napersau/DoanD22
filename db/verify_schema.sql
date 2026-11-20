-- Kiểm tra lược đồ v4.0 (Lịch trình Task 1.2, "Hướng dẫn kiểm thử" bước 2-3). Không nằm trong initdb; chạy tay hoặc bằng e2e/P0_infra.sh.
-- Kỳ vọng: auth 9 · appointment 4 · clinical 24 + 2 VIEW · billing 10 + 2 VIEW · reporting 5 => 52 bảng, 4 VIEW; 40 khóa ngoại; 0 cột ENUM.

SELECT table_schema AS db,
       SUM(table_type = 'BASE TABLE') AS tables_count,
       SUM(table_type = 'VIEW')       AS views_count
FROM information_schema.tables
WHERE table_schema LIKE 'pet_clinic_%'
GROUP BY table_schema
ORDER BY table_schema;

SELECT constraint_schema AS db, COUNT(*) AS fk_count
FROM information_schema.referential_constraints
WHERE constraint_schema LIKE 'pet_clinic_%'
GROUP BY constraint_schema
UNION ALL
SELECT 'TOTAL', COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema LIKE 'pet_clinic_%';

SELECT COUNT(*) AS enum_columns
FROM information_schema.columns
WHERE table_schema LIKE 'pet_clinic_%' AND data_type = 'enum';

SELECT SUM(table_type = 'BASE TABLE') AS total_tables, SUM(table_type = 'VIEW') AS total_views
FROM information_schema.tables
WHERE table_schema LIKE 'pet_clinic_%';
