package com.parku;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.*;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = "parku.demo.enabled=false")
class SprintTwoApiTest {
  @Autowired TestRestTemplate http;
  @Autowired JdbcTemplate db;

  @BeforeEach
  void reset() {
    assertThat(db.queryForObject("SELECT current_database()", String.class)).endsWith("_test");
    db.execute("TRUNCATE transactions,vehicles,sessions,users RESTART IDENTITY CASCADE");
    for (String role : List.of("estudiante", "docente", "guard", "admin", "operador")) {
      long id =
          db.queryForObject(
              "INSERT INTO users(name,email,password_hash,role,balance) VALUES (?,?,?, ?,10000) RETURNING id",
              Long.class,
              role,
              role + "@test.co",
              "unused",
              role);
      db.update(
          "INSERT INTO sessions(token_hash,user_id,expires_at) VALUES (?,?,CURRENT_TIMESTAMP+INTERVAL '1 hour')",
          VehicleQrService.digest(role),
          id);
    }
    db.update(
        "INSERT INTO parking_rates(vehicle_type,amount,block_seconds,minimum_blocks) VALUES('moto',4000,3600,1),('automovil',5000,3600,1)");
    db.update("UPDATE parking_settings SET capacity=NULL WHERE id=1");
    db.update(
        "INSERT INTO vehicles(user_id,plate,type) VALUES (1,'ABC123','moto'),(2,'XYZ789','automovil')");
  }

  ResponseEntity<Map> call(HttpMethod method, String path, Object body, String session) {
    var headers = new HttpHeaders();
    headers.setContentType(MediaType.APPLICATION_JSON);
    if (session != null) headers.setBearerAuth(session);
    return http.exchange(path, method, new HttpEntity<>(body, headers), Map.class);
  }

  ResponseEntity<Map> post(String path, Object body, String session) {
    return call(HttpMethod.POST, path, body, session);
  }

  String qr(long id, String session) {
    return (String) post("/api/vehicles/" + id + "/qr", null, session).getBody().get("token");
  }

  void error(ResponseEntity<Map> response, int status, String code) {
    assertThat(response.getStatusCode().value()).isEqualTo(status);
    assertThat(response.getBody()).containsEntry("code", code).containsEntry("success", false);
  }

  @Test
  void qrOwnershipAuthorizationExpiryRevocationAndInvalidTokens() {
    assertThat(post("/api/vehicles/1/qr", null, null).getStatusCode().value()).isEqualTo(401);
    error(post("/api/vehicles/1/qr", null, "docente"), 404, "VEHICLE_NOT_FOUND");
    String old = qr(1, "estudiante"), token = qr(1, "estudiante");
    assertThat(token).hasSize(43).isNotEqualTo(old);
    assertThat(
            db.queryForObject(
                "SELECT token_hash FROM vehicle_qr WHERE token_hash=?",
                String.class,
                VehicleQrService.digest(token)))
        .isNotEqualTo(token);
    error(post("/api/gate/inspect", Map.of("token", token), "estudiante"), 403, "FORBIDDEN");
    error(post("/api/gate/inspect", Map.of("token", old), "guard"), 409, "QR_REVOKED");
    error(
        post("/api/gate/inspect", Map.of("token", "PARKU-DEMO:1:9999999999999"), "guard"),
        422,
        "QR_INVALID");
    assertThat(post("/api/gate/inspect", Map.of("token", token), "guard").getStatusCode().value())
        .isEqualTo(200);
    assertThat(post("/api/gate/inspect", Map.of("token", token), "admin").getStatusCode().value())
        .isEqualTo(200);
    assertThat(db.queryForObject("SELECT count(*) FROM vehicle_qr WHERE consumed", Integer.class))
        .isZero();
    db.update(
        "UPDATE vehicle_qr SET expires_at=clock_timestamp() WHERE token_hash=?",
        VehicleQrService.digest(token));
    error(post("/api/gate/inspect", Map.of("token", token), "guard"), 410, "QR_EXPIRED");
    assertThat(post("/api/gate/inspect", Map.of("token", token), null).getStatusCode().value())
        .isEqualTo(401);
  }

  @Test
  void concurrentRegenerationLeavesExactlyOneUsableToken() {
    var a = CompletableFuture.supplyAsync(() -> qr(1, "estudiante"));
    var b = CompletableFuture.supplyAsync(() -> qr(1, "estudiante"));
    var results =
        List.of(a.join(), b.join()).stream()
            .map(
                t -> post("/api/gate/inspect", Map.of("token", t), "guard").getStatusCode().value())
            .toList();
    assertThat(results).containsExactlyInAnyOrder(200, 409);
  }

  Map<String, Object> operation(String token, String action, String key) {
    return Map.of("token", token, "action", action, "request_id", key);
  }

