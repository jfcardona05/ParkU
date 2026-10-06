package com.parku.dto;

import com.parku.enums.PassStatus;
import lombok.AllArgsConstructor;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@AllArgsConstructor
public class DailyPassResponse {

    private UUID id;
    private UUID userId;
    private UUID vehicleId;
    private String qrToken;
    private BigDecimal amountPaid;
    private LocalDate validDate;
    private PassStatus status;
    private LocalDateTime createdAt;
}