--Load data using copy command
--this mode returns all the error records
COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM @{STAGE_NAME}
    file_format= (type = csv field_delimiter=',' skip_header=1)
    pattern='.*FILE_NAME.*'
    VALIDATION_MODE = RETURN_ERRORS;

-- this mode return first 5 rows
VALIDATION_MODE = RETURN_5_ROWS

--create table to store rejected/failed results
CREATE OR REPLACE TABLE rejected AS 
select rejected_record from table(result_scan(last_query_id()));

-- Adding additional records --
INSERT INTO rejected
select rejected_record from table(result_scan(last_query_id()));

SELECT * FROM rejected;

---Saving rejected files without VALIDATION_MODE ---- 
COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM @{STAGE_NAME}
    file_format= (type = csv field_delimiter=',' skip_header=1)
    pattern='.*Order.*'
    ON_ERROR=CONTINUE;
  
  
select * from table(validate(orders, job_id => '_last'));

---Working with rejected records ---- 

SELECT REJECTED_RECORD FROM rejected;

CREATE OR REPLACE TABLE rejected_values as
SELECT 
SPLIT_PART(rejected_record,',',1) as ORDER_ID, 
SPLIT_PART(rejected_record,',',2) as AMOUNT, 
SPLIT_PART(rejected_record,',',3) as PROFIT, 
SPLIT_PART(rejected_record,',',4) as QUATNTITY, 
SPLIT_PART(rejected_record,',',5) as CATEGORY, 
SPLIT_PART(rejected_record,',',6) as SUBCATEGORY
FROM rejected; 


SELECT * FROM rejected_values;