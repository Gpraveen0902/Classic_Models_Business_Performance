/*
*********************************** Business Performance Analysis Project – ClassicModels *************************************

This project uses the ClassicModels sample database to perform real-world business analysis with SQL.  
The goal is to uncover **key business insights** across sales, finance, logistics, customers, and product performance.

The analysis highlights:
✓ Customer activity and top revenue contributors  
✓ Sales trends, seasonal growth, and product demand  
✓ Profitability by product line and per-unit margins  
✓ Employee and sales rep performance  
✓ Delivery speed by country  
✓ Payment patterns, pending balances, and risks  

Why this project matters:  
This project shows how raw transactional data can be turned into **actionable business insights**.  
It simulates real-world business problems such as customer churn, seasonality in sales, logistics efficiency, and financial risk.  
These insights can help businesses improve decision-making, strengthen customer relationships, and grow profits sustainably.
*/


use classicmodels;

SELECT * FROM employees;
SELECT * FROM offices;
SELECT * FROM products;
SELECT * FROM productlines;
SELECT * FROM orders;
SELECT * FROM orderdetails;
SELECT * FROM customers;
SELECT * FROM payments;

####################################################### DATA MANIPULATION #####################################################

-- Add a computed column 'price' to orderdetails  
-- This stores the total sales value for each order line (quantityOrdered * priceEach)  
-- It makes revenue and profit calculations easier in later queries.

ALTER TABLE orderdetails
ADD COLUMN price DECIMAL(10,2) GENERATED ALWAYS AS (quantityOrdered * priceEach) STORED;

############################################################## KPI's ###########################################################

-- Total Sales

SELECT
	SUM(quantityOrdered) AS total_sales
FROM
	orderdetails;

-- Total Revenue

SELECT
	SUM(amount) AS total_revenue
FROM
	payments;
    
    
-- Total Profit

SELECT
	ROUND(SUM(od.price) - SUM(od.quantityOrdered * p.buyprice), 2) AS total_profit
FROM
	orderdetails od
		JOIN
	products p ON od.productCode = p.productCode;


-- Top Customer

SELECT
	o.customerNumber,
    c.customerName,
    SUM(od.price) AS total_purchase
FROM
	customers c
		JOIN
	orders o ON c.customerNumber = o.customerNumber
		JOIN
	orderdetails od ON o.orderNumber = od.orderNumber
GROUP BY o.customerNumber, c.customerName
ORDER BY total_purchase DESC
LIMIT 1;


-- Average Profit Margin

SELECT
	CONCAT(ROUND(AVG(profit_margin),2),'%') AS avg_profit_margin
FROM
	(SELECT
		p.productCode,
        p.productName,
        ROUND(SUM(od.price - (od.quantityOrdered * p.buyPrice)) / SUM(od.price) * 100,2) AS profit_margin
	FROM
		orderdetails od
			JOIN
		products p ON od.productCode = p.productCode
	GROUP BY od.productCode) a;
    
    
############################################ STORED PROCEDURES FOR  AUTOMATING KPI's ###########################################

-- Total Revenue

DELIMITER $$
DROP PROCEDURE IF EXISTS sp_total_sales;
CREATE PROCEDURE sp_total_sales()
BEGIN
		SELECT
			SUM(quantityOrdered) AS total_sales
		FROM
			orderdetails;
END$$
DELIMITER ;

call sp_total_sales();

-- Total Revenue

DELIMITER $$
DROP PROCEDURE IF EXISTS sp_total_revenue;
CREATE PROCEDURE sp_total_revenue()
BEGIN
		SELECT
			SUM(amount) AS total_revenue
		FROM
			payments;
END$$
DELIMITER ;

call sp_total_revenue();

-- Total Profit

DELIMITER $$
DROP PROCEDURE IF EXISTS sp_total_profit;
CREATE PROCEDURE sp_total_profit()
BEGIN
		SELECT
			ROUND(SUM(od.price) - SUM(od.quantityOrdered * p.buyprice), 2) AS total_profit
		FROM
			orderdetails od
				JOIN
			products p ON od.productCode = p.productCode;
END$$
DELIMITER ;

call sp_total_profit();

-- Top Customer

DELIMITER $$
DROP PROCEDURE IF EXISTS sp_top_customer;
CREATE PROCEDURE sp_top_customer()
BEGIN
		SELECT
			o.customerNumber,
			c.customerName,
			SUM(od.price) AS total_purchase
		FROM
			customers c
				JOIN
			orders o ON c.customerNumber = o.customerNumber
				JOIN
			orderdetails od ON o.orderNumber = od.orderNumber
		GROUP BY o.customerNumber, c.customerName
		ORDER BY total_purchase DESC
		LIMIT 1;
