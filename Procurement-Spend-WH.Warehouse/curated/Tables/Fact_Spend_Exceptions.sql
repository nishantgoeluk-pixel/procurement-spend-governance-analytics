CREATE TABLE [curated].[Fact_Spend_Exceptions] (
    [TransactionID]   VARCHAR (20)  NULL,
    [DateKey]         VARCHAR (20)  NULL,
    [SupplierKey]     VARCHAR (10)  NULL,
    [DepartmentKey]   VARCHAR (10)  NULL,
    [CostCategoryKey] VARCHAR (10)  NULL,
    [InvoiceAmount]   VARCHAR (30)  NULL,
    [BudgetAmount]    VARCHAR (30)  NULL,
    [POFlag]          VARCHAR (3)   NULL,
    [ExceptionReason] VARCHAR (200) NULL,
    [LoadTimestamp]   DATETIME2 (6) NOT NULL
);


GO