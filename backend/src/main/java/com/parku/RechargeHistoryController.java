package com.parku;

import java.time.*;
import java.time.temporal.TemporalAdjusters;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/admin/recharges")
public class RechargeHistoryController {
  private static final ZoneId COLOMBIA = ZoneId.of("America/Bogota");
  private final JdbcTemplate db;
  private final IdentityService identity;
  private final Clock clock;

  public RechargeHistoryController(JdbcTemplate db, IdentityService identity, Clock clock) {
    this.db = db;
    this.identity = identity;
    this.clock = clock;
  }

  @GetMapping
  @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
  public Map<String, Object> history(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @RequestParam(defaultValue = "day") String period,
      @RequestParam(required = false) String date,
      @RequestParam(defaultValue = "") String search,
      @RequestParam(defaultValue = "0") int page) {
    identity.operator(auth);
    LocalDate selected;
    try {
      selected = date == null ? LocalDate.now(clock.withZone(COLOMBIA)) : LocalDate.parse(date);
      if (selected.getYear() < 1900 || selected.getYear() > 2100)
        throw new DateTimeException("year");
    } catch (DateTimeException ex) {
      throw new ApiProblem(400, "INVALID_DATE", "Selecciona una fecha válida");
    }
    if (page < 0 || page > 1000000 || search.length() > 200)
      throw new ApiProblem(400, "INVALID_FILTER", "Revisa los filtros del historial");
    LocalDate from =
        switch (period) {
          case "day" -> selected;
          case "week" -> selected.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
          case "month" -> selected.withDayOfMonth(1);
          default -> throw new ApiProblem(400, "INVALID_PERIOD", "Elige día, semana o mes");
        };
    LocalDate until =
        switch (period) {
          case "week" -> from.plusWeeks(1);
          case "month" -> from.plusMonths(1);
          default -> from.plusDays(1);
        };
    String term = search.trim().toLowerCase(Locale.ROOT);
    String filter =
        " FROM cash_income t LEFT JOIN users o ON o.id=t.operator_id WHERE t.created_at>=? AND"
            + " t.created_at<? AND (?='' OR strpos(lower(t.user_name||' '||t.user_email||'"
            + " '||t.document||' '||t.plate),?)>0)";
    Object[] args = {
      from.atStartOfDay(COLOMBIA).toOffsetDateTime(),
      until.atStartOfDay(COLOMBIA).toOffsetDateTime(),
      term,
      term
    };
    var summary =
        db.queryForMap(
            "SELECT COUNT(*) AS count,COALESCE(SUM(t.amount),0) AS total_amount,COUNT(DISTINCT"
                + " t.recipient_key) AS user_count"
                + filter,
            args);
    var rowsArgs = new ArrayList<Object>(Arrays.asList(args));
    rowsArgs.add(page * 50L);
    var rows =
        db.queryForList(
            "SELECT"
                + " t.id,t.amount,t.created_at,t.point_name,t.reference,t.user_id,t.user_name,t.user_email,t.income_type,t.document,t.plate,t.visitor_pass_id,COALESCE(o.name,'Operador"
                + " no disponible') AS operator_name"
                + filter
                + " ORDER BY t.created_at DESC,t.income_type,t.id DESC LIMIT 50 OFFSET ?",
            rowsArgs.toArray());
    long count = ((Number) summary.get("count")).longValue();
    return Map.of(
        "success",
        true,
        "period",
        period,
        "date",
        selected.toString(),
        "from",
        from.toString(),
        "through",
        until.minusDays(1).toString(),
        "timezone",
        COLOMBIA.toString(),
        "summary",
        summary,
        "recharges",
        rows,
        "page",
        page,
        "has_more",
        (page + 1L) * 50 < count);
  }
}
