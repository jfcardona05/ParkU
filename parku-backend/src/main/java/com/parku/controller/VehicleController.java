package com.parku.controller;

import com.parku.dto.CreateVehicleRequest;
import com.parku.dto.VehicleResponse;
import com.parku.service.VehicleService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/vehicles")
public class VehicleController {

    private final VehicleService vehicleService;

    public VehicleController(VehicleService vehicleService) {
        this.vehicleService = vehicleService;
    }

    @PostMapping
    public ResponseEntity<VehicleResponse> create(
            @Valid @RequestBody CreateVehicleRequest request
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(vehicleService.create(request));
    }

    @GetMapping("/{id}")
    public ResponseEntity<VehicleResponse> findById(
            @PathVariable UUID id
    ) {
        return ResponseEntity.ok(
                vehicleService.findById(id)
        );
    }

    @GetMapping("/user/{userId}")
    public ResponseEntity<List<VehicleResponse>> findByUser(
            @PathVariable UUID userId
    ) {
        return ResponseEntity.ok(
                vehicleService.findByUserId(userId)
        );
    }

    @PatchMapping("/{id}/deactivate")
    public ResponseEntity<VehicleResponse> deactivate(
            @PathVariable UUID id
    ) {
        return ResponseEntity.ok(
                vehicleService.deactivate(id)
        );
    }
}