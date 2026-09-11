# Procurement Spend Governance & Analytics
**Power BI · Microsoft Fabric Warehouse · Row-Level Security · Governed MI**

An independent portfolio project — a governed procurement spend analytics solution built end-to-end: SQL Warehouse layer, star-schema semantic model, Row-Level Security, and a controlled Dev→Test→Prod deployment pipeline. Synthetic dataset (850 transactions, 12 suppliers, 5 departments); enterprise-scale delivery experience is evidenced separately through commercial BI work at NatWest Group.

![Executive Overview](<screenshots/Executive overview.jpg>)

**Why this matters:**
- Data is validated and governed in a Fabric SQL Warehouse *before* it reaches Power BI — not loaded straight from CSV, with invalid rows automatically quarantined rather than silently dropped or loaded
- Row-Level Security uses a realistic mapping-table pattern, tested against known values (not just visually checked)
- Every threshold and definition (budget variance, PO coverage, contract status) has a single business-logic source of truth in the SQL layer, with DAX measures in `_Measures` providing the equivalent report-facing calculation for the semantic model

Full write-up, architecture, and every other report page below — click to expand any section.

---

<details>
<summary><strong>What This Demonstrates</strong></summary>

| Capability | Implementation |
|---|---|
| **Dimensional modelling** | Star schema — 1 fact table, 4 supporting dimensions, single-direction relationships, hidden foreign keys |
| **DAX measure design** | 8 measures isolated in a dedicated `_Measures` table with documented business definitions |
| **Row-Level Security** | Two roles — dynamic `Own Department` via a user-to-department mapping table matched to `USERPRINCIPALNAME()`, and static `Finance` role scoped to active suppliers; Entra ID group assignment documented for production |
| **Governed SQL layer** | Fabric Warehouse with staging/curated schema separation, T-SQL views, a parameterised function, and a stored procedure that validates and quarantines invalid rows before they reach the semantic model |
| **Fabric deployment** | Three-stage pipeline (Dev → Test → Prod) with deployment history |
| **Semantic model governance** | Production semantic model endorsed as Promoted, with documented business definitions and metadata |
| **Data lineage** | Source → Power Query → semantic model → report layer, documented through Fabric lineage |
| **Finance domain knowledge** | Budget variance analysis, supplier concentration risk, PO coverage governance, contract expiry management |

</details>

<details>
<summary><strong>Business Problem</strong></summary>

Finance and Procurement teams need a trusted, auditable view of spend across suppliers, departments and cost categories. Without a governed model, reporting becomes fragmented, budget variance is unclear, and access control becomes a compliance risk.

This solution replaces ad-hoc reporting with a structured semantic model, clearly defined measures, role-based access and documented governance — so teams can independently explore spending patterns with confidence in the numbers.

**The report answers three questions:**
- Are we on budget, and which departments are driving variance?
- Which suppliers represent concentration or contract renewal risk?
- Is our procurement process governed — are purchases approved and PO-backed?

</details>

<details>
<summary><strong>Data Layer — Fabric Warehouse</strong></summary>

Source data is processed through a governed SQL layer in Fabric before it ever reaches the semantic model — not loaded straight from CSV into Power BI.

**Why a Warehouse, not a Lakehouse:** the Lakehouse SQL analytics endpoint provides a read-only SQL surface over Delta tables — it does support creating views, functions and stored procedures, but not data modification (`INSERT`/`UPDATE`/`DELETE`) or table DDL (`CREATE`/`ALTER`/`DROP TABLE`). This project uses a Warehouse because the governed loading process requires persisted relational tables and T-SQL-based validation/quarantine logic, which only the Warehouse supports.

**Staging and curated schemas:**
- `stg` holds the raw extract exactly as it arrives — as text, unvalidated. Nothing downstream reads from it directly.
- `curated` is the governed layer — typed, keyed, validated — and the only schema the semantic model connects to.

**What the SQL layer does:**
- **`fn_ContractStatus`** — a parameterised inline table-valued function classifying suppliers as Secure, Near Expiry or Inactive as of any given date, rather than a fixed calculated column baked to one date
- **Governed views** — `vw_BudgetVarianceByDepartment`, `vw_POCoverageBySupplier`, `vw_SupplierConcentration` apply the same £10K variance and 80% PO coverage thresholds used in the report — the SQL layer's source of truth, with `_Measures` providing the equivalent DAX calculation for the semantic model
- **`usp_LoadFactSpend`** — validates and casts staged data, quarantining rows that fail type conversion or reference an unknown dimension key into a `Fact_Spend_Exceptions` table with a specific reason, rather than silently dropping or silently loading invalid data
- **Declared, unenforced keys** — `PRIMARY KEY`/`FOREIGN KEY ... NOT ENFORCED` constraints document the model's structure and support the query optimiser, even though Fabric Warehouse doesn't validate them at write time

