
Transformation logic documented in Power Query query steps. Full lineage visible in the Fabric lineage view in the Production workspace.

![Lineage View](<screenshots/Lineage view.jpg>)

---

## Known Limitations & Next Steps

**Current limitations**
- Budget amounts represent monthly procurement allocations distributed proportionally across transactions. Headline variance reflects the full-year position; filter by department for period-level analysis.
- Source files are loaded from CSV via Fabric Copy job into a text-only staging layer, then cast and validated in SQL — not yet a cloud-hosted, continuously-refreshing source.
- `Dim_UserDepartmentMap` is currently a small manually-entered table, not yet sourced from the Warehouse or an HR/directory system.
- RLS is validated in Desktop using View As Role; multi-user validation with separate accounts requires Entra ID group assignment.
- The project is not yet under Git version control — currently `.pbix` only, not `.pbip`.
- Refresh is manual; no scheduled/automated refresh is currently configured.

**Delivered since the initial build**
- **SQL source layer** — Fabric Warehouse with staging/curated schemas, governed views, a parameterised function, and a stored procedure. Replaces the original CSV → Power Query-only path.
- **Data-quality quarantine** — `usp_LoadFactSpend` validates and casts staged data, routing invalid rows to `Fact_Spend_Exceptions` with a specific reason. Tested by deliberately inserting an invalid row and confirming it was correctly caught, not just assumed to work.
- **RLS upgraded** — `Own Department` (formerly `Department_User`) now uses a user-to-department mapping table rather than a direct name comparison, a more realistic production pattern.

**Planned next steps**
- **Git and `.pbip`** — bring the project under version control, replacing `.pbix`-only with a Git-tracked `.pbip` project.
- **Cloud-hosted, scheduled refresh** — move from manual refresh to a configured Fabric refresh schedule.
- **Incremental refresh** — evaluated as part of the target architecture for larger transactional volumes; the portfolio dataset is intentionally small enough that full refresh remains appropriate at this scale.
- **Multi-user RLS validation** — assign Entra ID security groups and verify role behaviour across separate user accounts.
- **`Dim_UserDepartmentMap` sourced from the Warehouse** — replacing the manually-entered version with a properly governed table.
- **Automated refresh monitoring and alerting** — beyond the quarantine logic already built, for production-scale operational visibility.

---

*Nishant Goel — Senior BI Developer | Power BI · DAX · Semantic Modelling · Data Governance · Microsoft Fabric | PL-300 Certified · DP-600 (Retaking)*
*[linkedin.com/in/nish-goel](https://linkedin.com/in/nish-goel) · [github.com/nishantgoeluk-pixel](https://github.com/nishantgoeluk-pixel)*
