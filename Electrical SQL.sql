create database electronics;
use electronics;
show tables;
ALTER TABLE `customers - copy` RENAME TO customers;
select * from customers;
select * from products;
select * from orders;
select * from product_orders;

desc customers;
desc products;
desc orders;
desc product_orders;

#DATA CLEANING
#GIVING CONSTRAINT like PRIMARY KEY AND FOREIGN KEY TO THE TABLES
alter table customers modify customer_id int primary key auto_increment not null;
alter table products modify product_id int primary key auto_increment not null;
alter table orders modify order_id int primary key auto_increment not null;
alter table orders modify order_id int primary key auto_increment not null;


alter table orders
add constraint fk_customer
foreign key (customer_id) 
references customers(customer_id);

#FOUND THAT PRODUCT_ID IN PRODUCT_ORDERS ARE NOT MATCHING WITH PRODUCT_ID IN PRODUCTS
#TAKING NECESSARY STEPS

#FINDING PRODUCT_ID IN PRODUCT_ORDERS NOT IN PRODUCTS
SELECT DISTINCT product_id
FROM product_orders
WHERE product_id NOT IN (SELECT product_id FROM products);

#DELETING PRODUCT_ID IN PRODUCT_ORDERS NOT IN PRODUCTS
DELETE po
FROM product_orders po
LEFT JOIN products p ON po.product_id = p.product_id
WHERE p.product_id IS NULL;

alter table product_orders
add constraint fk_products
foreign key (product_id)
references products(product_id);

alter table product_orders
add constraint fk_orders
foreign key (order_id)
references orders(order_id);

#CHANGING DATE FORMAT
ALTER TABLE orders ADD COLUMN new_date DATE;

UPDATE orders
SET new_date = STR_TO_DATE(order_date, '%m/%d/%Y');
SELECT order_date, new_date FROM orders;
ALTER TABLE orders DROP COLUMN order_date;
alter table orders change new_date order_date date;






#ANALYSIS STARTS FROM HERE
#Time series analysis

#Total number of orders
SELECT COUNT(order_id) 
FROM orders;

#Total number of customers
SELECT COUNT(customer_id) AS Total_customers
FROM customers;

#Total number of product type
SELECT COUNT(DISTINCT product_type) AS product_types 
FROM products;

SELECT * FROM orders ORDER BY order_date;

#Compute Month wise tototal sales of products
SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    ROUND(SUM(po.quantity * po.unit_price)) AS total_sales
FROM orders o
JOIN product_orders po ON o.order_id = po.order_id
GROUP BY month
ORDER BY month;

#Sales trend over time
SELECT o.order_date,
    ROUND(SUM(po.quantity * po.unit_price)) AS daily_sales
FROM orders o
JOIN product_orders po ON o.order_id = po.order_id
GROUP BY o.order_date
ORDER BY o.order_date;

#Sales each quater
SELECT YEAR(o.order_date) AS year,
		QUARTER(o.order_date) AS quarter,
		ROUND(SUM(po.quantity * po.unit_price)) AS total_sales
FROM orders o
JOIN product_orders po ON o.order_id = po.order_id
GROUP BY year,quarter
ORDER BY year,quarter;

#Sales per year
SELECT YEAR(o.order_date) AS year,
    COUNT(o.order_id) AS total_orders
FROM orders o
GROUP BY year
ORDER BY year;

#Monthly average sales
SELECT 
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    ROUND(SUM(po.quantity * po.unit_price), 2) AS total_monthly_sales
FROM orders o
JOIN product_orders po ON o.order_id = po.order_id
GROUP BY month
ORDER BY month;

#Comparing this month sales to previous month sales
SELECT 
    month,
    total_sales,
    LAG(total_sales, 1, 0) OVER (ORDER BY month) AS previous_month_sales,
    total_sales - LAG(total_sales, 1, 0) OVER (ORDER BY month) AS month_on_month_change
