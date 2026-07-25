
WITH CustomerMetrics AS (
    SELECT 
        c.Customer_ID,
        c.Full_Name,
        c.Customer_Segment,
        c.City,
        c.Region,
        c.Gender,
        c.Age,
        DATEDIFF(DAY, MAX(o.Order_Date), GETDATE()) AS Recency,
        COUNT(DISTINCT o.Order_ID) AS Frequency,
        SUM(o.Total_Amount_SAR) AS Monetary,
        AVG(o.Total_Amount_SAR) AS Avg_Order_Value,
        COUNT(DISTINCT o.Coupon_Code) AS Coupons_Used,
        SUM(CASE WHEN o.Order_Status = 'Returned' THEN 1 ELSE 0 END) AS Returns_Count
    FROM dbo.Customers c
    LEFT JOIN dbo.Orders o ON c.Customer_ID = o.Customer_ID
    GROUP BY c.Customer_ID, c.Full_Name, c.Customer_Segment, c.City, c.Region, c.Gender, c.Age
),
RFM_Scores AS (
    SELECT 
        Customer_ID,
        Full_Name,
        Customer_Segment,
        City,
        Region,
        Gender,
        Age,
        Recency,
        Frequency,
        Monetary,
        Avg_Order_Value,
        Coupons_Used,
        Returns_Count,
        NTILE(5) OVER (ORDER BY Recency DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary) AS M_Score
    FROM CustomerMetrics
)
SELECT 
    Customer_ID,
    Full_Name,
    Customer_Segment,
    City,
    Region,
    Gender,
    Age,
    Recency,
    Frequency,
    Monetary,
    Avg_Order_Value,
    Coupons_Used,
    Returns_Count,
    R_Score,
    F_Score,
    M_Score,
    (R_Score + F_Score + M_Score) / 3.0 AS RFM_Score,
    CASE 
        WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
        WHEN R_Score >= 3 AND F_Score >= 3 AND M_Score >= 3 THEN 'Loyal Customers'
        WHEN R_Score >= 4 AND F_Score <= 2 THEN 'New Customers'
        WHEN R_Score <= 2 AND F_Score >= 3 AND M_Score >= 3 THEN 'At Risk'
        WHEN R_Score <= 2 AND F_Score <= 2 AND M_Score <= 2 THEN 'Lost'
        WHEN M_Score >= 4 AND F_Score <= 2 THEN 'Big Spenders'
        WHEN F_Score >= 4 AND M_Score <= 2 THEN 'Frequent Buyers'
        ELSE 'Others'
    END AS Customer_Category
FROM RFM_Scores
ORDER BY RFM_Score DESC;



