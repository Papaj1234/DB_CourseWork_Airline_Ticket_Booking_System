BEGIN;


CREATE TEMP TABLE ref_value (domain TEXT, value TEXT) ON COMMIT DROP;
INSERT INTO ref_value VALUES
	('ticket_status', 'ISSUED'), ('ticket_status', 'CHECKED_IN'), ('ticket_status', 'BOARDED'),
	('ticket_status', 'USED'),   ('ticket_status', 'CANCELLED'),
	('cabin_class', 'ECONOMY'),  ('cabin_class', 'BUSINESS'),    ('cabin_class', 'FIRST');


CREATE TEMP TABLE stg_passenger ON COMMIT DROP AS
SELECT TRIM(passport_number) AS passport_number, TRIM(first_name) AS first_name, TRIM(last_name) AS last_name,
       UPPER(TRIM(nationality)) AS nationality, LOWER(TRIM(email)) AS email, TRIM(phone) AS phone
FROM ft_passenger;

CREATE TEMP TABLE stg_ticket ON COMMIT DROP AS
SELECT TRIM(ticket_number) AS ticket_number, booking_ref, UPPER(TRIM(cabin_class)) AS cabin_class,
       price, baggage_kg, UPPER(TRIM(ticket_status)) AS ticket_status
FROM ft_ticket;


CREATE TEMP TABLE etl_reject (tbl TEXT, record_key TEXT, reason TEXT) ON COMMIT DROP;

WITH bad AS (
	DELETE FROM stg_passenger p
	WHERE p.email NOT LIKE '%_@_%.__%'
	   OR p.nationality NOT IN (SELECT country_code FROM ft_country)
	RETURNING p.passport_number)
INSERT INTO etl_reject SELECT 'passenger', passport_number, 'invalid email or unknown nationality' FROM bad;

WITH bad AS (
	DELETE FROM stg_ticket t
	WHERE t.price < 0 OR t.baggage_kg < 0
	   OR t.ticket_status NOT IN (SELECT value FROM ref_value WHERE domain = 'ticket_status')
	   OR t.cabin_class   NOT IN (SELECT value FROM ref_value WHERE domain = 'cabin_class')
	RETURNING t.ticket_number)
INSERT INTO etl_reject SELECT 'ticket', ticket_number, 'negative price/baggage or unknown status/class' FROM bad;



INSERT INTO dim_country (country_code, country_name)
SELECT country_code, country_name
FROM ft_country
ON CONFLICT (country_code) DO UPDATE
	SET country_name = EXCLUDED.country_name
	WHERE dim_country.country_name IS DISTINCT FROM EXCLUDED.country_name;


INSERT INTO dim_city (city_code, city_name, country_key)
SELECT
	c.city_code,
	c.city_name,
	dc.country_key
FROM ft_city c
JOIN dim_country dc ON dc.country_code = c.country_code
ON CONFLICT (city_code) DO UPDATE
	SET city_name   = EXCLUDED.city_name,
	    country_key = EXCLUDED.country_key
	WHERE (dim_city.city_name, dim_city.country_key)
	      IS DISTINCT FROM (EXCLUDED.city_name, EXCLUDED.country_key);


INSERT INTO dim_airport (iata_code, airport_name, city_key)
SELECT
	a.iata_code,
	a.airport_name,
	dci.city_key
FROM ft_airport a
JOIN dim_city dci ON dci.city_code = a.city_code
ON CONFLICT (iata_code) DO UPDATE
	SET airport_name = EXCLUDED.airport_name,
	    city_key     = EXCLUDED.city_key
	WHERE (dim_airport.airport_name, dim_airport.city_key)
	      IS DISTINCT FROM (EXCLUDED.airport_name, EXCLUDED.city_key);


INSERT INTO dim_route (route_code, origin_airport_key, destination_airport_key, distance_km)
SELECT
	r.route_code,
	dao.airport_key,
	dad.airport_key,
	r.distance_km
