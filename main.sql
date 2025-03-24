-- Challenge 1
-- This challenge consists of three exercises that will test your ability to use the SQL RANK() function. You will use it to rank films by their length, their length within the rating category, and by the actor or actress who has acted in the greatest number of films.
use sakila;
-- 1. Rank films by their length and create an output table that includes the title, length, and rank columns only. Filter out any rows with null or zero values in the length column.
select 
	title
    , length
    , rank() over (order by length desc) as rank_length
from film
where length is not null and length > 0;


select * from film;

-- 2. Rank films by length within the rating category and create an output table that includes the title, length, rating and rank columns only. Filter out any rows with null or zero values in the length column.

select 
	title
    , length
    , rating
    , rank() over (partition by rating order by length desc) as rank_length
from film
where length is not null and length > 0; 

-- 3. Produce a list that shows for each film in the Sakila database, the actor or actress who has acted in the greatest number of films, as well as the total number of films in which they have acted. Hint: Use temporary tables, CTEs, or Views when appropiate to simplify your queries.
create view all_cast_for_films as
select 
	film_id
    , title
    , actor_id
    , first_name
    , last_name
    , count(film_id) over(partition by actor_id) as total_num_of_films
from film_actor
join film
	using (film_id)
join actor
	using (actor_id)
order by film_id, total_num_of_films desc
;

create view all_cast_for_films_with_range as
select *
	, rank () over(partition by film_id order by total_num_of_films desc) as top_actor_per_film
from all_cast_for_films
;

select 
	film_id,
    title,
    actor_id as most_performed_actor_id,
    first_name,
    last_name,
    total_num_of_films
from all_cast_for_films_with_range
where top_actor_per_film = 1;


-- second version

WITH all_cast_for_films AS (
    SELECT 
        film_id,
        title,
        actor_id,
        first_name,
        last_name,
        COUNT(film_id) OVER(PARTITION BY actor_id) AS total_num_of_films
    FROM film_actor
    JOIN film USING (film_id)
    JOIN actor USING (actor_id)
),
all_cast_for_films_with_range AS (
    SELECT *,
           RANK() OVER(PARTITION BY film_id ORDER BY total_num_of_films DESC) AS top_actor_per_film
    FROM all_cast_for_films
)
SELECT 
    film_id,
    title,
    actor_id AS most_performed_actor_id,
    first_name,
    last_name,
    total_num_of_films,
    top_actor_per_film
FROM all_cast_for_films_with_range
WHERE top_actor_per_film = 1
;

    

-- Challenge 2
-- This challenge involves analyzing customer activity and retention in the Sakila database to gain insight into business performance. By analyzing customer behavior over time, businesses can identify trends and make data-driven decisions to improve customer retention and increase revenue.

-- The goal of this exercise is to perform a comprehensive analysis of customer activity and retention by conducting an analysis on the monthly percentage change in the number of active customers and the number of retained customers. Use the Sakila database and progressively build queries to achieve the desired outcome.

-- Step 1. Retrieve the number of monthly active customers, i.e., the number of unique customers who rented a movie in each month.

select
	 DATE_FORMAT(CONVERT(rental_date,DATE), '%Y') AS rent_year
	,DATE_FORMAT(CONVERT(rental_date,DATE), '%m') AS rent_month
	,count(distinct customer_id) as num_of_customers
from rental
group by rent_year, rent_month
order by rent_year, rent_month
;

-- Step 2. Retrieve the number of active users in the previous month.
create view customers_m_to_m as

with monthly_rental as
(
	select
		 DATE_FORMAT(CONVERT(rental_date,DATE), '%Y') AS rent_year
		,DATE_FORMAT(CONVERT(rental_date,DATE), '%m') AS rent_month
		,count(distinct customer_id) as num_of_customers
	from rental
	group by rent_year, rent_month
	order by rent_year, rent_month
)
select 
*
, lag(num_of_customers) over (order by rent_year, rent_month) as num_of_custom_prev_month
from monthly_rental
group by rent_year, rent_month
order by rent_year, rent_month
;

select * from customers_m_to_m;

-- Step 3. Calculate the percentage change in the number of active customers between the current and previous month.
select *
, if (num_of_custom_prev_month is not null, round((num_of_customers - num_of_custom_prev_month)/num_of_custom_prev_month*100), 0)  as diff_percent
from customers_m_to_m;

-- Step 4. Calculate the number of retained customers every month, i.e., customers who rented movies in the current and previous months.
with monthly_customers as (
	select 
		 DATE_FORMAT(CONVERT(rental_date,DATE), '%Y') AS rent_year
		,DATE_FORMAT(CONVERT(rental_date,DATE), '%m') AS rent_month
		, customer_id
	from rental
	-- group by rent_year, rent_month
	order by rent_year, rent_month, customer_id
)
SELECT 
    curr.rent_year,
    curr.rent_month,
    COUNT(DISTINCT curr.customer_id) AS retained_customers
FROM monthly_customers AS curr
JOIN monthly_customers AS prev
    ON prev.customer_id = curr.customer_id
    AND (
        (prev.rent_year = curr.rent_year AND prev.rent_month = curr.rent_month - 1)
        OR (prev.rent_year = curr.rent_year - 1 AND prev.rent_month = 12 AND curr.rent_month = 1)
    )
GROUP BY curr.rent_year, curr.rent_month
ORDER BY curr.rent_year, curr.rent_month;
;

-- second ver
create or replace view customers_vs_month as
SELECT 
    customer_id,
    MAX(CASE WHEN rent_year = '2005' AND rent_month = '05' THEN 1 ELSE 0 END) AS y2005m05,
    MAX(CASE WHEN rent_year = '2005' AND rent_month = '06' THEN 1 ELSE 0 END) AS y2005m06,
    MAX(CASE WHEN rent_year = '2005' AND rent_month = '07' THEN 1 ELSE 0 END) AS y2005m07,
    MAX(CASE WHEN rent_year = '2005' AND rent_month = '08' THEN 1 ELSE 0 END) AS y2005m08
    
FROM (
    SELECT 
        customer_id,
        DATE_FORMAT(CONVERT(rental_date, DATE), '%Y') AS rent_year,
        DATE_FORMAT(CONVERT(rental_date, DATE), '%m') AS rent_month
    FROM rental
    GROUP BY customer_id, rent_year, rent_month
) AS rentals
GROUP BY customer_id
order by customer_id;

-- select * from customers_vs_month;

with m_to_m as
(
select
	customer_id, 
	(y2005m06*2 - y2005m05) % 2 as m06,
    (y2005m07*2 - y2005m06) % 2 as m07,
    (y2005m08*2 - y2005m07) % 2 as m08
from customers_vs_month
)
select 
	SUM(m06) AS total_m06,
    SUM(m07) AS total_m07,
    SUM(m08) AS total_m08
from m_to_m;

