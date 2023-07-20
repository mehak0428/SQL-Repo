--Inspecting Data
select * from [dbo].[sales_data_sample]

--Checking Unique Values
select distinct [status] from [dbo].[sales_data_sample] -- Good to Plot
select distinct year_id from [dbo].[sales_data_sample]
select distinct PRODUCTLINE from [dbo].[sales_data_sample] -- Good to Plot
select distinct COUNTRY from [dbo].[sales_data_sample] -- Good to Plot
select distinct DEALSIZE from [dbo].[sales_data_sample] -- Good to Plot
select distinct TERRITORY from [dbo].[sales_data_sample] -- Good to Plot

------------------------------------ANALYSIS-----------------------------------

---Grouping sales by productline to see which product has the highest sale = Classic Cars
select PRODUCTLINE, sum(sales) AS Revenue
from [dbo].[sales_data_sample]
group by PRODUCTLINE
order by 2 desc

---Grouping sales by YEAR_ID to see which year has the highest sale = 2004
select YEAR_ID, sum(sales) AS Revenue
from [dbo].[sales_data_sample]
group by YEAR_ID
order by 2 desc

---Checking Company operations in each year
---[2003:All 12 months, 2004:All 12 months AND 2005: Only 5 months]
---MAX SALES:2004 AND MIN SALES:2005
select distinct MONTH_ID from [dbo].[sales_data_sample]
where year_id = 2003

select distinct MONTH_ID from [dbo].[sales_data_sample]
where year_id = 2004

select distinct MONTH_ID from [dbo].[sales_data_sample]
where year_id = 2005

---Checking which deal_size generates the max revenue(Small, Medium or Large)
---MAX:Medium
select  DEALSIZE, sum(sales) AS Revenue
from [PortfolioDB].[dbo].[sales_data_sample]
group by  DEALSIZE
order by 2 desc

---What was the best month for sales in a specific year? How much was earned that month? 
---YEAR_ID=2003
select  MONTH_ID, sum(sales) AS Revenue, count(ORDERNUMBER) AS Frequency
from [PortfolioDB].[dbo].[sales_data_sample]
where YEAR_ID = 2003 --change year to see the rest
group by  MONTH_ID
order by 2 desc

---YEAR_ID=2004
select  MONTH_ID, sum(sales) AS Revenue, count(ORDERNUMBER) AS Frequency
from [PortfolioDB].[dbo].[sales_data_sample]
where YEAR_ID = 2004 --change year to see the rest
group by  MONTH_ID
order by 2 desc

---YEAR_ID=2005 
---[DATA IS NOT COMPLETE AS ITS ONLY FOR FIRST 5 MONTHS AND NOT FOR ENTIRE YEAR]
select  MONTH_ID, sum(sales) AS Revenue, count(ORDERNUMBER) AS Frequency
from [PortfolioDB].[dbo].[sales_data_sample]
where YEAR_ID = 2005 --change year to see the rest
group by  MONTH_ID
order by Revenue desc

---November seems to be the month, what product do they sell in November
---As per Analysis of Productline, Classic Cars has the highest sale---

---YEAR_ID = 2004
select  MONTH_ID, PRODUCTLINE, sum(sales) AS Revenue, count(ORDERNUMBER) AS Frequency
from [PortfolioDB].[dbo].[sales_data_sample]
where YEAR_ID = 2004 and MONTH_ID = 11 --change year to see the rest
group by  MONTH_ID, PRODUCTLINE
order by 3 desc

---YEAR_ID = 2003
select  MONTH_ID, PRODUCTLINE, sum(sales) AS Revenue, count(ORDERNUMBER) AS Frequency
from [PortfolioDB].[dbo].[sales_data_sample]
where YEAR_ID = 2003 and MONTH_ID = 11 --change year to see the rest
group by  MONTH_ID, PRODUCTLINE
order by 3 desc


---What city has the highest number of sales in a specific country (say, UK)
select city, sum (sales) AS Revenue
from [PortfolioDB].[dbo].[sales_data_sample]
where country = 'UK'
group by city
order by 2 desc

