-- ============================================================================
-- SQLITE-COMPATIBLE QUERIES FOR GLOBAL INEQUALITY ANALYSIS
-- ============================================================================
-- Run these queries ONE AT A TIME in DB Browser's "Execute SQL" tab
-- Copy one query, paste, click Execute (▶️), then move to the next
-- ============================================================================

-- ============================================================================
-- QUERY 1: Top 10 Most Unequal Countries (Latest Year)
-- ============================================================================
SELECT 
    cm.country_name,
    cm.region,
    cm.income_group,
    im.year,
    im.gini_coefficient,
    im.income_share_lowest_20pct,
    im.income_share_highest_20pct,
    im.palma_ratio
FROM inequality_metrics im
JOIN country_metadata cm ON im.country_code = cm.country_code
WHERE im.year = (SELECT MAX(year) FROM inequality_metrics)
    AND im.gini_coefficient IS NOT NULL
ORDER BY im.gini_coefficient DESC
LIMIT 10;

-- ============================================================================
-- QUERY 2: Year-over-Year GDP Growth Rates Using Window Functions
-- ============================================================================
WITH gdp_with_previous AS (
    SELECT 
        cm.country_name,
        cm.region,
        gd.year,
        gd.gdp_per_capita_current_usd,
        LAG(gd.gdp_per_capita_current_usd, 1) OVER (
            PARTITION BY gd.country_code 
            ORDER BY gd.year
        ) AS previous_year_gdp
    FROM gdp_data gd
    JOIN country_metadata cm ON gd.country_code = cm.country_code
    WHERE gd.gdp_per_capita_current_usd IS NOT NULL
)
SELECT 
    country_name,
    region,
    year,
    ROUND(gdp_per_capita_current_usd, 0) AS gdp_per_capita,
    ROUND(previous_year_gdp, 0) AS previous_year_gdp,
    ROUND(
        ((gdp_per_capita_current_usd - previous_year_gdp) / previous_year_gdp) * 100, 
        2
    ) AS yoy_growth_pct
FROM gdp_with_previous
WHERE previous_year_gdp IS NOT NULL
    AND year >= 2020
ORDER BY country_name, year DESC;

-- ============================================================================
-- QUERY 3: Regional Average Inequality Trends (SQLite Compatible)
-- ============================================================================
SELECT 
    cm.region,
    im.year,
    ROUND(AVG(im.gini_coefficient), 2) AS avg_gini,
    COUNT(*) AS country_count,
    ROUND(MIN(im.gini_coefficient), 2) AS min_gini,
    ROUND(MAX(im.gini_coefficient), 2) AS max_gini
FROM inequality_metrics im
JOIN country_metadata cm ON im.country_code = cm.country_code
WHERE im.gini_coefficient IS NOT NULL
    AND im.year IN (2015, 2017, 2019, 2021, 2023)
GROUP BY cm.region, im.year
ORDER BY cm.region, im.year;

-- ============================================================================
-- QUERY 4: High Growth, Low Inequality Champions
-- ============================================================================
WITH recent_performance AS (
    SELECT 
        cm.country_code,
        cm.country_name,
        cm.region,
        AVG(gd.gdp_growth_annual_pct) AS avg_gdp_growth_5yr,
        im.gini_coefficient AS latest_gini,
        im.year AS gini_year
    FROM country_metadata cm
    JOIN gdp_data gd ON cm.country_code = gd.country_code
    LEFT JOIN inequality_metrics im ON cm.country_code = im.country_code
    WHERE gd.year BETWEEN 2018 AND 2023
        AND gd.gdp_growth_annual_pct IS NOT NULL
        AND im.year = (
            SELECT MAX(year) 
            FROM inequality_metrics im2 
            WHERE im2.country_code = cm.country_code
        )
    GROUP BY cm.country_code, cm.country_name, cm.region, im.gini_coefficient, im.year
)
SELECT 
    country_name,
    region,
    ROUND(avg_gdp_growth_5yr, 2) AS avg_growth_2018_2023,
    ROUND(latest_gini, 2) AS gini_coefficient,
    gini_year
FROM recent_performance
WHERE avg_gdp_growth_5yr > (SELECT AVG(avg_gdp_growth_5yr) FROM recent_performance)
    AND latest_gini < (SELECT AVG(latest_gini) FROM recent_performance)
ORDER BY avg_gdp_growth_5yr DESC, latest_gini ASC
LIMIT 15;

