# Procurement Spend Governance & Analytics
**Power BI | Star Schema | Row-Level Security | Governed MI**

A governed Power BI solution for finance and procurement spend analytics — built to enterprise production standards with documented data lineage, role-based security and structured deployment thinking.

---

## Business Problem

Finance and Procurement teams need a trusted, auditable view of spend across suppliers, departments and cost categories. Without a governed model, spend reporting becomes fragmented, budget variance is unclear, and access control becomes a risk.

This solution addresses that by replacing ad-hoc reporting with a structured semantic model, clearly defined measures, role-based access and documented governance — so teams can independently explore spending patterns with confidence in the numbers.

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

Single-direction relationships from dimensions to fact. Foreign keys hidden from report layer. Measures isolated in a dedicated `_Measures` table.

![Model View](screenshots/Model%20View.jpg)

---

## Key Measures

| Measure | Purpose |
|---|---|
| Total Spend | Base measure — sum of invoice amounts |
| Budget Variance | Actual spend minus budget allocation |
| % Budget Variance | Normalised variance for cross-department comparison |
| PO Coverage Rate | Proportion of spend supported by purchase orders |
| Supplier Concentration % | Dependency on individual suppliers by spend share |
| Spend vs Prior Year | Year-over-year spend movement |

> **Known limitation:** BudgetAmount is a weekly allocation (annual budget ÷ 52 weeks). High % Budget Variance at headline level is expected — filter by department or supplier for actionable insight. This is documented in the governance notes and surfaced to report users.

---

## Row-Level Security

Two roles implemented with least-privilege design:

| Role | Filter | Access |
|---|---|---|
| `Department_User` | `[DepartmentName] = USERPRINCIPALNAME()` | Own cost centre only |
| `Finance` | `Dim_Supplier[Status] = "Active"` | All departments, active suppliers only |

RLS logic is intentionally simple to ensure it is auditable and testable. In production, role assignment would be managed through Entra ID security groups in Power BI Service.

![RLS — Department_User role](screenshots/Security%20Roles%201.jpg)
![RLS — Finance role](screenshots/Security%20Roles%202.jpg)

---

## Data Lineage

```
Source
└── Procurement transaction extract (CSV)
    └── Dataflow Gen2 input layer
        └── Power Query transformation (df_clean_spend)
            ├── Column typing and key validation
            ├── Removal of unused fields
            └── Star schema semantic model
                ├── 4 dimension tables
                ├── 1 fact table
                ├── Single-direction relationships
                └── Report layer
```

Transformation logic is documented in Power Query query steps and auditable in Fabric lineage view on promotion to a Fabric workspace.

---

## Report Pages

**Executive Overview**
KPI tiles — Total Spend, Budget Variance, % Budget Variance, Spend vs Prior Year. Total Spend trend by month. Spend by division breakdown.

**Supplier Analysis**
Spend by supplier with concentration %, PO coverage rate, budget variance and supplier tier. Category and tier filters for focused analysis.

---

## Production Approach

- Daily refresh at 06:00 GMT aligned to operational reporting cycle
- Dev/Test/Prod workspace deployment pipeline
- RLS tested in Power BI Service before release
- Spend and budget reconciliation checks before publication
- Certified semantic model for trusted spend reporting
- Governance contact and report version documented

---

## What This Demonstrates

- Star-schema semantic model design with conformed dimensions
- Governed data preparation using Power Query with documented transformation steps
- Row-Level Security with dynamic USERPRINCIPALNAME() and static supplier filter
- Dataflow Gen2 input layer with Fabric promotion readiness
- Data lineage documented from source to report layer
- Production deployment thinking — refresh, security, reconciliation, certification
- Finance and procurement domain knowledge including supplier concentration, PO coverage and budget variance analysis

---

## Related

[Group COO Operational Control MI](https://github.com/nishantgoeluk-pixel/group-coo-operational-control-dashboard) — multi-fact executive MI with RAG KPI logic, OKR tracking and exception-led leadership reporting.

---

*Nishant Goel — Senior BI Engineer | Power BI, Tableau, Microsoft Fabric*
*linkedin.com/in/nish-goel*
