package com.parku;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/admin/visitor-passes")
public class VisitorPassController {
  private final VisitorPassService visitors;

  public VisitorPassController(VisitorPassService visitors) {
    this.visitors = visitors;
  }

  public record Sale(
      @NotBlank @Size(max = 120) String visitor_name,
      @NotBlank @Pattern(regexp = "[A-Za-z0-9]{5,10}") String plate,
      @NotBlank @Pattern(regexp = "moto|automovil") String vehicle_type,
      @NotBlank @Size(max = 120) String point_name,
      @NotNull
          @Positive
          @Max(1000000000)
          @com.fasterxml.jackson.databind.annotation.JsonDeserialize(using = WholeCopAmount.class)
          Long expected_amount,
      @NotBlank @Pattern(regexp = "[0-9]{4}-[0-9]{2}-[0-9]{2}") String service_date,
      @NotBlank @Size(max = 100) String request_id) {}

  @GetMapping("/quote")
  public Map<String, Object> quote(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @RequestParam String vehicle_type) {
    return visitors.quote(auth, vehicle_type);
  }

  @PostMapping
  public Map<String, Object> sell(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @Valid @RequestBody Sale body) {
    return visitors.sell(auth, body);
  }

  @GetMapping("/{id}")
  public Map<String, Object> receipt(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @PathVariable long id) {
    return visitors.receipt(auth, id);
  }
}
