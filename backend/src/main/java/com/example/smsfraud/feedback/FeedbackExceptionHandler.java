package com.example.smsfraud.feedback;

import com.example.smsfraud.common.exception.ErrorResponse;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

// Handle feedback errors before the global handler's generic Exception fallback.
@Order(Ordered.HIGHEST_PRECEDENCE)
@RestControllerAdvice(assignableTypes = FraudRecordController.class)
public class FeedbackExceptionHandler {

    @ExceptionHandler(RecordNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleRecordNotFound(RecordNotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new ErrorResponse(ex.getMessage(), HttpStatus.NOT_FOUND.value()));
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ErrorResponse> handleInvalidRecordId(MethodArgumentTypeMismatchException ex) {
        return ResponseEntity.badRequest()
                .body(new ErrorResponse("recordId must be a valid UUID.",
                        HttpStatus.BAD_REQUEST.value()));
    }
}
