# Procurement Spend Governance & Analytics
**Power BI | Star Schema | Row-Level Security | Governed MI**

A governed Power BI solution for finance and procurement spend analytics — 
built to enterprise production standards with documented data lineage, 
role-based security and a structured Dev/Test/Prod deployment pipeline.

---

## Business Problem

Finance and Procurement teams need a trusted, auditable view of spend 
across suppliers, departments and cost categories. Without a governed model, 
spend reporting becomes fragmented, budget variance is unclear, and access 
control becomes a risk.

This solution addresses that by replacing ad-hoc reporting with a structured 
semantic model, clearly defined measures, role-based access and documented 
governance — so teams can independently explore spending patterns with 
confidence in the numbers.

---

## Model Design

Classic star schema with a single fact table and four conformed dimensions.

| Layer | Table | Purpose |
|---|---|---|
| Fact | `df_clean_spend` | Transaction-level spend, budget, variance, PO and approval detail |
| Dimension | `Dim_Date` | Consistent time filtering — fiscal year, quarter, month, week |
| Dimension | `Dim_Supplier` | Supplier name, tier, category, contract expiry, preferred status |
| Dimension | `Dim_Department` | Department, division, location, cost centre head, annual budget |
| Dimension | `Dim_CostCategory` | Category name, budget type, spend type |

Single-direction relationships from dimensions to fact. Foreign keys hidden 
from report layer. Measures isolated in a dedicated `_Measures` table.

![Model View](screenshots/Model%20View.jpg)

---

## Key Measures

| Measure | Business Definition | DAX Logic Summary | Source Table | Consumer Duty Relevant |
|---|---|---|---|---|
| Total Spend | Sum of all invoiced spend within the selected period | `SUM(df_clean_spend[InvoiceAmount])` | df_clean_spend | Yes — baseline spend visibility for fair value assessment |
| Budget Variance | Actual spend minus allocated budget | `[Total Spend] - SUM(df_clean_spend[BudgetAmount])` | df_clean_spend | Yes — evidences budgetary control and accountability |
| % Budget Variance | Variance normalised as percentage of budget — enables cross-department comparison | `DIVIDE([Budget Variance], SUM(df_clean_spend[BudgetAmount]))` | df_clean_spend | Yes — supports proportionate outcome monitoring |
| PO Coverage Rate | Proportion of spend supported by a raised purchase order | `DIVIDE(CALCULATE([Total Spend], df_clean_spend[POFlag] = "Y"), [Total Spend])` | df_clean_spend | Yes — demonstrates process control and auditability |
| Supplier Concentration % | Percentage of total spend attributable to a single supplier | `DIVIDE([Total Spend], CALCULATE([Total Spend], ALL(Dim_Supplier)))` | df_clean_spend, Dim_Supplier | Yes — supports fair value and third-party risk oversight |
| Spend vs Prior Year | Year-over-year movement in total spend | `[Total Spend] - CALCULATE([Total Spend], SAMEPERIODLASTYEAR(Dim_Date[Date]))` | df_clean_spend, Dim_Date | No — trend indicator, not directly linked to Consumer Duty obligations |

> **Known data limitation:** BudgetAmount is a weekly allocation (annual 
> budget ÷ 52 weeks). High % Budget Variance at headline level is expected 
> — filter by Department or Supplier for actionable insight. This limitation 
> is documented in the Governance Notes page and disclosed to all report 
> users as part of governed MI standards.

---

## Row-Level Security

Two roles implemented with least-privilege design:

| Role | Filter | Access Scope | Managed Via |
|---|---|---|---|
| `Department_User` | `[DepartmentName] = USERPRINCIPALNAME()` | Own cost centre only | Entra ID security group assignment in Power BI Service |
| `Finance` | `Dim_Supplier[Status] = "Active"` | All departments, active suppliers only | Entra ID security group assignment in Power BI Service |

RLS logic is intentionally simple to ensure it is auditable and testable. 
Role assignment is managed through Entra ID security groups in Power BI 
Service — not individual user assignment.

