CREATE FUNCTION Security.fn_DepartmentPredicate(@DepartmentKey AS VARCHAR(10))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS fn_securitypredicate_result
    FROM curated.Dim_UserDepartmentMap m
    INNER JOIN curated.Dim_Department d
        ON m.DepartmentName = d.DepartmentName
    WHERE m.UserPrincipalName = USER_NAME()
      AND d.DepartmentKey = @DepartmentKey;

GO