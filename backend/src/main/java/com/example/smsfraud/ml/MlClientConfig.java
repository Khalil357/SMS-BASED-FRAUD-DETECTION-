package com.example.smsfraud.ml;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

@Configuration
public class MlClientConfig {

    @Bean
    public RestClient mlRestClient(@Value("${ml.service.url}") String mlServiceUrl) {
        return RestClient.builder()
                .baseUrl(mlServiceUrl)
                .build();
    }
}
