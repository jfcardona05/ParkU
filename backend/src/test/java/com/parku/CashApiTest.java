package com.parku;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.*;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.context.annotation.*;
import org.springframework.http.*;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = "parku.demo.enabled=false")
class CashApiTest {
  static final String POINT = CashService.POINTS.getFirst();
  @Autowired TestRestTemplate http;
  @Autowired JdbcTemplate db;
  @Autowired CashClock clock;

  static class CashClock extends Clock {
    final AtomicReference<Instant> now = new AtomicReference<>();

    void set(String value) {
      now.set(Instant.parse(value));
    }

    public ZoneId getZone() {
      return ZoneOffset.UTC;
    }

    public Clock withZone(ZoneId zone) {
      return Clock.fixed(instant(), zone);
    }

    public Instant instant() {
      return now.get();
    }
  }

  @TestConfiguration
  static class TimeConfig {
    @Bean
    @Primary
    CashClock cashClock() {
      return new CashClock();
    }
  }

  @BeforeEach
  void seed() {
    assertThat(db.queryForObject("SELECT current_database()", String.class)).endsWith("_test");
    db.execute("TRUNCATE transactions,vehicles,sessions,users RESTART IDENTITY CASCADE");
    clock.set("2030-01-01T15:00:00Z");
    for (int i = 1; i <= 4; i++) {
      db.update(
          "INSERT INTO users(name,email,password_hash,role,balance) VALUES(?,?,'unused',?,0)",
          "User " + i,
          "cash" + i + "@test.co",
          i == 1 ? "estudiante" : i == 4 ? "admin" : "operador");
      db.update(
          "INSERT INTO sessions(token_hash,user_id,expires_at) VALUES(?,?,CURRENT_TIMESTAMP+INTERVAL '1 hour')",
          VehicleQrService.digest("c" + i),
          i);
    }
  }

  ResponseEntity<Map> call(HttpMethod method, String path, Object body, String token) {
    var headers = new HttpHeaders();
    headers.setContentType(MediaType.APPLICATION_JSON);
    if (token != null) headers.setBearerAuth(token);
    return http.exchange(path, method, new HttpEntity<>(body, headers), Map.class);
  }

  ResponseEntity<Map> post(String path, Object body, String token) {
    return call(HttpMethod.POST, path, body, token);
  }

  ResponseEntity<Map> open(long base, String token) {
    return post("/api/cash/open", Map.of("point_name", POINT, "opening_amount", base), token);
  }

  ResponseEntity<Map> recharge(long amount) {
    return post(
        "/api/wallet/recharge", Map.of("user_id", 1, "point_name", POINT, "amount", amount), "c2");
  }

  ResponseEntity<Map> close(Object id, long counted, long retained, String reason) {
    return post(
        "/api/cash/" + id + "/close",
        Map.of("counted_cash", counted, "retained_cash", retained, "notes", reason),
        "c2");
  }

  Map session(ResponseEntity<Map> r) {
    assertThat(r.getStatusCode().value()).isEqualTo(200);
    return (Map) r.getBody().get("session");
  }

  @Test
  void dailyTotalsRetainedBaseCarryAndImmutableReplay() {
    var opened = session(open(10000, "c2"));
    var id = opened.get("id");
    assertThat(session(open(10000, "c2")).get("id")).isEqualTo(id);
    assertThat(recharge(20000).getStatusCode().value()).isEqualTo(200);
    var closed = session(close(id, 30000, 8000, ""));
    assertThat(closed)
        .containsEntry("opening_amount", 10000)
        .containsEntry("recharge_total", 20000)
        .containsEntry("expected_cash", 30000)
        .containsEntry("retained_cash", 8000)
        .containsEntry("remitted_cash", 22000)
        .containsEntry("difference", 0);
    assertThat(session(close(id, 30000, 8000, ""))).isEqualTo(closed);
    assertThat(close(id, 31000, 8000, "change").getStatusCode().value()).isEqualTo(409);
    assertThat(recharge(1000).getStatusCode().value()).isEqualTo(409);
    assertThat(open(8000, "c2").getStatusCode().value()).isEqualTo(409);
    clock.set("2030-01-02T15:00:00Z");
    assertThat(open(0, "c3").getStatusCode().value()).isEqualTo(409);
    assertThat(session(open(8000, "c3")))
        .containsEntry("opening_amount", 8000)
        .containsEntry("previous_session_id", id);
    var history = call(HttpMethod.GET, "/api/cash/history?date=2030-01-01", null, "c3").getBody();
    assertThat((List) history.get("sessions")).hasSize(1);
    assertThat(db.queryForObject("SELECT balance FROM users WHERE id=1", Long.class))
        .isEqualTo(20000);
  }

