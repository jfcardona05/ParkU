package com.parku.dto;

import com.parku.enums.VehicleType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

import java.util.UUID;

@Getter
@Setter
public class CreateVehicleRequest {

    @NotNull(message = "User ID is required")
    private UUID userId;

    @NotBlank(message = "Plate is required")
    @Size(max = 10, message = "Plate must have at most 10 characters")
    private String plate;

    @NotNull(message = "Vehicle type is required")
    private VehicleType type;

    @Size(max = 50)
    private String brand;

    @Size(max = 50)
    private String model;
}
