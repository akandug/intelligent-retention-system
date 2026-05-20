#Display the table `base`.`tv_subscription_data_realistic`
select *
from `base`.`tv_subscription_data_realistic`;

#check the columns data types
describe `tv_subscription_data_realistic`;

#drop table tv_data_clean;
drop table customer_base;

#Create a Clean Table (Convert TEXT → DATE)
CREATE TABLE tv_data_clean AS
SELECT 
    customer_id,
    STR_TO_DATE(signup_date, '%Y-%m-%d') AS signup_date,
    STR_TO_DATE(billing_date, '%Y-%m-%d') AS billing_date,
    plan,
    region,
    payment_success,
    discount,
    revenue
FROM tv_subscription_data_realistic;

#confirm if it worked
DESCRIBE tv_data_clean;

select * from tv_data_clean;

#SELECT 
    #billing_date,
# STR_TO_DATE(billing_date, '%Y-%m-%d') AS converted_date
#FROM tv_subscription_data_realistic
#LIMIT 20;

SELECT MAX(billing_date) FROM tv_data_clean;


#Creating aggregate table
SET @analysis_date = (SELECT MAX(billing_date) FROM tv_data_clean);

CREATE TABLE customer_base AS
SELECT 
    customer_id,

    MIN(signup_date) AS first_purchase_date,
    MAX(billing_date) AS last_billing_date,

    COUNT(*) AS total_billing_cycles,
    SUM(revenue) AS total_revenue,
    AVG(revenue) AS avg_revenue_per_cycle,

    SUM(CASE WHEN payment_success = 0 THEN 1 ELSE 0 END) AS failed_payments,

    DATEDIFF(@analysis_date, MAX(billing_date)) AS days_since_last_payment

FROM tv_data_clean
GROUP BY customer_id;

#sanity check table
select * 
from customer_base;

SELECT @analysis_date;

#PHASE 2 — CHURN INTELLIGENCE ENGINE
#creating customer churn table
CREATE TABLE customer_status AS
SELECT 
    customer_id,
    last_billing_date,
    days_since_last_payment,

    CASE 
        WHEN days_since_last_payment <= 30 THEN 'Active'
        WHEN days_since_last_payment <= 90 THEN 'At Risk'
        ELSE 'Churned'
    END AS customer_status

FROM customer_base;

#sanity check
select * from customer_status;

#Display the table customer_base
select *
from customer_base;

#get max date
#SELECT MAX(billing_date)
#FROM tv_subscription_data_realistic;

select*
from customer_status;

#overall churn view
SELECT 
    customer_status,
    COUNT(*) AS customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_status), 2) AS percentage
FROM customer_status
GROUP BY customer_status;

create table `churn view` as
SELECT 
    customer_status,
    COUNT(*) AS customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_status), 2) AS percentage
FROM customer_status
GROUP BY customer_status;

select* from `churn view`;

#churn by plan
SELECT 
    tdc.plan,
    cs.customer_status,
    COUNT(*) AS customers,
    round(AVG(tdc.revenue)) AS avg_revenue
FROM tv_data_clean tdc
JOIN customer_status cs 
    ON tdc.customer_id = cs.customer_id
GROUP BY tdc.plan, cs.customer_status;

#Revenue at risk
SELECT 
    SUM(revenue) AS revenue_at_risk
FROM tv_data_clean tdc
JOIN customer_status cs 
    ON tdc.customer_id = cs.customer_id
WHERE cs.customer_status = 'At Risk';

#failed payment vs churn(root cause)
SELECT 
    CASE 
        WHEN payment_success = 0 THEN 'No Failures'
        WHEN payment_success BETWEEN 1 AND 2 THEN 'Few Failures'
        ELSE 'Frequent Failures'
    END AS failure_group,

    cs.customer_status,
    COUNT(*) AS customers

FROM tv_data_clean tdc
JOIN customer_status cs 
    ON tdc.customer_id = cs.customer_id

GROUP BY failure_group, cs.customer_status;

#cohort retention
SELECT 
    DATE_FORMAT(signup_date, '%Y-%m') AS cohort_month,
    DATE_FORMAT(billing_date, '%Y-%m') AS activity_month,
    COUNT(DISTINCT customer_id) AS active_customers
