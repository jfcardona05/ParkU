package com.parku;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.*;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.*;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = "parku.demo.enabled=false")
class DailyWalletApiTest {
  @Autowired TestRestTemplate http;
  @Autowired JdbcTemplate db;
  @Autowired MutableClock clock;

  static class MutableClock extends Clock {
    final AtomicReference<Instant> time = new AtomicReference<>();

    void set(String value) {
      time.set(Instant.parse(value));
    }

    @Override
    public ZoneId getZone() {
      return ZoneOffset.UTC;
    }

    @Override
    public Clock withZone(ZoneId zone) {
      return Clock.fixed(instant(), zone);
    }

    @Override
    public Instant instant() {
      return time.get();
    }
  }

  @TestConfiguration
  static class TimeConfig {
    @Bean
    @Primary
    MutableClock testClock() {
      return new MutableClock();
    }
  }

  @BeforeEach
  void reset() {
    assertThat(db.queryForObject("SELECT current_database()", String.class)).endsWith("_test");
    db.execute("TRUNCATE transactions,vehicles,sessions,users RESTART IDENTITY CASCADE");
    clock.set("2030-01-01T04:30:00Z"); // 23:30 on December 31 in Colombia.
    for (int i = 1; i <= 5; i++) {
      String role = i == 3 ? "guard" : i == 4 ? "operador" : "estudiante";
      db.update(
          "INSERT INTO users(name,email,password_hash,role,balance) VALUES(?,?,?, ?,10000)",
          "Usuario " + i,
          "user" + i + "@test.co",
          "unused",
          role);
      db.update(
          "INSERT INTO sessions(token_hash,user_id,expires_at) VALUES(?,?,CURRENT_TIMESTAMP+INTERVAL '1 hour')",
          VehicleQrService.digest("s" + i),
          i);
    }
    db.update(
        "INSERT INTO vehicles(user_id,plate,type) VALUES(1,'CAR123','automovil'),(2,'MOT123','moto'),(1,'ALT123','moto')");
    db.update(
        "INSERT INTO parking_rates(vehicle_type,amount,block_seconds,minimum_blocks) VALUES('moto',4000,3600,1),('automovil',5000,3600,1)");
    db.update("UPDATE parking_settings SET capacity=NULL WHERE id=1");
  }

  ResponseEntity<Map> call(HttpMethod method, String path, Object body, String session) {
    var headers = new HttpHeaders();
    headers.setContentType(MediaType.APPLICATION_JSON);
    if (session != null) headers.setBearerAuth(session);
    return http.exchange(path, method, new HttpEntity<>(body, headers), Map.class);
  }

  ResponseEntity<Map> issue(int vehicle, String user) {
    return call(HttpMethod.POST, "/api/vehicles/" + vehicle + "/qr", null, user);
  }

  ResponseEntity<Map> transfer(String from, String to, long amount, String key) {
    return call(
        HttpMethod.POST,
        "/api/wallet/transfers",
        Map.of("recipient_email", to, "amount", amount, "request_id", key),
        from);
  }

  void error(ResponseEntity<Map> result, int status, String code) {
    assertThat(result.getStatusCode().value()).isEqualTo(status);
    assertThat(result.getBody()).containsEntry("code", code);
  }

  long balance(int id) {
    return db.queryForObject("SELECT balance FROM users WHERE id=?", Long.class, id);
  }

  int count(String table) {
    return db.queryForObject("SELECT count(*) FROM " + table, Integer.class);
  }

  @Test
  void quoteIsFreeAndUsesColombianMidnight() {
    var quote = call(HttpMethod.GET, "/api/vehicles/1/qr", null, "s1");
    assertThat(quote.getStatusCode().value()).isEqualTo(200);
    assertThat(quote.getBody())
        .containsEntry("issued", false)
        .containsEntry("amount", 5000)
        .containsEntry("service_date", "2029-12-31")
        .containsEntry("expires_at", "2030-01-01T05:00:00Z");
    assertThat(balance(1)).isEqualTo(10000);
    assertThat(count("transactions")).isZero();
    assertThat(count("vehicle_qr")).isZero();
  }

