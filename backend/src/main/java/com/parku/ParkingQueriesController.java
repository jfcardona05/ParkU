package com.parku;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class ParkingQueriesController {
  private final JdbcTemplate db;
  private final IdentityService identity;
  private final ObjectMapper json;

  public ParkingQueriesController(JdbcTemplate db, IdentityService identity, ObjectMapper json) {
    this.db = db;
    this.identity = identity;
    this.json = json;
  }

  @GetMapping("/parking/occupancy")
  public Map<String, Object> occupancy(
      @RequestHeader(value = "Authorization", required = false) String auth) {
    identity.current(auth);
    var counts =
        db.queryForMap(
            "SELECT capacity,(SELECT count(*) FROM parking_visits WHERE exited_at IS NULL) AS occupied FROM parking_settings WHERE id=1");
    if (counts.get("capacity") == null)
      throw new ApiProblem(503, "PARKING_NOT_CONFIGURED", "Capacidad no configurada");
    long capacity = ((Number) counts.get("capacity")).longValue(),
        occupied = ((Number) counts.get("occupied")).longValue();
    return Map.of(
        "success",
        true,
        "capacity",
        capacity,
        "occupied",
        occupied,
        "available",
        capacity - occupied);
  }

  @GetMapping("/vehicles/{id}/parking")
  public Map<String, Object> state(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @PathVariable long id) {
    var user = identity.current(auth);
    var rows =
        db.queryForList(
            "SELECT v.id,p.id AS visit_id,p.entered_at FROM vehicles v LEFT JOIN parking_visits p ON p.vehicle_id=v.id AND p.exited_at IS NULL WHERE v.id=? AND v.user_id=?",
            id,
            user.get("id"));
    if (rows.isEmpty()) throw new ApiProblem(404, "VEHICLE_NOT_FOUND", "Vehículo no encontrado");
    var row = rows.getFirst();
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("success", true);
    result.put("vehicle_id", id);
    result.put("parking_state", row.get("visit_id") == null ? "OUTSIDE" : "INSIDE");
    result.put("visit_id", row.get("visit_id"));
    result.put(
        "entered_at",
        row.get("entered_at") == null
            ? null
            : ((java.sql.Timestamp) row.get("entered_at")).toInstant());
    return result;
  }

  @GetMapping("/parking/history")
  public Map<String, Object> history(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @RequestParam(defaultValue = "20") int limit,
      @RequestParam(required = false) Long before_id) {
    var user = identity.current(auth);
    if (limit < 1 || limit > 100 || (before_id != null && before_id < 1))
      throw new ApiProblem(400, "INVALID_REQUEST", "Paginación inválida");
    var rows =
        db.queryForList(
            "SELECT o.id,o.receipt,p.plate FROM parking_operations o JOIN parking_visits p ON p.id=o.visit_id WHERE p.user_id=? AND o.id<? ORDER BY o.id DESC LIMIT ?",
            user.get("id"),
            before_id == null ? Long.MAX_VALUE : before_id,
            limit + 1);
    var operations = new ArrayList<Map<String, Object>>();
    for (var row : rows.subList(0, Math.min(limit, rows.size()))) {
      try {
        Map<String, Object> receipt =
            json.readValue(
                (String) row.get("receipt"), new TypeReference<Map<String, Object>>() {});
        receipt.remove("message");
        receipt.remove("success");
        receipt.remove("replayed");
        receipt.put("plate", row.get("plate"));
        receipt.putIfAbsent("charge", null);
        operations.add(receipt);
      } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
        throw new IllegalStateException(e);
      }
    }
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("success", true);
    result.put("operations", operations);
    result.put("next_before_id", rows.size() > limit ? rows.get(limit - 1).get("id") : null);
    return result;
  }
}
