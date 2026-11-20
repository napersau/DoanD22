package com.vetclinic.auth;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** Tài khoản, vai trò, token, hồ sơ người dùng (cổng 8081). Chỉ quét package com.vetclinic.auth (Quy chuẩn 2.2). */
@SpringBootApplication
public class AuthServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(AuthServiceApplication.class, args);
    }
}
