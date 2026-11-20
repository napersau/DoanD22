package com.vetclinic.reporting;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** Mô hình đọc báo cáo (CQRS), chỉ ghi bằng sự kiện (cổng 8086). Chỉ quét package com.vetclinic.reporting (Quy chuẩn 2.2). */
@SpringBootApplication
public class ReportingServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(ReportingServiceApplication.class, args);
    }
}