**Tested, not just built:** the quarantine logic was verified by deliberately inserting a row with an invalid date and an unknown supplier key — it was correctly caught and routed to the exceptions table, with the curated fact table unaffected.


![Warehouse Object Explorer](<screenshots/Warehouse object explorer.jpg>)
![Exception Handling Proof](<screenshots/Exception test.jpg>)

</details>

<details>
<summary><strong>Model Design</strong></summary>

Classic star schema with a single fact table and four supporting dimensions.

| Layer | Table | Purpose |
|---|---|---|
| Fact | `df_clean_spend` | Transaction-level spend, budget, variance, PO and approval detail |
| Dimension | `Dim_Date` | Consistent time filtering — calendar year, quarter, month, week; fiscal year and fiscal quarter columns available in the semantic layer |
| Dimension | `Dim_Supplier` | Supplier name, tier, category, contract expiry, contract risk classification |
| Dimension | `Dim_Department` | Department, division, location, cost centre head, annual budget |
| Dimension | `Dim_CostCategory` | Category name, budget type, spend type |

Single-direction relationships from dimensions to fact. Foreign keys hidden from report layer. Measures isolated in a dedicated `_Measures` table — not embedded in visuals.

**Design rationale:** Single-direction relationships keep filter propagation predictable and the model easier to reason about. Bidirectional filtering was not required for this model, so it was deliberately avoided. Measures are isolated in `_Measures` to separate calculation logic from the underlying data model and simplify maintenance.

![Model View](<screenshots/Model View.jpg>)

</details>

<details>
<summary><strong>Key Measures</strong></summary>

All measures defined in `_Measures` table. Business definitions documented in Governance Notes report page.

| Measure | DAX Pattern | Purpose |
|---|---|---|
| `Total Spend` | `SUM(InvoiceAmount)` | Base measure — total invoice value in filter context |
| `Total Budget` | `SUM(BudgetAmount)` | Budget allocation in filter context |
| `Budget Variance` | `[Total Spend] - [Total Budget]` | Absolute variance — positive = overspend |
| `% Budget Variance` | `DIVIDE([Budget Variance], [Total Budget])` | Normalised variance for cross-department comparison |
| `PO Coverage Rate` | `DIVIDE(CALCULATE([Total Spend], df_clean_spend[POFlag] = "Yes"), [Total Spend])` | Proportion of spend backed by a purchase order — values below 80% flagged in report |
| `Supplier Concentration %` | `DIVIDE([Total Spend], CALCULATE([Total Spend], ALL(Dim_Supplier)))` | Each supplier's share of total spend — denominator is total spend across all suppliers, regardless of current filter context |
| `Top 2 Supplier Concentration` | `DIVIDE(SUMX(TOPN(2, VALUES(Dim_Supplier[SupplierKey]), [Total Spend], DESC), [Total Spend]), CALCULATE([Total Spend], ALL(Dim_Supplier)))` | Combined spend share of the two largest suppliers — denominator uses ALL(Dim_Supplier) so percentage is always relative to total spend, not the filtered subset |
| `Spend vs Prior Year` | `DIVIDE([Total Spend] - CALCULATE([Total Spend], SAMEPERIODLASTYEAR(Dim_Date[FullDate])), CALCULATE([Total Spend], SAMEPERIODLASTYEAR(Dim_Date[FullDate])))` | Year-over-year spend as a percentage change — filter-context dependent; responds to year, department and division slicers |

**`DIVIDE` is used throughout** rather than division operators — makes denominator handling explicit and avoids uncontrolled divide-by-zero behaviour, rather than leaving it to chance.

</details>

<details>
<summary><strong>Row-Level Security</strong></summary>

Two roles implemented with least-privilege design.

| Role | Mechanism | Access |
|---|---|---|
| `Own Department` | `Dim_UserDepartmentMap[UserPrincipalName] = USERPRINCIPALNAME()`, related through to `Dim_Department` | Own cost centre only |
| `Finance` | `Dim_Supplier[Status] = "Active"` | All departments, active suppliers only |

**Design decisions:**
- `Own Department` uses a dedicated user-to-department mapping table (`Dim_UserDepartmentMap`) rather than comparing `USERPRINCIPALNAME()` directly against a department name column. This is a more realistic pattern — a user's email address rarely matches a department name directly, and a mapping table lets one user be linked to a department independently of naming, the same way production RLS would use an HR or directory source
- `Finance` role applies a static supplier filter — excludes inactive/lapsed suppliers from the finance view, reducing noise and supporting data quality governance
- RLS logic is intentionally simple to ensure it is auditable and testable
- In production, role assignment is managed through Entra ID security groups in Power BI Service — not individual user assignment
- RLS applies to Viewer role only — Admins, Members and Contributors bypass RLS by design

