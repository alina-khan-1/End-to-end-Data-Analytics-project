
IF DB_ID('SuperstoreDB') IS NULL CREATE DATABASE SuperstoreDB;
GO
USE SuperstoreDB;
GO

select * from Superstore

-- Month-wise New vs Returning Customers
with first_purchase as (
	select 
		customer_id,
		min(order_date) as first_order_date
	from Superstore
	group by Customer_ID
),

monthly_customers as (
	select 
		FORMAT(s.order_date,'yyyy-MM') as month,
		s.customer_id,
		case 
			when s.order_date = f.first_order_date then 'New'
			else 'Returning'
		end as customer_type
	from Superstore s inner join first_purchase f on s.Customer_ID=f.customer_id
)
select
MONTH, customer_type,
count(distinct customer_id ) as customer_count 
from monthly_customers
group by month, customer_type 
order by month, customer_type;

  
--- Region–Category combination profit
CREATE OR ALTER VIEW dbo.v_category_region_profit AS
SELECT 
    Region,
    Category,
    SUM(Profit) AS total_profit,
    SUM(Sales) AS total_sales
FROM Superstore
GROUP BY Region, Category;


--------------------Concise summary: most profitable & most loss-making category per region
CREATE OR ALTER VIEW dbo.v_category_region_summary AS
with category_profit as (
	select Region, Category, sum(profit) as total_profit
	from Superstore
	group by Region, Category
)
-- Top profitable category per region
select 
	cp.Region,
	cp.Category,
	cp.total_profit,
	'Most Profitable' AS CategoryType
from category_profit cp 
where cp.total_profit = (
	select max(total_profit) 
	from category_profit 
	where Region = cp.Region
)

union all 

-- Worst loss-making category per region

select cp.Region, cp.Category, cp.total_profit, 'Most Loss-making' As CategoryType
from category_profit cp
where cp.total_profit=(
	select MIN(total_profit)
	from category_profit
	where Region = cp.Region 
);

select * from v_category_region_summary

---------------------------------------------------------------------------------------------------
--Discount Effectiveness Check

create or alter view dbo.v_discount_effectiveness as
select 
	case 
		when discount = 0 then 'No Discount'
		when Discount > 0 and Discount <= 0.1 then '0-10%'
		WHEN Discount > 0.1 AND Discount <= 0.2 THEN '10-20%'
        WHEN Discount > 0.2 AND Discount <= 0.3 THEN '20-30%'
		else '30%+'
	end AS Discount_range,
	sum(sales) as Toatl_sales,
	sum(profit) as Total_profit,
	cast(sum(profit) * 100.0 / nullif(sum(sales),0) as decimal(10,2)) AS profit_percent 
from superstore 
group by 
	case 
		when discount = 0 then 'No Discount'
		when Discount > 0 and Discount <= 0.1 then '0-10%'
		WHEN Discount > 0.1 AND Discount <= 0.2 THEN '10-20%'
        WHEN Discount > 0.2 AND Discount <= 0.3 THEN '20-30%'
		else '30%+'
	end;

select * from dbo.v_discount_effectiveness

---------------------------
--Customer Retention (Cohort Analysis)
CREATE VIEW v_customer_retention AS
-- 1) First purchase month of every customer
with first_purchase AS (
	select 
		customer_id,
		min(cast(order_date as date)) as first_order_date
	from Superstore
	group by Customer_ID
),

-- 2) Each order joined with customer's first purchase

customer_orders AS ( 
	select 
		s.customer_id,
		format(MIN(f.first_order_date), 'yyyy-MM') AS cohort_month,
		FORMAT(cast(s.order_date as date), 'yyyy-MM')AS order_month
	from Superstore s 
	inner join first_purchase f
		on s.Customer_ID = f.customer_id
	group by s.customer_id, f.first_order_date, s.order_date
)
-- 3) Count active customers per cohort per month

select
	cohort_month,
	order_month,
	COUNT(distinct customer_id) AS active_customer
from customer_orders
group by cohort_month, order_month;


---RFM Segmentation
--Recency (R): when customer placed the last order? (New orders → high recency score)

--Frequency (F): How many times customer placed the order? (more order → high frequency score)

--Monetary (M): How much total money spended by customer? (more money → high monetary score)
--- 1) Customer level RFM calculation
create or alter view dbo.v_customer_rfm as
select 
	customer_id,
	max(order_date) as last_purchase_date,
	COUNT(order_id) as frequency,
	SUM(sales) as monetary
from Superstore
group by Customer_ID;

---- 2) Add Recency score
CREATE OR ALTER VIEW dbo.v_customer_rfm_scored AS
SELECT
    customer_id,
    DATEDIFF(DAY, MAX(order_date), GETDATE()) AS recency_days,
    COUNT(order_id) AS frequency,
    SUM(sales) AS monetary
FROM Superstore
GROUP BY customer_id;







