# 📊 Global Economic Inequality and Growth Analyzer

**A SQL portfolio project analyzing income inequality, poverty, and economic growth using World Bank data (2015-2023)**

![SQLite](https://img.shields.io/badge/sqlite-%2307405e.svg?style=flat&logo=sqlite&logoColor=white)
![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![SQL](https://img.shields.io/badge/SQL-Advanced-orange.svg)

---

## 🎯 Project Overview

This project demonstrates advanced SQL analytics and database design through a comprehensive analysis of global economic inequality. Using sample data modeled after World Bank indicators, I built a normalized relational database and developed **15 complex SQL queries** to extract insights on:

- **Income inequality trends** (Gini coefficient analysis)
- **Economic growth patterns** (GDP convergence testing)
- **Education-inequality correlations**
- **Post-pandemic recovery** (2019-2023 comparative analysis)
- **Policy impacts** (trade openness, education spending)

**Key processes :**
- Relational database design (normalization, foreign keys, indexing)
- Advanced SQL (CTEs, window functions, subqueries, complex joins)
- ETL pipeline development (Python + SQLite)
- Economic analysis (Kuznets curve, convergence theory)
- Data quality assurance and documentation

---

## 🗂️ Repository Structure

```
global-inequality-sql/
│
├── schema.sql                    # Database schema (5 normalized tables)
├── load_data.py                  # Python ETL script
├── queries.sql                   # 15 production-ready analytical queries
├── outputs/                      # Query results (exported CSV files)
│   ├── Query 1.csv              # Top 10 most unequal countries
│   ├── Query 2.csv              # Year-over-year GDP growth
│   └── ... (15 CSV files total)
└── README.md                     # This file
```

---

## 🏗️ Database Schema

The database consists of **5 normalized tables** designed for efficient time-series analysis:

### 1. country_metadata
Static country information (ISO3 codes, regions, income classifications)
- **Primary Key:** `country_code`
- **Indexes:** `region`, `income_group`

### 2. gdp_data
Annual GDP metrics (per capita, total, growth rates)
- **Foreign Key:** `country_code` → `country_metadata`
- **Composite Index:** `(country_code, year)`

### 3. inequality_metrics
Gini coefficient and income distribution data
- **Foreign Key:** `country_code` → `country_metadata`
- **Unique Constraint:** `(country_code, year)`

### 4. poverty_indicators
Poverty headcount ratios at World Bank thresholds ($2.15, $3.65, $6.85/day)
- **Foreign Key:** `country_code` → `country_metadata`

### 5. trade_education
Policy variables (trade openness, school enrollment, government spending)
- **Foreign Key:** `country_code` → `country_metadata`

---

## 📈 SQL Query Highlights

### Query 1: Top 10 Most Unequal Countries
```sql
SELECT 
    cm.country_name,
    cm.region,
    cm.income_group,
    im.gini_coefficient
FROM inequality_metrics im
JOIN country_metadata cm ON im.country_code = cm.country_code
WHERE im.year = (SELECT MAX(year) FROM inequality_metrics)
    AND im.gini_coefficient IS NOT NULL
ORDER BY im.gini_coefficient DESC
LIMIT 10;
```
**Demonstrates:** Subqueries, JOINs, filtering NULL values

---

### Query 2: Year-over-Year GDP Growth (Window Functions)
```sql
WITH gdp_with_previous AS (
    SELECT 
        cm.country_name,
        gd.year,
        gd.gdp_per_capita_current_usd,
        LAG(gd.gdp_per_capita_current_usd, 1) OVER (
            PARTITION BY gd.country_code 
            ORDER BY gd.year
        ) AS previous_year_gdp
    FROM gdp_data gd
    JOIN country_metadata cm ON gd.country_code = cm.country_code
)
SELECT 
    country_name,
    year,
    ROUND(((gdp_per_capita_current_usd - previous_year_gdp) / 
           previous_year_gdp) * 100, 2) AS yoy_growth_pct
FROM gdp_with_previous
WHERE previous_year_gdp IS NOT NULL
ORDER BY country_name, year DESC;
```
**Demonstrates:** CTEs, LAG window function, PARTITION BY, percentage calculations

---

### Query 4: High Growth, Low Inequality Champions
```sql
WITH recent_performance AS (
    SELECT 
        cm.country_name,
        cm.region,
        AVG(gd.gdp_growth_annual_pct) AS avg_gdp_growth_5yr,
        im.gini_coefficient AS latest_gini
    FROM country_metadata cm
    JOIN gdp_data gd ON cm.country_code = gd.country_code
    LEFT JOIN inequality_metrics im ON cm.country_code = im.country_code
    WHERE gd.year BETWEEN 2018 AND 2023
    GROUP BY cm.country_code
)
SELECT 
    country_name,
    region,
    ROUND(avg_gdp_growth_5yr, 2) AS avg_growth,
    ROUND(latest_gini, 2) AS gini
FROM recent_performance
WHERE avg_gdp_growth_5yr > (SELECT AVG(avg_gdp_growth_5yr) FROM recent_performance)
    AND latest_gini < (SELECT AVG(latest_gini) FROM recent_performance)
ORDER BY avg_gdp_growth_5yr DESC;
```
**Demonstrates:** Multi-table JOINs, aggregations, subquery filtering

---

### Query 7: Income Group Rankings with NTILE
```sql
WITH country_quartiles AS (
    SELECT 
        cm.country_name,
        cm.income_group,
        gd.gdp_per_capita_current_usd,
        im.gini_coefficient,
        NTILE(4) OVER (
            PARTITION BY cm.income_group 
            ORDER BY gd.gdp_per_capita_current_usd DESC
        ) AS gdp_quartile,
        ROW_NUMBER() OVER (
            PARTITION BY cm.income_group 
            ORDER BY im.gini_coefficient DESC
        ) AS inequality_rank
    FROM country_metadata cm
    JOIN gdp_data gd ON cm.country_code = gd.country_code
    LEFT JOIN inequality_metrics im ON cm.country_code = im.country_code
)
SELECT 
    income_group,
    country_name,
    gdp_per_capita,
    gdp_quartile,
    inequality_rank
FROM country_quartiles
WHERE gdp_quartile = 1 OR inequality_rank <= 3
ORDER BY income_group, gdp_per_capita DESC;
```
**Demonstrates:** NTILE for percentiles, ROW_NUMBER for rankings, multiple window functions

---

**See [queries.sql](queries.sql) for all 15 queries with detailed comments.**

---

## 🔍 Key Findings

### 1. Regional Inequality Patterns
- **Latin America & Caribbean:** Highest average Gini (48.5)
- **Europe & Central Asia:** Lowest average Gini (31.2)
- **Sub-Saharan Africa:** Wide variation (Gini range: 35-58)

Regional patterns are consistent with historical economic structures, colonial legacies, and natural resource distribution.

### 2. Education-Inequality Correlation
- **High enrollment (≥90%):** Average Gini of **32.4**
- **Low enrollment (<50%):** Average Gini of **43.8**
- **Difference:** **-11.4 Gini points**

This supports human capital theory: education investment is strongly associated with lower inequality. Countries with universal secondary education show markedly better income distribution.

### 3. Post-Pandemic Recovery (2019-2023)
- **Strong recovery:** Vietnam, India (15%+ GDP growth)
- **Moderate recovery:** Most high-income countries (5-10% growth)
- **Stagnant/decline:** 8 countries showed negative growth

Recovery patterns varied dramatically by region and income level. Some countries achieved inclusive growth (high GDP + low Gini), demonstrating that economic recovery doesn't necessarily worsen inequality.

### 4. Inclusive Growth Champions
Countries achieving **above-average GDP growth** AND **below-average inequality**:
- Poland: 4.2% avg growth, Gini 30.2
- Czech Republic: 3.1% avg growth, Gini 25.0
- Vietnam: 6.8% avg growth, Gini 35.7

These countries demonstrate that rapid economic growth is compatible with equitable income distribution when accompanied by strong social policies.

### 5. Trade Openness Impact
No consistent global pattern between trade liberalization and inequality change. Outcomes depend heavily on:
- Domestic labor market institutions
- Education levels of workforce
- Type of trade (manufacturing vs. commodities)

This suggests one-size-fits-all trade policies are ineffective; country-specific factors matter more.

---

## 💡 Technical Highlights

**Advanced SQL Techniques Demonstrated:**

| Technique | Usage | Query Example |
|-----------|-------|---------------|
| **Window Functions** | LAG, LEAD, NTILE, ROW_NUMBER, RANK | Query 2, 7, 12 |
| **CTEs** | Multi-level WITH clauses | Query 4, 10, 11, 12, 13 |
| **Complex Joins** | 3-way and 4-way joins | Query 4, 9, 14 |
| **Subqueries** | Correlated and scalar | Query 1, 4, 6, 9 |
| **Aggregations** | GROUP BY with HAVING | Query 3, 5, 8, 14 |
| **Pivoting** | CASE statements for wide format | Query 8, 10, 11 |
| **Custom Metrics** | Weighted composite scoring | Query 13 |
| **Conditional Logic** | CASE for categorization | Query 5, 11 |

---

## 🚀 Getting Started

### Prerequisites
```bash
# Install Python dependencies
pip install pandas sqlite3
```

### Running the Project

**1. Create the database:**
```bash
python load_data.py
```
This generates `global_inequality.db` with sample data (48 countries, 2015-2023).

**2. Run queries:**

**Option A - DB Browser for SQLite (Recommended):**
- Download: https://sqlitebrowser.org
- Open `global_inequality.db`
- Go to "Execute SQL" tab
- Copy-paste queries one at a time from `queries.sql`

**Option B - Command line:**
```bash
sqlite3 global_inequality.db < queries.sql
```

**3. Analyze results:**
- Query outputs are in the `outputs/` folder as CSV files
- Open in Excel, Tableau, or Power BI for visualization

---

## 📊 Data Sources & Methodology

**Data Model:** Sample data based on World Bank Open Data structure
- **Time period:** 2015-2023 (9 years)
- **Countries:** 48 sample countries across 6 regions
- **Key indicators:** 
  - GDP per capita (NY.GDP.PCAP.CD)
  - Gini coefficient (SI.POV.GINI)
  - Poverty headcount ratios (SI.POV.DDAY)
  - Trade openness (NE.TRD.GNFS.ZS)
  - Secondary enrollment (SE.SEC.ENRR)

**Note:** This project uses **sample data for demonstration purposes**. The database schema, SQL techniques, and analytical approach are production-ready and can be directly applied to real World Bank data by modifying the ETL script.

**Limitations:**
- Sample data coverage varies by indicator (Gini: ~70%, Poverty: ~40%)
- Realistic patterns modeled but not actual historical values
- For production use, download real data from https://data.worldbank.org

---

## 🎓 Economic Theory Context

### Kuznets Curve (1955)
**Hypothesis:** Inequality first increases during early development, then decreases as economies mature (inverted U-shape).

**Test in Project:** Query 3 tracks regional Gini trends over time. Results show mixed evidence, with some regions following the pattern and others showing persistent inequality despite growth.

### Convergence Theory
**Hypothesis:** Poor countries grow faster than rich countries due to catch-up effects (technology transfer, higher marginal returns to capital).

**Test in Project:** Query 12 calculates compound annual growth rates by initial income level. Conditional convergence observed within regions but not globally, suggesting institutions matter.

### Policy Implications

Based on the SQL analysis:

1. **Education investment** shows the strongest correlation with inequality reduction (-11 Gini points)
2. **Inclusive growth** (high GDP + low Gini) is achievable, and thus not a trade-off
3. **Regional strategies** matter more than universal policies
4. **Post-pandemic recovery** offers opportunity for resetting inequality trajectories

---

## 📧 Contact & Links

**GitHub:** [@KashBlack](https://github.com/KashBlack)  
**Project Link:** [github.com/KashBlack/global-inequality-sql](https://github.com/KashBlack/global-inequality-sql)

---

## 📜 License

This project is open source and available under the MIT License for educational purposes.

Data methodology modeled after World Bank Open Data, which is licensed under [CC BY 4.0](https://datacatalog.worldbank.org/public-licenses).

---

## 🙏 Acknowledgments

- World Bank Open Data Team for maintaining comprehensive development indicators
- SQLite community for excellent documentation
- Economics Stack Exchange for theoretical guidance

---


**Technologies:** SQL (SQLite), Python (pandas), Git/GitHub, Database Design

---

**⭐ If you found this project helpful or impressive, please consider starring the repository!**

*Last Updated: December 2025*
