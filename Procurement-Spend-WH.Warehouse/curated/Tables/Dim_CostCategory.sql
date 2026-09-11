CREATE TABLE [curated].[Dim_CostCategory] (
    [CostCategoryKey] VARCHAR (10)  NOT NULL,
    [CategoryName]    VARCHAR (100) NOT NULL,
    [SpendType]       VARCHAR (50)  NOT NULL,
    [BudgetType]      VARCHAR (50)  NOT NULL
);


GO

ALTER TABLE [curated].[Dim_CostCategory]
    ADD CONSTRAINT [PK_Dim_CostCategory] PRIMARY KEY NONCLUSTERED ([CostCategoryKey] ASC) NOT ENFORCED;


GO