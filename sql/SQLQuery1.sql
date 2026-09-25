CREATE TABLE Walmart_Staging (
    Store           NVARCHAR(20),
    Dept            NVARCHAR(20),
    [Date]          NVARCHAR(20),
    Weekly_Sales    NVARCHAR(30),
    IsHoliday       NVARCHAR(10),
    StoreType       NVARCHAR(5),
    StoreSize       NVARCHAR(20),
    Temperature     NVARCHAR(20),
    Fuel_Price      NVARCHAR(20),
    MarkDown1       NVARCHAR(20),
    MarkDown2       NVARCHAR(20),
    MarkDown3       NVARCHAR(20),
    MarkDown4       NVARCHAR(20),
    MarkDown5       NVARCHAR(20),
    CPI             NVARCHAR(30),
    Unemployment    NVARCHAR(20)
);
GO

---------------------------------------------------------------------

BULK INSERT Walmart_Staging
FROM "C:\Users\IT\Desktop\walmart dataset.csv" 
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001', 
    TABLOCK
);
GO

--------------------------------------------------------------


CREATE TABLE Walmart_Sales (
    Store           INT,
    Dept            INT,
    SalesDate       DATE,
    Weekly_Sales    DECIMAL(18,2),
    IsHoliday       BIT,
    StoreType       CHAR(1),
    StoreSize       INT,
    Temperature     DECIMAL(6,2),
    Fuel_Price      DECIMAL(6,3),
    MarkDown1       DECIMAL(18,2) NULL,
    MarkDown2       DECIMAL(18,2) NULL,
    MarkDown3       DECIMAL(18,2) NULL,
    MarkDown4       DECIMAL(18,2) NULL,
    MarkDown5       DECIMAL(18,2) NULL,
    CPI             DECIMAL(10,4),
    Unemployment    DECIMAL(6,3)
);
GO

----------------------------------------------------------------

INSERT INTO Walmart_Sales
SELECT
    CAST(Store AS INT),
    CAST(Dept AS INT),
    CONVERT(DATE, [Date], 101),
    CAST(Weekly_Sales AS DECIMAL(18,2)),
    CASE WHEN IsHoliday = 'TRUE' THEN 1 ELSE 0 END,
    StoreType,
    CAST(StoreSize AS INT),
    TRY_CAST(Temperature AS DECIMAL(6,2)),
    TRY_CAST(Fuel_Price AS DECIMAL(6,3)),
    TRY_CAST(NULLIF(MarkDown1,'NA') AS DECIMAL(18,2)),
    TRY_CAST(NULLIF(MarkDown2,'NA') AS DECIMAL(18,2)),
    TRY_CAST(NULLIF(MarkDown3,'NA') AS DECIMAL(18,2)),
    TRY_CAST(NULLIF(MarkDown4,'NA') AS DECIMAL(18,2)),
    TRY_CAST(NULLIF(MarkDown5,'NA') AS DECIMAL(18,2)),
    TRY_CAST(CPI AS DECIMAL(10,4)),
    TRY_CAST(Unemployment AS DECIMAL(6,3))
FROM Walmart_Staging;
GO

-----------------------------------------------------------------------------

SELECT COUNT(*) AS TotalRows, MIN(SalesDate) AS MinDate, MAX(SalesDate) AS MaxDate
FROM Walmart_Sales;


SELECT StoreType,
       COUNT(DISTINCT Store) AS NumStores,
       SUM(Weekly_Sales) AS TotalSales,
       AVG(Weekly_Sales) AS AvgWeeklySales
FROM Walmart_Sales
GROUP BY StoreType
ORDER BY TotalSales DESC;


SELECT IsHoliday,
       AVG(Weekly_Sales) AS AvgWeeklySales
FROM Walmart_Sales
GROUP BY IsHoliday;

------------------------------------------------------------------------------

SELECT
    (MAX(CASE WHEN IsHoliday = 1 THEN AvgSales END)
     - MAX(CASE WHEN IsHoliday = 0 THEN AvgSales END))
    / MAX(CASE WHEN IsHoliday = 0 THEN AvgSales END) * 100 AS HolidayLiftPercent
FROM (
    SELECT IsHoliday, AVG(Weekly_Sales) AS AvgSales
    FROM Walmart_Sales
    GROUP BY IsHoliday
) t;
----------------------------------------------------------------------------------

