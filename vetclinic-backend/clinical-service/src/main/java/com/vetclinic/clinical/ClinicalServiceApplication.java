package com.vetclinic.clinical;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** Thú cưng, khám 2 pha, cận lâm sàng, hóa đơn dịch vụ, đơn thuốc, hàng đợi Redis (cổng 8083). Chỉ quét package com.vetclinic.clinical (Quy chuẩn 2.2). */
@SpringBootApplication
public class ClinicalServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(ClinicalServiceApplication.class, args);
    }
}
