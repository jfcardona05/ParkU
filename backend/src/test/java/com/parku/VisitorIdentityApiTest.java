package com.parku;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.*;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = "parku.demo.enabled=false")
class VisitorIdentityApiTest {
  @Autowired TestRestTemplate http;
  @Autowired JdbcTemplate db;
  final String point = "Punto 1 - Portería Principal USTA";

  @BeforeEach
  void setup() {
    assertThat(db.queryForObject("SELECT current_database()", String.class)).endsWith("_test");
    db.execute("TRUNCATE transactions,vehicles,sessions,users RESTART IDENTITY CASCADE");
    String hash = new BCryptPasswordEncoder().encode("pass123");
    for (int i = 1; i <= 4; i++) {
      db.update(
          "INSERT INTO users(name,email,password_hash,role,balance,document_type,document_number)"
              + " VALUES(?,?,?,?,10000,'CC',?)",
          "Persona " + i,
          "person" + i + "@test.co",
          hash,
          i == 1 ? "operador" : i == 2 ? "guard" : "estudiante",
          "10000" + i);
      db.update(
          "INSERT INTO sessions(token_hash,user_id,expires_at)"
              + " VALUES(?,?,CURRENT_TIMESTAMP+INTERVAL '1 hour')",
          VehicleQrService.digest("v" + i),
          i);
    }
    db.update(
        "INSERT INTO parking_rates(vehicle_type,amount,block_seconds,minimum_blocks)"
            + " VALUES('moto',4000,3600,1),('automovil',5000,3600,1)");
  }

  ResponseEntity<Map> call(String method, String path, Object data, String token) {
    var h = new HttpHeaders();
    h.setContentType(MediaType.APPLICATION_JSON);
    if (token != null) h.setBearerAuth(token);
    return http.exchange(path, HttpMethod.valueOf(method), new HttpEntity<>(data, h), Map.class);
  }

  void open() {
    assertThat(
            call(
                    "POST",
                    "/api/cash/open",
                    Map.of("point_name", point, "opening_amount", 1000),
                    "v1")
                .getStatusCode()
                .value())
        .isEqualTo(200);
  }

  Map<String, Object> sale(String plate, String key) {
    return Map.of(
        "visitor_name",
        "Visita <script>",
        "plate",
        plate,
        "vehicle_type",
        "automovil",
        "point_name",
        point,
        "expected_amount",
        5000,
        "service_date",
        LocalDate.now(ZoneId.of("America/Bogota")).toString(),
        "request_id",
        key);
  }

  long count(String table) {
    return db.queryForObject("SELECT count(*) FROM " + table, Long.class);
  }

  @Test
  void cashCombinesVisitorSaleAndRechargeAndReprintsSamePass() {
    open();
    var response = call("POST", "/api/admin/visitor-passes", sale("ABC123", "sale-1"), "v1");
    assertThat(response.getStatusCode().value()).isEqualTo(200);
    var pass = (Map) response.getBody().get("pass");
    assertThat(
            call(
                    "POST",
                    "/api/wallet/recharge",
                    Map.of("user_id", 3, "amount", 20000, "point_name", point),
                    "v1")
                .getStatusCode()
                .value())
        .isEqualTo(200);
    var report = call("GET", "/api/admin/recharges", null, "v1").getBody();
    var summary = (Map) report.get("summary");
    assertThat(((Number) summary.get("total_amount")).longValue()).isEqualTo(25000);
    assertThat(summary.get("count")).isEqualTo(2);
    var rows = (List<Map>) report.get("recharges");
    assertThat(rows)
        .extracting(r -> r.get("income_type"))
        .containsExactlyInAnyOrder("RECARGA_USUARIO", "PASE_DIARIO_VISITANTE");
    assertThat(
            call("GET", "/api/admin/visitor-passes/" + pass.get("id"), null, "v1")
                .getBody()
                .get("pass"))
        .isInstanceOf(Map.class);
    long cashId = db.queryForObject("SELECT id FROM cash_sessions", Long.class);
    var closed =
        call(
            "POST",
            "/api/cash/" + cashId + "/close",
            Map.of("counted_cash", 26000, "retained_cash", 1000, "notes", ""),
            "v1");
    assertThat(closed.getStatusCode().value()).isEqualTo(200);
    assertThat(
            db.queryForObject(
                "SELECT recharge_total FROM cash_sessions WHERE id=?", Long.class, cashId))
        .isEqualTo(25000);
    assertThat(
            call("POST", "/api/admin/visitor-passes", sale("ABC123", "sale-1"), "v1")
                .getStatusCode()
                .value())
        .isEqualTo(200);
    assertThat(count("visitor_passes")).isEqualTo(1);
    assertThat(db.queryForObject("SELECT balance FROM users WHERE id=3", Long.class))
        .isEqualTo(30000);
  }

