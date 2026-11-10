package com.parku;

import static org.assertj.core.api.Assertions.*;

import java.time.Instant;
import org.junit.jupiter.api.Test;

class ParkingPriceTest {
  @Test
  void hourlyRoundingIncludesFractionalSecondsAndMinimum() {
    var start = Instant.parse("2026-11-10T00:00:00Z");
    assertThat(ParkingPrice.quote(start, start, 3600, 1, 4000).amount()).isEqualTo(4000);
    assertThat(ParkingPrice.quote(start, start.plusSeconds(3600), 3600, 1, 5000).amount())
        .isEqualTo(5000);
    assertThat(
            ParkingPrice.quote(start, start.plusSeconds(3600).plusNanos(1), 3600, 1, 5000).amount())
        .isEqualTo(10000);
    assertThat(ParkingPrice.quote(start, start.plusSeconds(1), 1800, 2, 4000).amount())
        .isEqualTo(8000);
  }

  @Test
  void impossibleTimesAndOverflowRejectInsteadOfWrappingMoney() {
    var start = Instant.parse("2026-11-10T00:00:00Z");
    assertThatThrownBy(() -> ParkingPrice.quote(start, start.minusSeconds(1), 3600, 1, 4000))
        .isInstanceOf(ApiProblem.class)
        .hasMessageContaining("posterior");
    assertThatThrownBy(() -> ParkingPrice.quote(start, start.plusSeconds(2), 1, 1, Long.MAX_VALUE))
        .isInstanceOf(ApiProblem.class)
        .hasMessageContaining("límite");
  }
}