FROM (SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
			ROUND(SUM(po.quantity * po.unit_price)) AS total_sales
    FROM orders o
    JOIN product_orders po ON o.order_id = po.order_id
    GROUP BY month
) AS sales_data
ORDER BY month;

#SALES ANALYSIS BY PRODUCT TYPE

#SHOW PRODUCTS AND THEIR COUNT
SELECT product_type,
       COUNT(product_type)
FROM products
GROUP BY product_type;

#Listing of different product names of each product type and their sales
SELECT YEAR(o.order_date) AS year,
		p.product_type,
		GROUP_CONCAT(DISTINCT p.product_name ORDER BY p.product_name SEPARATOR ', ') AS product_names,
		ROUND(SUM(po.quantity * po.unit_price)) AS total_sales
FROM orders o
JOIN product_orders po ON o.order_id = po.order_id
JOIN products p ON po.product_id = p.product_id
GROUP BY YEAR(o.order_date),p.product_type
ORDER BY YEAR(o.order_date),p.product_type;

#Total sales by product type
SELECT p.product_type,
		ROUND(SUM(po.quantity * po.unit_price)) AS total_sales
FROM product_orders po
JOIN products p ON po.product_id = p.product_id
GROUP BY p.product_type
ORDER BY total_sales DESC;

#Numbers of order per product type
SELECT p.product_type,
		COUNT(DISTINCT o.order_id) AS number_of_orders
FROM product_orders po
JOIN products p ON po.product_id = p.product_id
JOIN orders o ON po.order_id = o.order_id
GROUP BY p.product_type
ORDER BY number_of_orders DESC;

#Quaterly sales by product type
SELECT YEAR(o.order_date) AS year,
		QUARTER(o.order_date) AS quarter,
		p.product_type,
		ROUND(SUM(po.quantity * po.unit_price)) AS total_sales
FROM orders o
JOIN product_orders po ON o.order_id = po.order_id
JOIN products p ON po.product_id = p.product_id
GROUP BY year,quarter,p.product_type
ORDER BY year,quarter,p.product_type;

#Monthly sales trend by product type
SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
		p.product_type,
		ROUND(SUM(po.quantity * po.unit_price)) AS total_sales
FROM orders o
JOIN product_orders po ON o.order_id = po.order_id
JOIN products p ON po.product_id = p.product_id
GROUP BY month,p.product_type
ORDER BY month,p.product_type;

#Percentage distribution of Sales by prouct type
SELECT p.product_type,
		ROUND(SUM(po.quantity * po.unit_price)) AS total_sales,
		ROUND(SUM(po.quantity * po.unit_price) / (SELECT SUM(po2.quantity * po2.unit_price) 
        FROM product_orders po2) * 100,2) AS percentage_of_total
FROM product_orders po
JOIN products p ON po.product_id = p.product_id
GROUP BY p.product_type
ORDER BY total_sales DESC;


#Year over year sales growth by product type
SELECT current.year, current.product_type,ROUND(current.total_sales) AS current_year_sales,
		ROUND(COALESCE(previous.total_sales, 0)) AS previous_year_sales,
		ROUND((current.total_sales - COALESCE(previous.total_sales, 0)) / 
		COALESCE(previous.total_sales, 1) * 100,2) AS growth_rate
FROM 
    (SELECT YEAR(o.order_date) AS year, p.product_type, SUM(po.quantity * po.unit_price) AS total_sales
	FROM orders o
	JOIN product_orders po ON o.order_id = po.order_id
	JOIN products p ON po.product_id = p.product_id
	GROUP BY YEAR(o.order_date),p.product_type
    ) AS current
LEFT JOIN 
    (SELECT YEAR(o.order_date) AS year, p.product_type, SUM(po.quantity * po.unit_price) AS total_sales
	FROM orders o
	JOIN product_orders po ON o.order_id = po.order_id
	JOIN products p ON po.product_id = p.product_id
	GROUP BY YEAR(o.order_date),p.product_type
    ) AS previous 
    ON current.product_type = previous.product_type
    AND current.year = previous.year + 1
ORDER BY current.year,current.product_type;
    