FROM tv_data_clean
GROUP BY cohort_month, activity_month;

#create cohort table
CREATE TABLE cohort_table AS
SELECT 
    DATE_FORMAT(signup_date, '%Y-%m') AS cohort_month,
    DATE_FORMAT(billing_date, '%Y-%m') AS activity_month,
    COUNT(DISTINCT customer_id) AS active_customers
FROM tv_data_clean
GROUP BY cohort_month, activity_month;

#sanity check 
select * from cohort_table;

#Convert to Retention %
SELECT 
    cohort_month,
    activity_month,
    active_customers,

    FIRST_VALUE(active_customers) OVER (
        PARTITION BY cohort_month 
        ORDER BY activity_month
    ) AS cohort_size,

    ROUND(
        active_customers * 100.0 /
        FIRST_VALUE(active_customers) OVER (
            PARTITION BY cohort_month 
            ORDER BY activity_month
        ), 2
    ) AS retention_rate

FROM cohort_table;


#Connect Cohort to Churn Drivers
SELECT 
    DATE_FORMAT(signup_date, '%Y-%m') AS cohort_month,
    plan,
    COUNT(DISTINCT customer_id) AS customers
FROM tv_data_clean
GROUP BY cohort_month, plan;

#cohort month,plan by customers
SELECT 
    DATE_FORMAT(signup_date, '%Y-%m') AS cohort_month,
    plan,
    COUNT(DISTINCT customer_id) AS customers
FROM tv_data_clean
GROUP BY cohort_month, plan
ORDER BY cohort_month;

SELECT 
    DATE_FORMAT(signup_date, '%Y-%m') AS cohort_month,
    AVG(CASE WHEN payment_success = 0 THEN 1 ELSE 0 END) AS failure_rate
FROM tv_data_clean
GROUP BY cohort_month
ORDER BY cohort_month;


#Define CLV  For a subscription business: CLV = Average Revenue × Lifetime. Where: Lifetime = number of billing cycles (or months active)
#monthly values
SELECT 
    customer_id,
    avg_revenue_per_cycle AS monthly_value
FROM customer_base;

#estmated lifetime
SELECT 
    customer_id,
    total_billing_cycles AS lifetime_months
FROM customer_base;

#build predictive CLV
SELECT 
    customer_id,

    round(avg_revenue_per_cycle * total_billing_cycles) AS clv,

    CASE 
        WHEN days_since_last_payment <= 30 THEN round(avg_revenue_per_cycle * (total_billing_cycles + 3))
        WHEN days_since_last_payment <= 90 THEN round(avg_revenue_per_cycle * (total_billing_cycles + 1))
        ELSE total_revenue
    END AS predicted_clv

FROM customer_base;

#build clv table
create table CLV as
SELECT 
    customer_id,

    round(avg_revenue_per_cycle * total_billing_cycles) AS clv,

    CASE 
        WHEN days_since_last_payment <= 30 THEN round(avg_revenue_per_cycle * (total_billing_cycles + 3))
        WHEN days_since_last_payment <= 90 THEN round(avg_revenue_per_cycle * (total_billing_cycles + 1))
        ELSE total_revenue
    END AS predicted_clv

FROM customer_base;

select* from clv;

#CLV Segmentation
SELECT 
    customer_id,
    predicted_clv,

    CASE 
        WHEN predicted_clv >= 50000 THEN 'High Value'
        WHEN predicted_clv >= 20000 THEN 'Mid Value'
        ELSE 'Low Value'
    END AS clv_segment

FROM (
    SELECT 
        customer_id,

        CASE 
            WHEN days_since_last_payment <= 30 THEN avg_revenue_per_cycle * (total_billing_cycles + 3)
            WHEN days_since_last_payment <= 90 THEN avg_revenue_per_cycle * (total_billing_cycles + 1)
            ELSE total_revenue
        END AS predicted_clv

    FROM customer_base
) t;
# this helps us know who are most valuable customers
# who we should focus our retention on

