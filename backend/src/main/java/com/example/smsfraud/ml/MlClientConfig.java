package com.example.smsfraud.ml;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

@Configuration
public class MlClientConfig {

    @Bean
    public RestClient mlRestClient(@Value("${ml.service.url}") String mlServiceUrl,
                                   @Value("${ml.service.api-key:}") String apiKey) {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(5000);
        factory.setReadTimeout(10000);

        return RestClient.builder()
                .baseUrl(mlServiceUrl)
                .requestFactory(factory)
                .requestInterceptor((request, body, execution) -> {
                    if (apiKey == null || apiKey.isBlank()) {
                        throw new IllegalStateException(
                                "ML service API key is not configured (ML_SERVICE_API_KEY).");
                    }
                    request.getHeaders().set("X-API-Key", apiKey);
                    return execution.execute(request, body);
                })
                .build();
    }
}
