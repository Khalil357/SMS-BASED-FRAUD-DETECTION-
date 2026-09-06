package com.example.smsfraud.user;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByEmail(String email);

    Optional<User> findByPhone(String phone);

    Optional<User> findByGoogleId(String googleId);

    boolean existsByEmail(String email);

    boolean existsByPhone(String phone);

    /** Eagerly loads the role so it can be read outside the persistence context. */
    @Query("SELECT u FROM User u JOIN FETCH u.role WHERE u.userId = :userId")
    Optional<User> findByIdWithRole(@Param("userId") UUID userId);

    /** All users with their roles eagerly loaded (admin listing). */
    @Query("SELECT u FROM User u JOIN FETCH u.role")
    List<User> findAllWithRoles();
}
