package com.parku.service;

import com.parku.dto.PassValidationResponse;
import com.parku.dto.ValidatePassRequest;
import com.parku.enums.PassStatus;
import com.parku.enums.UserRole;
import com.parku.model.DailyPass;
import com.parku.model.PassValidation;
import com.parku.model.User;
import com.parku.repository.DailyPassRepository;
import com.parku.repository.PassValidationRepository;
import com.parku.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

@Service
public class PassValidationService {

    private final PassValidationRepository passValidationRepository;
    private final DailyPassRepository dailyPassRepository;
    private final UserRepository userRepository;

    public PassValidationService(
            PassValidationRepository passValidationRepository,
            DailyPassRepository dailyPassRepository,
            UserRepository userRepository
    ) {
        this.passValidationRepository = passValidationRepository;
        this.dailyPassRepository = dailyPassRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public PassValidationResponse validate(ValidatePassRequest request) {

        User guard = userRepository.findById(request.getGuardId())
                .orElseThrow(() ->
                        new IllegalArgumentException("Guard not found"));

        if (guard.getRole() != UserRole.GUARD
                && guard.getRole() != UserRole.ADMIN) {
            throw new IllegalArgumentException(
                    "User is not authorized to validate passes"
            );
        }

        DailyPass pass = dailyPassRepository
                .findByQrToken(request.getQrToken())
                .orElseThrow(() ->
                        new IllegalArgumentException("Daily pass not found"));

        if (pass.getStatus() != PassStatus.ACTIVE) {
            throw new IllegalArgumentException(
                    "Daily pass is not active"
            );
        }

        if (!pass.getValidDate().equals(LocalDate.now())) {
            throw new IllegalArgumentException(
                    "Daily pass is not valid for today"
            );
        }

        PassValidation validation = new PassValidation();

        validation.setDailyPass(pass);
        validation.setGuard(guard);

        PassValidation savedValidation =
                passValidationRepository.save(validation);

        return new PassValidationResponse(
                true,
                "Pass validated successfully",
                savedValidation.getId(),
                pass.getId(),
                pass.getUser().getId(),
                pass.getVehicle().getId(),
                guard.getId(),
                savedValidation.getValidatedAt()
        );
    }
}