#create a complete clv table
CREATE TABLE clv_table AS
SELECT 
    customer_id,

    total_revenue AS actual_clv,

    avg_revenue_per_cycle,
    total_billing_cycles,
    days_since_last_payment,

    -- Predicted CLV
    CASE 
        WHEN days_since_last_payment <= 30 THEN avg_revenue_per_cycle * (total_billing_cycles + 3)
        WHEN days_since_last_payment <= 90 THEN avg_revenue_per_cycle * (total_billing_cycles + 1)
        ELSE total_revenue
    END AS predicted_clv,

    -- CLV Segmentation
    CASE 
        WHEN 
            CASE 
                WHEN days_since_last_payment <= 30 THEN avg_revenue_per_cycle * (total_billing_cycles + 3)
                WHEN days_since_last_payment <= 90 THEN avg_revenue_per_cycle * (total_billing_cycles + 1)
                ELSE total_revenue
            END >= 50000 THEN 'High Value'

        WHEN 
            CASE 
                WHEN days_since_last_payment <= 30 THEN avg_revenue_per_cycle * (total_billing_cycles + 3)
                WHEN days_since_last_payment <= 90 THEN avg_revenue_per_cycle * (total_billing_cycles + 1)
                ELSE total_revenue
            END >= 20000 THEN 'Mid Value'

        ELSE 'Low Value'
    END AS clv_segment

FROM customer_base;
# The clv table created above can be used for the following: Identify high-value customers
#✅ Calculate revenue at risk
#✅ Prioritize retention efforts
#✅ Combine with churn + segmentation


#validate it
SELECT * FROM clv_table;

#customer distribution in clv segment
SELECT 
    clv_segment,
    COUNT(*) AS customers,
    SUM(predicted_clv) AS total_value
FROM clv_table
GROUP BY clv_segment;
# “High-value customers represent ₦93.2 million of total future revenue”

#combine CLV with CHURN
SELECT 
    cs.customer_status,
    COUNT(*) AS customers,
    AVG(predicted_clv) AS avg_clv,
    SUM(predicted_clv) AS total_value

FROM (
    SELECT 
        customer_id,

        CASE 
            WHEN days_since_last_payment <= 30 THEN avg_revenue_per_cycle * (total_billing_cycles + 3)
            WHEN days_since_last_payment <= 90 THEN avg_revenue_per_cycle * (total_billing_cycles + 1)
            ELSE total_revenue
        END AS predicted_clv

    FROM customer_base
) clv

JOIN customer_status cs
    ON clv.customer_id = cs.customer_id

GROUP BY cs.customer_status;


#RFM SEGMENTATION
SELECT 
    customer_id,

    days_since_last_payment AS recency,
    total_billing_cycles AS frequency,
    total_revenue AS monetary

FROM customer_base;


#create rfm segmentation table
create table rfm_segmentation as
SELECT 
    customer_id,

    days_since_last_payment AS recency,
    total_billing_cycles AS frequency,
    total_revenue AS monetary

FROM customer_base;

#check table
select* from rfm_segmentation;


#create RFM scores
SELECT 
    customer_id,

    NTILE(5) OVER (ORDER BY days_since_last_payment DESC) AS r_score,
    NTILE(5) OVER (ORDER BY total_billing_cycles) AS f_score,
    NTILE(5) OVER (ORDER BY total_revenue) AS m_score

FROM customer_base;


#combine into segments
SELECT 
    customer_id,

    CONCAT(r_score, f_score, m_score) AS rfm_score,

    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'VIP'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'At Risk'
        ELSE 'Regular'
    END AS segment

FROM (
    SELECT 
        customer_id,

        NTILE(5) OVER (ORDER BY days_since_last_payment DESC) AS r_score,
        NTILE(5) OVER (ORDER BY total_billing_cycles) AS f_score,
        NTILE(5) OVER (ORDER BY total_revenue) AS m_score

    FROM customer_base
) t;


select* from rfm_table;
select* from clv;

#building RFM_Table
create table rfm_table as
SELECT 
    customer_id,

    CONCAT(r_score, f_score, m_score) AS rfm_score,

    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'VIP'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'At Risk'
        ELSE 'Regular'
    END AS segment

FROM (
    SELECT 
        customer_id,

        NTILE(5) OVER (ORDER BY days_since_last_payment DESC) AS r_score,
        NTILE(5) OVER (ORDER BY total_billing_cycles) AS f_score,
        NTILE(5) OVER (ORDER BY total_revenue) AS m_score

    FROM customer_base
) t;

