WITH i(x) AS ( VALUES(1) UNION ALL SELECT  +1 FROM i ORDER BY 1)
SELECT LIKE(2001-01-011,1,1) x FROM i LIMIT 30;