CREATE SECURITY POLICY [Security].[FactSpendFilter]
    ADD FILTER PREDICATE [Security].[fn_DepartmentPredicate]([DepartmentKey]) ON [curated].[Fact_Spend]
    WITH (STATE = ON);


GO