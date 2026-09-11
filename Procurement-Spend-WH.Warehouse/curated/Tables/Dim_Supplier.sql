CREATE TABLE [curated].[Dim_Supplier] (
    [SupplierKey]       VARCHAR (10)  NOT NULL,
    [SupplierName]      VARCHAR (100) NOT NULL,
    [Category]          VARCHAR (50)  NOT NULL,
    [Country]           VARCHAR (50)  NOT NULL,
    [Status]            VARCHAR (20)  NOT NULL,
    [SupplierTier]      VARCHAR (20)  NOT NULL,
    [PreferredSupplier] VARCHAR (3)   NOT NULL,
    [ContractExpiry]    DATE          NULL
);


GO

ALTER TABLE [curated].[Dim_Supplier]
    ADD CONSTRAINT [PK_Dim_Supplier] PRIMARY KEY NONCLUSTERED ([SupplierKey] ASC) NOT ENFORCED;


GO