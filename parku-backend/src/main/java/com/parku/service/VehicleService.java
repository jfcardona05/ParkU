package com.parku.service;

import com.parku.dto.CreateVehicleRequest;
import com.parku.dto.VehicleResponse;
import com.parku.model.User;
import com.parku.model.Vehicle;
import com.parku.repository.UserRepository;
import com.parku.repository.VehicleRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class VehicleService {

    private final VehicleRepository vehicleRepository;
    private final UserRepository userRepository;

    public VehicleService(
            VehicleRepository vehicleRepository,
            UserRepository userRepository
    ) {
        this.vehicleRepository = vehicleRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public VehicleResponse create(CreateVehicleRequest request) {

        String plate = request.getPlate().trim().toUpperCase();

        if (vehicleRepository.existsByPlate(plate)) {
            throw new IllegalArgumentException("Plate is already registered");
        }

        User user = userRepository.findById(request.getUserId())
                .orElseThrow(() ->
                        new IllegalArgumentException("User not found"));

        Vehicle vehicle = new Vehicle();

        vehicle.setUser(user);
        vehicle.setPlate(plate);
        vehicle.setType(request.getType());
        vehicle.setBrand(request.getBrand());
        vehicle.setModel(request.getModel());
        vehicle.setActive(true);

        Vehicle savedVehicle = vehicleRepository.save(vehicle);

        return toResponse(savedVehicle);
    }

    @Transactional(readOnly = true)
    public VehicleResponse findById(UUID id) {

        Vehicle vehicle = vehicleRepository.findById(id)
                .orElseThrow(() ->
                        new IllegalArgumentException("Vehicle not found"));

        return toResponse(vehicle);
    }

    @Transactional(readOnly = true)
    public List<VehicleResponse> findByUserId(UUID userId) {

        return vehicleRepository.findByUserId(userId)
                .stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public VehicleResponse deactivate(UUID id) {

        Vehicle vehicle = vehicleRepository.findById(id)
                .orElseThrow(() ->
                        new IllegalArgumentException("Vehicle not found"));

        vehicle.setActive(false);

        return toResponse(vehicleRepository.save(vehicle));
    }

    private VehicleResponse toResponse(Vehicle vehicle) {

        return new VehicleResponse(
                vehicle.getId(),
                vehicle.getUser().getId(),
                vehicle.getPlate(),
                vehicle.getType(),
                vehicle.getBrand(),
                vehicle.getModel(),
                vehicle.isActive(),
                vehicle.getCreatedAt(),
                vehicle.getUpdatedAt()
        );
    }
}
