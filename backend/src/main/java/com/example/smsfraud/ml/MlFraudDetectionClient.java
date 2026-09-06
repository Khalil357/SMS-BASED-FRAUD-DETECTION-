package com.example.smsfraud.ml;

import com.example.smsfraud.ml.dto.FraudCheckRequest;
import com.example.smsfraud.ml.dto.FraudCheckResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

// Handles communication with the external ML fraud detection service.
@Service
@RequiredArgsConstructor
public class MlFraudDetectionClient {

    private final RestClient restClient;

    public FraudCheckResponse analyzeSms(String message) {
        FraudCheckRequest request = new FraudCheckRequest(message);

        var responseEntity = restClient
                .post()
                .uri("/predict")
                .body(request)
                .retrieve()
                .onStatus(HttpStatusCode::isError, (clientRequest, response) -> {
                    String responseBody = readResponseBody(response);

                    throw new IllegalStateException(
                            "ML fraud detection request failed with status "
                                    + response.getStatusCode()
                                    + (responseBody.isBlank() ? "" : ": " + responseBody));
                })
                .toEntity(FraudCheckResponse.class);

        if (!responseEntity.hasBody()) {
            throw new IllegalStateException("ML fraud detection service returned an empty response");
        }

        return responseEntity.getBody();
    }

    private String readResponseBody(ClientHttpResponse response) throws IOException {

        return new String(response.getBody().readAllBytes(), StandardCharsets.UTF_8);
    }
}