---What is the best product in a specific country (say, United States)?
select country, YEAR_ID, PRODUCTLINE, sum(sales) AS Revenue
from [PortfolioDB].[dbo].[sales_data_sample]
where country = 'USA'
group by  country, YEAR_ID, PRODUCTLINE
order by 4 desc


---Finding the best customer (USING RFM)

DROP TABLE IF EXISTS #rfm -- Creating Local Temporary Table

;WITH rfm AS
(
select 
		CUSTOMERNAME, 
		sum(sales) AS MonetaryValue,
		avg(sales) AS AvgMonetaryValue,
		count(ORDERNUMBER) AS Frequency,
		max(ORDERDATE) AS last_order_date,
		(select max(ORDERDATE) from [dbo].[sales_data_sample]) AS max_order_date,
		DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from [dbo].[sales_data_sample] )) AS Recency
		FROM [PortfolioDB].[dbo].[sales_data_sample]
		GROUP BY CUSTOMERNAME
),

rfm_calc AS
(
	select r.*,
	   NTILE(4) OVER (order by Recency desc) AS rfm_recency, --Greater the recency, higher the value [loyal the customer] ~ lower values indicate, no recent purchases
	   NTILE(4) OVER (order by Frequency) AS rfm_frequency, --Greater the frequency, higher the value [[loyal the customer] ~ lower value indicates non frequent customer
	   NTILE(4) OVER (order by MonetaryValue) AS rfm_monetary --Greater they spend, higher the value [loyal the customer] ~ lower value indicates purchases of lesser points
	FROM rfm r
)

    select c.*, 
	rfm_recency+rfm_frequency+rfm_monetary AS rfm_cell,
    cast(rfm_recency AS nvarchar) + cast(rfm_frequency AS nvarchar) + cast(rfm_monetary AS nvarchar) 
	AS rfm_cell_string
into #rfm
FROM rfm_calc c

---Using Temporary Table to fetch the results of CTE without explicitely running lengthy CTE codes everytime
select * from #rfm

---Classifying customers on the basis of RFM ANALYSIS
select CUSTOMERNAME , rfm_recency, rfm_frequency, rfm_monetary,
	CASE 
		when rfm_cell_string in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers'  --lost customers
		when rfm_cell_string in (133, 134, 143, 234, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' -- (Big spenders who haven’t purchased lately) slipping away
		when rfm_cell_string in (311, 411, 331) then 'new customers'
		when rfm_cell_string in (221, 222, 223, 232, 233, 322) then 'potential churners'
		when rfm_cell_string in (323, 333,321, 412, 421, 422, 423, 332, 432) then 'active' --(Customers who have bought recently & buy often, but at low price points)
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal'

	END AS rfm_segment
FROM #rfm

---What products are most often sold together? Can be used for some promotional/sale campaign
SELECT DISTINCT ORDERNUMBER, ---col1
STUFF(

	 (  select ',' + PRODUCTCODE --- Append all ProductCodes in a single coulumn using XML Path, separating each ProductCode using separator comma (,) as specified
		FROM [dbo].[sales_data_sample] temp2
		WHERE ORDERNUMBER IN
				(
					select ORDERNUMBER 
					FROM
					(
						select ORDERNUMBER, count(*) AS order_total
								FROM [PortfolioDB].[dbo].[sales_data_sample]
								where STATUS = 'Shipped'
								group by ORDERNUMBER
					) temp1 WHERE order_total = 2 --- 19 such orders where only 2 products were ordered/sold together

								---Checking the different products in a particular order
								---select * from [dbo].[sales_data_sample] where ORDERNUMBER =  10388
				)
		
		AND temp2.ORDERNUMBER = temp3.ORDERNUMBER
		FOR xml path ('')

	  ), 1, 1, ('')) AS ProductCodes ---col2 (Removing comma before first ProductCode using Stuff Function)

FROM [dbo].[sales_data_sample] temp3
order by 2 desc ---Ordering By ProductCodes(col2), so that we can only see the orders we are insterested in (i.e. orders that contain 2 ProductCodes, separated by comma 
                ---which means, products that are bought together. 
