package com.parku.repository;

import com.parku.model.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByEmail(String email);

    Optional<User> findByStudentCode(String studentCode);

    boolean existsByEmail(String email);

    boolean existsByStudentCode(String studentCode);
}