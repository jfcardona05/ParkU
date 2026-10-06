package com.parku.service;

import com.parku.dto.CreateTariffRequest;
import com.parku.dto.TariffResponse;
import com.parku.dto.UpdateTariffRequest;
import com.parku.model.Tariff;
import com.parku.repository.TariffRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class TariffService {

    private final TariffRepository tariffRepository;

    public TariffService(TariffRepository tariffRepository) {
        this.tariffRepository = tariffRepository;
    }

    @Transactional
    public TariffResponse create(CreateTariffRequest request) {

        if (tariffRepository.existsByVehicleType(request.getVehicleType())) {
            throw new IllegalArgumentException(
                    "Tariff already exists for this vehicle type"
            );
        }

        Tariff tariff = new Tariff();

        tariff.setVehicleType(request.getVehicleType());
        tariff.setAmount(request.getAmount());
        tariff.setActive(true);

        return toResponse(tariffRepository.save(tariff));
    }

    @Transactional(readOnly = true)
    public List<TariffResponse> findAll() {
        return tariffRepository.findAll()
                .stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public TariffResponse findById(UUID id) {

        Tariff tariff = tariffRepository.findById(id)
                .orElseThrow(() ->
                        new IllegalArgumentException("Tariff not found"));

        return toResponse(tariff);
    }

    @Transactional
    public TariffResponse update(UUID id, UpdateTariffRequest request) {

        Tariff tariff = tariffRepository.findById(id)
                .orElseThrow(() ->
                        new IllegalArgumentException("Tariff not found"));

        tariff.setAmount(request.getAmount());

        return toResponse(tariffRepository.save(tariff));
    }

    @Transactional
    public TariffResponse deactivate(UUID id) {

        Tariff tariff = tariffRepository.findById(id)
                .orElseThrow(() ->
                        new IllegalArgumentException("Tariff not found"));

        tariff.setActive(false);

        return toResponse(tariffRepository.save(tariff));
    }

    private TariffResponse toResponse(Tariff tariff) {
        return new TariffResponse(
                tariff.getId(),
                tariff.getVehicleType(),
                tariff.getAmount(),
                tariff.isActive(),
                tariff.getCreatedAt(),
                tariff.getUpdatedAt()
        );
    }
}