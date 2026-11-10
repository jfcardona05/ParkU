package com.parku;

import java.util.Map;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

@RestControllerAdvice
public class ApiErrors {
  @ExceptionHandler(ApiProblem.class)
  public ResponseEntity<?> problem(ApiProblem ex) {
    return ResponseEntity.status(ex.status)
        .body(Map.of("success", false, "code", ex.code, "message", ex.getMessage()));
  }

  @ExceptionHandler(ResponseStatusException.class)
  public ResponseEntity<?> status(ResponseStatusException ex) {
    return ResponseEntity.status(ex.getStatusCode())
        .body(
            Map.of(
                "success",
                false,
                "code",
                ex.getStatusCode().value() == 401 ? "UNAUTHORIZED" : "REQUEST_REJECTED",
                "message",
                ex.getReason() == null ? "Solicitud rechazada" : ex.getReason()));
  }

  @ExceptionHandler({
    MethodArgumentNotValidException.class,
    HttpMessageNotReadableException.class,
    org.springframework.web.method.annotation.MethodArgumentTypeMismatchException.class
  })
  public ResponseEntity<?> validation(Exception ex) {
    return ResponseEntity.badRequest()
        .body(
            Map.of(
                "success",
                false,
                "message",
                "Datos inválidos: revise los campos obligatorios y sus valores",
                "code",
                "INVALID_REQUEST"));
  }

  @ExceptionHandler(DataIntegrityViolationException.class)
  public ResponseEntity<?> conflict(DataIntegrityViolationException ex) {
    return ResponseEntity.status(409)
        .body(
            Map.of(
                "success",
                false,
                "message",
                "El correo o la placa ya están registrados, o los datos no cumplen las restricciones"));
  }
}
