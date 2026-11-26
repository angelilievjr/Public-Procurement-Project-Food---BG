-- Step 1: 2020-25 food Filter

CREATE OR REPLACE VIEW raw AS
SELECT *
FROM read_csv('/Users/angel/Desktop/SQL Project/data-bg-csv/*.csv',
				delim = ';', header = true,
				union_by_name = true, all_varchar = true,  filename = true);

-- csv raw data read as one table - raw

DESCRIBE raw;
SELECT * FROM raw LIMIT 20;

SELECT tender_mainCpv, length(tender_mainCpv) AS len, tender_cpvs
FROM raw
WHERE tender_mainCpv IS NOT NULL
LIMIT 10;

-- csv codes complete

SELECT left(tender_mainCpv, 2) AS division, COUNT(*) AS n_rows
FROM raw
GROUP BY 1
ORDER BY 2 DESC;

-- 15, food 44,015 rows

SELECT filename, COUNT(*) AS n_rows
FROM raw
GROUP BY filename
ORDER BY filename;

-- file names for year

SELECT 
	regexp_extract(filename, '(20[0-9]{2})', 1) AS file_year,
	tender_year,
	COUNT(*) AS n
	FROM raw
	GROUP BY ALL
	ORDER BY file_year, n DESC;

SELECT filename, COUNT(*) AS n
FROM raw
WHERE regexp_extract(filename, '(20[0-9]{2})', 1) = ''
GROUP BY filename;

SELECT column_name
FROM (DESCRIBE raw)
WHERE column_name ILIKE '%date%' OR column_name ILIKE '%deadline%';

SELECT
    COUNT(*)                                                     AS total_rows,
    COUNT(*) FILTER (WHERE left(tender_mainCpv, 2) = '15')       AS food_div15,
    COUNT(NULLIF(tender_publications_firstCallForTenderDate, '')) AS has_publication,
    COUNT(NULLIF(tender_bidDeadline, ''))                        AS has_deadline,
    COUNT(NULLIF(tender_awardDecisionDate, ''))                  AS has_award,
    COUNT(NULLIF(tender_contractSignatureDate, ''))              AS has_signature
FROM raw
WHERE filename LIKE '%year-unavailable%';

-- decision to drop year unavailable

SELECT
    NULLIF(regexp_extract(filename, '(20[0-9]{2})', 1), '')::INT  AS yr,
    COUNT(*)                                                      AS total_rows,
    COUNT(NULLIF(tender_publications_firstCallForTenderDate, '')) AS has_publication,
    COUNT(NULLIF(tender_bidDeadline, ''))                         AS has_deadline
FROM raw
GROUP BY yr
ORDER BY yr;

-- yr = year from file name; year-unavailable file -> NULL -> dropped by the 2020–2025 filter

-- date coverage across the whole dataset (needed later for the deadline-length test)

SELECT tender_mainCpv, length(tender_mainCpv) AS len, COUNT(*) AS n
FROM raw
WHERE tender_mainCpv IS NULL
   OR NOT regexp_matches(tender_mainCpv, '^[0-9]{8}')
GROUP BY ALL
ORDER BY n DESC
LIMIT 30;

SELECT COUNT(*) AS n_broken
FROM raw
WHERE tender_mainCpv IS NULL
   OR NOT regexp_matches(tender_mainCpv, '^[0-9]{8}');

-- 79,301 broken CSVs for all years

CREATE OR REPLACE VIEW raw_2020_2025 AS
SELECT
    *,
    NULLIF(regexp_extract(filename, '(20[0-9]{2})', 1), '')::INT AS yr
FROM raw
WHERE NULLIF(regexp_extract(filename, '(20[0-9]{2})', 1), '')::INT BETWEEN 2020 AND 2025;

-- Filter from 2020 to 2025

SELECT yr, COUNT(*) AS n
FROM raw_2020_2025
GROUP BY yr
ORDER BY yr;

-- number of bids for each of those years

