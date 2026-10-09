
\set ON_ERROR_STOP on

BEGIN;


CREATE TEMP TABLE raw_passenger (n INT GENERATED ALWAYS AS IDENTITY, c1 TEXT, c2 TEXT, c3 TEXT, c4 TEXT, c5 TEXT, c6 TEXT, c7 TEXT) ON COMMIT DROP;
CREATE TEMP TABLE raw_flight    (n INT GENERATED ALWAYS AS IDENTITY, c1 TEXT, c2 TEXT, c3 TEXT, c4 TEXT, c5 TEXT, c6 TEXT, c7 TEXT, c8 TEXT, c9 TEXT) ON COMMIT DROP;
CREATE TEMP TABLE raw_booking   (n INT GENERATED ALWAYS AS IDENTITY, c1 TEXT, c2 TEXT, c3 TEXT, c4 TEXT, c5 TEXT, c6 TEXT, c7 TEXT, c8 TEXT, c9 TEXT) ON COMMIT DROP;
CREATE TEMP TABLE raw_ticket    (n INT GENERATED ALWAYS AS IDENTITY, c1 TEXT, c2 TEXT, c3 TEXT, c4 TEXT, c5 TEXT, c6 TEXT, c7 TEXT, c8 TEXT) ON COMMIT DROP;
CREATE TEMP TABLE raw_reference (n INT GENERATED ALWAYS AS IDENTITY, c1 TEXT, c2 TEXT, c3 TEXT, c4 TEXT, c5 TEXT, c6 TEXT) ON COMMIT DROP;

\copy raw_passenger (c1,c2,c3,c4,c5,c6,c7)          FROM 'C:/pgdata/passenger.csv' WITH (FORMAT csv, ENCODING 'UTF8')
\copy raw_flight    (c1,c2,c3,c4,c5,c6,c7,c8,c9)    FROM 'C:/pgdata/flight.csv'    WITH (FORMAT csv, ENCODING 'UTF8')
\copy raw_booking   (c1,c2,c3,c4,c5,c6,c7,c8,c9)    FROM 'C:/pgdata/booking.csv'   WITH (FORMAT csv, ENCODING 'UTF8')
\copy raw_ticket    (c1,c2,c3,c4,c5,c6,c7,c8)       FROM 'C:/pgdata/ticket.csv'    WITH (FORMAT csv, ENCODING 'UTF8')
\copy raw_reference (c1,c2,c3,c4,c5,c6)             FROM 'C:/pgdata/reference.csv' WITH (FORMAT csv, ENCODING 'UTF8')


CREATE TEMP TABLE stg (tbl TEXT, n INT, c1 TEXT, c2 TEXT, c3 TEXT, c4 TEXT, c5 TEXT, c6 TEXT, c7 TEXT, c8 TEXT, c9 TEXT) ON COMMIT DROP;

INSERT INTO stg
WITH src AS (
    SELECT 'passenger' AS f, n, c1, c2, c3, c4, c5, c6, c7, NULL AS c8, NULL AS c9 FROM raw_passenger
    UNION ALL SELECT 'flight',    n, c1, c2, c3, c4, c5, c6, c7, c8, c9     FROM raw_flight
    UNION ALL SELECT 'booking',   n, c1, c2, c3, c4, c5, c6, c7, c8, c9     FROM raw_booking
    UNION ALL SELECT 'ticket',    n, c1, c2, c3, c4, c5, c6, c7, c8, NULL   FROM raw_ticket
    UNION ALL SELECT 'reference', n, c1, c2, c3, c4, c5, c6, NULL, NULL, NULL FROM raw_reference
),
lbl AS (            -- строки-метки: только первая ячейка заполнена
    SELECT f, n, btrim(replace(c1, E'\uFEFF', '')) AS tbl
    FROM src
    WHERE c1 IS NOT NULL AND c2 IS NULL
    UNION ALL       -- «виртуальная» метка в строке 0 = имя файла
    SELECT DISTINCT f, 0, f FROM src
),
tagged AS (
    SELECT s.*,
           (SELECT l.tbl FROM lbl l WHERE l.f = s.f AND l.n < s.n ORDER BY l.n DESC LIMIT 1) AS tbl,
           (SELECT l.n   FROM lbl l WHERE l.f = s.f AND l.n < s.n ORDER BY l.n DESC LIMIT 1) AS lbl_n
    FROM src s
    WHERE s.c1 IS NOT NULL AND s.c2 IS NOT NULL      -- без пустых строк и меток
)
SELECT tbl, n, c1, c2, c3, c4, c5, c6, c7, c8, c9
FROM tagged
WHERE n > lbl_n + 1;                                  -- без строки заголовка


