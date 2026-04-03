show tables;
#Task 1
#1. Remove duplicates
SELECT Order_ID, COUNT(*) 
FROM orders
GROUP BY Order_ID
HAVING COUNT(*) > 1;
#2. Replace NULL Traffic Delay
UPDATE routes r
JOIN (
    SELECT Route_ID, AVG(Traffic_Delay_Min) AS avg_delay
    FROM routes
    GROUP BY Route_ID
) t
ON r.Route_ID = t.Route_ID
SET r.Traffic_Delay_Min = t.avg_delay
WHERE r.Traffic_Delay_Min IS NULL;
#3. Convert date format
ALTER TABLE orders
MODIFY Order_Date DATE,
MODIFY Expected_Delivery_Date DATE,
MODIFY Actual_Delivery_Date DATE;
#4. Flag invalid dates
SELECT *
FROM orders
WHERE Actual_Delivery_Date < Order_Date;

#Task 2
#TASK 2.1 — Delivery delay for each order
SELECT 
    Order_ID,
    Warehouse_ID,
    Route_ID,
    DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) AS Delay_Days
FROM orders;
#TASK 2.2 — Top 10 delayed routes
SELECT 
    Route_ID,
    AVG(DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date)) AS Avg_Delay_Days
FROM orders
GROUP BY Route_ID
ORDER BY Avg_Delay_Days DESC
LIMIT 10;
#TASK 2.3 — Window function (IMPORTANT for marks 🔥)
SELECT 
    Order_ID,
    Warehouse_ID,
    DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) AS Delay_Days,
    RANK() OVER (
        PARTITION BY Warehouse_ID
        ORDER BY DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) DESC
    ) AS Delay_Rank
FROM orders;

#TASK 3: Route Optimization Insights
#3.1 — Route-level metrics
SELECT 
    r.Route_ID,

    -- Avg delivery time (Order → Actual)
    AVG(DATEDIFF(o.Actual_Delivery_Date, o.Order_Date)) AS Avg_Delivery_Time_Days,

    -- Avg traffic delay
    AVG(r.Traffic_Delay_Min) AS Avg_Traffic_Delay,

    -- Efficiency ratio
    (r.Distance_KM / r.Average_Travel_Time_Min) AS Efficiency_Ratio

FROM routes r
JOIN orders o ON r.Route_ID = o.Route_ID

GROUP BY 
    r.Route_ID, 
    r.Distance_KM, 
    r.Average_Travel_Time_Min

ORDER BY Efficiency_Ratio ASC;
#3.2 — Worst 3 routes (lowest efficiency)
SELECT 
    Route_ID,
    (Distance_KM / Average_Travel_Time_Min) AS Efficiency_Ratio
FROM routes
ORDER BY Efficiency_Ratio ASC
LIMIT 3;
#3.3 — Routes with >20% delayed shipments
SELECT 
    Route_ID,
    COUNT(*) AS Total_Orders,

    SUM(CASE 
        WHEN DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) > 0 
        THEN 1 ELSE 0 
    END) AS Delayed_Orders,

    (SUM(CASE 
        WHEN DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) > 0 
        THEN 1 ELSE 0 
    END) * 100.0 / COUNT(*)) AS Delay_Percentage

FROM orders

GROUP BY Route_ID

HAVING Delay_Percentage > 20;

#TASK 4 — Warehouse Performance
#4.1 — Top 3 warehouses (highest processing time)
SELECT 
    Warehouse_ID,
    City,
    Average_Processing_Time_Min
FROM warehouses
ORDER BY Average_Processing_Time_Min DESC
LIMIT 3;
#4.2 — Total vs Delayed shipments per warehouse
SELECT 
    Warehouse_ID,
    
    COUNT(*) AS Total_Orders,

    SUM(CASE 
        WHEN DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) > 0 
        THEN 1 ELSE 0 
    END) AS Delayed_Orders

FROM orders

GROUP BY Warehouse_ID;
#4.3 — Bottleneck warehouses
WITH avg_processing AS (
    SELECT AVG(Average_Processing_Time_Min) AS global_avg
    FROM warehouses
)

SELECT 
    w.Warehouse_ID,
    w.City,
    w.Average_Processing_Time_Min
FROM warehouses w, avg_processing a
WHERE w.Average_Processing_Time_Min > a.global_avg;
#4.4 — Rank warehouses by on-time delivery %
SELECT 
    Warehouse_ID,

    (SUM(CASE 
        WHEN DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) = 0 
        THEN 1 ELSE 0 
    END) * 100.0 / COUNT(*)) AS OnTime_Percentage,

    RANK() OVER (
        ORDER BY 
        (SUM(CASE 
            WHEN DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) = 0 
            THEN 1 ELSE 0 
        END) * 100.0 / COUNT(*)) DESC
    ) AS Warehouse_Rank

