package com.parku;

import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/cash")
public class CashController {
  private final CashService cash;

  public CashController(CashService cash) {
    this.cash = cash;
  }

  public record Open(
      @NotBlank String point_name,
      @NotNull @Min(0) @Max(1000000000000L) @JsonDeserialize(using = WholeCopAmount.class)
          Long opening_amount) {}

  public record Close(
      @NotNull @Min(0) @Max(1000000000000L) @JsonDeserialize(using = WholeCopAmount.class)
          Long counted_cash,
      @NotNull @Min(1) @Max(1000000000000L) @JsonDeserialize(using = WholeCopAmount.class)
          Long retained_cash,
      @Size(max = 1000) String notes) {}

  @ModelAttribute
  public void noCache(jakarta.servlet.http.HttpServletResponse response) {
    response.setHeader("Cache-Control", "no-store");
  }

  @GetMapping("/current")
  public Map<String, Object> current(
      @RequestHeader(value = "Authorization", required = false) String auth) {
    return cash.current(auth);
  }

  @PostMapping("/open")
  public Map<String, Object> open(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @Valid @RequestBody Open body) {
    return Map.of(
        "success", true, "session", cash.open(auth, body.point_name(), body.opening_amount()));
  }

  @PostMapping("/{id}/close")
  public Map<String, Object> close(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @PathVariable long id,
      @Valid @RequestBody Close body) {
    return Map.of(
        "success",
        true,
        "session",
        cash.close(auth, id, body.counted_cash(), body.retained_cash(), body.notes()));
  }

  @GetMapping("/history")
  public Map<String, Object> history(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @RequestParam(required = false) String date,
      @RequestParam(defaultValue = "0") int page) {
    return cash.history(auth, date, page);
  }
}