WITH ProductSales AS (
    SELECT 
        p.Product_ID,
        p.Product_Name,
        p.Category,
        p.Subcategory,
        p.Brand,
        p.Unit_Price_SAR,
        p.Cost_Price_SAR,
        (p.Unit_Price_SAR - p.Cost_Price_SAR) / NULLIF(p.Cost_Price_SAR, 0) * 100 AS Margin_Percent,
        p.Stock_Quantity,
        p.Reorder_Level,
        p.Warranty_Months,
        p.Rating,
        p.Is_Active,
        COUNT(DISTINCT oi.Order_ID) AS Times_Ordered,
        SUM(oi.Quantity) AS Total_Units_Sold,
        SUM(oi.Item_Total_SAR) AS Total_Revenue,
        SUM(oi.Quantity * p.Cost_Price_SAR) AS Total_Cost,
        SUM(oi.Item_Total_SAR) - SUM(oi.Quantity * p.Cost_Price_SAR) AS Total_Profit,
        AVG(oi.Discount_Pct) AS Avg_Discount_Given,
        SUM(CASE WHEN oi.Return_Status = 'Returned' THEN oi.Quantity ELSE 0 END) AS Returned_Units,
        COUNT(CASE WHEN oi.Return_Status = 'Returned' THEN 1 END) AS Return_Orders
    FROM dbo.Products p
    LEFT JOIN dbo.Order_Items oi ON p.Product_ID = oi.Product_ID
    GROUP BY 
        p.Product_ID, p.Product_Name, p.Category, p.Subcategory, p.Brand,
        p.Unit_Price_SAR, p.Cost_Price_SAR, p.Stock_Quantity, p.Reorder_Level,
        p.Warranty_Months, p.Rating, p.Is_Active
)
SELECT 
    Product_ID,
    Product_Name,
    Category,
    Subcategory,
    Brand,
    Unit_Price_SAR,
    Cost_Price_SAR,
    ROUND(Margin_Percent, 2) AS Margin_Percent,
    Stock_Quantity,
    Reorder_Level,
    CASE 
        WHEN Stock_Quantity <= Reorder_Level THEN '⚠️ Reorder Now'
        WHEN Stock_Quantity <= Reorder_Level * 1.5 THEN '⚡ Low Stock'
        ELSE '✅ Adequate'
    END AS Stock_Status,
    Warranty_Months,
    Rating,
    Is_Active,
    Times_Ordered,
    Total_Units_Sold,
    ROUND(Total_Revenue, 2) AS Total_Revenue,
    ROUND(Total_Cost, 2) AS Total_Cost,
    ROUND(Total_Profit, 2) AS Total_Profit,
    ROUND(Avg_Discount_Given, 2) AS Avg_Discount_Given,
    Returned_Units,
    Return_Orders,
    CASE WHEN Total_Units_Sold > 0 
         THEN ROUND(Returned_Units * 100.0 / Total_Units_Sold, 2) 
         ELSE 0 END AS Return_Rate_Percent,
    CASE 
        WHEN Total_Profit > 0 AND Times_Ordered >= 50 THEN '⭐ Star Product'
        WHEN Total_Profit > 0 AND Times_Ordered >= 20 THEN '💰 Profitable'
        WHEN Total_Profit <= 0 THEN '❌ Loss Maker'
        WHEN Times_Ordered < 5 THEN '📉 Low Mover'
        ELSE '📊 Average'
    END AS Product_Status
FROM ProductSales
ORDER BY Total_Profit DESC, Total_Revenue DESC;



