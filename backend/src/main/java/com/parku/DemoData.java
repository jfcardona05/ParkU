package com.parku;

import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@ConditionalOnProperty(name = "parku.demo.enabled", havingValue = "true")
public class DemoData implements CommandLineRunner {
  private final JdbcTemplate db;

  public DemoData(JdbcTemplate db) {
    this.db = db;
  }

  @Override
  @Transactional
  public void run(String... args) {
    var encoder = new BCryptPasswordEncoder();
    add(
        "Ronaldo Mosquera",
        "ronaldo.mosquera@usantotomas.edu.co",
        "pass123",
        "estudiante",
        15000,
        encoder);
    add(
        "Juan Felipe Cardona",
        "juan.cardona@usantotomas.edu.co",
        "pass123",
        "estudiante",
        8000,
        encoder);
    add("María Gómez", "maria.gomez@usantotomas.edu.co", "usta2026", "estudiante", 0, encoder);
    add("Operador Taquilla", "taquilla@usantotomas.edu.co", "caja123", "operador", 0, encoder);
  }

  private void add(
      String name,
      String email,
      String password,
      String role,
      long balance,
      BCryptPasswordEncoder encoder) {
    db.update(
        "INSERT INTO users(name,email,password_hash,role,balance) VALUES (?,?,?,?,?) ON CONFLICT(email) DO NOTHING",
        name,
        email,
        encoder.encode(password),
        role,
        balance);
  }
}
