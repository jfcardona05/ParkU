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
}
