CREATE TABLE [stg].[Dim_CostCategory_Raw] (
    [CostCategoryKey] VARCHAR (10)  NOT NULL,
    [CategoryName]    VARCHAR (100) NOT NULL,
    [SpendType]       VARCHAR (50)  NOT NULL,
    [BudgetType]      VARCHAR (50)  NOT NULL
);


GO