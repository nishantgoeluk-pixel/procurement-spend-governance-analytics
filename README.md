# Procurement Spend Governance & Analytics
**Power BI · Microsoft Fabric Warehouse · Row-Level Security · Governed MI**

An independent portfolio project demonstrating governed BI delivery patterns using Power BI and Microsoft Fabric. It combines a Fabric SQL Warehouse, a star-schema semantic model, Row-Level Security and a controlled Dev → Test → Prod deployment workflow.

The dataset is deliberately synthetic and small — 850 transactions, 12 suppliers and 5 departments. Enterprise-scale commercial BI experience is demonstrated separately, through my work at NatWest Group.

![Executive Overview](<screenshots/Executive overview.jpg>)

**Why this matters:**
- Fact spend data is validated in the Fabric Warehouse before it reaches the semantic model. Invalid fact rows are quarantined with an explicit reason rather than silently loaded or discarded.
- Business logic is kept in defined layers: contract status in SQL, analytical measures in the semantic model, and report thresholds documented in the report layer.
- Dynamic Row-Level Security uses a user-to-department mapping pattern and was tested against known results rather than only checked visually.
- Deployment, security, lineage and known limitations are documented alongside the report rather than treated as separate afterthoughts.

**Who this is for:**
- **Finance** — monitor spend against budget, identify material variance and understand where spend is changing.
- **Procurement** — monitor supplier concentration, PO compliance and contracts approaching expiry.
- **Business / Risk owners** — understand supplier dependency, access controls and where governance issues need investigation.

The report is designed around decisions rather than individual visuals: monitor financial position, identify supplier or control risk, and understand the rules and data behind the numbers.

Full detail and every report page are below — click a section to expand it.

## What This Demonstrates

| Capability | Implementation |
|---|---|
| **Dimensional modelling** | Star schema — 1 fact table, 4 analytical dimensions and 1 security mapping table, single-direction relationships and dedicated dimensional keys |
| **DAX measure design** | Measures are centralised in a dedicated `_Measures` table with documented business definitions and consistent calculation logic |
| **Row-Level Security** | Two roles — a dynamic `Own Department` role using a user-to-department mapping table and `USERPRINCIPALNAME()`, and a static `Finance` role scoped to active suppliers only; Entra ID group assignment is documented for production use |
| **Governed SQL layer** | Fabric Warehouse with staging and curated schemas, a governed view, a parameterised function, a validation/quarantine load procedure and a reconciliation procedure |
| **Fabric deployment** | Three-stage pipeline (Dev → Test → Prod) built with Fabric's native Deployment pipelines feature; Test and Prod share Dev's Warehouse as one data source; the Prod semantic model is endorsed as Promoted |
| **Direct Lake & SQL-layer security** | Separate Direct Lake on SQL semantic model used to compare refresh behaviour with Import and test SQL-layer RLS behaviour, including DirectQuery fallback and a dimension/fact security gap identified through testing |
| **Semantic model governance** | Production semantic model endorsed as Promoted, with documented business definitions for its measures |
| **Data lineage** | Source files → Fabric Copy Job → Warehouse → semantic model → report, supported by Fabric lineage and repository artefacts |
| **Procurement & finance analytics** | Budget variance, supplier concentration, PO coverage and contract-expiry analysis |

---

<details>
<summary id="business-problem"><strong>Business Problem</strong></summary>

Finance and Procurement teams need a trusted, auditable view of spend — by supplier, department and cost category. Without a governed model, reporting becomes fragmented, budget variance is unclear, and access control becomes a risk.

This solution replaces ad-hoc reporting with one structured semantic model, clear measures, role-based access, and documented governance. Teams can explore spend on their own, with confidence in the numbers.

**The solution supports three levels of decision-making:**
- **Monitor** — are we on budget, and where is spend moving?
- **Identify risk** — which suppliers, contracts or purchasing behaviours need attention?
- **Govern** — are purchases compliant with procurement controls and access policies?

</details>

<details>
<summary id="data-layer"><strong>Data Layer — Fabric Warehouse</strong></summary>