SELECT
    COUNT(*) FILTER (WHERE tender_mainCpv IS NULL OR trim(tender_mainCpv) = '') AS missing_cpv,
    COUNT(*) FILTER (WHERE NOT regexp_matches(coalesce(trim(tender_mainCpv), ''), '^[0-9]{8}')
                       AND trim(tender_mainCpv) <> '')                          AS misparsed,
    COUNT(*)                                                                    AS total
FROM raw_2020_2025;

-- 44,870 missing_cpv (keyword fallback), total 294,538, misparsed 38 (dropped)

SELECT
    COUNT(*)                                                       AS no_main_cpv,
    COUNT(*) FILTER (WHERE NULLIF(trim(tender_cpvs), '') IS NOT NULL) AS has_secondary_cpvs
FROM raw_2020_2025
WHERE tender_mainCpv IS NULL OR trim(tender_mainCpv) = '';

-- only small number have secondary cpv (6) --> keyword fallback

CREATE OR REPLACE VIEW food AS
WITH base AS (
    SELECT
        *,
        CASE WHEN regexp_matches(trim(tender_mainCpv), '^[0-9]{8}')
             THEN left(trim(tender_mainCpv), 8) END   AS cpv8,
        lower(tender_title)                           AS title_lc
    FROM raw_2020_2025
    WHERE tender_mainCpv IS NULL
       OR trim(tender_mainCpv) = ''
       OR regexp_matches(trim(tender_mainCpv), '^[0-9]{8}')
)
SELECT
    *,
    CASE WHEN cpv8 IS NOT NULL THEN 'cpv' ELSE 'keyword' END AS food_source
FROM base
WHERE
    -- division 15 minus alcohol (1591–1597), tobacco (1599) and the vague parent 15900000
    (left(cpv8, 2) = '15'
        AND left(cpv8, 4) NOT IN ('1591','1592','1593','1594','1595','1596','1597','1599')
        AND cpv8 <> '15900000')
    -- CPV 03 food groups
 OR left(cpv8, 4) IN ('0311','0313','0314','0331','0333')
 OR left(cpv8, 3) = '032'
    -- catering
 OR left(cpv8, 3) IN ('553','555')
    -- keyword fallback, only when there is no code
 OR (cpv8 IS NULL
     AND regexp_matches(title_lc,
         'хранител|(^|[^а-я])храни([^а-я]|$)|храна|кетъринг|хранене|мляко|млечн|месо|месни|хляб|хлебн|плодове|зеленчуц|риба|рибн|яйца|сирене|брашно|олио|захар')
     AND NOT regexp_matches(title_lc,
         'охран|фураж|за животни|ваучер|карти за храна|хранителни среди|хранителни добавки|лекарств|рибариц|оборудване|апаратура'));

-- food view v4: 2020–25, CPV 15 (no alcohol, no tobacco, no 15900000)
--   + CPV 03 food groups (0311, 0313, 0314, 032, 0331, 0333) + catering (553, 555)
--   + Bulgarian title keywords when CPV is missing
-- 38 misparsed CPV rows dropped (text in CPV column, likely ';' inside a description)
-- tender_cpvs ignored: only 6 of 44,870 no-CPV rows have secondary codes
-- keyword exclusions (all except охран / фураж / за животни found by sampling keyword matches):
--   охран -> security services ("охранителни" contains "хранителни")
--   фураж / за животни -> animal feed
--   ваучер / карти за храна -> food vouchers are employee benefits, not food supply
--   хранителни среди -> lab culture media
--   хранителни добавки / лекарств -> supplements and medicines, hospital pharmacy tenders
--   рибариц -> village name Рибарица contains "риба"
--   оборудване / апаратура -> equipment for food-related institutions
-- kept: mixed "хранителни и нехранителни стоки" contracts (part food) -> limitation in write-up
-- fix: replaced храни\b with (^|[^а-я])храни([^а-я]|$) — RE2's \b doesn't work next to Cyrillic letters


-- rows (bids) per year and source
SELECT yr, food_source, COUNT(*) AS n
FROM food
GROUP BY ALL
ORDER BY yr, food_source;