![RLS — Department_User role](screenshots/Security%20Roles%201.jpg)
![RLS — Finance role](screenshots/Security%20Roles%202.jpg)

---

## Data Lineage

Source → procurement transaction extract (CSV) → Power Query transformation 
layer → df_clean_spend (fact table) → Star schema semantic model → 
Promoted semantic model (Procurement-Spend-PROD) → Report layer

Transformation logic is documented in Power Query query steps. Lineage is 
auditable via the Fabric lineage view in the Production workspace.

![Lineage View](screenshots/Lineage%20view.jpg)

---

## Deployment Architecture

This solution is deployed using a structured three-stage pipeline in 
Microsoft Fabric, reflecting enterprise CI/CD governance principles.

| Stage | Workspace | Purpose |
|---|---|---|
| Development | `Procurement-Spend-DEV` | Active development and iteration |
| Test | `Procurement-Spend-DEV [Test]` | Pre-production validation |
| Production | `Procurement-Spend-PROD` | Governed, promoted semantic model — live reporting |

- Deployment pipeline: `Procurement-Spend-Pipeline`
- Deployments tracked with timestamp, deployer identity and item count 
via Fabric Deployment History
- Semantic model endorsed as **Promoted** in Production workspace
- Refresh schedule designed for daily 06:00 GMT execution — 
pending migration of source files to cloud-accessible storage

![Pipeline View](screenshots/Pipeline%20view.jpg)
![Deployment History](screenshots/Deployment%20history.jpg)
![DEV Workspace](screenshots/Procurement-Spend-DEV%20workspace.jpg)
![PROD Workspace](screenshots/Procurement-Spend-PROD%20workspace.jpg)
![Endorsed Semantic Model](screenshots/Endorsed%20semantic%20model.jpg)

---

## Report Pages

**Page 1 — Executive Overview**  
KPI tiles — Total Spend, Budget Variance, % Budget Variance, Spend vs 
Prior Year. Total Spend trend by month. Spend by division breakdown.

![Executive Overview](screenshots/Report%20View.jpg)

**Page 2 — Supplier Analysis**  
Spend by supplier with concentration %, PO coverage rate, budget variance 
and supplier tier. Category and tier filters for focused analysis.

![Supplier Analysis](screenshots/Supplier%20Analysis.jpg)

**Page 3 — Governance Notes**  
Workspace architecture, data lineage overview, deployment pipeline summary, 
access control design, known data limitations and version governance.

---

## Production Approach

- Three-stage deployment pipeline (Dev → Test → Prod) with full 
deployment history showing timestamp and deployer identity
- Promoted semantic model in Production workspace for trusted reporting
- RLS tested in Power BI Service before promotion to Production
- Spend and budget reconciliation checks before publication
- Known data limitations documented and disclosed to report users
- Governance contact and report version documented on Page 3

---

## What This Demonstrates

- Star-schema semantic model design with conformed dimensions
- Governed data preparation using Power Query with documented 
transformation steps
- Row-Level Security with dynamic `USERPRINCIPALNAME()` and static 
supplier filter — managed via Entra ID groups
- Fabric deployment pipeline with Dev/Test/Prod governance and 
auditable deployment history
- Promoted semantic model with documented lineage from source to 
report layer — visible in Fabric lineage view
- Consumer Duty relevance mapping across all core KPIs
- Production deployment thinking — pipeline governance, security, 
reconciliation and version control
- Finance and procurement domain knowledge including supplier 
concentration, PO coverage and budget variance analysis

---

## Related

[Group COO Operational Control MI](https://github.com/nishantgoeluk-pixel/group-coo-operational-control-dashboard) 
— multi-fact executive MI with RAG KPI logic, OKR tracking and 
exception-led leadership reporting.

---

*Nishant Goel — Senior BI Engineer | Power BI, Tableau, Microsoft Fabric*  
*linkedin.com/in/nish-goel*
