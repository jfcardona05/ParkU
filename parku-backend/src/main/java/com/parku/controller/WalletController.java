package com.parku.controller;

import com.parku.dto.RechargeRequest;
import com.parku.dto.WalletResponse;
import com.parku.dto.WalletTransactionResponse;
import com.parku.service.WalletService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/wallets")
public class WalletController {

    private final WalletService walletService;

    public WalletController(WalletService walletService) {
        this.walletService = walletService;
    }

    @PostMapping("/user/{userId}")
    public ResponseEntity<WalletResponse> createWallet(
            @PathVariable UUID userId
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(walletService.createWallet(userId));
    }

    @GetMapping("/user/{userId}")
    public ResponseEntity<WalletResponse> getWallet(
            @PathVariable UUID userId
    ) {
        return ResponseEntity.ok(
                walletService.findByUserId(userId)
        );
    }

    @PostMapping("/user/{userId}/recharge")
    public ResponseEntity<WalletResponse> recharge(
            @PathVariable UUID userId,
            @Valid @RequestBody RechargeRequest request
    ) {
        return ResponseEntity.ok(
                walletService.recharge(userId, request)
        );
    }

    @GetMapping("/user/{userId}/transactions")
    public ResponseEntity<List<WalletTransactionResponse>> getTransactions(
            @PathVariable UUID userId
    ) {
        return ResponseEntity.ok(
                walletService.getTransactions(userId)
        );
    }
}