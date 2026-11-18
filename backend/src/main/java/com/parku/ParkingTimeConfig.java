package com.parku;

import java.time.Clock;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ParkingTimeConfig {
  @Bean
  public Clock parkingClock() {
    return Clock.systemUTC();
  }
}