Source data passes through a governed SQL layer in Fabric before it reaches the semantic model. It is not loaded straight from CSV into Power BI.

**Why a Warehouse, not a Lakehouse:** the Lakehouse SQL analytics endpoint provides a read-only T-SQL surface over Delta tables. It supports queries, views, functions and stored procedures, but not `INSERT`/`UPDATE`/`DELETE` against the underlying tables, or table-structure changes (`CREATE`/`ALTER`/`DROP TABLE`). This project requires T-SQL data modification during the governed load process, so a Warehouse was selected instead.

**Staging and curated schemas:**
- `stg` receives raw, text-based inputs from the Copy Job for Date, Department, Supplier and Fact. Nothing downstream reads from it directly.
- `curated` contains typed, keyed analytical tables. Only this layer connects to the semantic model.
- The **fact** load has a coded, committed path from staging to curated: `usp_LoadFactSpend` validates and converts staged rows, with rejected rows written to an exception table. The **Date, Department and Supplier** dimensions currently land in `stg`, but their promotion into `curated` is not yet captured as committed SQL in this repository — see Known Limitations. `Dim_CostCategory` bypasses `stg` entirely and is loaded directly into `curated` by the Copy Job.

**What the SQL layer does:**
- **`fn_ContractStatus`** — a parameterised function that classifies each supplier as Secure, Near Expiry or Inactive, as of any date you give it. Not a fixed column locked to one date.
- **`usp_LoadFactSpend`** — checks and converts staged data. Rows that fail — wrong type, or an unknown key — go to a `Fact_Spend_Exceptions` table with a reason. Nothing is silently dropped or silently loaded.
- **`usp_ReconcileSpendTotals`** — a parameterised reconciliation check that returns transaction counts, total spend and data-quality counts (invalid PO flags, missing amounts) as of a given date, used as a pre-deployment check.
- **Declared, unenforced keys** — in plain terms, the tables record which columns are meant to link to which, the same way a diagram would, even though the database doesn't actively check this at write time. In SQL, this is written as `PRIMARY KEY`/`FOREIGN KEY ... NOT ENFORCED` constraints. Fabric Warehouse does not check them at write time, but they still document how the tables relate.

**Tested, not just built:** the quarantine logic was checked by deliberately adding a row with a bad date and an unknown supplier key. It was caught correctly and routed to the exceptions table. The main fact table was not affected.

<pre>
stg (raw, unvalidated)
    └── usp_LoadFactSpend
        ├── valid   → curated.Fact_Spend
        └── invalid → curated.Fact_Spend_Exceptions (with reason)
</pre>

![Warehouse Object Explorer](<screenshots/Warehouse object explorer.jpg>)
![Exception Handling Proof](<screenshots/Exception test.jpg>)

</details>

<details>
<summary id="model-design"><strong>Model Design</strong></summary>

A star schema: one fact table, four analytical dimensions, and one security mapping table.

| Layer | Table | Purpose |
|---|---|---|
| Fact | `df_clean_spend` | Transaction-level spend, budget allocation and purchase-order status |
| Dimension | `Dim_Date` | Time filtering — year, quarter, month, week, plus fiscal year and quarter |
| Dimension | `Dim_Supplier` | Supplier name, tier, category, contract expiry, risk classification |
| Dimension | `Dim_Department` | Department, division, location, cost centre head, annual budget |
| Dimension | `Dim_CostCategory` | Category name, budget type, spend type |
| Dimension | `Dim_UserDepartmentMap` | Maps a user to their department, for `Own Department` RLS |

Relationships run one way, from dimensions to fact. Measures sit in one `_Measures` table rather than being scattered across visuals.

**Why one-way relationships:** they keep filtering predictable and the model easier to reason about. This model does not need two-way filtering, so it was left out on purpose. Keeping measures in `_Measures` separates calculation logic from the data itself, which makes the model easier to maintain.

![Model View](<screenshots/Model View.jpg>)

</details>

<details>
<summary id="key-measures"><strong>Key Measures</strong></summary>

**In plain terms:** calculations used throughout the report are centralised in a dedicated `_Measures` table rather than recreated inside individual visuals. The table below highlights the key analytical measures and representative DAX patterns alongside their business purpose.

