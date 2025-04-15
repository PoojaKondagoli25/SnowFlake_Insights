--Example 1 - Table

CREATE OR REPLACE TABLE {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME} (
    ORDER_ID VARCHAR(30),
    AMOUNT INT
    );

--Transforming using the SELECT statement, selecting only required column using $1 ,$2

COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM (select s.$1, s.$2 from @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME} s)
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files=('{FILE_NAME}.csv');

--Example 2 - Table    

CREATE OR REPLACE TABLE {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME} (
    ORDER_ID VARCHAR(30),
    AMOUNT INT,
    PROFIT INT,
    PROFITABLE_FLAG VARCHAR(30)
    );

--Copy Command using a SQL CASE statement (subset of functions available)

COPY INTO  {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM (select 
            s.$1,
            s.$2, 
            s.$3,
            CASE WHEN CAST(s.$3 as int) < 0 THEN 'not profitable' ELSE 'profitable' END 
          from @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}  s)
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files=('{FILE_NAME}.csv');

--Example 3 - Table

CREATE OR REPLACE TABLE {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}(
    ORDER_ID VARCHAR(30),
    AMOUNT INT,
    PROFIT INT,
    CATEGORY_SUBSTRING VARCHAR(5)
    );

--Example 3 - Copy Command using a SQL SUBSTRING function( in this example new column will be created by extracting first 5 letters of the word) (subset of functions available)

COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM (select 
            s.$1,
            s.$2, 
            s.$3,
            substring(s.$5,1,5) 
          from @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME} s)
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files=('{FILE_NAME}.csv');

--Example 4 - Table

CREATE OR REPLACE TABLE {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}(
    ORDER_ID VARCHAR(30),
    AMOUNT INT,
    PROFIT INT,
    PROFITABLE_FLAG VARCHAR(30)
    );

--Example 4 - Using subset of columns: we can mention the column names in which we can load data

COPY INTO  {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME} (ORDER_ID,PROFIT)
    FROM (select 
            s.$1,
            s.$3
          from @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}  s)
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files=('{FILE_NAME}.csv');

--Example 5 - Table Auto increment

CREATE OR REPLACE TABLE {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}  (
    ORDER_ID number autoincrement start 1 increment 1,
    AMOUNT INT,
    PROFIT INT,
    PROFITABLE_FLAG VARCHAR(30)
    );

--Example 5 - Auto increment ID

COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}  (PROFIT,AMOUNT)
    FROM (select 
            s.$2,
            s.$3
          from @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME} s)
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files=('OrderDetails.csv');


SELECT * FROM {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}  WHERE ORDER_ID > 15;





