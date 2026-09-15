# Procurement Spend Governance & Analytics
**Power BI · Microsoft Fabric Warehouse · Row-Level Security · Governed MI**

An independent portfolio project. It builds a governed procurement spend analytics solution end to end: a SQL Warehouse layer, a star-schema semantic model, Row-Level Security, and a controlled Dev→Test→Prod deployment pipeline. Uses a synthetic dataset (850 transactions, 12 suppliers, 5 departments). Real enterprise-scale experience is shown separately, through commercial BI work at NatWest Group.

![Executive Overview](<screenshots/Executive overview.jpg>)

**Why this matters:**
- Data is checked and governed in a Fabric SQL Warehouse *before* it reaches Power BI. It is not loaded straight from CSV. Bad rows are caught and set aside automatically, not silently dropped or loaded.
- Row-Level Security uses a realistic mapping-table pattern. It was tested against known values, not just checked by eye.
- Contract status has one definition, in the SQL layer (`fn_ContractStatus`). Budget variance and PO coverage thresholds are defined in DAX, in `_Measures`.

Full detail and every report page are below — click a section to expand it.

## What This Demonstrates

| Capability | Implementation |
|---|---|
| **Dimensional modelling** | Star schema — 1 fact table, 4 analytical dimensions and 1 security mapping table, single-direction relationships, hidden foreign keys |
| **DAX measure design** | 8 measures kept in one `_Measures` table, each with a documented business definition |
| **Row-Level Security** | Two roles — a dynamic `Own Department` role using a user-to-department mapping table and `USERPRINCIPALNAME()`, and a static `Finance` role scoped to active suppliers only; Entra ID group assignment is documented for production use |
| **Governed SQL layer** | Fabric Warehouse with separate staging and curated schemas, one T-SQL view, one parameterised function, and one stored procedure that checks and quarantines bad rows before they reach the semantic model |
| **Fabric deployment** | Three-stage pipeline (Dev → Test → Prod) built with Fabric's native Deployment pipelines feature; Test and Prod share Dev's Warehouse as one data source; the Prod semantic model is endorsed as Promoted |
| **Direct Lake & SQL-layer security** | A second, separate semantic model built in Direct Lake on SQL mode — measured against Import for refresh speed, and used to find and fix a real SQL-layer RLS gap between a dimension and its related fact table |
| **Semantic model governance** | Production semantic model endorsed as Promoted, with documented business definitions and metadata |
| **Data lineage** | Source → Power Query → semantic model → report, documented through Fabric lineage |
| **Finance domain knowledge** | Budget variance analysis, supplier concentration risk, PO coverage governance, contract expiry management |