-- v1:  2020: 2,328 cpv, 7 keyword; 2021: 3,064 cpv; 2022: 3,458 cpv;
--      2023: 3,395 cpv; 2024: 1,687 cpv, 877 keyword; 2025: 1,389 cpv, 1,767 keyword
-- v2 (vouchers excluded): 2024 keyword 877 -> 840 (-37), 2025 keyword 1,767 -> 1,689 (-78); CPV unchanged
-- v4 (+ culture media, supplements/medicines, Рибарица, equipment excluded; храни boundary fixed):
--      2024 keyword 840 -> 627 (-213), 2025 keyword 1,689 -> 1,565 (-124); CPV unchanged
--      final: 2020: 2,328 cpv, 7 keyword; 2021: 3,064; 2022: 3,458; 2023: 3,395;
--             2024: 1,687 cpv, 627 keyword; 2025: 1,389 cpv, 1,565 keyword (total 18,920 rows)



SELECT tender_title
FROM food
WHERE food_source = 'keyword'
ORDER BY random()
LIMIT 50;

SELECT tender_title
FROM raw_2020_2025
WHERE (tender_mainCpv IS NULL OR trim(tender_mainCpv) = '')
  AND NOT regexp_matches(lower(tender_title),
      'хранител|(^|[^а-я])храни([^а-я]|$)|храна|кетъринг|хранене|мляко|млечн|месо|месни|хляб|хлебн|плодове|зеленчуц|риба|рибн|яйца|сирене|брашно|олио|захар')
ORDER BY random()
LIMIT 50;
-- food showed up, keywords not sufficient


CREATE OR REPLACE VIEW food AS
WITH base AS (
    SELECT
        *,
        CASE WHEN regexp_matches(trim(tender_mainCpv), '^[0-9]{8}')
             THEN left(trim(tender_mainCpv), 8) END   AS cpv8,
        lower(tender_title)                           AS title_lc
    FROM raw_2020_2025
    WHERE tender_mainCpv IS NULL
       OR trim(tender_mainCpv) = ''
       OR regexp_matches(trim(tender_mainCpv), '^[0-9]{8}')
)
SELECT
    *,
    CASE WHEN cpv8 IS NOT NULL THEN 'cpv' ELSE 'keyword' END AS food_source
FROM base
WHERE
    -- division 15 minus alcohol (1591–1597), tobacco (1599) and the vague parent 15900000
    (left(cpv8, 2) = '15'
        AND left(cpv8, 4) NOT IN ('1591','1592','1593','1594','1595','1596','1597','1599')
        AND cpv8 <> '15900000')
    -- CPV 03 food groups
 OR left(cpv8, 4) IN ('0311','0313','0314','0331','0333')
 OR left(cpv8, 3) = '032'
    -- catering
 OR left(cpv8, 3) IN ('553','555')
    -- keyword fallback, only when there is no code
 OR (cpv8 IS NULL
     AND regexp_matches(title_lc,
         'хранител|(^|[^а-я])храни([^а-я]|$)|храна|кетъринг|хранене|мляко|млечн|месо|месни|хляб|хлебн|плодове|зеленчуц|риба|рибн|яйца|сирене|брашно|олио|захар')
     AND NOT regexp_matches(title_lc,
         'охран|фураж|за животни|ваучер|карти за храна|хранителни среди|хранителни добавки|лекарств|рибариц|оборудване|апарат|автомобил|софтуер|горив'));

