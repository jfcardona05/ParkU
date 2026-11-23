-- Existing accounts remain valid; their owners can complete identity from Usuario.
ALTER TABLE users ADD COLUMN document_type varchar(2), ADD COLUMN document_number varchar(15),
 ADD CONSTRAINT user_document CHECK ((document_type IS NULL AND document_number IS NULL) OR
 (document_type IS NOT NULL AND document_number IS NOT NULL AND document_type IN ('CC','TI') AND document_number ~ '^[0-9]{5,15}$')),
 ADD CONSTRAINT unique_user_document UNIQUE(document_type,document_number);
ALTER TABLE wallet_transfers ADD COLUMN recipient_document_type varchar(2), ADD COLUMN recipient_document_number varchar(15);
CREATE TABLE visitor_passes (
 id bigserial PRIMARY KEY, visitor_name varchar(120) NOT NULL CHECK(length(trim(visitor_name))>0),
 plate varchar(10) NOT NULL CHECK(plate ~ '^[A-Z0-9]{5,10}$'),
 vehicle_type varchar(20) NOT NULL CHECK(vehicle_type IN ('moto','automovil')),
 service_date date NOT NULL, amount bigint NOT NULL CHECK(amount>0), rate_id bigint NOT NULL REFERENCES parking_rates(id),
 cash_session_id bigint NOT NULL REFERENCES cash_sessions(id), operator_id bigint NOT NULL REFERENCES users(id),
 point_name varchar(120) NOT NULL, reference uuid NOT NULL UNIQUE,
 request_id varchar(100) NOT NULL, fingerprint varchar(64) NOT NULL,
 token varchar(43) NOT NULL UNIQUE, token_hash varchar(64) NOT NULL UNIQUE,
 created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, expires_at timestamptz NOT NULL,
 entered_at timestamptz, exited_at timestamptz,
 UNIQUE(operator_id,request_id), UNIQUE(plate,service_date),
 CHECK(expires_at>created_at), CHECK(exited_at IS NULL OR entered_at IS NOT NULL)
);
CREATE INDEX visitor_cash_session ON visitor_passes(cash_session_id);
CREATE INDEX visitor_income_date ON visitor_passes(created_at DESC,id DESC);
CREATE TABLE visitor_gate_operations (
 id bigserial PRIMARY KEY, operator_id bigint NOT NULL REFERENCES users(id),
 request_id varchar(100) NOT NULL, fingerprint varchar(64) NOT NULL,
 pass_id bigint NOT NULL REFERENCES visitor_passes(id), action varchar(5) NOT NULL CHECK(action IN ('entry','exit')),
 occurred_at timestamptz NOT NULL, UNIQUE(operator_id,request_id)
);
-- One ledger for cash receipts. Visitor sales do not credit a fictitious user's wallet.
CREATE VIEW cash_income AS
 SELECT t.id,t.amount,t.created_at,t.point_name,t.reference,t.cash_session_id,t.operator_id,
 'RECARGA_USUARIO'::text AS income_type,u.id AS user_id,u.name AS user_name,u.email AS user_email,
 COALESCE(u.document_type||' '||u.document_number,'') AS document,''::text AS plate,
 NULL::bigint AS visitor_pass_id,'user:'||u.id AS recipient_key
 FROM transactions t JOIN users u ON u.id=t.user_id WHERE t.type='RECARGA_PRESENCIAL'
 UNION ALL
 SELECT v.id,v.amount,v.created_at,v.point_name,v.reference,v.cash_session_id,v.operator_id,
 'PASE_DIARIO_VISITANTE',NULL::bigint,v.visitor_name,''::text,''::text,v.plate,
 v.id,'visitor:'||v.id FROM visitor_passes v;
