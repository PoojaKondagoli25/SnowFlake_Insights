--Create database to manage stage objects, fileformats etc.
CREATE OR REPLACE DATABASE {DATABASE_NAME};

--Create Schema
CREATE OR REPLACE SCHEMA {SCHEMA_NAME};

--Create table
CREATE OR REPLACE TABLE {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME} (
    ORDER_ID VARCHAR(30),
    AMOUNT INT,
    PROFIT INT,
    QUANTITY INT,
    CATEGORY VARCHAR(30),
    SUBCATEGORY VARCHAR(30));

--Creating external stage which is not publically available
CREATE OR REPLACE {DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}
    url='(give s3 bucket url)'
    credentials=(aws_key_id='' aws_secret_key='');

--Alter external stage
ALTER STAGE {STAGE_NAME}
    SET credentials=(aws_key_id='(give aws_key_id)' aws_secret_key='(new aws_secret_key)');

--Publicly accessible staging area    

CREATE OR REPLACE STAGE {DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}
    url='(give the url)';

--Description of external stage
DESC STAGE  {DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME};

--List files in stage
LIST @{STAGE_NAME};




