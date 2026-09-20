package com.example.smsfraud.ml;

import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.client5.http.impl.classic.HttpClients;
import org.apache.hc.client5.http.config.ConnectionConfig;
import org.apache.hc.client5.http.impl.io.PoolingHttpClientConnectionManagerBuilder;
import org.apache.hc.client5.http.ssl.ClientTlsStrategyBuilder;
import org.apache.hc.client5.http.ssl.NoopHostnameVerifier;
import org.apache.hc.client5.http.ssl.TlsSocketStrategy;
import org.apache.hc.client5.http.ssl.TrustAllStrategy;
import org.apache.hc.core5.ssl.SSLContexts;
import org.apache.hc.core5.util.Timeout;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import javax.net.ssl.SSLContext;
import java.security.GeneralSecurityException;

@Configuration
public class MlClientConfig {

    private static final Logger log = LoggerFactory.getLogger(MlClientConfig.class);

    @Bean
    public RestClient mlRestClient(@Value("${ml.service.url}") String mlServiceUrl,
                                   @Value("${ml.service.api-key:}") String apiKey,
                                   @Value("${ml.service.insecure-tls:false}") boolean insecureTls)
            throws GeneralSecurityException {
        ClientHttpRequestFactory requestFactory = insecureTls
                ? insecureRequestFactory()
                : secureRequestFactory();

        if (insecureTls) {
            log.warn("ML_SERVICE_INSECURE_TLS is enabled; certificate and hostname validation are disabled for the ML gateway only.");
        }

        return RestClient.builder()
                .baseUrl(mlServiceUrl)
                .requestFactory(requestFactory)
                .requestInterceptor((request, body, execution) -> {
                    if (apiKey == null || apiKey.isBlank()) {
                        throw new IllegalStateException(
                                "ML service API key is not configured (ML_SERVICE_API_KEY).");
                    }
                    request.getHeaders().set("x-api-key", apiKey);
                    return execution.execute(request, body);
                })
                .build();
    }

    private ClientHttpRequestFactory secureRequestFactory() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(5000);
        factory.setReadTimeout(10000);
        return factory;
    }

    private ClientHttpRequestFactory insecureRequestFactory() throws GeneralSecurityException {
        SSLContext sslContext = SSLContexts.custom()
                .loadTrustMaterial(null, TrustAllStrategy.INSTANCE)
                .build();
        TlsSocketStrategy tlsStrategy = ClientTlsStrategyBuilder.create()
                .setSslContext(sslContext)
                .setHostnameVerifier(NoopHostnameVerifier.INSTANCE)
                .buildClassic();
        ConnectionConfig connectionConfig = ConnectionConfig.custom()
                .setConnectTimeout(Timeout.ofSeconds(5))
                .setSocketTimeout(Timeout.ofSeconds(10))
                .build();
        CloseableHttpClient httpClient = HttpClients.custom()
                .setConnectionManager(PoolingHttpClientConnectionManagerBuilder.create()
                        .setTlsSocketStrategy(tlsStrategy)
                        .setDefaultConnectionConfig(connectionConfig)
                        .build())
                .build();

        return new HttpComponentsClientHttpRequestFactory(httpClient);
    }
}
