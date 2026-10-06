package com.parku.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.util.UUID;

@Getter
@Setter
public class CreateDailyPassRequest {

    @NotNull(message = "User ID is required")
    private UUID userId;

    @NotNull(message = "Vehicle ID is required")
    private UUID vehicleId;
}