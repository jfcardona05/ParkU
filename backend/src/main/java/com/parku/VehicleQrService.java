package com.parku;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VehicleQrService {
  private final JdbcTemplate db;
  private final IdentityService identity;
  private final SecureRandom random = new SecureRandom();

  public VehicleQrService(JdbcTemplate db, IdentityService identity) {
    this.db = db;
    this.identity = identity;
  }

  public static String digest(String token) {
    try {
      return HexFormat.of()
          .formatHex(
              MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
    } catch (java.security.NoSuchAlgorithmException e) {
      throw new IllegalStateException(e);
    }
  }

  @Transactional
  public Map<String, Object> issue(String auth, long vehicleId) {
    var user = identity.current(auth);
    var vehicles =
        db.queryForList(
            "SELECT id FROM vehicles WHERE id=? AND user_id=? FOR UPDATE",
            vehicleId,
            user.get("id"));
    if (vehicles.isEmpty())
      throw new ApiProblem(404, "VEHICLE_NOT_FOUND", "Vehículo no encontrado");
    db.update("UPDATE vehicle_qr SET revoked=true WHERE vehicle_id=? AND NOT consumed", vehicleId);
    byte[] bytes = new byte[32];
    random.nextBytes(bytes);
    String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    var expiresAt = OffsetDateTime.now(java.time.ZoneOffset.UTC).plusSeconds(120);
    db.update(
        "INSERT INTO vehicle_qr(token_hash,vehicle_id,user_id,expires_at) VALUES (?,?,?,?)",
        digest(token),
        vehicleId,
        user.get("id"),
        expiresAt);
    return Map.of(
        "success", true, "vehicle_id", vehicleId, "token", token, "expires_at", expiresAt);
  }

  // Caller must lock the vehicle before calling this method during confirmation.
  public Map<String, Object> inspectToken(String token) {
    var rows =
        db.queryForList(
            "SELECT q.*,v.plate FROM vehicle_qr q JOIN vehicles v ON v.id=q.vehicle_id AND v.user_id=q.user_id WHERE q.token_hash=?",
            digest(token));
    if (rows.isEmpty()) throw new ApiProblem(422, "QR_INVALID", "QR inválido");
    var qr = rows.getFirst();
    if (Boolean.TRUE.equals(qr.get("consumed")))
      throw new ApiProblem(409, "QR_USED", "Este QR ya fue utilizado");
    if (Boolean.TRUE.equals(qr.get("revoked")))
      throw new ApiProblem(409, "QR_REVOKED", "QR reemplazado. Solicita uno nuevo");
    var expiry = ((java.sql.Timestamp) qr.get("expires_at")).toInstant();
    if (!java.time.Instant.now().isBefore(expiry))
      throw new ApiProblem(410, "QR_EXPIRED", "QR vencido. Solicita uno nuevo");
    return qr;
  }

  @Transactional(readOnly = true)
  public Map<String, Object> inspect(String auth, String token) {
    identity.requireRole(auth, "guard", "admin");
    var qr = inspectToken(token);
    return Map.of(
        "success",
        true,
        "vehicle_id",
        qr.get("vehicle_id"),
        "plate",
        qr.get("plate"),
        "expires_at",
        ((java.sql.Timestamp) qr.get("expires_at")).toInstant());
  }
}
