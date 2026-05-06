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

-- =============================================================================
-- 1.2  Newest customer on the 'Kobiye Destek' tariff.
-- We sort by SIGNUP_DATE descending and keep only the top row using
-- FETCH FIRST 1 ROWS ONLY, which is clearer than ROWNUM tricks. Ties on
-- SIGNUP_DATE are broken by CUSTOMER_ID descending, giving a deterministic
-- "most recently inserted" winner per the README hint.
-- =============================================================================
SELECT c.CUSTOMER_ID, c.NAME, c.CITY, c.SIGNUP_DATE
  FROM CUSTOMERS c
  JOIN TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
 WHERE t.NAME = 'Kobiye Destek'
 ORDER BY c.SIGNUP_DATE DESC, c.CUSTOMER_ID DESC
 FETCH FIRST 1 ROWS ONLY;

-- =============================================================================
-- 2.1  Distribution of tariffs among customers.
-- We GROUP BY tariff name and count subscribers, joining via TARIFF_ID so
-- the friendly name is returned. Including the percentage share alongside
-- raw counts makes the distribution easier to read at a glance and is a
-- common ask from product. Ordering by count descending puts the biggest
-- plans on top.
-- =============================================================================
SELECT t.NAME AS TARIFF_NAME,
       COUNT(*) AS CUSTOMER_COUNT,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2) AS PERCENT_SHARE
  FROM CUSTOMERS c
  JOIN TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
 GROUP BY t.NAME
 ORDER BY CUSTOMER_COUNT DESC;

-- =============================================================================
-- 3.1  Earliest customers to sign up.
-- Per the README hint, "earliest" is by SIGNUP_DATE, not by CUSTOMER_ID.
-- We use RANK over SIGNUP_DATE so ties (multiple customers signing up on
-- the very first day) are all returned, not just one of them. Filtering
-- on rank = 1 in the outer query gives the full earliest cohort.
-- =============================================================================
SELECT CUSTOMER_ID, NAME, CITY, SIGNUP_DATE
  FROM (
    SELECT c.CUSTOMER_ID,
           c.NAME,
           c.CITY,
           c.SIGNUP_DATE,
           RANK() OVER (ORDER BY c.SIGNUP_DATE ASC) AS R
      FROM CUSTOMERS c
  )
 WHERE R = 1
 ORDER BY CUSTOMER_ID;

-- =============================================================================
-- 3.2  City distribution of the earliest signup cohort.
-- We reuse the rank-based earliest-cohort definition from 3.1 inside a
-- subquery, then GROUP BY city. This guarantees we count exactly the
-- customers from 3.1 — no risk of drift between the two answers. Ordering
-- by count descending then city alphabetically gives stable, readable output.
-- =============================================================================
SELECT CITY, COUNT(*) AS CUSTOMER_COUNT
  FROM (
    SELECT c.CUSTOMER_ID, c.CITY,
           RANK() OVER (ORDER BY c.SIGNUP_DATE ASC) AS R
      FROM CUSTOMERS c
  )
 WHERE R = 1
 GROUP BY CITY
 ORDER BY CUSTOMER_COUNT DESC, CITY ASC;
