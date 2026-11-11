package com.parku;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class ParkingAdminController {
  private final JdbcTemplate db;
  private final IdentityService identity;

  public ParkingAdminController(JdbcTemplate db, IdentityService identity) {
    this.db = db;
    this.identity = identity;
  }

  public record Rate(
      @NotBlank @Pattern(regexp = "moto|automovil") String vehicle_type,
      @NotNull @Min(1) @Max(1000000000) Long amount,
      @NotNull @Min(1) @Max(86400) Integer block_seconds,
      @NotNull @Min(1) @Max(100000) Integer minimum_blocks) {}

  public record Settings(@NotNull @Min(1) @Max(1000000) Integer capacity) {}

  @GetMapping("/parking/rates")
  public Map<String, Object> rates(
      @RequestHeader(value = "Authorization", required = false) String auth) {
    identity.current(auth);
    return Map.of(
        "success",
        true,
        "rates",
        db.queryForList(
            "SELECT DISTINCT ON(vehicle_type) id,vehicle_type,amount,block_seconds,minimum_blocks,created_at FROM parking_rates ORDER BY vehicle_type,id DESC"));
  }

  @PostMapping("/admin/parking/rates")
  @ResponseStatus(HttpStatus.CREATED)
  @Transactional
  public Map<String, Object> updateRate(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @Valid @RequestBody Rate body) {
    var admin = identity.requireRole(auth, "admin");
    db.queryForMap("SELECT id FROM parking_settings WHERE id=1 FOR UPDATE");
    var rate =
        db.queryForMap(
            "INSERT INTO parking_rates(vehicle_type,amount,block_seconds,minimum_blocks,created_by) VALUES (?,?,?,?,?) RETURNING id,vehicle_type,amount,block_seconds,minimum_blocks,created_at",
            body.vehicle_type(),
            body.amount(),
            body.block_seconds(),
            body.minimum_blocks(),
            admin.get("id"));
    return Map.of("success", true, "rate", rate);
  }

  @GetMapping("/admin/parking/settings")
  public Map<String, Object> settings(
      @RequestHeader(value = "Authorization", required = false) String auth) {
    identity.requireRole(auth, "admin");
    return Map.of(
        "success",
        true,
        "settings",
        db.queryForMap("SELECT capacity FROM parking_settings WHERE id=1"));
  }

  @PostMapping("/admin/parking/settings")
  @Transactional
  public Map<String, Object> updateSettings(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @Valid @RequestBody Settings body) {
    identity.requireRole(auth, "admin");
    db.queryForMap("SELECT id FROM parking_settings WHERE id=1 FOR UPDATE");
    long occupied =
        db.queryForObject(
            "SELECT count(*) FROM parking_visits WHERE exited_at IS NULL", Long.class);
    if (body.capacity() < occupied)
      throw new ApiProblem(
          409,
          "CAPACITY_BELOW_OCCUPANCY",
          "La capacidad no puede ser menor que la ocupación actual");
    db.update("UPDATE parking_settings SET capacity=? WHERE id=1", body.capacity());
    return Map.of("success", true, "settings", Map.of("capacity", body.capacity()));
  }
}
