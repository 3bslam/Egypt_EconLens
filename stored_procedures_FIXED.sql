-- ============================================================
-- Egyptian Supply Chain & Procurement BI Platform
-- Stored Procedures — CRUD Operations (FIXED)
-- ============================================================
-- Fixes applied vs. original:
--   #1, #4, #19  qty_kg column removed (Comtrade HS2 source = always NULL)
--   #5           sp_GetMacroIndicators aggregates monthly rows -> annual
--   #6           sp_GetSupplyChainKPIs OTIF logic corrected (CLOSED ok,
--                denominator = delivered orders only)
--   #20          sp_RunDQValidation rewritten (clears log, real checks)
--   #10          sp_AddCountry insert column order matches schema
-- Categories:
--   1. READ  (sp_Get...)  — Query & report procedures
--   2. CREATE (sp_Add...) — Insert new records
--   3. UPDATE (sp_Upd...) — Modify existing records
--   4. DELETE (sp_Del...) — Remove records
--   5. UTIL  (sp_...)     — Utility & validation
-- ============================================================

USE EgyptBI_DWH;
GO

-- ============================================================
-- ======================== READ ==============================
-- ============================================================

-- ------------------------------------------------------------
-- 1. Get trade summary by year/month  (FIXED: removed qty_kg)
-- Usage: EXEC sp_GetTradeSummary @year = 2023
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetTradeSummary
    @year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.[year],
        d.[month],
        d.month_name,
        f.flow_type,
        CASE f.flow_type WHEN 'X' THEN 'Export' ELSE 'Import' END AS flow_name,
        COUNT(*) AS record_count,
        SUM(f.trade_value_usd) AS total_value_usd
    FROM fact_trade_flows f
    JOIN dim_date d ON f.date_key = d.date_key
    WHERE (@year IS NULL OR d.[year] = @year)
    GROUP BY d.[year], d.[month], d.month_name, f.flow_type
    ORDER BY d.[year], d.[month], f.flow_type;
END
GO

-- ------------------------------------------------------------
-- 2. Get trade balance (exports - imports) by year
-- Usage: EXEC sp_GetTradeBalance
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetTradeBalance
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.[year],
        SUM(CASE WHEN f.flow_type = 'X' THEN f.trade_value_usd ELSE 0 END) AS total_exports,
        SUM(CASE WHEN f.flow_type = 'M' THEN f.trade_value_usd ELSE 0 END) AS total_imports,
        SUM(CASE WHEN f.flow_type = 'X' THEN f.trade_value_usd ELSE 0 END) -
        SUM(CASE WHEN f.flow_type = 'M' THEN f.trade_value_usd ELSE 0 END) AS trade_balance,
        CASE
            WHEN SUM(CASE WHEN f.flow_type = 'M' THEN f.trade_value_usd ELSE 0 END) >
                 SUM(CASE WHEN f.flow_type = 'X' THEN f.trade_value_usd ELSE 0 END)
            THEN 'DEFICIT'
            ELSE 'SURPLUS'
        END AS balance_status
    FROM fact_trade_flows f
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY d.[year]
    ORDER BY d.[year];
END
GO

-- ------------------------------------------------------------
-- 3. Get top trading partners
-- Usage: EXEC sp_GetTopPartners @flow = 'X', @year = 2023, @top = 10
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetTopPartners
    @flow CHAR(1) = 'X',
    @year INT = NULL,
    @top INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP(@top)
        c.country_name,
        c.iso_code,
        c.region,
        SUM(f.trade_value_usd) AS total_value_usd,
        COUNT(*) AS record_count
    FROM fact_trade_flows f
    JOIN dim_country c ON f.country_key = c.country_key
    JOIN dim_date d ON f.date_key = d.date_key
    WHERE f.flow_type = @flow
      AND (@year IS NULL OR d.[year] = @year)
    GROUP BY c.country_name, c.iso_code, c.region
    ORDER BY total_value_usd DESC;
END
GO

