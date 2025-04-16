--Create file format and stage object
/*What is Parquet?
Parquet is a columnar storage file format that's:
Highly efficient for analytical queries 
Compressed and optimized for performance
Commonly used with big data tools like Snowflake, Spark, Hadoop, etc.

Why use Parquet in Snowflake?
Faster query performance for large datasets
Ideal for semi-structured data
Better compression = cheaper storage*/

CREATE OR REPLACE FILE FORMAT {DATABASE_NAME}.{FILE_FORMAT_NAME}.{FORMAT_NAME}
    TYPE='PARQUET';

CREATE OR REPLACE {DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}
    url='(give s3 bucket url)'
    FILE_FORMAT={DATABASE_NAME}.{FILE_FORMAT_NAME}.{FORMAT_NAME}

--Preview the data
LIST @ {DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}

--Syntax for Querying unstructured data
SELECT
    $1:{COLUMN_NAME},
    $1:{COLUMN_NAME},
    $1:"{COLUMN_NAME}",
    $1:{COLUMN_NAME}
FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}

--EXAMPLE
SELECT 
$1:__index_level_0__,
$1:cat_id,
$1:date,
$1:"__index_level_0__",
$1:"cat_id",
$1:"d",
$1:"date",
$1:"dept_id",
$1:"id",
$1:"item_id",
$1:"state_id",
$1:"store_id",
$1:"value"
FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE;

--DATA CONVERSION
--In Snowflake, DATE is a data type that stores calendar date values (year, month, day) in the format:
SELECT 1;

SELECT DATE(365*60*60*24)

--EXAMPLE
SELECT 
$1:__index_level_0__::int as index_level,
$1:cat_id::VARCHAR(50) as category,
DATE($1:date::int ) as Date,
$1:"dept_id"::VARCHAR(50) as Dept_ID,
$1:"id"::VARCHAR(50) as ID,
$1:"item_id"::VARCHAR(50) as Item_ID,
$1:"state_id"::VARCHAR(50) as State_ID,
$1:"store_id"::VARCHAR(50) as Store_ID,
$1:"value"::int as value
FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE;

--ADDING METADATA
--Metadata is data about data, and in Snowflake, it helps you understand what you have, how it’s structured, and how it’s being used.

SELECT 
$1:__index_level_0__::int as index_level,
$1:cat_id::VARCHAR(50) as category,
DATE($1:date::int ) as Date,
$1:"dept_id"::VARCHAR(50) as Dept_ID,
$1:"id"::VARCHAR(50) as ID,
$1:"item_id"::VARCHAR(50) as Item_ID,
$1:"state_id"::VARCHAR(50) as State_ID,
$1:"store_id"::VARCHAR(50) as Store_ID,
$1:"value"::int as value,
METADATA$FILENAME as FILENAME,
METADATA$FILE_ROW_NUMBER as ROWNUMBER,
TO_TIMESTAMP_NTZ(current_timestamp) as LOAD_DATE
FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE;

/*CURRENT_TIMESTAMP returns the current date and time with time zone (type: TIMESTAMP_LTZ).
TO_TIMESTAMP_NTZ() converts that into a TIMESTAMP_NTZ, which:
Keeps the same date and time
Strips out any time zone info
*/

SELECT TO_TIMESTAMP_NTZ(current_timestamp);