  @Test
  void oneDailyCodePerUserAndDifferentPrices() {
    var car = issue(1, "s1").getBody();
    var moto = issue(2, "s2").getBody();
    assertThat(car).containsEntry("amount", 5000).containsEntry("charged", true);
    assertThat(moto).containsEntry("amount", 4000).containsEntry("charged", true);
    assertThat(car.get("token")).isNotEqualTo(moto.get("token"));
    assertThat(balance(1)).isEqualTo(5000);
    assertThat(balance(2)).isEqualTo(6000);
    assertThat(issue(1, "s1").getBody())
        .containsEntry("token", car.get("token"))
        .containsEntry("charged", false)
        .containsEntry("charge_amount", 0);
    assertThat(call(HttpMethod.GET, "/api/vehicles/1/qr", null, "s1").getBody())
        .containsEntry("token", car.get("token"));
    assertThat(count("transactions")).isEqualTo(2);
    assertThat(count("parking_day_passes")).isEqualTo(2);
  }

  @Test
  void cannotSwitchVehiclesOrAccessAnotherUsersCode() {
    error(issue(1, "s2"), 404, "VEHICLE_NOT_FOUND");
    assertThat(issue(1, null).getStatusCode().value()).isEqualTo(401);
    issue(1, "s1");
    error(issue(3, "s1"), 409, "DAILY_VEHICLE_LOCKED");
    error(call(HttpMethod.GET, "/api/vehicles/1/qr", null, "s2"), 404, "VEHICLE_NOT_FOUND");
    assertThat(balance(1)).isEqualTo(5000);
    assertThat(count("transactions")).isEqualTo(1);
  }

  @Test
  void buyingDailyPassRevokesAnyUnusedLegacyCode() {
    String legacy = "legacy-unused-code";
    db.update(
        "INSERT INTO vehicle_qr(token_hash,vehicle_id,user_id,expires_at) VALUES(?,1,1,?)",
        VehicleQrService.digest(legacy),
        java.sql.Timestamp.from(clock.instant().plusSeconds(120)));
    issue(1, "s1");
    error(
        call(HttpMethod.POST, "/api/gate/inspect", Map.of("token", legacy), "s3"),
        409,
        "QR_REVOKED");
    assertThat(balance(1)).isEqualTo(5000);
  }

  @Test
  void cannotDeleteVehicleWhileItsDailyPassIsValid() {
    issue(1, "s1");
    error(call(HttpMethod.DELETE, "/api/vehicles/1", null, "s1"), 409, "DAILY_PASS_ACTIVE");
    clock.set("2030-01-01T05:00:00Z");
    assertThat(call(HttpMethod.DELETE, "/api/vehicles/1", null, "s1").getStatusCode().value())
        .isEqualTo(200);
  }

  @Test
  void insufficientBalanceDoesNotCreateCodeAndRechargeAllowsOneCharge() {
    db.update("UPDATE users SET balance=4999 WHERE id=1");
    error(issue(1, "s1"), 409, "INSUFFICIENT_BALANCE");
    assertThat(count("vehicle_qr")).isZero();
    assertThat(count("parking_day_passes")).isZero();
    assertThat(count("transactions")).isZero();
    call(
        HttpMethod.POST,
        "/api/wallet/recharge",
        Map.of("amount", 5001, "point_name", "Punto 1 - Portería Principal USTA", "user_id", 1),
        "s4");
    issue(1, "s1");
    assertThat(balance(1)).isEqualTo(5000);
    db.update("UPDATE users SET balance=0 WHERE id=1");
    assertThat(issue(1, "s1").getBody()).containsEntry("charged", false);
    assertThat(balance(1)).isZero();
    assertThat(count("parking_day_passes")).isEqualTo(1);
  }

  @Test
  void concurrentGenerationDebitsExactlyOnce() {
    var requests = new ArrayList<CompletableFuture<ResponseEntity<Map>>>();
    for (int i = 0; i < 8; i++) requests.add(CompletableFuture.supplyAsync(() -> issue(1, "s1")));
    var results = requests.stream().map(CompletableFuture::join).toList();
    assertThat(results).allSatisfy(r -> assertThat(r.getStatusCode().value()).isEqualTo(201));
    assertThat(results.stream().map(r -> r.getBody().get("token")).distinct().count()).isEqualTo(1);
    assertThat(
            results.stream().filter(r -> Boolean.TRUE.equals(r.getBody().get("charged"))).count())
        .isEqualTo(1);
    assertThat(balance(1)).isEqualTo(5000);
    assertThat(count("transactions")).isEqualTo(1);
  }

