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
  @ExceptionHandler(ResponseStatusException.class)
  public ResponseEntity<?> status(ResponseStatusException ex) {
    return ResponseEntity.status(ex.getStatusCode())
        .body(
            Map.of(
                "success",
                false,
                "message",
                ex.getReason() == null ? "Solicitud rechazada" : ex.getReason()));
  }

  @ExceptionHandler({MethodArgumentNotValidException.class, HttpMessageNotReadableException.class})
  public ResponseEntity<?> validation(Exception ex) {
    return ResponseEntity.badRequest()
        .body(
            Map.of(
                "success",
                false,
                "message",
                "Datos inválidos: revise los campos obligatorios y sus valores"));
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
