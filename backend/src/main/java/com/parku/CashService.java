package com.parku;

import java.time.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CashService {
  public static final List<String> POINTS =
      List.of("Punto 1 - Portería Principal USTA", "Punto 2 - Cafetería Central USTA");
  private static final ZoneId ZONE = ZoneId.of("America/Bogota");
  private final JdbcTemplate db;
  private final IdentityService identity;
  private final Clock clock;

  public CashService(JdbcTemplate db, IdentityService identity, Clock clock) {
    this.db = db;
    this.identity = identity;
    this.clock = clock;
  }

  private LocalDate today() {
    return LocalDate.now(clock.withZone(ZONE));
  }

  private void checkPoint(String point) {
    if (!POINTS.contains(point))
      throw new ApiProblem(400, "INVALID_POINT", "Selecciona un punto de atención válido.");
  }

  private long number(Map<String, Object> row, String key) {
    return ((Number) row.get(key)).longValue();
  }

  private Map<String, Object> totals(long id) {
    return db.queryForMap(
        "SELECT COALESCE(SUM(amount),0)::bigint AS collected,COUNT(*) AS count FROM transactions WHERE cash_session_id=? AND type='RECARGA_PRESENCIAL'",
        id);
  }

  private Map<String, Object> view(Map<String, Object> row) {
    var result = new LinkedHashMap<>(row);
    if ("OPEN".equals(row.get("status"))) {
      var total = totals(number(row, "id"));
      result.put("recharge_total", total.get("collected"));
      result.put("recharge_count", total.get("count"));
      result.put("expected_cash", number(row, "opening_amount") + number(total, "collected"));
    }
    result.put(
        "can_recharge",
        "OPEN".equals(row.get("status"))
            && row.get("business_date").toString().equals(today().toString()));
    return result;
  }

  @Transactional(readOnly = true)
  public Map<String, Object> current(String auth) {
    var user = identity.operator(auth);
    var active =
        db.queryForList(
            "SELECT * FROM cash_sessions WHERE operator_id=? AND status='OPEN'", user.get("id"));
    var points = new ArrayList<Map<String, Object>>();
    for (var point : POINTS) {
      var last =
          db.queryForList(
              "SELECT * FROM cash_sessions WHERE point_name=? ORDER BY business_date DESC,id DESC LIMIT 1",
              point);
      var info = new LinkedHashMap<String, Object>();
      info.put("point_name", point);
      info.put("opening_amount", last.isEmpty() ? 0 : last.getFirst().get("retained_cash"));
      info.put("carried", !last.isEmpty());
      info.put(
          "available",
          last.isEmpty()
              || ("CLOSED".equals(last.getFirst().get("status"))
                  && LocalDate.parse(last.getFirst().get("business_date").toString())
                      .isBefore(today())));
      points.add(info);
    }
    var result = new LinkedHashMap<String, Object>();
    result.put("success", true);
    result.put("business_date", today().toString());
    result.put("points", points);
    result.put("session", active.isEmpty() ? null : view(active.getFirst()));
    return result;
  }

  @Transactional
  public Map<String, Object> open(String auth, String point, long base) {
    var user = identity.operator(auth);
    checkPoint(point);
    db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE", Long.class, user.get("id"));
    db.queryForList("SELECT pg_advisory_xact_lock(hashtext(?))", "parku-cash:" + point);
    var active =
        db.queryForList(
            "SELECT * FROM cash_sessions WHERE operator_id=? AND status='OPEN'", user.get("id"));
    if (!active.isEmpty()) {
      var row = active.getFirst();
      if (point.equals(row.get("point_name"))
          && number(row, "opening_amount") == base
          && row.get("business_date").toString().equals(today().toString())) return view(row);
      throw new ApiProblem(
          409, "CASH_ALREADY_OPEN", "Ya tienes una caja abierta. Ciérrala antes de abrir otra.");
    }
    var last =
        db.queryForList(
            "SELECT * FROM cash_sessions WHERE point_name=? ORDER BY business_date DESC,id DESC LIMIT 1",
            point);
    Long previous = null;
    if (!last.isEmpty()) {
      var row = last.getFirst();
      if ("OPEN".equals(row.get("status")))
        throw new ApiProblem(
            409, "POINT_BUSY", "Este punto tiene una caja abierta por otro operador.");
      if (!LocalDate.parse(row.get("business_date").toString()).isBefore(today()))
        throw new ApiProblem(
            409,
            "DAY_CLOSED",
            "Este punto ya fue cerrado hoy. La siguiente apertura corresponde al día siguiente.");
      if (base != number(row, "retained_cash"))
        throw new ApiProblem(
            409,
            "BASE_CHANGED",
            "La base debe coincidir con el efectivo retenido en el último cierre. Actualiza el panel.");
      previous = number(row, "id");
    }
    var row =
        db.queryForMap(
            "INSERT INTO cash_sessions(operator_id,point_name,business_date,opening_amount,previous_session_id,reference,opened_at) VALUES(?,?,?,?,?,?,?) RETURNING *",
            user.get("id"),
            point,
            today(),
            base,
            previous,
            UUID.randomUUID(),
            OffsetDateTime.now(clock));
    return view(row);
  }

  /** Must be called inside the recharge transaction. Closing locks this same row. */
  public long lockForRecharge(long operator, String point, long amount) {
    var rows =
        db.queryForList(
            "SELECT * FROM cash_sessions WHERE operator_id=? AND point_name=? AND status='OPEN' FOR UPDATE",
            operator,
            point);
    if (rows.isEmpty())
      throw new ApiProblem(
          409, "CASH_NOT_OPEN", "Abre la caja de este punto antes de registrar recargas.");
    var row = rows.getFirst();
    if (!row.get("business_date").toString().equals(today().toString()))
      throw new ApiProblem(
          409,
          "CASH_DAY_ENDED",
          "Cierra la caja del día anterior y abre la de hoy antes de recargar.");
    if (number(row, "opening_amount") + number(totals(number(row, "id")), "collected") + amount
        > 1000000000000L)
      throw new ApiProblem(409, "CASH_LIMIT", "El efectivo de caja supera el límite permitido.");
    return number(row, "id");
  }

  @Transactional
  public Map<String, Object> close(
      String auth, long id, long counted, long retained, String notes) {
    var user = identity.operator(auth);
    var rows =
        db.queryForList(
            "SELECT * FROM cash_sessions WHERE id=? AND operator_id=? FOR UPDATE",
            id,
            user.get("id"));
    if (rows.isEmpty()) throw new ApiProblem(404, "CASH_NOT_FOUND", "Caja no encontrada.");
    var row = rows.getFirst();
    String clean = notes == null ? "" : notes.trim();
    if ("CLOSED".equals(row.get("status"))) {
      if (number(row, "counted_cash") == counted
          && number(row, "retained_cash") == retained
          && Objects.equals(row.get("notes"), clean)) return view(row);
      throw new ApiProblem(
          409, "CASH_CLOSED", "El cierre ya está registrado y no puede modificarse.");
    }
    if (retained > counted)
      throw new ApiProblem(
          400, "INVALID_RETAINED", "La base para devueltas no puede superar el efectivo contado.");
    var total = totals(id);
    long collected = number(total, "collected"),
        expected = number(row, "opening_amount") + collected;
    if (counted != expected && clean.isEmpty())
      throw new ApiProblem(
          400, "DIFFERENCE_REASON", "Explica el faltante o sobrante antes de cerrar.");
    row =
        db.queryForMap(
            "UPDATE cash_sessions SET status='CLOSED',closed_at=?,recharge_total=?,recharge_count=?,expected_cash=?,counted_cash=?,retained_cash=?,remitted_cash=?,difference=?,notes=? WHERE id=? RETURNING *",
            OffsetDateTime.now(clock),
            collected,
            total.get("count"),
            expected,
            counted,
            retained,
            counted - retained,
            counted - expected,
            clean,
            id);
    return view(row);
  }

  @Transactional(readOnly = true)
  public Map<String, Object> history(String auth, String date, int page) {
    identity.operator(auth);
    if (page < 0 || page > 1000000) throw new ApiProblem(400, "INVALID_PAGE", "Página inválida.");
    if (date != null) {
      try {
        LocalDate.parse(date);
      } catch (DateTimeException ex) {
        throw new ApiProblem(400, "INVALID_DATE", "Fecha inválida.");
      }
    }
    var rows =
        db.queryForList(
            "SELECT c.*,u.name AS operator_name FROM cash_sessions c JOIN users u ON u.id=c.operator_id WHERE c.status='CLOSED' AND (?::date IS NULL OR c.business_date=?::date) ORDER BY c.business_date DESC,c.id DESC LIMIT 21 OFFSET ?",
            date,
            date,
            page * 20L);
    boolean more = rows.size() > 20;
    return Map.of("success", true, "sessions", rows.stream().limit(20).toList(), "has_more", more);
  }
}