  @Test
  void concurrentDifferentVehiclesStillProduceOnePass() {
    var a = CompletableFuture.supplyAsync(() -> issue(1, "s1"));
    var b = CompletableFuture.supplyAsync(() -> issue(3, "s1"));
    assertThat(List.of(a.join().getStatusCode().value(), b.join().getStatusCode().value()))
        .containsExactlyInAnyOrder(201, 409);
    assertThat(count("parking_day_passes")).isEqualTo(1);
    assertThat(count("transactions")).isEqualTo(1);
    assertThat(balance(1)).isIn(5000L, 6000L);
  }

  @Test
  void changedPriceOrDateRequiresNewConfirmation() {
    error(
        call(
            HttpMethod.POST,
            "/api/vehicles/1/qr",
            Map.of("expected_amount", 4000, "service_date", "2029-12-31"),
            "s1"),
        409,
        "PRICE_CHANGED");
    error(
        call(
            HttpMethod.POST,
            "/api/vehicles/1/qr",
            Map.of("expected_amount", 5000, "service_date", "2029-12-30"),
            "s1"),
        409,
        "DAY_CHANGED");
    assertThat(balance(1)).isEqualTo(10000);
    assertThat(count("transactions")).isZero();
  }

  @Test
  void nextDayGetsDifferentCodeAndOldCodeExpires() {
    String old = (String) issue(1, "s1").getBody().get("token");
    clock.set("2030-01-01T05:00:00Z");
    error(
        call(HttpMethod.POST, "/api/gate/inspect", Map.of("token", old), "s3"), 410, "QR_EXPIRED");
    var next = issue(1, "s1").getBody();
    assertThat(next).containsEntry("service_date", "2030-01-01");
    assertThat(next.get("token")).isNotEqualTo(old);
    assertThat(balance(1)).isZero();
    assertThat(count("transactions")).isEqualTo(2);
  }

  @Test
  void paidCodeSupportsEntryExitAndScannedUrlWithoutAnotherCharge() {
    String token = (String) issue(1, "s1").getBody().get("token");
    String url = "https://parku.example/p/" + token;
    var entry = Map.of("token", url, "action", "entry", "request_id", "entry-1");
    assertThat(call(HttpMethod.POST, "/api/gate/operations", entry, "s3").getBody())
        .containsEntry("prepaid", true);
    assertThat(call(HttpMethod.POST, "/api/gate/operations", entry, "s3").getStatusCode().value())
        .isEqualTo(200);
    var exit =
        call(
            HttpMethod.POST,
            "/api/gate/operations",
            Map.of("token", url, "action", "exit", "request_id", "exit-1"),
            "s3");
    assertThat(exit.getStatusCode().value()).isEqualTo(201);
    assertThat(exit.getBody()).doesNotContainKey("charge");
    assertThat(balance(1)).isEqualTo(5000);
    assertThat(count("transactions")).isEqualTo(1);
    assertThat(
            call(HttpMethod.POST, "/api/gate/inspect", Map.of("token", token), "s3")
                .getStatusCode()
                .value())
        .isEqualTo(200);
  }

  @Test
  void publicPhoneCardOnlyShowsBasicDetailsAndEscapesNames() {
    db.update("UPDATE users SET name='<script>alert(1)</script>' WHERE id=1");
    String token = (String) issue(1, "s1").getBody().get("token");
    var page = http.getForEntity("/p/" + token, String.class);
    assertThat(page.getStatusCode().value()).isEqualTo(200);
    assertThat(page.getBody())
        .contains("CAR123", "Automóvil", "&lt;script&gt;")
        .doesNotContain("<script>", "user1@test.co", "5000", token);
    assertThat(page.getHeaders().getFirst("Cache-Control")).isEqualTo("no-store");
    assertThat(page.getHeaders().getContentType().getCharset())
        .isEqualTo(java.nio.charset.StandardCharsets.UTF_8);
    assertThat(count("parking_operations")).isZero();
    clock.set("2030-01-01T05:00:00Z");
    var expired = http.getForEntity("/p/" + token, String.class);
    assertThat(expired.getStatusCode().value()).isEqualTo(410);
    assertThat(expired.getBody()).doesNotContain("CAR123", "&lt;script&gt;");
  }

