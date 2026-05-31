INSERT INTO dim_country (country_code, country_name)
SELECT country_code, country_name
FROM ft_country
ON CONFLICT (country_code) DO NOTHING;


INSERT INTO dim_city (city_code, city_name, country_key)
SELECT
	c.city_code,
	c.city_name,
	dc.country_key
FROM ft_city c
JOIN dim_country dc ON dc.country_code = c.country_code
ON CONFLICT (city_code) DO NOTHING;


INSERT INTO dim_airport (iata_code, airport_name, city_key)
SELECT
	a.iata_code,
	a.airport_name,
	dci.city_key
FROM ft_airport a
JOIN dim_city dci ON dci.city_code = a.city_code
ON CONFLICT (iata_code) DO NOTHING;


INSERT INTO dim_route (route_code, origin_airport_key, destination_airport_key, distance_km)
SELECT
	r.route_code,
	dao.airport_key,
	dad.airport_key,
	r.distance_km
FROM ft_route r
JOIN dim_airport dao ON dao.iata_code = r.origin_airport
JOIN dim_airport dad ON dad.iata_code = r.destination_airport
ON CONFLICT (route_code) DO NOTHING;


INSERT INTO dim_airline (iata_code, airline_name, country_key)
SELECT
	a.iata_code,
	a.airline_name,
	dc.country_key
FROM ft_airline a
JOIN dim_country dc ON dc.country_code = a.country_code
ON CONFLICT (iata_code) DO NOTHING;


INSERT INTO dim_aircraft (tail_number, model, total_seats, economy_seats, business_seats)
SELECT tail_number, model, total_seats, economy_seats, business_seats
FROM ft_aircraft
ON CONFLICT (tail_number) DO NOTHING;


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
FROM ft_passenger p
WHERE NOT EXISTS (
	SELECT 1 FROM dim_passenger dp
	WHERE dp.passport_number = p.passport_number
	AND dp.email = p.email
	AND dp.is_current = TRUE
);


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
FROM ft_ticket t
JOIN ft_booking b ON b.booking_ref = t.booking_ref
JOIN ft_flight f ON f.flight_number = b.flight_number AND f.scheduled_date = b.scheduled_date
JOIN dim_passenger dp ON dp.passport_number = b.passenger_passport AND dp.is_current = TRUE
JOIN dim_route dr ON dr.route_code = f.route_code
JOIN dim_airline da ON da.iata_code = f.airline_code
JOIN dim_aircraft dac ON dac.tail_number = f.tail_number
ON CONFLICT (ticket_number) DO NOTHING;


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
LEFT JOIN ft_ticket t ON t.booking_ref = b.booking_ref AND t.ticket_status != 'CANCELLED'
GROUP BY
	f.scheduled_date, f.flight_number, f.status, f.delay_minutes,
	dr.route_key, da.airline_key, dac.aircraft_key
ON CONFLICT (flight_number, time_id) DO NOTHING;


INSERT INTO bridge_booking_ticket (booking_ref, ticket_number, passenger_key, price, cabin_class)
SELECT
	t.booking_ref,
	t.ticket_number,
	dp.passenger_key,
	t.price,
	t.cabin_class
FROM ft_ticket t
JOIN ft_booking b ON b.booking_ref = t.booking_ref
JOIN dim_passenger dp ON dp.passport_number = b.passenger_passport AND dp.is_current = TRUE
WHERE NOT EXISTS (
	SELECT 1 FROM bridge_booking_ticket bbt
	WHERE bbt.ticket_number = t.ticket_number
);