WITH MonthlySales AS (
    SELECT 
        YEAR(o.Order_Date) AS Sales_Year,
        MONTH(o.Order_Date) AS Sales_Month,
        DATENAME(MONTH, o.Order_Date) AS Month_Name,
        COUNT(DISTINCT o.Order_ID) AS Total_Orders,
        COUNT(DISTINCT o.Customer_ID) AS Unique_Customers,
        SUM(o.Num_Items) AS Total_Items_Sold,
        SUM(o.Subtotal_SAR) AS Subtotal,
        SUM(o.Shipping_Cost_SAR) AS Total_Shipping,
        SUM(o.Tax_SAR) AS Total_Tax,
        SUM(o.Total_Amount_SAR) AS Total_Revenue,
        AVG(o.Total_Amount_SAR) AS Avg_Order_Value,
        SUM(CASE WHEN o.Payment_Method = 'Credit Card' THEN o.Total_Amount_SAR ELSE 0 END) AS Credit_Card_Revenue,
        SUM(CASE WHEN o.Payment_Method = 'Cash' THEN o.Total_Amount_SAR ELSE 0 END) AS Cash_Revenue,
        SUM(CASE WHEN o.Coupon_Code IS NOT NULL THEN o.Total_Amount_SAR ELSE 0 END) AS Discounted_Revenue,
        SUM(CASE WHEN o.Order_Status = 'Delivered' THEN 1 ELSE 0 END) AS Delivered_Orders,
        SUM(CASE WHEN o.Order_Status = 'Cancelled' THEN 1 ELSE 0 END) AS Cancelled_Orders,
        SUM(CASE WHEN o.Order_Status = 'Returned' THEN 1 ELSE 0 END) AS Returned_Orders,
        SUM(CASE WHEN o.Device_Type = 'Mobile' THEN 1 ELSE 0 END) AS Mobile_Orders,
        SUM(CASE WHEN o.Device_Type = 'Desktop' THEN 1 ELSE 0 END) AS Desktop_Orders
    FROM dbo.Orders o
    GROUP BY YEAR(o.Order_Date), MONTH(o.Order_Date), DATENAME(MONTH, o.Order_Date)
),
YoY_Comparison AS (
    SELECT 
        Sales_Year,
        Sales_Month,
        Month_Name,
        Total_Orders,
        Unique_Customers,
        Total_Items_Sold,
        Subtotal,
        Total_Shipping,
        Total_Tax,
        Total_Revenue,
        Avg_Order_Value,
        Credit_Card_Revenue,
        Cash_Revenue,
        Discounted_Revenue,
        Delivered_Orders,
        Cancelled_Orders,
        Returned_Orders,
        Mobile_Orders,
        Desktop_Orders,
        LAG(Total_Revenue) OVER (PARTITION BY Sales_Month ORDER BY Sales_Year) AS Prev_Year_Revenue,
        LAG(Total_Orders) OVER (PARTITION BY Sales_Month ORDER BY Sales_Year) AS Prev_Year_Orders
    FROM MonthlySales
)
SELECT 
    Sales_Year,
    Month_Name,
    Total_Orders,
    Unique_Customers,
    Total_Items_Sold,
    ROUND(Subtotal, 2) AS Subtotal,
    ROUND(Total_Shipping, 2) AS Total_Shipping,
    ROUND(Total_Tax, 2) AS Total_Tax,
    ROUND(Total_Revenue, 2) AS Total_Revenue,
    ROUND(Avg_Order_Value, 2) AS Avg_Order_Value,
    ROUND(Credit_Card_Revenue, 2) AS Credit_Card_Revenue,
    ROUND(Cash_Revenue, 2) AS Cash_Revenue,
    ROUND(Discounted_Revenue, 2) AS Discounted_Revenue,
    Delivered_Orders,
    Cancelled_Orders,
    Returned_Orders,
    Mobile_Orders,
    Desktop_Orders,
    ROUND(CASE WHEN Prev_Year_Revenue > 0 
          THEN (Total_Revenue - Prev_Year_Revenue) / Prev_Year_Revenue * 100 
          ELSE NULL END, 2) AS YoY_Revenue_Growth_Percent,
    ROUND(CASE WHEN Prev_Year_Orders > 0 
          THEN (Total_Orders - Prev_Year_Orders) / Prev_Year_Orders * 100 
          ELSE NULL END, 2) AS YoY_Orders_Growth_Percent
FROM YoY_Comparison
ORDER BY Sales_Year, Sales_Month;



