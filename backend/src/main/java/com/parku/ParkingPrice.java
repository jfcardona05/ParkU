package com.parku;

import java.time.Duration;
import java.time.Instant;

final class ParkingPrice {
  private ParkingPrice() {}

  static Quote quote(
      Instant entered, Instant exited, long blockSeconds, long minimumBlocks, long rate) {
    var duration = Duration.between(entered, exited);
    if (duration.isNegative())
      throw new ApiProblem(409, "INVALID_PARKING_TIME", "Fecha de ingreso posterior a la salida");
    try {
      long nanos = duration.toNanos();
      long blockNanos = Math.multiplyExact(blockSeconds, 1000000000L);
      long blocks =
          Math.max(
              minimumBlocks, Math.addExact(nanos / blockNanos, nanos % blockNanos == 0 ? 0 : 1));
      return new Quote(blocks, Math.multiplyExact(blocks, rate));
    } catch (ArithmeticException e) {
      throw new ApiProblem(409, "CHARGE_OVERFLOW", "Duración o importe fuera del límite permitido");
    }
  }

  record Quote(long blocks, long amount) {}
}
