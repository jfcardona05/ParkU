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
      var rates =
          db.queryForList(
              "SELECT id FROM parking_rates WHERE vehicle_type=? ORDER BY id DESC LIMIT 1",
              vehicle.get("type"));
      if (rates.isEmpty())
        throw new ApiProblem(503, "PARKING_NOT_CONFIGURED", "Tarifa no configurada");
      visit =
          db.queryForMap(
              "INSERT INTO parking_visits(vehicle_id,user_id,plate,vehicle_type,entered_at,rate_id) VALUES(?,?,?,?,?,?) RETURNING *",
              vehicleId,
              valid.get("user_id"),
              vehicle.get("plate"),
              vehicle.get("type"),
              now,
              rates.getFirst().get("id"));
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
    if (visit.get("rate_id") == null)
      throw new ApiProblem(
          503,
          "PARKING_NOT_CONFIGURED",
          "Estancia sin tarifa: requiere conciliación administrativa");
    var rate = db.queryForMap("SELECT * FROM parking_rates WHERE id=?", visit.get("rate_id"));
    var user =
        db.queryForMap("SELECT balance FROM users WHERE id=? FOR UPDATE", visit.get("user_id"));
    long before = ((Number) user.get("balance")).longValue();
    var quote =
        ParkingPrice.quote(
            ((java.sql.Timestamp) visit.get("entered_at")).toInstant(),
            now.toInstant(),
            ((Number) rate.get("block_seconds")).longValue(),
            ((Number) rate.get("minimum_blocks")).longValue(),
            ((Number) rate.get("amount")).longValue());
    long blocks = quote.blocks();
    long amount = quote.amount();
    if (before < amount)
      throw new ApiProblem(
          409, "INSUFFICIENT_BALANCE", "Saldo insuficiente para completar la salida");
    long after = before - amount;
    db.update("UPDATE users SET balance=? WHERE id=?", after, visit.get("user_id"));
    String label =
        rate.get("amount")
            + " COP / "
            + rate.get("block_seconds")
            + " s iniciados; mínimo "
            + rate.get("minimum_blocks");
    long movement =
        db.queryForObject(
            "INSERT INTO transactions(user_id,operator_id,type,amount,point_name,reference,balance_after,visit_id,parking_rate_label) VALUES(?,?,'COBRO_ESTACIONAMIENTO',?,'Portería',?,?,?,?) RETURNING id",
            Long.class,
            visit.get("user_id"),
            operator.get("id"),
            amount,
            java.util.UUID.randomUUID(),
            after,
            visit.get("id"),
            label);
    return Map.of(
        "amount",
        amount,
        "currency",
        "COP",
        "balance_after",
        after,
        "transaction_id",
        movement,
        "rate_version",
        rate.get("id"),
        "blocks",
        blocks,
        "parking_rate_label",
        label);
  }

  public record Result(boolean replayed, Map<String, Object> receipt) {}
}
