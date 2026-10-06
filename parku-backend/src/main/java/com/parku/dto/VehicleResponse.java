package com.parku.dto;

import com.parku.enums.VehicleType;
import lombok.AllArgsConstructor;
import lombok.Getter;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@AllArgsConstructor
public class VehicleResponse {

    private UUID id;
    private UUID userId;
    private String plate;
    private VehicleType type;
    private String brand;
    private String model;
    private boolean active;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
