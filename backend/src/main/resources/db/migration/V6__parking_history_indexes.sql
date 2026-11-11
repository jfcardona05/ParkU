CREATE INDEX parking_visits_owner ON parking_visits(user_id,id);
CREATE INDEX parking_operations_visit ON parking_operations(visit_id,id DESC);
