package com.example.smsfraud.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.security.spec.KeySpec;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

/** The API contract consumed by the Flutter authentication screens. */
@RestController
@RequestMapping("/api/auth")
@CrossOrigin
public class AuthController {
  private static final SecureRandom RANDOM = new SecureRandom();
  private final Map<String, User> usersByPhone = new ConcurrentHashMap<>();
  private final Map<String, String> phoneByEmail = new ConcurrentHashMap<>();
  private final Map<String, ResetCode> resetCodes = new ConcurrentHashMap<>();

  @PostMapping("/signup") ResponseEntity<?> signUp(@Valid @RequestBody SignUpRequest r) {
    String phone = phone(r.phoneNumber()); String email = r.email().trim().toLowerCase();
    if (!email.contains("@")) throw error(HttpStatus.BAD_REQUEST, "Enter a valid email address.");
    if (usersByPhone.containsKey(phone)) throw error(HttpStatus.CONFLICT, "A user with this phone number already exists.");
    if (phoneByEmail.putIfAbsent(email, phone) != null) throw error(HttpStatus.CONFLICT, "A user with this email address already exists.");
    usersByPhone.put(phone, new User(email, hash(r.password())));
    return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("message", "Account created successfully"));
  }
  @PostMapping("/login") Map<String, String> login(@Valid @RequestBody LoginRequest r) {
    User user = usersByPhone.get(phone(r.phoneNumber()));
    if (user == null || !matches(r.password(), user.passwordHash)) throw error(HttpStatus.UNAUTHORIZED, "Invalid phone number or password.");
    return Map.of("message", "Login successful", "token", token());
  }
  @PostMapping("/forgot-password") Map<String, String> forgot(@Valid @RequestBody PhoneRequest r) { issue(phone(r.phoneNumber())); return Map.of("message", "Reset code sent successfully"); }
  @PostMapping("/resend-code") Map<String, String> resend(@Valid @RequestBody PhoneRequest r) { issue(phone(r.phoneNumber())); return Map.of("message", "Code resent successfully"); }
  @PostMapping("/verify-code") Map<String, String> verify(@Valid @RequestBody VerifyCodeRequest r) { valid(phone(r.phoneNumber()), r.verificationCode()).verified = true; return Map.of("message", "Code verified successfully"); }
  @PostMapping("/reset-password") Map<String, String> reset(@Valid @RequestBody ResetRequest r) {
    String phone = phone(r.phoneNumber()); ResetCode code = valid(phone, r.verificationCode());
    if (!code.verified) throw error(HttpStatus.BAD_REQUEST, "Verify the reset code before changing your password.");
    usersByPhone.get(phone).passwordHash = hash(r.newPassword()); resetCodes.remove(phone);
    return Map.of("message", "Password reset successfully");
  }
  private void issue(String phone) {
    if (!usersByPhone.containsKey(phone)) throw error(HttpStatus.NOT_FOUND, "No account was found for this phone number.");
    String code = "%06d".formatted(RANDOM.nextInt(1_000_000)); resetCodes.put(phone, new ResetCode(code, Instant.now().plus(10, ChronoUnit.MINUTES)));
    // Development transport: wire this to the team's SMS provider for production.
    System.out.println("Password-reset code for " + phone + ": " + code);
  }
  private ResetCode valid(String phone, String code) {
    ResetCode reset = resetCodes.get(phone);
    if (reset == null || reset.expiresAt.isBefore(Instant.now()) || !reset.code.equals(code)) throw error(HttpStatus.BAD_REQUEST, "The verification code is invalid or has expired.");
    return reset;
  }
  private static String phone(String value) { String p = value.replaceAll("[\\s()-]", ""); if (!p.matches("\\+?[0-9]{7,15}")) throw error(HttpStatus.BAD_REQUEST, "Enter a valid phone number."); return p; }
  private static String hash(String password) { byte[] salt = new byte[16]; RANDOM.nextBytes(salt); return Base64.getEncoder().encodeToString(salt) + ":" + Base64.getEncoder().encodeToString(derive(password, salt)); }
  private static boolean matches(String password, String stored) { try { String[] p = stored.split(":", 2); return MessageDigest.isEqual(derive(password, Base64.getDecoder().decode(p[0])), Base64.getDecoder().decode(p[1])); } catch (Exception e) { return false; } }
  private static byte[] derive(String password, byte[] salt) { try { KeySpec spec = new PBEKeySpec(password.toCharArray(), salt, 120_000, 256); return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded(); } catch (Exception e) { throw new IllegalStateException("Unable to hash password", e); } }
  private static String token() { byte[] bytes = new byte[32]; RANDOM.nextBytes(bytes); return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes); }
  private static ApiException error(HttpStatus status, String message) { return new ApiException(status, message); }
  record SignUpRequest(@NotBlank String fullName, @NotBlank String email, @NotBlank String phoneNumber, @NotBlank String gender, @NotBlank @Size(min = 8) String password) {}
  record LoginRequest(@NotBlank String phoneNumber, @NotBlank String password) {}
  record PhoneRequest(@NotBlank String phoneNumber) {}
  record VerifyCodeRequest(@NotBlank String phoneNumber, @NotBlank @Size(min = 6, max = 6) String verificationCode) {}
  record ResetRequest(@NotBlank String phoneNumber, @NotBlank @Size(min = 6, max = 6) String verificationCode, @NotBlank @Size(min = 8) String newPassword) {}
  static final class User { final String email; String passwordHash; User(String email, String passwordHash) { this.email = email; this.passwordHash = passwordHash; } }
  static final class ResetCode { final String code; final Instant expiresAt; boolean verified; ResetCode(String code, Instant expiresAt) { this.code = code; this.expiresAt = expiresAt; } }
}
@RestControllerAdvice class ApiErrors {
  @ExceptionHandler(ApiException.class) ResponseEntity<Map<String, String>> api(ApiException e) { return ResponseEntity.status(e.status).body(Map.of("message", e.getMessage())); }
  @ExceptionHandler(org.springframework.web.bind.MethodArgumentNotValidException.class) ResponseEntity<Map<String, String>> validation() { return ResponseEntity.badRequest().body(Map.of("message", "Please provide valid information for every required field.")); }
}
class ApiException extends RuntimeException { final HttpStatus status; ApiException(HttpStatus status, String message) { super(message); this.status = status; } }
