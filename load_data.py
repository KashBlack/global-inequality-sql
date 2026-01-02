


import pandas as pd
import sqlite3
import random


# CONFIGURATION


DB_PATH = 'global_inequality.db'


# LOADING COUNTRY METADATA


def load_country_metadata(conn):
    """Load country reference data"""
    print("Loading country metadata...")
    
    countries_data = {
        'country_code': ['USA', 'GBR', 'DEU', 'FRA', 'JPN', 'CHN', 'IND', 'BRA', 
                         'ZAF', 'NGA', 'KEN', 'ETH', 'MEX', 'ARG', 'CHL', 'POL',
                         'CZE', 'HUN', 'RUS', 'TUR', 'IDN', 'THA', 'VNM', 'PHL',
                         'EGY', 'MAR', 'GHA', 'TZA', 'UGA', 'RWA', 'SWE', 'NOR',
                         'DNK', 'FIN', 'NLD', 'BEL', 'AUT', 'CHE', 'ITA', 'ESP',
                         'PRT', 'GRC', 'CAN', 'AUS', 'NZL', 'KOR', 'SGP', 'MYS'],
        'country_name': ['United States', 'United Kingdom', 'Germany', 'France', 'Japan',
                        'China', 'India', 'Brazil', 'South Africa', 'Nigeria',
                        'Kenya', 'Ethiopia', 'Mexico', 'Argentina', 'Chile',
                        'Poland', 'Czech Republic', 'Hungary', 'Russia', 'Turkey',
                        'Indonesia', 'Thailand', 'Vietnam', 'Philippines',
                        'Egypt', 'Morocco', 'Ghana', 'Tanzania', 'Uganda', 'Rwanda',
                        'Sweden', 'Norway', 'Denmark', 'Finland', 'Netherlands',
                        'Belgium', 'Austria', 'Switzerland', 'Italy', 'Spain',
                        'Portugal', 'Greece', 'Canada', 'Australia', 'New Zealand',
                        'South Korea', 'Singapore', 'Malaysia'],
        'region': ['North America', 'Europe & Central Asia', 'Europe & Central Asia', 
                   'Europe & Central Asia', 'East Asia & Pacific', 'East Asia & Pacific',
                   'South Asia', 'Latin America & Caribbean', 'Sub-Saharan Africa',
                   'Sub-Saharan Africa', 'Sub-Saharan Africa', 'Sub-Saharan Africa',
                   'Latin America & Caribbean', 'Latin America & Caribbean', 
                   'Latin America & Caribbean', 'Europe & Central Asia',
                   'Europe & Central Asia', 'Europe & Central Asia', 'Europe & Central Asia',
                   'Europe & Central Asia', 'East Asia & Pacific', 'East Asia & Pacific',
                   'East Asia & Pacific', 'East Asia & Pacific', 'Middle East & North Africa',
                   'Middle East & North Africa', 'Sub-Saharan Africa', 'Sub-Saharan Africa',
                   'Sub-Saharan Africa', 'Sub-Saharan Africa', 'Europe & Central Asia',
                   'Europe & Central Asia', 'Europe & Central Asia', 'Europe & Central Asia',
                   'Europe & Central Asia', 'Europe & Central Asia', 'Europe & Central Asia',
                   'Europe & Central Asia', 'Europe & Central Asia', 'Europe & Central Asia',
                   'Europe & Central Asia', 'Europe & Central Asia', 'North America',
                   'East Asia & Pacific', 'East Asia & Pacific', 'East Asia & Pacific',
                   'East Asia & Pacific', 'East Asia & Pacific'],
        'income_group': ['High income', 'High income', 'High income', 'High income', 'High income',
                        'Upper middle income', 'Lower middle income', 'Upper middle income',
                        'Upper middle income', 'Lower middle income', 'Lower middle income',
                        'Low income', 'Upper middle income', 'Upper middle income', 
                        'High income', 'High income', 'High income', 'High income',
                        'Upper middle income', 'Upper middle income', 'Upper middle income',
                        'Upper middle income', 'Lower middle income', 'Lower middle income',
                        'Lower middle income', 'Lower middle income', 'Lower middle income',
                        'Lower middle income', 'Low income', 'Low income', 'High income',
                        'High income', 'High income', 'High income', 'High income',
                        'High income', 'High income', 'High income', 'High income',
                        'High income', 'High income', 'High income', 'High income',
                        'High income', 'High income', 'High income', 'High income',
                        'Upper middle income']
    }
    
    df = pd.DataFrame(countries_data)
    df['population_2023'] = None
    
    df.to_sql('country_metadata', conn, if_exists='replace', index=False)
    print(f"✓ Loaded {len(df)} countries")
    return df