-- ------------------------------------------------------------
-- 4. Get top commodities  (FIXED: removed qty_kg)
-- Usage: EXEC sp_GetTopCommodities @flow = 'M', @year = 2022, @top = 10
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetTopCommodities
    @flow CHAR(1) = 'M',
    @year INT = NULL,
    @top INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP(@top)
        cm.hs_code,
        cm.[description],
        cm.category,
        cm.is_strategic,
        SUM(f.trade_value_usd) AS total_value_usd,
        COUNT(*) AS record_count
    FROM fact_trade_flows f
    JOIN dim_commodity cm ON f.commodity_key = cm.commodity_key
    JOIN dim_date d ON f.date_key = d.date_key
    WHERE f.flow_type = @flow
      AND (@year IS NULL OR d.[year] = @year)
    GROUP BY cm.hs_code, cm.[description], cm.category, cm.is_strategic
    ORDER BY total_value_usd DESC;
END
GO

-- ------------------------------------------------------------
-- 5. Get macro indicators by year
-- FIXED: dim_egypt_macro now has 84 monthly rows. Aggregate to annual.
--        usd_egp -> average of 12 monthly rates.
--        gdp/inflation/reserves -> MAX (broadcast value, all months same).
--        is_crisis_year -> MAX (1 if any month of year flagged crisis).
-- Usage: EXEC sp_GetMacroIndicators @year = 2023
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetMacroIndicators
    @year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        m.[year],
        CAST(AVG(m.usd_egp_annual_avg) AS DECIMAL(10,4)) AS usd_egp_annual_avg,
        MAX(m.gdp_usd)              AS gdp_usd,
        MAX(m.gdp_growth_pct)       AS gdp_growth_pct,
        MAX(m.inflation_pct)        AS inflation_pct,
        MAX(m.foreign_reserves_usd) AS foreign_reserves_usd,
        MAX(CAST(d.is_crisis_year AS INT)) AS is_crisis_year
    FROM dim_egypt_macro m
    JOIN dim_date d ON m.date_key = d.date_key
    WHERE (@year IS NULL OR m.[year] = @year)
    GROUP BY m.[year]
    ORDER BY m.[year];
END
GO

-- ------------------------------------------------------------
-- 5b. Get macro indicators MONTHLY (new — uses full 84-row granularity)
-- Usage: EXEC sp_GetMacroMonthly @year = 2022
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetMacroMonthly
    @year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        m.date_key,
        m.[year],
        d.[month],
        d.month_name,
        m.usd_egp_annual_avg AS usd_egp_monthly,
        m.gdp_usd,
        m.gdp_growth_pct,
        m.inflation_pct,
        m.foreign_reserves_usd,
        d.is_crisis_year
    FROM dim_egypt_macro m
    JOIN dim_date d ON m.date_key = d.date_key
    WHERE (@year IS NULL OR m.[year] = @year)
    ORDER BY m.date_key;
END
GO

