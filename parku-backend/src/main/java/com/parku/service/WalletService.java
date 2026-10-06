package com.parku.service;

import com.parku.dto.RechargeRequest;
import com.parku.dto.WalletResponse;
import com.parku.dto.WalletTransactionResponse;
import com.parku.enums.TransactionType;
import com.parku.model.User;
import com.parku.model.Wallet;
import com.parku.model.WalletTransaction;
import com.parku.repository.UserRepository;
import com.parku.repository.WalletRepository;
import com.parku.repository.WalletTransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Service
public class WalletService {

    private final WalletRepository walletRepository;
    private final WalletTransactionRepository transactionRepository;
    private final UserRepository userRepository;

    public WalletService(
            WalletRepository walletRepository,
            WalletTransactionRepository transactionRepository,
            UserRepository userRepository
    ) {
        this.walletRepository = walletRepository;
        this.transactionRepository = transactionRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public WalletResponse createWallet(UUID userId) {

        if (walletRepository.existsByUserId(userId)) {
            throw new IllegalArgumentException("User already has a wallet");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        Wallet wallet = new Wallet();
        wallet.setUser(user);
        wallet.setBalance(BigDecimal.ZERO);

        Wallet savedWallet = walletRepository.save(wallet);

        return toResponse(savedWallet);
    }

    @Transactional(readOnly = true)
    public WalletResponse findByUserId(UUID userId) {

        Wallet wallet = getWalletByUserId(userId);

        return toResponse(wallet);
    }

    @Transactional
    public WalletResponse recharge(UUID userId, RechargeRequest request) {

        Wallet wallet = getWalletByUserId(userId);

        wallet.recharge(request.getAmount());

        walletRepository.save(wallet);

        WalletTransaction transaction = new WalletTransaction();
        transaction.setWallet(wallet);
        transaction.setAmount(request.getAmount());
        transaction.setType(TransactionType.RECHARGE);
        transaction.setDescription(
                request.getDescription() != null
                        ? request.getDescription()
                        : "Wallet recharge"
        );

        transactionRepository.save(transaction);

        return toResponse(wallet);
    }

    @Transactional(readOnly = true)
    public List<WalletTransactionResponse> getTransactions(UUID userId) {

        Wallet wallet = getWalletByUserId(userId);

        return transactionRepository
                .findByWalletIdOrderByCreatedAtDesc(wallet.getId())
                .stream()
                .map(this::toTransactionResponse)
                .toList();
    }

    private Wallet getWalletByUserId(UUID userId) {
        return walletRepository.findByUserId(userId)
                .orElseThrow(() ->
                        new IllegalArgumentException("Wallet not found"));
    }

    private WalletResponse toResponse(Wallet wallet) {
        return new WalletResponse(
                wallet.getId(),
                wallet.getUser().getId(),
                wallet.getBalance(),
                wallet.getCreatedAt(),
                wallet.getUpdatedAt()
        );
    }

    private WalletTransactionResponse toTransactionResponse(
            WalletTransaction transaction
    ) {
        return new WalletTransactionResponse(
                transaction.getId(),
                transaction.getAmount(),
                transaction.getType(),
                transaction.getDescription(),
                transaction.getCreatedAt()
        );
    }
}