package com.parku;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.Locale;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/vehicles")
public class VehicleController {
  private final JdbcTemplate db;
  private final IdentityService identity;

  public VehicleController(JdbcTemplate db, IdentityService identity) {
    this.db = db;
    this.identity = identity;
  }

  public record Vehicle(
      @NotBlank @Pattern(regexp = "[A-Za-z0-9-]{5,12}") String plate,
      @NotBlank @Pattern(regexp = "moto|automovil") String type,
      @Size(max = 120) String brand_model) {}

  @GetMapping
  public Map<String, Object> list(
      @RequestHeader(value = "Authorization", required = false) String auth) {
    var user = identity.current(auth);
    return Map.of(
        "success",
        true,
        "vehicles",
        db.queryForList(
            "SELECT id,plate,type,brand_model,created_at FROM vehicles WHERE user_id=? ORDER BY id DESC",
            user.get("id")));
  }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  public Map<String, Object> add(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @Valid @RequestBody Vehicle body) {
    var user = identity.current(auth);
    var vehicle =
        db.queryForMap(
            "INSERT INTO vehicles(user_id,plate,type,brand_model) VALUES (?,?,?,?) RETURNING id,plate,type,brand_model,created_at",
            user.get("id"),
            body.plate().toUpperCase(Locale.ROOT),
            body.type(),
            body.brand_model() == null ? "" : body.brand_model());
    return Map.of("success", true, "vehicle", vehicle, "message", "Vehículo registrado");
  }

  @DeleteMapping("/{id}")
  public Map<String, Object> delete(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @PathVariable long id) {
    var user = identity.current(auth);
    if (db.update("DELETE FROM vehicles WHERE id=? AND user_id=?", id, user.get("id")) == 0)
      throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Vehículo no encontrado");
    return Map.of("success", true);
  }
}