select*from rfm_table;

#clv segmentation(compliments RFM)
SELECT 
    customer_id,
    predicted_clv,

    CASE 
        WHEN predicted_clv >= 50000 THEN 'High Value'
        WHEN predicted_clv >= 20000 THEN 'Mid Value'
        ELSE 'Low Value'
    END AS clv_segment
FROM clv;



#Churn × CLV Segmentation Table
CREATE TABLE customer_value_status AS
SELECT 
    c.customer_id,

    c.predicted_clv,
    c.clv_segment,

    cs.customer_status

FROM clv_table c
JOIN customer_status cs
    ON c.customer_id = cs.customer_id;
    
    #validate
    SELECT * FROM customer_value_status LIMIT 10;
    
    #core analysis
    SELECT 
    clv_segment,
    customer_status,
    COUNT(*) AS customers,
    SUM(predicted_clv) AS total_value
FROM customer_value_status
GROUP BY clv_segment, customer_status
ORDER BY clv_segment, customer_status;
# This answers the business question of who are actually churning
# 1. Are high Value customers churning, if yes, a major business issue. But it is low
#2.Are low value customers dominating churn, if yes, good,it may not hurtrevenue much.
#3 where is the revenue at risk? 

#revenue at risk
SELECT 
    clv_segment,
    SUM(predicted_clv) AS revenue_at_risk
FROM customer_value_status
WHERE customer_status = 'At Risk'
GROUP BY clv_segment;
#“₦1.18 million in high-value customers are at risk, 1.92 million in mid value and 453k in low value customers.”

#Add RFM Layer
SELECT 
    r.segment AS rfm_segment,
    c.clv_segment,
    cs.customer_status,
    COUNT(*) AS customers
FROM rfm_table r
JOIN clv_table c ON r.customer_id = c.customer_id
JOIN customer_status cs ON r.customer_id = cs.customer_id
GROUP BY rfm_segment, clv_segment, customer_status;
# shows our vip segment are not churned
# Those churnrd are actually from mid value and low value
# loyal users are stable

select* from customer_value_status;



#Add RFM Layer + total_revenue
SELECT 
    r.segment AS rfm_segment,
    c.clv_segment,
    cs.customer_status,
    cb.total_revenue,
    COUNT(*) AS customers
FROM rfm_table r
JOIN clv_table c ON r.customer_id = c.customer_id
JOIN customer_status cs ON r.customer_id = cs.customer_id
join customer_base cb on cb.customer_id=r.customer_id
GROUP BY rfm_segment, clv_segment, customer_status,cb.total_revenue;

#updated rfm+clv+churn+revenue***
SELECT 
    r.segment AS rfm_segment, 
    c.clv_segment, 
    cs.customer_status, 
    SUM(cb.total_revenue) AS total_segment_revenue, -- Sums the revenue
    COUNT(*) AS customer_count -- Counts customers in this group
FROM rfm_table r 
JOIN clv_table c ON r.customer_id = c.customer_id 
JOIN customer_status cs ON r.customer_id = cs.customer_id 
JOIN customer_base cb ON cb.customer_id = r.customer_id 
GROUP BY rfm_segment, c.clv_segment, cs.customer_status; -- Groups only by the categorical segments


#combining rfm_segmentation table and customer_status table, so we can add rfm to individual customer churn status
select rs.customer_id,
rs.recency,
rs.frequency,
rs.monetary,
cs.customer_status
from rfm_segmentation as rs
join customer_status cs
on rs.customer_id=cs.customer_id;

#create the above into a table
create table rfm_churn as
select rs.customer_id,
rs.recency,
rs.frequency,
rs.monetary,
cs.customer_status
from rfm_segmentation as rs
join customer_status cs
on rs.customer_id=cs.customer_id;

#check table
select*from rfm_churn;
select*from customer_status;
select*from rfm_segmentation;


#TASK: ANALYZING THE CHURNED SEGMENT TO UNDERSTAND WHY THEY CHURNED
#Analyzing deep into the churned customer segment tounderstand the following: High vs Low value, New vs Loyal, Plan
#defining new vs loyal
SELECT 
    customer_id, 
    CASE 
        WHEN total_billing_cycles <= 3 THEN 'New' 
        ELSE 'Loyal' 
    END AS status
