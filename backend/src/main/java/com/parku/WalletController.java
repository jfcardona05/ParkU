package com.parku;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api")
public class WalletController {
  private final JdbcTemplate db;
  private final IdentityService identity;

  public WalletController(JdbcTemplate db, IdentityService identity) {
    this.db = db;
    this.identity = identity;
  }

  public record Recharge(
      @NotNull @Positive Long amount,
      @NotBlank @Size(max = 120) String point_name,
      @NotNull @Positive Long user_id) {}

  @GetMapping("/wallet/balance")
  public Map<String, Object> balance(
      @RequestHeader(value = "Authorization", required = false) String auth) {
    return Map.of("success", true, "balance", identity.current(auth).get("balance"));
  }

  @GetMapping("/wallet/history")
  public Map<String, Object> history(
      @RequestHeader(value = "Authorization", required = false) String auth) {
    var user = identity.current(auth);
    return Map.of(
        "success",
        true,
        "transactions",
        db.queryForList(
            "SELECT id,type,amount,point_name,reference,balance_after,created_at FROM transactions WHERE user_id=? ORDER BY id DESC",
            user.get("id")));
  }

  @GetMapping("/admin/users")
  public Map<String, Object> users(
      @RequestHeader(value = "Authorization", required = false) String auth) {
    identity.operator(auth);
    return Map.of(
        "success",
        true,
        "users",
        db.queryForList(
            "SELECT id,name,email,role,balance FROM users WHERE role<>'operador' ORDER BY name"));
  }

  @PostMapping("/wallet/recharge")
  @Transactional
  public Map<String, Object> recharge(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @Valid @RequestBody Recharge body) {
    var operator = identity.operator(auth);
    if (!body.point_name().equals("Punto 1 - Portería Principal USTA")
        && !body.point_name().equals("Punto 2 - Cafetería Central USTA"))
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Punto físico inválido");
    var balances =
        db.queryForList(
            "SELECT balance FROM users WHERE id=? AND role<>'operador' FOR UPDATE", body.user_id());
    if (balances.isEmpty())
      throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado");
    long before = ((Number) balances.getFirst().get("balance")).longValue();
    long after;
    try {
      after = Math.addExact(before, body.amount());
    } catch (ArithmeticException ex) {
      throw new ResponseStatusException(
          HttpStatus.BAD_REQUEST, "El importe supera el saldo permitido");
    }
    db.update("UPDATE users SET balance=? WHERE id=?", after, body.user_id());
    var receipt =
        db.queryForMap(
            "INSERT INTO transactions(user_id,operator_id,type,amount,point_name,reference,balance_after) VALUES (?,?,'RECARGA_PRESENCIAL',?,?,?,?) RETURNING id,type,amount,point_name,reference,balance_after,created_at",
            body.user_id(),
            operator.get("id"),
            body.amount(),
            body.point_name(),
            UUID.randomUUID(),
            after);
    return Map.of("success", true, "message", "Recarga registrada", "recharge", receipt);
  }
}