FROM ft_route r
JOIN dim_airport dao ON dao.iata_code = r.origin_airport
JOIN dim_airport dad ON dad.iata_code = r.destination_airport
ON CONFLICT (route_code) DO UPDATE
	SET origin_airport_key      = EXCLUDED.origin_airport_key,
	    destination_airport_key = EXCLUDED.destination_airport_key,
	    distance_km             = EXCLUDED.distance_km
	WHERE (dim_route.origin_airport_key, dim_route.destination_airport_key, dim_route.distance_km)
	      IS DISTINCT FROM (EXCLUDED.origin_airport_key, EXCLUDED.destination_airport_key, EXCLUDED.distance_km);


INSERT INTO dim_airline (iata_code, airline_name, country_key)
SELECT
	a.iata_code,
	a.airline_name,
	dc.country_key
FROM ft_airline a
JOIN dim_country dc ON dc.country_code = a.country_code
ON CONFLICT (iata_code) DO UPDATE
	SET airline_name = EXCLUDED.airline_name,
	    country_key  = EXCLUDED.country_key
	WHERE (dim_airline.airline_name, dim_airline.country_key)
	      IS DISTINCT FROM (EXCLUDED.airline_name, EXCLUDED.country_key);


INSERT INTO dim_aircraft (tail_number, model, total_seats, economy_seats, business_seats)
SELECT tail_number, model, total_seats, economy_seats, business_seats
FROM ft_aircraft
ON CONFLICT (tail_number) DO UPDATE
	SET model          = EXCLUDED.model,
	    total_seats    = EXCLUDED.total_seats,
	    economy_seats  = EXCLUDED.economy_seats,
	    business_seats = EXCLUDED.business_seats
	WHERE (dim_aircraft.model, dim_aircraft.total_seats, dim_aircraft.economy_seats, dim_aircraft.business_seats)
	      IS DISTINCT FROM (EXCLUDED.model, EXCLUDED.total_seats, EXCLUDED.economy_seats, EXCLUDED.business_seats);


INSERT INTO dim_time (time_id, full_date, day_of_week, day_name, month_num, month_name, quarter, year, is_weekend)
SELECT DISTINCT
	TO_CHAR(scheduled_date, 'YYYYMMDD')::INTEGER,
	scheduled_date,
	EXTRACT(DOW FROM scheduled_date)::SMALLINT,
	TO_CHAR(scheduled_date, 'Day'),
	EXTRACT(MONTH FROM scheduled_date)::SMALLINT,
	TO_CHAR(scheduled_date, 'Month'),
	EXTRACT(QUARTER FROM scheduled_date)::SMALLINT,
	EXTRACT(YEAR FROM scheduled_date)::SMALLINT,
	EXTRACT(DOW FROM scheduled_date) IN (0, 6)
FROM ft_flight
ON CONFLICT (time_id) DO NOTHING;


UPDATE dim_passenger dp
SET valid_to   = CURRENT_DATE,
    is_current = FALSE
FROM stg_passenger p
WHERE dp.passport_number = p.passport_number
  AND dp.is_current = TRUE
  AND (dp.first_name, dp.last_name, dp.nationality, dp.email, dp.phone)
      IS DISTINCT FROM (p.first_name, p.last_name, p.nationality, p.email, p.phone);


INSERT INTO dim_passenger (passport_number, first_name, last_name, nationality, email, phone, valid_from, valid_to, is_current)
SELECT
	p.passport_number,
	p.first_name,
	p.last_name,
	p.nationality,
	p.email,
	p.phone,
	CURRENT_DATE,
	NULL,
	TRUE
FROM stg_passenger p
WHERE NOT EXISTS (
	SELECT 1 FROM dim_passenger dp
	WHERE dp.passport_number = p.passport_number
	AND dp.is_current = TRUE
);


