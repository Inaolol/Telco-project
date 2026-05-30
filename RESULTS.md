# Telco Analytics Results

These outputs were captured from Oracle XE after a clean `docker compose down -v && docker compose up -d` reseed. The database service was `XEPDB1`, and the seed loaded `10000` customers, `4` tariffs, and `9950` monthly usage rows.

## Seed Verification

| Table | Rows |
| --- | ---: |
| `CUSTOMERS` | 10000 |
| `TARIFFS` | 4 |
| `MONTHLY_STATS` | 9950 |

Payment statuses are normalized during load, including removal of the CSV carriage-return byte from the final column.

| `PAYMENT_STATUS` | Customers |
| --- | ---: |
| `LATE` | 1497 |
| `PAID` | 6999 |
| `UNPAID` | 1454 |

Invalid payment-status rows: `0`.

## Query Results

### 1.1 Customers subscribed to `Kobiye Destek`

Total customers: `2483`.

Sample output:

| `CUSTOMER_ID` | `NAME` | `CITY` | `SIGNUP_DATE` |
| ---: | --- | --- | --- |
| 15 | Fatih | MUŞ | 2025-10-27 |
| 33 | Fadime | KAYSERİ | 2025-11-19 |
| 34 | Recep | BİLECİK | 2025-04-09 |
| 35 | Özlem | EDİRNE | 2025-09-02 |
| 44 | Hasan | BOLU | 2026-02-25 |

### 1.2 Newest `Kobiye Destek` customer

| `CUSTOMER_ID` | `NAME` | `CITY` | `SIGNUP_DATE` |
| ---: | --- | --- | --- |
| 8295 | Ömer | AFYONKARAHİSAR | 2026-04-05 |

### 2.1 Tariff distribution

| `TARIFF_NAME` | Customers | Percent |
| --- | ---: | ---: |
| `Kurumsal SMS` | 2577 | 25.77 |
| `Genç Dinamik` | 2527 | 25.27 |
| `Kobiye Destek` | 2483 | 24.83 |
| `Çalışan GB` | 2413 | 24.13 |

### 3.1 Earliest signup customers

Earliest signup date: `2025-04-07`.

Customers on that earliest date: `35`.

Sample output:

| `CUSTOMER_ID` | `NAME` | `CITY` | `SIGNUP_DATE` |
| ---: | --- | --- | --- |
| 233 | Halil | BİTLİS | 2025-04-07 |
| 414 | Songül | YOZGAT | 2025-04-07 |
| 587 | Merve | KONYA | 2025-04-07 |
| 613 | Yasemin | YOZGAT | 2025-04-07 |
| 719 | Emine | YALOVA | 2025-04-07 |
| 832 | Ayşe | KIRŞEHİR | 2025-04-07 |
| 1033 | Rabia | GAZİANTEP | 2025-04-07 |
| 1531 | Leyla | İSTANBUL | 2025-04-07 |
| 1721 | Songül | ANTALYA | 2025-04-07 |
| 1966 | Merve | HAKKARİ | 2025-04-07 |

### 3.2 City distribution of earliest signup customers

Top city counts:

| `CITY` | Customers |
| --- | ---: |
| ANTALYA | 2 |
| GAZİANTEP | 2 |
| SAKARYA | 2 |
| YOZGAT | 2 |
| ŞIRNAK | 2 |

The remaining earliest-signup cities each have `1` customer.

### 4.1 Customers with missing `MONTHLY_STATS`

Total customers missing a monthly record: `50`.

Sample output:

| `CUSTOMER_ID` | `NAME` | `CITY` |
| ---: | --- | --- |
| 6 | Fadime | KIRŞEHİR |
| 10 | Hakan | GAZİANTEP |
| 31 | Serkan | SİİRT |
| 39 | Yasemin | MUŞ |
| 45 | Süleyman | KIRIKKALE |
| 81 | Zehra | GİRESUN |
| 116 | Emre | ADANA |
| 136 | Zeynep | AĞRI |
| 140 | Abdullah | İZMİR |
| 156 | Mahmut | NEVŞEHİR |

### 4.2 City distribution of missing monthly records

Top city counts:

| `CITY` | Missing records |
| --- | ---: |
| OSMANIYE | 3 |
| BİTLİS | 2 |
| DENİZLİ | 2 |
| KAYSERİ | 2 |
| KIRIKKALE | 2 |
| MUŞ | 2 |
| NEVŞEHİR | 2 |
| ORDU | 2 |
| SİVAS | 2 |
| İZMİR | 2 |

The remaining affected cities each have `1` missing monthly record.

### 5.1 Customers who used at least 75 percent of their data limit

Total customers: `1880`.

Top sample output:

| `CUSTOMER_ID` | `NAME` | `DATA_USAGE` | `DATA_LIMIT` | `USAGE_PCT` |
| ---: | --- | ---: | ---: | ---: |
| 311 | Fatma | 20476.18 | 20480 | 99.98 |
| 5623 | Meryem | 20476.27 | 20480 | 99.98 |
| 8825 | Ayşe | 20476.31 | 20480 | 99.98 |
| 2770 | Ahmet | 20474.77 | 20480 | 99.97 |
| 666 | Fadime | 10234.05 | 10240 | 99.94 |
| 8960 | Yağmur | 20466.81 | 20480 | 99.94 |
| 6924 | Halil | 20465.87 | 20480 | 99.93 |
| 2655 | Tuğba | 10229.96 | 10240 | 99.90 |
| 4749 | Aynur | 20460.43 | 20480 | 99.90 |
| 3376 | Kübra | 20456.27 | 20480 | 99.88 |

### 5.2 Customers who exhausted all positive package limits

Total customers: `0`.

The query is still useful because it proves no customer in this generated month simultaneously consumed every positive package allowance to 100 percent or more.

### 6.1 Customers with unpaid fees

Total customers with `UNPAID` or `LATE` status: `2951`.

| `PAYMENT_STATUS` | Customers |
| --- | ---: |
| `LATE` | 1497 |
| `UNPAID` | 1454 |

### 6.2 Payment-status distribution across tariffs

| `TARIFF_NAME` | `PAYMENT_STATUS` | Customers |
| --- | --- | ---: |
| `Genç Dinamik` | `LATE` | 372 |
| `Genç Dinamik` | `PAID` | 1792 |
| `Genç Dinamik` | `UNPAID` | 352 |
| `Kobiye Destek` | `LATE` | 392 |
| `Kobiye Destek` | `PAID` | 1719 |
| `Kobiye Destek` | `UNPAID` | 360 |
| `Kurumsal SMS` | `LATE` | 368 |
| `Kurumsal SMS` | `PAID` | 1796 |
| `Kurumsal SMS` | `UNPAID` | 403 |
| `Çalışan GB` | `LATE` | 365 |
| `Çalışan GB` | `PAID` | 1692 |
| `Çalışan GB` | `UNPAID` | 339 |
