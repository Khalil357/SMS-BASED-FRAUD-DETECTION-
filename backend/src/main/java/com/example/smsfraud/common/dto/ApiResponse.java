package com.example.smsfraud.common.dto;

/**
 * Uniform success envelope returned by every REST endpoint: {@code {message, data}}.
 * Keeps the frontend's top-level {@code message} and {@code data} keys intact.
 */
public record ApiResponse<T>(String message, T data) {

    public static <T> ApiResponse<T> ok(String message, T data) {
        return new ApiResponse<>(message, data);
    }

    public static <T> ApiResponse<T> ok(String message) {
        return new ApiResponse<>(message, null);
    }
}