  @Test
  void permissionsAndMoneyValidationCannotChangeBalances() {
    for (String token : List.of("c1", "c4"))
      assertThat(open(0, token).getStatusCode().value()).isEqualTo(403);
    assertThat(open(0, null).getStatusCode().value()).isEqualTo(401);
    assertThat(recharge(5000).getStatusCode().value()).isEqualTo(409);
    assertThat(
            post("/api/cash/open", Map.of("point_name", POINT, "opening_amount", 0.5), "c2")
                .getStatusCode()
                .value())
        .isEqualTo(400);
    var id = session(open(10000, "c2")).get("id");
    assertThat(
            post(
                    "/api/cash/" + id + "/close",
                    Map.of("counted_cash", 10000, "retained_cash", 0),
                    "c3")
                .getStatusCode()
                .value())
        .isEqualTo(404);
    assertThat(close(id, 9000, 10000, "reason").getStatusCode().value()).isEqualTo(400);
    assertThat(close(id, 9000, 1000, "").getStatusCode().value()).isEqualTo(400);
    assertThat(session(close(id, 9000, 1000, "Faltante verificado")))
        .containsEntry("difference", -1000)
        .containsEntry("remitted_cash", 8000);
    assertThat(db.queryForObject("SELECT count(*) FROM transactions", Integer.class)).isZero();
  }

  @Test
  void midnightBlocksNewCashButAllowsPriorDayClose() {
    clock.set("2030-01-02T04:59:59Z");
    var id = session(open(1000, "c2")).get("id");
    clock.set("2030-01-02T05:00:00Z");
    assertThat(recharge(1000).getBody()).containsEntry("code", "CASH_DAY_ENDED");
    assertThat(session(call(HttpMethod.GET, "/api/cash/current", null, "c2")))
        .containsEntry("can_recharge", false);
    session(close(id, 1000, 1000, ""));
    assertThat(session(open(1000, "c2"))).containsEntry("business_date", "2030-01-02");
  }

  @Test
  void prefixedShareQrUrlsKeepTheTokenAndRejectMalformedPaths() {
    String token = "a".repeat(43);
    assertThat(
            VehicleQrService.tokenValue(
                "https://preview.trycloudflare.com/" + "b".repeat(32) + "/p/" + token))
        .isEqualTo(token);
    org.assertj.core.api.Assertions.assertThatThrownBy(
            () -> VehicleQrService.tokenValue("https://preview.trycloudflare.com/wrong/p/" + token))
        .isInstanceOf(ApiProblem.class);
  }

  @Test
  void twoCashiersCannotOpenSamePointConcurrently() {
    var a = CompletableFuture.supplyAsync(() -> open(0, "c2"));
    var b = CompletableFuture.supplyAsync(() -> open(0, "c3"));
    assertThat(List.of(a.join().getStatusCode().value(), b.join().getStatusCode().value()))
        .containsExactlyInAnyOrder(200, 409);
    assertThat(db.queryForObject("SELECT count(*) FROM cash_sessions", Integer.class)).isEqualTo(1);
  }

  @Test
  void closingAndRechargeSerializeOnSameSession() {
    var id = session(open(0, "c2")).get("id");
    var a = CompletableFuture.supplyAsync(() -> recharge(1000));
    var b = CompletableFuture.supplyAsync(() -> close(id, 0, 0, "Conteo al cierre"));
    var credit = a.join();
    var closed = session(b.join());
    int total = credit.getStatusCode().value() == 200 ? 1000 : 0;
    assertThat(closed).containsEntry("recharge_total", total).containsEntry("difference", -total);
    assertThat(db.queryForObject("SELECT balance FROM users WHERE id=1", Long.class))
        .isEqualTo(total);
    assertThat(recharge(1000).getStatusCode().value()).isEqualTo(409);
  }
}
