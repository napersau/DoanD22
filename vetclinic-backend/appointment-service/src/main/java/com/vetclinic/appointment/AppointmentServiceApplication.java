package com.vetclinic.appointment;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** Đặt lịch hẹn, sức chứa khung giờ, NO_SHOW (cổng 8082). Chỉ quét package com.vetclinic.appointment (Quy chuẩn 2.2). */
@SpringBootApplication
public class AppointmentServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(AppointmentServiceApplication.class, args);
    }
}
