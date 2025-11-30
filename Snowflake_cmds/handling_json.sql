--Create file format object
CREATE OR REPLACE file format {DATABASE_NAME}.{FILE_FORMAT_NAME}.{FORMAT_NAME}
    type = json;

--Create stage object with integration object & file format object
CREATE OR REPLACE stage {DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}
    URL = '(give your s3 url)'
    STORAGE_INTEGRATION = {'give storage integration name'}
    FILE_FORMAT = {DATABASE_NAME}.{FILE_FORMAT_NAME}.{FORMAT_NAME};

--First query from S3 Bucket   

SELECT * FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME};

--Introduce columns 
SELECT 
$1:asin,
$1:helpful,
$1:overall,
$1:reviewText,
$1:reviewTime,
$1:reviewerID,
$1:reviewTime,
$1:reviewerName,
$1:summary,
$1:unixReviewTime
FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME};

--Format columns & use DATE function
--This expression is used to convert a UNIX timestamp (usually in seconds) into a DATE (YYYY-MM-DD format).
SELECT 
$1:asin::STRING as ASIN,
$1:helpful as helpful,
$1:overall as overall,
$1:reviewText::STRING as reviewtext,
$1:reviewTime::STRING,
$1:reviewerID::STRING,
$1:reviewTime::STRING,
$1:reviewerName::STRING,
$1:summary::STRING,
DATE($1:unixReviewTime::int) as Revewtime
FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME};

--Format columns & handle custom date 
--DATE_FROM_PARTS() constructs a valid DATE value from separate YEAR, MONTH, and DAY values.


SELECT 
$1:asin::STRING as ASIN,
$1:helpful as helpful,
$1:overall as overall,
$1:reviewText::STRING as reviewtext,
DATE_FROM_PARTS( <year>, <month>, <day> )
$1:reviewTime::STRING,
$1:reviewerID::STRING,
$1:reviewTime::STRING,
$1:reviewerName::STRING,
$1:summary::STRING,
DATE($1:unixReviewTime::int) as Revewtime
FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME};

--Use DATE_FROM_PARTS and see another difficulty
--You're extracting year, month, and day from a string-formatted date (like '05 20, 2014') in a semi-structured JSON field, and turning it into a proper DATE.
SELECT 
$1:asin::STRING as ASIN,
$1:helpful as helpful,
$1:overall as overall,
$1:reviewText::STRING as reviewtext,
DATE_FROM_PARTS( RIGHT($1:reviewTime::STRING,4), LEFT($1:reviewTime::STRING,2), SUBSTRING($1:reviewTime::STRING,4,2) ),
$1:reviewerID::STRING,
$1:reviewTime::STRING,
$1:reviewerName::STRING,
$1:summary::STRING,
DATE($1:unixReviewTime::int) as unixRevewtime
FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME};

--Use DATE_FROM_PARTS and handle the case difficulty
/*
You're parsing a reviewTime string like:
'05 2, 2014' → Day = 2 (single digit)
'05 20, 2014' → Day = 20 (double digit)
Example 1: '05 2, 2014'
SUBSTRING(5,1) → ',' → so pick just SUBSTRING(4,1) → '2'
Result: DATE_FROM_PARTS(2014, 05, 2) → ✅ 2014-05-02
Example 2: '05 20, 2014'
SUBSTRING(5,1) → '0' (not a comma), so get SUBSTRING(4,2) → '20'
Result: DATE_FROM_PARTS(2014, 05, 20) → ✅ 2014-05-20
*/
SELECT 
$1:asin::STRING as ASIN,
$1:helpful as helpful,
$1:overall as overall,
$1:reviewText::STRING as reviewtext,
DATE_FROM_PARTS( 
  RIGHT($1:reviewTime::STRING,4), 
  LEFT($1:reviewTime::STRING,2), 
  CASE WHEN SUBSTRING($1:reviewTime::STRING,5,1)=',' 
        THEN SUBSTRING($1:reviewTime::STRING,4,1) ELSE SUBSTRING($1:reviewTime::STRING,4,2) END),
$1:reviewerID::STRING,
$1:reviewTime::STRING,
$1:reviewerName::STRING,
$1:summary::STRING,
DATE($1:unixReviewTime::int) as UnixRevewtime
FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME};