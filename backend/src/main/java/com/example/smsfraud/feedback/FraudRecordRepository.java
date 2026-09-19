package com.example.smsfraud.feedback;

import com.example.smsfraud.scan.SmsScan;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.UUID;

public interface FraudRecordRepository extends JpaRepository<SmsScan, UUID> {

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("DELETE FROM SmsScan scan WHERE scan.scanId = :recordId AND scan.userId = :userId")
    int deleteOwnedById(@Param("recordId") UUID recordId, @Param("userId") UUID userId);
}
