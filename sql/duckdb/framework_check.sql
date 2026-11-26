-- Step 3:

SELECT tender_isFrameworkAgreement,
       COUNT(*) AS n_rows
FROM food
GROUP BY 1
ORDER BY 2 DESC; 

SELECT yr,
       tender_isFrameworkAgreement,
       COUNT(*) AS n_rows
FROM food
GROUP BY yr, tender_isFrameworkAgreement
ORDER BY yr, tender_isFrameworkAgreement;

SELECT tender_isFrameworkAgreement,
       tender_indicator_ADMINISTRATIVE_FRAMEWORK_AGREEMENT,
       COUNT(*) FILTER (WHERE lower(tender_title) LIKE '%рамков%') AS title_says_framework,
       COUNT(*) AS n_rows
FROM food
GROUP BY 1, 2
ORDER BY 1, 2;

DESCRIBE food;

-- No column links call-offs to their parent framework.

-- Conclusion: framework status is missing for ~70% of the data, so it is
-- NOT used as a driver. Blank = unknown (never treated as "no").
-- The column is kept; one robustness check reruns the main model without
-- the known "yes" lots; noted as a limitation in the write-up.

WITH lots AS (
    SELECT
        tender_id || '_' || lot_lotId                      AS lot_key,
        MAX(TRY_CAST(lot_bidsCount AS INT))                AS bids,
        MAX(TRY_CAST(lot_estimatedPrice_EUR AS DOUBLE))    AS lot_value,
        MAX(TRY_CAST(tender_estimatedPrice_EUR AS DOUBLE)) AS tender_value,
        MAX(TRY_CAST(tender_lots_count AS INT))            AS n_lots,
        MAX(lot_estimatedPrice_EUR)                        AS lot_value_raw
    FROM food
    GROUP BY lot_key
)
SELECT
    COUNT(*)                                                         AS n_lots_total,
    COUNT(*) FILTER (WHERE bids >= 1)                                AS usable,
    COUNT(*) FILTER (WHERE bids >= 1 AND lot_value IS NULL)          AS usable_no_lot_value,
    COUNT(*) FILTER (WHERE bids >= 1 AND lot_value IS NULL
                       AND tender_value IS NOT NULL AND n_lots = 1)  AS fixable_from_tender,
    COUNT(*) FILTER (WHERE bids >= 1 AND lot_value IS NULL
                       AND tender_value IS NULL)                     AS usable_no_value_at_all,
    COUNT(*) FILTER (WHERE lot_value = 0)                            AS zero_lot_value,
    COUNT(*) FILTER (WHERE NULLIF(trim(lot_value_raw), '') IS NOT NULL
                       AND lot_value IS NULL)                        AS unparsed_value
FROM lots;

-- unparsed_value 0

WITH lots AS (
    SELECT
        tender_id || '_' || lot_lotId                      AS lot_key,
        MAX(yr)                                            AS yr,
        MAX(TRY_CAST(lot_bidsCount AS INT))                AS bids,
        MAX(TRY_CAST(lot_estimatedPrice_EUR AS DOUBLE))    AS lot_value
    FROM food
    GROUP BY lot_key
)
SELECT
    yr,
    COUNT(*) FILTER (WHERE bids >= 1)                                AS usable,
    COUNT(*) FILTER (WHERE bids >= 1 AND lot_value IS NULL)          AS usable_no_lot_value,
    ROUND(100.0 * COUNT(*) FILTER (WHERE bids >= 1 AND lot_value IS NULL)
          / NULLIF(COUNT(*) FILTER (WHERE bids >= 1), 0), 1)         AS pct_missing
FROM lots
GROUP BY yr
ORDER BY yr;


WITH lots AS (
    SELECT tender_id,
           tender_id || '_' || lot_lotId           AS lot_key,
           MAX(TRY_CAST(tender_lots_count AS INT)) AS n_lots_stated
    FROM food
    GROUP BY tender_id, lot_key
)
SELECT COUNT(*) FILTER (WHERE n_lots_stated = n_lots_seen)  AS match,
       COUNT(*) FILTER (WHERE n_lots_stated <> n_lots_seen) AS mismatch,
       COUNT(*) FILTER (WHERE n_lots_stated IS NULL)        AS stated_missing
FROM (SELECT tender_id,
             MAX(n_lots_stated) AS n_lots_stated,
             COUNT(*)           AS n_lots_seen
      FROM lots
      GROUP BY tender_id) t;

-- Missing lot values: 1,443 of 10,590 usable lots (13.6%).
-- 326 are single-lot tenders and can be filled exactly from the tender value.
-- ~1,100 are in multi-lot tenders; only 17 have no value at lot or tender level.
-- No zero values, nothing unparsed.
-- Missing share by year: 2020 6.7% | 2021 15.4% | 2022 0.4% | 2023 1.0% | 2024 26.1% | 2025 53.4%,
-- so the gaps are not random and cluster in 2024–25.
-- Stated lot count matches lots seen in 5,968 tenders.
