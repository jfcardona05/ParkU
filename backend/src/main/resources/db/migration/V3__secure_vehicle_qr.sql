ALTER TABLE users DROP CONSTRAINT users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('estudiante','docente','operador','guard','admin'));
CREATE TABLE vehicle_qr (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 token_hash CHAR(64) NOT NULL UNIQUE,
 vehicle_id BIGINT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
 user_id BIGINT NOT NULL REFERENCES users(id),
 expires_at TIMESTAMPTZ NOT NULL,
 revoked BOOLEAN NOT NULL DEFAULT false,
 consumed BOOLEAN NOT NULL DEFAULT false
);
CREATE INDEX vehicle_qr_vehicle ON vehicle_qr(vehicle_id);