CREATE TEMP TABLE load_log (tbl TEXT, inserted INT, updated INT) ON COMMIT DROP;

-- country
WITH up AS (
    INSERT INTO country (country_code, country_name)
    SELECT c1, c2 FROM stg WHERE tbl = 'country'
    ON CONFLICT (country_code) DO UPDATE
       SET country_name = EXCLUDED.country_name
     WHERE (country.country_name) IS DISTINCT FROM (EXCLUDED.country_name)
    RETURNING (xmax = 0) AS ins)
INSERT INTO load_log SELECT 'country', COUNT(*) FILTER (WHERE ins), COUNT(*) FILTER (WHERE NOT ins) FROM up;

-- city
WITH up AS (
    INSERT INTO city (city_code, city_name, country_code)
    SELECT c1, c2, c3 FROM stg WHERE tbl = 'city'
    ON CONFLICT (city_code) DO UPDATE
       SET city_name = EXCLUDED.city_name, country_code = EXCLUDED.country_code
     WHERE (city.city_name, city.country_code)
           IS DISTINCT FROM (EXCLUDED.city_name, EXCLUDED.country_code)
    RETURNING (xmax = 0) AS ins)
INSERT INTO load_log SELECT 'city', COUNT(*) FILTER (WHERE ins), COUNT(*) FILTER (WHERE NOT ins) FROM up;

-- airport
WITH up AS (
    INSERT INTO airport (iata_code, airport_name, city_code, timezone)
    SELECT c1, c2, c3, c4 FROM stg WHERE tbl = 'airport'
    ON CONFLICT (iata_code) DO UPDATE
       SET airport_name = EXCLUDED.airport_name, city_code = EXCLUDED.city_code, timezone = EXCLUDED.timezone
     WHERE (airport.airport_name, airport.city_code, airport.timezone)
           IS DISTINCT FROM (EXCLUDED.airport_name, EXCLUDED.city_code, EXCLUDED.timezone)
    RETURNING (xmax = 0) AS ins)
INSERT INTO load_log SELECT 'airport', COUNT(*) FILTER (WHERE ins), COUNT(*) FILTER (WHERE NOT ins) FROM up;

-- airline
WITH up AS (
    INSERT INTO airline (iata_code, airline_name, country_code, is_active)
    SELECT c1, c2, c3, c4::BOOLEAN FROM stg WHERE tbl = 'airline'
    ON CONFLICT (iata_code) DO UPDATE
       SET airline_name = EXCLUDED.airline_name, country_code = EXCLUDED.country_code, is_active = EXCLUDED.is_active
     WHERE (airline.airline_name, airline.country_code, airline.is_active)
           IS DISTINCT FROM (EXCLUDED.airline_name, EXCLUDED.country_code, EXCLUDED.is_active)
    RETURNING (xmax = 0) AS ins)
INSERT INTO load_log SELECT 'airline', COUNT(*) FILTER (WHERE ins), COUNT(*) FILTER (WHERE NOT ins) FROM up;

-- aircraft
WITH up AS (
    INSERT INTO aircraft (tail_number, model, total_seats, economy_seats, business_seats, airline_code)
    SELECT c1, c2, c3::SMALLINT, c4::SMALLINT, c5::SMALLINT, c6 FROM stg WHERE tbl = 'aircraft'
    ON CONFLICT (tail_number) DO UPDATE
       SET model = EXCLUDED.model, total_seats = EXCLUDED.total_seats, economy_seats = EXCLUDED.economy_seats,
           business_seats = EXCLUDED.business_seats, airline_code = EXCLUDED.airline_code
     WHERE (aircraft.model, aircraft.total_seats, aircraft.economy_seats, aircraft.business_seats, aircraft.airline_code)
           IS DISTINCT FROM (EXCLUDED.model, EXCLUDED.total_seats, EXCLUDED.economy_seats, EXCLUDED.business_seats, EXCLUDED.airline_code)
    RETURNING (xmax = 0) AS ins)