END$$
DELIMITER ;

call sp_top_customer();

-- Average Profit Margin

DELIMITER $$
DROP PROCEDURE IF EXISTS sp_avg_profit_margin;
CREATE PROCEDURE sp_avg_profit_margin()
BEGIN
		SELECT
			CONCAT(ROUND(AVG(profit_margin),2),'%') AS avg_profit_margin
		FROM
			(SELECT
				p.productCode,
				p.productName,
				ROUND(SUM(od.price - (od.quantityOrdered * p.buyPrice)) / SUM(od.price) * 100,2) AS profit_margin
			FROM
				orderdetails od
					JOIN
				products p ON od.productCode = p.productCode
			GROUP BY od.productCode) a;
END$$
DELIMITER ;

call sp_avg_profit_margin();

####################################################### CUSTOMER ANALYTICS #####################################################

-- 1. Which customers haven’t placed any orders in the last 6 months?

SELECT
	a.customer_no,
    a.customer_name,
	a.last_order_date
FROM
	(SELECT DISTINCT
		c.customerNumber AS customer_no,
        c.customerName AS customer_name,
		IFNULL(MAX(o.orderDate), '0 orders placed') AS last_order_date
	FROM 
		orders o
			RIGHT JOIN
		customers c ON o.customerNumber = c.customerNumber
	GROUP BY c.customerNumber) a
		CROSS JOIN
	(SELECT
		MAX(orderDate) AS max_date
	FROM
		orders) b
WHERE a.last_order_date < DATE_SUB(b.max_date, INTERVAL 6 MONTH) OR a.last_order_date IS NULL
ORDER BY a.last_order_date;
    
/* Insights :-
	Show all the customers who doesn't placed any orders in the past 6 months.
	Helps to see whoever is not an active customer 
*/


-- 2. Which countries bring the most revenue?

SELECT
	c.country,
    ROUND(SUM(p.amount)) AS revenue,
    RANK() OVER(ORDER BY SUM(p.amount) DESC) AS rank_num
FROM
	customers c
		JOIN
	payments p ON c.customerNumber = p.customerNumber
GROUP BY c.country
LIMIT 5;
    
/* Insights :-
	This query identifies the top 5 countries generating the highest total revenue based on customer payment data.

 Findings:  
	USA leads with the highest revenue around $3M.  
	Spain and France follow as strong markets around $1M.  
	Australia and New Zealand contribute moderately.
 */

-- 3. Who are the top 10 high-value customers?

SELECT
	p.customerNumber,
    c.customerName,
    ROUND(SUM(p.amount)) AS total_revenue,
    RANK() OVER(ORDER BY SUM(p.amount) DESC) AS rank_num
FROM
	customers c 
		JOIN
	payments p ON c.customerNumber = p.customerNumber
GROUP BY p.customerNumber, c.customerName
LIMIT 10;

/* Insights :-
	This query identifies the top 10 customers who have generated the highest total revenue for the business.
	
Findings:
	Euro+ Shopping Channel is the biggest customer, giving the highest revenue (₹715K).
	Mini Gifts Distributors Ltd. is second with ₹584K, but still far behind the first.
	From rank 3 onward, revenue drops sharply (e.g., Australian Collectors, ₹180K).
	Business depends too much on the top 2 customers.

Suggestion:
	Focus on keeping the top 2 happy, but also grow mid-level customers to reduce risk.
*/

################################################### SALES & PRODUCT ANALYSIS ###################################################

-- 4. Which product lines are most profitable?

SELECT
	p.productLine,
    SUM(od.quantityOrdered) AS units_sold,
    ROUND(SUM(od.quantityOrdered * od.priceEach) - SUM(od.quantityOrdered * p.buyprice), 2) AS total_profit,
    ROUND((SUM(od.quantityOrdered * od.priceEach) - SUM(od.quantityOrdered * p.buyprice)) / SUM(od.quantityOrdered), 2) AS profit_per_unit,
    ROUND((SUM(od.quantityOrdered * od.priceEach) - SUM(od.quantityOrdered * p.buyprice)) / SUM(od.quantityOrdered * od.priceEach) * 100, 2) AS profit_margin_percent
FROM
	orderdetails od
		JOIN
	products p ON od.productCode = p.productCode
