package com.example.smsfraud;

import com.example.smsfraud.config.DotEnv;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.stereotype.Component;







@SpringBootApplication
public class SmsfraudApplication {

	public static void main(String[] args) {
		DotEnv.load();
		SpringApplication.run(SmsfraudApplication.class, args);
	}

}
