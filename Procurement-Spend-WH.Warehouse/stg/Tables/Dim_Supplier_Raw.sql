CREATE TABLE [stg].[Dim_Supplier_Raw] (
    [SupplierKey]       VARCHAR (10)  NULL,
    [SupplierName]      VARCHAR (100) NULL,
    [Category]          VARCHAR (50)  NULL,
    [Country]           VARCHAR (50)  NULL,
    [Status]            VARCHAR (20)  NULL,
    [SupplierTier]      VARCHAR (20)  NULL,
    [PreferredSupplier] VARCHAR (3)   NULL,
    [ContractExpiry]    VARCHAR (20)  NULL
);


GO