INSERT INTO load_log SELECT 'aircraft', COUNT(*) FILTER (WHERE ins), COUNT(*) FILTER (WHERE NOT ins) FROM up;

-- route
WITH up AS (
    INSERT INTO route (route_code, origin_airport, destination_airport, distance_km)
    SELECT c1, c2, c3, c4::SMALLINT FROM stg WHERE tbl = 'route'
    ON CONFLICT (route_code) DO UPDATE
       SET origin_airport = EXCLUDED.origin_airport, destination_airport = EXCLUDED.destination_airport,
           distance_km = EXCLUDED.distance_km
     WHERE (route.origin_airport, route.destination_airport, route.distance_km)
           IS DISTINCT FROM (EXCLUDED.origin_airport, EXCLUDED.destination_airport, EXCLUDED.distance_km)
    RETURNING (xmax = 0) AS ins)
INSERT INTO load_log SELECT 'route', COUNT(*) FILTER (WHERE ins), COUNT(*) FILTER (WHERE NOT ins) FROM up;

-- service
WITH up AS (
    INSERT INTO service (service_code, service_name, category, base_price)
    SELECT c1, c2, c3, c4::NUMERIC(10,2) FROM stg WHERE tbl = 'service'
    ON CONFLICT (service_code) DO UPDATE
       SET service_name = EXCLUDED.service_name, category = EXCLUDED.category, base_price = EXCLUDED.base_price
     WHERE (service.service_name, service.category, service.base_price)
           IS DISTINCT FROM (EXCLUDED.service_name, EXCLUDED.category, EXCLUDED.base_price)
    RETURNING (xmax = 0) AS ins)
INSERT INTO load_log SELECT 'service', COUNT(*) FILTER (WHERE ins), COUNT(*) FILTER (WHERE NOT ins) FROM up;

-- flight
WITH up AS (
    INSERT INTO flight (flight_number, scheduled_date, airline_code, route_code, tail_number,
                        departure_time, arrival_time, status, delay_minutes)
    SELECT c1, c2::DATE, c3, c4, c5, c6::TIMESTAMPTZ, c7::TIMESTAMPTZ, c8, c9::SMALLINT
    FROM stg WHERE tbl = 'flight'
    ON CONFLICT (flight_number, scheduled_date) DO UPDATE
       SET airline_code = EXCLUDED.airline_code, route_code = EXCLUDED.route_code, tail_number = EXCLUDED.tail_number,
           departure_time = EXCLUDED.departure_time, arrival_time = EXCLUDED.arrival_time,
           status = EXCLUDED.status, delay_minutes = EXCLUDED.delay_minutes
     WHERE (flight.airline_code, flight.route_code, flight.tail_number, flight.departure_time,
            flight.arrival_time, flight.status, flight.delay_minutes)
           IS DISTINCT FROM (EXCLUDED.airline_code, EXCLUDED.route_code, EXCLUDED.tail_number, EXCLUDED.departure_time,
            EXCLUDED.arrival_time, EXCLUDED.status, EXCLUDED.delay_minutes)
    RETURNING (xmax = 0) AS ins)
INSERT INTO load_log SELECT 'flight', COUNT(*) FILTER (WHERE ins), COUNT(*) FILTER (WHERE NOT ins) FROM up;

-- passenger
WITH up AS (
    INSERT INTO passenger (passport_number, first_name, last_name, date_of_birth, nationality, email, phone)
    SELECT c1, c2, c3, c4::DATE, c5, c6, c7 FROM stg WHERE tbl = 'passenger'
    ON CONFLICT (passport_number) DO UPDATE
       SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, date_of_birth = EXCLUDED.date_of_birth,
           nationality = EXCLUDED.nationality, email = EXCLUDED.email, phone = EXCLUDED.phone
     WHERE (passenger.first_name, passenger.last_name, passenger.date_of_birth,
            passenger.nationality, passenger.email, passenger.phone)
           IS DISTINCT FROM (EXCLUDED.first_name, EXCLUDED.last_name, EXCLUDED.date_of_birth,
            EXCLUDED.nationality, EXCLUDED.email, EXCLUDED.phone)
    RETURNING (xmax = 0) AS ins)
