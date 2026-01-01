
-- GLOBAL ECONOMIC INEQUALITY AND GROWTH ANALYZER - DATABASE SCHEMA


-- Drop existing tables (for clean setup)
DROP TABLE IF EXISTS poverty_indicators;
DROP TABLE IF EXISTS inequality_metrics;
DROP TABLE IF EXISTS gdp_data;
DROP TABLE IF EXISTS trade_education;
DROP TABLE IF EXISTS country_metadata;


-- TABLE 1: COUNTRY METADATA

-- Stores static country information and regional classifications
CREATE TABLE country_metadata (
    country_code CHAR(3) PRIMARY KEY,  -- ISO3 code (USA, GBR, etc.)
    country_name VARCHAR(100) NOT NULL,
    region VARCHAR(50),                 -- e.g., Sub-Saharan Africa, Europe & Central Asia
    income_group VARCHAR(50),           -- e.g., High income, Upper middle income
    population_2023 BIGINT,             -- Latest population for normalization
    CONSTRAINT chk_country_code CHECK (LENGTH(country_code) = 3)
);

-- Index for regional queries
CREATE INDEX idx_region ON country_metadata(region);
CREATE INDEX idx_income_group ON country_metadata(income_group);


-- TABLE 2: GDP DATA

-- Time-series GDP metrics (current USD and growth rates)
CREATE TABLE gdp_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,  -- Surrogate key (use SERIAL for PostgreSQL)
    country_code CHAR(3) NOT NULL,
    year INTEGER NOT NULL,
    gdp_per_capita_current_usd DECIMAL(12, 2),  -- NY.GDP.PCAP.CD
    gdp_total_current_usd DECIMAL(15, 2),       -- NY.GDP.MKTP.CD (billions)
    gdp_growth_annual_pct DECIMAL(5, 2),        -- NY.GDP.MKTP.KD.ZG
    FOREIGN KEY (country_code) REFERENCES country_metadata(country_code),
    CONSTRAINT chk_year CHECK (year BETWEEN 1990 AND 2030),
    CONSTRAINT uq_country_year UNIQUE (country_code, year)
);

-- Performance indexes for time-series queries
CREATE INDEX idx_gdp_country_year ON gdp_data(country_code, year);
CREATE INDEX idx_gdp_year ON gdp_data(year);


-- TABLE 3: INEQUALITY METRICS

-- Gini coefficient and income share data
CREATE TABLE inequality_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    country_code CHAR(3) NOT NULL,
    year INTEGER NOT NULL,
    gini_coefficient DECIMAL(4, 2),             -- SI.POV.GINI (0-100 scale)
    income_share_lowest_20pct DECIMAL(5, 2),    -- SI.DST.FRST.20
    income_share_highest_20pct DECIMAL(5, 2),   -- SI.DST.05TH.20
    palma_ratio DECIMAL(5, 2),                  -- Calculated: top 10% / bottom 40%
    FOREIGN KEY (country_code) REFERENCES country_metadata(country_code),
    CONSTRAINT chk_gini CHECK (gini_coefficient BETWEEN 0 AND 100),
    CONSTRAINT uq_inequality_country_year UNIQUE (country_code, year)
);

CREATE INDEX idx_inequality_country_year ON inequality_metrics(country_code, year);
CREATE INDEX idx_gini ON inequality_metrics(gini_coefficient);


-- TABLE 4: POVERTY INDICATORS

-- Poverty headcount ratios at various thresholds
CREATE TABLE poverty_indicators (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    country_code CHAR(3) NOT NULL,
    year INTEGER NOT NULL,
    poverty_headcount_215_pct DECIMAL(5, 2),   -- SI.POV.DDAY ($2.15/day, 2017 PPP)
    poverty_headcount_365_pct DECIMAL(5, 2),   -- SI.POV.LMIC ($3.65/day)
    poverty_headcount_685_pct DECIMAL(5, 2),   -- SI.POV.UMIC ($6.85/day)
    poverty_gap DECIMAL(5, 2),                  -- Depth of poverty
    FOREIGN KEY (country_code) REFERENCES country_metadata(country_code),
    CONSTRAINT uq_poverty_country_year UNIQUE (country_code, year)
);

CREATE INDEX idx_poverty_country_year ON poverty_indicators(country_code, year);


-- TABLE 5: TRADE AND EDUCATION

-- Policy-relevant indicators: trade openness, human capital
CREATE TABLE trade_education (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    country_code CHAR(3) NOT NULL,
    year INTEGER NOT NULL,
    trade_pct_gdp DECIMAL(6, 2),                -- NE.TRD.GNFS.ZS (exports + imports)
    secondary_enrollment_rate DECIMAL(5, 2),    -- SE.SEC.ENRR (gross %)
    tertiary_enrollment_rate DECIMAL(5, 2),     -- SE.TER.ENRR
    government_expenditure_education_pct DECIMAL(5, 2), -- SE.XPD.TOTL.GD.ZS
    FOREIGN KEY (country_code) REFERENCES country_metadata(country_code),
    CONSTRAINT uq_trade_edu_country_year UNIQUE (country_code, year)
);

CREATE INDEX idx_trade_edu_country_year ON trade_education(country_code, year);



-- Comprehensive view joining all metrics for a given year
CREATE VIEW latest_comprehensive_data AS
SELECT 
    cm.country_code,
    cm.country_name,
    cm.region,
    cm.income_group,
    gd.year,
    gd.gdp_per_capita_current_usd,
    gd.gdp_growth_annual_pct,
    im.gini_coefficient,
    pi.poverty_headcount_215_pct,
    te.trade_pct_gdp,
    te.secondary_enrollment_rate
FROM country_metadata cm
LEFT JOIN gdp_data gd ON cm.country_code = gd.country_code
LEFT JOIN inequality_metrics im ON cm.country_code = im.country_code AND gd.year = im.year
LEFT JOIN poverty_indicators pi ON cm.country_code = pi.country_code AND gd.year = pi.year
LEFT JOIN trade_education te ON cm.country_code = te.country_code AND gd.year = te.year
WHERE gd.year = (SELECT MAX(year) FROM gdp_data);

-- END OF SCHEMA