**Testing:** Roles validated using View As Role in Power BI Desktop, confirmed against known values — e.g. the Finance role's active-supplier filter verified by checking supplier count drops from 12 to 9 (excluding the three named Inactive suppliers), not just visually inspecting the result.

![RLS — Own Department role](<screenshots/Security Roles 1.jpg>)
![RLS — Finance role](<screenshots/Security Roles 2.jpg>)

</details>

<details>
<summary><strong>Enterprise Use Cases & Operational Considerations</strong></summary>

Although the portfolio uses a synthetic dataset, the solution was designed around recurring procurement and finance reporting requirements rather than one-off visualisation.

**Business use cases**
- **Budget and spend exception management** — budget variance is surfaced against a defined £10K threshold to highlight material overspend requiring investigation.
- **Procurement compliance monitoring** — PO Coverage Rate identifies areas falling below the defined 80% coverage threshold.
- **Supplier concentration monitoring** — Supplier Concentration % and Top 2 Supplier Concentration provide visibility of dependency on individual suppliers.
- **Contract monitoring** — supplier contract status is categorised as Secure, Near Expiry or Inactive based on the defined contract-review logic.
- **Role-based management information** — Row-Level Security restricts departmental visibility while allowing authorised users to access the information relevant to their responsibilities.
- **Controlled reporting releases** — the solution uses a Development → Test → Production Fabric deployment pipeline to demonstrate a structured approach to report and semantic-model changes.
- **Semantic-model governance** — business logic is centralised through reusable measures and a dedicated `_Measures` table, supported by metadata, documented definitions, lineage and semantic-model endorsement.

**Operational considerations**

Row-level data-quality validation is implemented — the Warehouse load procedure quarantines invalid or unresolvable rows into an exceptions table rather than silently dropping or loading them (see Data Layer section above). What's not yet built is production-scale *monitoring*: automated alerting on exception volumes, refresh-failure notifications, and scheduled rather than manual refresh.

The current portfolio does not claim automated monitoring or alerting — those remain documented as considerations for a future production implementation, alongside the other next-step items below.

</details>

<details>
<summary><strong>Report Pages (full detail)</strong></summary>

### Page 1 — Executive Overview
*Answers: Are we on budget? Where is spend trending?*

Four KPI tiles: Total Spend, Budget Variance, % Budget Variance, Spend vs Prior Year.

**Spend vs Budget by Period** — combo chart showing monthly actual spend (bars) against budget line. Bars show spend volatility across the year; the budget line provides the consistent reference point. 2024 full-year position: -5.1% under budget (£305K favourable variance).

**Spend vs Budget by Department** — clustered bar chart. Immediately surfaces the department story: IT is the largest overspend department; Marketing and Finance came in under budget. Operations and HR within tolerance.

Year and Division slicers placed on the page keep filtering in context — no need to navigate to a separate page for a different view.

### Page 2 — Supplier Analysis
*Answers: Which suppliers carry concentration or governance risk?*

**Total Spend by Supplier** and **Supplier Concentration %** — horizontal bar charts. Top two suppliers (Northstar Software 26.7%, BluePeak Consulting 24.2%) account for over 50% of total spend. Concentration at this level warrants active contract management.

**Supplier detail table** — sorted by Contract Status (Inactive → Near Expiry → Secure), then Total Spend. Columns: Supplier Name, Category, Supplier Tier, Contract Status, Contract Expiry, PO Coverage Rate, Budget Variance.

Total Spend is intentionally excluded from the table — it is already visible in the bar charts above. The table serves as the governance layer only: contract risk, PO discipline, and budget position.

`Contract Status` is sourced from the Warehouse's `fn_ContractStatus` function via `vw_ContractStatus_Current`, merged into `Dim_Supplier` in Power Query — not a Power BI calculated column. Evaluated against the reporting period end date (31 Dec 2024):
- **Inactive** — supplier's `Status` field is Inactive (Summit Services, Greenline Solutions, CoreWorks Ltd — all Tier 3)
- **Near Expiry** — active supplier with a contract expiring within 12 months (Skyline Travel, OfficeHub Supplies, Pioneer Tech)
- **Secure** — active supplier with a contract valid beyond 12 months (all Tier 1 suppliers, plus Nimbus Training at Tier 2)

The 12-month threshold is a working assumption based on typical procurement renewal lead times — renegotiation for Tier 1 and Tier 2 contracts typically begins 6–12 months before expiry to maintain commercial continuity and avoid contract lapse.

**Report Indicators**

