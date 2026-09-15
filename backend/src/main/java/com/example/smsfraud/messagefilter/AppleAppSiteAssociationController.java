package com.example.smsfraud.messagefilter;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Serves Apple App Site Association for Message Filter associated domains.
 * Host this JSON (or an equivalent CDN copy) at
 * {@code https://<host>/.well-known/apple-app-site-association} with
 * {@code Content-Type: application/json} and no redirects.
 *
 * <p>Replace {@code TEAM_ID} via {@code app.apple.team-id}. Bundle IDs must match
 * the Runner + MessageFilterExtension product identifiers.
 */
@RestController
public class AppleAppSiteAssociationController {

    private final String teamId;
    private final String appBundleId;
    private final String extensionBundleId;

    public AppleAppSiteAssociationController(
            @Value("${app.apple.team-id:TEAM_ID}") String teamId,
            @Value("${app.apple.app-bundle-id:com.example.secureSignal}") String appBundleId,
            @Value("${app.apple.extension-bundle-id:com.example.secureSignal.MessageFilterExtension}")
                    String extensionBundleId) {
        this.teamId = teamId;
        this.appBundleId = appBundleId;
        this.extensionBundleId = extensionBundleId;
    }

    @GetMapping(
            value = {"/.well-known/apple-app-site-association", "/apple-app-site-association"},
            produces = MediaType.APPLICATION_JSON_VALUE)
    public String appleAppSiteAssociation() {
        String app = teamId + "." + appBundleId;
        String extension = teamId + "." + extensionBundleId;
        return """
                {
                  "messagefilter": {
                    "apps": ["%s", "%s"]
                  }
                }
                """.formatted(app, extension);
    }
}
