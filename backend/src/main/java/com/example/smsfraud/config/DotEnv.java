package com.example.smsfraud.config;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Minimal {@code .env} loader. Called from {@code SmsfraudApplication.main()} before Spring
 * boots, so every {@code KEY=VALUE} line becomes a system property that
 * {@code ${KEY:default}} placeholders in {@code application.properties} resolve against.
 *
 * <p>Spring Boot does not read {@code .env} files natively (only Docker Compose's
 * {@code env_file} directive does). This makes local {@code mvn spring-boot:run} / IDE runs
 * pick up the same values. It is a no-op in Docker, where the image has no {@code .env} and
 * values arrive as real environment variables.</p>
 *
 * <p>Existing environment variables and system properties are never overridden.</p>
 */
public final class DotEnv {

    private DotEnv() {
    }

    public static void load() {
        Path envFile = locateEnvFile();
        if (envFile == null || !Files.exists(envFile)) {
            return;
        }
        try {
            for (String raw : Files.readAllLines(envFile)) {
                parseLine(raw.trim());
            }
        } catch (IOException ignored) {
            // A missing/unreadable .env must never prevent startup.
        }
    }

    private static void parseLine(String line) {
        if (line.isEmpty() || line.startsWith("#")) {
            return;
        }
        if (line.startsWith("export ")) {
            line = line.substring("export ".length()).trim();
        }
        int eq = line.indexOf('=');
        if (eq <= 0) {
            return;
        }
        String key = line.substring(0, eq).trim();
        String value = line.substring(eq + 1).trim();
        // Strip surrounding single/double quotes.
        if (value.length() >= 2) {
            char first = value.charAt(0);
            char last = value.charAt(value.length() - 1);
            if ((first == '"' && last == '"') || (first == '\'' && last == '\'')) {
                value = value.substring(1, value.length() - 1);
            }
        }
        // Never override a real environment variable or an existing system property.
        if (!key.isEmpty() && System.getProperty(key) == null && System.getenv(key) == null) {
            System.setProperty(key, value);
        }
    }

    private static Path locateEnvFile() {
        Path cwd = Paths.get(System.getProperty("user.dir", "."));
        Path direct = cwd.resolve(".env");
        if (Files.exists(direct)) {
            return direct;
        }
        // Fall back to the parent (e.g. launched from a submodule directory).
        Path parent = cwd.getParent();
        if (parent != null && Files.exists(parent.resolve(".env"))) {
            return parent.resolve(".env");
        }
        return direct;
    }
}