INSERT INTO dim_service (service_code, service_name, category, base_price)
SELECT service_code, service_name, category, base_price
FROM ft_service
ON CONFLICT (service_code) DO UPDATE
	SET service_name = EXCLUDED.service_name,
	    category     = EXCLUDED.category,
	    base_price   = EXCLUDED.base_price
	WHERE (dim_service.service_name, dim_service.category, dim_service.base_price)
	      IS DISTINCT FROM (EXCLUDED.service_name, EXCLUDED.category, EXCLUDED.base_price);



INSERT INTO fact_ticket_sales (
	time_id, passenger_key, route_key, airline_key, aircraft_key,
	flight_number, booking_ref, ticket_number, cabin_class, price, baggage_kg,
	ticket_status, payment_method, payment_status
)
SELECT
	TO_CHAR(f.scheduled_date, 'YYYYMMDD')::INTEGER,
	dp.passenger_key,
	dr.route_key,
	da.airline_key,
	dac.aircraft_key,
	f.flight_number,
	b.booking_ref,
	t.ticket_number,
	t.cabin_class,
	t.price,
	t.baggage_kg,
	t.ticket_status,
	b.payment_method,
	b.payment_status
FROM stg_ticket t
JOIN ft_booking b ON b.booking_ref = t.booking_ref
JOIN ft_flight f ON f.flight_number = b.flight_number AND f.scheduled_date = b.scheduled_date
JOIN dim_passenger dp ON dp.passport_number = b.passenger_passport AND dp.is_current = TRUE
JOIN dim_route dr ON dr.route_code = f.route_code
JOIN dim_airline da ON da.iata_code = f.airline_code
JOIN dim_aircraft dac ON dac.tail_number = f.tail_number
ON CONFLICT (ticket_number) DO UPDATE
	SET time_id        = EXCLUDED.time_id,
	    route_key      = EXCLUDED.route_key,
	    airline_key    = EXCLUDED.airline_key,
	    aircraft_key   = EXCLUDED.aircraft_key,
	    flight_number  = EXCLUDED.flight_number,
	    booking_ref    = EXCLUDED.booking_ref,
	    cabin_class    = EXCLUDED.cabin_class,
	    price          = EXCLUDED.price,
	    baggage_kg     = EXCLUDED.baggage_kg,
	    ticket_status  = EXCLUDED.ticket_status,
	    payment_method = EXCLUDED.payment_method,
	    payment_status = EXCLUDED.payment_status
	WHERE (fact_ticket_sales.time_id, fact_ticket_sales.route_key, fact_ticket_sales.airline_key,
	       fact_ticket_sales.aircraft_key, fact_ticket_sales.flight_number, fact_ticket_sales.booking_ref,
	       fact_ticket_sales.cabin_class, fact_ticket_sales.price, fact_ticket_sales.baggage_kg,
	       fact_ticket_sales.ticket_status, fact_ticket_sales.payment_method, fact_ticket_sales.payment_status)
	      IS DISTINCT FROM
	      (EXCLUDED.time_id, EXCLUDED.route_key, EXCLUDED.airline_key,
	       EXCLUDED.aircraft_key, EXCLUDED.flight_number, EXCLUDED.booking_ref,
	       EXCLUDED.cabin_class, EXCLUDED.price, EXCLUDED.baggage_kg,
	       EXCLUDED.ticket_status, EXCLUDED.payment_method, EXCLUDED.payment_status);


INSERT INTO fact_flight_performance (
	time_id, route_key, airline_key, aircraft_key,
	flight_number, status, delay_minutes, tickets_sold, total_revenue
)
SELECT
	TO_CHAR(f.scheduled_date, 'YYYYMMDD')::INTEGER,
	dr.route_key,
	da.airline_key,
	dac.aircraft_key,
	f.flight_number,
	f.status,
	f.delay_minutes,
	COUNT(t.ticket_number),
	COALESCE(SUM(t.price), 0)
