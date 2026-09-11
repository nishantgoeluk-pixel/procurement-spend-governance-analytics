CREATE TABLE [curated].[Fact_Spend] (
    [TransactionID]   VARCHAR (20)    NOT NULL,
    [DateKey]         INT             NOT NULL,
    [SupplierKey]     VARCHAR (10)    NOT NULL,
    [DepartmentKey]   VARCHAR (10)    NOT NULL,
    [CostCategoryKey] VARCHAR (10)    NOT NULL,
    [InvoiceAmount]   DECIMAL (18, 2) NOT NULL,
    [BudgetAmount]    DECIMAL (18, 2) NOT NULL,
    [POFlag]          VARCHAR (3)     NOT NULL
);


GO

ALTER TABLE [curated].[Fact_Spend]
    ADD CONSTRAINT [FK_Fact_Spend_CostCat] FOREIGN KEY ([CostCategoryKey]) REFERENCES [curated].[Dim_CostCategory] ([CostCategoryKey]) NOT ENFORCED;


GO

ALTER TABLE [curated].[Fact_Spend]
    ADD CONSTRAINT [FK_Fact_Spend_Date] FOREIGN KEY ([DateKey]) REFERENCES [curated].[Dim_Date] ([DateKey]) NOT ENFORCED;


GO

ALTER TABLE [curated].[Fact_Spend]
    ADD CONSTRAINT [FK_Fact_Spend_Department] FOREIGN KEY ([DepartmentKey]) REFERENCES [curated].[Dim_Department] ([DepartmentKey]) NOT ENFORCED;


GO

ALTER TABLE [curated].[Fact_Spend]
    ADD CONSTRAINT [FK_Fact_Spend_Supplier] FOREIGN KEY ([SupplierKey]) REFERENCES [curated].[Dim_Supplier] ([SupplierKey]) NOT ENFORCED;


GO

ALTER TABLE [curated].[Fact_Spend]
    ADD CONSTRAINT [PK_Fact_Spend] PRIMARY KEY NONCLUSTERED ([TransactionID] ASC) NOT ENFORCED;


GO