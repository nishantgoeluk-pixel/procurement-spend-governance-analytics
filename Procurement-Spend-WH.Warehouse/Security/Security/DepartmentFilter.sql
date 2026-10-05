CREATE SECURITY POLICY [Security].[DepartmentFilter]
    ADD FILTER PREDICATE [Security].[fn_DepartmentPredicate]([DepartmentKey]) ON [curated].[Dim_Department]
    WITH (STATE = ON);


GO