All measures live in `_Measures`. Business definitions are documented on the Governance Notes report page.

| Measure | DAX Pattern | Purpose |
|---|---|---|
| `Total Spend` | `SUM(InvoiceAmount)` | Base measure — total invoice value in the current filter |
| `Total Budget` | `SUM(BudgetAmount)` | Budget allocation in the current filter |
| `Budget Variance` | `[Total Spend] - [Total Budget]` | Absolute variance — positive means overspend |
| `% Budget Variance` | `DIVIDE([Budget Variance], [Total Budget])` | Variance as a percentage, for comparing across departments |
| `PO Coverage Rate` | `DIVIDE(COUNTROWS(FILTER(df_clean_spend, df_clean_spend[POFlag] = "Yes")), COUNTROWS(df_clean_spend), 0)` | Share of transactions with a purchase order — flagged in the report below the illustrative 80% threshold |
| `Supplier Concentration %` | `DIVIDE([Total Spend], CALCULATE([Total Spend], ALL(Dim_Supplier)))` | Each supplier's share of spend after removing supplier-table filters, while retaining the surrounding date, department and other model context |
| `Top 2 Supplier Concentration` | `DIVIDE(SUMX(TOPN(2, VALUES(Dim_Supplier[SupplierKey]), [Total Spend], DESC), [Total Spend]), CALCULATE([Total Spend], ALL(Dim_Supplier)))` | Combined share of the two biggest suppliers, on the same all-supplier basis as above |
| `Spend vs Prior Year` | `DIVIDE([Total Spend] - CALCULATE([Total Spend], SAMEPERIODLASTYEAR(Dim_Date[FullDate])), CALCULATE([Total Spend], SAMEPERIODLASTYEAR(Dim_Date[FullDate])))` | Year-over-year change as a percentage — responds to the year, department and division filters |

**Ratio and percentage measures use `DIVIDE`** rather than the `/` operator, making zero-denominator handling explicit.

</details>

<details>
<summary id="row-level-security"><strong>Row-Level Security</strong></summary>

**In plain terms:** not everyone who opens this report should see everything in it. A department manager should see their own department's spend, not every department's. Finance should see spend across the business, but only for suppliers still active. Row-Level Security is the mechanism that enforces this automatically — the same report, showing different data, depending on who's signed in. The table below shows how each rule is actually written.

Two roles demonstrate dynamic and static RLS patterns.

| Role | Mechanism | Access |
|---|---|---|
| `Own Department` | `Dim_UserDepartmentMap[UserPrincipalName] = USERPRINCIPALNAME()`, linked through to `Dim_Department` | Mapped department only |
| `Finance` | `Dim_Supplier[Status] = "Active"` | All departments, active suppliers only |

**Design choices:**
- `Own Department` uses a separate mapping table (`Dim_UserDepartmentMap`) instead of comparing a user's email directly to a department name. A user's email rarely matches a department name, so this is closer to how a real company would do it — usually with data from HR or a directory system.
- `Finance` filters out inactive suppliers. This is an illustrative static role used to demonstrate a second RLS pattern; unlike the dynamic `Own Department` role, it's portfolio-specific business filtering rather than a recommended production finance-access design — a production finance/audit model would typically retain historical supplier visibility where needed, since access control should answer "who is allowed to see what," not "which records are currently useful."
- The RLS logic is kept simple on purpose, so it stays easy to check and test.
- In production, roles would be assigned through Entra ID security groups in Power BI Service, not to individual users.
- RLS applies to the Viewer role only. Admins, Members and Contributors can see everything, by design.

**Testing:** roles were checked using View As Role in Power BI Desktop, against known values — for example, the Finance role's supplier count drops from 12 to 9 when switched on, matching the three suppliers marked Inactive. This was checked directly, not just eyeballed.

![RLS — Own Department role](<screenshots/Security Roles 1.jpg>)
![RLS — Finance role](<screenshots/Security Roles 2.jpg>)

</details>

<details>
<summary id="direct-lake--sql-layer-security-testing"><strong>Direct Lake & SQL-Layer Security Testing</strong></summary>

