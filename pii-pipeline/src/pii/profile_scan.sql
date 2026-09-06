-- Single-column illustration of the content-profiling idea (Part 1, rung 2):
-- what fraction of a column's non-null values look like an email address?
-- The Python module loops this over every column and pattern.
SELECT
  round(avg(
    CASE WHEN regexp_matches(contact_ref, '^[\w.+-]+@[\w-]+\.[\w.]+$')
         THEN 1.0 ELSE 0.0 END
  ), 2) AS email_ratio
FROM 'data/customers.csv'
WHERE contact_ref IS NOT NULL;
