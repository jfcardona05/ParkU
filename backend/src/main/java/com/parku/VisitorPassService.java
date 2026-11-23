package com.parku;

import java.security.SecureRandom;
import java.time.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VisitorPassService {
  private final JdbcTemplate db;
  private final IdentityService identity;
  private final CashService cash;
  private final Clock clock;

  public VisitorPassService(
      JdbcTemplate db, IdentityService identity, CashService cash, Clock clock) {
    this.db = db;
    this.identity = identity;
    this.cash = cash;
    this.clock = clock;
  }

  private LocalDate day() {
    return LocalDate.now(clock.withZone(DailyPassService.ZONE));
  }

  private Map<String, Object> rate(String type) {
    var rows =
        db.queryForList(
            "SELECT id,amount FROM parking_rates WHERE vehicle_type=? ORDER BY id DESC LIMIT 1",
            type);
    if (rows.isEmpty())
      throw new ApiProblem(503, "PARKING_NOT_CONFIGURED", "Tarifa no configurada");
    return rows.getFirst();
  }

  public Map<String, Object> quote(String auth, String type) {
    identity.operator(auth);
    if (!List.of("moto", "automovil").contains(type))
      throw new ApiProblem(400, "INVALID_VEHICLE", "Tipo de vehículo inválido");
    return Map.of(
        "success", true, "amount", rate(type).get("amount"), "service_date", day().toString());
  }

  private Map<String, Object> receipt(Map<String, Object> row, boolean replayed) {
    var out = new LinkedHashMap<>(row);
    out.remove("token_hash");
    out.remove("fingerprint");
    out.remove("request_id");
    out.put("income_type", "PASE_DIARIO_VISITANTE");
    out.put("replayed", replayed);
    return out;
  }

  public Map<String, Object> receipt(String auth, long id) {
    identity.operator(auth);
    var rows = db.queryForList("SELECT * FROM visitor_passes WHERE id=?", id);
    if (rows.isEmpty()) throw new ApiProblem(404, "PASS_NOT_FOUND", "Pase no encontrado");
    return Map.of("success", true, "pass", receipt(rows.getFirst(), true));
  }

  @Transactional
  public Map<String, Object> sell(String auth, VisitorPassController.Sale body) {
    var operator = identity.operator(auth);
    String plate = body.plate().trim().toUpperCase(Locale.ROOT), name = body.visitor_name().trim();
    if (name.isEmpty())
      throw new ApiProblem(400, "INVALID_NAME", "Escribe el nombre del visitante");
    String fingerprint =
        VehicleQrService.digest(
            name
                + ":"
                + plate
                + ":"
                + body.vehicle_type()
                + ":"
                + body.point_name()
                + ":"
                + body.expected_amount()
                + ":"
                + body.service_date());
    // Serialize same-key retries, including retries after the cash register has closed.
    db.queryForObject(
        "SELECT pg_advisory_xact_lock(hashtextextended(?,0))",
        Object.class,
        "visitor-sale:" + operator.get("id") + ":" + body.request_id());
    var old =
        db.queryForList(
            "SELECT * FROM visitor_passes WHERE operator_id=? AND request_id=?",
            operator.get("id"),
            body.request_id());
    if (!old.isEmpty()) {
      if (!fingerprint.equals(old.getFirst().get("fingerprint")))
        throw new ApiProblem(
            409, "IDEMPOTENCY_CONFLICT", "La referencia corresponde a otros datos");
      return Map.of("success", true, "pass", receipt(old.getFirst(), true));
    }
    long cashId =
        cash.lockForRecharge(
            ((Number) operator.get("id")).longValue(), body.point_name(), body.expected_amount());
    var day = day();
    if (!day.toString().equals(body.service_date()))
      throw new ApiProblem(
          409, "DAY_CHANGED", "Cambió el día. Consulta y confirma el pase otra vez.");
    var rate = rate(body.vehicle_type());
    if (((Number) rate.get("amount")).longValue() != body.expected_amount())
      throw new ApiProblem(
          409, "PRICE_CHANGED", "Cambió la tarifa. Consulta y confirma el nuevo importe.");
    db.queryForObject(
        "SELECT pg_advisory_xact_lock(hashtextextended(?,0))",
        Object.class,
        "visitor-plate:" + plate);
    if (!db.queryForList(
            "SELECT id FROM visitor_passes WHERE plate=? AND service_date=?", plate, day)
        .isEmpty())
      throw new ApiProblem(
          409,
          "DAILY_PASS_EXISTS",
          "Esta placa ya tiene pase hoy. Reimprime su comprobante desde el historial.");
    byte[] bytes = new byte[32];
    new SecureRandom().nextBytes(bytes);
    String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    var saved =
        db.queryForMap(
            "INSERT INTO"
                + " visitor_passes(visitor_name,plate,vehicle_type,service_date,amount,rate_id,cash_session_id,operator_id,point_name,reference,request_id,fingerprint,token,token_hash,created_at,expires_at)"
                + " VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) RETURNING *",
            name,
            plate,
            body.vehicle_type(),
            day,
            body.expected_amount(),
            rate.get("id"),
            cashId,
            operator.get("id"),
            body.point_name(),
            UUID.randomUUID(),
            body.request_id(),
            fingerprint,
            token,
            VehicleQrService.digest(token),
            java.sql.Timestamp.from(clock.instant()),
            java.sql.Timestamp.from(
                day.plusDays(1).atStartOfDay(DailyPassService.ZONE).toInstant()));
    return Map.of("success", true, "pass", receipt(saved, false));
  }

  public Map<String, Object> find(String token) {
    var rows =
        db.queryForList(
            "SELECT *,visitor_name AS owner_name FROM visitor_passes WHERE token_hash=?",
            VehicleQrService.digest(VehicleQrService.tokenValue(token)));
    return rows.isEmpty() ? null : rows.getFirst();
  }

  public void valid(Map<String, Object> pass) {
    if (pass.get("exited_at") != null)
      throw new ApiProblem(409, "QR_USED", "El pase de visitante ya fue finalizado");
    if (!clock.instant().isBefore(((java.sql.Timestamp) pass.get("expires_at")).toInstant()))
      throw new ApiProblem(410, "QR_EXPIRED", "Pase diario vencido. Consulta con taquilla.");
  }

  public Map<String, Object> preview(Map<String, Object> pass) {
    valid(pass);
    boolean inside = pass.get("entered_at") != null;
    return Map.of(
        "success",
        true,
        "vehicle_id",
        pass.get("id"),
        "plate",
        pass.get("plate"),
        "owner_name",
        pass.get("visitor_name"),
        "vehicle_type",
        pass.get("vehicle_type"),
        "expires_at",
        ((java.sql.Timestamp) pass.get("expires_at")).toInstant(),
        "parking_state",
        inside ? "INSIDE" : "OUTSIDE",
        "allowed_action",
        inside ? "exit" : "entry",
        "prepaid",
        true,
        "pass_kind",
        "VISITOR");
  }

  // Called inside GateService's transaction, holding the shared parking_settings lock.
  public GateService.Result confirm(Object operator, String token, String action, String key) {
    String fingerprint = VehicleQrService.digest(action + ":" + token);
    var old =
        db.queryForList(
            "SELECT o.*,p.plate FROM visitor_gate_operations o JOIN visitor_passes p ON"
                + " p.id=o.pass_id WHERE o.operator_id=? AND o.request_id=?",
            operator,
            key);
    if (!old.isEmpty()) {
      if (!fingerprint.equals(old.getFirst().get("fingerprint")))
        throw new ApiProblem(409, "IDEMPOTENCY_CONFLICT", "Clave utilizada con otra solicitud");
      return result(old.getFirst(), true);
    }
    var pass =
        db.queryForMap(
            "SELECT * FROM visitor_passes WHERE token_hash=? FOR UPDATE",
            VehicleQrService.digest(token));
    valid(pass);
    if ("entry".equals(action)) {
      if (pass.get("entered_at") != null
          || !db.queryForList(
                  "SELECT id FROM parking_visits WHERE plate=? AND exited_at IS NULL",
                  pass.get("plate"))
              .isEmpty()
          || !db.queryForList(
                  "SELECT id FROM visitor_passes WHERE plate=? AND entered_at IS NOT NULL AND"
                      + " exited_at IS NULL",
                  pass.get("plate"))
              .isEmpty())
        throw new ApiProblem(409, "ALREADY_INSIDE", "La placa ya tiene ingreso activo");
      db.update(
          "UPDATE visitor_passes SET entered_at=? WHERE id=?",
          java.sql.Timestamp.from(clock.instant()),
          pass.get("id"));
    } else {
      if (pass.get("entered_at") == null)
        throw new ApiProblem(409, "NOT_INSIDE", "El visitante no tiene ingreso activo");
      db.update(
          "UPDATE visitor_passes SET exited_at=? WHERE id=?",
          java.sql.Timestamp.from(clock.instant()),
          pass.get("id"));
    }
    var operation =
        db.queryForMap(
            "INSERT INTO"
                + " visitor_gate_operations(operator_id,request_id,fingerprint,pass_id,action,occurred_at)"
                + " VALUES(?,?,?,?,?,?) RETURNING *",
            operator,
            key,
            fingerprint,
            pass.get("id"),
            action,
            java.sql.Timestamp.from(clock.instant()));
    return result(operation, false);
  }

  private GateService.Result result(Map<String, Object> row, boolean replayed) {
    var receipt = new LinkedHashMap<String, Object>();
    receipt.put("success", true);
    receipt.put("operation_id", row.get("id"));
    receipt.put("visit_id", row.get("pass_id"));
    receipt.put("vehicle_id", row.get("pass_id"));
    receipt.put("action", row.get("action"));
    receipt.put("parking_state", "entry".equals(row.get("action")) ? "INSIDE" : "OUTSIDE");
    receipt.put("occurred_at", ((java.sql.Timestamp) row.get("occurred_at")).toInstant());
    receipt.put("replayed", replayed);
    receipt.put("prepaid", true);
    receipt.put("pass_kind", "VISITOR");
    receipt.put(
        "message", "entry".equals(row.get("action")) ? "Ingreso registrado" : "Salida registrada");
    return new GateService.Result(replayed, receipt);
  }
}
