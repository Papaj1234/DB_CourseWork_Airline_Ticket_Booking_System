BEGIN;

SET session_replication_role = replica;


CREATE TEMP TABLE tmp_country (country_code CHAR(2), country_name VARCHAR(100)) ON COMMIT DROP;
\copy tmp_country FROM 'C:/pgdata/country.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO country SELECT * FROM tmp_country
ON CONFLICT (country_code) DO UPDATE SET
	country_name = EXCLUDED.country_name;


CREATE TEMP TABLE tmp_city (city_code CHAR(3), city_name VARCHAR(100), country_code CHAR(2)) ON COMMIT DROP;
\copy tmp_city FROM 'C:/pgdata/city.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO city SELECT * FROM tmp_city
ON CONFLICT (city_code) DO UPDATE SET
	city_name = EXCLUDED.city_name,
	country_code = EXCLUDED.country_code;


CREATE TEMP TABLE tmp_airport (iata_code CHAR(3), airport_name VARCHAR(150), city_code CHAR(3), timezone VARCHAR(50)) ON COMMIT DROP;
\copy tmp_airport FROM 'C:/pgdata/airport.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO airport SELECT * FROM tmp_airport
ON CONFLICT (iata_code) DO UPDATE SET
	airport_name = EXCLUDED.airport_name,
	city_code = EXCLUDED.city_code,
	timezone = EXCLUDED.timezone;


CREATE TEMP TABLE tmp_airline (iata_code CHAR(2), airline_name VARCHAR(150), country_code CHAR(2), is_active BOOLEAN) ON COMMIT DROP;
\copy tmp_airline FROM 'C:/pgdata/airline.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO airline SELECT * FROM tmp_airline
ON CONFLICT (iata_code) DO UPDATE SET
	airline_name = EXCLUDED.airline_name,
	country_code = EXCLUDED.country_code,
	is_active = EXCLUDED.is_active;


CREATE TEMP TABLE tmp_aircraft (tail_number VARCHAR(10), model VARCHAR(50), total_seats SMALLINT, economy_seats SMALLINT, business_seats SMALLINT, airline_code CHAR(2)) ON COMMIT DROP;
\copy tmp_aircraft FROM 'C:/pgdata/aircraft.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO aircraft (tail_number, model, total_seats, economy_seats, business_seats, airline_code)
SELECT * FROM tmp_aircraft
ON CONFLICT (tail_number) DO UPDATE SET
	model = EXCLUDED.model,
	total_seats = EXCLUDED.total_seats,
	economy_seats = EXCLUDED.economy_seats,
	business_seats = EXCLUDED.business_seats,
	airline_code = EXCLUDED.airline_code;


CREATE TEMP TABLE tmp_route (route_code VARCHAR(10), origin_airport CHAR(3), destination_airport CHAR(3), distance_km SMALLINT) ON COMMIT DROP;
\copy tmp_route FROM 'C:/pgdata/route.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO route SELECT * FROM tmp_route
ON CONFLICT (route_code) DO UPDATE SET
	origin_airport = EXCLUDED.origin_airport,
	destination_airport = EXCLUDED.destination_airport,
	distance_km = EXCLUDED.distance_km;


CREATE TEMP TABLE tmp_flight (flight_number VARCHAR(8), scheduled_date DATE, airline_code CHAR(2), route_code VARCHAR(10), tail_number VARCHAR(10), departure_time TIMESTAMPTZ, arrival_time TIMESTAMPTZ, status VARCHAR(20), delay_minutes SMALLINT) ON COMMIT DROP;
\copy tmp_flight FROM 'C:/pgdata/flight.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO flight (flight_number, scheduled_date, airline_code, route_code, tail_number, departure_time, arrival_time, status, delay_minutes)
SELECT * FROM tmp_flight
ON CONFLICT (flight_number, scheduled_date) DO UPDATE SET
	airline_code = EXCLUDED.airline_code,
	route_code = EXCLUDED.route_code,
	tail_number = EXCLUDED.tail_number,
	departure_time = EXCLUDED.departure_time,
	arrival_time = EXCLUDED.arrival_time,
	status = EXCLUDED.status,
	delay_minutes = EXCLUDED.delay_minutes;