**In plain terms:** Direct Lake is a Fabric semantic-model storage mode designed to access OneLake data without performing a traditional Import copy. This section tests whether Direct Lake still respects security rules written directly in the database — and finds that it does, but only if every table involved is protected, not just the obvious one. That gap, how it was found, and the fix, are documented below alongside a direct, measured comparison of refresh behaviour.

An additional, self-contained experiment alongside the main project: a second semantic model, built in **Direct Lake on SQL** mode from the same Warehouse, to test two things directly rather than take them on faith — how Direct Lake's refresh behaviour compares to Import, and how SQL-layer Row-Level Security actually behaves once Direct Lake is involved.

This is separate from the production semantic model used in the main report. It does not replace it.

**Why this matters:**
- Direct Lake refreshes by repointing to the latest data ("framing"), not by copying it. This was measured directly, not assumed.
- SQL-layer Row-Level Security on a Warehouse table interacts differently with Direct Lake depending on which variant is used, and depending on which tables a query actually touches. This was tested until the reason was understood, not stopped at the first correct-looking result.

---

### Setting up the Direct Lake model

A second semantic model, `ProcurementSpend-DirectLake`, was created directly from the Warehouse's `curated` schema, using **Direct Lake on SQL** storage mode.

![New semantic model — Direct Lake on SQL](<screenshots/direct lake semantic model.jpg>)

**Why "Direct Lake on SQL" and not "Direct Lake on OneLake":** the purpose of this experiment was specifically to test SQL-endpoint Row-Level Security. With Direct Lake on SQL, queries that reference tables protected by SQL-endpoint RLS can fall back to DirectQuery so the SQL engine can enforce the policy. Direct Lake on OneLake follows a different security model — it does not enforce SQL-endpoint RLS, and instead supports OneLake security and/or semantic-model security. For this specific SQL-RLS experiment, Direct Lake on SQL was therefore the appropriate mode.

---

### Refresh comparison: Direct Lake vs Import

The same underlying data was refreshed both ways, and the refresh history for each was checked directly.

**Direct Lake refresh ("framing") — 1 second:**

![Direct Lake refresh history — 1 second](<screenshots/direct lake refresh.jpg>)

**Import refresh (full data copy) — 22 seconds:**

![Import model refresh history — 22 seconds](<screenshots/import refresh.jpg>)

In this small portfolio test, Direct Lake framing completed in 1 second compared with 22 seconds for the Import refresh. This demonstrates a difference in refresh behaviour and duration in this specific model; it is not presented as a benchmark for query performance or enterprise-scale workloads.

---

### Testing SQL-layer Row-Level Security with Direct Lake

**In plain terms:** a security rule was added directly in the database, restricting each department to see only their own spend. The rule was first applied to the department list, and a related table of transactions was checked to see whether it was protected too — it wasn't. That gap, and how it was fixed, is shown below.

A T-SQL security predicate function and security policy were created directly on the Warehouse, separate from the existing DAX-based `Own Department` role used in the main report. This tests SQL-layer RLS specifically, not the model-layer RLS documented elsewhere in this project.

**Reproducibility note:** this SQL-layer RLS test was performed directly against the Warehouse as a standalone experiment. The predicate function, the two security policies, and the `curated.Dim_UserDepartmentMap` table they depend on are not currently committed as Warehouse project SQL objects in this repository — they exist only as the code shown below, run and verified interactively. Committing them as reproducible Warehouse artefacts is listed as a next step.

```sql
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
```

The predicate was first applied to `Dim_Department` only:

```sql
CREATE SECURITY POLICY Security.DepartmentFilter
ADD FILTER PREDICATE Security.fn_DepartmentPredicate(DepartmentKey)
ON curated.Dim_Department
WITH (STATE = ON);
GO
```

**A real finding: securing the dimension table alone was not enough.** Querying `Dim_Department` directly correctly returned only the signed-in user's own department. But a visual built from `DepartmentName` and total spend still showed a second, unlabelled row carrying the full spend total of every *other* department — the security policy was filtering the dimension correctly, but `Fact_Spend` itself had no protection at all, so unmatched rows from other departments were still being summed and shown, just without a department name attached to them.

