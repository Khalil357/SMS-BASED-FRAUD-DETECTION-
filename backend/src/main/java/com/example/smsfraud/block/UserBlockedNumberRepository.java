package com.example.smsfraud.block;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface UserBlockedNumberRepository extends JpaRepository<UserBlockedNumber, UUID> {

    List<UserBlockedNumber> findByUserId(UUID userId);

    List<UserBlockedNumber> findByUserIdAndPhoneNumber(UUID userId, String phoneNumber);

    void deleteByUserIdAndPhoneNumber(UUID userId, String phoneNumber);

    boolean existsByUserIdAndPhoneNumber(UUID userId, String phoneNumber);
}