-- ------------------------------------------------------------
-- 6. Get supply chain KPIs by year/month
-- FIXED: OTIF includes 'CLOSED' (delivered) status. Denominator =
--        delivered orders only (excludes PENDING/PROCESSING/PAYMENT_REVIEW
--        which haven't reached delivery stage yet).
-- Delivered = COMPLETE, CLOSED, CANCELED, SUSPECTED_FRAUD
-- Usage: EXEC sp_GetSupplyChainKPIs @year = 2024
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetSupplyChainKPIs
    @year INT = NULL,
    @month INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.[year],
        d.[month],
        d.month_name,
        COUNT(*) AS total_orders,
        SUM(CASE WHEN sc.order_status IN ('COMPLETE','CLOSED','CANCELED','SUSPECTED_FRAUD')
                 THEN 1 ELSE 0 END) AS delivered_orders,
        SUM(sc.sales_usd)  AS total_sales,
        SUM(sc.profit_usd) AS total_profit,
        CAST(SUM(sc.profit_usd) * 100.0 / NULLIF(SUM(sc.sales_usd), 0) AS DECIMAL(5,2)) AS profit_margin_pct,
        AVG(CAST(sc.shipping_delay_days AS DECIMAL(5,1))) AS avg_delay_days,
        -- OTIF: on-time + delivered (COMPLETE or CLOSED), over delivered orders
        CAST(SUM(CASE WHEN sc.is_late = 0
                       AND sc.order_status IN ('COMPLETE','CLOSED')
                      THEN 1 ELSE 0 END) * 100.0 /
             NULLIF(SUM(CASE WHEN sc.order_status IN
                              ('COMPLETE','CLOSED','CANCELED','SUSPECTED_FRAUD')
                            THEN 1 ELSE 0 END), 0) AS DECIMAL(5,2)) AS otif_pct,
        CAST(SUM(CASE WHEN sc.is_late = 1 THEN 1 ELSE 0 END) * 100.0 /
             NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS late_delivery_pct,
        CAST(SUM(CASE WHEN sc.order_status = 'CANCELED' THEN 1 ELSE 0 END) * 100.0 /
             NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS cancellation_pct,
        CAST(SUM(CASE WHEN sc.order_status = 'SUSPECTED_FRAUD' THEN 1 ELSE 0 END) * 100.0 /
             NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS fraud_pct
    FROM fact_supply_chain sc
    JOIN dim_date d ON sc.date_key = d.date_key
    WHERE (@year IS NULL OR d.[year] = @year)
      AND (@month IS NULL OR d.[month] = @month)
    GROUP BY d.[year], d.[month], d.month_name
    ORDER BY d.[year], d.[month];
END
GO

-- ------------------------------------------------------------
-- 7. Get product performance ranking
-- Usage: EXEC sp_GetProductPerformance @top = 20
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetProductPerformance
    @year INT = NULL,
    @top INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP(@top)
        p.product_name,
        p.category_name,
        p.department_name,
        SUM(sc.sales_usd)  AS total_sales,
        SUM(sc.profit_usd) AS total_profit,
        CAST(SUM(sc.profit_usd) * 100.0 / NULLIF(SUM(sc.sales_usd), 0) AS DECIMAL(5,2)) AS margin_pct,
        COUNT(*) AS order_count,
        CAST(SUM(CASE WHEN sc.is_late = 1 THEN 1 ELSE 0 END) * 100.0 /
             NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS late_pct
    FROM fact_supply_chain sc
    JOIN dim_product p ON sc.product_key = p.product_key
    JOIN dim_date d ON sc.date_key = d.date_key
    WHERE (@year IS NULL OR d.[year] = @year)
    GROUP BY p.product_name, p.category_name, p.department_name
    ORDER BY total_sales DESC;
END
GO

-- ------------------------------------------------------------
-- 8. Get shipping mode analysis
-- Usage: EXEC sp_GetShippingAnalysis @year = 2024
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetShippingAnalysis
    @year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        sc.shipping_mode,
        COUNT(*) AS order_count,
        CAST(COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER(), 0) AS DECIMAL(5,2)) AS mode_pct,
        AVG(CAST(sc.actual_shipping_days    AS DECIMAL(5,1))) AS avg_actual_days,
        AVG(CAST(sc.scheduled_shipping_days AS DECIMAL(5,1))) AS avg_scheduled_days,
        AVG(CAST(sc.shipping_delay_days     AS DECIMAL(5,1))) AS avg_delay_days,
        CAST(SUM(CASE WHEN sc.is_late = 1 THEN 1 ELSE 0 END) * 100.0 /
             NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS late_pct,
        SUM(sc.sales_usd) AS total_sales
    FROM fact_supply_chain sc
    JOIN dim_date d ON sc.date_key = d.date_key
    WHERE (@year IS NULL OR d.[year] = @year)
    GROUP BY sc.shipping_mode
    ORDER BY order_count DESC;
END
GO

-- ------------------------------------------------------------
-- 9. Crisis impact comparison
-- Usage: EXEC sp_GetCrisisImpact
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetCrisisImpact
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        'Trade' AS layer,
        d.is_crisis_year,
        CASE d.is_crisis_year WHEN 1 THEN 'Crisis' ELSE 'Normal' END AS period_type,
        COUNT(*)                AS record_count,
        AVG(f.trade_value_usd)  AS avg_trade_value
    FROM fact_trade_flows f
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY d.is_crisis_year

    UNION ALL

    SELECT
        'Supply Chain' AS layer,
        d.is_crisis_year,
        CASE d.is_crisis_year WHEN 1 THEN 'Crisis' ELSE 'Normal' END AS period_type,
        COUNT(*)             AS record_count,
        AVG(sc.sales_usd)    AS avg_value
    FROM fact_supply_chain sc
    JOIN dim_date d ON sc.date_key = d.date_key
    GROUP BY d.is_crisis_year

    ORDER BY layer, is_crisis_year;
END
GO

-- ============================================================
-- ======================== CREATE ============================
-- ============================================================

-- ------------------------------------------------------------
-- 10. Add new country  (FIXED: insert column order matches schema)
-- Usage: EXEC sp_AddCountry @name = N'New Country', @iso = 'NWC', @region = 'Africa'
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_AddCountry
    @name NVARCHAR(100),
    @iso CHAR(3) = NULL,
    @region NVARCHAR(50) = NULL,
    @income_group VARCHAR(30) = NULL,
    @is_egypt BIT = 0,
    @gdp DECIMAL(18,0) = NULL,
    @population BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dim_country WHERE country_name = @name)
    BEGIN
        PRINT N'Country already exists: ' + @name;
        RETURN;
    END

    INSERT INTO dim_country (iso_code, country_name, region, income_group, is_egypt, gdp_usd, [population])
    VALUES (@iso, @name, @region, @income_group, @is_egypt, @gdp, @population);

    PRINT N'Country added: ' + @name + N' (key: ' + CAST(SCOPE_IDENTITY() AS NVARCHAR) + N')';
END
GO

-- ------------------------------------------------------------
-- 11. Add new commodity
-- Usage: EXEC sp_AddCommodity @hs = '0805', @desc = N'Citrus fruits', @strategic = 1
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_AddCommodity
    @hs VARCHAR(10),
    @desc NVARCHAR(200),
    @category NVARCHAR(50) = NULL,
    @strategic BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dim_commodity WHERE hs_code = @hs)
    BEGIN
        PRINT N'Commodity already exists: ' + @hs;
        RETURN;
    END

    INSERT INTO dim_commodity (hs_code, [description], category, is_strategic)
    VALUES (@hs, @desc, @category, @strategic);

    PRINT N'Commodity added: ' + @hs + N' — ' + @desc;
END
GO

-- ------------------------------------------------------------
-- 12. Add macro indicator row
-- Usage: EXEC sp_AddMacroData @year = 2025, @month = 6, @usd_egp = 48.50
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_AddMacroData
    @year INT,
    @month INT = 6,
    @usd_egp DECIMAL(10,4) = NULL,
    @gdp_usd DECIMAL(18,0) = NULL,
    @gdp_growth DECIMAL(5,2) = NULL,
    @inflation DECIMAL(5,2) = NULL,
    @reserves DECIMAL(18,0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @dk INT = @year * 100 + @month;

    IF NOT EXISTS (SELECT 1 FROM dim_date WHERE date_key = @dk)
    BEGIN
        PRINT N'date_key not found: ' + CAST(@dk AS NVARCHAR);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dim_egypt_macro WHERE date_key = @dk)
    BEGIN
        PRINT N'Macro data already exists for ' + CAST(@dk AS NVARCHAR) + N'. Use sp_UpdMacroData instead.';
        RETURN;
    END

    INSERT INTO dim_egypt_macro (date_key, [year], usd_egp_annual_avg, gdp_usd, gdp_growth_pct, inflation_pct, foreign_reserves_usd)
    VALUES (@dk, @year, @usd_egp, @gdp_usd, @gdp_growth, @inflation, @reserves);

    PRINT N'Macro data added for ' + CAST(@dk AS NVARCHAR);
END
GO

-- ============================================================
-- ======================== UPDATE ============================
-- ============================================================

-- ------------------------------------------------------------
-- 13. Update country details
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_UpdCountry
    @name NVARCHAR(100),
    @iso CHAR(3) = NULL,
    @region NVARCHAR(50) = NULL,
    @income_group VARCHAR(30) = NULL,
    @gdp DECIMAL(18,0) = NULL,
    @population BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dim_country WHERE country_name = @name)
    BEGIN
        PRINT N'Country not found: ' + @name;
        RETURN;
    END

    UPDATE dim_country SET
        iso_code     = ISNULL(@iso,          iso_code),
        region       = ISNULL(@region,       region),
        income_group = ISNULL(@income_group, income_group),
        gdp_usd      = ISNULL(@gdp,          gdp_usd),
        [population] = ISNULL(@population,   [population])
    WHERE country_name = @name;

    PRINT N'Country updated: ' + @name;
END
GO

-- ------------------------------------------------------------
-- 14. Update macro data
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_UpdMacroData
    @year INT,
    @month INT = 6,
    @usd_egp DECIMAL(10,4) = NULL,
    @gdp_usd DECIMAL(18,0) = NULL,
    @gdp_growth DECIMAL(5,2) = NULL,
    @inflation DECIMAL(5,2) = NULL,
    @reserves DECIMAL(18,0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @dk INT = @year * 100 + @month;

    IF NOT EXISTS (SELECT 1 FROM dim_egypt_macro WHERE date_key = @dk)
    BEGIN
        PRINT N'No macro data for ' + CAST(@dk AS NVARCHAR) + N'. Use sp_AddMacroData first.';
        RETURN;
    END

    UPDATE dim_egypt_macro SET
        usd_egp_annual_avg   = ISNULL(@usd_egp,    usd_egp_annual_avg),
        gdp_usd              = ISNULL(@gdp_usd,    gdp_usd),
        gdp_growth_pct       = ISNULL(@gdp_growth, gdp_growth_pct),
        inflation_pct        = ISNULL(@inflation,  inflation_pct),
        foreign_reserves_usd = ISNULL(@reserves,   foreign_reserves_usd)
    WHERE date_key = @dk;

    PRINT N'Macro data updated for ' + CAST(@dk AS NVARCHAR);
END
GO

-- ------------------------------------------------------------
-- 15. Update commodity category
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_UpdCommodity
    @hs VARCHAR(10),
    @category NVARCHAR(50) = NULL,
    @strategic BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dim_commodity WHERE hs_code = @hs)
    BEGIN
        PRINT N'Commodity not found: ' + @hs;
        RETURN;
    END

    UPDATE dim_commodity SET
        category     = ISNULL(@category,  category),
        is_strategic = ISNULL(@strategic, is_strategic)
    WHERE hs_code = @hs;

    PRINT N'Commodity updated: ' + @hs;
END
GO

-- ============================================================
-- ======================== DELETE ============================
-- ============================================================

-- ------------------------------------------------------------
-- 16. Delete country (only if not referenced in facts)
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_DelCountry
    @name NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @key INT;

    SELECT @key = country_key FROM dim_country WHERE country_name = @name;

    IF @key IS NULL
    BEGIN
        PRINT N'Country not found: ' + @name;
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM fact_trade_flows  WHERE country_key = @key)
       OR EXISTS (SELECT 1 FROM fact_supply_chain WHERE country_key = @key)
    BEGIN
        PRINT N'Cannot delete — country is referenced in fact tables: ' + @name;
        RETURN;
    END

    DELETE FROM dim_country WHERE country_key = @key;
    PRINT N'Country deleted: ' + @name;
END
GO

-- ------------------------------------------------------------
-- 17. Delete commodity (only if not referenced)
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_DelCommodity
    @hs VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @key INT;

    SELECT @key = commodity_key FROM dim_commodity WHERE hs_code = @hs;

    IF @key IS NULL
    BEGIN
        PRINT N'Commodity not found: ' + @hs;
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM fact_trade_flows WHERE commodity_key = @key)
    BEGIN
        PRINT N'Cannot delete — commodity is referenced in fact_trade_flows: ' + @hs;
        RETURN;
    END

    DELETE FROM dim_commodity WHERE commodity_key = @key;
    PRINT N'Commodity deleted: ' + @hs;
