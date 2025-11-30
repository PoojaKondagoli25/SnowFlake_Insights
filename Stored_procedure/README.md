# Stored Procedures — Quick Reference

## What is a Stored Procedure?
A reusable block of code stored in the database that encapsulates business logic and can be executed on demand.

## Creating Stored Procedures

### SQL
```sql
CREATE OR REPLACE PROCEDURE sp_hello()
RETURNS STRING
LANGUAGE SQL
AS $$ SELECT 'Hello'; $$;
```

### Python
```sql
CREATE OR REPLACE PROCEDURE sp_python()
LANGUAGE PYTHON
RUNTIME_VERSION = '3.8'
AS $$ def main(): return "Hello" $$;
```

### Java
```sql
CREATE OR REPLACE PROCEDURE sp_java()
LANGUAGE JAVA
RUNTIME_VERSION = '11'
AS $$ class Hello { public static String main() { return "Hello"; } } $$;
```

## Arguments in Stored Procedures
```sql
CREATE OR REPLACE PROCEDURE sp_calc(price NUMBER, quantity NUMBER, OUT total NUMBER)
RETURNS NUMBER
LANGUAGE SQL
AS $$ BEGIN total := price * quantity; END; $$;
```

## Bind Variables in SQL Statements
Use `:variable_name` for parameterized queries to prevent SQL injection.
```sql
SELECT * FROM customers WHERE id = :customer_id;
```

## Loop Through Results & Execute Statements
```sql
CREATE OR REPLACE PROCEDURE sp_process()
LANGUAGE SQL
AS $$
  DECLARE result_set RESULTSET DEFAULT (SELECT order_id FROM orders);
  BEGIN
    FOR record IN result_set DO
      UPDATE orders SET status = 'processed' WHERE id = record.order_id;
    END FOR;
  END;
$$;
```
// ...existing code...