  @Test
  void duplicateConcurrentSalesOnlyCollectOnceAndEnforceOpenCash() {
    assertThat(
            call("POST", "/api/admin/visitor-passes", sale("ABC123", "k"), "v1")
                .getStatusCode()
                .value())
        .isEqualTo(409);
    open();
    var requests = new ArrayList<CompletableFuture<ResponseEntity<Map>>>();
    for (int i = 0; i < 6; i++)
      requests.add(
          CompletableFuture.supplyAsync(
              () -> call("POST", "/api/admin/visitor-passes", sale("ABC123", "k"), "v1")));
    for (var req : requests) assertThat(req.join().getStatusCode().value()).isEqualTo(200);
    assertThat(count("visitor_passes")).isEqualTo(1);
    assertThat(
            call("POST", "/api/admin/visitor-passes", sale("ABC123", "another-key"), "v1")
                .getStatusCode()
                .value())
        .isEqualTo(409);
    assertThat(
            call("POST", "/api/admin/visitor-passes", sale("XYZ123", "k"), "v1")
                .getBody()
                .get("code"))
        .isEqualTo("IDEMPOTENCY_CONFLICT");
  }

  @Test
  void visitorQrIsPublicEscapedAndGateNeverChargesAgain() {
    open();
    var pass =
        (Map)
            call("POST", "/api/admin/visitor-passes", sale("ABC123", "k"), "v1")
                .getBody()
                .get("pass");
    String token = (String) pass.get("token");
    var publicPage = http.getForEntity("/p/" + token, String.class);
    assertThat(publicPage.getBody())
        .contains("ABC123", "5000 COP", "&lt;script&gt;", "Pagado")
        .doesNotContain("<script>", "password", token);
    assertThat(count("visitor_gate_operations")).isZero();
    var preview =
        call("POST", "/api/gate/inspect", Map.of("token", "https://example.test/p/" + token), "v2");
    assertThat(preview.getBody().get("allowed_action")).isEqualTo("entry");
    for (String action : List.of("entry", "exit")) {
      var op = Map.of("token", token, "action", action, "request_id", "gate-" + action);
      var res = call("POST", "/api/gate/operations", op, "v2");
      assertThat(res.getStatusCode().value()).isEqualTo(201);
      assertThat(res.getBody()).containsEntry("prepaid", true).doesNotContainKey("charge");
      assertThat(call("POST", "/api/gate/operations", op, "v2").getStatusCode().value())
          .isEqualTo(200);
    }
    assertThat(count("transactions")).isZero();
    assertThat(count("visitor_gate_operations")).isEqualTo(2);
    assertThat(
            call("POST", "/api/gate/inspect", Map.of("token", token), "v2").getStatusCode().value())
        .isEqualTo(409);
  }

  @Test
  void saleRejectsBadPricesRolesAndDoesNotChangeWallet() {
    open();
    assertThat(
            call("POST", "/api/admin/visitor-passes", sale("ABC123", "k"), "v3")
                .getStatusCode()
                .value())
        .isEqualTo(403);
    var bad = new HashMap<>(sale("ABC123", "k"));
    bad.put("expected_amount", 1);
    assertThat(call("POST", "/api/admin/visitor-passes", bad, "v1").getBody().get("code"))
        .isEqualTo("PRICE_CHANGED");
    bad.put("expected_amount", 5000);
    bad.put("service_date", "2000-01-01");
    assertThat(call("POST", "/api/admin/visitor-passes", bad, "v1").getBody().get("code"))
        .isEqualTo("DAY_CHANGED");
    assertThat(count("visitor_passes")).isZero();
  }

  Map<String, Object> profile() {
    return new HashMap<>(
        Map.of(
            "name",
            "Nuevo nombre",
            "email",
            "updated@test.co",
            "document_type",
            "TI",
            "document_number",
            "123456789",
            "current_password",
            "pass123"));
  }

