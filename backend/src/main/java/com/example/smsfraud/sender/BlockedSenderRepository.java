package com.example.smsfraud.sender;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface BlockedSenderRepository extends JpaRepository<BlockedSender, UUID> {
    boolean existsByPhoneNumber(String phoneNumber);
}