This was confirmed directly, by querying `Fact_Spend` on its own, bypassing `Dim_Department` entirely:

```sql
EVALUATE
SUMMARIZECOLUMNS(
    'Fact_Spend'[DepartmentKey],
    "Total", SUM('Fact_Spend'[InvoiceAmount])
)
```

This returned all five departments' totals, confirming `Fact_Spend` was still fully exposed regardless of the dimension-level policy.

**The fix — extending the same predicate to `Fact_Spend` directly:**

```sql
CREATE SECURITY POLICY Security.FactSpendFilter
ADD FILTER PREDICATE Security.fn_DepartmentPredicate(DepartmentKey)
ON curated.Fact_Spend
WITH (STATE = ON);
GO
```

With both policies in place, the unlabelled row disappeared, and the visual correctly showed only the signed-in user's own department.

---

### Confirming the result

![RLS correctly enforced, with confirmed DirectQuery fallback](<screenshots/RLS fallback confirmed.jpg>)

This single result confirms two things at once:

1. **The security is correct** — signed in as a user mapped to the IT department, the visual shows only IT's spend (£3,535,681.60), with no unlabelled or leaked total from any other department.
2. **The fallback is real, not assumed** — Performance Analyzer shows a non-zero **Direct query** time (170ms) alongside the DAX query time (249ms) for this same visual. This is the documented mechanism by which Direct Lake enforces SQL-layer RLS: it cannot check the security policy itself, so it routes the query through DirectQuery specifically to have the SQL engine apply it.

**What this demonstrates, taken together:** in this project, Direct Lake framing was materially faster than the Import refresh. The more important finding, however, came from security testing: SQL-endpoint RLS on the dimension did not by itself protect direct access to the related fact table. In this implementation, protecting only `Dim_Department` did not protect direct queries against `Fact_Spend`. Testing exposed that gap, so the same security predicate was also applied to the fact table and the result retested.

</details>

<details>
<summary id="enterprise-use-cases--operational-considerations"><strong>Enterprise Use Cases & Operational Considerations</strong></summary>

The dataset is synthetic, but the solution was built around real, recurring procurement and finance needs — not a one-off report. The measures, security model and report pages documented above map directly onto real budget management, procurement compliance, supplier risk and controlled-release scenarios that any finance or procurement function would recognise.

**Operational considerations**

Data-quality checking is already built — the Warehouse load procedure catches bad or unresolvable rows and sends them to an exceptions table, instead of dropping or silently loading them (see Data Layer above). What is not yet built is *monitoring at scale*: automatic alerts when exceptions pile up, alerts when a refresh fails, and a proper refresh schedule instead of a manual one.

This project does not claim to have automated monitoring or alerting. Those are listed as future work, alongside the other items below.

</details>

<details>
<summary id="report-pages-full-detail"><strong>Report Pages (full detail)</strong></summary>

### Page 1 — Executive Overview
*Answers: Are we on budget? Where is spend trending?*

Four KPI tiles: Total Spend, Budget Variance, % Budget Variance, Spend vs Prior Year.

**Spend vs Budget by Period** — a combo chart, monthly spend as bars against a budget line. The bars show how spend moved through the year; the line gives a steady point of reference. Full-year 2024 position: -5.1% under budget (£305K favourable).

**Spend vs Budget by Department** — a bar chart. IT is the biggest overspend department; Marketing and Finance came in under budget; Operations and HR are within tolerance.

Year and Division filters sit on this page, so you don't need to leave it to change view.

![Executive Overview](<screenshots/Executive overview.jpg>)

### Page 2 — Supplier Analysis
*Answers: Which suppliers carry concentration or governance risk?*

**Total Spend by Supplier** and **Supplier Concentration %** — bar charts. The top two suppliers (Northstar Software 26.7%, BluePeak Consulting 24.2%) make up over half of total spend. That level of concentration is worth active contract management.

**Supplier detail table** — sorted by Contract Status (Inactive → Near Expiry → Secure), then by Total Spend. Columns: Supplier Name, Category, Supplier Tier, Contract Status, Contract Expiry, PO Coverage Rate, Budget Variance.

