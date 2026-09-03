package com.example.smsfraud.ml;

import com.example.smsfraud.ml.dto.FraudCheckRequest;
import com.example.smsfraud.ml.dto.FraudCheckResponse;
import org.springframework.http.HttpStatusCode;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.http.client.ClientHttpResponse;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

// Handles communication with the external ML fraud detection service.
@Service
public class MlFraudDetectionClient {

    private final RestClient restClient;

    public MlFraudDetectionClient(RestClient restClient) {

        this.restClient = restClient;
    }

    public FraudCheckResponse analyzeSms(String sender, String content) {
        FraudCheckRequest request = new FraudCheckRequest(sender, content);

        return restClient.post()
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
                .body(FraudCheckResponse.class);
    }

    private String readResponseBody(ClientHttpResponse response) throws IOException {

        return new String(response.getBody().readAllBytes(), StandardCharsets.UTF_8);
    }
}