WITH OrderDetails AS (
    SELECT 
        o.Order_ID,
        o.Customer_ID,
        c.Full_Name,
        c.Customer_Segment,
        o.Order_Date,
        o.Order_Time,
        o.Delivery_Date,
        DATEDIFF(DAY, o.Order_Date, o.Delivery_Date) AS Delivery_Days,
        o.Order_Status,
        o.Payment_Method,
        o.Shipping_Provider,
        o.Subtotal_SAR,
        o.Shipping_Cost_SAR,
        o.Tax_SAR,
        o.Total_Amount_SAR,
        o.Num_Items,
        o.Coupon_Code,
        o.Device_Type,
        o.City AS Order_City,
        o.Region AS Order_Region,
        COUNT(oi.Item_ID) AS Line_Items,
        SUM(CASE WHEN oi.Return_Status = 'Returned' THEN 1 ELSE 0 END) AS Returned_Items,
        STRING_AGG(DISTINCT oi.Category, ', ') AS Categories_Purchased
    FROM dbo.Orders o
    INNER JOIN dbo.Customers c ON o.Customer_ID = c.Customer_ID
    LEFT JOIN dbo.Order_Items oi ON o.Order_ID = oi.Order_ID
    GROUP BY 
        o.Order_ID, o.Customer_ID, c.Full_Name, c.Customer_Segment,
        o.Order_Date, o.Order_Time, o.Delivery_Date, o.Order_Status,
        o.Payment_Method, o.Shipping_Provider, o.Subtotal_SAR,
        o.Shipping_Cost_SAR, o.Tax_SAR, o.Total_Amount_SAR,
        o.Num_Items, o.Coupon_Code, o.Device_Type, o.City, o.Region
)
SELECT 
    Order_ID,
    Customer_ID,
    Full_Name,
    Customer_Segment,
    Order_Date,
    Order_Time,
    Delivery_Date,
    Delivery_Days,
    CASE 
        WHEN Delivery_Days <= 1 THEN '⚡ Same/Next Day'
        WHEN Delivery_Days <= 3 THEN '📦 Fast (2-3 Days)'
        WHEN Delivery_Days <= 7 THEN '🚚 Standard (4-7 Days)'
        ELSE '⏳ Delayed (>7 Days)'
    END AS Delivery_Speed,
    Order_Status,
    Payment_Method,
    Shipping_Provider,
    ROUND(Subtotal_SAR, 2) AS Subtotal_SAR,
    ROUND(Shipping_Cost_SAR, 2) AS Shipping_Cost_SAR,
    ROUND(Tax_SAR, 2) AS Tax_SAR,
    ROUND(Total_Amount_SAR, 2) AS Total_Amount_SAR,
    Num_Items,
    Line_Items,
    ROUND(Total_Amount_SAR / NULLIF(Num_Items, 0), 2) AS Avg_Price_Per_Item,
    Coupon_Code,
    Device_Type,
    Order_City,
    Order_Region,
    Returned_Items,
    Categories_Purchased,
    CASE 
        WHEN Total_Amount_SAR >= 1000 THEN '💎 Premium'
        WHEN Total_Amount_SAR >= 500 THEN '🥇 High Value'
        WHEN Total_Amount_SAR >= 200 THEN '🥈 Medium Value'
        ELSE '🥉 Low Value'
    END AS Order_Tier
FROM OrderDetails
ORDER BY Order_Date DESC, Total_Amount_SAR DESC;


WITH CategoryMetrics AS (
    SELECT 
        oi.Category,
        oi.Subcategory,
        COUNT(DISTINCT oi.Product_ID) AS Unique_Products,
        COUNT(DISTINCT oi.Order_ID) AS Orders_Count,
        SUM(oi.Quantity) AS Total_Units,
        SUM(oi.Item_Total_SAR) AS Total_Revenue,
        AVG(oi.Unit_Price_SAR) AS Avg_Unit_Price,
        AVG(oi.Discount_Pct) AS Avg_Discount,
        SUM(CASE WHEN oi.Return_Status = 'Returned' THEN oi.Quantity ELSE 0 END) AS Returned_Units,
        COUNT(DISTINCT o.Customer_ID) AS Unique_Buyers,
        COUNT(DISTINCT CASE WHEN o.Device_Type = 'Mobile' THEN o.Order_ID END) AS Mobile_Orders,
        COUNT(DISTINCT CASE WHEN o.Coupon_Code IS NOT NULL THEN o.Order_ID END) AS Coupon_Orders
    FROM dbo.Order_Items oi
    INNER JOIN dbo.Orders o ON oi.Order_ID = o.Order_ID
    GROUP BY oi.Category, oi.Subcategory
),
CategoryTotals AS (
    SELECT 
        Category,
        SUM(Total_Revenue) AS Category_Total_Revenue
    FROM CategoryMetrics
    GROUP BY Category
)
SELECT 
    cm.Category,
    cm.Subcategory,
    cm.Unique_Products,
    cm.Orders_Count,
    cm.Total_Units,
    ROUND(cm.Total_Revenue, 2) AS Total_Revenue,
    ROUND(cm.Total_Revenue * 100.0 / NULLIF(ct.Category_Total_Revenue, 0), 2) AS Subcategory_Share_Percent,
    ROUND(cm.Avg_Unit_Price, 2) AS Avg_Unit_Price,
    ROUND(cm.Avg_Discount, 2) AS Avg_Discount,
    cm.Returned_Units,
    ROUND(cm.Returned_Units * 100.0 / NULLIF(cm.Total_Units, 0), 2) AS Return_Rate_Percent,
    cm.Unique_Buyers,
    cm.Mobile_Orders,
    ROUND(cm.Mobile_Orders * 100.0 / NULLIF(cm.Orders_Count, 0), 2) AS Mobile_Share_Percent,
    cm.Coupon_Orders,
    ROUND(cm.Coupon_Orders * 100.0 / NULLIF(cm.Orders_Count, 0), 2) AS Coupon_Usage_Percent,
    ROUND(cm.Total_Revenue / NULLIF(cm.Orders_Count, 0), 2) AS Revenue_Per_Order,
    ROUND(cm.Total_Revenue / NULLIF(cm.Unique_Buyers, 0), 2) AS Revenue_Per_Buyer,
    RANK() OVER (PARTITION BY cm.Category ORDER BY cm.Total_Revenue DESC) AS Subcategory_Rank
