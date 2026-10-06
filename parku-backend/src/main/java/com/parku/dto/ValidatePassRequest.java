package com.parku.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.util.UUID;

@Getter
@Setter
public class ValidatePassRequest {

    @NotBlank(message = "QR token is required")
    private String qrToken;

    @NotNull(message = "Guard ID is required")
    private UUID guardId;
}