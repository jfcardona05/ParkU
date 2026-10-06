package com.parku.repository;

import com.parku.model.PassValidation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface PassValidationRepository
        extends JpaRepository<PassValidation, UUID> {

    List<PassValidation> findByDailyPassIdOrderByValidatedAtDesc(
            UUID dailyPassId
    );

    List<PassValidation> findByGuardIdOrderByValidatedAtDesc(
            UUID guardId
    );
}