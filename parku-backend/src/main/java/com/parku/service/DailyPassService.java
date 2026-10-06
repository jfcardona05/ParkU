package com.parku.service;

import com.parku.dto.CreateDailyPassRequest;
import com.parku.dto.DailyPassResponse;
import com.parku.enums.PassStatus;
import com.parku.model.DailyPass;
import com.parku.model.Tariff;
import com.parku.model.User;
import com.parku.model.Vehicle;
import com.parku.repository.DailyPassRepository;
import com.parku.repository.TariffRepository;
import com.parku.repository.UserRepository;
import com.parku.repository.VehicleRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.UUID;

@Service
public class DailyPassService {

    private final DailyPassRepository dailyPassRepository;
    private final UserRepository userRepository;
    private final VehicleRepository vehicleRepository;
    private final TariffRepository tariffRepository;
    private final WalletService walletService;

    public DailyPassService(
            DailyPassRepository dailyPassRepository,
            UserRepository userRepository,
            VehicleRepository vehicleRepository,
            TariffRepository tariffRepository,
            WalletService walletService
    ) {
        this.dailyPassRepository = dailyPassRepository;
        this.userRepository = userRepository;
        this.vehicleRepository = vehicleRepository;
        this.tariffRepository = tariffRepository;
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

        Vehicle vehicle = vehicleRepository.findById(request.getVehicleId())
                .orElseThrow(() ->
                        new IllegalArgumentException("Vehicle not found"));

        if (!vehicle.getUser().getId().equals(user.getId())) {
            throw new IllegalArgumentException(
                    "Vehicle does not belong to this user"
            );
        }

        if (!vehicle.isActive()) {
            throw new IllegalArgumentException("Vehicle is inactive");
        }

        Tariff tariff = tariffRepository
                .findByVehicleTypeAndActiveTrue(vehicle.getType())
                .orElseThrow(() ->
                        new IllegalArgumentException(
                                "No active tariff found for vehicle type"
                        ));

        walletService.payParking(
                user.getId(),
                tariff.getAmount()
        );

        DailyPass pass = new DailyPass();

        pass.setUser(user);
        pass.setVehicle(vehicle);
        pass.setQrToken(UUID.randomUUID().toString());
        pass.setAmountPaid(tariff.getAmount());
        pass.setValidDate(today);
        pass.setStatus(PassStatus.ACTIVE);

        return toResponse(dailyPassRepository.save(pass));
    }

    @Transactional(readOnly = true)
    public DailyPassResponse findByQrToken(String qrToken) {

        DailyPass pass = dailyPassRepository.findByQrToken(qrToken)
                .orElseThrow(() ->
                        new IllegalArgumentException("Daily pass not found"));

        return toResponse(pass);
    }

    private DailyPassResponse toResponse(DailyPass pass) {

        return new DailyPassResponse(
                pass.getId(),
                pass.getUser().getId(),
                pass.getVehicle().getId(),
                pass.getQrToken(),
                pass.getAmountPaid(),
                pass.getValidDate(),
                pass.getStatus(),
                pass.getCreatedAt()
        );
    }
}