  @Test
  void transferIsAtomicNormalizedAndRecordedForBothUsers() {
    var sent = transfer("s1", " USER2@TEST.CO ", 3000, "send-1");
    assertThat(sent.getStatusCode().value()).isEqualTo(200);
    assertThat(sent.getBody())
        .containsEntry("recipient_email", "user2@test.co")
        .containsEntry("balance_after", 7000)
        .doesNotContainKeys("recipient_balance", "password_hash");
    assertThat(balance(1)).isEqualTo(7000);
    assertThat(balance(2)).isEqualTo(13000);
    var outgoing =
        (List<Map>)
            call(HttpMethod.GET, "/api/wallet/history", null, "s1").getBody().get("transactions");
    var incoming =
        (List<Map>)
            call(HttpMethod.GET, "/api/wallet/history", null, "s2").getBody().get("transactions");
    assertThat(outgoing.getFirst())
        .containsEntry("type", "TRANSFERENCIA_ENVIADA")
        .containsEntry("counterpart_email", "user2@test.co");
    assertThat(incoming.getFirst())
        .containsEntry("type", "TRANSFERENCIA_RECIBIDA")
        .containsEntry("counterpart_email", "user1@test.co");
    assertThat(count("transactions")).isEqualTo(2);
  }

  @Test
  void invalidTransfersNeverMoveMoney() {
    assertThat(transfer(null, "user2@test.co", 100, "unauth").getStatusCode().value())
        .isEqualTo(401);
    error(transfer("s1", "user1@test.co", 100, "self"), 400, "SELF_TRANSFER");
    error(transfer("s1", "absent@test.co", 100, "missing"), 404, "RECIPIENT_NOT_FOUND");
    error(transfer("s1", "user2@test.co", 10001, "poor"), 409, "INSUFFICIENT_BALANCE");
    for (long value : List.of(0L, -1L, 1000000001L))
      assertThat(transfer("s1", "user2@test.co", value, "invalid" + value).getStatusCode().value())
          .isEqualTo(400);
    assertThat(transfer("s1", "not-an-email", 1, "email").getStatusCode().value()).isEqualTo(400);
    assertThat(balance(1)).isEqualTo(10000);
    assertThat(balance(2)).isEqualTo(10000);
    assertThat(count("transactions")).isZero();
  }

  @Test
  void fractionalOrStringMoneyIsRejectedWithoutRounding() {
    for (Object amount : List.of(1.9, "1000", 1000.0)) {
      var response =
          call(
              HttpMethod.POST,
              "/api/wallet/transfers",
              Map.of(
                  "recipient_email",
                  "user2@test.co",
                  "amount",
                  amount,
                  "request_id",
                  "invalid-number"),
              "s1");
      error(response, 400, "INVALID_REQUEST");
    }
    assertThat(balance(1)).isEqualTo(10000);
    assertThat(balance(2)).isEqualTo(10000);
    assertThat(count("transactions")).isZero();
  }

  @Test
  void retriesReuseTransferAndConflictingDataAreRejected() {
    var first = transfer("s1", "user2@test.co", 3000, "same");
    var retry = transfer("s1", "USER2@test.co", 3000, "same");
    assertThat(retry.getBody())
        .containsEntry("transfer_id", first.getBody().get("transfer_id"))
        .containsEntry("replayed", true);
    error(transfer("s1", "user2@test.co", 3001, "same"), 409, "IDEMPOTENCY_CONFLICT");
    error(transfer("s1", "missing@test.co", 3000, "same"), 409, "IDEMPOTENCY_CONFLICT");
    assertThat(balance(1)).isEqualTo(7000);
    assertThat(count("wallet_transfers")).isEqualTo(1);
    assertThat(count("transactions")).isEqualTo(2);
  }

