DROP TABLE IF EXISTS ticket_service CASCADE;
DROP TABLE IF EXISTS service CASCADE;
DROP TABLE IF EXISTS ticket CASCADE;
DROP TABLE IF EXISTS booking CASCADE;
DROP TABLE IF EXISTS passenger CASCADE;
DROP TABLE IF EXISTS flight CASCADE;
DROP TABLE IF EXISTS route CASCADE;
DROP TABLE IF EXISTS aircraft CASCADE;
DROP TABLE IF EXISTS airline CASCADE;
DROP TABLE IF EXISTS airport CASCADE;
DROP TABLE IF EXISTS city CASCADE;
DROP TABLE IF EXISTS country CASCADE;


CREATE TABLE country (
	country_code CHAR(2) PRIMARY KEY,
	country_name VARCHAR(100) NOT NULL UNIQUE
);


CREATE TABLE city (
	city_code CHAR(3) PRIMARY KEY,
	city_name VARCHAR(100) NOT NULL,
	country_code CHAR(2) NOT NULL REFERENCES country(country_code)
);


CREATE TABLE airport (
	iata_code CHAR(3) PRIMARY KEY,
	airport_name VARCHAR(150) NOT NULL,
	city_code CHAR(3) NOT NULL REFERENCES city(city_code),
	timezone VARCHAR(50) NOT NULL
);


CREATE TABLE airline (
	iata_code CHAR(2) PRIMARY KEY,
	airline_name VARCHAR(150) NOT NULL UNIQUE,
	country_code CHAR(2) NOT NULL REFERENCES country(country_code),
	is_active BOOLEAN NOT NULL DEFAULT TRUE
);


CREATE TABLE aircraft (
	tail_number VARCHAR(10) PRIMARY KEY,
	model VARCHAR(50) NOT NULL,
	total_seats SMALLINT NOT NULL CHECK (total_seats > 0),
	economy_seats SMALLINT NOT NULL CHECK (economy_seats >= 0),
	business_seats SMALLINT NOT NULL CHECK (business_seats >= 0),
	first_seats SMALLINT NOT NULL DEFAULT 0 CHECK (first_seats >= 0),
	airline_code CHAR(2) NOT NULL REFERENCES airline(iata_code),
	CONSTRAINT chk_seats CHECK (economy_seats + business_seats + first_seats <= total_seats)
);


CREATE TABLE route (
	route_code VARCHAR(10) PRIMARY KEY,
	origin_airport CHAR(3) NOT NULL REFERENCES airport(iata_code),
	destination_airport CHAR(3) NOT NULL REFERENCES airport(iata_code),
	distance_km SMALLINT NOT NULL CHECK (distance_km > 0),
	CONSTRAINT chk_different_airports CHECK (origin_airport <> destination_airport),
	CONSTRAINT uq_route_airports UNIQUE (origin_airport, destination_airport)
);


CREATE TABLE flight (
	flight_number VARCHAR(8) NOT NULL,
	scheduled_date DATE NOT NULL,
	airline_code CHAR(2) NOT NULL REFERENCES airline(iata_code),
	route_code VARCHAR(10) NOT NULL REFERENCES route(route_code),
	tail_number VARCHAR(10) NOT NULL REFERENCES aircraft(tail_number),
	departure_time TIMESTAMPTZ NOT NULL,
	arrival_time TIMESTAMPTZ NOT NULL,
	status VARCHAR(20) NOT NULL DEFAULT 'SCHEDULED' CHECK (status IN ('SCHEDULED','BOARDING','DEPARTED','ARRIVED','CANCELLED','DELAYED')),
	delay_minutes SMALLINT NOT NULL DEFAULT 0 CHECK (delay_minutes >= 0),
	PRIMARY KEY (flight_number, scheduled_date),
	CONSTRAINT chk_times CHECK (arrival_time > departure_time)
);


CREATE TABLE passenger (
	passport_number VARCHAR(20) PRIMARY KEY,
	first_name VARCHAR(80) NOT NULL,
	last_name VARCHAR(80) NOT NULL,
	date_of_birth DATE NOT NULL,
	nationality CHAR(2) NOT NULL REFERENCES country(country_code),
	email VARCHAR(150) NOT NULL UNIQUE,
	phone VARCHAR(20),
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE booking (
	booking_ref CHAR(6) PRIMARY KEY,
	passenger_passport VARCHAR(20) NOT NULL REFERENCES passenger(passport_number),
	flight_number VARCHAR(8) NOT NULL,
	scheduled_date DATE NOT NULL,
	booked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),
	currency CHAR(3) NOT NULL DEFAULT 'EUR',
	payment_status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING','PAID','REFUNDED','FAILED')),
	payment_method VARCHAR(20) CHECK (payment_method IN ('CARD','BANK_TRANSFER','CASH')),
	FOREIGN KEY (flight_number, scheduled_date) REFERENCES flight(flight_number, scheduled_date)
);


CREATE TABLE ticket (
	ticket_number VARCHAR(14) PRIMARY KEY,
	booking_ref CHAR(6) NOT NULL REFERENCES booking(booking_ref),
	seat_number VARCHAR(4) NOT NULL,
	cabin_class VARCHAR(10) NOT NULL CHECK (cabin_class IN ('ECONOMY','BUSINESS','FIRST')),
	fare_basis VARCHAR(10),
	price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
	baggage_kg SMALLINT NOT NULL DEFAULT 0 CHECK (baggage_kg >= 0),
	ticket_status VARCHAR(20) NOT NULL DEFAULT 'ISSUED' CHECK (ticket_status IN ('ISSUED','CHECKED_IN','BOARDED','USED','CANCELLED'))
);


CREATE TABLE service (
	service_code VARCHAR(10) PRIMARY KEY,
	service_name VARCHAR(100) NOT NULL UNIQUE,
	category VARCHAR(30) NOT NULL CHECK (category IN ('BAGGAGE','MEAL','SEAT','INSURANCE','PRIORITY','OTHER')),
	base_price NUMERIC(10,2) NOT NULL CHECK (base_price >= 0)
);


CREATE TABLE ticket_service (
	ticket_number VARCHAR(14) NOT NULL REFERENCES ticket(ticket_number),
	service_code VARCHAR(10) NOT NULL REFERENCES service(service_code),
	quantity SMALLINT NOT NULL DEFAULT 1 CHECK (quantity > 0),
	price_paid NUMERIC(10,2) NOT NULL CHECK (price_paid >= 0),
	PRIMARY KEY (ticket_number, service_code)
);

CREATE INDEX idx_flight_route ON flight(route_code);
CREATE INDEX idx_flight_airline ON flight(airline_code);
CREATE INDEX idx_flight_departure ON flight(departure_time);
CREATE INDEX idx_booking_passenger ON booking(passenger_passport);
CREATE INDEX idx_booking_flight ON booking(flight_number, scheduled_date);
CREATE INDEX idx_ticket_booking ON ticket(booking_ref);
CREATE INDEX idx_ticket_status ON ticket(ticket_status);
CREATE INDEX idx_ticket_service_service ON ticket_service(service_code);