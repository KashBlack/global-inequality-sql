# Global Inequality SQL Project

A SQL portfolio project demonstrating database design and complex query techniques using realistic sample data modeled after World Bank development indicators.

## What This Is

I wanted to practice SQL for data analysis work, so I built a normalized database and wrote 15 increasingly complex queries. The data is synthetic (I generated it with realistic distributions by region and income level), but the SQL techniques are real and applicable to actual World Bank data.

Think of this as a SQL skills demonstration rather than an economics project. The queries themselves are what matter here.

## What I Learned

- Database normalization and schema design
- Window functions (LAG, NTILE, ROW_NUMBER)
- CTEs and subqueries
- Multi-table JOINs
- Aggregations and pivoting
- Python data generation (made the sample data distributions realistic by region)

## Project Structure

```
global-inequality-sql/
├── schema.sql           # Database design (5 normalized tables)
├── load_data.py         # Python script to generate sample data
├── queries.sql          # 15 SQL queries of increasing complexity
├── outputs/             # Query results exported as CSV
│   └── Query 1-15.csv
└── global_inequality.db # SQLite database (created by load_data.py)
```

## Database Schema

Five tables designed for time-series analysis:

1. **country_metadata** - Country codes, regions, income classifications
2. **gdp_data** - GDP per capita and growth rates (2015-2023)
3. **inequality_metrics** - Gini coefficients, income shares
4. **poverty_indicators** - Poverty headcount ratios
5. **trade_education** - Trade openness, enrollment rates, education spending

All tables properly normalized with foreign keys, indexes, and constraints.

## Sample Queries

**Query 2: Year-over-year GDP growth using window functions**
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

**Query 7: Income group rankings with NTILE**
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
SELECT * FROM country_quartiles
WHERE gdp_quartile = 1 OR inequality_rank <= 3;
```

**Query 13: Composite inequality score with weighted metrics**

Creates a custom inequality index combining Gini coefficient (50% weight), poverty rate (30%), and income share (20%), then ranks countries into quintiles.

See [queries.sql](queries.sql) for all 15 queries with comments.

## SQL Techniques Demonstrated

| Technique | Queries |
|-----------|---------|
| Window functions (LAG, NTILE, ROW_NUMBER) | 2, 7, 12, 13, 14 |
| Common Table Expressions (CTEs) | 2, 4, 6, 10, 11, 12, 13 |
| Multi-table JOINs (3-4 tables) | 4, 9, 14, 15 |
| Subqueries | 1, 4, 6, 9 |
| Aggregations with GROUP BY | 3, 5, 8, 14, 15 |
| CASE statements for categorization | 5, 9, 10, 11, 12 |
| Pivoting with CASE/MAX | 8, 10, 11 |

## Running This Yourself

**Requirements:**
- Python 3.8+
- pandas
- sqlite3 (comes with Python)

**Setup:**
```bash
# Generate the database
python load_data.py

# Option 1: Use DB Browser for SQLite (recommended)
# Download from https://sqlitebrowser.org
# Open global_inequality.db
# Copy queries from queries.sql into the Execute SQL tab

# Option 2: Command line
sqlite3 global_inequality.db < queries.sql
```

The `outputs/` folder already has all query results as CSV files if you just want to see the outputs.

## About the Sample Data

The data is **completely synthetic** - I wrote a Python script that generates realistic distributions:

- **48 countries** across 6 World Bank regions
- **Gini coefficients** vary by region (Latin America: 45-55, Europe: 25-38, etc.)
- **GDP** assigned based on income group with realistic growth rates
- **COVID impact** modeled in 2020 (negative growth)
- **Time period:** 2015-2023

The distributions are based on actual patterns from World Bank data, but the specific numbers are random. This means:
- ✅ The SQL techniques are real and transferable
- ✅ The database design follows World Bank indicator structure
- ❌ Don't use this for actual economics research
- ❌ The "findings" aren't real - they're artifacts of my random number generator

If you want to use this with real data, just download the actual indicators from https://data.worldbank.org and modify `load_data.py` to load from CSV instead of generating random values.

## Why I Built This

I'm an econ student trying to break into data analytics. I wanted something more substantial than tutorial exercises, so I:
1. Studied the World Bank API structure
2. Designed a normalized database that could handle their indicators
3. Generated sample data with realistic constraints
4. Wrote increasingly complex queries to practice different SQL patterns

The goal was to demonstrate I can work with real-world data structures even if I don't have access to proprietary datasets yet.

## Known Issues

- The Python data generator uses hardcoded random ranges - would be better to fit distributions from actual data
- Some queries return NULL values where poverty data isn't generated (by design, only for low/middle income countries)
- No data validation beyond basic constraints
- Should probably add more years for better time-series analysis

## License

MIT - use this as needed

## Contact

Sricharan Chandrasekhar
- GitHub: [@KashBlack](https://github.com/KashBlack)
- Email: sricharan.chandrasekhar@gmail.com
- LinkedIn: [sricharan-chandrasekhar](https://www.linkedin.com/in/sricharan-chandrasekhar-41a98534a/)

---

**Data structure based on World Bank Open Data indicators**  
This is a portfolio project with synthetic data for SQL demonstration purposes.
