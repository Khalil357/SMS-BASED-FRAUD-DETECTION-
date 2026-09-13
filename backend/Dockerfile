# ─── Stage 1: Build ───────────────────────────────────────────────────────────
FROM maven:3.9-eclipse-temurin-21 AS builder

WORKDIR /workspace

# Copy dependency descriptors first to leverage Docker layer caching
COPY pom.xml .
RUN mvn -q dependency:go-offline

# Copy source and build the fat JAR (skip tests for image build speed)
COPY src ./src
RUN mvn -q -DskipTests package

# ─── Stage 2: Runtime ─────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Copy only the built JAR from the builder stage
COPY --from=builder /workspace/target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