## Contents
- [Business Problem](#business-problem)
- [Data Layer — Fabric Warehouse](#data-layer)
- [Model Design](#model-design)
- [Key Measures](#key-measures)
- [Row-Level Security](#row-level-security)
- [Direct Lake & SQL-Layer Security Testing](#direct-lake--sql-layer-security-testing)
- [Enterprise Use Cases & Operational Considerations](#enterprise-use-cases--operational-considerations)
- [Report Pages (full detail)](#report-pages-full-detail)
- [Deployment & Governance](#deployment--governance)
- [AI Readiness — Copilot Metadata](#ai-readiness--copilot-metadata)
- [Data Lineage](#data-lineage)
- [Known Limitations & Next Steps](#known-limitations--next-steps)
- [Key Design Decisions](#key-design-decisions)

---

<details>
<summary><strong>Business Problem</strong></summary>

Finance and Procurement teams need a trusted, auditable view of spend — by supplier, department and cost category. Without a governed model, reporting becomes fragmented, budget variance is unclear, and access control becomes a risk.

This solution replaces ad-hoc reporting with one structured semantic model, clear measures, role-based access, and documented governance. Teams can explore spend on their own, with confidence in the numbers.

**The solution supports three levels of decision-making:**
- **Monitor** — are we on budget, and where is spend moving?
- **Identify risk** — which suppliers, contracts or purchasing behaviours need attention?
- **Govern** — are purchases compliant with procurement controls and access policies?

</details>

<details>
<summary><strong>Data Layer — Fabric Warehouse</strong></summary>

Source data passes through a governed SQL layer in Fabric before it reaches the semantic model. It is not loaded straight from CSV into Power BI.

**Why a Warehouse, not a Lakehouse:** the Lakehouse SQL analytics endpoint is read-only over the underlying Lakehouse tables. It can create views, functions and stored procedures, but not change data (`INSERT`/`UPDATE`/`DELETE`) or change table structure (`CREATE`/`ALTER`/`DROP TABLE`). This project needs both, so it uses a Warehouse.

**Staging and curated schemas:**
- `stg` holds the raw data exactly as it arrives — as text, unchecked. Nothing downstream reads from it directly.
- `curated` is the governed layer — typed, keyed, checked. Only this layer connects to the semantic model.

**What the SQL layer does:**
- **`fn_ContractStatus`** — a parameterised function that classifies each supplier as Secure, Near Expiry or Inactive, as of any date you give it. Not a fixed column locked to one date.
- **`usp_LoadFactSpend`** — checks and converts staged data. Rows that fail — wrong type, or an unknown key — go to a `Fact_Spend_Exceptions` table with a reason. Nothing is silently dropped or silently loaded.
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
<summary><strong>Model Design</strong></summary>

A star schema: one fact table, four analytical dimensions, and one security mapping table.

| Layer | Table | Purpose |
|---|---|---|
| Fact | `df_clean_spend` | Transaction-level spend, budget, variance, PO and approval detail |
| Dimension | `Dim_Date` | Time filtering — year, quarter, month, week, plus fiscal year and quarter |
| Dimension | `Dim_Supplier` | Supplier name, tier, category, contract expiry, risk classification |
| Dimension | `Dim_Department` | Department, division, location, cost centre head, annual budget |
| Dimension | `Dim_CostCategory` | Category name, budget type, spend type |
| Dimension | `Dim_UserDepartmentMap` | Maps a user to their department, for `Own Department` RLS |

Relationships run one way, from dimensions to fact. Foreign keys are hidden from the report layer. Measures sit in one `_Measures` table, not scattered across visuals.

**Why one-way relationships:** they keep filtering predictable and the model easier to reason about. This model does not need two-way filtering, so it was left out on purpose. Keeping measures in `_Measures` separates calculation logic from the data itself, which makes the model easier to maintain.

![Model View](<screenshots/Model View.jpg>)

</details>

<details>
<summary><strong>Key Measures</strong></summary>

**In plain terms:** every calculation used in this report — spend totals, budget comparisons, supplier risk indicators — is written once, in one place, using a formula language called DAX. Keeping every calculation in one table, with one definition each, means every report page uses exactly the same logic, and there's only ever one place to check or update it. The table below shows the actual formula for each measure, alongside what it's for in plain business terms.

All measures live in `_Measures`. Business definitions are documented on the Governance Notes report page.

| Measure | DAX Pattern | Purpose |
|---|---|---|
| `Total Spend` | `SUM(InvoiceAmount)` | Base measure — total invoice value in the current filter |
| `Total Budget` | `SUM(BudgetAmount)` | Budget allocation in the current filter |
| `Budget Variance` | `[Total Spend] - [Total Budget]` | Absolute variance — positive means overspend |
| `% Budget Variance` | `DIVIDE([Budget Variance], [Total Budget])` | Variance as a percentage, for comparing across departments |
| `PO Coverage Rate` | `DIVIDE(CALCULATE([Total Spend], df_clean_spend[POFlag] = "Yes"), [Total Spend])` | Share of spend backed by a purchase order — flagged in the report below 80% |
| `Supplier Concentration %` | `DIVIDE([Total Spend], CALCULATE([Total Spend], ALL(Dim_Supplier)))` | Each supplier's share of total spend, regardless of the current filter |
| `Top 2 Supplier Concentration` | `DIVIDE(SUMX(TOPN(2, VALUES(Dim_Supplier[SupplierKey]), [Total Spend], DESC), [Total Spend]), CALCULATE([Total Spend], ALL(Dim_Supplier)))` | Combined share of the two biggest suppliers, always relative to total spend |
| `Spend vs Prior Year` | `DIVIDE([Total Spend] - CALCULATE([Total Spend], SAMEPERIODLASTYEAR(Dim_Date[FullDate])), CALCULATE([Total Spend], SAMEPERIODLASTYEAR(Dim_Date[FullDate])))` | Year-over-year change as a percentage — responds to the year, department and division filters |

**`DIVIDE` is used everywhere** instead of the `/` operator. It makes zero-denominator handling explicit and avoids divide-by-zero errors, rather than leaving it to chance.

</details>

<details>
<summary><strong>Row-Level Security</strong></summary>

**In plain terms:** not everyone who opens this report should see everything in it. A department manager should see their own department's spend, not every department's. Finance should see spend across the business, but only for suppliers still active. Row-Level Security is the mechanism that enforces this automatically — the same report, showing different data, depending on who's signed in. The table below shows how each rule is actually written.

Two roles, built on least-privilege access.

| Role | Mechanism | Access |
|---|---|---|
| `Own Department` | `Dim_UserDepartmentMap[UserPrincipalName] = USERPRINCIPALNAME()`, linked through to `Dim_Department` | Own cost centre only |
| `Finance` | `Dim_Supplier[Status] = "Active"` | All departments, active suppliers only |

**Design choices:**
- `Own Department` uses a separate mapping table (`Dim_UserDepartmentMap`) instead of comparing a user's email directly to a department name. A user's email rarely matches a department name, so this is closer to how a real company would do it — usually with data from HR or a directory system.
- `Finance` filters out inactive suppliers. This is scoped for this portfolio's operational reporting scenario; a production finance/audit model would typically retain historical supplier visibility where needed, since access control should answer "who is allowed to see what," not "which records are currently useful."
- The RLS logic is kept simple on purpose, so it stays easy to check and test.
- In production, roles would be assigned through Entra ID security groups in Power BI Service, not to individual users.
- RLS applies to the Viewer role only. Admins, Members and Contributors can see everything, by design.

**Testing:** roles were checked using View As Role in Power BI Desktop, against known values — for example, the Finance role's supplier count drops from 12 to 9 when switched on, matching the three suppliers marked Inactive. This was checked directly, not just eyeballed.

![RLS — Own Department role](<screenshots/Security Roles 1.jpg>)
![RLS — Finance role](<screenshots/Security Roles 2.jpg>)

</details>

<details>
<summary><strong>Direct Lake & SQL-Layer Security Testing</strong></summary>

**In plain terms:** Power BI has a newer, faster way of connecting to data called Direct Lake. This section tests whether that faster connection still respects security rules written directly in the database — and finds that it does, but only if every table involved is protected, not just the obvious one. That gap, how it was found, and the fix, are documented below alongside a direct, measured comparison of refresh speed.

An additional, self-contained experiment alongside the main project: a second semantic model, built in **Direct Lake on SQL** mode from the same Warehouse, to test two things directly rather than take them on faith — how Direct Lake's refresh behaviour compares to Import, and how SQL-layer Row-Level Security actually behaves once Direct Lake is involved.

This is separate from the production semantic model used in the main report. It does not replace it.

**Why this matters:**
- Direct Lake refreshes by repointing to the latest data ("framing"), not by copying it. This was measured directly, not assumed.
- SQL-layer Row-Level Security on a Warehouse table interacts differently with Direct Lake depending on which variant is used, and depending on which tables a query actually touches. This was tested until the reason was understood, not stopped at the first correct-looking result.

---

### Setting up the Direct Lake model

A second semantic model, `ProcurementSpend-DirectLake`, was created directly from the Warehouse's `curated` schema, using **Direct Lake on SQL** storage mode.

![New semantic model — Direct Lake on SQL](<screenshots/Direct Lake semantic model.jpg>)

**Why "Direct Lake on SQL" and not "Direct Lake on OneLake":** the two variants behave differently when SQL-layer Row-Level Security is present. On SQL, a query that needs RLS-protected data falls back to DirectQuery to enforce it. On OneLake, that same query would succeed but silently skip the RLS check entirely — the model wouldn't apply it, and nothing would warn you. Since the whole point of this experiment was to observe RLS enforcement, the SQL variant was the correct choice.

---

### Refresh comparison: Direct Lake vs Import

The same underlying data was refreshed both ways, and the refresh history for each was checked directly.

**Direct Lake refresh ("framing") — 1 second:**

![Direct Lake refresh history — 1 second](<screenshots/Direct Lake refresh.jpg>)

**Import refresh (full data copy) — 22 seconds:**

![Import model refresh history — 22 seconds](<screenshots/Import refresh.jpg>)

At this project's small scale (850 transactions), that's already a ~22x difference. At larger data volumes, the performance characteristics of each mode make a bigger gap likely, but the actual difference in any given environment depends on the model, workload, and capacity — not something this test alone can prove at scale.

---

### Testing SQL-layer Row-Level Security with Direct Lake

**In plain terms:** a security rule was added directly in the database, restricting each department to see only their own spend. The rule was first applied to the department list, and a related table of transactions was checked to see whether it was protected too — it wasn't. That gap, and how it was fixed, is shown below.

A T-SQL security predicate function and security policy were created directly on the Warehouse, separate from the existing DAX-based `Own Department` role used in the main report. This tests SQL-layer RLS specifically, not the model-layer RLS documented elsewhere in this project.

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

**What this demonstrates, taken together:** Direct Lake's speed advantage over Import is real and measurable, even at small scale. Its handling of SQL-layer security is equally real, but does not automatically extend from a dimension table to a related fact table — that has to be applied deliberately, table by table, and verified by testing what a query actually returns, not just what the security policy appears to say.

</details>

<details>
<summary><strong>Enterprise Use Cases & Operational Considerations</strong></summary>

The dataset is synthetic, but the solution was built around real, recurring procurement and finance needs — not a one-off report. The measures, security model and report pages documented above map directly onto real budget management, procurement compliance, supplier risk and controlled-release scenarios that any finance or procurement function would recognise.

**Operational considerations**

Data-quality checking is already built — the Warehouse load procedure catches bad or unresolvable rows and sends them to an exceptions table, instead of dropping or silently loading them (see Data Layer above). What is not yet built is *monitoring at scale*: automatic alerts when exceptions pile up, alerts when a refresh fails, and a proper refresh schedule instead of a manual one.

This project does not claim to have automated monitoring or alerting. Those are listed as future work, alongside the other items below.

</details>

<details>
<summary><strong>Report Pages (full detail)</strong></summary>

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

The 12-month cutoff is a working assumption, based on how far ahead procurement teams typically start renewing Tier 1 and Tier 2 contracts.

**Report indicators**

PO Coverage Rate turns red below 80% — meaning less than 80% of a supplier's spend had a purchase order in place before the invoice. All three suppliers below this line are Tier 3 and Inactive, which fits — lower tiers tend to have looser controls.

Budget Variance turns red above £10,000 overspend. Smaller variances aren't flagged, since only material ones are worth escalating.

The bar charts only include active suppliers, so old spend from inactive ones doesn't distort the picture.

![Supplier Analysis](<screenshots/Supplier Analysis.jpg>)

### Page 3 — Governance Notes
*Answers: What are the rules of this report?*

Plain-language documentation of the refresh schedule, RLS design, deployment setup, report indicators, and known limitations. Open to all report users.

**Report indicators documented here:**
- PO Coverage Rate flagged below 80%
- Budget Variance flagged above £10,000 overspend
- Contract Status thresholds — Inactive, Near Expiry (within 12 months), Secure

**Why this page exists:** in a regulated setting, users need to know what the data means, how it's secured, and who to ask if something looks wrong. Putting this in the report itself closes the gap between documentation and the actual delivery.

![Governance Notes](<screenshots/Governance notes.jpg>)

</details>

<details>
<summary><strong>Deployment & Governance</strong></summary>

A three-stage Fabric pipeline: Development → Test → Production.

| Stage | Workspace | Status |
|---|---|---|
| Dev | `Procurement-Spend-DEV` | Warehouse, Copy job, semantic model and report — all built, loaded and checked |
| Test | `Procurement-Spend-TEST` | Semantic model and report published, connected to Dev's Warehouse, refreshing correctly; RLS checked using Test as role in the Service |
| Prod | `Procurement-Spend-PROD` | Semantic model and report published, connected to Dev's Warehouse, endorsed as **Promoted** |

**A note on the architecture:** for this portfolio-scale dataset, Test and Prod deliberately share the Dev Warehouse, so the project can demonstrate artifact promotion without duplicating a small data platform three times. In a regulated production environment, I would separate environment data sources and apply environment-specific connection configuration — full per-stage data isolation is the standard pattern at that scale, and this project's shared-Warehouse approach is a deliberate simplification, not a claim that it's the more common design.

- The pipeline was built with Fabric's native Deployment pipelines feature, linking all three workspaces.
- Pre-deployment checks include reconciling spend totals against the source extract.
- Row-Level Security was tested directly in the Service, using Test as role for both `Own Department` and `Finance` — not just View As Role in Desktop.

![Deployment Pipeline](<screenshots/Pipeline view.jpg>)
![Endorsed Semantic Model](<screenshots/Endorsed semantic model.jpg>)

</details>

<details>
<summary><strong>AI Readiness — Copilot Metadata</strong></summary>

The semantic model was prepared for Copilot using Power BI Desktop's Model view.

Applied across the model:
- **Table descriptions** — all six tables, with a note on what each is for
- **Column descriptions** — queryable columns, with business meaning, usage notes, and known limitations
- **Measure descriptions** — all eight measures, with business meaning, calculation logic, and usage guidance

This metadata helps Copilot interpret the model and improves the quality of supported Copilot experiences once the model runs on Fabric capacity. It makes the model Copilot-ready; actually running Copilot queries needs Fabric capacity, which isn't switched on in this trial environment.

</details>

<details>
<summary><strong>Data Lineage</strong></summary>

**In plain terms:** the diagram below traces the full path data takes through this project — from the original file, through the checks and validation in the Warehouse, into the model, and finally into the report. Each step only receives data that has passed the step before it.

<pre>
Source (CSV extract)
└── Fabric Warehouse — stg schema (text, unvalidated)
    └── usp_LoadFactSpend — cast, validate, quarantine
        ├── curated schema (typed, keyed, governed)
        │   ├── 4 dimension tables + 1 security mapping table
        │   ├── 1 fact table
        │   ├── View, function, exceptions table
        │   └── Declared PK/FK (NOT ENFORCED)
        └── Fact_Spend_Exceptions (invalid rows, with reason)
            └── Power BI semantic model (Import)
                ├── Single-direction relationships
                ├── Row-Level Security
                └── Report layer (3 pages)
</pre>

Transformations are documented in the Power Query steps. Full lineage is visible in Fabric's lineage view, in the Production workspace.

![Lineage View](<screenshots/Lineage view.jpg>)

</details>

<details>
<summary><strong>Known Limitations & Next Steps</strong></summary>

**Current limitations**
- Budget figures are monthly allocations, spread proportionally across transactions. The headline variance is a full-year figure — filter by department to see period-level detail.
- Source files load from CSV, through a Fabric Copy job, into a text-only staging layer, then get typed and checked in SQL. Not yet a cloud-hosted source that refreshes continuously.
- `Dim_UserDepartmentMap` is still a small, manually-typed table — not yet pulled from the Warehouse or from an HR/directory system.
- RLS has been checked with View As Role in Desktop and Test as role in the Service, for one authorised department user. Cross-department denial and unmapped-user cases aren't documented separately yet. Testing with multiple real accounts needs Entra ID group assignment.
- Refresh is manual — no schedule is set up yet.

**Delivered since the initial build**
- **SQL source layer** — a Fabric Warehouse with staging and curated schemas, one governed view, one parameterised function, and one stored procedure. Replaces the original CSV-and-Power-Query-only setup.
- **Data-quality quarantine** — `usp_LoadFactSpend` checks and converts staged data, sending bad rows to `Fact_Spend_Exceptions` with a reason. Tested by deliberately breaking a row and confirming it was caught — not just assumed to work.
- **RLS upgraded** — `Own Department` (previously `Department_User`) now uses a mapping table instead of comparing names directly. Closer to how a real deployment would work.
- **Deployment pipeline completed** — all three stages (Dev/Test/Prod) publish and refresh correctly against a shared Warehouse. The Prod model is endorsed as Promoted, and RLS is checked in the Service.
- **Version control added** — the Dev workspace is connected to Git, syncing Fabric items (Warehouse, semantic model, report) as `.pbip`, not just `.pbix`.
- **Direct Lake and SQL-layer security tested** — a separate Direct Lake semantic model was built to measure refresh speed against Import, and to test how SQL-layer Row-Level Security behaves with Direct Lake. Found and fixed a real gap where securing a dimension table alone did not protect the related fact table.

**Planned next steps**
- **Cloud-hosted, scheduled refresh** — move from manual refresh to a set Fabric schedule.
- **Incremental refresh** — considered for larger datasets. At this size, a full refresh is still the right call.
- **Multi-user RLS testing** — assign Entra ID security groups and check role behaviour across separate accounts.
- **Move `Dim_UserDepartmentMap` into the Warehouse** — replacing the manual table with a properly governed one.
- **Automated refresh monitoring and alerting** — beyond the quarantine logic already built, for real production visibility.

</details>

<details>
<summary><strong>Key Design Decisions</strong></summary>

| Decision | Reason |
|---|---|
| Fabric Warehouse over Lakehouse | The load process needs to change table structure and modify data (`INSERT`/`UPDATE`/`DELETE`); the Lakehouse SQL endpoint supports views, functions and procedures, but not those two |
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
