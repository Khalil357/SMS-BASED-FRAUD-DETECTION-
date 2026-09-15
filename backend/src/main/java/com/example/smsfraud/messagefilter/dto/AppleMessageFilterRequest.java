package com.example.smsfraud.messagefilter.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Request body posted by iOS when a Message Filter Extension calls
 * {@code deferQueryRequestToNetwork}. Format is defined by Apple.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public class AppleMessageFilterRequest {

    @JsonProperty("_version")
    private Integer version;

    private Query query;
    private App app;

    public Integer getVersion() {
        return version;
    }

    public void setVersion(Integer version) {
        this.version = version;
    }

    public Query getQuery() {
        return query;
    }

    public void setQuery(Query query) {
        this.query = query;
    }

    public App getApp() {
        return app;
    }

    public void setApp(App app) {
        this.app = app;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class Query {
        private String sender;
        private Message message;

        public String getSender() {
            return sender;
        }

        public void setSender(String sender) {
            this.sender = sender;
        }

        public Message getMessage() {
            return message;
        }

        public void setMessage(Message message) {
            this.message = message;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class Message {
        private String text;

        public String getText() {
            return text;
        }

        public void setText(String text) {
            this.text = text;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class App {
        private String version;

        public String getVersion() {
            return version;
        }

        public void setVersion(String version) {
            this.version = version;
        }
    }
}