-- ============================================================================
-- QUERY 5: Education-Inequality Correlation Analysis
-- ============================================================================
SELECT 
    CASE 
        WHEN te.secondary_enrollment_rate >= 90 THEN 'High Enrollment (≥90%)'
        WHEN te.secondary_enrollment_rate >= 70 THEN 'Medium Enrollment (70-89%)'
        WHEN te.secondary_enrollment_rate >= 50 THEN 'Low Enrollment (50-69%)'
        ELSE 'Very Low Enrollment (<50%)'
    END AS education_category,
    COUNT(DISTINCT im.country_code) AS country_count,
    ROUND(AVG(im.gini_coefficient), 2) AS avg_gini,
    ROUND(AVG(te.secondary_enrollment_rate), 2) AS avg_enrollment_rate,
    ROUND(MIN(im.gini_coefficient), 2) AS min_gini,
    ROUND(MAX(im.gini_coefficient), 2) AS max_gini
FROM trade_education te
JOIN inequality_metrics im 
    ON te.country_code = im.country_code 
    AND te.year = im.year
WHERE te.secondary_enrollment_rate IS NOT NULL
    AND im.gini_coefficient IS NOT NULL
    AND te.year >= 2015
GROUP BY education_category
ORDER BY avg_enrollment_rate DESC;

-- ============================================================================
-- QUERY 6: Poverty Reduction Success Stories (2015-2023)
-- ============================================================================
SELECT 
    cm.country_name,
    cm.region,
    p1.year AS baseline_year,
    p2.year AS latest_year,
    ROUND(p1.poverty_headcount_215_pct, 2) AS poverty_rate_baseline,
    ROUND(p2.poverty_headcount_215_pct, 2) AS poverty_rate_latest,
    ROUND(p1.poverty_headcount_215_pct - p2.poverty_headcount_215_pct, 2) AS poverty_reduction_pct_points,
    ROUND(
        ((p1.poverty_headcount_215_pct - p2.poverty_headcount_215_pct) / 
         p1.poverty_headcount_215_pct) * 100, 
        1
    ) AS pct_reduction
FROM poverty_indicators p1
JOIN poverty_indicators p2 
    ON p1.country_code = p2.country_code
JOIN country_metadata cm 
    ON p1.country_code = cm.country_code
WHERE p1.year = 2015
    AND p2.year = (
        SELECT MAX(year) 
        FROM poverty_indicators p3 
        WHERE p3.country_code = p1.country_code
            AND p3.year >= 2020
    )
    AND p1.poverty_headcount_215_pct > 5
    AND p2.poverty_headcount_215_pct IS NOT NULL
ORDER BY poverty_reduction_pct_points DESC
LIMIT 20;

-- ============================================================================
-- QUERY 7: Income Group Rankings with NTILE
-- ============================================================================
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
    LEFT JOIN inequality_metrics im 
        ON cm.country_code = im.country_code 
        AND gd.year = im.year
    WHERE gd.year = (SELECT MAX(year) FROM gdp_data)
        AND cm.income_group != 'Aggregates'
        AND gd.gdp_per_capita_current_usd IS NOT NULL
)
SELECT 
    income_group,
    country_name,
    ROUND(gdp_per_capita_current_usd, 0) AS gdp_per_capita,
    gdp_quartile,
    ROUND(gini_coefficient, 2) AS gini,
    inequality_rank
FROM country_quartiles
WHERE gdp_quartile = 1 OR inequality_rank <= 3
ORDER BY income_group, gdp_per_capita DESC;

-- ============================================================================
-- QUERY 8: Gini Coefficient Pivot Table
-- ============================================================================
SELECT 
    cm.country_name,
    cm.region,
    MAX(CASE WHEN im.year = 2015 THEN im.gini_coefficient END) AS gini_2015,
    MAX(CASE WHEN im.year = 2017 THEN im.gini_coefficient END) AS gini_2017,
    MAX(CASE WHEN im.year = 2019 THEN im.gini_coefficient END) AS gini_2019,
    MAX(CASE WHEN im.year = 2021 THEN im.gini_coefficient END) AS gini_2021,
    MAX(CASE WHEN im.year = 2023 THEN im.gini_coefficient END) AS gini_2023,
    ROUND(
        MAX(CASE WHEN im.year = 2023 THEN im.gini_coefficient END) - 
        MAX(CASE WHEN im.year = 2015 THEN im.gini_coefficient END),
        2
    ) AS gini_change_2015_2023
FROM country_metadata cm
JOIN inequality_metrics im ON cm.country_code = im.country_code
WHERE im.year IN (2015, 2017, 2019, 2021, 2023)
GROUP BY cm.country_name, cm.region
HAVING COUNT(DISTINCT im.year) >= 3
ORDER BY ABS(gini_change_2015_2023) DESC
LIMIT 25;

