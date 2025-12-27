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



