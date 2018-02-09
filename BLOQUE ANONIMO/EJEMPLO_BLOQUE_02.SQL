/* Formatted on 09/02/2018 11:57:05 (QP5 v5.287)   EJEMPLO  */ 
DECLARE
  dummy2   NUMBER;
BEGIN
  SELECT COUNT (1)
    INTO dummy2
    FROM pendupm.iaal israel
   WHERE LOTE IS NULL AND CANTIDAD_LOTE = 1;

  WHILE (dummy2 != 0)
  LOOP
     UPDATE pendupm.iaal israel
        SET LOTE =
               ( SELECT DISTINCT NO_LOTE FROM PENDUPM.PRORRATEOGASTO pr WHERE pr.ID_GASTO = (SELECT IDGASTO FROM pendupm.iaal WHERE CANTIDAD_LOTE = 1 AND IDGASTO = israel.IDGASTO )
               )
                 
      WHERE LOTE IS NULL AND CANTIDAD_LOTE = 1 AND ROWNUM < 2;

     SELECT COUNT (1)
       INTO dummy2
       FROM pendupm.iaal israel
      WHERE LOTE IS NULL AND CANTIDAD_LOTE = 1;

     COMMIT;
  END LOOP;
EXCEPTION
  WHEN NO_DATA_FOUND
  THEN
     NULL;
  WHEN OTHERS
  THEN
     NULL;
END;





