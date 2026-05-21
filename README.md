# Procurement Spend Governance & Analytics
**Power BI · Star Schema · Row-Level Security · Fabric Deployment Pipeline · Governed MI**

A procurement spend analytics solution built to production standard — from source data to governed report. Covers dimensional modelling, DAX measure design, row-level security, Fabric deployment pipeline and embedded governance across a finance and procurement domain. Reflects the delivery approach applied commercially at NatWest Group for £5bn+ enterprise spend reporting.

---

## What This Demonstrates

| Capability | Implementation |
|---|---|
| **Dimensional modelling** | Star schema — 1 fact table, 4 supporting dimensions, single-direction relationships, hidden foreign keys |
| **DAX measure design** | 8 measures isolated in a dedicated `_Measures` table with documented business definitions |
| **Row-Level Security** | Dynamic `USERPRINCIPALNAME()` role and static supplier filter — Entra ID group assignment in Service |
| **Fabric deployment** | Three-stage pipeline (Dev → Test → Prod) with auditable deployment history |
| **Semantic model governance** | Endorsed as Promoted in Production workspace — available as a trusted source for report builders |
| **Data lineage** | Source → Power Query → semantic model → report layer, auditable in Fabric lineage view |
| **Finance domain knowledge** | Budget variance analysis, supplier concentration risk, PO coverage governance, contract expiry management |

---

## Business Problem

Finance and Procurement teams need a trusted, auditable view of spend across suppliers, departments and cost categories. Without a governed model, reporting becomes fragmented, budget variance is unclear, and access control becomes a compliance risk.

This solution replaces ad-hoc reporting with a structured semantic model, clearly defined measures, role-based access and documented governance — so teams can independently explore spending patterns with confidence in the numbers.

**The report answers three questions:**
- Are we on budget, and which departments are driving variance?
- Which suppliers represent concentration or contract renewal risk?
- Is our procurement process governed — are purchases approved and PO-backed?

---

## Model Design

Classic star schema with a single fact table and four supporting dimensions.

| Layer | Table | Purpose |
|---|---|---|
| Fact | `df_clean_spend` | Transaction-level spend, budget, variance, PO and approval detail |
| Dimension | `Dim_Date` | Consistent time filtering — calendar year, quarter, month, week; fiscal year and fiscal quarter columns available in the semantic layer |
| Dimension | `Dim_Supplier` | Supplier name, tier, category, contract expiry, contract risk classification |
| Dimension | `Dim_Department` | Department, division, location, cost centre head, annual budget |
| Dimension | `Dim_CostCategory` | Category name, budget type, spend type |

Single-direction relationships from dimensions to fact. Foreign keys hidden from report layer. Measures isolated in a dedicated `_Measures` table — not embedded in visuals.

**Design rationale:** Single-direction relationships prevent ambiguous filter propagation. Isolating measures in a dedicated table enforces separation between data and calculation logic, simplifying governance and future maintenance.

![Model View](<screenshots/Model View.jpg>)

---

## Key Measures

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
| `Spend vs Prior Year` | `CALCULATE([Total Spend], SAMEPERIODLASTYEAR(Dim_Date[FullDate]))` | Year-over-year spend movement — filter-context dependent; responds to year, department and division slicers |

**`DIVIDE` is used throughout** rather than division operators — prevents divide-by-zero errors and returns BLANK in empty filter contexts. This is the correct behaviour for a governed reporting model where missing data should be visible, not hidden behind an error.

---

## Row-Level Security

Two roles implemented with least-privilege design.

| Role | Table | Filter | Access |
|---|---|---|---|
| `Department_User` | `Dim_Department` | `[DepartmentName] = USERPRINCIPALNAME()` | Own cost centre only |
| `Finance` | `Dim_Supplier` | `[Status] = "Active"` | All departments, active suppliers only |

**Design decisions:**
- `Department_User` uses dynamic RLS via `USERPRINCIPALNAME()` — one role covers all department users without maintaining individual user filters. In a production deployment, DepartmentName values would be replaced with UPN values, or a user-to-department mapping table would be used to link each user's email address to their cost centre
- `Finance` role applies a static supplier filter — excludes inactive/lapsed suppliers from the finance view, reducing noise and supporting data quality governance
- RLS logic is intentionally simple to ensure it is auditable and testable
- In production, role assignment is managed through Entra ID security groups in Power BI Service — not individual user assignment
- RLS applies to Viewer role only — Admins, Members and Contributors bypass RLS by design

