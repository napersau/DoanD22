package com.vetclinic.notification;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** WebSocket STOMP và Email theo sự kiện (cổng 8085). Chỉ quét package com.vetclinic.notification (Quy chuẩn 2.2). */
@SpringBootApplication
public class NotificationServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(NotificationServiceApplication.class, args);
    }
}
