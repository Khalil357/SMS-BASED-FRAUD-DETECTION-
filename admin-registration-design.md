# Admin Registration — Design Overview

> **User Story:** As an Admin, I want to be able to register another admin so that I can grant authorized users administrative access to the system.

---

## Subtasks

1. Design admin registration API & flow
2. Implement admin registration endpoint
3. Implement admin creation + password hashing
4. Tests

---

## Acceptance Criteria

- **Given** I am authenticated as an `ADMIN`, **when** I `POST /api/admin/users` with valid full name, email, phone number and password, **then** a new user with role `ADMIN` is created and a `201` is returned (never exposing the password hash).
- **Given** the email or phone number already exists, **then** the request returns `409` with a clear message.
- **Given** I am authenticated as a non-admin `USER` (or unauthenticated), **when** I `POST /api/admin/users`, **then** the request returns `403`/`401`.
- **Given** an invalid email or a weak password, **then** the request returns `400` with validation errors.
- **Given** a new admin is created, **then** their password is stored as a BCrypt hash (not plaintext).

---

## Diagram 1 — Subtask Flow

```mermaid
flowchart TD
    A["1. Design admin registration API & flow"] --> B["2. Implement endpoint<br/>POST /api/admin/users"]
    B --> C["3. Implement admin creation + password hashing"]
    C --> D["4. Tests"]

    A1["Deliverable:<br/>endpoint contract · DTOs<br/>verified=true decision"] --- A
    B1["Deliverable:<br/>controller + @Valid DTOs<br/>409 conflict handling"] --- B
    C1["Deliverable:<br/>assign ADMIN role · BCrypt hash<br/>set verified=true · save"] --- C
    D1["Deliverable:<br/>non-admin 403 · hashed pwd<br/>duplicate 409 · invalid 400"] --- D
```

---

## Diagram 2 — API Request Flow

```mermaid
sequenceDiagram
    participant A as Admin (caller)
    participant F as JwtAuthFilter
    participant C as AdminController
    participant S as AdminService
    participant R as UserRepo / UserRoleRepo
    participant B as BCrypt Encoder

    A->>F: POST /api/admin/users + JWT
    F->>C: authenticated + ROLE_ADMIN
    C->>S: registerAdmin(req)

    S->>R: existsByEmail / existsByPhone

    alt duplicate email or phone
        S-->>C: ConflictException (409)
    else new user
        S->>R: findByRoleName("ADMIN")
        S->>B: encode(password)
        S->>R: save(user)
        S-->>C: AdminUserResponse (201)
    end

    C-->>A: JSON (never returns passwordHash)
```

---

## Diagram 3 — Data Model

```mermaid
erDiagram
    USER_ROLE ||--o{ USER : "assigns role (role_id)"

    USER_ROLE {
        int role_id PK
        string role_name UK "ADMIN | USER"
    }

    USER {
        uuid user_id PK
        int role_id FK "points to ADMIN"
        string full_name
        string email UK
        string phone UK
        string password_hash "BCrypt (never plaintext)"
        boolean is_verified "true for admin signup"
        boolean is_active
        boolean is_locked
        timestamp created_at
        timestamp updated_at
    }
```

**New admin row:**

```mermaid
flowchart LR
    subgraph DB
        direction TB
        R["USER_ROLE<br/>role_id = 2 · role_name = ADMIN"]
        U["USER (new)<br/>role_id = 2<br/>password_hash = $2a$10$… (BCrypt)<br/>is_verified = true"]
    end
    U -->|"role_id FK"| R
```

---

## Design Details

| Item | Value |
|---|---|
| Endpoint | `POST /api/admin/users` |
| Authorization | Class-level `@PreAuthorize("hasRole('ADMIN')")` on `AdminController` (inherited) |
| Request DTO | `AdminRegistrationRequest { full_name, email, phone_number, password }` |
| Response DTO | `AdminUserResponse { id, full_name, email, phone_number, role }` |
| Role assignment | `userRoleRepository.findByRoleName("ADMIN")` |
| Password | `passwordEncoder.encode(...)` → BCrypt (bean already exists) |
| Initial state | `verified = true`, `active = true`, `locked = false` |
| Conflicts | `existsByEmail` / `existsByPhone` → `409` |

---

## Implementation Touch Points (Java files)

| File | Change |
|---|---|
| `backend/src/main/java/com/example/smsfraud/admin/AdminController.java` | Add `POST /api/admin/users` method |
| `backend/src/main/java/com/example/smsfraud/admin/AdminService.java` | Add `registerAdmin(...)` to the interface |
| `backend/src/main/java/com/example/smsfraud/admin/AdminServiceImpl.java` | Implement creation + BCrypt + role assignment |
| `backend/src/main/java/com/example/smsfraud/admin/dto/AdminRegistrationRequest.java` | New request DTO |
| `backend/src/main/java/com/example/smsfraud/admin/dto/AdminUserResponse.java` | New response DTO |

No changes needed to `SecurityConfig`, `UserRole`, or `DatabaseSeeder` — the `ADMIN` role and BCrypt bean already exist.