# LOADING GDP DATA


def load_gdp_data(conn, countries):
    """Generate realistic sample GDP data"""
    print("Creating GDP data...")
    
    # Base GDP per capita by income group (realistic ranges)
    gdp_ranges = {
        'High income': (40000, 80000),
        'Upper middle income': (8000, 20000),
        'Lower middle income': (2000, 8000),
        'Low income': (500, 2000)
    }
    
    data = []
    for _, country in countries.iterrows():
        country_code = country['country_code']
        income_group = country['income_group']
        
        # Starting GDP (2015)
        min_gdp, max_gdp = gdp_ranges[income_group]
        base_gdp = random.uniform(min_gdp, max_gdp)
        
        # Generate time series (2015-2023)
        for year in range(2015, 2024):
            # Realistic growth rates by income level
            if income_group == 'High income':
                growth = random.uniform(1, 3)
            elif income_group == 'Upper middle income':
                growth = random.uniform(3, 7)
            elif income_group == 'Lower middle income':
                growth = random.uniform(4, 8)
            else:  # Low income
                growth = random.uniform(3, 6)
            
            # COVID impact in 2020
            if year == 2020:
                growth = random.uniform(-5, -2)
            
            # Calculate GDP
            years_since_base = year - 2015
            gdp = base_gdp * ((1 + growth/100) ** years_since_base)
            
            data.append({
                'country_code': country_code,
                'year': year,
                'gdp_per_capita_current_usd': round(gdp, 2),
                'gdp_total_current_usd': None,
                'gdp_growth_annual_pct': round(growth, 2)
            })
    
    df = pd.DataFrame(data)
    df.to_sql('gdp_data', conn, if_exists='replace', index=False)
    print(f"✓ Loaded {len(df)} GDP records")


# LOADING INEQUALITY DATA


def load_inequality_data(conn, countries):
    """Generate realistic inequality data"""
    print("Creating inequality data...")
    
    # Gini coefficients by region (realistic ranges)
    gini_ranges = {
        'Latin America & Caribbean': (45, 55),
        'Sub-Saharan Africa': (40, 65),
        'Middle East & North Africa': (35, 42),
        'South Asia': (32, 38),
        'East Asia & Pacific': (30, 45),
        'Europe & Central Asia': (25, 38),
        'North America': (38, 42)
    }
    
    data = []
    years = [2015, 2017, 2019, 2021, 2023]  # Surveys every 2 years
    
    for _, country in countries.iterrows():
        country_code = country['country_code']
        region = country['region']
        
        min_gini, max_gini = gini_ranges[region]
        base_gini = random.uniform(min_gini, max_gini)
        
        for year in years:
            # Small variation over time
            gini = base_gini + random.uniform(-3, 3)
            gini = max(20, min(70, gini))  # Realistic bounds
            
            # Income shares
            lowest_20 = random.uniform(4, 9)
            highest_20 = random.uniform(40, 55)
            palma = round(highest_20 / (lowest_20 * 2), 2)
            
            data.append({
                'country_code': country_code,
                'year': year,
                'gini_coefficient': round(gini, 2),
                'income_share_lowest_20pct': round(lowest_20, 2),
                'income_share_highest_20pct': round(highest_20, 2),
                'palma_ratio': palma
            })
    
    df = pd.DataFrame(data)
    df.to_sql('inequality_metrics', conn, if_exists='replace', index=False)
    print(f"✓ Loaded {len(df)} inequality records")


# LOADING POVERTY DATA


def load_poverty_data(conn, countries):
    """Generate poverty data (mainly for developing countries)"""
    print("Creating poverty data...")
    
    data = []
    years = [2015, 2017, 2019, 2021, 2023]
    
    for _, country in countries.iterrows():
        country_code = country['country_code']
        income_group = country['income_group']
        
        # Only low/middle income countries have significant poverty data
        if income_group in ['Low income', 'Lower middle income', 'Upper middle income']:
            
            # Base poverty rates by income level
            if income_group == 'Low income':
                base_215 = random.uniform(40, 70)
                base_365 = random.uniform(60, 85)
                base_685 = random.uniform(75, 95)
            elif income_group == 'Lower middle income':
                base_215 = random.uniform(10, 40)
                base_365 = random.uniform(25, 60)
                base_685 = random.uniform(50, 80)
            else:  # Upper middle income
                base_215 = random.uniform(1, 15)
                base_365 = random.uniform(5, 30)
                base_685 = random.uniform(15, 50)
            
            for year in years:
                # Declining trend over time
                years_since_2015 = (year - 2015) / 8
                reduction_factor = 1 - (years_since_2015 * 0.15)  # 15% reduction over period
                
                data.append({
                    'country_code': country_code,
                    'year': year,
                    'poverty_headcount_215_pct': round(base_215 * reduction_factor, 2),
                    'poverty_headcount_365_pct': round(base_365 * reduction_factor, 2),
                    'poverty_headcount_685_pct': round(base_685 * reduction_factor, 2),
                    'poverty_gap': None
                })
    
    df = pd.DataFrame(data)
    df.to_sql('poverty_indicators', conn, if_exists='replace', index=False)
    print(f"✓ Loaded {len(df)} poverty records")