GROUP BY p.productLine
ORDER BY total_profit DESC;

/* Insights :-
	This query identifies which product lines generate the highest total profits
	and compares their efficiency using profit margin % and profit per unit.
   
Findings:
	Classic Cars generate the highest total profit (₹1.52M), making them the top contributor.
	Vintage Cars and Motorcycles show strong efficiency with the highest profit margins (~41%).
	Trucks & Buses, Planes, and Ships provide moderate profits with margins around 38–39%.
	Trains underperform across all metrics (lowest profit, margin, and per-unit profit).
   
Suggestion:
	Keep focusing on Classic Cars as the main profit driver.
	Promote and expand Vintage Cars and Motorcycles since they combine good sales with the best margins.
	Review Trains category performance — consider pricing changes, cost optimization, or reducing focus if demand cannot improve.
*/


-- 5. List the lowest and highest selling product in each product line?

WITH sales_rank AS (SELECT
		p.productLine,
		p.productCode,
		p.productName,
		IFNULL(SUM(od.quantityOrdered), 0) AS total_sales,
		ROW_NUMBER() OVER(PARTITION BY p.productLIne ORDER BY SUM(od.quantityOrdered)) AS l_rn,
        ROW_NUMBER() OVER(PARTITION BY p.productLIne ORDER BY SUM(od.quantityOrdered) DESC) AS h_rn
	FROM
		products p
			LEFT JOIN
		orderdetails od ON p.productCode = od.productCode
	GROUP BY p.productCode, p.productName, p.productLine)

SELECT
	l.productLine,
    l.productCode AS product_code_lowselling,
    l. productName AS product_name_lowselling,
    l.total_sales AS total_sales_lowselling,
    h.productCode AS product_code_highselling,
    h.productName AS product_name_highselling,
    h.total_sales AS total_sales_highselling
FROM
	sales_rank l
		CROSS JOIN
	sales_rank h ON l.productLine = h.productLine
WHERE 
	l.l_rn = 1 AND h.h_rn = 1
ORDER BY total_sales_highselling DESC, total_sales_lowselling;

/* Insights :-
   This query highlights the best- and worst-selling products within each product line,
   revealing demand patterns and potential improvement areas.

Findings:
	Classic Cars: Best seller is <1992 Ferrari 360 Spider red> (1808 units), worst seller is <1985 Toyota Supra> (0 units).
	Vintage Cars: Best seller is <1937 Lincoln Berline>, worst seller is <1936 Mercedes Benz 500k Roadster>.
	Trains consistently underperform with the lowest sales volume across its category.

Suggestions:
	Focus on promoting top-selling products to maintain revenue flow.
	For low-selling items, analyze causes (low demand, poor marketing, or pricing issues).
	Consider bundling or discount strategies to improve slow-moving products.
	Allocate production and inventory more efficiently towards high-demand items.
*/

-- 6. What’s the trend in sales over time (monthly)?

SELECT
	year_months,
    total_sales,
    ROUND(
		((total_sales - LAG(total_sales) OVER(ORDER BY year_months))/LAG(total_sales) OVER(ORDER BY year_months))*100,
		2
	) AS mom_sales_percent
FROM
	(SELECT
		DATE_FORMAT(o.orderDate, '%Y-%m') AS year_months,
		SUM(od.quantityOrdered) AS total_sales
	FROM
		orders o
			JOIN
		orderdetails od ON o.orderNumber = od.orderNumber
	GROUP BY year_months
	ORDER BY year_months) a;

/* Insights:
	This query calculates month-over-month (MoM) sales growth %, helping to track sales trends

Findings:
	Sales show strong seasonality, with recurring spikes in October & November (70%–130% growth), followed by sharp drops in December (–50% to –70%).
	The biggest growth was in Oct 2003 (+128.33%), likely due to festive or promotional campaigns.
	The steepest decline was in Dec 2003 (–72.74%), repeating in later Decembers, suggesting post-festival slowdowns.
	Overall sales performance has quadrupled (4X growth) from early 2003 to mid-2005, showing strong long-term growth despite volatility.
	Months like Feb 2005 (–0.06%) show stable but flat performance, indicating a non-seasonal baseline level of demand.

Suggestions:
	Leverage festive demand in October–November with targeted promotions, bulk inventory, and marketing campaigns.
	Introduce retention offers in December (discounts, bundles, loyalty rewards) to reduce steep post-festival drops.
	Analyze whether the growth trend is driven more by new customer acquisition or repeat purchases for sustainable planning.
*/

