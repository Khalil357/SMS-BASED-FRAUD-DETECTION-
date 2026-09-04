package com.example.smsfraud.smsScannedRepository;

import com.example.smsfraud.entity.SmsScan;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface SmsScanRepository extends JpaRepository<SmsScan, UUID> {

    Page<SmsScan> findByUserIdOrderByScannedAtDesc(UUID userId, Pageable pageable);
}