  @Test
  void entryIsAuthorizedIdempotentAndRejectsDuplicateVehicle() {
    db.update("UPDATE parking_settings SET capacity=10 WHERE id=1");
    String token = qr(1, "estudiante");
    var body = operation(token, "entry", "[#flutter-key]");
    error(post("/api/gate/operations", body, "estudiante"), 403, "FORBIDDEN");
    var entered = post("/api/gate/operations", body, "guard");
    assertThat(entered.getStatusCode().value()).isEqualTo(201);
    var retry = post("/api/gate/operations", body, "guard");
    assertThat(retry.getStatusCode().value()).isEqualTo(200);
    assertThat(retry.getBody())
        .containsEntry("operation_id", entered.getBody().get("operation_id"))
        .containsEntry("replayed", true);
    error(
        post("/api/gate/operations", operation(token, "exit", "[#flutter-key]"), "guard"),
        409,
        "IDEMPOTENCY_CONFLICT");
    error(
        post("/api/gate/operations", operation(token, "entry", "new-key"), "guard"),
        409,
        "QR_USED");
    error(
        post("/api/gate/operations", operation(qr(1, "estudiante"), "entry", "another"), "guard"),
        409,
        "ALREADY_INSIDE");
    error(call(HttpMethod.DELETE, "/api/vehicles/1", null, "estudiante"), 409, "VEHICLE_IN_USE");
    error(
        post("/api/gate/operations", operation(qr(2, "docente"), "exit", "no-entry"), "guard"),
        409,
        "NOT_INSIDE");
    assertThat(db.queryForObject("SELECT count(*) FROM parking_operations", Integer.class))
        .isEqualTo(1);
  }

  @Test
  void simultaneousEntryAndCapacityDoNotOverbook() {
    db.update("UPDATE parking_settings SET capacity=1 WHERE id=1");
    String one = qr(1, "estudiante"), two = qr(2, "docente");
    var a =
        CompletableFuture.supplyAsync(
            () -> post("/api/gate/operations", operation(one, "entry", "a"), "guard"));
    var b =
        CompletableFuture.supplyAsync(
            () -> post("/api/gate/operations", operation(two, "entry", "b"), "guard"));
    assertThat(List.of(a.join().getStatusCode().value(), b.join().getStatusCode().value()))
        .containsExactlyInAnyOrder(201, 409);
    assertThat(
            db.queryForObject(
                "SELECT count(*) FROM parking_visits WHERE exited_at IS NULL", Integer.class))
        .isEqualTo(1);
  }

  @Test
  void simultaneousSameRequestProducesOneReceipt() {
    db.update("UPDATE parking_settings SET capacity=10 WHERE id=1");
    var body = operation(qr(1, "estudiante"), "entry", "same");
    var a = CompletableFuture.supplyAsync(() -> post("/api/gate/operations", body, "guard"));
    var b = CompletableFuture.supplyAsync(() -> post("/api/gate/operations", body, "guard"));
    assertThat(List.of(a.join().getStatusCode().value(), b.join().getStatusCode().value()))
        .containsExactlyInAnyOrder(201, 200);
    assertThat(a.join().getBody().get("operation_id"))
        .isEqualTo(b.join().getBody().get("operation_id"));
  }

  void capacity(int value) {
    assertThat(
            post("/api/admin/parking/settings", Map.of("capacity", value), "admin")
                .getStatusCode()
                .value())
        .isEqualTo(200);
  }

  ResponseEntity<Map> enter(long id, String user) {
    return post(
        "/api/gate/operations",
        operation(qr(id, user), "entry", UUID.randomUUID().toString()),
        "guard");
  }

  ResponseEntity<Map> exit(long id, String user) {
    return post(
        "/api/gate/operations",
        operation(qr(id, user), "exit", UUID.randomUUID().toString()),
        "guard");
  }

  @Test
  void adminCanChangeRatesButCannotRepriceAnActiveVisit() {
    capacity(10);
    assertThat(enter(1, "estudiante").getStatusCode().value()).isEqualTo(201);
    var rate =
        Map.of("vehicle_type", "moto", "amount", 6000, "block_seconds", 3600, "minimum_blocks", 1);
    error(post("/api/admin/parking/rates", rate, "guard"), 403, "FORBIDDEN");
    error(post("/api/admin/parking/rates", rate, "operador"), 403, "FORBIDDEN");
    assertThat(post("/api/admin/parking/rates", rate, "admin").getStatusCode().value())
        .isEqualTo(201);
    assertThat(((Map) exit(1, "estudiante").getBody().get("charge")).get("amount")).isEqualTo(4000);
    assertThat(enter(1, "estudiante").getStatusCode().value()).isEqualTo(201);
    assertThat(((Map) exit(1, "estudiante").getBody().get("charge")).get("amount")).isEqualTo(6000);
    assertThat(db.queryForObject("SELECT balance FROM users WHERE id=1", Long.class)).isZero();
    assertThat(
            db.queryForObject(
                "SELECT count(*) FROM transactions WHERE type='COBRO_ESTACIONAMIENTO'",
                Integer.class))
        .isEqualTo(2);
  }

