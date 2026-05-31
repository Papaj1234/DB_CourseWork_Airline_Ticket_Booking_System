DROP TABLE IF EXISTS fact_ticket_sales CASCADE;
DROP TABLE IF EXISTS fact_flight_performance CASCADE;
DROP TABLE IF EXISTS bridge_booking_ticket CASCADE;
DROP TABLE IF EXISTS dim_passenger CASCADE;
DROP TABLE IF EXISTS dim_route CASCADE;
DROP TABLE IF EXISTS dim_airline CASCADE;
DROP TABLE IF EXISTS dim_aircraft CASCADE;
DROP TABLE IF EXISTS dim_time CASCADE;
DROP TABLE IF EXISTS dim_airport CASCADE;
DROP TABLE IF EXISTS dim_city CASCADE;
DROP TABLE IF EXISTS dim_country CASCADE;

CREATE TABLE dim_country (
	country_key SERIAL PRIMARY KEY,
	country_code CHAR(2) NOT NULL UNIQUE,
	country_name VARCHAR(100) NOT NULL
);

CREATE TABLE dim_city (
	city_key SERIAL PRIMARY KEY,
	city_code CHAR(3) NOT NULL UNIQUE,
	city_name VARCHAR(100) NOT NULL,
	country_key INTEGER NOT NULL REFERENCES dim_country(country_key)
);

CREATE TABLE dim_airport (
	airport_key SERIAL PRIMARY KEY,
	iata_code CHAR(3) NOT NULL UNIQUE,
	airport_name VARCHAR(150) NOT NULL,
	city_key INTEGER NOT NULL REFERENCES dim_city(city_key)
);

CREATE TABLE dim_route (
	route_key SERIAL PRIMARY KEY,
	route_code VARCHAR(10) NOT NULL UNIQUE,
	origin_airport_key INTEGER NOT NULL REFERENCES dim_airport(airport_key),
	destination_airport_key INTEGER NOT NULL REFERENCES dim_airport(airport_key),
	distance_km SMALLINT NOT NULL,
	CONSTRAINT chk_route_diff_airports CHECK (origin_airport_key <> destination_airport_key)
);

CREATE TABLE dim_airline (
	airline_key SERIAL PRIMARY KEY,
	iata_code CHAR(2) NOT NULL UNIQUE,
	airline_name VARCHAR(150) NOT NULL,
	country_key INTEGER NOT NULL REFERENCES dim_country(country_key)
);

CREATE TABLE dim_aircraft (
	aircraft_key SERIAL PRIMARY KEY,
	tail_number VARCHAR(10) NOT NULL UNIQUE,
	model VARCHAR(50) NOT NULL,
	total_seats SMALLINT NOT NULL,
	economy_seats SMALLINT NOT NULL,
	business_seats SMALLINT NOT NULL,
	first_seats SMALLINT NOT NULL DEFAULT 0,
	CONSTRAINT chk_aircraft_seats CHECK (economy_seats + business_seats + first_seats <= total_seats)
);

CREATE TABLE dim_time (
	time_id INTEGER PRIMARY KEY,
	full_date DATE NOT NULL,
	day_of_week SMALLINT NOT NULL,
	day_name VARCHAR(10) NOT NULL,
	month_num SMALLINT NOT NULL,
	month_name VARCHAR(10) NOT NULL,
	quarter SMALLINT NOT NULL,
	year SMALLINT NOT NULL,
	is_weekend BOOLEAN NOT NULL
);

CREATE TABLE dim_passenger (
	passenger_key SERIAL PRIMARY KEY,
	passport_number VARCHAR(20) NOT NULL,
	first_name VARCHAR(80) NOT NULL,
	last_name VARCHAR(80) NOT NULL,
	nationality CHAR(2) NOT NULL,
	email VARCHAR(150) NOT NULL,
	phone VARCHAR(20),
	valid_from DATE NOT NULL,
	valid_to DATE,
	is_current BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE fact_ticket_sales (
	ticket_sales_id SERIAL PRIMARY KEY,
	time_id INTEGER NOT NULL REFERENCES dim_time(time_id),
	passenger_key INTEGER NOT NULL REFERENCES dim_passenger(passenger_key),
	route_key INTEGER NOT NULL REFERENCES dim_route(route_key),
	airline_key INTEGER NOT NULL REFERENCES dim_airline(airline_key),
	aircraft_key INTEGER NOT NULL REFERENCES dim_aircraft(aircraft_key),
	flight_number VARCHAR(8) NOT NULL,
	booking_ref CHAR(6) NOT NULL,
	ticket_number VARCHAR(14) NOT NULL UNIQUE,
	cabin_class VARCHAR(10) NOT NULL,
	price NUMERIC(10,2) NOT NULL,
	baggage_kg SMALLINT NOT NULL,
	ticket_status VARCHAR(20) NOT NULL,
	payment_method VARCHAR(20),
	payment_status VARCHAR(20) NOT NULL,
	CONSTRAINT chk_fts_cabin CHECK (cabin_class IN ('ECONOMY','BUSINESS','FIRST')),
	CONSTRAINT chk_fts_ticket_status CHECK (ticket_status IN ('ISSUED','CHECKED_IN','BOARDED','USED','CANCELLED')),
	CONSTRAINT chk_fts_pay_method CHECK (payment_method IN ('CARD','BANK_TRANSFER','CASH')),
	CONSTRAINT chk_fts_pay_status CHECK (payment_status IN ('PENDING','PAID','REFUNDED','FAILED')),
	CONSTRAINT chk_fts_price CHECK (price >= 0),
	CONSTRAINT chk_fts_baggage CHECK (baggage_kg >= 0)
);

CREATE TABLE fact_flight_performance (
	flight_perf_id SERIAL PRIMARY KEY,
	time_id INTEGER NOT NULL REFERENCES dim_time(time_id),
	route_key INTEGER NOT NULL REFERENCES dim_route(route_key),
	airline_key INTEGER NOT NULL REFERENCES dim_airline(airline_key),
	aircraft_key INTEGER NOT NULL REFERENCES dim_aircraft(aircraft_key),
	flight_number VARCHAR(8) NOT NULL,
	status VARCHAR(20) NOT NULL,
	delay_minutes SMALLINT NOT NULL,
	tickets_sold SMALLINT NOT NULL,
	total_revenue NUMERIC(10,2) NOT NULL,
	UNIQUE (flight_number, time_id),
	CONSTRAINT chk_ffp_status CHECK (status IN ('SCHEDULED','BOARDING','DEPARTED','ARRIVED','CANCELLED','DELAYED')),
	CONSTRAINT chk_ffp_delay CHECK (delay_minutes >= 0),
	CONSTRAINT chk_ffp_tickets CHECK (tickets_sold >= 0),
	CONSTRAINT chk_ffp_revenue CHECK (total_revenue >= 0)
);

CREATE TABLE bridge_booking_ticket (
	bridge_id SERIAL PRIMARY KEY,
	booking_ref CHAR(6) NOT NULL,
	ticket_number VARCHAR(14) NOT NULL,
	passenger_key INTEGER NOT NULL REFERENCES dim_passenger(passenger_key),
	price NUMERIC(10,2) NOT NULL,
	cabin_class VARCHAR(10) NOT NULL,
	CONSTRAINT chk_bridge_cabin CHECK (cabin_class IN ('ECONOMY','BUSINESS','FIRST')),
	CONSTRAINT chk_bridge_price CHECK (price >= 0)
);