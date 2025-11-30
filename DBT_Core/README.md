// ...existing code...
# DBT Core — Role & Database Setup (Cortex Data Diff)

Minimal role and database permissions for the Cortex data-diff service user.

Quick steps
- Create service user and set its DEFAULT_ROLE.
- Create roles (e.g., CORTEX_SERVICE, CORTEX_AGENT, CORTEX_ADMIN) and grant role(s) to the service user.
- Grant IMPORTED PRIVILEGES on the shared sample database (db-level).
- Grant USAGE on the warehouse required by the service role.

Minimal example
```sql
CREATE ROLE IF NOT EXISTS CORTEX_SERVICE;
CREATE USER IF NOT EXISTS svc_cortex DEFAULT_ROLE = CORTEX_SERVICE PASSWORD = 'ReplaceMe!';
GRANT ROLE CORTEX_SERVICE TO USER svc_cortex;
GRANT IMPORTED PRIVILEGES ON DATABASE shared_sample_db TO ROLE CORTEX_SERVICE;
GRANT USAGE ON WAREHOUSE WH_CORTEX TO ROLE CORTEX_SERVICE;
```
// ...existing code...