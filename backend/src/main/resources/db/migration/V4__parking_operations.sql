CREATE TABLE parking_settings (
 id INTEGER PRIMARY KEY CHECK(id=1),
 capacity INTEGER CHECK(capacity>0)
);
INSERT INTO parking_settings(id) VALUES(1);
CREATE TABLE parking_visits (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 vehicle_id BIGINT REFERENCES vehicles(id) ON DELETE SET NULL,
 user_id BIGINT NOT NULL REFERENCES users(id),
 plate VARCHAR(12) NOT NULL,
 vehicle_type VARCHAR(20) NOT NULL,
 entered_at TIMESTAMPTZ NOT NULL,
 exited_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX one_active_visit ON parking_visits(vehicle_id) WHERE exited_at IS NULL;
CREATE TABLE parking_operations (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 operator_id BIGINT NOT NULL REFERENCES users(id),
 request_id VARCHAR(100) NOT NULL,
 fingerprint CHAR(64) NOT NULL,
 visit_id BIGINT NOT NULL REFERENCES parking_visits(id),
 action VARCHAR(5) NOT NULL CHECK(action IN ('entry','exit')),
 occurred_at TIMESTAMPTZ NOT NULL,
 receipt TEXT NOT NULL,
 UNIQUE(operator_id,request_id)
);
