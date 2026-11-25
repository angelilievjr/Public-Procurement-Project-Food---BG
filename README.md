# Public Food Procurement in Bulgaria: Single-Bid Tender Prediction

**Status:** work in progress (data preparation)

## Main Goal
Identify which features of a Bulgarian public food tender predict that it will
receive only one bid, using only information available *before* the tender is
published, so that risky tenders can be flagged at the design stage.

### Planned extension
Test whether food producers and processors that win single-bid tenders also
receive EU subsidies.

## Methods

### Scope
- **Period:** 2020–2025 (2020–2021 flagged as COVID years)
- **Food tenders:** CPV division 15 (excluding tobacco and alcohol) plus
  catering services (CPV 555), with a Bulgarian title-keyword fallback where
  the CPV code is missing
- **Excluded:** negotiated procedures without prior publication (single-bid by
  design; described separately), cancelled lots, lots with zero bids

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
   Mann-Whitney U (continuous drivers), Holm-corrected for multiple testing
2. **Logistic regression:** all drivers together, year fixed effects,
   standard errors clustered by tender; results reported as odds ratios
3. **Robustness:** re-estimated without 2020–2021 and at tender level
4. **Prediction test:** trained on 2020–2024, evaluated on 2025 (AUC)
5. **Missing data:** lots with and without a recorded bid count compared
   by year, procedure, buyer and firm

## Data
- **Opentender Bulgaria** (opentender.eu): compiled from the Bulgarian Public
  Procurement Register and TED (Tenders Electronic Daily)

### Known limitations
- CPV code missing for ~half of tenders from mid-2024 (keyword fallback used)
- Bid count missing for ~1/3 of lots
- Tender year missing in the 2025 file (rebuilt from dates)

### Candidate sources for the extension
- CAP beneficiary lists (State Fund Agriculture)
- Kohesio (EU cohesion-fund projects)
- UMIS (Bulgarian EU-funds information system)

## Tools
- **DuckDB** (via DBeaver): raw CSV processing
- **PostgreSQL**: storage, lot-level aggregation, cleaning
- **Python**: hypothesis tests and regression
- **Git / GitHub**

### Planned
- **Palantir Foundry** (Pipeline Builder)

## Results
*Coming soon.*

## Data licence
Opentender data used under its published licence. See opentender.eu.