-- ============================================================================
-- QUERY 9: Compare Countries Against Global Medians (Simplified)
-- ============================================================================
WITH country_latest AS (
    SELECT 
        cm.country_code,
        cm.country_name,
        cm.region,
        gd.gdp_per_capita_current_usd,
        im.gini_coefficient
    FROM country_metadata cm
    LEFT JOIN gdp_data gd ON cm.country_code = gd.country_code
    LEFT JOIN inequality_metrics im 
        ON cm.country_code = im.country_code 
        AND gd.year = im.year
    WHERE gd.year = (SELECT MAX(year) FROM gdp_data)
),
global_averages AS (
    SELECT 
        AVG(gdp_per_capita_current_usd) AS avg_gdp,
        AVG(gini_coefficient) AS avg_gini
    FROM country_latest
    WHERE gdp_per_capita_current_usd IS NOT NULL
        AND gini_coefficient IS NOT NULL
)
SELECT 
    cl.country_name,
    cl.region,
    ROUND(cl.gdp_per_capita_current_usd, 0) AS gdp_per_capita,
    ROUND(cl.gini_coefficient, 2) AS gini,
    ROUND(ga.avg_gdp, 0) AS global_avg_gdp,
    ROUND(ga.avg_gini, 2) AS global_avg_gini,
    CASE 
        WHEN cl.gdp_per_capita_current_usd > ga.avg_gdp THEN 'Above Average'
        ELSE 'Below Average'
    END AS gdp_vs_global,
    CASE 
        WHEN cl.gini_coefficient > ga.avg_gini THEN 'More Unequal'
        ELSE 'Less Unequal'
    END AS inequality_vs_global
FROM country_latest cl
CROSS JOIN global_averages ga
WHERE cl.gdp_per_capita_current_usd IS NOT NULL
    AND cl.gini_coefficient IS NOT NULL
ORDER BY cl.gdp_per_capita_current_usd DESC;

-- ============================================================================
-- QUERY 10: Trade Openness vs. Inequality Change (2015-2023)
-- ============================================================================
WITH trade_change AS (
    SELECT 
        country_code,
        MAX(CASE WHEN year = 2015 THEN trade_pct_gdp END) AS trade_2015,
        MAX(CASE WHEN year = 2023 THEN trade_pct_gdp END) AS trade_2023
    FROM trade_education
    WHERE year IN (2015, 2023)
    GROUP BY country_code
),
inequality_change AS (
    SELECT 
        country_code,
        MAX(CASE WHEN year = 2015 THEN gini_coefficient END) AS gini_2015,
        MAX(CASE WHEN year = 2023 THEN gini_coefficient END) AS gini_2023
    FROM inequality_metrics
    WHERE year IN (2015, 2023)
    GROUP BY country_code
)
SELECT 
    cm.country_name,
    cm.region,
    ROUND(tc.trade_2015, 1) AS trade_openness_2015,
    ROUND(tc.trade_2023, 1) AS trade_openness_2023,
    ROUND(tc.trade_2023 - tc.trade_2015, 1) AS trade_change,
    ROUND(ic.gini_2015, 2) AS gini_2015,
    ROUND(ic.gini_2023, 2) AS gini_2023,
    ROUND(ic.gini_2023 - ic.gini_2015, 2) AS gini_change,
    CASE 
        WHEN tc.trade_2023 > tc.trade_2015 AND ic.gini_2023 < ic.gini_2015 
            THEN 'Trade↑ Inequality↓'
        WHEN tc.trade_2023 > tc.trade_2015 AND ic.gini_2023 > ic.gini_2015 
            THEN 'Trade↑ Inequality↑'
        WHEN tc.trade_2023 < tc.trade_2015 AND ic.gini_2023 < ic.gini_2015 
            THEN 'Trade↓ Inequality↓'
        ELSE 'Trade↓ Inequality↑'
    END AS pattern
FROM country_metadata cm
JOIN trade_change tc ON cm.country_code = tc.country_code
JOIN inequality_change ic ON cm.country_code = ic.country_code
WHERE tc.trade_2015 IS NOT NULL 
    AND tc.trade_2023 IS NOT NULL
    AND ic.gini_2015 IS NOT NULL 
    AND ic.gini_2023 IS NOT NULL
ORDER BY ABS(ic.gini_2023 - ic.gini_2015) DESC
LIMIT 30;

