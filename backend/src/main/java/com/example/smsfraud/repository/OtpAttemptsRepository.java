package com.example.smsfraud.repository;

import com.example.smsfraud.entity.OtpAttempts;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OtpAttemptsRepository extends JpaRepository<OtpAttempts, UUID> {

    List<OtpAttempts> findByUserId(UUID userId);

    Optional<OtpAttempts> findByOtpId(UUID otpId);
}