FROM customer_base;


#building churn segmentation table
CREATE TABLE churn_segmentation AS
SELECT 
    c.customer_id,

    c.clv_segment,
    
    CASE 
        WHEN b.total_billing_cycles <= 3 THEN 'New'
        ELSE 'Loyal'
    END AS customer_stage

FROM customer_value_status c

JOIN customer_base b 
    ON c.customer_id = b.customer_id

WHERE c.customer_status = 'Churned';

#validate
select* from churn_segmentation;

SELECT 
    c.customer_id,

    c.clv_segment,
    
    CASE 
        WHEN b.total_billing_cycles <= 3 THEN 'New'
        ELSE 'Loyal'
    END AS customer_stage

FROM customer_value_status c

JOIN customer_base b 
    ON c.customer_id = b.customer_id

WHERE c.customer_status = 'Churned'
group by c.clv_segment,customer_stage, c.customer_id;


#High vs low value churn
SELECT 
    clv_segment,
    COUNT(*) AS customers
FROM churn_segmentation
GROUP BY clv_segment;
#if high value churn most,its a critical problem and may be associated with services problem.
#But out of the total churned 228=low value (may be price sensitivity) and 80, mid value,high value=10 only
# low value churn ismanageable

#Analysing new vs loyal
SELECT 
    customer_stage,
    COUNT(*) AS customers
FROM churn_segmentation
GROUP BY customer_stage;
#More New churn → onboarding issue
#More Loyal churn → product dissatisfaction

#Analyzing plan level effect on churned customers
SELECT 
    plan,
    COUNT(*) AS customers
FROM churn_segmentation
GROUP BY plan;

#no plan column for the analysis,lets create the table
create table updated_churn_segmentation as
select cs.customer_id,
cs.clv_segment,
cs.customer_stage,
tdc.plan,
tdc.region
from churn_segmentation cs
join tv_data_clean tdc
on cs.customer_id=tdc.customer_id
group by  cs.customer_id,
cs.clv_segment,
cs.customer_stage,
tdc.plan,
tdc.region;

#valdate
select*from updated_churn_segmentation;
#drop table updated_churn_segmentation;

#now lets analyze Plan-level Churn
SELECT 
    plan,
    COUNT(*) AS customers
FROM updated_churn_segmentation
GROUP BY plan;
#Insight
#Basic high → price-sensitive users leaving
#Premium high → serious product/value issue

#combine all
SELECT 
    clv_segment,
    customer_stage,
    plan,
    COUNT(*) AS customers
FROM updated_churn_segmentation
GROUP BY clv_segment, customer_stage, plan
ORDER BY customers DESC;
#Gives us the big picture
#Low-value + New + Basic → bulk churn
#High-value + Loyal + Premium → dangerous churn

#Analysing revenue impact
SELECT 
    cs.clv_segment,
    cs.customer_stage,
    cs.plan,
    COUNT(*) AS customers,
    SUM(cv.predicted_clv) AS lost_value
FROM updated_churn_segmentation cs
JOIN clv_table cv 
    ON cs.customer_id = cv.customer_id
GROUP BY cs.clv_segment, cs.customer_stage, cs.plan
ORDER BY lost_value DESC;


# build it into a table
#Analysing revenue impact
create table revenue_impact as
SELECT 
    cs.clv_segment,
    cs.customer_stage,
    cs.plan,
    COUNT(*) AS customers,
    SUM(cv.predicted_clv) AS lost_value
FROM updated_churn_segmentation cs
JOIN clv_table cv 
    ON cs.customer_id = cv.customer_id
GROUP BY cs.clv_segment, cs.customer_stage, cs.plan
ORDER BY lost_value DESC;

select* from revenue_impact;

#now lets analyze region-level Churn
SELECT 
    region,
    COUNT(*) AS customers
FROM updated_churn_segmentation
GROUP BY region;



#Build a real-time SQL alert system that:
#Detects risk daily
#Classifies customers (VIP / Red / Yellow)
#Stores alerts
#Enables action (CRM, email, dashboard)

#SYSTEM ARCHITECTURE 

#Detection Layer → identifies risky customers
#Alert Table → stores alerts
#Daily Job → refreshes alerts
#Action Layer → used by business

