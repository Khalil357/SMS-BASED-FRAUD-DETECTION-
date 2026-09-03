package com.example.smsfraud.ml;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

@Configuration
public class MlClientConfig {

    @Bean
    public RestClient mlRestClient(
            RestClient.Builder restClientBuilder,
            @Value("${http://13.53.200.176:3232}") String mlServiceUrl) {
        return restClientBuilder
                .baseUrl(mlServiceUrl)
                .build();
    }
}