FROM ft_flight f
JOIN dim_route dr ON dr.route_code = f.route_code
JOIN dim_airline da ON da.iata_code = f.airline_code
JOIN dim_aircraft dac ON dac.tail_number = f.tail_number
LEFT JOIN ft_booking b ON b.flight_number = f.flight_number AND b.scheduled_date = f.scheduled_date
LEFT JOIN stg_ticket t ON t.booking_ref = b.booking_ref AND t.ticket_status != 'CANCELLED'
GROUP BY
	f.scheduled_date, f.flight_number, f.status, f.delay_minutes,
	dr.route_key, da.airline_key, dac.aircraft_key
ON CONFLICT (flight_number, time_id) DO UPDATE
	SET route_key     = EXCLUDED.route_key,
	    airline_key   = EXCLUDED.airline_key,
	    aircraft_key  = EXCLUDED.aircraft_key,
	    status        = EXCLUDED.status,
	    delay_minutes = EXCLUDED.delay_minutes,
	    tickets_sold  = EXCLUDED.tickets_sold,
	    total_revenue = EXCLUDED.total_revenue
	WHERE (fact_flight_performance.route_key, fact_flight_performance.airline_key, fact_flight_performance.aircraft_key,
	       fact_flight_performance.status, fact_flight_performance.delay_minutes,
	       fact_flight_performance.tickets_sold, fact_flight_performance.total_revenue)
	      IS DISTINCT FROM
	      (EXCLUDED.route_key, EXCLUDED.airline_key, EXCLUDED.aircraft_key,
	       EXCLUDED.status, EXCLUDED.delay_minutes,
	       EXCLUDED.tickets_sold, EXCLUDED.total_revenue);


INSERT INTO bridge_ticket_service (ticket_number, service_key, quantity, price_paid)
SELECT
    ts.ticket_number,
    ds.service_key,
    ts.quantity,
    ts.price_paid
FROM ft_ticket_service ts
JOIN dim_service ds ON ds.service_code = ts.service_code
ON CONFLICT (ticket_number, service_key) DO UPDATE
	SET quantity   = EXCLUDED.quantity,
	    price_paid = EXCLUDED.price_paid
	WHERE (bridge_ticket_service.quantity, bridge_ticket_service.price_paid)
	      IS DISTINCT FROM (EXCLUDED.quantity, EXCLUDED.price_paid);



UPDATE fact_ticket_service fsv
SET time_id    = TO_CHAR(f.scheduled_date, 'YYYYMMDD')::INTEGER,
    quantity   = bts.quantity,
    price_paid = bts.price_paid
FROM bridge_ticket_service bts
JOIN stg_ticket t ON t.ticket_number = bts.ticket_number
JOIN ft_booking b ON b.booking_ref = t.booking_ref
JOIN ft_flight f ON f.flight_number = b.flight_number AND f.scheduled_date = b.scheduled_date
WHERE fsv.ticket_number = bts.ticket_number
  AND fsv.service_key = bts.service_key
  AND (fsv.time_id, fsv.quantity, fsv.price_paid)
      IS DISTINCT FROM (TO_CHAR(f.scheduled_date, 'YYYYMMDD')::INTEGER, bts.quantity, bts.price_paid);


INSERT INTO fact_ticket_service (ticket_number, service_key, time_id, passenger_key, quantity, price_paid)
SELECT
    bts.ticket_number,
    bts.service_key,
    TO_CHAR(f.scheduled_date, 'YYYYMMDD')::INTEGER,
    dp.passenger_key,
    bts.quantity,
    bts.price_paid
FROM bridge_ticket_service bts
JOIN stg_ticket t ON t.ticket_number = bts.ticket_number
JOIN ft_booking b ON b.booking_ref = t.booking_ref
JOIN ft_flight f ON f.flight_number = b.flight_number AND f.scheduled_date = b.scheduled_date
JOIN dim_passenger dp ON dp.passport_number = b.passenger_passport AND dp.is_current = TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM fact_ticket_service fsv
    WHERE fsv.ticket_number = bts.ticket_number
    AND fsv.service_key = bts.service_key
);



SELECT tbl AS "table", record_key, reason FROM etl_reject ORDER BY tbl, record_key;

COMMIT;