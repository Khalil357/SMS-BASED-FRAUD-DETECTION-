package com.example.smsfraud.scan;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface SmsReportAttemptRepository extends JpaRepository<SmsReportAttempt, UUID> {
}
