package com.parku.controller;

import com.parku.dto.PassValidationResponse;
import com.parku.dto.ValidatePassRequest;
import com.parku.service.PassValidationService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/pass-validations")
public class PassValidationController {

    private final PassValidationService passValidationService;

    public PassValidationController(
            PassValidationService passValidationService
    ) {
        this.passValidationService = passValidationService;
    }

    @PostMapping
    public ResponseEntity<PassValidationResponse> validate(
            @Valid @RequestBody ValidatePassRequest request
    ) {
        return ResponseEntity.ok(
                passValidationService.validate(request)
        );
    }
}