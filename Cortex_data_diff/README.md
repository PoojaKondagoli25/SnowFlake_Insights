
# SnowFlake Cortex Data_diff

A compact toolkit and reference for the Snowflake Cortex Agent that automates row-level table comparisons between environments to ensure data consistency and surface mismatches quickly.

## Overview
SnowFlake Cortex data diff agent uses a custom Snowflake stored procedure (SP_DATA_DIFF_JSON) to compare rows using primary keys and produce a single, structured JSON output designed for easy machine and LLM consumption. It reduces manual SQL diff work and speeds up validation across DEV, QA, and PROD.

## Key features
- Row-level comparison using primary keys
- Single JSON output optimized for automated summarization
- Detects missing rows, mismatched values and schema drift
- Easy integration into CI/CD or data validation pipelines

## How it works
1. Specify source and target environments (e.g., DEV vs PROD) and the table(s) to compare.  
2. The SP_DATA_DIFF_JSON stored procedure performs keyed row-by-row comparisons.  
3. Procedure returns a concise JSON summary plus detailed mismatch entries for downstream reporting or automatic remediation.

## Example usage
CALL SP_DATA_DIFF_JSON('<source_db>.<schema>.<table>', '<target_db>.<schema>.<table>', '<primary_key_columns>');

(Adjust procedure signature to your deployment — this is a representative example.)

## Output format (summary)
- summary: high-level counts (rows compared, mismatches, missing rows)
- mismatches: array of objects { primary_key, source_row, target_row, diff_fields }
- metadata: timestamps, source/target identifiers, execution details

## Benefits
- Faster, repeatable data validation across environments  
- Clear, machine-readable results suitable for automated alerts and LLM analysis  
- Reduces human error in manual SQL diffs