FROM orders

GROUP BY Warehouse_ID;

#TASK 5: Delivery Agent Performance
#5.1 — Rank agents per route (On-time %)
SELECT 
    da.Agent_ID,
    da.Agent_Name,
    o.Route_ID,

    (SUM(CASE 
        WHEN DATEDIFF(o.Actual_Delivery_Date, o.Expected_Delivery_Date) = 0 
        THEN 1 ELSE 0 
    END) * 100.0 / COUNT(*)) AS OnTime_Percentage,

    RANK() OVER (
        PARTITION BY o.Route_ID
        ORDER BY 
        (SUM(CASE 
            WHEN DATEDIFF(o.Actual_Delivery_Date, o.Expected_Delivery_Date) = 0 
            THEN 1 ELSE 0 
        END) * 100.0 / COUNT(*)) DESC
    ) AS Rank_in_Route

FROM orders o
JOIN deliveryagents da ON o.Agent_ID = da.Agent_ID

GROUP BY da.Agent_ID, da.Agent_Name, o.Route_ID;
#5.2 — Agents with <80% on-time
SELECT 
    da.Agent_ID,
    da.Agent_Name,

    (SUM(CASE 
        WHEN DATEDIFF(o.Actual_Delivery_Date, o.Expected_Delivery_Date) = 0 
        THEN 1 ELSE 0 
    END) * 100.0 / COUNT(*)) AS OnTime_Percentage

FROM orders o
JOIN deliveryagents da ON o.Agent_ID = da.Agent_ID

GROUP BY da.Agent_ID, da.Agent_Name

HAVING OnTime_Percentage < 80;
#5.3 — Compare avg speed (Top 5 vs Bottom 5)
SELECT 
    (SELECT AVG(Avg_Speed_KMPH) 
     FROM (
        SELECT Avg_Speed_KMPH 
        FROM deliveryagents 
        ORDER BY Avg_Speed_KMPH DESC 
        LIMIT 5
     ) AS top5) AS Avg_Top5_Speed,

    (SELECT AVG(Avg_Speed_KMPH) 
     FROM (
        SELECT Avg_Speed_KMPH 
        FROM deliveryagents 
        ORDER BY Avg_Speed_KMPH ASC 
        LIMIT 5
     ) AS bottom5) AS Avg_Bottom5_Speed;
     
#TASK 6: Shipment Tracking Analytics
#6.1 — Last checkpoint + time
SELECT 
    st.Order_ID,
    st.Checkpoint,
    st.Checkpoint_Time
FROM shipmenttracking st
JOIN (
    SELECT 
        Order_ID,
        MAX(Checkpoint_Time) AS Last_Time
    FROM shipmenttracking
    GROUP BY Order_ID
) last_cp
ON st.Order_ID = last_cp.Order_ID
AND st.Checkpoint_Time = last_cp.Last_Time;
#6.2 — Most common delay reasons
SELECT 
    Delay_Reason,
    COUNT(*) AS Occurrences
FROM shipmenttracking
WHERE Delay_Reason != 'None'
GROUP BY Delay_Reason
ORDER BY Occurrences DESC;
#6.3 — Orders with >2 delayed checkpoints
SELECT 
    Order_ID,
    COUNT(*) AS Delay_Count
FROM shipmenttracking
WHERE Delay_Minutes > 0
GROUP BY Order_ID
HAVING COUNT(*) > 2;

#TASK 7: Advanced KPI Reporting
#7.1 Average Delivery Delay per Region
SELECT 
    r.Start_Location AS Region,
    AVG(DATEDIFF(o.Actual_Delivery_Date, o.Expected_Delivery_Date)) AS Avg_Delay_Days
FROM orders o
JOIN routes r ON o.Route_ID = r.Route_ID
GROUP BY r.Start_Location
ORDER BY Avg_Delay_Days DESC;
#7.2 On-Time Delivery Percentage
SELECT 
    COUNT(*) AS Total_Orders,

    SUM(CASE 
        WHEN DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) = 0 
        THEN 1 ELSE 0 
    END) AS OnTime_Orders,

    (SUM(CASE 
        WHEN DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) = 0 
        THEN 1 ELSE 0 
    END) * 100.0 / COUNT(*)) AS OnTime_Percentage

FROM orders;
#7.3 Average Traffic Delay per Route
SELECT 
    Route_ID,
    AVG(Traffic_Delay_Min) AS Avg_Traffic_Delay_Min
FROM routes
GROUP BY Route_ID
ORDER BY Avg_Traffic_Delay_Min DESC;