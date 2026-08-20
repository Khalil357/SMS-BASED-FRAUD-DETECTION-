package com.example.smsfraud.repository;

import com.example.smsfraud.entity.OtpCodes;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OtpCodesRepository extends JpaRepository<OtpCodes, UUID> {

    List<OtpCodes> findByUserId(UUID userId);

    Optional<OtpCodes> findByUserIdAndOtpCodeAndIsUsedFalse(UUID userId, String otpCode);

    List<OtpCodes> findByUserIdAndPurpose(UUID userId, String purpose);
}
