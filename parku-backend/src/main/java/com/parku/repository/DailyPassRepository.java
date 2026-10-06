package com.parku.repository;

import com.parku.model.DailyPass;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

public interface DailyPassRepository extends JpaRepository<DailyPass, UUID> {

    Optional<DailyPass> findByQrToken(String qrToken);

    Optional<DailyPass> findByUserIdAndVehicleIdAndValidDate(
            UUID userId,
            UUID vehicleId,
            LocalDate validDate
    );

    boolean existsByUserIdAndVehicleIdAndValidDate(
            UUID userId,
            UUID vehicleId,
            LocalDate validDate
    );
}