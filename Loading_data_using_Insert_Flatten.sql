--The INSERT INTO statement is used in SQL to add new rows of data into a table in a database.
--FLATTEN is a table function in Snowflake that takes a variant, object, or array column and returns a separate row for each element in the array or each key-value pair in an object.
INSERT INTO {TABLE_NAME}
SELECT FILE_NAME:{FIRST_COLUMN_NAME}::{DATA_TYPE} as {FIRST_COLUMN_NAME},
       FILE_NAME:{SECOND_COLUMN_NAME}::{DATA_TYPE} as {SECOND_COLUMN_NAME},
       FILE_NAME:{THIRD_COLUMN_NAME}::{DATA_TYPE} as {THIRD_COLUMN_NAME}
 FROM {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME},TABLE(FLATTEN({FILE_NAME}:{COLUMN_NAME}));

