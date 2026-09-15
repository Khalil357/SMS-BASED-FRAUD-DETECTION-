package com.example.smsfraud.scan;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface SmsScanRepository extends JpaRepository<SmsScan, UUID> {

    Page<SmsScan> findByUserIdOrderByScannedAtDesc(UUID userId, Pageable pageable);

    Page<SmsScan> findByUserIdAndVerdictOrderByScannedAtDescScanIdDesc(
            UUID userId, String verdict, Pageable pageable);

    long countByVerdict(String verdict);

    java.util.List<SmsScan> findByVerdictAndScannedAtAfter(String verdict, java.time.Instant start);

    Page<SmsScan> findByVerdictOrderByScannedAtDesc(String verdict, Pageable pageable);

    Page<SmsScan> findAllByOrderByScannedAtDesc(Pageable pageable);

    @org.springframework.data.jpa.repository.Query("SELECT DISTINCT s.sender FROM SmsScan s WHERE s.sender IS NOT NULL")
    java.util.List<String> findDistinctSenders();
}
