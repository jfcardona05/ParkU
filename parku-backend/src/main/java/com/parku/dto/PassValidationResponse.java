package com.parku.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@AllArgsConstructor
public class PassValidationResponse {

    private boolean valid;
    private String message;
    private UUID validationId;
    private UUID dailyPassId;
    private UUID userId;
    private UUID vehicleId;
    private UUID guardId;
    private LocalDateTime validatedAt;
}