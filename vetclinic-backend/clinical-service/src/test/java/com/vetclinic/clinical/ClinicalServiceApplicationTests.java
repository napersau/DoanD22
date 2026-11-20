package com.vetclinic.clinical;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(properties = "eureka.client.enabled=false")
class ClinicalServiceApplicationTests {

    @Test
    void contextLoads() {
    }
}