# LOADING TRADE AND EDUCATION DATA


def load_trade_education(conn, countries):
    """Generate trade and education data"""
    print("Creating trade and education data...")
    
    data = []
    for _, country in countries.iterrows():
        country_code = country['country_code']
        income_group = country['income_group']
        
        # Trade openness varies by country size and development
        base_trade = random.uniform(40, 150)
        
        # Education enrollment by income level
        if income_group == 'High income':
            sec_enrollment = random.uniform(95, 105)
            ter_enrollment = random.uniform(60, 90)
            gov_edu_exp = random.uniform(4, 6)
        elif income_group == 'Upper middle income':
            sec_enrollment = random.uniform(75, 95)
            ter_enrollment = random.uniform(30, 60)
            gov_edu_exp = random.uniform(3.5, 5.5)
        elif income_group == 'Lower middle income':
            sec_enrollment = random.uniform(50, 80)
            ter_enrollment = random.uniform(15, 40)
            gov_edu_exp = random.uniform(3, 5)
        else:  # Low income
            sec_enrollment = random.uniform(30, 60)
            ter_enrollment = random.uniform(5, 20)
            gov_edu_exp = random.uniform(2, 4)
        
        for year in range(2015, 2024):
            # Slight improvement in education over time
            years_since_2015 = year - 2015
            sec_improvement = sec_enrollment + (years_since_2015 * 0.5)
            ter_improvement = ter_enrollment + (years_since_2015 * 0.3)
            
            data.append({
                'country_code': country_code,
                'year': year,
                'trade_pct_gdp': round(base_trade + random.uniform(-10, 10), 2),
                'secondary_enrollment_rate': round(min(105, sec_improvement), 2),
                'tertiary_enrollment_rate': round(ter_improvement, 2),
                'government_expenditure_education_pct': round(gov_edu_exp + random.uniform(-0.5, 0.5), 2)
            })
    
    df = pd.DataFrame(data)
    df.to_sql('trade_education', conn, if_exists='replace', index=False)
    print(f"✓ Loaded {len(df)} trade/education records")


# MAIN EXECUTION


def main():
    print("\n" + "="*70)
    print("BASIC GLOBAL INEQUALITY DATABASE LOADER")
    print("Sample data for SQL portfolio demonstration")
    print("="*70 + "\n")
    
    # Connect to database
    conn = sqlite3.connect(DB_PATH)
    
    try:
        # Execute schema
        print("Creating database schema...")
        with open('schema.sql', 'r') as f:
            conn.executescript(f.read())
        print("✓ Schema created\n")
        
        # Load all data
        countries = load_country_metadata(conn)
        load_gdp_data(conn, countries)
        load_inequality_data(conn, countries)
        load_poverty_data(conn, countries)
        load_trade_education(conn, countries)
        
        # Verify data
        print("\n" + "="*70)
        print("DATA LOADING SUMMARY")
        print("="*70)
        
        tables = ['country_metadata', 'gdp_data', 'inequality_metrics', 
                 'poverty_indicators', 'trade_education']
        
        for table in tables:
            count = pd.read_sql(f"SELECT COUNT(*) as cnt FROM {table}", conn)
            print(f"{table:25s}: {count['cnt'][0]:,} rows")
        
        print("\n✓ Database successfully created: " + DB_PATH)
        print("\n" + "="*70)
        print("NEXT STEPS")
        print("="*70)
        print("1. Open DB Browser for SQLite")
        print("2. Load global_inequality.db")
        print("3. Run queries from queries.sql")
        print("4. Export results and build visualizations")
        print("\nNote: This is SAMPLE data for demonstration.")
        print("For real data, see instructions in README.md\n")
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        conn.close()

if __name__ == "__main__":
    main()
