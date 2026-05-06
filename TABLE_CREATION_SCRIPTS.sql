-- Tariff/plan definitions. Master data for what each plan offers.
CREATE TABLE TARIFFS (
  TARIFF_ID      NUMBER(4)        PRIMARY KEY,
  NAME           VARCHAR2(100)    NOT NULL,
  MONTHLY_FEE    NUMBER(10,2)     NOT NULL CHECK (MONTHLY_FEE >= 0),
  DATA_LIMIT     NUMBER(10)       NOT NULL CHECK (DATA_LIMIT >= 0),
  MINUTE_LIMIT   NUMBER(10)       NOT NULL CHECK (MINUTE_LIMIT >= 0),
  SMS_LIMIT      NUMBER(10)       NOT NULL CHECK (SMS_LIMIT >= 0)
);
