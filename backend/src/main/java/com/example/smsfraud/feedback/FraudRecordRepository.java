package com.example.smsfraud.feedback;

import com.example.smsfraud.scan.SmsScan;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface FraudRecordRepository extends JpaRepository<SmsScan, UUID> {
}
