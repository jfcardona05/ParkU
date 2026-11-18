package com.parku;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.util.HexFormat;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VehicleQrService {
  private final JdbcTemplate db;
  private final IdentityService identity;
  private final DailyPassService daily;
  private final Clock clock;

  public VehicleQrService(
      JdbcTemplate db, IdentityService identity, DailyPassService daily, Clock clock) {
    this.db = db;
    this.identity = identity;
    this.daily = daily;
    this.clock = clock;
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

  public Map<String, Object> issue(String auth, long vehicleId) {
    return daily.issue(auth, vehicleId);
  }

  public static String tokenValue(String value) {
    if (value != null && (value.startsWith("https://") || value.startsWith("http://"))) {
      try {
        var uri = java.net.URI.create(value);
        if (uri.getPath().matches("/(?:[a-f0-9]{32}/)?p/[A-Za-z0-9_-]{43}")
            && uri.getRawQuery() == null
            && uri.getFragment() == null)
          return uri.getPath().substring(uri.getPath().lastIndexOf('/') + 1);
      } catch (IllegalArgumentException ignored) {
        // Reject malformed URLs through the same invalid-token response.
      }
      throw new ApiProblem(422, "QR_INVALID", "El enlace QR no es válido.");
    }
    return value;
  }

  // Caller must lock the vehicle before calling this method during confirmation.
  public Map<String, Object> inspectToken(String token) {
    token = tokenValue(token);
    var rows =
        db.queryForList(
            "SELECT q.*,v.plate,v.type AS vehicle_type,u.name AS owner_name FROM vehicle_qr q JOIN vehicles v ON v.id=q.vehicle_id AND v.user_id=q.user_id JOIN users u ON u.id=q.user_id WHERE q.token_hash=?",
            digest(token));
    if (rows.isEmpty()) throw new ApiProblem(422, "QR_INVALID", "QR inválido");
    var qr = rows.getFirst();
    if (Boolean.TRUE.equals(qr.get("consumed")))
      throw new ApiProblem(409, "QR_USED", "Este QR ya fue utilizado");
    if (Boolean.TRUE.equals(qr.get("revoked")))
      throw new ApiProblem(409, "QR_REVOKED", "QR reemplazado. Solicita uno nuevo");
    var expiry = ((java.sql.Timestamp) qr.get("expires_at")).toInstant();
    if (!clock.instant().isBefore(expiry))
      throw new ApiProblem(410, "QR_EXPIRED", "QR vencido. Solicita uno nuevo");
    return qr;
  }

  @Transactional(readOnly = true)
  public Map<String, Object> inspect(String auth, String token) {
    identity.requireRole(auth, "guard", "admin");
    var qr = inspectToken(token);
    boolean inside =
        !db.queryForList(
                "SELECT id FROM parking_visits WHERE vehicle_id=? AND exited_at IS NULL",
                qr.get("vehicle_id"))
            .isEmpty();
    return Map.of(
        "success",
        true,
        "vehicle_id",
        qr.get("vehicle_id"),
        "plate",
        qr.get("plate"),
        "expires_at",
        ((java.sql.Timestamp) qr.get("expires_at")).toInstant(),
        "parking_state",
        inside ? "INSIDE" : "OUTSIDE",
        "allowed_action",
        inside ? "exit" : "entry");
  }
}
