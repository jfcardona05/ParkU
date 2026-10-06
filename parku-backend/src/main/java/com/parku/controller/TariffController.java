package com.parku.controller;

import com.parku.dto.CreateTariffRequest;
import com.parku.dto.TariffResponse;
import com.parku.dto.UpdateTariffRequest;
import com.parku.service.TariffService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/tariffs")
public class TariffController {

    private final TariffService tariffService;

    public TariffController(TariffService tariffService) {
        this.tariffService = tariffService;
    }

    @PostMapping
    public ResponseEntity<TariffResponse> create(
            @Valid @RequestBody CreateTariffRequest request
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(tariffService.create(request));
    }

    @GetMapping
    public ResponseEntity<List<TariffResponse>> findAll() {
        return ResponseEntity.ok(tariffService.findAll());
    }

    @GetMapping("/{id}")
    public ResponseEntity<TariffResponse> findById(
            @PathVariable UUID id
    ) {
        return ResponseEntity.ok(tariffService.findById(id));
    }

    @PutMapping("/{id}")
    public ResponseEntity<TariffResponse> update(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateTariffRequest request
    ) {
        return ResponseEntity.ok(
                tariffService.update(id, request)
        );
    }

    @PatchMapping("/{id}/deactivate")
    public ResponseEntity<TariffResponse> deactivate(
            @PathVariable UUID id
    ) {
        return ResponseEntity.ok(
                tariffService.deactivate(id)
        );
    }
}