PO Coverage Rate is highlighted in red where the value falls below 80% — indicating that less than 80% of a supplier's spend was backed by a purchase order before invoice receipt. All three suppliers below threshold are Tier 3 and Inactive, consistent with lower procurement controls at that tier.

Budget Variance is highlighted in red where overspend exceeds £10,000 — immaterial variances below this threshold are not flagged. This reflects a commonly used finance reporting approach where only material exceptions warrant escalation.

Bar charts filtered to Active suppliers only — Inactive suppliers excluded from spend and concentration analysis to avoid historical spend distorting the active supplier picture.

![Supplier Analysis](<screenshots/Supplier Analysis.jpg>)

### Page 3 — Governance Notes
*Answers: What are the rules of this report?*

Documents refresh schedule, RLS design, deployment architecture, report indicators and known limitations in plain language. Accessible to all report users as part of the published report.

**Report Indicators documented on this page:**
- PO Coverage Rate flagged below 80%
- Budget Variance flagged where overspend exceeds £10,000
- Contract Status thresholds — Inactive, Near Expiry (within 12 months), Secure

**Why this page exists:** In a regulated environment, report users need to understand what the data represents, how it is secured, and who to contact with questions. Embedding this in the report removes the gap between documentation and delivery.

![Governance Notes](<screenshots/Governance notes.jpg>)

</details>

<details>
<summary><strong>Deployment & Governance</strong></summary>

Three-stage Fabric deployment pipeline: Development → Test → Production.

| Stage | Workspace | Purpose |
|---|---|---|
| Dev | `Procurement-Spend-DEV` | Active development |
| Test | `Procurement-Spend-TEST` | Pre-release validation |
| Prod | `Procurement-Spend-PROD` | Promoted production version |

- Deployment history tracked with timestamp and deployer identity — auditable in Fabric Deployment History
- Semantic model endorsed as **Promoted** in Production workspace
- RLS tested in Power BI Service before each production deployment
- Pre-deployment validation includes spend totals reconciled against the source extract

![Deployment Pipeline](<screenshots/Pipeline view.jpg>)
![Deployment History](<screenshots/Deployment history.jpg>)
![Endorsed Semantic Model](<screenshots/Endorsed semantic model.jpg>)

</details>

<details>
<summary><strong>AI Readiness — Copilot Metadata</strong></summary>

The semantic model has been prepared for Copilot using Power BI Desktop's Model view.

Applied across the semantic layer:
- **Table descriptions** — all six tables documented with business purpose
- **Column descriptions** — queryable columns documented with business definition, usage context and known limitations
- **Measure descriptions** — all eight measures documented with business definition, calculation rationale and usage guidance

This applies the metadata layer that governs Copilot query quality when the model is deployed on Fabric capacity. The descriptions configure the model for Copilot readiness; Copilot query execution itself requires Fabric capacity and is not enabled in this trial environment.

</details>

<details>
<summary><strong>Data Lineage</strong></summary>


Transformation logic documented in Power Query query steps. Full lineage visible in the Fabric lineage view in the Production workspace.

![Lineage View](<screenshots/Lineage view.jpg>)

</details>

<details>
<summary><strong>Known Limitations & Next Steps</strong></summary>

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

</details>

<details>
<summary><strong>Key Design Decisions</strong></summary>

| Decision | Rationale |
|---|---|
| Fabric Warehouse over Lakehouse | Table DDL and data modification (`INSERT`/`UPDATE`/`DELETE`) are required for the governed load process; the Lakehouse SQL endpoint supports views/functions/procedures but not these |
| Staging → curated schema split | Keeps raw, unvalidated data out of anything the semantic model or reports can read from directly |
| Exception quarantine over silent drop | Preserves invalid records and their specific failure reason for investigation, rather than losing them |
| Parameterised `fn_ContractStatus` over a fixed calculated column | Works for any reporting date; the first version hard-coded one date and had to be corrected |
| Mapping-table RLS over direct name comparison | Separates user identity from department logic — more realistic than assuming a username matches a department name |
| Declared, unenforced PK/FK | Not validated at write time in Fabric Warehouse, but documents the model's structure and aids the query optimiser |
| Dedicated `_Measures` table | Separates DAX calculation logic from the physical data model |
| Dev → Test → Prod pipeline | Demonstrates controlled promotion rather than direct changes to production |

</details>

---

*Nishant Goel — Senior BI Developer | Power BI · DAX · Semantic Modelling · Data Governance · Microsoft Fabric | PL-300 Certified · DP-600 (Retaking)*
*[linkedin.com/in/nish-goel](https://linkedin.com/in/nish-goel) · [github.com/nishantgoeluk-pixel](https://github.com/nishantgoeluk-pixel)*
