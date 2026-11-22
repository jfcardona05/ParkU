package com.parku;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class IdentityService {
  private final JdbcTemplate db;
  private final BCryptPasswordEncoder passwords = new BCryptPasswordEncoder();
  private final SecureRandom random = new SecureRandom();
  private final String dummyHash = passwords.encode("invalid-account-placeholder");

  public IdentityService(JdbcTemplate db) {
    this.db = db;
  }

  @Transactional
  public Map<String, Object> register(
      String name, String email, String password, String documentType, String documentNumber) {
    long id =
        db.queryForObject(
            "INSERT INTO users(name,email,password_hash,role,document_type,document_number) VALUES"
                + " (?,?,?,'estudiante',?,?) RETURNING id",
            Long.class,
            name.trim(),
            email.trim().toLowerCase(Locale.ROOT),
            passwords.encode(password),
            documentType,
            documentNumber);
    return session(id);
  }

  @Transactional
  public Map<String, Object> login(String email, String password) {
    var rows =
        db.queryForList(
            "SELECT id,password_hash FROM users WHERE email=?",
            email.trim().toLowerCase(Locale.ROOT));
    String hash = rows.isEmpty() ? dummyHash : (String) rows.getFirst().get("password_hash");
    boolean matches = passwords.matches(password, hash);
    if (rows.isEmpty() || !matches)
      throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Credenciales inválidas");
    return session(((Number) rows.getFirst().get("id")).longValue());
  }

  private Map<String, Object> session(long id) {
    byte[] bytes = new byte[32];
    random.nextBytes(bytes);
    String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    db.update(
        "INSERT INTO sessions(token_hash,user_id,expires_at) VALUES (?,?,?)",
        digest(token),
        id,
        OffsetDateTime.now().plusHours(8));
    return Map.of("success", true, "token", token, "user", user(id), "message", "Sesión iniciada");
  }

  public Map<String, Object> current(String authorization) {
    if (authorization == null || !authorization.startsWith("Bearer ")) throw unauthorized();
    List<Map<String, Object>> rows =
        db.queryForList(
            "SELECT u.id,u.name,u.email,u.role,u.balance,u.document_type,u.document_number FROM"
                + " users u JOIN sessions s ON s.user_id=u.id WHERE s.token_hash=? AND"
                + " s.expires_at>CURRENT_TIMESTAMP",
            digest(authorization.substring(7)));
    if (rows.isEmpty()) throw unauthorized();
    return rows.getFirst();
  }

  public Map<String, Object> operator(String authorization) {
    var user = current(authorization);
    if (!"operador".equals(user.get("role")))
      throw new ResponseStatusException(
          HttpStatus.FORBIDDEN, "Solo taquilla puede registrar recargas");
    return user;
  }

  public Map<String, Object> requireRole(String authorization, String... roles) {
    var user = current(authorization);
    if (!java.util.Arrays.asList(roles).contains(user.get("role")))
      throw new ApiProblem(403, "FORBIDDEN", "No tienes permiso para esta operación");
    return user;
  }

  public Map<String, Object> user(long id) {
    var rows =
        db.queryForList(
            "SELECT id,name,email,role,balance,document_type,document_number FROM users WHERE id=?",
            id);
    if (rows.isEmpty())
      throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado");
    return rows.getFirst();
  }

  @Transactional
  public Map<String, Object> updateProfile(String auth, IdentityController.Profile body) {
    var current = requireRole(auth, "estudiante", "docente", "guard", "admin");
    var locked = db.queryForMap("SELECT * FROM users WHERE id=? FOR UPDATE", current.get("id"));
    if (!passwords.matches(body.current_password(), (String) locked.get("password_hash")))
      throw new ApiProblem(403, "WRONG_PASSWORD", "La contraseña actual no es correcta.");
    if (body.name().trim().isEmpty())
      throw new ApiProblem(400, "INVALID_NAME", "Escribe tu nombre.");
    String email = body.email().trim().toLowerCase(Locale.ROOT);
    boolean credentialsChanged = !email.equals(locked.get("email")) || body.new_password() != null;
    db.update(
        "UPDATE users SET name=?,email=?,document_type=?,document_number=?,password_hash=? WHERE"
            + " id=?",
        body.name().trim(),
        email,
        body.document_type(),
        body.document_number(),
        body.new_password() == null
            ? locked.get("password_hash")
            : passwords.encode(body.new_password()),
        current.get("id"));
    if (credentialsChanged)
      db.update(
          "DELETE FROM sessions WHERE user_id=? AND token_hash<>?",
          current.get("id"),
          digest(auth.substring(7)));
    return Map.of(
        "success",
        true,
        "user",
        user(((Number) current.get("id")).longValue()),
        "message",
        "Datos actualizados");
  }

  public void logout(String authorization) {
    current(authorization);
    db.update("DELETE FROM sessions WHERE token_hash=?", digest(authorization.substring(7)));
  }

  private ResponseStatusException unauthorized() {
    return new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sesión requerida o vencida");
  }

  private String digest(String value) {
    try {
      return HexFormat.of()
          .formatHex(
              MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
    } catch (java.security.NoSuchAlgorithmException e) {
      throw new IllegalStateException(e);
    }
  }
}