#create aleart table
CREATE TABLE retention_alerts (
    snapshot_date DATE,
    customer_id VARCHAR(20),
    retention_alert VARCHAR(20),
    days_since_last_payment INT,
    total_billing_cycles INT,
    total_revenue DECIMAL(10,2),
    predicted_clv DECIMAL(10,2)
);

#build the alert logic
SELECT 
    customer_id,

    CASE 
        WHEN predicted_clv > 50000 
             AND days_since_last_payment >= 20 
        THEN 'VIP Rescue'

        WHEN total_billing_cycles < 4 
             AND days_since_last_payment >= 25 
        THEN 'Red Alert'

        WHEN days_since_last_payment >= 30 
        THEN 'Yellow Alert'

        ELSE 'Stable'
    END AS retention_alert,

    days_since_last_payment,
    total_billing_cycles,
    actual_clv as total_revenue,
    predicted_clv

FROM clv_table;

select * from clv_table;



#Insert Daily Alerts (Automation)***
INSERT INTO retention_alerts
SELECT 
    CURDATE(),
    customer_id,
    
    CASE 
        WHEN CAST(predicted_clv AS DECIMAL(15,2)) > 50000 
             AND days_since_last_payment >= 20 
        THEN 'VIP Rescue'

        WHEN total_billing_cycles < 4 
             AND days_since_last_payment >= 25 
        THEN 'Red Alert'

        WHEN days_since_last_payment >= 30 
        THEN 'Yellow Alert'

        ELSE 'Stable'
    END,

    days_since_last_payment,
    total_billing_cycles,
    actual_clv as total_revenue,

    CAST(predicted_clv AS DECIMAL(15,2))

FROM clv_table;


#Schedule it
CREATE EVENT daily_retention_alerts
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_DATE + INTERVAL 1 DAY
DO
INSERT INTO retention_alerts
SELECT 
    CURDATE(),
    customer_id,
    
    CASE 
        WHEN predicted_clv > 50000 
             AND days_since_last_payment >= 20 
        THEN 'VIP Rescue'

        WHEN total_billing_cycles < 4 
             AND days_since_last_payment >= 25 
        THEN 'Red Alert'

        WHEN days_since_last_payment >= 30 
        THEN 'Yellow Alert'

        ELSE 'Stable'
    END,

    days_since_last_payment,
    total_billing_cycles,
    actual_clv as total_revenue,
    predicted_clv

FROM clv_table;
#What this does. Every day:1. Recalculates customer risk.2. Stores snapshot.3.Tracks movement over time


#Building alert monitoring
SELECT 
    snapshot_date,
    retention_alert,
    COUNT(DISTINCT customer_id) AS customers,
    predicted_clv AS total_value
FROM retention_alerts
GROUP BY snapshot_date, retention_alert;

#Building alert monitoring the prevents double counts: 1 customer = 1 record per day per alert
SELECT 
    snapshot_date,
    retention_alert,
    COUNT(*) AS customers,
    SUM(predicted_clv) AS total_value
FROM (
    SELECT DISTINCT 
        snapshot_date,
        customer_id,
        retention_alert,
        predicted_clv
    FROM retention_alerts
) t
GROUP BY snapshot_date, retention_alert;



#creating escalation tracking table: Helps know how the customers transition from one level tothe other and their current status
CREATE TABLE alert_transitions AS
SELECT 
    customer_id,
    snapshot_date,

    retention_alert AS current_status,

    LAG(retention_alert) OVER (
        PARTITION BY customer_id 
        ORDER BY snapshot_date
    ) AS previous_status,

    predicted_clv

FROM retention_alerts;
    
    
   select * from  alert_transitions;
    
    
    
    #identify escalation
    CREATE TABLE escalation_events AS
SELECT 
    customer_id,
    snapshot_date,

    previous_status,
    current_status,

    CASE 
        WHEN previous_status = 'Stable' AND current_status = 'Yellow' THEN 'Early Risk'
        WHEN previous_status = 'Yellow' AND current_status = 'Red' THEN 'Escalated Risk'
        WHEN previous_status = 'Red' AND current_status = 'VIP Rescue' THEN 'Critical Escalation'
        WHEN current_status = 'Stable' AND previous_status IN ('Yellow','Red','VIP Rescue') THEN 'Recovered'
        ELSE 'No Change'
    END AS transition_type,

    predicted_clv

