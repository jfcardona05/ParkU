package com.parku;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = "parku.demo.enabled=false")
class SprintOneApiTest {
  @Autowired TestRestTemplate http;
  @Autowired JdbcTemplate db;
  private final String point = "Punto 1 - Portería Principal USTA";

  @BeforeEach
  void reset() {
    assertThat(db.queryForObject("SELECT current_database()", String.class)).endsWith("_test");
    db.execute("TRUNCATE transactions,vehicles,sessions,users RESTART IDENTITY CASCADE");
    var encoder = new BCryptPasswordEncoder();
    for (String email : List.of("one@test.co", "two@test.co", "cash@test.co")) {
      db.update(
          "INSERT INTO users(name,email,password_hash,role,balance) VALUES (?,?,?,?,?)",
          email,
          email,
          encoder.encode("pass123"),
          email.startsWith("cash") ? "operador" : "estudiante",
          1000);
    }
  }

  private ResponseEntity<Map> request(HttpMethod method, String path, Object body, String token) {
    var headers = new HttpHeaders();
    headers.setContentType(MediaType.APPLICATION_JSON);
    if (token != null) headers.setBearerAuth(token);
    return http.exchange(path, method, new HttpEntity<>(body, headers), Map.class);
  }

  private String login(String email) {
    return (String)
        request(
                HttpMethod.POST,
                "/api/auth/login",
                Map.of("email", email, "password", "pass123"),
                null)
            .getBody()
            .get("token");
  }

  @Test
  void cp01ValidLoginAndBalance() {
    String token = login("one@test.co");
    var result = request(HttpMethod.GET, "/api/wallet/balance", null, token);
    assertThat(result.getStatusCode()).isEqualTo(HttpStatus.OK);
    assertThat(result.getBody().get("balance")).isEqualTo(1000);
  }