![RLS — Department_User role](<screenshots/Security Roles 1.jpg>)
![RLS — Finance role](<screenshots/Security Roles 2.jpg>)

---

## Report Pages

### Page 1 — Executive Overview
*Answers: Are we on budget? Where is spend trending?*

Four KPI tiles: Total Spend, Budget Variance, % Budget Variance, Spend vs Prior Year.

**Spend vs Budget by Period** — combo chart showing monthly actual spend (bars) against budget line. Bars show spend volatility across the year; the budget line provides the consistent reference point. 2024 full-year position: -5.1% under budget (£305K favourable variance).

**Spend vs Budget by Department** — clustered bar chart. Immediately surfaces the department story: IT is the largest overspend department; Marketing came in under budget. Finance, Operations and HR within tolerance.

Year and Division slicers placed on the page keep filtering in context — no need to navigate to a separate page for a different view.

![Executive Overview](<screenshots/Executive overview.jpg>)

### Page 2 — Supplier Analysis
*Answers: Which suppliers carry concentration or governance risk?*

**Total Spend by Supplier** and **Supplier Concentration %** — horizontal bar charts. Top two suppliers (Northstar Software 26.7%, BluePeak Consulting 24.2%) account for over 50% of total spend. Concentration at this level warrants active contract management.

**Supplier detail table** — sorted by Contract Status (Inactive → Near Expiry → Secure), then Total Spend. Columns: Supplier Name, Category, Supplier Tier, Contract Status, Contract Expiry, PO Coverage Rate, Budget Variance.

Total Spend is intentionally excluded from the table — it is already visible in the bar charts above. The table serves as the governance layer only: contract risk, PO discipline, and budget position.

`Contract Status` is a calculated column evaluated against the reporting period end date (31 Dec 2024):
- **Inactive** — supplier deactivated (Summit Services, Greenline Solutions, CoreWorks Ltd — all Tier 3)
- **Near Expiry** — contract expiring within 12 months (Skyline Travel, OfficeHub Supplies, Pioneer Tech)
- **Secure** — contract valid beyond 12 months (all Tier 1 suppliers, plus Nimbus Training at Tier 2)

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

---

## Deployment & Governance

Three-stage Fabric deployment pipeline: Development → Test → Production.

| Stage | Workspace | Purpose |
|---|---|---|
| Dev | `Procurement-Spend-DEV` | Active development and testing |
| Test | `Procurement-Spend-DEV [Test]` | Pre-release validation |
| Prod | `Procurement-Spend-PROD` | Promoted production version |

- Deployment history tracked with timestamp and deployer identity — auditable in Fabric Deployment History
- Semantic model endorsed as **Promoted** in Production workspace
- RLS tested in Power BI Service before each production deployment
- Pre-deployment validation includes spend totals reconciled against source extract and RLS role testing in Power BI Service

![Deployment Pipeline](<screenshots/Pipeline view.jpg>)
![Deployment History](<screenshots/Deployment history.jpg>)
![Endorsed Semantic Model](<screenshots/Endorsed semantic model.jpg>)

---

## Data Lineage

```
Source (CSV extract)
└── Power Query transformation (df_clean_spend)
    ├── Column typing and key validation
    ├── Removal of unused fields
    └── Star schema semantic model
        ├── 4 dimension tables
        ├── 1 fact table
        ├── Single-direction relationships
        └── Report layer (3 pages)
```

Transformation logic documented in Power Query query steps. Full lineage visible in the Fabric lineage view in the Production workspace.

![Lineage View](<screenshots/Lineage view.jpg>)

---

## Known Limitations

Budget amounts represent monthly procurement allocations distributed proportionally across transactions. Headline variance reflects the full-year position; filter by department for period-level analysis.

Source files are currently loaded via a local gateway connection. The next development step is migrating source files to SharePoint or OneLake to enable fully cloud-based scheduled refresh — consistent with how this would be configured in an enterprise environment.

---

*Nishant Goel — Senior BI Engineer | Power BI · DAX · Power Query · Semantic Modelling · Microsoft Fabric*
*[linkedin.com/in/nish-goel](https://linkedin.com/in/nish-goel) · [github.com/nishantgoeluk-pixel](https://github.com/nishantgoeluk-pixel)*
