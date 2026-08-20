package com.example.smsfraud.repository;

import com.example.smsfraud.entity.AuditLogs;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AuditLogsRepository extends JpaRepository<AuditLogs, UUID> {

    List<AuditLogs> findByUserId(UUID userId);

    List<AuditLogs> findByEventType(String eventType);
}
