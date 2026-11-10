package com.parku;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GateService {
  private final JdbcTemplate db;
  private final IdentityService identity;
  private final VehicleQrService qr;
  private final ObjectMapper json;

  public GateService(
      JdbcTemplate db, IdentityService identity, VehicleQrService qr, ObjectMapper json) {
    this.db = db;
    this.identity = identity;
    this.qr = qr;
    this.json = json;
  }

  @Transactional
  public Result confirm(String auth, String token, String action, String requestId) {
    var operator = identity.requireRole(auth, "guard", "admin");
    // The singleton lock serializes admission, configuration and idempotency across app instances.
    var settings = db.queryForMap("SELECT * FROM parking_settings WHERE id=1 FOR UPDATE");
    String fingerprint = VehicleQrService.digest(action + ":" + token);
    var old =
        db.queryForList(
            "SELECT * FROM parking_operations WHERE operator_id=? AND request_id=?",
            operator.get("id"),
            requestId);
    if (!old.isEmpty()) {
      if (!fingerprint.equals(old.getFirst().get("fingerprint")))
        throw new ApiProblem(409, "IDEMPOTENCY_CONFLICT", "Clave utilizada con otra solicitud");
      try {
        Map<String, Object> receipt =
            json.readValue(
                (String) old.getFirst().get("receipt"),
                new TypeReference<Map<String, Object>>() {});
        receipt.put("replayed", true);
        return new Result(true, receipt);
      } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
        throw new IllegalStateException(e);
      }
    }
    var found =
        db.queryForList(
            "SELECT vehicle_id FROM vehicle_qr WHERE token_hash=?", VehicleQrService.digest(token));
    if (found.isEmpty()) throw new ApiProblem(422, "QR_INVALID", "QR inválido");
    Object vehicleId = found.getFirst().get("vehicle_id");
    var vehicles = db.queryForList("SELECT * FROM vehicles WHERE id=? FOR UPDATE", vehicleId);
    if (vehicles.isEmpty()) throw new ApiProblem(422, "QR_INVALID", "QR inválido");
    var valid = qr.inspectToken(token); // Expiry rechecked after waiting for both locks.
    var active =
        db.queryForList(
            "SELECT * FROM parking_visits WHERE vehicle_id=? AND exited_at IS NULL", vehicleId);
    var now = OffsetDateTime.now(ZoneOffset.UTC);
    Map<String, Object> visit;
    Map<String, Object> charge = null;
    if ("entry".equals(action)) {
      if (!active.isEmpty())
        throw new ApiProblem(409, "ALREADY_INSIDE", "El vehículo ya tiene ingreso activo");
      if (settings.get("capacity") == null)
        throw new ApiProblem(
            503, "PARKING_NOT_CONFIGURED", "El administrador debe configurar capacidad");
      long count =
          db.queryForObject(
              "SELECT count(*) FROM parking_visits WHERE exited_at IS NULL", Long.class);
      if (count >= ((Number) settings.get("capacity")).longValue())
        throw new ApiProblem(409, "PARKING_FULL", "Parqueadero lleno");
      var vehicle = vehicles.getFirst();
      visit =
          db.queryForMap(
              "INSERT INTO parking_visits(vehicle_id,user_id,plate,vehicle_type,entered_at) VALUES(?,?,?,?,?) RETURNING *",
              vehicleId,
              valid.get("user_id"),
              vehicle.get("plate"),
              vehicle.get("type"),
              now);
    } else {
      if (active.isEmpty())
        throw new ApiProblem(409, "NOT_INSIDE", "El vehículo no tiene ingreso activo");
      visit = active.getFirst();
      charge = completeExit(visit, operator, now);
      db.update("UPDATE parking_visits SET exited_at=? WHERE id=?", now, visit.get("id"));
    }
    db.update("UPDATE vehicle_qr SET consumed=true WHERE id=?", valid.get("id"));
    long operationId =
        db.queryForObject(
            "INSERT INTO parking_operations(operator_id,request_id,fingerprint,visit_id,action,occurred_at,receipt) VALUES(?,?,?,?,?,?,'{}') RETURNING id",
            Long.class,
            operator.get("id"),
            requestId,
            fingerprint,
            visit.get("id"),
            action,
            now);
    Map<String, Object> receipt = new LinkedHashMap<>();
    receipt.put("success", true);
    receipt.put("operation_id", operationId);
    receipt.put("visit_id", visit.get("id"));
    receipt.put("vehicle_id", vehicleId);
    receipt.put("action", action);
    receipt.put("parking_state", "entry".equals(action) ? "INSIDE" : "OUTSIDE");
    receipt.put("occurred_at", now.toString());
    receipt.put("replayed", false);
    receipt.put("message", "entry".equals(action) ? "Ingreso registrado" : "Salida registrada");
    if (charge != null) receipt.put("charge", charge);
    try {
      db.update(
          "UPDATE parking_operations SET receipt=? WHERE id=?",
          json.writeValueAsString(receipt),
          operationId);
    } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
      throw new IllegalStateException(e);
    }
    return new Result(false, receipt);
  }

  private Map<String, Object> completeExit(
      Map<String, Object> visit, Map<String, Object> operator, OffsetDateTime now) {
    throw new ApiProblem(503, "BILLING_NOT_READY", "Salida pendiente del servicio de cobro S2-03");
  }

  public record Result(boolean replayed, Map<String, Object> receipt) {}
}
