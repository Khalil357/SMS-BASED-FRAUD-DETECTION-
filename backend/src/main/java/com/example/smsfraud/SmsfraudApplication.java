package com.example.smsfraud;

import io.github.cdimascio.dotenv.Dotenv;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class SmsfraudApplication {

	public static void main(String[] args) {
		loadDotenv();
		SpringApplication.run(SmsfraudApplication.class, args);
	}

	private static void loadDotenv() {
		String[] directories = { "./", "./backend", "../" };
		for (String dir : directories) {
			try {
				Dotenv dotenv = Dotenv.configure().directory(dir).ignoreIfMissing().load();
				dotenv.entries().forEach(entry -> {
					if (System.getProperty(entry.getKey()) == null) {
						System.setProperty(entry.getKey(), entry.getValue());
					}
				});
			} catch (Exception ignored) {
			}
		}
	}
}
