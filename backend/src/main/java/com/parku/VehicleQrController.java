package com.parku;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class VehicleQrController {
  private final VehicleQrService qr;
  private final DailyPassService daily;

  public VehicleQrController(VehicleQrService qr, DailyPassService daily) {
    this.qr = qr;
    this.daily = daily;
  }

  public record IssueRequest(
      @jakarta.validation.constraints.Positive Long expected_amount,
      @jakarta.validation.constraints.Pattern(regexp = "[0-9]{4}-[0-9]{2}-[0-9]{2}")
          String service_date) {}

  public record Token(@NotBlank @Size(max = 512) String token) {}

  @GetMapping("/vehicles/{id}/qr")
  public ResponseEntity<?> quote(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @PathVariable long id) {
    return ResponseEntity.ok().header("Cache-Control", "no-store").body(daily.quote(auth, id));
  }

  @PostMapping("/vehicles/{id}/qr")
  public ResponseEntity<?> issue(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @PathVariable long id,
      @Valid @RequestBody(required = false) IssueRequest body) {
    return ResponseEntity.status(201)
        .header("Cache-Control", "no-store")
        .body(
            daily.issue(
                auth,
                id,
                body == null ? null : body.expected_amount(),
                body == null ? null : body.service_date()));
  }

  @PostMapping("/gate/inspect")
  public ResponseEntity<?> inspect(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @Valid @RequestBody Token token) {
    return ResponseEntity.ok()
        .header("Cache-Control", "no-store")
        .body(qr.inspect(auth, token.token()));
  }
}
