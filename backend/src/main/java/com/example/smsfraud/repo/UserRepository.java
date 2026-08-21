package com.example.smsfraud.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public class UserRepository {
  private final JdbcTemplate jdbc;

  public UserRepository(JdbcTemplate jdbc) {
    this.jdbc = jdbc;
  }

  public boolean existsByPhone(String phone) {
    Integer cnt = jdbc.queryForObject("SELECT count(1) FROM users WHERE phone = ?", Integer.class, phone);
    return cnt != null && cnt > 0;
  }

  public boolean existsByEmail(String email) {
    Integer cnt = jdbc.queryForObject("SELECT count(1) FROM users WHERE email = ?", Integer.class, email);
    return cnt != null && cnt > 0;
  }

  public void insertUser(String email, String phone, String fullName, String passwordHash, int roleId) {
    // Let the DB assign user_id and timestamps via defaults
    jdbc.update("INSERT INTO users (email, phone, full_name, password_hash, role_id) VALUES (?, ?, ?, ?, ?)",
        email, phone, fullName, passwordHash, roleId);
  }

  public Optional<String> findUserIdByPhone(String phone) {
    try {
      String id = jdbc.queryForObject("SELECT user_id::text FROM users WHERE phone = ?", String.class, phone);
      return Optional.ofNullable(id);
    } catch (Exception e) {
      return Optional.empty();
    }
  }

  public Optional<String> findPasswordHashByPhone(String phone) {
    try {
      String h = jdbc.queryForObject("SELECT password_hash FROM users WHERE phone = ?", String.class, phone);
      return Optional.ofNullable(h);
    } catch (Exception e) {
      return Optional.empty();
    }
  }

  public void updatePasswordByPhone(String phone, String passwordHash) {
    jdbc.update("UPDATE users SET password_hash = ? WHERE phone = ?", passwordHash, phone);
  }
}