FROM CategoryMetrics cm
INNER JOIN CategoryTotals ct ON cm.Category = ct.Category
ORDER BY cm.Category, cm.Total_Revenue DESC;



WITH CustomerOrders AS (
    SELECT 
        c.Customer_ID,
        c.Full_Name,
        c.Gender,
        c.Age,
        c.City,
        c.Region,
        c.Customer_Segment,
        c.Registration_Date,
        MIN(o.Order_Date) AS First_Order_Date,
        MAX(o.Order_Date) AS Last_Order_Date,
        COUNT(DISTINCT o.Order_ID) AS Total_Orders,
        SUM(o.Total_Amount_SAR) AS Total_Spent,
        AVG(o.Total_Amount_SAR) AS Avg_Order_Value,
        SUM(o.Num_Items) AS Total_Items,
        DATEDIFF(DAY, MIN(o.Order_Date), MAX(o.Order_Date)) AS Customer_Lifespan_Days,
        DATEDIFF(DAY, c.Registration_Date, MAX(o.Order_Date)) AS Days_Since_Registration
    FROM dbo.Customers c
    INNER JOIN dbo.Orders o ON c.Customer_ID = o.Customer_ID
    GROUP BY 
        c.Customer_ID, c.Full_Name, c.Gender, c.Age, c.City,
        c.Region, c.Customer_Segment, c.Registration_Date
),
CLV_Calculation AS (
    SELECT 
        Customer_ID,
        Full_Name,
        Gender,
        Age,
        City,
        Region,
        Customer_Segment,
        Registration_Date,
        First_Order_Date,
        Last_Order_Date,
        Total_Orders,
        Total_Spent,
        Avg_Order_Value,
        Total_Items,
        Customer_Lifespan_Days,
        Days_Since_Registration,
        CASE WHEN Customer_Lifespan_Days > 0 
             THEN Total_Orders * 1.0 / Customer_Lifespan_Days * 30 
             ELSE Total_Orders END AS Purchase_Frequency_Per_Month,
        CASE WHEN Total_Orders > 1 
             THEN Customer_Lifespan_Days * 1.0 / (Total_Orders - 1) 
             ELSE NULL END AS Avg_Days_Between_Orders
    FROM CustomerOrders
)
SELECT 
    Customer_ID,
    Full_Name,
    Gender,
    Age,
    City,
    Region,
    Customer_Segment,
    Registration_Date,
    First_Order_Date,
    Last_Order_Date,
    Total_Orders,
    ROUND(Total_Spent, 2) AS Total_Spent,
    ROUND(Avg_Order_Value, 2) AS Avg_Order_Value,
    Total_Items,
    Customer_Lifespan_Days,
    ROUND(Purchase_Frequency_Per_Month, 2) AS Purchase_Frequency_Per_Month,
    ROUND(Avg_Days_Between_Orders, 1) AS Avg_Days_Between_Orders,
    -- CLV Estimation (Projected 1-Year Value based on historical behavior)
    ROUND(Avg_Order_Value * Purchase_Frequency_Per_Month * 12, 2) AS Estimated_Annual_CLV,
    CASE 
        WHEN Total_Spent >= 10000 AND Total_Orders >= 20 THEN '💎 VIP'
        WHEN Total_Spent >= 5000 AND Total_Orders >= 10 THEN '🥇 Gold'
        WHEN Total_Spent >= 2000 AND Total_Orders >= 5 THEN '🥈 Silver'
        WHEN Total_Orders >= 2 THEN '🥉 Bronze'
        ELSE '⚪ New'
    END AS CLV_Tier,
    CASE 
        WHEN DATEDIFF(DAY, Last_Order_Date, GETDATE()) <= 30 THEN '🟢 Active'
        WHEN DATEDIFF(DAY, Last_Order_Date, GETDATE()) <= 90 THEN '🟡 Warm'
        WHEN DATEDIFF(DAY, Last_Order_Date, GETDATE()) <= 180 THEN '🟠 Cooling'
        ELSE '🔴 Inactive'
    END AS Engagement_Status