-- ============================================================================
-- QUERY 11: Post-Pandemic Recovery Analysis (2019 vs. 2023)
-- ============================================================================
WITH pandemic_comparison AS (
    SELECT 
        cm.country_code,
        cm.country_name,
        cm.region,
        MAX(CASE WHEN gd.year = 2019 THEN gd.gdp_per_capita_current_usd END) AS gdp_2019,
        MAX(CASE WHEN gd.year = 2020 THEN gd.gdp_per_capita_current_usd END) AS gdp_2020,
        MAX(CASE WHEN gd.year = 2023 THEN gd.gdp_per_capita_current_usd END) AS gdp_2023,
        MAX(CASE WHEN im.year = 2019 THEN im.gini_coefficient END) AS gini_2019,
        MAX(CASE WHEN im.year = 2023 THEN im.gini_coefficient END) AS gini_2023
    FROM country_metadata cm
    LEFT JOIN gdp_data gd ON cm.country_code = gd.country_code
    LEFT JOIN inequality_metrics im ON cm.country_code = im.country_code
    WHERE gd.year IN (2019, 2020, 2023) OR im.year IN (2019, 2023)
    GROUP BY cm.country_code, cm.country_name, cm.region
)
SELECT 
    country_name,
    region,
    ROUND(gdp_2019, 0) AS gdp_pre_pandemic,
    ROUND(gdp_2023, 0) AS gdp_2023,
    ROUND(((gdp_2023 - gdp_2019) / gdp_2019) * 100, 2) AS gdp_recovery_pct,
    ROUND(gini_2019, 2) AS gini_pre_pandemic,
    ROUND(gini_2023, 2) AS gini_2023,
    ROUND(gini_2023 - gini_2019, 2) AS gini_change,
    CASE 
        WHEN gdp_2023 > gdp_2019 * 1.05 THEN 'Strong Recovery'
        WHEN gdp_2023 > gdp_2019 THEN 'Moderate Recovery'
        WHEN gdp_2023 > gdp_2019 * 0.95 THEN 'Stagnant'
        ELSE 'Decline'
    END AS recovery_status
FROM pandemic_comparison
WHERE gdp_2019 IS NOT NULL 
    AND gdp_2023 IS NOT NULL
ORDER BY gdp_recovery_pct DESC;

-- ============================================================================
-- QUERY 12: Convergence Analysis - Are Poor Countries Catching Up?
-- ============================================================================
WITH baseline_and_growth AS (
    SELECT 
        cm.country_code,
        cm.country_name,
        cm.region,
        gd1.gdp_per_capita_current_usd AS gdp_2015,
        gd2.gdp_per_capita_current_usd AS gdp_2023,
        ROUND(
            (POWER(
                (gd2.gdp_per_capita_current_usd / gd1.gdp_per_capita_current_usd),
                (1.0 / 8)
            ) - 1) * 100, 
            2
        ) AS cagr_2015_2023
    FROM country_metadata cm
    JOIN gdp_data gd1 ON cm.country_code = gd1.country_code AND gd1.year = 2015
    JOIN gdp_data gd2 ON cm.country_code = gd2.country_code AND gd2.year = 2023
    WHERE gd1.gdp_per_capita_current_usd IS NOT NULL
        AND gd2.gdp_per_capita_current_usd IS NOT NULL
        AND gd1.gdp_per_capita_current_usd > 500
)
SELECT 
    country_name,
    region,
    ROUND(gdp_2015, 0) AS gdp_per_capita_2015,
    ROUND(gdp_2023, 0) AS gdp_per_capita_2023,
    cagr_2015_2023 AS avg_annual_growth_pct,
    CASE 
        WHEN gdp_2015 < 5000 THEN 'Low Income 2015'
        WHEN gdp_2015 < 15000 THEN 'Middle Income 2015'
        ELSE 'High Income 2015'
    END AS income_category_2015,
    RANK() OVER (ORDER BY cagr_2015_2023 DESC) AS growth_rank
FROM baseline_and_growth
ORDER BY cagr_2015_2023 DESC
LIMIT 40;

