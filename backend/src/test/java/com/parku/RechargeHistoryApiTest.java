package com.parku;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.*;
import java.util.*;
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
class RechargeHistoryApiTest {
  @Autowired TestRestTemplate http;
  @Autowired JdbcTemplate db;

  @TestConfiguration
  static class TimeConfig {
    @Bean
    @Primary
    Clock rechargeClock() {
      return Clock.fixed(Instant.parse("2026-11-17T04:30:00Z"), ZoneOffset.UTC);
    }
  }

  @BeforeEach
  void seed() {
    assertThat(db.queryForObject("SELECT current_database()", String.class)).endsWith("_test");
    db.execute("TRUNCATE transactions,vehicles,sessions,users RESTART IDENTITY CASCADE");
    for (int i = 1; i <= 5; i++) {
      db.update(
          "INSERT INTO users(name,email,password_hash,role,balance) VALUES(?,?,'unused',?,0)",
          i == 1 ? "Juan" : i == 2 ? "Ronaldo" : "Caja " + i,
          "user" + i + "@test.co",
          i <= 2 ? "estudiante" : i == 5 ? "guard" : "operador");
      db.update(
          "INSERT INTO sessions(token_hash,user_id,expires_at) VALUES(?,?,CURRENT_TIMESTAMP+INTERVAL '1 hour')",
          VehicleQrService.digest("r" + i),
          i);
    }
    add(1, 3, 9000, "2026-11-16T04:59:59Z", "RECARGA_PRESENCIAL");
    add(1, 3, 20000, "2026-11-16T05:00:00Z", "RECARGA_PRESENCIAL");
    add(2, 4, 50000, "2026-11-17T04:59:59Z", "RECARGA_PRESENCIAL");
    add(1, 3, 70000, "2026-11-17T05:00:00Z", "RECARGA_PRESENCIAL");
    add(1, 3, 10000, "2026-11-01T05:00:00Z", "RECARGA_PRESENCIAL");
    add(1, 3, 90000, "2026-12-01T05:00:00Z", "RECARGA_PRESENCIAL");
    add(1, 3, 5000, "2026-11-16T12:00:00Z", "COBRO_ESTACIONAMIENTO");
    add(2, 1, 8000, "2026-11-16T12:00:00Z", "TRANSFERENCIA_RECIBIDA");
  }

  void add(int user, int operator, long amount, String at, String type) {
    db.update(
        "INSERT INTO transactions(user_id,operator_id,type,amount,point_name,reference,balance_after,created_at) VALUES(?,?,?,?,'Portería',?,100000,?)",
        user,
        operator,
        type,
        amount,
        UUID.randomUUID(),
        OffsetDateTime.parse(at));
  }

  ResponseEntity<Map> get(String query, String token) {
    var headers = new HttpHeaders();
    if (token != null) headers.setBearerAuth(token);
    return http.exchange(
        java.net.URI.create(http.getRootUri() + "/api/admin/recharges" + query),
        HttpMethod.GET,
        new HttpEntity<>(headers),
        Map.class);
  }

  Map summary(Map body) {
    return (Map) body.get("summary");
  }

  @Test
  void dayUsesColombianDateAndOnlyRechargesFromAllCashiers() {
    var r = get("", "r3");
    assertThat(r.getStatusCode()).isEqualTo(HttpStatus.OK);
    var b = r.getBody();
    assertThat(b)
        .containsEntry("date", "2026-11-16")
        .containsEntry("from", "2026-11-16")
        .containsEntry("through", "2026-11-16");
    assertThat(summary(b))
        .containsEntry("total_amount", 70000)
        .containsEntry("count", 2)
        .containsEntry("user_count", 2);
    var rows = (List<Map>) b.get("recharges");
    assertThat(rows).hasSize(2);
    assertThat(rows.getFirst())
        .containsEntry("user_name", "Ronaldo")
        .containsEntry("operator_name", "Caja 4")
        .containsEntry("amount", 50000)
        .containsKeys("created_at", "reference", "point_name", "user_email");
    assertThat(rows.get(1)).containsEntry("user_name", "Juan");
  }

  @Test
  void weekStartsMondayAndMonthUsesCalendarBoundaries() {
    var w = get("?period=week&date=2026-11-22", "r3").getBody();
    assertThat(w).containsEntry("from", "2026-11-16").containsEntry("through", "2026-11-22");
    assertThat(summary(w)).containsEntry("total_amount", 140000).containsEntry("count", 3);
    var m = get("?period=month&date=2026-11-16", "r4").getBody();
    assertThat(m).containsEntry("from", "2026-11-01").containsEntry("through", "2026-11-30");
    assertThat(summary(m)).containsEntry("total_amount", 159000).containsEntry("count", 5);
  }

  @Test
  void recipientSearchFiltersRowsAndTotalsLiterally() {
    var b = get("?date=2026-11-16&search=RONALDO", "r3").getBody();
    assertThat(summary(b)).containsEntry("total_amount", 50000).containsEntry("count", 1);
    assertThat((List) b.get("recharges")).hasSize(1);
    assertThat(summary(get("?date=2026-11-16&search=user1%40test.co", "r3").getBody()))
        .containsEntry("total_amount", 20000);
    assertThat(summary(get("?search=%25", "r3").getBody())).containsEntry("count", 0);
  }

  @Test
  void studentGuardAndAnonymousCannotReadReport() {
    assertThat(get("", null).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    for (var token : List.of("r1", "r2", "r5")) {
      var r = get("", token);
      assertThat(r.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
      assertThat(r.getBody()).doesNotContainKeys("recharges", "summary");
    }
  }

  @Test
  void invalidFiltersFailAndEmptyPeriodHasZeroTotal() {
    for (var q :
        List.of(
            "?date=2026-02-30",
            "?date=hello",
            "?period=year",
            "?page=-1",
            "?page=1000001",
            "?date=9999-12-31"))
      assertThat(get(q, "r3").getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    var b = get("?date=2026-10-01", "r3").getBody();
    assertThat(summary(b)).containsEntry("count", 0).containsEntry("total_amount", 0);
    assertThat((List) b.get("recharges")).isEmpty();
  }

  @Test
  void pagesHaveNoDuplicatesAndTotalsCoverAllRows() {
    for (int i = 0; i < 53; i++) add(1, 3, 1000, "2026-11-16T15:00:00Z", "RECARGA_PRESENCIAL");
    var first = get("?date=2026-11-16", "r3").getBody();
    var second = get("?date=2026-11-16&page=1", "r3").getBody();
    var a = (List<Map>) first.get("recharges");
    var b = (List<Map>) second.get("recharges");
    assertThat(a).hasSize(50);
    assertThat(b).hasSize(5);
    assertThat(first).containsEntry("has_more", true);
    assertThat(second).containsEntry("has_more", false);
    assertThat(summary(first)).containsEntry("count", 55).containsEntry("total_amount", 123000);
    assertThat(summary(second)).isEqualTo(summary(first));
    Set<Object> ids = new HashSet<>();
    for (var row : a) assertThat(ids.add(row.get("id"))).isTrue();
    for (var row : b) assertThat(ids.add(row.get("id"))).isTrue();
  }
}