  @Test
  void cp02InvalidCredentialsAndMissingSessionDoNotRevealBalance() {
    var wrong =
        request(
            HttpMethod.POST,
            "/api/auth/login",
            Map.of("email", "one@test.co", "password", "wrong"),
            null);
    assertThat(wrong.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    assertThat(wrong.getBody()).doesNotContainKeys("balance", "user", "token");
    assertThat(request(HttpMethod.GET, "/api/wallet/balance", null, null).getStatusCode())
        .isEqualTo(HttpStatus.UNAUTHORIZED);
    assertThat(request(HttpMethod.GET, "/api/admin/users", null, null).getStatusCode())
        .isEqualTo(HttpStatus.UNAUTHORIZED);
  }

  @Test
  void cp03VehicleOwnershipAndDuplicatePlate() {
    String one = login("one@test.co"), two = login("two@test.co");
    var added =
        request(
            HttpMethod.POST, "/api/vehicles", Map.of("plate", "ABC123", "type", "automovil"), one);
    assertThat(added.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    var vehicle = (Map) added.getBody().get("vehicle");
    assertThat((List) request(HttpMethod.GET, "/api/vehicles", null, two).getBody().get("vehicles"))
        .isEmpty();
    assertThat(
            request(HttpMethod.DELETE, "/api/vehicles/" + vehicle.get("id"), null, two)
                .getStatusCode())
        .isEqualTo(HttpStatus.NOT_FOUND);
    assertThat(
            request(
                    HttpMethod.POST,
                    "/api/vehicles",
                    Map.of("plate", "ABC123", "type", "moto"),
                    two)
                .getStatusCode())
        .isEqualTo(HttpStatus.CONFLICT);
    assertThat((List) request(HttpMethod.GET, "/api/vehicles", null, one).getBody().get("vehicles"))
        .hasSize(1);
  }

  @Test
  void cp04MissingVehicleFieldsAreRejectedWithoutInsert() {
    String token = login("one@test.co");
    for (var body :
        List.of(
            Map.of("plate", "", "type", "moto"),
            Map.of("plate", "ABC123", "type", ""),
            Map.of("plate", "ABC123", "type", "bus"))) {
      assertThat(request(HttpMethod.POST, "/api/vehicles", body, token).getStatusCode())
          .isEqualTo(HttpStatus.BAD_REQUEST);
    }
    assertThat(db.queryForObject("SELECT count(*) FROM vehicles", Integer.class)).isZero();
  }

  @Test
  void cp05RechargeIsExactAndInvalidAmountsDoNotChangeBalanceOrHistory() {
    String cash = login("cash@test.co"), one = login("one@test.co"), two = login("two@test.co");
    var valid =
        request(
            HttpMethod.POST,
            "/api/wallet/recharge",
            Map.of("amount", 5000, "point_name", point, "user_id", 1),
            cash);
    assertThat(valid.getStatusCode()).isEqualTo(HttpStatus.OK);
    assertThat(((Map) valid.getBody().get("recharge")).get("balance_after")).isEqualTo(6000);
    for (int amount : List.of(0, -1))
      assertThat(
              request(
                      HttpMethod.POST,
                      "/api/wallet/recharge",
                      Map.of("amount", amount, "point_name", point, "user_id", 1),
                      cash)
                  .getStatusCode())
          .isEqualTo(HttpStatus.BAD_REQUEST);
    assertThat(request(HttpMethod.GET, "/api/wallet/balance", null, one).getBody().get("balance"))
        .isEqualTo(6000);
    var history =
        (List<Map>)
            request(HttpMethod.GET, "/api/wallet/history", null, one).getBody().get("transactions");
    assertThat(history).hasSize(1);
    assertThat(history.getFirst())
        .containsEntry("amount", 5000)
        .containsEntry("type", "RECARGA_PRESENCIAL")
        .containsEntry("point_name", point)
        .containsKey("reference");
    assertThat(
            (List)
                request(HttpMethod.GET, "/api/wallet/history", null, two)
                    .getBody()
                    .get("transactions"))
        .isEmpty();
  }

  @Test
  void studentCannotRechargeOrPromoteTheirOwnAccount() {
    String one = login("one@test.co");
    assertThat(
            request(
                    HttpMethod.POST,
                    "/api/wallet/recharge",
                    Map.of("amount", 5000, "point_name", point, "user_id", 1),
                    one)
                .getStatusCode())
        .isEqualTo(HttpStatus.FORBIDDEN);
    assertThat(request(HttpMethod.GET, "/api/admin/users", null, one).getStatusCode())
        .isEqualTo(HttpStatus.FORBIDDEN);
    var registration =
        request(
            HttpMethod.POST,
            "/api/auth/register",
            Map.of(
                "name", "Fake", "email", "fake@test.co", "password", "pass123", "role", "operador"),
            null);
    assertThat(registration.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    assertThat(((Map) registration.getBody().get("user")).get("role")).isEqualTo("estudiante");
  }

  @Test
  void logoutRevokesSession() {
    String one = login("one@test.co");
    assertThat(request(HttpMethod.POST, "/api/auth/logout", null, one).getStatusCode())
        .isEqualTo(HttpStatus.OK);
    assertThat(request(HttpMethod.GET, "/api/wallet/balance", null, one).getStatusCode())
        .isEqualTo(HttpStatus.UNAUTHORIZED);
  }

  @Test
  void simultaneousRechargesDoNotLoseMoney() {
    String cash = login("cash@test.co");
    var first =
        CompletableFuture.supplyAsync(
            () ->
                request(
                    HttpMethod.POST,
                    "/api/wallet/recharge",
                    Map.of("amount", 2000, "point_name", point, "user_id", 1),
                    cash));
    var second =
        CompletableFuture.supplyAsync(
            () ->
                request(
                    HttpMethod.POST,
                    "/api/wallet/recharge",
                    Map.of("amount", 3000, "point_name", point, "user_id", 1),
                    cash));
    assertThat(first.join().getStatusCode()).isEqualTo(HttpStatus.OK);
    assertThat(second.join().getStatusCode()).isEqualTo(HttpStatus.OK);
    assertThat(db.queryForObject("SELECT balance FROM users WHERE id=1", Long.class))
        .isEqualTo(6000);
    assertThat(db.queryForObject("SELECT count(*) FROM transactions", Integer.class)).isEqualTo(2);
  }
}
