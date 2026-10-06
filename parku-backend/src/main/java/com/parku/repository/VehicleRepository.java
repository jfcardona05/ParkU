package com.parku.repository;

import com.parku.model.Vehicle;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface VehicleRepository extends JpaRepository<Vehicle, UUID> {

    List<Vehicle> findByUserId(UUID userId);

    Optional<Vehicle> findByPlate(String plate);

    boolean existsByPlate(String plate);
}
