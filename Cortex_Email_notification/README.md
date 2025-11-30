// ...existing code...
# Snowflake Cortex — Email Notification (Demo Setup)

A concise demo setup for Snowflake Cortex email integration. This README describes the roles, database/schema layout, integrations, and a simple stored procedure for sending emails from agents or apps.

## Prerequisites
- A Snowflake account with the ACCOUNTADMIN role (or equivalent permissions).
- Snowflake access for creating roles, databases, schemas, and integrations.
- SMTP / external email integration configured in your environment (if required).

## High-level components
- Role setup and permissions — create roles and grant least-privilege access.
- Database and schema setup — a dedicated database with schemas per component.
- Agent permissions — roles and grants for the Cortex agents.
- Email integration — integration object(s) and a wrapper stored procedure to send email.

## Role setup and permissions
1. Switch to ACCOUNTADMIN to create roles and grant global privileges.
2. Create roles: e.g., CORTEX_ADMIN, CORTEX_AGENT, CORTEX_USER.
3. Grant role hierarchy and privileges:
   - GRANT ROLE CORTEX_AGENT TO USER <agent_user>;
   - GRANT USAGE ON DATABASE <db> TO ROLE CORTEX_AGENT;
   - GRANT USAGE ON SCHEMA <db>.<schema> TO ROLE CORTEX_AGENT;
   - GRANT SELECT, INSERT, EXECUTE as needed.

## Database and schema setup
- Create a single demo database (e.g., CORTEX_DEMO).
- Create schemas for each major piece, e.g.:
  - cke_core (core logic)
  - cke_agents (agent-related objects)
  - cke_integrations (external integrations like email)

Example:
```sql
CREATE DATABASE IF NOT EXISTS CORTEX_DEMO;
CREATE SCHEMA IF NOT EXISTS CORTEX_DEMO.CKE_INTEGRATIONS;
```

## Email integration
- Configure the Snowflake network integration or external service needed for sending emails.
- Create any required stages or secrets before creating the wrapper procedure.
- Ensure the CORTEX_AGENT role has access to the integration.

## Email sending stored procedure (wrapper)
- Create a stored procedure that encapsulates Snowflake's email send logic to make it callable by agents.
- Keep the procedure lightweight and parameterized (to, subject, body, attachments).

Example usage:
```sql
CALL SEND_CORTEX_EMAIL(
  RECIPIENTS => 'ops@example.com',
  SUBJECT    => 'Cortex Alert: Diff Results',
  BODY       => 'Attached are the results of the last diff run.'
);
```



