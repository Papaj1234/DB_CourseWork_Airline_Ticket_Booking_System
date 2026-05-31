SELECT
	r.route_code,
	ap1.airport_name AS origin,
	ap2.airport_name AS destination,
	COUNT(t.ticket_number) AS tickets_sold,
	SUM(t.price) AS total_revenue
FROM route r
JOIN flight f ON f.route_code = r.route_code
JOIN booking b ON b.flight_number = f.flight_number AND b.scheduled_date = f.scheduled_date
JOIN ticket t ON t.booking_ref = b.booking_ref
JOIN airport ap1 ON ap1.iata_code = r.origin_airport
JOIN airport ap2 ON ap2.iata_code = r.destination_airport
WHERE t.ticket_status != 'CANCELLED'
GROUP BY r.route_code, ap1.airport_name, ap2.airport_name
ORDER BY total_revenue DESC;


SELECT
	p.passport_number,
	p.first_name,
	p.last_name,
	p.nationality,
	COUNT(b.booking_ref) AS total_flights,
	SUM(t.price) AS total_spent
FROM passenger p
JOIN booking b ON b.passenger_passport = p.passport_number
JOIN ticket t ON t.booking_ref = b.booking_ref
WHERE t.ticket_status != 'CANCELLED'
GROUP BY p.passport_number, p.first_name, p.last_name, p.nationality
ORDER BY total_flights DESC;


SELECT
	f.flight_number,
	f.scheduled_date,
	r.route_code,
	a.airline_name,
	f.delay_minutes,
	f.status
FROM flight f
JOIN route r ON r.route_code = f.route_code
JOIN airline a ON a.iata_code = f.airline_code
WHERE f.delay_minutes > 0
ORDER BY f.delay_minutes DESC;
