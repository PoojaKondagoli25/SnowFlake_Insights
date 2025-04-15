--Create a new table to load a data into it
CREATE OR REPLACE TABLE {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME} (
    ORDER_ID VARCHAR(30),
    AMOUNT INT,
    PROFIT INT,
    QUANTITY INT,
    CATEGORY VARCHAR(30),
    SUBCATEGORY VARCHAR(30));

SELECT * FROM {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME};

----------------------------------------------------------------

--Copying data into table from stage
--type=csv : describe the file type
--field_delimiter: columns are seperated by (',') ,('|'),('-') etc
--skip_header=1 : by default the skip header value will be 0, if we dont change then header records will again be pasted in first row

COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM @{STAGE_NAME}
    file_format = (type = csv field_delimiter=',' skip_header=1);

--Copy command with specified file(s)
COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('OrderDetails.csv');

--Copy command with pattern for file names

COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}
    file_format= (type = csv field_delimiter=',' skip_header=1)
    pattern='.*Order.*';