FROM CLV_Calculation
ORDER BY Total_Spent DESC;




WITH RegionalMetrics AS (
    SELECT 
        o.Region,
        o.City,
        COUNT(DISTINCT o.Order_ID) AS Total_Orders,
        COUNT(DISTINCT o.Customer_ID) AS Unique_Customers,
        COUNT(DISTINCT c.Customer_ID) AS Total_Customers_In_City,
        SUM(o.Total_Amount_SAR) AS Total_Revenue,
        AVG(o.Total_Amount_SAR) AS Avg_Order_Value,
        SUM(o.Shipping_Cost_SAR) AS Total_Shipping_Cost,
        SUM(o.Tax_SAR) AS Total_Tax,
        SUM(o.Num_Items) AS Total_Items,
        AVG(DATEDIFF(DAY, o.Order_Date, o.Delivery_Date)) AS Avg_Delivery_Days,
        COUNT(DISTINCT CASE WHEN o.Device_Type = 'Mobile' THEN o.Order_ID END) AS Mobile_Orders,
        COUNT(DISTINCT CASE WHEN o.Payment_Method = 'Credit Card' THEN o.Order_ID END) AS Credit_Card_Orders,
        COUNT(DISTINCT CASE WHEN o.Order_Status = 'Delivered' THEN o.Order_ID END) AS Delivered_Orders,
        COUNT(DISTINCT CASE WHEN o.Order_Status = 'Returned' THEN o.Order_ID END) AS Returned_Orders
    FROM dbo.Orders o
    LEFT JOIN dbo.Customers c ON o.City = c.City
    GROUP BY o.Region, o.City
),
RegionalTotals AS (
    SELECT 
        Region,
        SUM(Total_Revenue) AS Region_Total_Revenue,
        SUM(Total_Orders) AS Region_Total_Orders
    FROM RegionalMetrics
    GROUP BY Region
)
SELECT 
    rm.Region,
    rm.City,
    rm.Total_Orders,
    rm.Unique_Customers,
    rm.Total_Customers_In_City,
    ROUND(rm.Total_Revenue, 2) AS Total_Revenue,
    ROUND(rm.Total_Revenue * 100.0 / NULLIF(rt.Region_Total_Revenue, 0), 2) AS City_Share_In_Region_Percent,
    ROUND(rm.Avg_Order_Value, 2) AS Avg_Order_Value,
    ROUND(rm.Total_Shipping_Cost, 2) AS Total_Shipping_Cost,
    ROUND(rm.Total_Tax, 2) AS Total_Tax,
    rm.Total_Items,
    ROUND(rm.Avg_Delivery_Days, 1) AS Avg_Delivery_Days,
    rm.Mobile_Orders,
    ROUND(rm.Mobile_Orders * 100.0 / NULLIF(rm.Total_Orders, 0), 2) AS Mobile_Percent,
    rm.Credit_Card_Orders,
    ROUND(rm.Credit_Card_Orders * 100.0 / NULLIF(rm.Total_Orders, 0), 2) AS Credit_Card_Percent,
    rm.Delivered_Orders,
    rm.Returned_Orders,
    ROUND(rm.Returned_Orders * 100.0 / NULLIF(rm.Total_Orders, 0), 2) AS Return_Rate_Percent,
    ROUND(rm.Total_Revenue / NULLIF(rm.Unique_Customers, 0), 2) AS Revenue_Per_Customer,
    RANK() OVER (PARTITION BY rm.Region ORDER BY rm.Total_Revenue DESC) AS City_Rank_In_Region,
    RANK() OVER (ORDER BY rm.Total_Revenue DESC) AS Overall_City_Rank