-- food view v5: 2020–25, CPV 15 (no alcohol, no tobacco, no 15900000)
--   + CPV 03 food groups (0311, 0313, 0314, 032, 0331, 0333) + catering (553, 555)
--   + Bulgarian title keywords when CPV is missing
-- 38 misparsed CPV rows dropped (text in CPV column, likely ';' inside a description)
-- tender_cpvs ignored: only 6 of 44,870 no-CPV rows have secondary codes
-- keyword exclusions (all except охран / фураж / за животни found by sampling keyword matches):
--   охран -> security services ("охранителни" contains "хранителни")
--   фураж / за животни -> animal feed
--   ваучер / карти за храна -> food vouchers are employee benefits, not food supply
--   хранителни среди -> lab culture media
--   хранителни добавки / лекарств -> supplements and medicines, hospital pharmacy tenders
--   рибариц -> village name Рибарица contains "риба"
--   оборудване / апарат -> equipment for food-related institutions (апарат covers апарати and апаратура)
--   автомобил / софтуер / горив -> cars, software, fuel bought by organisations with "храна/хранене" in their name
-- kept: mixed contracts with a real food part ("хранителни и нехранителни стоки", food + drinks/tobacco)
--   -> limitation in write-up
-- fix: replaced храни\b with (^|[^а-я])храни([^а-я]|$) — RE2's \b doesn't work next to Cyrillic letters
-- missed-food check: 2 samples of no-CPV, non-matched titles (55 rows) contained no food tenders
--   -> keyword list catches the food tenders; 2024 dip likely real

SELECT yr, food_source, COUNT(*) AS n
FROM food
GROUP BY ALL
ORDER BY yr, food_source;

SELECT tender_title
FROM food
WHERE food_source = 'keyword'
ORDER BY random()
LIMIT 50;

CREATE OR REPLACE VIEW food AS
WITH base AS (
    SELECT
        *,
        CASE WHEN regexp_matches(trim(tender_mainCpv), '^[0-9]{8}')
             THEN left(trim(tender_mainCpv), 8) END   AS cpv8,
        lower(tender_title)                           AS title_lc
    FROM raw_2020_2025
    WHERE tender_mainCpv IS NULL
       OR trim(tender_mainCpv) = ''
       OR regexp_matches(trim(tender_mainCpv), '^[0-9]{8}')
)
SELECT
    *,
    CASE WHEN cpv8 IS NOT NULL THEN 'cpv' ELSE 'keyword' END AS food_source
FROM base
WHERE
    -- division 15 minus alcohol (1591–1597), tobacco (1599) and the vague parent 15900000
    (left(cpv8, 2) = '15'
        AND left(cpv8, 4) NOT IN ('1591','1592','1593','1594','1595','1596','1597','1599')
        AND cpv8 <> '15900000')
    -- CPV 03 food groups
 OR left(cpv8, 4) IN ('0311','0313','0314','0331','0333')
 OR left(cpv8, 3) = '032'
    -- catering
 OR left(cpv8, 3) IN ('553','555')
    -- keyword fallback, only when there is no code
 OR (cpv8 IS NULL
     AND regexp_matches(title_lc,
         'хранител|(^|[^а-я])храни([^а-я]|$)|храна|кетъринг|хранене|мляко|млечн|месо|месни|хляб|хлебн|плодове|зеленчуц|риба|рибн|яйца|сирене|брашно|(^|[^а-я])олио|захар([^и]|$)')
     AND NOT regexp_matches(title_lc,
         'охран|фураж|за животни|ваучер|карти за храна|хранителни среди|хранителни добавки|лекарств|рибариц|оборудване|апарат|автомобил|софтуер|горив'));

