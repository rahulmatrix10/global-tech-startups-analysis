/*
PROJECT: Global Tech & AI Startups Analysis (2020-2026)
AUTHOR: Rahul Ballidav
TOOLS: Excel/Power Query, MySQL, Power BI

IMPORTANT:
This dataset is explicitly described by its creator as a SYNTHETIC dataset.
It is designed to model realistic patterns across three macro periods:

- ZIRP Era (2020-2022): over-hiring and easy funding
- Generative AI Boom (2023-present): capital concentrated in AI startups
- Tech Winter (2024-2025): market correction and layoffs

This is NOT scraped from real company records.
All findings describe patterns in simulated data and should not be
interpreted as the actual performance of real companies.
*/


-- =========================================================
-- SECTION 1: DATABASE + TABLE
-- =========================================================

CREATE DATABASE IF NOT EXISTS tech_startups_project;

USE tech_startups_project;

DROP TABLE IF EXISTS startups;

CREATE TABLE startups (
    company_id VARCHAR(50),
    domain VARCHAR(255),
    founding_year INT,
    country VARCHAR(100),
    city VARCHAR(100),
    funding_stage VARCHAR(50),
    total_funding_usd_millions DECIMAL(12,2),
    valuation_usd_millions DECIMAL(14,2),
    revenue_arr_millions DECIMAL(12,2),
    monthly_burn_rate_millions DECIMAL(10,2),
    runway_months_2024 DECIMAL(8,2),
    peak_headcount_2023 INT,
    layoffs_2024_2025 INT,
    current_headcount_2026 INT,
    investor_tier VARCHAR(100),
    ai_adoption_level VARCHAR(50),
    acquisition_status VARCHAR(50)
);


-- =========================================================
-- SECTION 2: LOAD DATA
-- =========================================================

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/global_tech_startups.csv'

INTO TABLE startups
CHARACTER SET utf8
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- Confirm number of records

SELECT COUNT(*) AS total_rows
FROM startups;


-- =========================================================
-- SECTION 3: DATA VALIDATION
-- =========================================================

-- V1. Confirm the actual category values in the dataset

SELECT DISTINCT funding_stage
FROM startups
ORDER BY funding_stage;

SELECT DISTINCT ai_adoption_level
FROM startups
ORDER BY ai_adoption_level;

SELECT DISTINCT acquisition_status
FROM startups
ORDER BY acquisition_status;

SELECT DISTINCT investor_tier
FROM startups
ORDER BY investor_tier;

SELECT DISTINCT country
FROM startups
ORDER BY country;


-- V2. Check for missing core values

SELECT
    SUM(company_id IS NULL OR TRIM(company_id) = '') AS missing_company_id,
    SUM(founding_year IS NULL) AS missing_founding_year,
    SUM(funding_stage IS NULL OR TRIM(funding_stage) = '') AS missing_funding_stage,
    SUM(peak_headcount_2023 IS NULL) AS missing_peak_headcount,
    SUM(current_headcount_2026 IS NULL) AS missing_current_headcount,
    SUM(layoffs_2024_2025 IS NULL) AS missing_layoffs
FROM startups;


-- V3. Check for duplicate company IDs

SELECT
    company_id,
    COUNT(*) AS occurrences
FROM startups
GROUP BY company_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;


-- NOTE:
-- company_id is NOT enforced as UNIQUE because the dataset contains
-- one repeated company_id with two different startup records.


-- V4. Flag unusual headcount situations
-- This identifies companies where current headcount exceeds the
-- 2023 peak even though layoffs were recorded.
-- This is a flag for investigation, not automatically a data error.

SELECT COUNT(*) AS flagged_headcount_rows
FROM startups
WHERE current_headcount_2026 > peak_headcount_2023
  AND layoffs_2024_2025 > 0;


-- V5. Founding year range check

SELECT
    MIN(founding_year) AS earliest_founded,
    MAX(founding_year) AS latest_founded
FROM startups;


-- V6. Check numeric ranges

SELECT
    MIN(total_funding_usd_millions) AS min_funding,
    MAX(total_funding_usd_millions) AS max_funding,
    MIN(valuation_usd_millions) AS min_valuation,
    MAX(valuation_usd_millions) AS max_valuation,
    MIN(revenue_arr_millions) AS min_revenue,
    MAX(revenue_arr_millions) AS max_revenue,
    MIN(monthly_burn_rate_millions) AS min_burn,
    MAX(monthly_burn_rate_millions) AS max_burn,
    MIN(runway_months_2024) AS min_runway,
    MAX(runway_months_2024) AS max_runway
FROM startups;


-- =========================================================
-- SECTION 4: BUSINESS QUESTIONS
-- =========================================================


