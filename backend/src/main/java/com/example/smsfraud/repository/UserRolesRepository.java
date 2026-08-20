package com.example.smsfraud.repository;

import com.example.smsfraud.entity.UserRoles;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRolesRepository extends JpaRepository<UserRoles, Integer> {

    Optional<UserRoles> findByRoleName(String roleName);
}