-- food view v6: 2020–25, CPV 15 (no alcohol, no tobacco, no 15900000)
--   + CPV 03 food groups (0311, 0313, 0314, 032, 0331, 0333) + catering (553, 555)
--   + Bulgarian title keywords when CPV is missing
-- 38 misparsed CPV rows dropped (text in CPV column, likely ';' inside a description)
-- tender_cpvs ignored: only 6 of 44,870 no-CPV rows have secondary codes
-- keyword exclusions (all except охран / фураж / за животни found by sampling keyword matches):
--   охран -> security services ("охранителни" contains "хранителни")
--   фураж / за животни -> animal feed
--   ваучер / карти за храна -> food vouchers are employee benefits, not food supply
--   хранителни среди -> lab culture media
--   хранителни добавки / лекарств -> supplements and medicines, hospital pharmacy tenders
--   рибариц -> village name Рибарица contains "риба"
--   оборудване / апарат -> equipment for food-related institutions (апарат covers апарати and апаратура)
--   автомобил / софтуер / горив -> cars, software, fuel bought by organisations with "храна/хранене" in their name
-- keyword boundaries (short stems matching inside names):
--   храни  -> (^|[^а-я])храни([^а-я]|$)  (RE2's \b doesn't work next to Cyrillic letters)
--   олио   -> (^|[^а-я])олио             ("Жолио-Кюри" school name contained "олио")
--   захар  -> захар([^и]|$)              (avoid "Захари Стоянов" names; keeps захар, захарни)
-- kept: mixed contracts with a real food part ("хранителни и нехранителни стоки", food + drinks/tobacco)
--   -> limitation in write-up
-- missed-food check: 2 samples of no-CPV, non-matched titles (55 rows) contained no food tenders
--   -> keyword list catches the food tenders; 2024 dip likely real

-- test 1: rows (bids) per year and source
SELECT yr, food_source, COUNT(*) AS n
FROM food
GROUP BY ALL
ORDER BY yr, food_source;


-- test 2: random keyword matches -> anything that isn't food?
SELECT tender_title
FROM food
WHERE food_source = 'keyword'
ORDER BY random()
LIMIT 50;

CREATE OR REPLACE VIEW food AS
WITH base AS (
    SELECT
        *,
        CASE WHEN regexp_matches(trim(tender_mainCpv), '^[0-9]{8}')
             THEN left(trim(tender_mainCpv), 8) END   AS cpv8,
        lower(tender_title)                           AS title_lc
    FROM raw_2020_2025
    WHERE tender_mainCpv IS NULL
       OR trim(tender_mainCpv) = ''
       OR regexp_matches(trim(tender_mainCpv), '^[0-9]{8}')
)
SELECT
    *,
    CASE WHEN cpv8 IS NOT NULL THEN 'cpv' ELSE 'keyword' END AS food_source
FROM base
WHERE
    -- division 15 minus alcohol (1591–1597), tobacco (1599) and the vague parent 15900000
    (left(cpv8, 2) = '15'
        AND left(cpv8, 4) NOT IN ('1591','1592','1593','1594','1595','1596','1597','1599')
        AND cpv8 <> '15900000')
    -- CPV 03 food groups
 OR left(cpv8, 4) IN ('0311','0313','0314','0331','0333')
 OR left(cpv8, 3) = '032'
    -- catering
 OR left(cpv8, 3) IN ('553','555')
    -- keyword fallback, only when there is no code
 OR (cpv8 IS NULL
     AND regexp_matches(title_lc,
         'хранител|(^|[^а-я])храни([^а-я]|$)|храна|кетъринг|хранене|мляко|млечн|месо|месни|хляб|хлебн|плодове|зеленчуц|риба|рибн|яйца|сирене|брашно|(^|[^а-я])олио|захар([^и]|$)')
     AND NOT regexp_matches(title_lc,
         'охран|фураж|за животни|ваучер|карти за храна|хранителни среди|хранителни добавки|лекарств|специални медицински цели|рибариц|рибнов|оборудване|апарат|автомобил|софтуер|горив|водопровод|отпадъ|невроразвитие'));

