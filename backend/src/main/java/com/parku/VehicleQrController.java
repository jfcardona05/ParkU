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

  public VehicleQrController(VehicleQrService qr) {
    this.qr = qr;
  }

  public record Token(@NotBlank @Size(max = 512) String token) {}

  @PostMapping("/vehicles/{id}/qr")
  public ResponseEntity<?> issue(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @PathVariable long id) {
    return ResponseEntity.status(201).header("Cache-Control", "no-store").body(qr.issue(auth, id));
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