WITH StoreWeek AS (
    SELECT Store, SalesDate,
           SUM(Weekly_Sales) AS TotalWeeklySales,
           AVG(Unemployment) AS Unemployment,
           AVG(Fuel_Price) AS Fuel_Price
    FROM Walmart_Sales
    GROUP BY Store, SalesDate
)
SELECT
    (COUNT(*) * SUM(Unemployment * TotalWeeklySales) - SUM(Unemployment) * SUM(TotalWeeklySales))
    / NULLIF((SQRT(COUNT(*) * SUM(POWER(Unemployment,2)) - POWER(SUM(Unemployment),2))
    * SQRT(COUNT(*) * SUM(POWER(TotalWeeklySales,2)) - POWER(SUM(TotalWeeklySales),2))),0)
    AS Corr_Unemployment_Sales,

    (COUNT(*) * SUM(Fuel_Price * TotalWeeklySales) - SUM(Fuel_Price) * SUM(TotalWeeklySales))
    / NULLIF((SQRT(COUNT(*) * SUM(POWER(Fuel_Price,2)) - POWER(SUM(Fuel_Price),2))
    * SQRT(COUNT(*) * SUM(POWER(TotalWeeklySales,2)) - POWER(SUM(TotalWeeklySales),2))),0)
    AS Corr_FuelPrice_Sales
FROM StoreWeek;



-------------------------------------------------------------------------------------

WITH StoreTotals AS (
    SELECT Store, StoreType,
           SUM(Weekly_Sales) AS TotalSales,
           AVG(Weekly_Sales) AS AvgWeeklySales
    FROM Walmart_Sales
    GROUP BY Store, StoreType
),
Stats AS (
    SELECT AVG(TotalSales) AS OverallAvg, STDEV(TotalSales) AS OverallStd
    FROM StoreTotals
)
SELECT s.Store, s.StoreType, s.TotalSales, s.AvgWeeklySales,
       RANK() OVER (ORDER BY s.TotalSales DESC) AS SalesRank,
       CASE WHEN s.TotalSales < (st.OverallAvg - st.OverallStd) THEN 'Underperformer' ELSE 'Normal' END AS Flag
FROM StoreTotals s
CROSS JOIN Stats st
ORDER BY s.TotalSales DESC;

-------------------------------------------------------------------------
TRUNCATE TABLE Walmart_Sales;

INSERT INTO Walmart_Sales
SELECT
    CAST(Store AS INT),
    CAST(Dept AS INT),
    CONVERT(DATE, [Date], 101),
    CAST(Weekly_Sales AS DECIMAL(18,2)),
    CASE WHEN IsHoliday = 'TRUE' THEN 1 ELSE 0 END,
    StoreType,
    CAST(StoreSize AS INT),
    TRY_CAST(Temperature AS DECIMAL(6,2)),
    TRY_CAST(Fuel_Price AS DECIMAL(6,3)),
    TRY_CAST(NULLIF(MarkDown1,'NA') AS DECIMAL(18,2)),
    TRY_CAST(NULLIF(MarkDown2,'NA') AS DECIMAL(18,2)),
    TRY_CAST(NULLIF(MarkDown3,'NA') AS DECIMAL(18,2)),
    TRY_CAST(NULLIF(MarkDown4,'NA') AS DECIMAL(18,2)),
    TRY_CAST(NULLIF(MarkDown5,'NA') AS DECIMAL(18,2)),
    TRY_CAST(CPI AS DECIMAL(10,4)),
    TRY_CAST(REPLACE(REPLACE(Unemployment, CHAR(13),''), CHAR(10),'') AS DECIMAL(6,3))
FROM Walmart_Staging;


-----------------------------------------------------------------------------------------------


SELECT SalesDate, COUNT(DISTINCT IsHoliday) AS DistinctFlags
FROM Walmart_Sales
GROUP BY SalesDate
HAVING COUNT(DISTINCT IsHoliday) > 1;


------------------------------------------------------------------------------------------------

SELECT DISTINCT SalesDate
FROM Walmart_Sales
WHERE IsHoliday = 1
ORDER BY SalesDate;





---------------------------------------------------------------------

;WITH KnownHolidays AS (
    SELECT CAST(d AS DATE) AS HolidayDate FROM (VALUES
        ('2010-02-12'),('2011-02-11'),('2012-02-10'),
        ('2010-09-10'),('2011-09-09'),('2012-09-07'),
        ('2010-11-26'),('2011-11-25'),
        ('2010-12-31'),('2011-12-30')
    ) AS t(d)
)
SELECT k.HolidayDate,
       CASE WHEN w.SalesDate IS NULL THEN 'Missing in data' ELSE 'OK' END AS Status
FROM KnownHolidays k
LEFT JOIN (SELECT DISTINCT SalesDate FROM Walmart_Sales WHERE IsHoliday = 1) w
    ON k.HolidayDate = w.SalesDate;
