# Multi-stage build: build with Maven, run with a lightweight JRE
FROM maven:3.9.16-eclipse-temurin-21 AS builder
WORKDIR /workspace
COPY backend /workspace
RUN mvn -DskipTests package -DskipITs -q

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app
COPY --from=builder /workspace/target/*.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
