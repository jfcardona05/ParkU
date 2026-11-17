package com.parku;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DailyPassService {
  static final ZoneId ZONE = ZoneId.of("America/Bogota");
  private final JdbcTemplate db;
  private final IdentityService identity;
  private final Clock clock;
  private final SecureRandom random = new SecureRandom();

  public DailyPassService(JdbcTemplate db, IdentityService identity, Clock clock) {
    this.db = db;
    this.identity = identity;
    this.clock = clock;
  }

  private Map<String, Object> vehicle(long id, Object userId, boolean lock) {
    var rows = db.queryForList(
        "SELECT * FROM vehicles WHERE id=? AND user_id=?" + (lock ? " FOR UPDATE" : ""), id, userId);
    if (rows.isEmpty()) throw new ApiProblem(404, "VEHICLE_NOT_FOUND", "Vehículo no encontrado");
    return rows.getFirst();
  }

  private Map<String, Object> existing(Object userId, LocalDate day) {
    var rows = db.queryForList(
        "SELECT * FROM parking_day_passes WHERE user_id=? AND service_date=?", userId, day);
    return rows.isEmpty() ? null : rows.getFirst();
  }

  private Map<String, Object> view(Map<String, Object> pass, long vehicleId, long balance, boolean charged) {
    if (pass.get("vehicle_id") == null || ((Number) pass.get("vehicle_id")).longValue() != vehicleId) {
      throw new ApiProblem(409, "DAILY_VEHICLE_LOCKED",
          "Tu QR de hoy ya está vinculado a " + pass.get("plate") + ". Solo puedes elegir otro vehículo mañana.");
    }
    var qr = db.queryForList("SELECT id FROM vehicle_qr WHERE id=? AND NOT revoked AND NOT consumed", pass.get("qr_id"));
    if (qr.isEmpty()) throw new ApiProblem(409, "DAILY_PASS_UNAVAILABLE", "Tu pase de hoy no está disponible. Consulta con portería; no se cobrará otro pase.");
    var result = new LinkedHashMap<String, Object>();
    result.put("success", true);
    result.put("daily", true);
    result.put("issued", true);
    result.put("vehicle_id", vehicleId);
    result.put("token", pass.get("token"));
    result.put("service_date", pass.get("service_date").toString());
    result.put("expires_at", ((java.sql.Timestamp) pass.get("expires_at")).toInstant());
    result.put("amount", pass.get("amount"));
    result.put("currency", "COP");
    result.put("charged", charged);
    result.put("charge_amount", charged ? pass.get("amount") : 0);
    result.put("balance_after", balance);
    result.put("transaction_id", pass.get("transaction_id"));
    return result;
  }

  @Transactional(readOnly = true)
  public Map<String, Object> quote(String auth, long vehicleId) {
    var user = identity.current(auth);
    var vehicle = vehicle(vehicleId, user.get("id"), false);
    var day = LocalDate.now(clock.withZone(ZONE));
    var pass = existing(user.get("id"), day);
    if (pass != null) return view(pass, vehicleId, ((Number) user.get("balance")).longValue(), false);
    var rate = rate(vehicle.get("type"));
    return Map.of("success", true, "daily", true, "issued", false, "vehicle_id", vehicleId,
        "amount", rate.get("amount"), "currency", "COP", "service_date", day.toString(),
        "expires_at", day.plusDays(1).atStartOfDay(ZONE).toInstant());
  }

  private Map<String, Object> rate(Object type) {
    var rates = db.queryForList(
        "SELECT id,amount FROM parking_rates WHERE vehicle_type=? ORDER BY id DESC LIMIT 1", type);
    if (rates.isEmpty()) throw new ApiProblem(503, "PARKING_NOT_CONFIGURED", "Tarifa no configurada");
    return rates.getFirst();
  }

  @Transactional
  public Map<String, Object> issue(String auth, long vehicleId) {
    var user = identity.current(auth);
    // Wallet first, vehicle second: shared ordering with gate and transfer operations.
    var wallet = db.queryForMap("SELECT balance FROM users WHERE id=? FOR UPDATE", user.get("id"));
    var vehicle = vehicle(vehicleId, user.get("id"), true);
    // Compute the Colombian service date after waiting for locks, including midnight crossings.
    var day = LocalDate.now(clock.withZone(ZONE));
    long before = ((Number) wallet.get("balance")).longValue();
    var pass = existing(user.get("id"), day);
    if (pass != null) return view(pass, vehicleId, before, false);
    var active = db.queryForList("SELECT id,daily_pass_id FROM parking_visits WHERE vehicle_id=? AND exited_at IS NULL", vehicleId);
    if (!active.isEmpty() && active.getFirst().get("daily_pass_id") == null) {
      throw new ApiProblem(409, "LEGACY_VISIT_ACTIVE", "Finaliza tu estancia anterior en portería antes de generar el pase diario.");
    }
    var rate = rate(vehicle.get("type"));
    long amount = ((Number) rate.get("amount")).longValue();
    if (before < amount) throw new ApiProblem(409, "INSUFFICIENT_BALANCE", "Saldo insuficiente para generar el QR diario.");
    long after = before - amount;
    var expiry = day.plusDays(1).atStartOfDay(ZONE).toInstant();
    byte[] bytes = new byte[32];
    random.nextBytes(bytes);
    String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    db.update("UPDATE users SET balance=? WHERE id=?", after, user.get("id"));
    long movement = db.queryForObject(
        "INSERT INTO transactions(user_id,operator_id,type,amount,point_name,reference,balance_after,parking_rate_label) VALUES(?,?,'COBRO_ESTACIONAMIENTO',?,'QR diario',?,?,?) RETURNING id",
        Long.class, user.get("id"), user.get("id"), amount, UUID.randomUUID(), after,
        amount + " COP / pase diario · " + ("moto".equals(vehicle.get("type")) ? "Moto" : "Automóvil"));
    long qrId = db.queryForObject(
        "INSERT INTO vehicle_qr(token_hash,vehicle_id,user_id,expires_at) VALUES(?,?,?,?) RETURNING id",
        Long.class, VehicleQrService.digest(token), vehicleId, user.get("id"), java.sql.Timestamp.from(expiry));
    pass = db.queryForMap(
        "INSERT INTO parking_day_passes(user_id,vehicle_id,plate,vehicle_type,service_date,qr_id,token,rate_id,amount,transaction_id,expires_at) VALUES(?,?,?,?,?,?,?,?,?,?,?) RETURNING *",
        user.get("id"), vehicleId, vehicle.get("plate"), vehicle.get("type"), day, qrId, token,
        rate.get("id"), amount, movement, java.sql.Timestamp.from(expiry));
    return view(pass, vehicleId, after, true);
  }
}
