CREATE TABLE parking_rates (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 vehicle_type VARCHAR(20) NOT NULL CHECK(vehicle_type IN ('moto','automovil')),
 amount BIGINT NOT NULL CHECK(amount>0 AND amount<=1000000000),
 block_seconds INTEGER NOT NULL CHECK(block_seconds BETWEEN 1 AND 86400),
 minimum_blocks INTEGER NOT NULL CHECK(minimum_blocks BETWEEN 1 AND 100000),
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 created_by BIGINT REFERENCES users(id)
);
INSERT INTO parking_rates(vehicle_type,amount,block_seconds,minimum_blocks) VALUES('moto',4000,3600,1),('automovil',5000,3600,1);
ALTER TABLE parking_visits ADD COLUMN rate_id BIGINT REFERENCES parking_rates(id);
ALTER TABLE transactions DROP CONSTRAINT transactions_type_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_type_check CHECK(type IN ('RECARGA_PRESENCIAL','COBRO_ESTACIONAMIENTO'));
ALTER TABLE transactions ADD COLUMN visit_id BIGINT UNIQUE REFERENCES parking_visits(id);
ALTER TABLE transactions ADD COLUMN parking_rate_label VARCHAR(200);
