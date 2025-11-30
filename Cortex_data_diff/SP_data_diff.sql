USE ROLE ACCOUNTADMIN;
USE DATABASE DEV_DB;
USE SCHEMA DBT_LEARNING;


CREATE OR REPLACE PROCEDURE SP_DATA_DIFF(
    DEV_DB_NAME       STRING,
    DEV_SCHEMA_NAME   STRING,
    DEV_TABLE_NAME    STRING,
    PROD_DB_NAME      STRING,
    PROD_SCHEMA_NAME  STRING,
    PROD_TABLE_NAME   STRING,
    PK_COLUMN         STRING       -- e.g. 'CUSTOMER_KEY'
)
RETURNS TABLE (
    PK_VALUE   NUMBER(38,0),
    DIFF_TYPE  VARCHAR,
    DEV_ROW    VARIANT,
    PROD_ROW   VARIANT
)
LANGUAGE SQL
AS
$$
DECLARE
    QUERY STRING;
    RS    RESULTSET;
BEGIN
    QUERY := '
        WITH dev AS (
            SELECT
                ' || PK_COLUMN || ',
                OBJECT_DELETE(OBJECT_CONSTRUCT(*), ''_LOADED_AT'') AS dev_obj
            FROM ' || DEV_DB_NAME || '.' || DEV_SCHEMA_NAME || '.' || DEV_TABLE_NAME || '
        ),
        prod AS (
            SELECT
                ' || PK_COLUMN || ',
                OBJECT_DELETE(OBJECT_CONSTRUCT(*), ''_LOADED_AT'') AS prod_obj
            FROM ' || PROD_DB_NAME || '.' || PROD_SCHEMA_NAME || '.' || PROD_TABLE_NAME || '
        ),
        diff AS (
            SELECT
                CAST(
                    COALESCE(d.' || PK_COLUMN || ', p.' || PK_COLUMN || ')
                    AS NUMBER(38,0)
                ) AS PK_VALUE,
                CAST(
                    CASE
                        WHEN p.' || PK_COLUMN || ' IS NULL THEN ''ONLY_IN_DEV''
                        WHEN d.' || PK_COLUMN || ' IS NULL THEN ''ONLY_IN_PROD''
                        WHEN MD5(CAST(d.dev_obj AS STRING))
                           <> MD5(CAST(p.prod_obj AS STRING)) THEN ''ROW_DIFFERENT''
                        ELSE ''SAME''
                    END AS VARCHAR
                ) AS DIFF_TYPE,
                d.dev_obj::VARIANT  AS DEV_ROW,
                p.prod_obj::VARIANT AS PROD_ROW
            FROM dev d
            FULL OUTER JOIN prod p
                ON d.' || PK_COLUMN || ' = p.' || PK_COLUMN || '
        )
        SELECT PK_VALUE, DIFF_TYPE, DEV_ROW, PROD_ROW
        FROM diff
        WHERE DIFF_TYPE <> ''SAME''
        ORDER BY PK_VALUE
    ';

    RS := (EXECUTE IMMEDIATE :QUERY);

    RETURN TABLE(RS);
END;
$$;


CALL SP_DATA_DIFF(
    'DEV_DB',           -- DEV_DB_NAME
    'DBT_LEARNING',     -- DEV_SCHEMA_NAME
    'STG_CUSTOMERS',    -- DEV_TABLE_NAME
    'PROD_DB',          -- PROD_DB_NAME
    'DBT_LEARNING',     -- PROD_SCHEMA_NAME
    'STG_CUSTOMERS',    -- PROD_TABLE_NAME
    'CUSTOMER_KEY'     -- PK_COLUMN
);


CREATE OR REPLACE PROCEDURE SP_DATA_DIFF_JSON(
    DEV_DB_NAME       STRING,
    DEV_SCHEMA_NAME   STRING,
    DEV_TABLE_NAME    STRING,
    PROD_DB_NAME      STRING,
    PROD_SCHEMA_NAME  STRING,
    PROD_TABLE_NAME   STRING,
    PK_COLUMN         STRING
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
AS
$$
    // Call the SQL procedure and fetch its resultset
    var rs = snowflake.execute({
        sqlText: `
            SELECT *
            FROM TABLE(
                SP_DATA_DIFF(
                    '${DEV_DB_NAME}',
                    '${DEV_SCHEMA_NAME}',
                    '${DEV_TABLE_NAME}',
                    '${PROD_DB_NAME}',
                    '${PROD_SCHEMA_NAME}',
                    '${PROD_TABLE_NAME}',
                    '${PK_COLUMN}'
                )
            )
        `
    });

    // Build a JSON array
    var resultArray = [];

    while (rs.next()) {
        resultArray.push({
            pk_value : rs.getColumnValue('PK_VALUE'),
            diff_type: rs.getColumnValue('DIFF_TYPE'),
            dev_row  : rs.getColumnValue('DEV_ROW'),
            prod_row : rs.getColumnValue('PROD_ROW')
        });
    }

    // Return the JSON array as VARIANT
    return resultArray;
$$;

CALL SP_DATA_DIFF_JSON(
    'DEV_DB','DBT_LEARNING','STG_CUSTOMERS',
    'PROD_DB','DBT_LEARNING','STG_CUSTOMERS',
    'CUSTOMER_KEY'
);


update DEV_DB.DBT_LEARNING.CUSTOMER
set c_address ='Denton'
where C_custkey='2';

select * from DEV_DB.DBT_LEARNING.STG_CUSTOMERS
where customer_key=2;

--agent prompt
/*
compare dev and prod tables data difference

    'DEV_DB','DBT_LEARNING','STG_CUSTOMERS',
    'PROD_DB','DBT_LEARNING','STG_CUSTOMERS',
    'CUSTOMER_KEY'
*/