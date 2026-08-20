package com.example.smsfraud.repository;

import com.example.smsfraud.entity.UserDevices;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface UserDevicesRepository extends JpaRepository<UserDevices, String> {
    // device_id is a VARCHAR primary key, so the ID type is String

    List<UserDevices> findByUserId(UUID userId);

    List<UserDevices> findByUserIdAndIsActiveTrue(UUID userId);
}