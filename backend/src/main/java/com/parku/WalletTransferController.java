package com.parku;

import jakarta.validation.Valid;
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
      @NotBlank @jakarta.validation.constraints.Pattern(regexp = "CC|TI")
          String recipient_document_type,
      @NotBlank @jakarta.validation.constraints.Pattern(regexp = "[0-9]{5,15}")
          String recipient_document_number,
      @NotNull
          @Positive
          @Max(1000000000)
          @com.fasterxml.jackson.databind.annotation.JsonDeserialize(using = WholeCopAmount.class)
          Long amount,
      @NotBlank @Size(max = 100) String request_id) {}

  @PostMapping("/transfers")
  public Map<String, Object> transfer(
      @RequestHeader(value = "Authorization", required = false) String auth,
      @Valid @RequestBody Transfer body) {
    return service.transfer(
        auth,
        body.recipient_document_type(),
        body.recipient_document_number(),
        body.amount(),
        body.request_id());
  }
}
