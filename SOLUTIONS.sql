-- =============================================================================
-- 1.1  Customers subscribed to the 'Kobiye Destek' tariff.
-- We join CUSTOMERS to TARIFFS on TARIFF_ID and filter by the tariff name
-- rather than hard-coding the ID, so the query stays correct if seed order
-- changes. We project the customer-facing fields a service rep would need
-- (id, name, city, signup date) and order by CUSTOMER_ID for stable output.
-- =============================================================================
SELECT c.CUSTOMER_ID, c.NAME, c.CITY, c.SIGNUP_DATE
  FROM CUSTOMERS c
  JOIN TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
 WHERE t.NAME = 'Kobiye Destek'
 ORDER BY c.CUSTOMER_ID;
