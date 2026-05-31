SELECT
	dt.year,
	dt.month_num,
	dt.month_name,
	COUNT(fts.ticket_sales_id) AS tickets_sold,
	SUM(fts.price) AS total_revenue
FROM fact_ticket_sales fts
JOIN dim_time dt ON dt.time_id = fts.time_id
WHERE fts.ticket_status != 'CANCELLED'
GROUP BY dt.year, dt.month_num, dt.month_name
ORDER BY dt.year, dt.month_num;


SELECT
	da.airline_name,
	dc.country_name,
	COUNT(fts.ticket_sales_id) AS tickets_sold,
	SUM(fts.price) AS total_revenue,
	ROUND(AVG(fts.price), 2) AS avg_ticket_price
FROM fact_ticket_sales fts
JOIN dim_airline da ON da.airline_key = fts.airline_key
JOIN dim_country dc ON dc.country_key = da.country_key
WHERE fts.ticket_status != 'CANCELLED'
GROUP BY da.airline_name, dc.country_name
ORDER BY total_revenue DESC;


SELECT
	dr.route_code,
	co.city_name AS origin_city,
	cd.city_name AS destination_city,
	fts.cabin_class,
	COUNT(fts.ticket_sales_id) AS tickets_sold,
	SUM(fts.price) AS total_revenue
FROM fact_ticket_sales fts
JOIN dim_route dr ON dr.route_key = fts.route_key
JOIN dim_airport ao ON ao.airport_key = dr.origin_airport_key
JOIN dim_city co ON co.city_key = ao.city_key
JOIN dim_airport ad ON ad.airport_key = dr.destination_airport_key
JOIN dim_city cd ON cd.city_key = ad.city_key
WHERE fts.ticket_status != 'CANCELLED'
GROUP BY dr.route_code, co.city_name, cd.city_name, fts.cabin_class
ORDER BY dr.route_code, tickets_sold DESC;