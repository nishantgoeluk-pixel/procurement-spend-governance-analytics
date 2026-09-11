-- ------------------------------------------------------------
-- 6. STORED PROCEDURE — parameterised reconciliation check
-- ------------------------------------------------------------

CREATE PROCEDURE curated.usp_ReconcileSpendTotals
    @AsOfDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT(*)                       AS TransactionCount,
        SUM(InvoiceAmount)             AS TotalSpend,
        SUM(CASE WHEN POFlag NOT IN ('Yes','No') THEN 1 ELSE 0 END) AS InvalidPOFlagCount,
        SUM(CASE WHEN InvoiceAmount IS NULL THEN 1 ELSE 0 END)       AS MissingAmountCount
    FROM curated.Fact_Spend f
    JOIN curated.Dim_Date d ON f.DateKey = d.DateKey
    WHERE d.FullDate <= @AsOfDate;
END;

GO