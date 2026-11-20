package com.vetclinic.gateway;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** Spring Cloud Gateway - cổng vào duy nhất (cổng 8080). Chỉ quét package com.vetclinic.gateway (Quy chuẩn 2.2). */
@SpringBootApplication
public class ApiGatewayApplication {

    public static void main(String[] args) {
        SpringApplication.run(ApiGatewayApplication.class, args);
    }
}