FROM alert_transitions;

select* from alert_transitions;

select*from escalation_events;


#Track time spent in risk: duration ineach alert state
CREATE TABLE alert_duration AS
SELECT 
    customer_id,
    retention_alert,

    MIN(snapshot_date) AS start_date,
    MAX(snapshot_date) AS end_date,

    DATEDIFF(MAX(snapshot_date), MIN(snapshot_date)) AS days_in_state

FROM retention_alerts
GROUP BY customer_id, retention_alert;

select*from alert_duration;


#build escalation summary:which alerts are dangerous
SELECT 
    transition_type,
    COUNT(DISTINCT customer_id) AS customers,
    SUM(predicted_clv) AS total_value
FROM escalation_events
GROUP BY transition_type;


#identify stuck customers: customers stuck in red alert
SELECT 
    customer_id,
    COUNT(*) AS days_in_red,
    MAX(predicted_clv) AS value
FROM retention_alerts
WHERE retention_alert = 'Red Alert'
GROUP BY customer_id
HAVING COUNT(*) >= 5;


# Recovery rate: Did the system work. Measure success
SELECT 
    COUNT(DISTINCT CASE 
        WHEN previous_status IN ('Yellow','Red','VIP Rescue') 
             AND current_status = 'Stable' 
        THEN customer_id END
    ) * 100.0 
    /
    COUNT(DISTINCT customer_id) AS recovery_rate
FROM alert_transitions;

SET @analysis_date = (SELECT MAX(billing_date) FROM tv_data_clean);
SELECT MAX(billing_date)
from tv_data_clean;

#Building table for machine learning

SET @analysis_date = CAST('2024-12-31' AS DATE);
SELECT
    customer_id,

    -- Behavior
    cast(AVG(revenue) as decimal(10,2)) AS avg_order_value,
   cast(STDDEV(revenue) as decimal(10,2)) AS spending_variability,

    -- Engagement
    COUNT(CASE WHEN billing_date >= DATE_SUB(@analysis_date, INTERVAL 90 DAY) THEN 1 END) AS billing_last_90d,
    DATEDIFF(@analysis_date, MIN(billing_date)) AS tenure_days,

    -- Trend
    COALESCE(
    SUM(CASE WHEN billing_date >= DATE_SUB(@analysis_date, INTERVAL 30 DAY) THEN revenue END) / 
    NULLIF(SUM(CASE WHEN billing_date BETWEEN DATE_SUB(@analysis_date, INTERVAL 60 DAY) 
    AND DATE_SUB(@analysis_date, INTERVAL 30 DAY) THEN revenue END), 0),
    0
) AS growth_ratio

FROM tv_data_clean
GROUP BY customer_id;


drop table spending_variability;
select*from customer_base;
#select*from customer_status;
#select*from customer_value_status;
select*from clv_table;
select*from rfm_segmentation;
#select*from rfm_table;
select*from updated_churn_segmentation;
select*from tv_data_clean;

#building spending variability table
SET @analysis_date = CAST('2024-12-31' AS DATE);
create table spending_variability as
SELECT
    customer_id,

    -- Behavior
    cast(AVG(revenue) as decimal(10,2)) AS avg_order_value,
   cast(STDDEV(revenue) as decimal(10,2)) AS spending_variability,

    -- Engagement
    COUNT(CASE WHEN billing_date >= DATE_SUB(@analysis_date, INTERVAL 90 DAY) THEN 1 END) AS billing_last_90d,
    DATEDIFF(@analysis_date, MIN(billing_date)) AS tenure_days,

    -- Trend
    COALESCE(
    SUM(CASE WHEN billing_date >= DATE_SUB(@analysis_date, INTERVAL 30 DAY) THEN revenue END) / 
    NULLIF(SUM(CASE WHEN billing_date BETWEEN DATE_SUB(@analysis_date, INTERVAL 60 DAY) 
    AND DATE_SUB(@analysis_date, INTERVAL 30 DAY) THEN revenue END), 0),
    0
) AS growth_ratio

FROM tv_data_clean
GROUP BY customer_id;

select *from spending_variability;

