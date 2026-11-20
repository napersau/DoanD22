/**
 * Thư viện dùng chung của VetClinic (Quy chuẩn 2.2).
 * <ul>
 *   <li>{@code dto}, {@code exception}, {@code event}, {@code util}, {@code constant}: lớp thuần, không {@code @Component}, mọi module dùng được.</li>
 *   <li>{@code web}: cấu hình servlet, nạp bằng {@code CommonWebAutoConfiguration} (chỉ khi ứng dụng là SERVLET).</li>
 *   <li>{@code outbox}: Transactional Outbox + consumer idempotent, nạp có điều kiện khi service có JPA và RabbitMQ.</li>
 * </ul>
 */
package com.vetclinic.common;
