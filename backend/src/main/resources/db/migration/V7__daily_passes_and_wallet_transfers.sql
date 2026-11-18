CREATE TABLE parking_day_passes (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 user_id BIGINT NOT NULL REFERENCES users(id),
 vehicle_id BIGINT REFERENCES vehicles(id) ON DELETE SET NULL,
 plate VARCHAR(12) NOT NULL,
 vehicle_type VARCHAR(20) NOT NULL CHECK(vehicle_type IN ('moto','automovil')),
 service_date DATE NOT NULL,
 qr_id BIGINT UNIQUE REFERENCES vehicle_qr(id) ON DELETE SET NULL,
 token VARCHAR(64) NOT NULL UNIQUE,
 rate_id BIGINT NOT NULL REFERENCES parking_rates(id),
 amount BIGINT NOT NULL CHECK(amount>0),
 transaction_id BIGINT NOT NULL UNIQUE REFERENCES transactions(id),
 expires_at TIMESTAMPTZ NOT NULL,
 UNIQUE(user_id,service_date)
);
ALTER TABLE parking_visits ADD COLUMN daily_pass_id BIGINT REFERENCES parking_day_passes(id);
ALTER TABLE transactions DROP CONSTRAINT transactions_type_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_type_check CHECK(type IN (
 'RECARGA_PRESENCIAL','COBRO_ESTACIONAMIENTO','TRANSFERENCIA_ENVIADA','TRANSFERENCIA_RECIBIDA'
));
ALTER TABLE transactions ADD COLUMN counterpart_email VARCHAR(200);
CREATE TABLE wallet_transfers (
 id UUID PRIMARY KEY,
 sender_id BIGINT NOT NULL REFERENCES users(id),
 recipient_id BIGINT NOT NULL REFERENCES users(id),
 request_id VARCHAR(100) NOT NULL,
 fingerprint CHAR(64) NOT NULL,
 recipient_email VARCHAR(200) NOT NULL,
 amount BIGINT NOT NULL CHECK(amount>0 AND amount<=1000000000),
 sender_balance_after BIGINT NOT NULL CHECK(sender_balance_after>=0),
 debit_id BIGINT NOT NULL UNIQUE REFERENCES transactions(id),
 credit_id BIGINT NOT NULL UNIQUE REFERENCES transactions(id),
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CHECK(sender_id<>recipient_id),
 UNIQUE(sender_id,request_id)
);
