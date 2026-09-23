package com.example.smsfraud.ml;

import com.example.smsfraud.common.exception.ServiceUnavailableException;
import com.example.smsfraud.ml.dto.FraudCheckRequest;
import com.example.smsfraud.ml.dto.FraudCheckResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

// Handles communication with the external ML fraud detection service.
@Service
@RequiredArgsConstructor
public class MlFraudDetectionClient {

    private final RestClient restClient;

    public FraudCheckResponse analyzeSms(String message) {
        FraudCheckRequest request = new FraudCheckRequest(message);

        try {
            var responseEntity = restClient
                    .post()
                    .uri("/predict")
                    .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                    .body(request)
                    .retrieve()
                    .onStatus(HttpStatusCode::isError, (clientRequest, response) -> {
                        String responseBody = readResponseBody(response);
                        throw new ServiceUnavailableException(
                                "The fraud-detection model is unavailable (status "
                                        + response.getStatusCode().value() + ")."
                                        + (responseBody.isBlank() ? "" : " Please try again shortly."));
                    })
                    .toEntity(FraudCheckResponse.class);

            if (!responseEntity.hasBody()) {
                throw new ServiceUnavailableException("The fraud-detection model returned an empty response.");
            }

            return responseEntity.getBody();
        } catch (ServiceUnavailableException ex) {
            throw ex;
        } catch (RestClientException | IllegalStateException ex) {
            throw new ServiceUnavailableException(
                    "Unable to reach the fraud-detection model. Check your connection and try again.");
        }
    }

    private String readResponseBody(ClientHttpResponse response) throws IOException {

        return new String(response.getBody().readAllBytes(), StandardCharsets.UTF_8);
    }
}