INSERT INTO load_log SELECT 'passenger', COUNT(*) FILTER (WHERE ins), COUNT(*) FILTER (WHERE NOT ins) FROM up;

-- booking
WITH up AS (
    INSERT INTO booking (booking_ref, passenger_passport, flight_number, scheduled_date, booked_at,
                         total_amount, currency, payment_status, payment_method)
    SELECT c1, c2, c3, c4::DATE, c5::TIMESTAMPTZ, c6::NUMERIC(10,2), c7, c8, c9
    FROM stg WHERE tbl = 'booking'
    ON CONFLICT (booking_ref) DO UPDATE
       SET passenger_passport = EXCLUDED.passenger_passport, flight_number = EXCLUDED.flight_number,
           scheduled_date = EXCLUDED.scheduled_date, booked_at = EXCLUDED.booked_at,
           total_amount = EXCLUDED.total_amount, currency = EXCLUDED.currency,
           payment_status = EXCLUDED.payment_status, payment_method = EXCLUDED.payment_method
     WHERE (booking.passenger_passport, booking.flight_number, booking.scheduled_date, booking.booked_at,
            booking.total_amount, booking.currency, booking.payment_status, booking.payment_method)
           IS DISTINCT FROM (EXCLUDED.passenger_passport, EXCLUDED.flight_number, EXCLUDED.scheduled_date, EXCLUDED.booked_at,
            EXCLUDED.total_amount, EXCLUDED.currency, EXCLUDED.payment_status, EXCLUDED.payment_method)
    RETURNING (xmax = 0) AS ins)
INSERT INTO load_log SELECT 'booking', COUNT(*) FILTER (WHERE ins), COUNT(*) FILTER (WHERE NOT ins) FROM up;

-- ticket
WITH up AS (
    INSERT INTO ticket (ticket_number, booking_ref, seat_number, cabin_class, fare_basis, price, baggage_kg, ticket_status)
    SELECT c1, c2, c3, c4, c5, c6::NUMERIC(10,2), c7::SMALLINT, c8 FROM stg WHERE tbl = 'ticket'
    ON CONFLICT (ticket_number) DO UPDATE
       SET booking_ref = EXCLUDED.booking_ref, seat_number = EXCLUDED.seat_number, cabin_class = EXCLUDED.cabin_class,
           fare_basis = EXCLUDED.fare_basis, price = EXCLUDED.price, baggage_kg = EXCLUDED.baggage_kg,
           ticket_status = EXCLUDED.ticket_status
     WHERE (ticket.booking_ref, ticket.seat_number, ticket.cabin_class, ticket.fare_basis,
            ticket.price, ticket.baggage_kg, ticket.ticket_status)
           IS DISTINCT FROM (EXCLUDED.booking_ref, EXCLUDED.seat_number, EXCLUDED.cabin_class, EXCLUDED.fare_basis,
            EXCLUDED.price, EXCLUDED.baggage_kg, EXCLUDED.ticket_status)
    RETURNING (xmax = 0) AS ins)
INSERT INTO load_log SELECT 'ticket', COUNT(*) FILTER (WHERE ins), COUNT(*) FILTER (WHERE NOT ins) FROM up;

-- ticket_service
WITH up AS (
    INSERT INTO ticket_service (ticket_number, service_code, quantity, price_paid)
    SELECT c1, c2, c3::SMALLINT, c4::NUMERIC(10,2) FROM stg WHERE tbl = 'ticket_service'
    ON CONFLICT (ticket_number, service_code) DO UPDATE
       SET quantity = EXCLUDED.quantity, price_paid = EXCLUDED.price_paid
     WHERE (ticket_service.quantity, ticket_service.price_paid)
           IS DISTINCT FROM (EXCLUDED.quantity, EXCLUDED.price_paid)
    RETURNING (xmax = 0) AS ins)
INSERT INTO load_log SELECT 'ticket_service', COUNT(*) FILTER (WHERE ins), COUNT(*) FILTER (WHERE NOT ins) FROM up;


SELECT tbl AS "table", inserted, updated FROM load_log;

COMMIT;
