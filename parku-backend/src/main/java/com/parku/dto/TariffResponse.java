package com.parku.dto;

import com.parku.enums.VehicleType;
import lombok.AllArgsConstructor;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@AllArgsConstructor
public class TariffResponse {

    private UUID id;
    private VehicleType vehicleType;
    private BigDecimal amount;
    private boolean active;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}