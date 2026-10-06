package com.parku.service;

import com.parku.dto.CreateDailyPassRequest;
import com.parku.dto.DailyPassResponse;
import com.parku.enums.PassStatus;
import com.parku.model.DailyPass;
import com.parku.model.User;
import com.parku.repository.DailyPassRepository;
import com.parku.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.UUID;

@Service
public class DailyPassService {

    private final DailyPassRepository dailyPassRepository;
    private final UserRepository userRepository;
    private final WalletService walletService;

    public DailyPassService(
            DailyPassRepository dailyPassRepository,
            UserRepository userRepository,
            WalletService walletService
    ) {
        this.dailyPassRepository = dailyPassRepository;
        this.userRepository = userRepository;
        this.walletService = walletService;
    }

    @Transactional
    public DailyPassResponse create(CreateDailyPassRequest request) {

        LocalDate today = LocalDate.now();

        DailyPass existingPass = dailyPassRepository
                .findByUserIdAndVehicleIdAndValidDate(
                        request.getUserId(),
                        request.getVehicleId(),
                        today
                )
                .orElse(null);

        if (existingPass != null) {
            return toResponse(existingPass);
        }

        User user = userRepository.findById(request.getUserId())
                .orElseThrow(() ->
                        new IllegalArgumentException("User not found"));

        walletService.payParking(
                request.getUserId(),
                request.getAmount()
        );

        DailyPass pass = new DailyPass();

        pass.setUser(user);
        pass.setVehicleId(request.getVehicleId());
        pass.setQrToken(UUID.randomUUID().toString());
        pass.setAmountPaid(request.getAmount());
        pass.setValidDate(today);
        pass.setStatus(PassStatus.ACTIVE);

        DailyPass savedPass = dailyPassRepository.save(pass);

        return toResponse(savedPass);
    }

    @Transactional(readOnly = true)
    public DailyPassResponse findByQrToken(String qrToken) {

        DailyPass pass = dailyPassRepository
                .findByQrToken(qrToken)
                .orElseThrow(() ->
                        new IllegalArgumentException("Daily pass not found"));

        return toResponse(pass);
    }

    private DailyPassResponse toResponse(DailyPass pass) {
        return new DailyPassResponse(
                pass.getId(),
                pass.getUser().getId(),
                pass.getVehicleId(),
                pass.getQrToken(),
                pass.getAmountPaid(),
                pass.getValidDate(),
                pass.getStatus(),
                pass.getCreatedAt()
        );
    }
}