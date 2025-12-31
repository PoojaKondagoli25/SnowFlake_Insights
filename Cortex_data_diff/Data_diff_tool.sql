USE ROLE ACCOUNTADMIN;
USE DATABASE DEV_DB;
USE SCHEMA DBT_LEARNING;

CREATE OR REPLACE PROCEDURE SP_DATA_DIFF_COMBINED_JSON(
    DEV_DB_NAME       STRING,
    DEV_SCHEMA_NAME   STRING,
    DEV_TABLE_NAME    STRING,
    PROD_DB_NAME      STRING,
    PROD_SCHEMA_NAME  STRING,
    PROD_TABLE_NAME   STRING,
    PK_COLUMN         STRING       -- e.g. 'CUSTOMER_KEY'
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
AS
$$
    // Build the dynamic diff query (same logic as your SP_DATA_DIFF)
    var sql = `
        WITH dev AS (
            SELECT
                ${PK_COLUMN},
                OBJECT_DELETE(OBJECT_CONSTRUCT(*), '_LOADED_AT') AS dev_obj
            FROM ${DEV_DB_NAME}.${DEV_SCHEMA_NAME}.${DEV_TABLE_NAME}
        ),
        prod AS (
            SELECT
                ${PK_COLUMN},
                OBJECT_DELETE(OBJECT_CONSTRUCT(*), '_LOADED_AT') AS prod_obj
            FROM ${PROD_DB_NAME}.${PROD_SCHEMA_NAME}.${PROD_TABLE_NAME}
        ),
        diff AS (
            SELECT
                CAST(
                    COALESCE(d.${PK_COLUMN}, p.${PK_COLUMN})
                    AS NUMBER(38,0)
                ) AS PK_VALUE,
                CAST(
                    CASE
                        WHEN p.${PK_COLUMN} IS NULL THEN 'ONLY_IN_DEV'
                        WHEN d.${PK_COLUMN} IS NULL THEN 'ONLY_IN_PROD'
                        WHEN MD5(CAST(d.dev_obj AS STRING))
                           <> MD5(CAST(p.prod_obj AS STRING)) THEN 'ROW_DIFFERENT'
                        ELSE 'SAME'
                    END AS VARCHAR
                ) AS DIFF_TYPE,
                d.dev_obj::VARIANT  AS DEV_ROW,
                p.prod_obj::VARIANT AS PROD_ROW
            FROM dev d
            FULL OUTER JOIN prod p
                ON d.${PK_COLUMN} = p.${PK_COLUMN}
        )
        SELECT PK_VALUE, DIFF_TYPE, DEV_ROW, PROD_ROW
        FROM diff
        WHERE DIFF_TYPE <> 'SAME'
        ORDER BY PK_VALUE
    `;

    // Execute the query
    var rs = snowflake.execute({ sqlText: sql });

    // Build JSON array from the resultset
    var resultArray = [];

    while (rs.next()) {
        resultArray.push({
            PK_VALUE : rs.getColumnValue('PK_VALUE'),
            DIFF_TYPE: rs.getColumnValue('DIFF_TYPE'),
            DEV_ROW  : rs.getColumnValue('DEV_ROW'),
            PROD_ROW : rs.getColumnValue('PROD_ROW')
        });
    }

    // Return [] instead of null if no diffs
    return resultArray;
$$;

CALL SP_DATA_DIFF_COMBINED_JSON(
    'DEV_DB',           -- DEV_DB_NAME
    'DBT_LEARNING',     -- DEV_SCHEMA_NAME
    'STG_CUSTOMERS',    -- DEV_TABLE_NAME
    'PROD_DB',          -- PROD_DB_NAME
    'DBT_LEARNING',     -- PROD_SCHEMA_NAME
    'STG_CUSTOMERS',    -- PROD_TABLE_NAME
    'C_CUSTKEY'         -- PK_COLUMN
);