Total Spend is left out of the table on purpose — it's already in the bar charts above. The table's job is governance only: contract risk, PO discipline, budget position.

`Contract Status` comes from the Warehouse's `fn_ContractStatus` function, through `vw_ContractStatus_Current`, merged into `Dim_Supplier` in Power Query. It is not a Power BI calculated column. Checked against the reporting period end date (31 Dec 2024):
- **Inactive** — the supplier's `Status` field is Inactive (Summit Services, Greenline Solutions, CoreWorks Ltd — all Tier 3)
- **Near Expiry** — an active supplier with a contract expiring within 12 months (Skyline Travel, OfficeHub Supplies, Pioneer Tech)
- **Secure** — an active supplier with a contract valid beyond 12 months (all Tier 1 suppliers, plus Nimbus Training at Tier 2)

The 12-month **Near Expiry** threshold is an illustrative portfolio assumption. In a production implementation, the threshold would be agreed with Procurement and could vary by supplier tier, contract type or business policy.

**Report indicators**

PO Coverage Rate turns red below 80% — meaning fewer than 80% of a supplier's transactions had a purchase order recorded. The 80% threshold is an illustrative governance rule for this portfolio and would be business-configurable in a production implementation. In this synthetic dataset, the three suppliers below the threshold are Tier 3 and inactive.

Budget Variance turns red above £10,000 overspend. This is an illustrative materiality rule for this portfolio; a production threshold would be agreed with Finance/Procurement and may vary by organisational context.

The bar charts only display active suppliers. `Supplier Concentration %`'s denominator (`ALL(Dim_Supplier)`) removes all supplier-table filters, including Status — so the percentage shown is each active supplier's share of *total* spend, including inactive suppliers, not their share of active-supplier spend alone. Restricting the denominator to active suppliers only would be a DAX change, not just a display one, and is a candidate refinement if the page's intent shifts from total-spend share to current-supplier-base share.

![Supplier Analysis](<screenshots/Supplier Analysis.jpg>)

### Page 3 — Governance Notes
*Answers: What are the rules of this report?*

Plain-language documentation of the refresh schedule, RLS design, deployment setup, report indicators, and known limitations. Open to all report users.

**Report indicators documented here:**
- PO Coverage Rate flagged below 80% (illustrative threshold)
- Budget Variance flagged above £10,000 overspend (illustrative threshold)
- Contract Status thresholds — Inactive, Near Expiry (within 12 months, illustrative), Secure

**Why this page exists:** in a regulated setting, users need to know what the data means, how it's secured, and who to ask if something looks wrong. Putting this in the report itself closes the gap between documentation and the actual delivery.

![Governance Notes](<screenshots/Governance notes.jpg>)

</details>

<details>
<summary id="deployment--governance"><strong>Deployment & Governance</strong></summary>

A three-stage Fabric pipeline: Development → Test → Production.

| Stage | Workspace | Status |
|---|---|---|
| Dev | `Procurement-Spend-DEV` | Warehouse, Copy job, semantic model and report — all built, loaded and checked |
| Test | `Procurement-Spend-TEST` | Semantic model and report published, connected to Dev's Warehouse, refreshing correctly; RLS checked using Test as role in the Service |
| Prod | `Procurement-Spend-PROD` | Semantic model and report published, connected to Dev's Warehouse, endorsed as **Promoted** |

**A note on the architecture:** for this portfolio-scale dataset, Test and Prod deliberately share the Dev Warehouse, so the project can demonstrate artifact promotion without duplicating a small data platform three times. In a regulated production environment, I would separate environment data sources and apply environment-specific connection configuration — full per-stage data isolation is the standard pattern at that scale, and this project's shared-Warehouse approach is a deliberate simplification, not a claim that it's the more common design.

- The pipeline was built with Fabric's native Deployment pipelines feature, linking all three workspaces.
- Pre-deployment checks include reviewing transaction counts, spend totals and data-quality counts returned by the `usp_ReconcileSpendTotals` reconciliation procedure.
- Row-Level Security was tested directly in the Service, using Test as role for both `Own Department` and `Finance` — not just View As Role in Desktop.

