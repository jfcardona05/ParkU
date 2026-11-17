CREATE INDEX transactions_recharge_date ON transactions(created_at DESC, id DESC)
 WHERE type = 'RECARGA_PRESENCIAL';
