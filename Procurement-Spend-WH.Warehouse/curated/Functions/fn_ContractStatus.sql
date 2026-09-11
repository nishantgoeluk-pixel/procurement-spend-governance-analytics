CREATE FUNCTION curated.fn_ContractStatus (@AsOfDate DATE) RETURNS TABLE AS RETURN ( SELECT s.SupplierKey, s.SupplierName, s.SupplierTier, s.ContractExpiry, CASE WHEN s.Status = 'Inactive' THEN 'Inactive' WHEN s.ContractExpiry < DATEADD(MONTH, 12, @AsOfDate) THEN 'Near Expiry' ELSE 'Secure' END AS ContractStatus FROM curated.Dim_Supplier s );

GO