![Deployment Pipeline](<screenshots/Pipeline view.jpg>)
![Endorsed Semantic Model](<screenshots/Endorsed semantic model.jpg>)

</details>

<details>
<summary id="ai-readiness--copilot-metadata"><strong>Semantic Model Documentation</strong></summary>

The semantic model includes centrally defined measures with documented business meaning and calculation intent (see `_Measures` above), supported by an in-report Governance Notes page.

Further model metadata — including broader table/column descriptions and synonym coverage for Copilot — is an area for continued enhancement rather than something currently committed to the model.

</details>

<details>
<summary id="data-lineage"><strong>Data Lineage</strong></summary>

**In plain terms:** the diagram below traces the full path data takes through this project — from the original file, through the checks and validation in the Warehouse, into the model, and finally into the report. The fact table's path is fully coded end to end; the dimension tables' promotion from staging to curated is not yet captured as committed SQL — see Known Limitations.

<pre>
Source files
└── Fabric Copy Job
    └── Fabric Warehouse
        ├── stg — raw / unvalidated inputs (Date, Department, Supplier, Fact)
        │   └── usp_LoadFactSpend — coded, committed load for Fact only
        │       ├── valid rows → curated.Fact_Spend
        │       └── invalid rows → Fact_Spend_Exceptions
        │   (Date/Department/Supplier promotion to curated not yet committed as SQL)
        │
        └── curated — typed / governed analytical tables
            └── Power BI semantic model (Import)
                ├── Single-direction relationships
                ├── DAX measures
                ├── Row-Level Security
                └── Report layer (3 pages)
</pre>

`Dim_CostCategory` is currently loaded by the Copy Job directly into `curated`, bypassing `stg` — see Known Limitations. Transformations are documented in the Power Query steps. Full lineage is visible in Fabric's lineage view, in the Production workspace.

![Lineage View](<screenshots/Lineage view.jpg>)

</details>

<details>
<summary id="known-limitations--next-steps"><strong>Known Limitations & Next Steps</strong></summary>

**Planned evolution**

The current project demonstrates governed spend reporting. The next phase — in priority order, after the ingestion gap below is closed — moves it toward *spend, supplier risk and governance* more broadly:
1. **Complete the ingestion architecture** — a consistent, reproducible staging → curated load path across all dimensions, not just the fact table (see below).
2. **A second genuine dynamic RLS scenario** — a `Procurement Category Manager` role, mapped to assigned categories the same way `Own Department` maps to departments, replacing the current static `Finance` role as the project's second security pattern.
3. **Supplier performance / third-party risk data** — SLA performance, incidents, criticality and contract ownership alongside the existing spend and contract-expiry view, reflecting how financial-services firms are expected to monitor third-party dependency throughout the life of a supplier relationship.
4. **Operational monitoring** — surfacing load/exception counts, reconciliation status and refresh freshness, rather than leaving that value implicit in the Warehouse.

This is intentionally sequenced rather than attempted all at once: the ingestion gap is closed first because it underpins everything built on top of it, and the RLS change is deliberately held until it can be done with the same rigour (test users, positive/negative cases, documentation) as the rest of this project.

**Current limitations**
- Budget figures are monthly allocations, spread proportionally across transactions. The headline variance is a full-year figure — filter by department to see period-level detail.
- Fact data follows a coded staging → validation → curated path through `usp_LoadFactSpend`. Date, Department and Supplier currently land in staging, but their equivalent promotion logic into curated is not yet captured as committed SQL in this repository. `Dim_CostCategory` currently bypasses staging entirely. Completing a consistent, reproducible staging → curated load path across all dimensions is a known next step. Also not yet a cloud-hosted source that refreshes continuously.
- `Dim_UserDepartmentMap` is still a small, manually-typed table — not yet pulled from the Warehouse or from an HR/directory system.
- RLS has been checked with View As Role in Desktop and Test as role in the Service, for one authorised department user. Cross-department denial and unmapped-user cases aren't documented separately yet. Testing with multiple real accounts needs Entra ID group assignment.
- Refresh is manual — no schedule is set up yet.

