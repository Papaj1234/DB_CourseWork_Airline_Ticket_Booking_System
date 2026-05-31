DROP SERVER IF EXISTS oltp_server CASCADE;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

CREATE SERVER oltp_server
	FOREIGN DATA WRAPPER postgres_fdw
	OPTIONS (host '127.0.0.1', port '1166', dbname 'postgres');

CREATE USER MAPPING FOR postgres
	SERVER oltp_server
	OPTIONS (user 'postgres', password 'postgres');

CREATE FOREIGN TABLE ft_country (
	country_code CHAR(2),
	country_name VARCHAR(100)
) SERVER oltp_server OPTIONS (schema_name 'public', table_name 'country');

CREATE FOREIGN TABLE ft_city (
	city_code CHAR(3),
	city_name VARCHAR(100),
	country_code CHAR(2)
) SERVER oltp_server OPTIONS (schema_name 'public', table_name 'city');

CREATE FOREIGN TABLE ft_airport (
	iata_code CHAR(3),
	airport_name VARCHAR(150),
	city_code CHAR(3),
	timezone VARCHAR(50)
) SERVER oltp_server OPTIONS (schema_name 'public', table_name 'airport');

CREATE FOREIGN TABLE ft_airline (
	iata_code CHAR(2),
	airline_name VARCHAR(150),
	country_code CHAR(2),
	is_active BOOLEAN
) SERVER oltp_server OPTIONS (schema_name 'public', table_name 'airline');

CREATE FOREIGN TABLE ft_aircraft (
	tail_number VARCHAR(10),
	model VARCHAR(50),
	total_seats SMALLINT,
	economy_seats SMALLINT,
	business_seats SMALLINT,
	first_seats SMALLINT,
	airline_code CHAR(2)
) SERVER oltp_server OPTIONS (schema_name 'public', table_name 'aircraft');

CREATE FOREIGN TABLE ft_route (
	route_code VARCHAR(10),
	origin_airport CHAR(3),
	destination_airport CHAR(3),
	distance_km SMALLINT
) SERVER oltp_server OPTIONS (schema_name 'public', table_name 'route');

CREATE FOREIGN TABLE ft_flight (
	flight_number VARCHAR(8),
	scheduled_date DATE,
	airline_code CHAR(2),
	route_code VARCHAR(10),
	tail_number VARCHAR(10),
	departure_time TIMESTAMPTZ,
	arrival_time TIMESTAMPTZ,
	status VARCHAR(20),
	delay_minutes SMALLINT
) SERVER oltp_server OPTIONS (schema_name 'public', table_name 'flight');

CREATE FOREIGN TABLE ft_passenger (
	passport_number VARCHAR(20),
	first_name VARCHAR(80),
	last_name VARCHAR(80),
	date_of_birth DATE,
	nationality CHAR(2),
	email VARCHAR(150),
	phone VARCHAR(20),
	created_at TIMESTAMPTZ
) SERVER oltp_server OPTIONS (schema_name 'public', table_name 'passenger');

CREATE FOREIGN TABLE ft_booking (
	booking_ref CHAR(6),
	passenger_passport VARCHAR(20),
	flight_number VARCHAR(8),
	scheduled_date DATE,
	booked_at TIMESTAMPTZ,
	total_amount NUMERIC(10,2),
	currency CHAR(3),
	payment_status VARCHAR(20),
	payment_method VARCHAR(20)
) SERVER oltp_server OPTIONS (schema_name 'public', table_name 'booking');

CREATE FOREIGN TABLE ft_ticket (
	ticket_number VARCHAR(14),
	booking_ref CHAR(6),
	seat_number VARCHAR(4),
	cabin_class VARCHAR(10),
	fare_basis VARCHAR(10),
	price NUMERIC(10,2),
	baggage_kg SMALLINT,
	ticket_status VARCHAR(20)
) SERVER oltp_server OPTIONS (schema_name 'public', table_name 'ticket');