CREATE PROCEDURE curated.usp_LoadFactSpend
AS
BEGIN
    SET NOCOUNT ON;

    -- Quarantine records that fail validation.
    INSERT INTO curated.Fact_Spend_Exceptions
        (TransactionID, DateKey, SupplierKey, DepartmentKey,
         CostCategoryKey, InvoiceAmount, BudgetAmount, POFlag,
         ExceptionReason, LoadTimestamp)
    SELECT
        r.TransactionID, r.DateKey, r.SupplierKey, r.DepartmentKey,
        r.CostCategoryKey, r.InvoiceAmount, r.BudgetAmount, r.POFlag,
        CASE
            WHEN r.TransactionID IS NULL
                THEN 'Missing TransactionID'
            WHEN TRY_CAST(r.InvoiceAmount AS DECIMAL(18,2)) IS NULL
                THEN 'InvoiceAmount not a valid number'
            WHEN TRY_CAST(r.DateKey AS INT) IS NULL
                THEN 'DateKey not a valid number'
            WHEN TRY_CAST(r.BudgetAmount AS DECIMAL(18,2)) IS NULL
                THEN 'BudgetAmount missing or not a valid number'
            WHEN r.POFlag IS NULL OR r.POFlag NOT IN ('Yes','No')
                THEN 'POFlag missing or invalid'
            WHEN dt.DateKey IS NULL
                THEN 'Unknown DateKey'
            WHEN s.SupplierKey IS NULL
                THEN 'Unknown SupplierKey'
            WHEN d.DepartmentKey IS NULL
                THEN 'Unknown DepartmentKey'
            WHEN cc.CostCategoryKey IS NULL
                THEN 'Unknown CostCategoryKey'
            ELSE 'Duplicate TransactionID'
        END,
        SYSUTCDATETIME()
    FROM stg.Fact_Spend_Raw r
    LEFT JOIN curated.Dim_Date dt
        ON TRY_CAST(r.DateKey AS INT) = dt.DateKey
    LEFT JOIN curated.Dim_Supplier s
        ON r.SupplierKey = s.SupplierKey
    LEFT JOIN curated.Dim_Department d
        ON r.DepartmentKey = d.DepartmentKey
    LEFT JOIN curated.Dim_CostCategory cc
        ON r.CostCategoryKey = cc.CostCategoryKey
    WHERE r.TransactionID IS NULL
       OR TRY_CAST(r.InvoiceAmount AS DECIMAL(18,2)) IS NULL
       OR TRY_CAST(r.DateKey AS INT) IS NULL
       OR TRY_CAST(r.BudgetAmount AS DECIMAL(18,2)) IS NULL
       OR r.POFlag IS NULL
       OR r.POFlag NOT IN ('Yes','No')
       OR dt.DateKey IS NULL
       OR s.SupplierKey IS NULL
       OR d.DepartmentKey IS NULL
       OR cc.CostCategoryKey IS NULL
       OR EXISTS (
            SELECT 1
            FROM stg.Fact_Spend_Raw r2
            WHERE r2.TransactionID = r.TransactionID
            GROUP BY r2.TransactionID
            HAVING COUNT(*) > 1
       );

    -- Replace the fact data within a transaction.
    -- Roll back to the previous data if the reload fails.
    BEGIN TRANSACTION;

    BEGIN TRY
        DELETE FROM curated.Fact_Spend;

        INSERT INTO curated.Fact_Spend
            (TransactionID, DateKey, SupplierKey, DepartmentKey,
             CostCategoryKey, InvoiceAmount, BudgetAmount, POFlag)
        SELECT
            r.TransactionID,
            CAST(r.DateKey AS INT),
            r.SupplierKey,
            r.DepartmentKey,
            r.CostCategoryKey,
            CAST(r.InvoiceAmount AS DECIMAL(18,2)),
            CAST(r.BudgetAmount AS DECIMAL(18,2)),
            r.POFlag
        FROM stg.Fact_Spend_Raw r
        JOIN curated.Dim_Date dt
            ON TRY_CAST(r.DateKey AS INT) = dt.DateKey
        JOIN curated.Dim_Supplier s
            ON r.SupplierKey = s.SupplierKey
        JOIN curated.Dim_Department d
            ON r.DepartmentKey = d.DepartmentKey
        JOIN curated.Dim_CostCategory cc
            ON r.CostCategoryKey = cc.CostCategoryKey
        WHERE r.TransactionID IS NOT NULL
          AND TRY_CAST(r.InvoiceAmount AS DECIMAL(18,2)) IS NOT NULL
          AND TRY_CAST(r.BudgetAmount AS DECIMAL(18,2)) IS NOT NULL
          AND TRY_CAST(r.DateKey AS INT) IS NOT NULL
          AND r.POFlag IN ('Yes','No')
          AND NOT EXISTS (
                SELECT 1
                FROM stg.Fact_Spend_Raw r2
                WHERE r2.TransactionID = r.TransactionID
                GROUP BY r2.TransactionID
                HAVING COUNT(*) > 1
          );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO