package com.parku.controller;

import com.parku.dto.CreateDailyPassRequest;
import com.parku.dto.DailyPassResponse;
import com.parku.service.DailyPassService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/daily-passes")
public class DailyPassController {

    private final DailyPassService dailyPassService;

    public DailyPassController(DailyPassService dailyPassService) {
        this.dailyPassService = dailyPassService;
    }

    @PostMapping
    public ResponseEntity<DailyPassResponse> create(
            @Valid @RequestBody CreateDailyPassRequest request
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(dailyPassService.create(request));
    }

    @GetMapping("/qr/{qrToken}")
    public ResponseEntity<DailyPassResponse> findByQrToken(
            @PathVariable String qrToken
    ) {
        return ResponseEntity.ok(
                dailyPassService.findByQrToken(qrToken)
        );
    }
}