FROM RegionalMetrics rm
INNER JOIN RegionalTotals rt ON rm.Region = rt.Region
ORDER BY rm.Region, rm.Total_Revenue DESC;



WITH ReturnAnalysis AS (
    SELECT 
        oi.Product_ID,
        oi.Product_Name,
        oi.Category,
        oi.Subcategory,
        oi.Brand,
        oi.Return_Status,
        oi.Return_Reason,
        oi.Quantity AS Returned_Qty,
        oi.Item_Total_SAR AS Refund_Amount,
        o.Customer_ID,
        c.Full_Name,
        c.Customer_Segment,
        o.Order_Date,
        o.Delivery_Date,
        DATEDIFF(DAY, o.Delivery_Date, o.Order_Date) AS Days_To_Return, -- Negative if return before delivery (data issue)
        o.Payment_Method,
        o.City,
        o.Region
    FROM dbo.Order_Items oi
    INNER JOIN dbo.Orders o ON oi.Order_ID = o.Order_ID
    INNER JOIN dbo.Customers c ON o.Customer_ID = c.Customer_ID
    WHERE oi.Return_Status = 'Returned'
),
ProductReturnStats AS (
    SELECT 
        Product_ID,
        Product_Name,
        Category,
        Subcategory,
        Brand,
        COUNT(*) AS Total_Returns,
        SUM(Returned_Qty) AS Total_Returned_Units,
        SUM(Refund_Amount) AS Total_Refund_Amount,
        COUNT(DISTINCT Customer_ID) AS Unique_Customers_Returned,
        Return_Reason,
        COUNT(*) AS Returns_By_Reason
    FROM ReturnAnalysis
    GROUP BY Product_ID, Product_Name, Category, Subcategory, Brand, Return_Reason
)
SELECT 
    Product_ID,
    Product_Name,
    Category,
    Subcategory,
    Brand,
    Total_Returns,
    Total_Returned_Units,
    ROUND(Total_Refund_Amount, 2) AS Total_Refund_Amount,
    Unique_Customers_Returned,
    Return_Reason,
    Returns_By_Reason,
    ROUND(Returns_By_Reason * 100.0 / NULLIF(Total_Returns, 0), 2) AS Reason_Share_Percent,
    RANK() OVER (PARTITION BY Product_ID ORDER BY Returns_By_Reason DESC) AS Reason_Rank_Per_Product,
    RANK() OVER (ORDER BY Total_Refund_Amount DESC) AS Overall_Refund_Rank
FROM ProductReturnStats
ORDER BY Total_Refund_Amount DESC, Reason_Rank_Per_Product;