-- Q1. How many companies and what's the total/average funding
-- by funding stage?

SELECT
    funding_stage,
    COUNT(*) AS num_companies,
    ROUND(AVG(total_funding_usd_millions), 2) AS avg_funding_millions,
    ROUND(SUM(total_funding_usd_millions), 2) AS total_funding_millions
FROM startups
GROUP BY funding_stage
ORDER BY total_funding_millions DESC;


-- Q2. Which funding stage saw the deepest average layoffs
-- during 2024-2025?

SELECT
    funding_stage,
    COUNT(*) AS num_companies,
    ROUND(AVG(layoffs_2024_2025), 1) AS avg_layoffs,
    ROUND(AVG(peak_headcount_2023), 1) AS avg_peak_headcount,
    ROUND(
        AVG(layoffs_2024_2025)
        / NULLIF(AVG(peak_headcount_2023), 0) * 100,
        2
    ) AS avg_layoff_rate_pct
FROM startups
GROUP BY funding_stage
ORDER BY avg_layoff_rate_pct DESC;


-- Q3. Headcount contraction: peak 2023 vs current 2026,
-- by funding stage

SELECT
    funding_stage,
    ROUND(AVG(peak_headcount_2023), 1) AS avg_peak_2023,
    ROUND(AVG(current_headcount_2026), 1) AS avg_current_2026,
    ROUND(
        (
            AVG(peak_headcount_2023)
            - AVG(current_headcount_2026)
        )
        / NULLIF(AVG(peak_headcount_2023), 0) * 100,
        2
    ) AS pct_contraction
FROM startups
GROUP BY funding_stage
ORDER BY pct_contraction DESC;


-- Q4. AI adoption level vs. layoff severity —
-- how does AI adoption level relate to layoffs?

SELECT
    ai_adoption_level,
    COUNT(*) AS num_companies,
    ROUND(AVG(layoffs_2024_2025), 1) AS avg_layoffs,
    ROUND(AVG(valuation_usd_millions), 2) AS avg_valuation_millions
FROM startups
GROUP BY ai_adoption_level
ORDER BY avg_layoffs DESC;


-- Q5. Burn rate vs. runway —
-- are high-burn companies actually running out of time faster?

SELECT
    CASE
        WHEN monthly_burn_rate_millions < 1
            THEN '1. Under $1M/mo'
        WHEN monthly_burn_rate_millions < 5
            THEN '2. $1-5M/mo'
        WHEN monthly_burn_rate_millions < 15
            THEN '3. $5-15M/mo'
        ELSE '4. $15M+/mo'
    END AS burn_band,
    COUNT(*) AS num_companies,
    ROUND(AVG(runway_months_2024), 1) AS avg_runway_months
FROM startups
WHERE monthly_burn_rate_millions IS NOT NULL
GROUP BY burn_band
ORDER BY burn_band;


-- Q6. Which countries have the most startups,
-- and what's their average valuation?

SELECT
    country,
    COUNT(*) AS num_companies,
    ROUND(AVG(valuation_usd_millions), 2) AS avg_valuation_millions,
    ROUND(AVG(layoffs_2024_2025), 1) AS avg_layoffs
FROM startups
GROUP BY country
ORDER BY num_companies DESC;


-- Q7. Investor tier vs. valuation and funding

SELECT
    investor_tier,
    COUNT(*) AS num_companies,
    ROUND(AVG(valuation_usd_millions), 2) AS avg_valuation_millions,
    ROUND(AVG(total_funding_usd_millions), 2) AS avg_funding_millions
FROM startups
GROUP BY investor_tier
ORDER BY avg_valuation_millions DESC;


-- Q8. Revenue efficiency: ARR vs. valuation
-- Is valuation grounded in real revenue, or is there a
-- larger valuation-to-revenue gap?

SELECT
    funding_stage,
    ROUND(AVG(valuation_usd_millions), 2) AS avg_valuation_millions,
    ROUND(AVG(revenue_arr_millions), 2) AS avg_arr_millions,
    ROUND(
        AVG(valuation_usd_millions)
        / NULLIF(AVG(revenue_arr_millions), 0),
        2
    ) AS avg_valuation_to_arr_multiple
FROM startups
WHERE revenue_arr_millions > 0
GROUP BY funding_stage
ORDER BY avg_valuation_to_arr_multiple DESC;


-- Q9. Founding year vs. outcomes —
-- did companies founded during the ZIRP era (2020-2022)
-- experience different outcomes compared with earlier or later companies?

