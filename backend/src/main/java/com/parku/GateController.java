package com.parku;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/gate")
public class GateController {
  private final GateService gate;

  public GateController(GateService gate) {
    this.gate = gate;
  }

  public record Operation(
      @NotBlank @Size(max = 512) String token,
      @NotBlank @Pattern(regexp = "entry|exit") String action,
      @NotBlank @Size(max = 100) String request_id) {}

  @PostMapping("/operations")
  public ResponseEntity<?> confirm(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @Valid @RequestBody Operation body) {
    var result = gate.confirm(auth, body.token(), body.action(), body.request_id());
    return ResponseEntity.status(result.replayed() ? 200 : 201).body(result.receipt());
  }
}