END
GO

-- ============================================================
-- ====================== UTILITY =============================
-- ============================================================

-- ------------------------------------------------------------
-- 18. Get DWH row counts (health check)
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_DWH_HealthCheck
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 'dim_date'          AS [table], COUNT(*) AS [rows], 84 AS [expected] FROM dim_date
    UNION ALL SELECT 'dim_country',         COUNT(*), NULL FROM dim_country
    UNION ALL SELECT 'dim_commodity',       COUNT(*), NULL FROM dim_commodity
    UNION ALL SELECT 'dim_egypt_macro',     COUNT(*),   84 FROM dim_egypt_macro
    UNION ALL SELECT 'dim_product',         COUNT(*), NULL FROM dim_product
    UNION ALL SELECT 'fact_trade_flows',    COUNT(*), NULL FROM fact_trade_flows
    UNION ALL SELECT 'fact_supply_chain',   COUNT(*), NULL FROM fact_supply_chain
    UNION ALL SELECT 'dq_validation_log',   COUNT(*), NULL FROM dq_validation_log
    ORDER BY [table];
END
GO

-- ------------------------------------------------------------
-- 19. Search trade data by keyword  (FIXED: removed qty_kg)
-- Usage: EXEC sp_SearchTrade @keyword = N'wheat', @year = 2022
-- (for Claude API Text-to-SQL)
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_SearchTrade
    @keyword NVARCHAR(100),
    @year INT = NULL,
    @flow CHAR(1) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.[year],
        d.month_name,
        c.country_name,
        cm.hs_code,
        cm.[description],
        f.flow_type,
        f.trade_value_usd
    FROM fact_trade_flows f
    JOIN dim_date      d  ON f.date_key      = d.date_key
    JOIN dim_country   c  ON f.country_key   = c.country_key
    JOIN dim_commodity cm ON f.commodity_key = cm.commodity_key
    WHERE cm.[description] LIKE '%' + @keyword + '%'
      AND (@year IS NULL OR d.[year] = @year)
      AND (@flow IS NULL OR f.flow_type = @flow)
    ORDER BY f.trade_value_usd DESC;
