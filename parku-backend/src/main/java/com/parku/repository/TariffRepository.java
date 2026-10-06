package com.parku.repository;

import com.parku.enums.VehicleType;
import com.parku.model.Tariff;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface TariffRepository extends JpaRepository<Tariff, UUID> {

    Optional<Tariff> findByVehicleType(VehicleType vehicleType);

    Optional<Tariff> findByVehicleTypeAndActiveTrue(VehicleType vehicleType);

    boolean existsByVehicleType(VehicleType vehicleType);
}