-- food view v7: 2020–25, CPV 15 (no alcohol, no tobacco, no 15900000)
--   + CPV 03 food groups (0311, 0313, 0314, 032, 0331, 0333) + catering (553, 555)
--   + Bulgarian title keywords when CPV is missing
-- 38 misparsed CPV rows dropped (text in CPV column, likely ';' inside a description)
-- tender_cpvs ignored: only 6 of 44,870 no-CPV rows have secondary codes
-- keyword exclusions (all except охран / фураж / за животни found by sampling keyword matches):
--   охран -> security services ("охранителни" contains "хранителни")
--   фураж / за животни -> animal feed
--   ваучер / карти за храна -> food vouchers are employee benefits, not food supply
--   хранителни среди -> lab culture media
--   хранителни добавки / лекарств / специални медицински цели -> supplements, medicines, medical nutrition
--   рибариц / рибнов -> village names Рибарица, Рибново contain "риба" / "рибн"
--   оборудване / апарат -> equipment for food-related institutions (апарат covers апарати and апаратура)
--   автомобил / софтуер / горив -> cars, software, fuel bought by organisations with "храна/хранене" in their name
--   водопровод -> "хранителни водопроводи" = feeding water mains
--   отпадъ -> food waste processing
--   невроразвитие -> research group "Хранене и невроразвитие" (cell cultures, software)
-- keyword boundaries (short stems matching inside names):
--   храни  -> (^|[^а-я])храни([^а-я]|$)  (RE2's \b doesn't work next to Cyrillic letters)
--   олио   -> (^|[^а-я])олио             ("Жолио-Кюри" school name contained "олио")
--   захар  -> захар([^и]|$)              (avoid "Захари Стоянов" names; keeps захар, захарни)
-- kept: mixed contracts with a real food part ("хранителни и нехранителни стоки", food + drinks/tobacco)
--   -> limitation in write-up
-- missed-food check: 2 samples of no-CPV, non-matched titles (55 rows) contained no food tenders
--   -> keyword list catches the food tenders; 2024 dip likely real

-- test 2: random keyword matches -> anything that isn't food?
SELECT tender_title
FROM food
WHERE food_source = 'keyword'
ORDER BY random()
LIMIT 50;

CREATE OR REPLACE VIEW food AS
WITH base AS (
    SELECT
        *,
        CASE WHEN regexp_matches(trim(tender_mainCpv), '^[0-9]{8}')
             THEN left(trim(tender_mainCpv), 8) END   AS cpv8,
        lower(tender_title)                           AS title_lc
    FROM raw_2020_2025
    WHERE tender_mainCpv IS NULL
       OR trim(tender_mainCpv) = ''
       OR regexp_matches(trim(tender_mainCpv), '^[0-9]{8}')
)
SELECT
    *,
    CASE WHEN cpv8 IS NOT NULL THEN 'cpv' ELSE 'keyword' END AS food_source
FROM base
WHERE
    -- division 15 minus alcohol (1591–1597), tobacco (1599) and the vague parent 15900000
    (left(cpv8, 2) = '15'
        AND left(cpv8, 4) NOT IN ('1591','1592','1593','1594','1595','1596','1597','1599')
        AND cpv8 <> '15900000')
    -- CPV 03 food groups
 OR left(cpv8, 4) IN ('0311','0313','0314','0331','0333')
 OR left(cpv8, 3) = '032'
    -- catering
 OR left(cpv8, 3) IN ('553','555')
    -- keyword fallback, only when there is no code
 OR (cpv8 IS NULL
     AND regexp_matches(title_lc,
         'хранител|(^|[^а-я])храни([^а-я]|$)|храна|кетъринг|хранене|мляко|млечн|месо|месни|хляб|хлебн|плодове|зеленчуц|риба|рибн|яйца|сирене|брашно|(^|[^а-я])олио|захар([^и]|$)')
     AND NOT regexp_matches(title_lc,
         'охран|фураж|за животни|ваучер|карти за храна|хранителни среди|хранителни добавки|лекарств|специални медицински цели|рибариц|рибнов|рибарско пристанище|оборудване|апарат|автомобил|софтуер|горив|водопровод|отпадъ|невроразвитие|смр|ремонт'));

