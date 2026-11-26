-- Step 2:

SELECT
    COUNT(*)                                                    AS n_rows,
    COUNT(*) FILTER (WHERE NULLIF(trim(tender_id), '') IS NULL)  AS no_tender_id,
    COUNT(*) FILTER (WHERE NULLIF(trim(lot_lotId), '') IS NULL)  AS no_lot_id
FROM food;

-- no_tender_id, no_lot_id are 0

WITH lots AS (
    SELECT
        yr,
        tender_id || '_' || lot_lotId           AS lot_key,
        MAX(TRY_CAST(lot_bidsCount AS INT))      AS bids,
        MAX(TRY_CAST(lot_validBidsCount AS INT)) AS valid_bids
    FROM food
    GROUP BY yr, lot_key
)
SELECT
    yr,
    COUNT(*)                                         AS n_lots,
    COUNT(*) FILTER (WHERE bids IS NULL)             AS no_bidcount,
    COUNT(*) FILTER (WHERE bids = 0)                 AS zero_bids,
    COUNT(*) FILTER (WHERE bids >= 1)                AS usable,
    ROUND(100.0 * COUNT(*) FILTER (WHERE bids >= 1) / COUNT(*), 1) AS pct_usable,
    COUNT(*) FILTER (WHERE bids = 1)                 AS single_bid,
    COUNT(*) FILTER (WHERE valid_bids IS NULL)       AS no_validbidcount
FROM lots
GROUP BY yr
ORDER BY yr;

--Step 2 RESULT (25 Nov 2026): lots per year + usable bid counts, food v8, 2020–25
-- Lot key tender_id || '_' || lot_lotId: 0 missing IDs → key is safe
--
-- yr   | lots   | no_bidcount | zero | usable | %usable | single_bid
-- 2020 |  2290  |   778       |  0   |  1512  |  66.0   |   493
-- 2021 |  3058  |   888       |  0   |  2170  |  71.0   |   615
-- 2022 |  3427  |  1156       |  0   |  2271  |  66.3   |   797
-- 2023 |  3315  |   993       |  0   |  2322  |  70.0   |   734
-- 2024 |  2201  |  1183       | 52   |   966  |  43.9   |   294where
-- 2025 |  2844  |  1458       | 37   |  1349  |  47.4   |   432
-- TOT  | 17135  |  6456 (37.7%)| 89  | 10590  |  61.8   |  3365 (31.8% of usable)
--
-- Findings:
--  * Enough data: 10,590 usable lots, 3,365 single-bid
--  * Missing bid count jumps from 30–34% (2020–23) to >50% (2024–25),
--    the same period CPV goes missing → likely a source/register change
--  * Zero-bid lots only in 2024–25 → recording change (excluded anyway)
--  * lot_validBidsCount empty for ALL lots → drop on Thu 26
--  * Single-bid share stable at 28–35% → outcome not distorted
-- Plan impact: year fixed effects + robustness check on 2020–23 only
 


