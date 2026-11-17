package com.parku;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/wallet")
public class WalletTransferController {
  private final WalletTransferService service;

  public WalletTransferController(WalletTransferService service) {
    this.service = service;
  }

  public record Transfer(
      @NotBlank @Email @Size(max = 200) String recipient_email,
      @NotNull @Positive @Max(1000000000) Long amount,
      @NotBlank @Size(max = 100) String request_id) {
    public Transfer {
      if (recipient_email != null) recipient_email = recipient_email.trim();
    }
  }

  @PostMapping("/transfers")
  public Map<String, Object> transfer(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @Valid @RequestBody Transfer body) {
    return service.transfer(auth, body.recipient_email(), body.amount(), body.request_id());
  }
}