##################################################### EMPLOYEE & PERFORMANCE ###################################################

-- 7. Which sales reps generated the highest revenue?

SELECT
	c.salesRepEmployeeNumber,
	e.firstName,
    e.lastName,
    CONCAT(e.firstName, e.lastName) AS full_name,
    e.jobTitle,
    SUM(p.amount) AS revenue
FROM
	employees e
		JOIN
	customers c ON e.employeeNumber = c.salesRepEmployeeNumber
		JOIN
	payments p ON c.customerNumber = p.customerNumber
GROUP BY c.salesRepEmployeeNumber
ORDER BY revenue DESC
LIMIT 1;

/* Insights :-
	This query identifies the sales representative who generated the highest total revenue based on customer payments.
*/

-- 8. Which country have faster delivery times?

WITH orders_mod AS(SELECT 
		orderNumber,
		DATEDIFF(shippedDate, orderDate) AS delivery_period,
		customerNumber
	FROM
		orders
	WHERE
		shippedDate IS NOT NULL)

SELECT
	c.country,
    ROUND(AVG(delivery_period),1) AS avg_delivery_period
FROM
	orders_mod o
		JOIN
	customers c ON o.customerNumber = c.customerNumber
GROUP BY c.country
ORDER BY avg_delivery_period
LIMIT 3;
	

/* Insights :-
	This query identifies the countries with the fastest average delivery times 
	based on the difference between order and shipment dates.

Findings:
	Belgium and Switzerland lead with the fastest delivery, averaging just 2 days.  
	Denmark follows closely with an average of 2.4 days.  
	This indicates highly efficient logistics and quick order processing in these regions.
*/


###################################################### FINANCE AND PAYMENTS ####################################################

-- 9. What is the monthly payment trend?

SELECT
	calendar_month,
    payments,
    ROUND(
		((payments - LAG(payments) OVER(ORDER BY calendar_month))/LAG(payments) OVER(ORDER BY calendar_month)) * 100,
        2
	) AS mom_payments_percent
FROM
	(SELECT
		DATE_FORMAT(paymentDate, '%Y-%m') AS calendar_month,
		SUM(amount) AS payments
	FROM
		payments
	GROUP BY calendar_month
	ORDER BY calendar_month) a;
    
/* Insights:  
	Payments go up and down through the year but show a clear seasonal trend.  

Findings:  
	Payments increase fast in early 2003.  
	Both 2003 and 2004 show many ups and downs.  
	Oct–Nov have the biggest payments, same months when sales boom.  
	Dec also stays strong, showing year-end demand.  
	Jan–Feb payments drop heavily after the holiday season.  
	Mar and mid-year months recover a bit but are not stable.  
	In 2005, payments start very low in Jan, rise slightly in Feb–Mar, then fall again in Jun.  

Overall:  
	Payments are highest in **Oct–Dec** and lowest in **Jan–Feb**, repeating every year.  
*/


-- 10. Who are the customers with pending payment?

WITH order_totals AS (SELECT
        o.customerNumber,
        SUM(od.quantityOrdered * od.priceEach) AS total_purchase
    FROM
		orders o
			JOIN
		orderdetails od ON o.orderNumber = od.orderNumber
    GROUP BY o.customerNumber
),
payment_totals AS (SELECT
        customerNumber,
        SUM(amount) AS total_payment
    FROM
		payments
    GROUP BY customerNumber
)
SELECT
    c.customerNumber,
    c.customerName,
    o.total_purchase,
    COALESCE(p.total_payment, 0) AS total_payment,
    o.total_purchase - COALESCE(p.total_payment, 0) AS pending_amount
FROM
	customers c
		JOIN
	order_totals o ON c.customerNumber = o.customerNumber
		LEFT JOIN
	payment_totals p ON c.customerNumber = p.customerNumber
WHERE
	o.total_purchase - COALESCE(p.total_payment, 0) <> 0
ORDER BY pending_amount DESC;


/* Insights :-  
	This query identifies the top customers who still have the highest pending payments.  

Findings:  
	Euro+ Shopping Channel has the biggest pending balance (~$105K).  
	The Sharp Gifts Warehouse is second with ~$84K.  
	From rank 3 onward, pending amounts drop to ~$50K or less.  
	Outstanding payments are heavily concentrated in the top 2 customers.  

Suggestion:  
	Ensure close follow-up with the top 2 customers to recover large pending amounts.  
	At the same time, monitor mid-tier customers to prevent balances from growing further.  
*/