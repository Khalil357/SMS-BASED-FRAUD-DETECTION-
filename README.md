# SMS Fraud Detection System

A monorepo for the SMS fraud detection API, a Flutter mobile app, and a React admin portal.

## Repository layout

    .
    ├── backend/                 Spring Boot API, PostgreSQL persistence, tests, and deployment files
    │   ├── src/main/java/com/example/smsfraud/
    │   ├── src/main/resources/db/migration/   Flyway migrations for production
    │   ├── src/test/
    │   ├── compose.yaml         Production-oriented Compose stack
    │   └── pom.xml
    ├── frontend/                Flutter mobile app (source in lib/, tests in test/)
    ├── web-client/              React/TypeScript admin portal (Vite)
    ├── .github/workflows/       CI and deployment workflows
    └── README.md

The backend uses Java 21, Spring Boot 4, Maven, PostgreSQL, Spring Security/JWT, and Redis-backed OTP storage in the production profile. The mobile app uses Flutter/Dart. The admin portal uses React, TypeScript, and Vite.

## Run locally

### Backend API

Install JDK 21 and have PostgreSQL available at localhost:5432. The default development database is sms_fraud, with user sms_app and password sms_pass (local development only). You can use an existing PostgreSQL installation or start a new local Docker container:

    docker run --name smsfraud-dev-postgres -e POSTGRES_DB=sms_fraud -e POSTGRES_USER=sms_app -e POSTGRES_PASSWORD=sms_pass -p 5432:5432 -d postgres:17-alpine

If that container already exists but is stopped, run docker start smsfraud-dev-postgres instead. Do not start a second database if something is already using port 5432. Check availability with docker exec smsfraud-dev-postgres pg_isready -U sms_app -d sms_fraud (or your PostgreSQL installation's pg_isready).

From the repository root on Windows PowerShell:

    $env:SPRING_DATASOURCE_URL = 'jdbc:postgresql://localhost:5432/sms_fraud'
    $env:SPRING_DATASOURCE_USERNAME = 'sms_app'
    $env:SPRING_DATASOURCE_PASSWORD = 'sms_pass'
    cd backend
    .\mvnw.cmd spring-boot:run

On macOS/Linux, use ./mvnw spring-boot:run in backend/ and export the same SPRING_DATASOURCE_* variables if needed. The API listens on http://localhost:8080; local Swagger UI is at http://localhost:8080/swagger-ui.html.

The default profile uses Hibernate schema updates and an in-memory OTP store. The prod profile uses Flyway migrations and Redis. backend/.env is read by the application's DotEnv loader when present, but existing environment variables take precedence. In particular, check for a SPRING_DATASOURCE_URL override if startup cannot reach PostgreSQL. Do not commit real credentials or use the development password in production.

### Admin web portal

Install Node.js 22 and run from the repository root in a second PowerShell window:

    cd web-client
    npm ci
    $env:VITE_API_BASE_URL = 'http://localhost:8080'
    npm run dev

Open the URL printed by Vite (normally http://localhost:5173). VITE_API_BASE_URL selects the backend; without it, the portal uses the deployed API address defined in web-client/src/services/. The portal includes the dashboard, SMS ingestion logs, team, and users sections.

### Flutter mobile app

Install Flutter and an Android/iOS development environment, then run from the repository root:

    cd frontend
    flutter pub get
    flutter run

The Flutter app's API base URL is defined in frontend/lib/services/auth_service.dart and currently defaults to the deployed backend. Configure that target for your development environment when testing against a local API; an Android emulator reaches the host machine at 10.0.2.2, not localhost.

## Checks

Run checks from each project's directory:

    cd backend
    .\mvnw.cmd test
    cd ..

    cd web-client
    npm run lint
    npm run build
    cd ..

    cd frontend
    flutter analyze
    flutter test

Backend tests that use PostgreSQL need a reachable test database. The GitHub Actions CI workflow provisions one for its backend test job.

## Deployment files

backend/compose.yaml defines the deployed Nginx, API, PostgreSQL, and Redis services; see backend/EC2_DEPLOYMENT.md for deployment-specific context. It does not publish its database port to the host and is not the local database setup described above. The repository-root docker-compose.yml is an older stack using Java 17 and should not be used as the current backend run path.
