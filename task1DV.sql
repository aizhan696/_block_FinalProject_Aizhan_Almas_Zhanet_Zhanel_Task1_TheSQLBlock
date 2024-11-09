-- Create table for customer_info
CREATE TABLE customer_info (
    Id_client INTEGER PRIMARY KEY,
    Total_amount DECIMAL,
    Gender VARCHAR(10),
    Age INTEGER,
    Count_city INTEGER,
    Response_communication INTEGER,
    Communication_3month INTEGER,
    Tenure INTEGER
);

-- Create table for transactions_info
CREATE TABLE transactions_info (
    date_new DATE,
    Id_check INTEGER,
    ID_client INTEGER REFERENCES customer_info(Id_client),
    Count_products DECIMAL,
    Sum_payment DECIMAL
);



--task1
--Clients with Continuous Monthly History, Average Receipt, and Transaction Count

--1 Calculate each client's total spending and transaction count per month
WITH MonthlyTransactions AS (
    SELECT 
        ID_client,
        TO_CHAR(date_new, 'YYYY-MM') AS transaction_month,
        SUM(Sum_payment) AS monthly_total_spent,
        COUNT(Id_check) AS monthly_transactions
    FROM transactions_info
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ID_client, transaction_month
),

-- 2 Identify clients who have transactions in all 12 months (indicating continuous monthly activity)
ContinuousClients AS (
    SELECT 
        ID_client
    FROM MonthlyTransactions
    GROUP BY ID_client
    HAVING COUNT(DISTINCT transaction_month) = 12  -- 12 months indicates continuous monthly transactions
)

-- 3 Calculate average receipt, average monthly spending, and total transaction count
SELECT 
    cc.ID_client,
    AVG(t.Sum_payment) AS avg_receipt,               -- Average receipt: average amount spent per transaction
    AVG(mt.monthly_total_spent) AS avg_monthly_spending,  -- Average monthly spending: average of monthly total spending
    COUNT(t.Id_check) AS total_transactions          -- Total transaction count for the specified period
FROM ContinuousClients cc
JOIN transactions_info t ON cc.ID_client = t.ID_client
JOIN MonthlyTransactions mt ON cc.ID_client = mt.ID_client
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01' 
GROUP BY cc.ID_client;




--task2
--Monthly Summary Statistics

--Calculate monthly statistics
WITH MonthlyStats AS (
    SELECT 
        TO_CHAR(date_new, 'YYYY-MM') AS month,
        AVG(Sum_payment) AS avg_check,                       -- Average amount of the check per month
        COUNT(Id_check) AS total_operations,                 -- Total number of transactions per month
        COUNT(DISTINCT ID_client) AS unique_clients,         -- Number of unique clients per month
        SUM(Sum_payment) AS monthly_total_spending           -- Total spending per month
    FROM transactions_info
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY month
),
AnnualStats AS (
    SELECT 
        SUM(total_operations) AS annual_total_operations,    -- Total number of transactions for the year
        SUM(monthly_total_spending) AS annual_total_spending -- Total spending for the year
    FROM MonthlyStats
),
MonthlyGenderStats AS (
    SELECT 
        TO_CHAR(t.date_new, 'YYYY-MM') AS month,
        c.Gender,
        COUNT(t.ID_client) AS client_count,                  -- Count of transactions per gender per month
        SUM(t.Sum_payment) AS gender_spending                -- Total spending by gender per month
    FROM transactions_info t
    JOIN customer_info c ON t.ID_client = c.Id_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY month, c.Gender
)

--  Final query to combine results
SELECT 
    ms.month,
    ms.avg_check,                                                 -- Average amount of the check per month
    ms.total_operations AS operations_per_month,                  -- Number of transactions per month
    ms.unique_clients AS avg_unique_clients,                      -- Average number of clients who performed transactions
    ROUND(ms.total_operations * 100.0 / ast.annual_total_operations, 2) AS monthly_operation_share, -- Monthly share of total transactions
    ROUND(ms.monthly_total_spending * 100.0 / ast.annual_total_spending, 2) AS monthly_spending_share, -- Monthly share of total spending
    mgs.Gender,
    ROUND(mgs.client_count * 100.0 / SUM(mgs.client_count) OVER (PARTITION BY ms.month), 2) AS gender_ratio, -- % ratio of M/F/NA per month
    ROUND(mgs.gender_spending * 100.0 / SUM(mgs.gender_spending) OVER (PARTITION BY ms.month), 2) AS gender_spending_share -- % share of costs by gender per month
FROM MonthlyStats ms
JOIN AnnualStats ast ON true
JOIN MonthlyGenderStats mgs ON ms.month = mgs.month
ORDER BY ms.month, mgs.Gender;





--task3
--Age Groups (10-year Intervals) with Amount and Transaction Counts, Quarterly Averages

-- Create age groups with 10-year increments, including a separate group for clients without age info
WITH AgeGroups AS (
    SELECT 
        ID_client,
        CASE 
            WHEN Age BETWEEN 0 AND 9 THEN '0-9'
            WHEN Age BETWEEN 10 AND 19 THEN '10-19'
            WHEN Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN Age BETWEEN 50 AND 59 THEN '50-59'
            WHEN Age BETWEEN 60 AND 69 THEN '60-69'
            WHEN Age >= 70 THEN '70+'
            ELSE 'Unknown'  -- Group for clients without age info
        END AS age_group
    FROM customer_info
),

-- Join age groups with transactions and calculate total amount and transaction count per age group for each quarter
QuarterlyAgeStats AS (
    SELECT 
        ag.age_group,
        DATE_TRUNC('quarter', t.date_new) AS quarter,           -- Extract quarter from date
        SUM(t.Sum_payment) AS total_amount,                     -- Total amount spent by age group per quarter
        COUNT(t.Id_check) AS transaction_count                  -- Total number of transactions by age group per quarter
    FROM transactions_info t
    JOIN AgeGroups ag ON t.ID_client = ag.ID_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ag.age_group, quarter
),

-- Calculate the overall totals for the period to use for percentage calculations
OverallTotals AS (
    SELECT 
        SUM(total_amount) AS overall_total_amount,
        SUM(transaction_count) AS overall_total_transactions
    FROM QuarterlyAgeStats
)

-- Calculate quarterly averages and percentage contributions for each age group
SELECT 
    qas.age_group,
    qas.quarter,
    qas.total_amount,
    qas.transaction_count,
    ROUND(qas.total_amount * 100.0 / ot.overall_total_amount, 2) AS amount_percentage,       -- % of total amount by age group
    ROUND(qas.transaction_count * 100.0 / ot.overall_total_transactions, 2) AS transaction_percentage,  -- % of total transactions by age group
    ROUND(AVG(qas.total_amount) OVER (PARTITION BY qas.age_group), 2) AS avg_quarterly_amount,         -- Quarterly average amount
    ROUND(AVG(qas.transaction_count) OVER (PARTITION BY qas.age_group), 2) AS avg_quarterly_transactions -- Quarterly average transactions
FROM QuarterlyAgeStats qas
JOIN OverallTotals ot ON true
ORDER BY qas.age_group, qas.quarter;


