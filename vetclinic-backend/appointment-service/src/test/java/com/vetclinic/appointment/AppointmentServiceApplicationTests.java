package com.vetclinic.appointment;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(properties = "eureka.client.enabled=false")
class AppointmentServiceApplicationTests {

    @Test
    void contextLoads() {
    }
}