  @Test
  void profileEditsOnlySelfPreservesBalanceAndRevokesOtherSessions() {
    db.update(
        "INSERT INTO sessions(token_hash,user_id,expires_at) VALUES(?,3,CURRENT_TIMESTAMP+INTERVAL"
            + " '1 hour')",
        VehicleQrService.digest("other-session"));
    var data = profile();
    data.put("new_password", "new-pass123");
    var result = call("POST", "/api/auth/profile", data, "v3");
    assertThat(result.getStatusCode().value()).isEqualTo(200);
    var user = (Map) result.getBody().get("user");
    assertThat(user)
        .containsEntry("name", "Nuevo nombre")
        .containsEntry("document_type", "TI")
        .containsEntry("balance", 10000)
        .doesNotContainKey("password_hash");
    assertThat(call("GET", "/api/auth/profile", null, "other-session").getStatusCode().value())
        .isEqualTo(401);
    assertThat(call("GET", "/api/auth/profile", null, "v3").getStatusCode().value()).isEqualTo(200);
    assertThat(
            call(
                    "POST",
                    "/api/auth/login",
                    Map.of("email", "updated@test.co", "password", "new-pass123"),
                    null)
                .getStatusCode()
                .value())
        .isEqualTo(200);
    assertThat(db.queryForObject("SELECT name FROM users WHERE id=4", String.class))
        .isEqualTo("Persona 4");
  }

  @Test
  void profileRejectsDuplicatesWrongPasswordsAndCashier() {
    var data = profile();
    data.put("document_type", "CC");
    data.put("document_number", "100004");
    assertThat(call("POST", "/api/auth/profile", data, "v3").getStatusCode().value())
        .isEqualTo(409);
    data = profile();
    data.put("current_password", "wrong");
    assertThat(call("POST", "/api/auth/profile", data, "v3").getStatusCode().value())
        .isEqualTo(403);
    assertThat(call("POST", "/api/auth/profile", profile(), "v1").getStatusCode().value())
        .isEqualTo(403);
  }

  @Test
  void registrationRequiresDocumentAndExistingAccountsCanCompleteIt() {
    var data =
        new HashMap<String, Object>(
            Map.of("name", "Nuevo", "email", "new@test.co", "password", "pass123"));
    assertThat(call("POST", "/api/auth/register", data, null).getStatusCode().value())
        .isEqualTo(400);
    data.put("document_type", "TI");
    data.put("document_number", "900001");
    assertThat(call("POST", "/api/auth/register", data, null).getStatusCode().value())
        .isEqualTo(201);
    data.put("email", "another@test.co");
    assertThat(call("POST", "/api/auth/register", data, null).getStatusCode().value())
        .isEqualTo(409);
    db.update("UPDATE users SET document_type=NULL,document_number=NULL WHERE id=3");
    assertThat(call("GET", "/api/auth/profile", null, "v3").getStatusCode().value()).isEqualTo(200);
    assertThat(call("POST", "/api/auth/profile", profile(), "v3").getStatusCode().value())
        .isEqualTo(200);
  }

  @Test
  void transferUsesCompositeDocumentAndRetrySurvivesRecipientProfileEdit() {
    var body =
        Map.of(
            "recipient_document_type",
            "CC",
            "recipient_document_number",
            "100004",
            "amount",
            3000,
            "request_id",
            "transfer1");
    var first = call("POST", "/api/wallet/transfers", body, "v3");
    assertThat(first.getStatusCode().value()).isEqualTo(200);
    db.update("UPDATE users SET document_number='9999999' WHERE id=4");
    assertThat(call("POST", "/api/wallet/transfers", body, "v3").getBody())
        .containsEntry("replayed", true);
    assertThat(db.queryForObject("SELECT balance FROM users WHERE id=3", Long.class))
        .isEqualTo(7000);
    assertThat(db.queryForObject("SELECT balance FROM users WHERE id=4", Long.class))
        .isEqualTo(13000);
    assertThat(
            call(
                    "POST",
                    "/api/wallet/transfers",
                    Map.of(
                        "recipient_document_type",
                        "TI",
                        "recipient_document_number",
                        "9999999",
                        "amount",
                        100,
                        "request_id",
                        "transfer2"),
                    "v3")
                .getStatusCode()
                .value())
        .isEqualTo(404);
  }

  @Test
  void searchFindsNameDocumentAndEmailButNeverPasswords() {
    for (String query : List.of("Persona%203", "100003", "person3%40test.co")) {
      var res = call("GET", "/api/admin/users?search=" + query, null, "v1");
      assertThat(res.getStatusCode().value()).isEqualTo(200);
    }
    var res = call("GET", "/api/admin/users?search=100003", null, "v1");
    assertThat((List) res.getBody().get("users")).hasSize(1);
    assertThat(res.getBody().toString()).doesNotContain("password_hash");
    assertThat(call("GET", "/api/admin/users?search=Persona", null, "v3").getStatusCode().value())
        .isEqualTo(403);
  }
}