-- food view v8: 2020–25, CPV 15 (no alcohol, no tobacco, no 15900000)
--   + CPV 03 food groups (0311, 0313, 0314, 032, 0331, 0333) + catering (553, 555)
--   + Bulgarian title keywords when CPV is missing
-- 38 misparsed CPV rows dropped (text in CPV column, likely ';' inside a description)
-- tender_cpvs ignored: only 6 of 44,870 no-CPV rows have secondary codes
-- keyword exclusions (all except охран / фураж / за животни found by sampling keyword matches):
--   охран -> security services ("охранителни" contains "хранителни")
--   фураж / за животни -> animal feed
--   ваучер / карти за храна -> food vouchers are employee benefits, not food supply
--   хранителни среди -> lab culture media
--   хранителни добавки / лекарств / специални медицински цели -> supplements, medicines, medical nutrition
--   рибариц / рибнов -> village names Рибарица, Рибново contain "риба" / "рибн"
--   рибарско пристанище -> fishing port works ("рибарско" contains "риба")
--   оборудване / апарат -> equipment for food-related institutions (апарат covers апарати and апаратура)
--   автомобил / софтуер / горив -> cars, software, fuel bought by organisations with "храна/хранене" in their name
--   водопровод -> "хранителни водопроводи" = feeding water mains
--   отпадъ -> food waste processing
--   невроразвитие -> research group "Хранене и невроразвитие" (cell cultures, software)
--   смр / ремонт -> construction/repair ("хранителен блок" kitchen buildings, "Захарна фабрика" neighbourhood)
-- keyword boundaries (short stems matching inside names):
--   храни  -> (^|[^а-я])храни([^а-я]|$)  (RE2's \b doesn't work next to Cyrillic letters)
--   олио   -> (^|[^а-я])олио             ("Жолио-Кюри" school name contained "олио")
--   захар  -> захар([^и]|$)              (avoid "Захари Стоянов" names; keeps захар, захарни)
-- kept: mixed contracts with a real food part ("хранителни и нехранителни стоки", food + drinks/tobacco)
--   -> limitation in write-up
-- keyword validation: random samples of 50 until two in a row had ≤1 false positive
--   last samples: 49/50, 49/50, 21/22 food (misses removed by смр / ремонт / рибарско пристанище)
-- missed-food check: 2 samples of no-CPV, non-matched titles (55 rows) contained no food tenders
--   -> keyword list catches the food tenders; 2024 dip likely real


-- test 4: titles that matched a food word but were excluded -> any real food lost?
SELECT tender_title, COUNT(*) AS n
FROM raw_2020_2025
WHERE (tender_mainCpv IS NULL OR trim(tender_mainCpv) = '')
  AND regexp_matches(lower(tender_title),
      'хранител|(^|[^а-я])храни([^а-я]|$)|храна|кетъринг|хранене|мляко|млечн|месо|месни|хляб|хлебн|плодове|зеленчуц|риба|рибн|яйца|сирене|брашно|(^|[^а-я])олио|захар([^и]|$)')
  AND regexp_matches(lower(tender_title),
      'охран|фураж|за животни|ваучер|карти за храна|хранителни среди|хранителни добавки|лекарств|специални медицински цели|рибариц|рибнов|рибарско пристанище|оборудване|апарат|автомобил|софтуер|горив|водопровод|отпадъ|невроразвитие|смр|ремонт')
GROUP BY tender_title
ORDER BY n DESC;

-- test 1: final rows (bids) per year and source
SELECT yr, food_source, COUNT(*) AS n
FROM food
GROUP BY ALL
ORDER BY yr, food_source;

-- test 5: rows (bids) and tenders per year
SELECT
    yr,
    COUNT(*)                  AS n_rows,
    COUNT(DISTINCT tender_id) AS n_tenders
FROM food
GROUP BY yr
ORDER BY yr;

-- final (v8) rows (bids) per year and source:
--   2020: 2,328 cpv, 7 keyword; 2021: 3,064 cpv; 2022: 3,458 cpv; 2023: 3,395 cpv;
--   2024: 1,687 cpv, 592 keyword; 2025: 1,389 cpv, 1,479 keyword
--   keyword share: 2024 = 26%, 2025 = 52%

-- final bids and tenders per year:
--   2020: 2,335 / 818;  2021: 3,064 / 1,127;  2022: 3,458 / 1,229
--   2023: 3,395 / 1,155;  2024: 2,279 / 782;  2025: 2,868 / 857
--   total: 17,399 bids, 5,968 tenders
