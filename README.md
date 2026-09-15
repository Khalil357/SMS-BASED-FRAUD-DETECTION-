# SMS Fraud Detection System

A software system for detecting, analyzing, and reporting fraudulent SMS messages using automated fraud detection techniques.

The project is developed as a **monorepo**, with the backend and frontend maintained in separate directories.

## Project Structure

```text
smsfraud/
├── backend/        # Spring Boot backend and REST API
├── frontend/       # Flutter mobile application
├── docs/           # Project documentation (optional)
├── .gitignore
└── README.md
```

## Technology Stack

### Backend

* Java
* Spring Boot
* Maven
* REST API
* MySQL/PostgreSQL *(depending on the finalized database)*

### Frontend

* Flutter
* Dart

## Backend Structure

The Spring Boot application is located in `backend/`.

```text
backend/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/example/smsfraud/
│   │   │       ├── config/
│   │   │       ├── controller/
│   │   │       ├── entity/
│   │   │       ├── repository/
│   │   │       ├── service/
│   │   │       └── SmsfraudApplication.java
│   │   └── resources/
│   └── test/
├── pom.xml
├── mvnw
└── mvnw.cmd
```

### Run the Backend

From the repository root:

```bash
cd backend
./mvnw spring-boot:run
```

### Run on a Physical Android Phone

`10.0.2.2` works only for an Android emulator. For a phone connected to the
same Wi-Fi network as the computer running the backend, use the computer's
LAN IP address when building the Flutter app. For example, if the computer is
`192.168.1.25`:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.25:8080
```

Build an installable APK with the same option:

```bash
flutter build apk --dart-define=API_BASE_URL=http://192.168.1.25:8080
```

Ensure the backend is listening on port `8080`, the phone and computer are on
the same network, and the computer firewall permits inbound TCP connections to
that port. For a deployed backend, use its HTTPS URL instead.

To run the tests:

```bash
./mvnw test
```

## Frontend

The Flutter application will be maintained inside:

```text
frontend/
```

The frontend team is responsible for the Flutter application and its integration with the backend REST API.

Once the Flutter project has been initialized:

```bash
cd frontend
flutter pub get
flutter run
```

## Development Workflow

The project uses a **Git-based collaborative workflow**.

### Branches

Use descriptive branches for development:

```text
feature/feature-name
bugfix/bug-description
docs/documentation-name
```

Examples:

```text
feature/user-authentication
feature/sms-detection
bugfix/login-validation
docs/api-documentation
```

### Pull Requests

1. Create a branch from `main`.
2. Make your changes.
3. Test your changes locally.
4. Commit using a clear commit message.
5. Push your branch to GitHub.
6. Open a Pull Request.
7. Have the changes reviewed before merging.

Do not push unfinished feature work directly to `main`.

## Team Responsibilities

### Backend Team

Responsible for:

* REST APIs
* Authentication and authorization
* SMS fraud detection services
* Database integration
* Business logic
* Security
* Backend testing

Location:

```text
backend/
```

### Frontend Team

Responsible for:

* Flutter mobile application
* User interface
* User experience
* API integration
* Client-side validation
* Frontend testing

Location:

```text
frontend/
```

## Project Status

🚧 **In Development**

Current development is organized into iterative sprints. Features and modules will be added incrementally as development progresses.

## Repository

This repository contains the complete SMS Fraud Detection System, including the backend, frontend, and project documentation.
