CREATE TABLE [stg].[Fact_Spend_Raw] (
    [TransactionID]   VARCHAR (20) NULL,
    [DateKey]         VARCHAR (20) NULL,
    [SupplierKey]     VARCHAR (10) NULL,
    [DepartmentKey]   VARCHAR (10) NULL,
    [CostCategoryKey] VARCHAR (10) NULL,
    [InvoiceAmount]   VARCHAR (30) NULL,
    [BudgetAmount]    VARCHAR (30) NULL,
    [VarianceAmount]  VARCHAR (30) NULL,
    [InvoiceNumber]   VARCHAR (20) NULL,
    [PONumber]        VARCHAR (20) NULL,
    [PaymentStatus]   VARCHAR (20) NULL,
    [ApprovedFlag]    VARCHAR (3)  NULL,
    [POFlag]          VARCHAR (3)  NULL,
    [ProcessingDays]  VARCHAR (10) NULL
);


GO