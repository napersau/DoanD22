package com.vetclinic.billing;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** Danh mục thuốc, giá, tồn kho, hóa đơn thuốc (cổng 8084). Chỉ quét package com.vetclinic.billing (Quy chuẩn 2.2). */
@SpringBootApplication
public class BillingPharmacyServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(BillingPharmacyServiceApplication.class, args);
    }
}
