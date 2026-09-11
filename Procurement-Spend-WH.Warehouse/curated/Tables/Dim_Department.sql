CREATE TABLE [curated].[Dim_Department] (
    [DepartmentKey]  VARCHAR (10)    NOT NULL,
    [DepartmentName] VARCHAR (100)   NOT NULL,
    [Division]       VARCHAR (100)   NOT NULL,
    [CostCentreHead] VARCHAR (100)   NOT NULL,
    [Location]       VARCHAR (100)   NOT NULL,
    [AnnualBudget]   DECIMAL (18, 2) NOT NULL
);


GO

ALTER TABLE [curated].[Dim_Department]
    ADD CONSTRAINT [PK_Dim_Department] PRIMARY KEY NONCLUSTERED ([DepartmentKey] ASC) NOT ENFORCED;


GO