WITH PaymentAnalysis AS (
    SELECT 
        o.Payment_Method,
        o.Device_Type,
        o.Region,
        COUNT(DISTINCT o.Order_ID) AS Total_Orders,
        COUNT(DISTINCT o.Customer_ID) AS Unique_Customers,
        SUM(o.Total_Amount_SAR) AS Total_Revenue,
        AVG(o.Total_Amount_SAR) AS Avg_Order_Value,
        SUM(o.Subtotal_SAR) AS Subtotal,
        SUM(o.Shipping_Cost_SAR) AS Shipping_Cost,
        SUM(o.Tax_SAR) AS Tax,
        SUM(o.Num_Items) AS Total_Items,
        AVG(DATEDIFF(DAY, o.Order_Date, o.Delivery_Date)) AS Avg_Delivery_Days,
        COUNT(DISTINCT CASE WHEN o.Coupon_Code IS NOT NULL THEN o.Order_ID END) AS Coupon_Orders,
        COUNT(DISTINCT CASE WHEN o.Order_Status = 'Delivered' THEN o.Order_ID END) AS Delivered_Orders,
        COUNT(DISTINCT CASE WHEN o.Order_Status = 'Cancelled' THEN o.Order_ID END) AS Cancelled_Orders,
        COUNT(DISTINCT CASE WHEN o.Order_Status = 'Returned' THEN o.Order_ID END) AS Returned_Orders
    FROM dbo.Orders o
    GROUP BY o.Payment_Method, o.Device_Type, o.Region
)
SELECT 
    Payment_Method,
    Device_Type,
    Region,
    Total_Orders,
    Unique_Customers,
    ROUND(Total_Revenue, 2) AS Total_Revenue,
    ROUND(Avg_Order_Value, 2) AS Avg_Order_Value,
    ROUND(Subtotal, 2) AS Subtotal,
    ROUND(Shipping_Cost, 2) AS Shipping_Cost,
    ROUND(Tax, 2) AS Tax,
    Total_Items,
    ROUND(Avg_Delivery_Days, 1) AS Avg_Delivery_Days,
    Coupon_Orders,
    ROUND(Coupon_Orders * 100.0 / NULLIF(Total_Orders, 0), 2) AS Coupon_Usage_Percent,
    Delivered_Orders,
    Cancelled_Orders,
    ROUND(Cancelled_Orders * 100.0 / NULLIF(Total_Orders, 0), 2) AS Cancellation_Rate_Percent,
    Returned_Orders,
    ROUND(Returned_Orders * 100.0 / NULLIF(Total_Orders, 0), 2) AS Return_Rate_Percent,
    ROUND(Total_Revenue / NULLIF(Unique_Customers, 0), 2) AS Revenue_Per_Customer,
    RANK() OVER (PARTITION BY Payment_Method ORDER BY Total_Revenue DESC) AS Device_Rank_By_Payment,
    RANK() OVER (PARTITION BY Region ORDER BY Total_Revenue DESC) AS Payment_Rank_By_Region
FROM PaymentAnalysis
ORDER BY Total_Revenue DESC;




WITH OrderCategories AS (
    SELECT 
        oi.Order_ID,
        oi.Category,
        COUNT(DISTINCT oi.Product_ID) AS Products_In_Category
    FROM dbo.Order_Items oi
    GROUP BY oi.Order_ID, oi.Category
),
CategoryPairs AS (
    SELECT 
        a.Order_ID,
        a.Category AS Category_A,
        b.Category AS Category_B,
        COUNT(*) OVER (PARTITION BY a.Category) AS Total_Orders_With_A,
        COUNT(*) OVER (PARTITION BY b.Category) AS Total_Orders_With_B
    FROM OrderCategories a
    INNER JOIN OrderCategories b ON a.Order_ID = b.Order_ID AND a.Category < b.Category
),
PairStats AS (
    SELECT 
        Category_A,
        Category_B,
        COUNT(DISTINCT Order_ID) AS Orders_With_Both,
        MAX(Total_Orders_With_A) AS Total_Orders_A,
        MAX(Total_Orders_With_B) AS Total_Orders_B
    FROM CategoryPairs
    GROUP BY Category_A, Category_B
)
SELECT 
    Category_A,
    Category_B,
    Orders_With_Both,
    Total_Orders_A,
    Total_Orders_B,
    ROUND(Orders_With_Both * 100.0 / NULLIF(Total_Orders_A, 0), 2) AS Confidence_A_To_B_Percent,
    ROUND(Orders_With_Both * 100.0 / NULLIF(Total_Orders_B, 0), 2) AS Confidence_B_To_A_Percent,
    ROUND(Orders_With_Both * 100.0 / NULLIF((Total_Orders_A + Total_Orders_B - Orders_With_Both), 0), 2) AS Lift_Percent,
    CASE 
        WHEN Orders_With_Both >= 100 AND Confidence_A_To_B_Percent >= 30 THEN '🔥 Strong Association'
        WHEN Orders_With_Both >= 50 AND Confidence_A_To_B_Percent >= 20 THEN '💡 Moderate Association'
        WHEN Orders_With_Both >= 20 THEN '📊 Weak Association'
        ELSE '❌ No Significant Association'
    END AS Association_Strength
FROM PairStats
ORDER BY Orders_With_Both DESC, Confidence_A_To_B_Percent DESC;


