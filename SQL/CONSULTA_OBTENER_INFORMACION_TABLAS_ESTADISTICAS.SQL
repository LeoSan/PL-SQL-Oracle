-- consulta para obtener el analisis de las tablas ultimas estadisticas total de registro por tablas 

select owner, table_name, num_rows, sample_size, last_analyzed,  tablespace_name from ALL_TABLES; 



SELECT  TABLE_NAME, TO_CHAR(last_analyzed, 'DD-MON-YYYY') AS last_analyzed FROM ALL_TABLES WHERE  last_analyzed > '12/11/2017'  GROUP BY   last_analyzed 


SELECT  TABLE_NAME, TRUNC(TO_DATE(last_analyzed,'DD-MM-YY'), 'DD') FROM ALL_TABLES  WHERE  last_analyzed > '12/11/2017'  





SELECT  count(TABLE_NAME) total , TO_CHAR(last_analyzed, 'DD-MON-YYYY') AS last_analyzed FROM ALL_TABLES  WHERE  last_analyzed > '12/11/2017'  GROUP BY  TABLE_NAME, last_analyzed


SELECT owner, TABLE_NAME, TO_CHAR(last_analyzed, 'DD-MON-YYYY') AS last_analyzed FROM ALL_TABLES  WHERE  last_analyzed > '12/11/2017'  GROUP BY owner, TABLE_NAME, last_analyzed ORDER BY last_analyzed


SELECT TO_CHAR(last_analyzed, 'DD-MON-YYYY') AS last_analyzed FROM ALL_TABLES  WHERE  last_analyzed > '15/11/2017'  GROUP BY last_analyzed ORDER BY last_analyzed

SELECT TO_CHAR(last_analyzed, 'DD-MON-YYYY') AS last_analyzed FROM ALL_TABLES  WHERE  last_analyzed > '15/11/2017'  GROUP BY last_analyzed ORDER BY last_analyzed



SELECT  count(TABLE_NAME) total, TO_CHAR(last_analyzed, 'DD-MON-YYYY') AS last_analyzed  FROM ALL_TABLES  WHERE  last_analyzed > '15/11/2017' GROUP BY TO_CHAR(last_analyzed, 'DD-MON-YYYY') AS last_analyzed 

SELECT  count(TABLE_NAME) total_TABLAS  FROM ALL_TABLES  WHERE  last_analyzed > '15/11/2017'


SELECT  count(TABLE_NAME) total, TO_CHAR(last_analyzed, 'DD-MON-YYYY') AS last_analyzed  FROM ALL_TABLES  WHERE  last_analyzed = '15/11/2017' GROUP BY last_analyzed 

SELECT  count(TABLE_NAME) total, TO_CHAR(last_analyzed, 'DD-MON-YYYY') AS last_analyzed  FROM ALL_TABLES  WHERE  last_analyzed = '14/11/2017' GROUP BY last_analyzed



