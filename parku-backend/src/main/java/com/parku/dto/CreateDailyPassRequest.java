package com.parku.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.UUID;

@Getter
@Setter
public class CreateDailyPassRequest {

    @NotNull(message = "User ID is required")
    private UUID userId;

    @NotNull(message = "Vehicle ID is required")
    private UUID vehicleId;

    @NotNull(message = "Amount is required")
    @DecimalMin(value = "0.01", message = "Amount must be greater than zero")
    private BigDecimal amount;
}