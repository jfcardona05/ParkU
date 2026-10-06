package com.parku.dto;

import com.parku.enums.TransactionType;
import lombok.AllArgsConstructor;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@AllArgsConstructor
public class WalletTransactionResponse {

    private UUID id;
    private BigDecimal amount;
    private TransactionType type;
    private String description;
    private LocalDateTime createdAt;
}