SELECT
    CASE
        WHEN founding_year BETWEEN 2020 AND 2022
            THEN '1. ZIRP era (2020-2022)'
        WHEN founding_year < 2020
            THEN '2. Pre-2020'
        ELSE '3. 2023+'
    END AS founding_era,
    COUNT(*) AS num_companies,
    ROUND(AVG(layoffs_2024_2025), 1) AS avg_layoffs,
    ROUND(AVG(current_headcount_2026), 1) AS avg_current_headcount
FROM startups
WHERE founding_year IS NOT NULL
GROUP BY founding_era
ORDER BY founding_era;


-- Q10. Top 15 cities by number of startups

SELECT
    city,
    COUNT(*) AS num_companies
FROM startups
GROUP BY city
ORDER BY num_companies DESC
LIMIT 15;


-- Q11. Acquisition/status outcomes by funding stage

SELECT
    funding_stage,
    acquisition_status,
    COUNT(*) AS num_companies
FROM startups
GROUP BY funding_stage, acquisition_status
ORDER BY funding_stage, num_companies DESC;


-- Q12. Highest-valuation companies and their layoff rates

SELECT
    company_id,
    domain,
    country,
    funding_stage,
    valuation_usd_millions,
    peak_headcount_2023,
    layoffs_2024_2025,
    ROUND(
        layoffs_2024_2025
        / NULLIF(peak_headcount_2023, 0) * 100,
        2
    ) AS layoff_rate_pct
FROM startups
WHERE valuation_usd_millions IS NOT NULL
ORDER BY valuation_usd_millions DESC
LIMIT 15;


-- Q13. Runway distribution —
-- how many companies are in a danger zone
-- with under 6 months of runway?

SELECT
    COUNT(*) AS total_companies,
    SUM(runway_months_2024 < 6) AS under_6_months_runway,
    ROUND(
        SUM(runway_months_2024 < 6)
        * 100.0 / COUNT(*),
        2
    ) AS pct_under_6_months
FROM startups
WHERE runway_months_2024 IS NOT NULL;


-- Q14. AI adoption level distribution overall,
-- and its relationship to funding stage

SELECT
    funding_stage,
    ai_adoption_level,
    COUNT(*) AS num_companies
FROM startups
GROUP BY funding_stage, ai_adoption_level
ORDER BY funding_stage, num_companies DESC;


-- Q15. Overall summary statistics for Power BI KPI cards

SELECT
    COUNT(*) AS total_companies,
    ROUND(SUM(total_funding_usd_millions), 2)
        AS total_funding_millions,
    ROUND(AVG(valuation_usd_millions), 2)
        AS avg_valuation_millions,
    SUM(layoffs_2024_2025)
        AS total_layoffs,
    ROUND(AVG(runway_months_2024), 1)
        AS avg_runway_months,
    COUNT(DISTINCT country)
        AS total_countries
FROM startups;


-- =========================================================
-- SECTION 5: ADDITIONAL CATEGORY-BASED QUESTIONS
-- =========================================================

-- Q16. Companies with HIGH AI adoption vs LOW/NONE —
-- direct comparison.
--
-- IMPORTANT:
-- First run:
-- SELECT DISTINCT ai_adoption_level FROM startups;
--
-- Then replace the values below with the exact category names
-- from your dataset.

SELECT
    ai_adoption_level,
    COUNT(*) AS num_companies,
    ROUND(AVG(layoffs_2024_2025), 1) AS avg_layoffs,
    ROUND(AVG(valuation_usd_millions), 2)
        AS avg_valuation_millions
FROM startups
WHERE ai_adoption_level IN ('High', 'None')
GROUP BY ai_adoption_level;


-- Q17. Companies that were ACQUIRED vs SHUT DOWN
-- vs still INDEPENDENT
--
-- First confirm the exact values using:
-- SELECT DISTINCT acquisition_status FROM startups;

SELECT
    acquisition_status,
    COUNT(*) AS num_companies,
    ROUND(AVG(total_funding_usd_millions), 2)
        AS avg_funding_received,
    ROUND(AVG(layoffs_2024_2025), 1)
        AS avg_layoffs
FROM startups
GROUP BY acquisition_status
ORDER BY avg_funding_received DESC;


-- Q18. Late-stage funding vs early-stage funding
-- layoff comparison
--
-- The CASE values should be checked against the actual
-- funding_stage categories in the dataset.

SELECT
    CASE
        WHEN funding_stage IN ('Seed', 'Series A')
            THEN 'Early stage'
        WHEN funding_stage IN ('Series C', 'Series D', 'Series E')
            THEN 'Late stage'
        ELSE 'Other'
    END AS stage_group,
    COUNT(*) AS num_companies,
    ROUND(AVG(layoffs_2024_2025), 1)
        AS avg_layoffs
FROM startups
GROUP BY stage_group;


-- =========================================================
-- END OF PROJECT
-- =========================================================