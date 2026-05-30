-- Snapshot tariff limits/fee onto each MONTHLY_STATS row (see ADR-0001).
MERGE INTO MONTHLY_STATS m
USING (
  SELECT c.CUSTOMER_ID,
         t.DATA_LIMIT,
         t.MINUTE_LIMIT  AS MINUTES_LIMIT,
         t.SMS_LIMIT,
         t.MONTHLY_FEE
    FROM CUSTOMERS c
    JOIN TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
) src
ON (m.CUSTOMER_ID = src.CUSTOMER_ID)
WHEN MATCHED THEN UPDATE SET
  m.DATA_LIMIT     = src.DATA_LIMIT,
  m.MINUTES_LIMIT  = src.MINUTES_LIMIT,
  m.SMS_LIMIT      = src.SMS_LIMIT,
  m.MONTHLY_FEE    = src.MONTHLY_FEE;

COMMIT;

DECLARE
  v_bad_status_count NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_bad_status_count
    FROM MONTHLY_STATS
   WHERE PAYMENT_STATUS NOT IN ('PAID', 'UNPAID', 'LATE');

  IF v_bad_status_count > 0 THEN
    RAISE_APPLICATION_ERROR(
      -20001,
      'MONTHLY_STATS contains invalid PAYMENT_STATUS values: ' || v_bad_status_count
    );
  END IF;
END;
/

EXIT;
