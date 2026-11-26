# Predicting Single-Bid Risk in Bulgarian Public Food Procurement

**Status:** in progress. Scope and data check complete (DuckDB); next: loading into PostgreSQL, cleaning and analysis.

## Main Goal
Identify which features of a Bulgarian public food tender predict that it will
receive only one bid, using only information available *before* the tender is
published, so that risky tenders can be flagged at the design stage.

### Planned extension
Test whether food producers and processors that win single-bid tenders also
receive EU subsidies.

## Data check (first results)
Food tenders 2020–2025, after applying the food definition below:

| | Count |
|---|---|
| Tenders | 5,968 |
| Lots | 17,135 |
| Lots with a usable bid count | 10,590 (61.8%) |
| Single-bid lots | 3,365 (31.8% of usable lots) |

- The single-bid share is stable at 28–35% per year.
- Missing bid counts and missing CPV codes both jump in 2024–2025, which points
  to a change in how the source register records data rather than chance.
  The analysis controls for year and is re-run on 2020–2023 only.

## Key design decisions
- **Only pre-publication information as predictors.** Bid count, winner, final
  price and award date are outcomes, never drivers (no data leakage).
- **The lot is the unit**, because bids are made per lot. Lots in the same
  tender are not independent, so standard errors are clustered by tender.
- **Bid count is taken from the recorded field, never by counting rows**: rows
  are winning bids, not all bids.
- **Missing bid counts are excluded, never treated as zero**, and the missing
  lots are compared with the rest to check for selection bias.
- **Missing lot values are filled from the tender value and flagged**
  (13.6% of usable lots). Dropping them would halve 2025 and bias the sample
  towards 2022–2023; a robustness check uses real lot values only.
- **Framework-agreement status is not used as a driver**: it is blank for
  about 70% of food records, and blank is treated as unknown, not as "no".

## Methods

### Scope
- **Period:** 2020–2025 (2020–2021 flagged as COVID years)
- **Food tenders:** CPV division 15 (excluding tobacco and alcohol), the food
  groups of CPV division 03 (fruit and vegetables, livestock products, fish),
  plus catering services (CPV 553 and 555), with a Bulgarian title-keyword
  fallback only where the CPV code is missing. Keyword matches were checked by
  repeated random samples, and all excluded titles were reviewed by hand.
- **Excluded from the main model:** negotiated procedures without prior
  publication (single-bid by design; described separately), cancelled lots,
  lots with zero bids

### Unit of analysis and outcome
- **Unit:** lot (bid-level records aggregated to lots)
- **Outcome:** single-bid flag (bid count = 1)
- Tender-level context kept on each lot: number of lots, number of distinct
  winners, whether one firm won every lot

### Drivers (all known before publication)
- Procedure type
- Submission deadline relative to the legal minimum
- Estimated value (log-transformed)
- Buyer type
- Number of lots
- Region
- Award criteria (lowest price vs best value)

### Analysis
1. **Single-driver tests:** chi-square (categorical drivers) and
   Mann-Whitney U (continuous drivers), Holm-corrected for multiple testing,
   with significance level and correction fixed before seeing results
2. **Logistic regression:** all drivers together, year fixed effects,
   standard errors clustered by tender; results reported as odds ratios
3. **Robustness:** without 2020–2021, 2020–2023 only, at tender level, with
   real lot values only, and without known framework agreements
4. **Prediction test:** train on earlier years, evaluate on a held-out later
   year (AUC)
5. **Missing data:** lots with and without a recorded bid count compared
   by year, procedure, buyer and firm

## Data
- **Opentender Bulgaria** (opentender.eu): compiled from the Bulgarian Public
  Procurement Register and TED (Tenders Electronic Daily)

### Known limitations
- CPV code missing for many tenders from mid-2024: 26% of food records in 2024
  and 52% in 2025 were identified by title keywords
- Bid count missing for 38% of food lots in 2020–2025, rising above 50% in
  2024–2025
- Tender year empty in all source files (taken from the file name)
- Framework-agreement flag blank for about 70% of food records
- The legal ground for negotiated procedures without prior publication is not
  in the data, so that part is descriptive only

### Candidate sources for the extension
- CAP beneficiary lists (State Fund Agriculture)
- Kohesio (EU cohesion-fund projects)
- UMIS (Bulgarian EU-funds information system)

## Tools
- **DuckDB** (via DBeaver): raw CSV processing, food filter and data checks
- **Git / GitHub**

### Next
- **PostgreSQL**: storage, lot-level table, cleaning
- **Python** (pandas, statsmodels, scikit-learn): hypothesis tests and regression
- **Palantir Foundry** (Pipeline Builder)

## Results
*Coming soon.*

## Data licence
Opentender data (opentender.eu) used under the Creative Commons
Attribution-NonCommercial-ShareAlike 4.0 licence (CC BY-NC-SA 4.0).

## Author
Angel Iliev · [LinkedIn](https://www.linkedin.com/in/angel-a-iliev)
