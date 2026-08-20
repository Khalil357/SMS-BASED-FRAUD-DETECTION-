package com.example.smsfraud.repository;

import com.example.smsfraud.entity.UserSessions;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserSessionsRepository extends JpaRepository<UserSessions, UUID> {

    List<UserSessions> findByUserId(UUID userId);

    Optional<UserSessions> findByRefreshToken(String refreshToken);

    List<UserSessions> findByUserIdAndIsRevokedFalse(UUID userId);
}