  @Test
  void insufficientFundsRollBackAndRechargeAllowsRetryWithoutDoubleDebit() {
    capacity(10);
    enter(2, "docente");
    db.update("UPDATE users SET balance=1000 WHERE id=2");
    String token = qr(2, "docente");
    var body = operation(token, "exit", "exit-retry");
    error(post("/api/gate/operations", body, "guard"), 409, "INSUFFICIENT_BALANCE");
    assertThat(db.queryForObject("SELECT count(*) FROM transactions", Integer.class)).isZero();
    assertThat(
            db.queryForObject(
                "SELECT count(*) FROM parking_visits WHERE exited_at IS NULL", Integer.class))
        .isEqualTo(1);
    assertThat(post("/api/gate/inspect", Map.of("token", token), "guard").getStatusCode().value())
        .isEqualTo(200);
    assertThat(
            post(
                    "/api/wallet/recharge",
                    Map.of(
                        "amount",
                        5000,
                        "point_name",
                        "Punto 1 - Portería Principal USTA",
                        "user_id",
                        2),
                    "operador")
                .getStatusCode()
                .value())
        .isEqualTo(200);
    var paid = post("/api/gate/operations", body, "guard");
    assertThat(paid.getStatusCode().value()).isEqualTo(201);
    assertThat(((Map) paid.getBody().get("charge")).get("amount")).isEqualTo(5000);
    db.update("UPDATE vehicle_qr SET expires_at=clock_timestamp()-INTERVAL '1 minute'");
    assertThat(post("/api/gate/operations", body, "guard").getStatusCode().value()).isEqualTo(200);
    assertThat(db.queryForObject("SELECT balance FROM users WHERE id=2", Long.class))
        .isEqualTo(1000);
  }

  @Test
  void concurrentExitsOnSameWalletCannotOverdraw() {
    capacity(10);
    db.update("INSERT INTO vehicles(user_id,plate,type) VALUES(1,'AAA999','moto')");
    db.update("UPDATE users SET balance=6000 WHERE id=1");
    enter(1, "estudiante");
    enter(3, "estudiante");
    String aToken = qr(1, "estudiante"), bToken = qr(3, "estudiante");
    var a =
        CompletableFuture.supplyAsync(
            () -> post("/api/gate/operations", operation(aToken, "exit", "a"), "guard"));
    var b =
        CompletableFuture.supplyAsync(
            () -> post("/api/gate/operations", operation(bToken, "exit", "b"), "guard"));
    assertThat(List.of(a.join().getStatusCode().value(), b.join().getStatusCode().value()))
        .containsExactlyInAnyOrder(201, 409);
    assertThat(db.queryForObject("SELECT balance FROM users WHERE id=1", Long.class))
        .isEqualTo(2000);
    assertThat(db.queryForObject("SELECT count(*) FROM transactions", Integer.class)).isEqualTo(1);
  }

  @Test
  void repeatedConcurrentExitAndRechargeAreConsistent() {
    capacity(10);
    enter(1, "estudiante");
    var body = operation(qr(1, "estudiante"), "exit", "same-exit");
    var a = CompletableFuture.supplyAsync(() -> post("/api/gate/operations", body, "guard"));
    var b = CompletableFuture.supplyAsync(() -> post("/api/gate/operations", body, "guard"));
    var c =
        CompletableFuture.supplyAsync(
            () ->
                post(
                    "/api/wallet/recharge",
                    Map.of(
                        "amount",
                        2000,
                        "point_name",
                        "Punto 1 - Portería Principal USTA",
                        "user_id",
                        1),
                    "operador"));
    assertThat(List.of(a.join().getStatusCode().value(), b.join().getStatusCode().value()))
        .containsExactlyInAnyOrder(201, 200);
    assertThat(c.join().getStatusCode().value()).isEqualTo(200);
    assertThat(db.queryForObject("SELECT balance FROM users WHERE id=1", Long.class))
        .isEqualTo(8000);
    assertThat(db.queryForObject("SELECT count(*) FROM transactions", Integer.class)).isEqualTo(2);
  }

  @Test
  void configurationAndCapacityAreValidated() {
    error(
        post(
            "/api/gate/operations",
            operation(qr(1, "estudiante"), "entry", "not-configured"),
            "guard"),
        503,
        "PARKING_NOT_CONFIGURED");
    capacity(2);
    enter(1, "estudiante");
    enter(2, "docente");
    error(
        post("/api/admin/parking/settings", Map.of("capacity", 1), "admin"),
        409,
        "CAPACITY_BELOW_OCCUPANCY");
    assertThat(
            post(
                    "/api/admin/parking/rates",
                    Map.of(
                        "vehicle_type",
                        "moto",
                        "amount",
                        -1,
                        "block_seconds",
                        0,
                        "minimum_blocks",
                        0),
                    "admin")
                .getStatusCode()
                .value())
        .isEqualTo(400);
    assertThat(
            post("/api/admin/parking/settings", Map.of("capacity", 0), "admin")
                .getStatusCode()
                .value())
        .isEqualTo(400);
  }
}
