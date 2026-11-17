package com.parku;

import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class WalletTransferService {
  private final JdbcTemplate db;
  private final IdentityService identity;
  public WalletTransferService(JdbcTemplate db, IdentityService identity) {
    this.db = db;
    this.identity = identity;
  }

  private Map<String, Object> old(Object sender, String key, String fingerprint) {
    var rows = db.queryForList("SELECT * FROM wallet_transfers WHERE sender_id=? AND request_id=?", sender, key);
    if (rows.isEmpty()) return null;
    var saved = rows.getFirst();
    if (!fingerprint.equals(saved.get("fingerprint")))
      throw new ApiProblem(409, "IDEMPOTENCY_CONFLICT", "La referencia ya fue utilizada con otros datos.");
    return receipt(saved, true);
  }

  private Map<String, Object> receipt(Map<String, Object> row, boolean replayed) {
    return Map.of("success", true, "transfer_id", row.get("id"), "amount", row.get("amount"),
        "recipient_email", row.get("recipient_email"), "balance_after", row.get("sender_balance_after"),
        "created_at", ((java.sql.Timestamp) row.get("created_at")).toInstant(),
        "replayed", replayed, "message", "Transferencia realizada");
  }

  @Transactional
  public Map<String, Object> transfer(String auth, String email, long amount, String requestId) {
    var sender = identity.current(auth);
    long senderId = ((Number) sender.get("id")).longValue();
    String normalized = email.trim().toLowerCase(Locale.ROOT);
    String fingerprint = VehicleQrService.digest(normalized + ":" + amount);
    var prior = old(senderId, requestId, fingerprint);
    if (prior != null) return prior;
    var recipients = db.queryForList("SELECT id,email FROM users WHERE email=?", normalized);
    if (recipients.isEmpty()) throw new ApiProblem(404, "RECIPIENT_NOT_FOUND", "No hay un usuario registrado con ese correo.");
    long recipientId = ((Number) recipients.getFirst().get("id")).longValue();
    if (senderId == recipientId) throw new ApiProblem(400, "SELF_TRANSFER", "No puedes transferirte saldo a tu propia cuenta.");
    // Always acquire both wallets in ascending ID order to prevent opposite-transfer deadlocks.
    var wallets = db.queryForList("SELECT id,balance FROM users WHERE id IN (?,?) ORDER BY id FOR UPDATE", senderId, recipientId);
    prior = old(senderId, requestId, fingerprint);
    if (prior != null) return prior;
    long from = 0, to = 0;
    for (var row : wallets) {
      if (((Number) row.get("id")).longValue() == senderId) from = ((Number) row.get("balance")).longValue();
      else to = ((Number) row.get("balance")).longValue();
    }
    if (wallets.size() != 2) throw new ApiProblem(404, "RECIPIENT_NOT_FOUND", "Usuario no disponible.");
    if (from < amount) throw new ApiProblem(409, "INSUFFICIENT_BALANCE", "Saldo insuficiente para transferir ese importe.");
    long recipientAfter;
    try { recipientAfter = Math.addExact(to, amount); }
    catch (ArithmeticException ex) { throw new ApiProblem(400, "BALANCE_LIMIT", "El saldo del destinatario supera el límite permitido."); }
    long senderAfter = from - amount;
    db.update("UPDATE users SET balance=? WHERE id=?", senderAfter, senderId);
    db.update("UPDATE users SET balance=? WHERE id=?", recipientAfter, recipientId);
    UUID transferId = UUID.randomUUID();
    long debit = movement(senderId, senderId, "TRANSFERENCIA_ENVIADA", amount, senderAfter, normalized);
    long credit = movement(recipientId, senderId, "TRANSFERENCIA_RECIBIDA", amount, recipientAfter, (String) sender.get("email"));
    var saved = db.queryForMap(
        "INSERT INTO wallet_transfers(id,sender_id,recipient_id,request_id,fingerprint,recipient_email,amount,sender_balance_after,debit_id,credit_id) VALUES(?,?,?,?,?,?,?,?,?,?) RETURNING *",
        transferId, senderId, recipientId, requestId, fingerprint, normalized, amount, senderAfter, debit, credit);
    return receipt(saved, false);
  }

  private long movement(long owner, long sender, String type, long amount, long balance, String counterpart) {
    return db.queryForObject(
        "INSERT INTO transactions(user_id,operator_id,type,amount,point_name,reference,balance_after,counterpart_email) VALUES(?,?,?,?,'Billetera ParkU',?,?,?) RETURNING id",
        Long.class, owner, sender, type, amount, UUID.randomUUID(), balance, counterpart);
  }
}