  @Test
  void concurrentSameTransferOnlyMovesMoneyOnce() {
    var requests = new ArrayList<CompletableFuture<ResponseEntity<Map>>>();
    for (int i = 0; i < 8; i++)
      requests.add(
          CompletableFuture.supplyAsync(() -> transfer("s1", "user2@test.co", 3000, "same")));
    var results = requests.stream().map(CompletableFuture::join).toList();
    assertThat(results).allSatisfy(r -> assertThat(r.getStatusCode().value()).isEqualTo(200));
    assertThat(results.stream().map(r -> r.getBody().get("transfer_id")).distinct().count())
        .isEqualTo(1);
    assertThat(balance(1)).isEqualTo(7000);
    assertThat(balance(2)).isEqualTo(13000);
    assertThat(count("transactions")).isEqualTo(2);
  }

  @Test
  void simultaneousSpendsCannotOverdrawAndOppositeTransfersDoNotDeadlock() {
    var a = CompletableFuture.supplyAsync(() -> transfer("s1", "user2@test.co", 7000, "a"));
    var b = CompletableFuture.supplyAsync(() -> transfer("s1", "user5@test.co", 7000, "b"));
    assertThat(List.of(a.join().getStatusCode().value(), b.join().getStatusCode().value()))
        .containsExactlyInAnyOrder(200, 409);
    assertThat(balance(1)).isEqualTo(3000);
    db.update("UPDATE users SET balance=10000 WHERE id IN (1,2)");
    var c = CompletableFuture.supplyAsync(() -> transfer("s1", "user2@test.co", 3000, "c"));
    var d = CompletableFuture.supplyAsync(() -> transfer("s2", "user1@test.co", 4000, "d"));
    assertThat(c.join().getStatusCode().value()).isEqualTo(200);
    assertThat(d.join().getStatusCode().value()).isEqualTo(200);
    assertThat(balance(1)).isEqualTo(11000);
    assertThat(balance(2)).isEqualTo(9000);
  }

  @Test
  void qrAndTransferShareTheSameWalletLock() {
    var a = CompletableFuture.supplyAsync(() -> issue(1, "s1"));
    var b = CompletableFuture.supplyAsync(() -> transfer("s1", "user2@test.co", 7000, "race"));
    assertThat(List.of(a.join().getStatusCode().value(), b.join().getStatusCode().value()))
        .containsAnyOf(409);
    assertThat(balance(1)).isIn(3000L, 5000L);
  }

  @Test
  void recipientOverflowIsRejectedBeforeEitherBalanceChanges() {
    db.update("UPDATE users SET balance=? WHERE id=2", Long.MAX_VALUE);
    error(transfer("s1", "user2@test.co", 1, "overflow"), 400, "BALANCE_LIMIT");
    assertThat(balance(1)).isEqualTo(10000);
    assertThat(balance(2)).isEqualTo(Long.MAX_VALUE);
    assertThat(count("transactions")).isZero();
  }

  @Test
  void failuresAfterDebitsRollbackEveryChange() {
    db.execute(
        "CREATE FUNCTION test_reject_daily() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'test rollback'; END $$");
    db.execute(
        "CREATE TRIGGER reject_daily BEFORE INSERT ON parking_day_passes FOR EACH ROW EXECUTE FUNCTION test_reject_daily()");
    try {
      assertThat(issue(1, "s1").getStatusCode().value()).isEqualTo(500);
    } finally {
      db.execute("DROP TRIGGER reject_daily ON parking_day_passes");
      db.execute("DROP FUNCTION test_reject_daily()");
    }
    assertThat(balance(1)).isEqualTo(10000);
    assertThat(count("vehicle_qr")).isZero();
    assertThat(count("transactions")).isZero();
    db.execute(
        "CREATE FUNCTION test_reject_transfer() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'test rollback'; END $$");
    db.execute(
        "CREATE TRIGGER reject_transfer BEFORE INSERT ON wallet_transfers FOR EACH ROW EXECUTE FUNCTION test_reject_transfer()");
    try {
      assertThat(transfer("s1", "user2@test.co", 3000, "rollback").getStatusCode().value())
          .isEqualTo(500);
    } finally {
      db.execute("DROP TRIGGER reject_transfer ON wallet_transfers");
      db.execute("DROP FUNCTION test_reject_transfer()");
    }
    assertThat(balance(1)).isEqualTo(10000);
    assertThat(balance(2)).isEqualTo(10000);
    assertThat(count("transactions")).isZero();
  }
}