END
GO

-- ------------------------------------------------------------
-- 20. DQ Validation — run checks  (FIXED: real checks, clears log)
-- Three checks per year+flow:
--   ROW_COUNT  — expect > 100 detail rows per year/flow
--   VALUE_SUM  — expect SUM(trade_value_usd) > 0
--   FK_INTEGRITY — expect no orphan country/commodity keys
-- Usage: EXEC sp_RunDQValidation
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_RunDQValidation
AS
BEGIN
    SET NOCOUNT ON;

    -- Reset log
    DELETE FROM dq_validation_log;

    -- Check A: row count + value sum per year/flow
    INSERT INTO dq_validation_log ([year], flow_type, expected_value, actual_value, diff_pct, [status])
    SELECT
        d.[year],
        f.flow_type,
        100.0                                              AS expected_value,
        CAST(COUNT(*) AS DECIMAL(18,2))                    AS actual_value,
        CAST((COUNT(*) - 100.0) * 100.0 / 100.0 AS DECIMAL(5,2)) AS diff_pct,
        CASE WHEN COUNT(*) >= 100 AND SUM(f.trade_value_usd) > 0
             THEN 'PASS' ELSE 'FAIL' END                   AS [status]
    FROM fact_trade_flows f
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY d.[year], f.flow_type;

    -- Check B: orphan FK detection (should always pass — schema FKs enforce)
    INSERT INTO dq_validation_log ([year], flow_type, expected_value, actual_value, diff_pct, [status])
    SELECT
        9999 AS [year],
        'M'  AS flow_type,
        0    AS expected_value,
        CAST(
          (SELECT COUNT(*) FROM fact_trade_flows f
           WHERE NOT EXISTS (SELECT 1 FROM dim_country c WHERE c.country_key = f.country_key)
              OR NOT EXISTS (SELECT 1 FROM dim_commodity cm WHERE cm.commodity_key = f.commodity_key))
          AS DECIMAL(18,2)) AS actual_value,
        0    AS diff_pct,
        CASE WHEN
          (SELECT COUNT(*) FROM fact_trade_flows f
           WHERE NOT EXISTS (SELECT 1 FROM dim_country c WHERE c.country_key = f.country_key)
              OR NOT EXISTS (SELECT 1 FROM dim_commodity cm WHERE cm.commodity_key = f.commodity_key)) = 0
        THEN 'PASS' ELSE 'FAIL' END;

    PRINT N'DQ validation complete. Check dq_validation_log.';
    SELECT * FROM dq_validation_log ORDER BY [year], flow_type;
END
GO

-- ============================================================
-- Verify all procedures created
-- ============================================================
SELECT
    name AS procedure_name,
    CASE
        WHEN name LIKE '%Get%' OR name LIKE '%Search%' OR name LIKE '%Health%' THEN 'READ'
        WHEN name LIKE '%Add%' THEN 'CREATE'
        WHEN name LIKE '%Upd%' THEN 'UPDATE'
        WHEN name LIKE '%Del%' THEN 'DELETE'
        WHEN name LIKE '%Run%' THEN 'UTILITY'
        ELSE 'OTHER'
    END AS operation_type,
    create_date
FROM sys.procedures
WHERE name LIKE 'sp_%'
ORDER BY operation_type, name;
GO

PRINT N'✅ 21 Stored Procedures created — 10 READ, 3 CREATE, 3 UPDATE, 2 DELETE, 3 UTILITY';
GO