**Delivered since the initial build**
- **SQL source layer** — a Fabric Warehouse with staging and curated schemas, one governed view, one parameterised function, and two stored procedures (`usp_LoadFactSpend` for validated loading, `usp_ReconcileSpendTotals` for pre-deployment reconciliation). Replaces the original CSV-and-Power-Query-only setup.
- **Data-quality quarantine** — `usp_LoadFactSpend` checks and converts staged data, sending bad rows to `Fact_Spend_Exceptions` with a reason. Tested by deliberately breaking a row and confirming it was caught — not just assumed to work.
- **RLS upgraded** — `Own Department` (previously `Department_User`) now uses a mapping table instead of comparing names directly. Closer to how a real deployment would work.
- **Deployment pipeline completed** — all three stages (Dev/Test/Prod) publish and refresh correctly against a shared Warehouse. The Prod model is endorsed as Promoted, and RLS is checked in the Service.
- **Version control added** — the Development workspace is connected to Git. The Warehouse schema is source-controlled as a database project with individual SQL objects, while the semantic model and report are stored in source-controllable Power BI/Fabric project (PBIP) formats.
- **Direct Lake and SQL-layer security tested** — a separate Direct Lake semantic model was built to measure refresh speed against Import, and to test how SQL-layer Row-Level Security behaves with Direct Lake. Found and fixed a real gap where securing a dimension table alone did not protect the related fact table.

**Planned next steps**
- **Cloud-hosted, scheduled refresh** — move from manual refresh to a set Fabric schedule.
- **Incremental refresh** — considered for larger datasets. At this size, a full refresh is still the right call.
- **Multi-user RLS testing** — assign Entra ID security groups and check role behaviour across separate accounts.
- **Move `Dim_UserDepartmentMap` into the Warehouse** — replacing the manual table with a properly governed one.
- **Commit the SQL-layer RLS experiment as Warehouse objects** — the predicate function, dimension and fact security policies, and the mapping table it depends on, currently exist only as tested SQL shown in this README, not as committed project artefacts.
- **Complete a consistent staging → curated load path for all dimensions** — currently only the fact load is coded; see Known Limitations.
- **Automated refresh monitoring and alerting** — beyond the quarantine logic already built, for real production visibility.

</details>

<details>
<summary id="key-design-decisions"><strong>Key Design Decisions</strong></summary>

| Decision | Reason |
|---|---|
| Fabric Warehouse over Lakehouse SQL analytics endpoint | The Lakehouse SQL analytics endpoint provides a read-only T-SQL surface over Delta tables — it supports queries, views, functions and stored procedures, but not `INSERT`/`UPDATE`/`DELETE` against the underlying tables. This project requires T-SQL data modification during the governed load process, so Warehouse was selected |
| Staging → curated schema split | Keeps raw, unchecked data away from anything the semantic model or reports can read |
| Exception quarantine over silent drop | Keeps bad records and the reason they failed, so they can be investigated — rather than losing them |
| Parameterised `fn_ContractStatus` over a fixed column | Works for any date you ask about; the first version was locked to one fixed date and had to be fixed |
| Mapping-table RLS over direct name comparison | Separates who a user is from what department they belong to — closer to how it would work in a real company |
| Declared, unenforced PK/FK | Not checked at write time in Fabric Warehouse, but still documents the intended structure of the model |
| Dedicated `_Measures` table | Keeps DAX calculation logic separate from the underlying data model |
| Dev → Test → Prod pipeline | Shows controlled promotion of changes, rather than editing production directly |
| SQL-layer RLS extended to the fact table, not just the dimension | Testing showed the dimension-only policy left the fact table's own data unprotected — the same rule had to be applied to both |

</details>

---

*Senior BI Developer | Power BI & Microsoft Fabric | Modernising Enterprise BI | Semantic Modelling, DAX & Governance | Financial Services | PL-300 Certified*
*[linkedin.com/in/nish-goel](https://linkedin.com/in/nish-goel) · [github.com/nishantgoeluk-pixel](https://github.com/nishantgoeluk-pixel)*