#adding spending_variability table to rfm_segmentation table
create table spending_variability1 as
select sv.customer_id,sv.avg_order_value,sv.spending_variability,sv.billing_last_90d,sv.tenure_days,sv.growth_ratio,
rs.recency,rs.frequency,rs.monetary
from spending_variability as sv
join rfm_segmentation as rs
on sv.customer_id=rs.customer_id;

select*from spending_variability4;
select*from rfm_table;

create table spending_variability2 as
select sv.customer_id,sv.avg_order_value,sv.spending_variability,sv.billing_last_90d,sv.tenure_days,sv.growth_ratio,
sv.recency,sv.frequency,sv.monetary,tdc.plan,tdc.payment_success,tdc.discount
from spending_variability1 as sv
join tv_data_clean as tdc
on sv.customer_id=tdc.customer_id;


select sv.customer_id,sv.avg_order_value,sv.spending_variability,sv.billing_last_90d,sv.tenure_days,sv.growth_ratio,
sv.recency,sv.frequency,sv.monetary,sv.plan,sv.payment_success,sv.discount,
rt.segment 
from spending_variability3 as sv
join rfm_table as rt
on sv.customer_id=rt.customer_id;

create table spending_variability3 as
select sv.customer_id,sv.avg_order_value,sv.spending_variability,sv.billing_last_90d,sv.tenure_days,sv.growth_ratio,
sv.recency,sv.frequency,sv.monetary,sv.plan,sv.payment_success,sv.discount,
ct.actual_clv,ct.predicted_clv,ct.clv_segment
from spending_variability2 as sv
join clv_table as ct
on sv.customer_id=ct.customer_id;

create table spending_variability4 as
select sv.customer_id,sv.avg_order_value,sv.spending_variability,sv.billing_last_90d,sv.tenure_days,sv.growth_ratio,
sv.recency,sv.frequency,sv.monetary,sv.plan,sv.payment_success,sv.discount,sv.actual_clv,sv.predicted_clv,sv.clv_segment,
rt.segment 
from spending_variability3 as sv
join rfm_table as rt
on sv.customer_id=rt.customer_id;


select sv.customer_id,sv.avg_order_value,sv.spending_variability,sv.billing_last_90d,sv.tenure_days,sv.growth_ratio,
sv.recency,sv.frequency,sv.monetary,sv.plan,sv.payment_success,sv.discount,sv.actual_clv,sv.predicted_clv,sv.clv_segment,
sv.segment, cvs.customer_status
from spending_variability4 as sv
join customer_value_status as cvs
on sv.customer_id=cvs.customer_id
group by sv.customer_id,sv.avg_order_value,sv.spending_variability,sv.billing_last_90d,sv.tenure_days,sv.growth_ratio,
sv.recency,sv.frequency,sv.monetary,sv.plan,sv.payment_success,sv.discount,sv.actual_clv,sv.predicted_clv,sv.clv_segment,
sv.segment, cvs.customer_status;

create table machine_learning as
SELECT 
    sv.customer_id,
    ANY_VALUE(sv.avg_order_value) AS avg_order_value,
    ANY_VALUE(sv.spending_variability) AS spending_variability,
    ANY_VALUE(sv.billing_last_90d) AS billing_last_90d,
    ANY_VALUE(sv.tenure_days) AS tenure_days,
    ANY_VALUE(sv.growth_ratio) AS growth_ratio, 
    ANY_VALUE(sv.recency) AS recency,
    ANY_VALUE(sv.frequency) AS frequency,
    ANY_VALUE(sv.monetary) AS monetary,
    ANY_VALUE(sv.plan) AS plan,
    ANY_VALUE(sv.payment_success) AS payment_success,
    ANY_VALUE(sv.discount) AS discount,
    ANY_VALUE(sv.actual_clv) AS actual_clv,
    ANY_VALUE(sv.predicted_clv) AS predicted_clv,
    ANY_VALUE(sv.clv_segment) AS clv_segment, 
    ANY_VALUE(sv.segment) AS segment, 
    ANY_VALUE(cvs.customer_status) AS customer_status
FROM spending_variability4 AS sv
JOIN customer_value_status AS cvs ON sv.customer_id = cvs.customer_id
GROUP BY sv.customer_id;

select*from machine_learning;