-- ============================================================================
-- QUERY 13: Multidimensional Inequality Index
-- ============================================================================
WITH metrics_2023 AS (
    SELECT 
        cm.country_code,
        cm.country_name,
        cm.region,
        im.gini_coefficient,
        COALESCE(pi.poverty_headcount_215_pct, 0) AS poverty_rate,
        COALESCE(im.income_share_lowest_20pct, 10) AS income_share_bottom
    FROM country_metadata cm
    LEFT JOIN inequality_metrics im 
        ON cm.country_code = im.country_code AND im.year = 2023
    LEFT JOIN poverty_indicators pi 
        ON cm.country_code = pi.country_code AND pi.year = 2023
    WHERE im.gini_coefficient IS NOT NULL
),
normalized AS (
    SELECT 
        *,
        (gini_coefficient - (SELECT MIN(gini_coefficient) FROM metrics_2023)) /
        ((SELECT MAX(gini_coefficient) FROM metrics_2023) - (SELECT MIN(gini_coefficient) FROM metrics_2023)) * 100 
            AS gini_normalized,
        poverty_rate AS poverty_normalized,
        (50 - income_share_bottom) / 40 * 100 AS income_share_normalized
    FROM metrics_2023
)
SELECT 
    country_name,
    region,
    ROUND(gini_coefficient, 2) AS gini,
    ROUND(poverty_rate, 2) AS poverty_rate,
    ROUND(income_share_bottom, 2) AS income_share_bottom_20pct,
    ROUND(
        (gini_normalized * 0.5 + poverty_normalized * 0.3 + income_share_normalized * 0.2),
        1
    ) AS composite_inequality_score,
    NTILE(5) OVER (
        ORDER BY (gini_normalized * 0.5 + poverty_normalized * 0.3 + income_share_normalized * 0.2)
    ) AS inequality_quintile
FROM normalized
ORDER BY composite_inequality_score DESC
LIMIT 30;

-- ============================================================================
-- QUERY 14: Government Education Spending and Inequality Outcomes
-- ============================================================================
WITH spending_quartiles AS (
    SELECT 
        te.country_code,
        te.government_expenditure_education_pct,
        NTILE(4) OVER (ORDER BY te.government_expenditure_education_pct) AS spending_quartile
    FROM trade_education te
    WHERE te.year = 2023
        AND te.government_expenditure_education_pct IS NOT NULL
)
SELECT 
    sq.spending_quartile,
    CASE sq.spending_quartile
        WHEN 1 THEN 'Lowest 25%'
        WHEN 2 THEN 'Low-Medium 25%'
        WHEN 3 THEN 'Medium-High 25%'
        WHEN 4 THEN 'Highest 25%'
    END AS spending_category,
    COUNT(DISTINCT sq.country_code) AS country_count,
    ROUND(AVG(sq.government_expenditure_education_pct), 2) AS avg_edu_spending_pct_gdp,
    ROUND(AVG(im.gini_coefficient), 2) AS avg_gini,
    ROUND(AVG(pi.poverty_headcount_215_pct), 2) AS avg_poverty_rate,
    ROUND(AVG(te.secondary_enrollment_rate), 2) AS avg_secondary_enrollment
FROM spending_quartiles sq
JOIN trade_education te ON sq.country_code = te.country_code AND te.year = 2023
LEFT JOIN inequality_metrics im ON sq.country_code = im.country_code AND im.year = 2023
LEFT JOIN poverty_indicators pi ON sq.country_code = pi.country_code AND pi.year = 2023
GROUP BY sq.spending_quartile
ORDER BY sq.spending_quartile;

-- ============================================================================
-- QUERY 15: Data Completeness Report
-- ============================================================================
SELECT 
    cm.region,
    COUNT(DISTINCT cm.country_code) AS total_countries,
    SUM(CASE WHEN gd.gdp_per_capita_current_usd IS NOT NULL THEN 1 ELSE 0 END) AS gdp_data_available,
    ROUND(
        100.0 * SUM(CASE WHEN gd.gdp_per_capita_current_usd IS NOT NULL THEN 1 ELSE 0 END) / 
        COUNT(DISTINCT cm.country_code), 
        1
    ) AS gdp_coverage_pct,
    SUM(CASE WHEN im.gini_coefficient IS NOT NULL THEN 1 ELSE 0 END) AS gini_data_available,
    ROUND(
        100.0 * SUM(CASE WHEN im.gini_coefficient IS NOT NULL THEN 1 ELSE 0 END) / 
        COUNT(DISTINCT cm.country_code), 
        1
    ) AS gini_coverage_pct,
    SUM(CASE WHEN pi.poverty_headcount_215_pct IS NOT NULL THEN 1 ELSE 0 END) AS poverty_data_available,
    ROUND(
        100.0 * SUM(CASE WHEN pi.poverty_headcount_215_pct IS NOT NULL THEN 1 ELSE 0 END) / 
        COUNT(DISTINCT cm.country_code), 
        1
    ) AS poverty_coverage_pct
FROM country_metadata cm
LEFT JOIN gdp_data gd ON cm.country_code = gd.country_code AND gd.year = 2023
LEFT JOIN inequality_metrics im ON cm.country_code = im.country_code AND im.year = 2023
LEFT JOIN poverty_indicators pi ON cm.country_code = pi.country_code AND pi.year = 2023
WHERE cm.region != 'Aggregates'
GROUP BY cm.region
ORDER BY gini_coverage_pct DESC;