CREATE TEMP TABLE tmp_passenger (passport_number VARCHAR(20), first_name VARCHAR(80), last_name VARCHAR(80), date_of_birth DATE, nationality CHAR(2), email VARCHAR(150), phone VARCHAR(20)) ON COMMIT DROP;
\copy tmp_passenger FROM 'C:/pgdata/passenger.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO passenger (passport_number, first_name, last_name, date_of_birth, nationality, email, phone)
SELECT * FROM tmp_passenger
ON CONFLICT (passport_number) DO UPDATE SET
	first_name = EXCLUDED.first_name,
	last_name = EXCLUDED.last_name,
	date_of_birth = EXCLUDED.date_of_birth,
	nationality = EXCLUDED.nationality,
	email = EXCLUDED.email,
	phone = EXCLUDED.phone;


CREATE TEMP TABLE tmp_booking (booking_ref CHAR(6), passenger_passport VARCHAR(20), flight_number VARCHAR(8), scheduled_date DATE, booked_at TIMESTAMPTZ, total_amount NUMERIC(10,2), currency CHAR(3), payment_status VARCHAR(20), payment_method VARCHAR(20)) ON COMMIT DROP;
\copy tmp_booking FROM 'C:/pgdata/booking.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO booking SELECT * FROM tmp_booking
ON CONFLICT (booking_ref) DO UPDATE SET
	passenger_passport = EXCLUDED.passenger_passport,
	flight_number = EXCLUDED.flight_number,
	scheduled_date = EXCLUDED.scheduled_date,
	booked_at = EXCLUDED.booked_at,
	total_amount = EXCLUDED.total_amount,
	currency = EXCLUDED.currency,
	payment_status = EXCLUDED.payment_status,
	payment_method = EXCLUDED.payment_method;


CREATE TEMP TABLE tmp_ticket (ticket_number VARCHAR(14), booking_ref CHAR(6), seat_number VARCHAR(4), cabin_class VARCHAR(10), fare_basis VARCHAR(10), price NUMERIC(10,2), baggage_kg SMALLINT, ticket_status VARCHAR(20)) ON COMMIT DROP;
\copy tmp_ticket FROM 'C:/pgdata/ticket.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO ticket SELECT * FROM tmp_ticket
ON CONFLICT (ticket_number) DO UPDATE SET
	booking_ref = EXCLUDED.booking_ref,
	seat_number = EXCLUDED.seat_number,
	cabin_class = EXCLUDED.cabin_class,
	fare_basis = EXCLUDED.fare_basis,
	price = EXCLUDED.price,
	baggage_kg = EXCLUDED.baggage_kg,
	ticket_status = EXCLUDED.ticket_status;


CREATE TEMP TABLE tmp_service (service_code VARCHAR(10), service_name VARCHAR(100), category VARCHAR(30), base_price NUMERIC(10,2)) ON COMMIT DROP;
\copy tmp_service FROM 'C:/pgdata/service.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO service SELECT * FROM tmp_service
ON CONFLICT (service_code) DO UPDATE SET
	service_name = EXCLUDED.service_name,
	category = EXCLUDED.category,
	base_price = EXCLUDED.base_price;


CREATE TEMP TABLE tmp_ticket_service (ticket_number VARCHAR(14), service_code VARCHAR(10), quantity SMALLINT, price_paid NUMERIC(10,2)) ON COMMIT DROP;
\copy tmp_ticket_service FROM 'C:/pgdata/ticket_service.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO ticket_service SELECT * FROM tmp_ticket_service
ON CONFLICT (ticket_number, service_code) DO UPDATE SET
	quantity = EXCLUDED.quantity,
	price_paid = EXCLUDED.price_paid;


SET session_replication_role = DEFAULT;

COMMIT;


SELECT 'country' AS tbl, COUNT(*) FROM country
UNION ALL SELECT 'city', COUNT(*) FROM city
UNION ALL SELECT 'airport', COUNT(*) FROM airport
UNION ALL SELECT 'airline', COUNT(*) FROM airline
UNION ALL SELECT 'aircraft', COUNT(*) FROM aircraft
UNION ALL SELECT 'route', COUNT(*) FROM route
UNION ALL SELECT 'flight', COUNT(*) FROM flight
UNION ALL SELECT 'passenger', COUNT(*) FROM passenger
UNION ALL SELECT 'booking', COUNT(*) FROM booking
UNION ALL SELECT 'ticket', COUNT(*) FROM ticket
UNION ALL SELECT 'service', COUNT(*) FROM service
UNION ALL SELECT 'ticket_service', COUNT(*) FROM ticket_service
ORDER BY tbl;