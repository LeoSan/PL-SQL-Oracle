/* Formatted on 09/02/2018 11:57:05 (QP5 v5.287)   EJJEMPLO  */ 
DECLARE
  dummy   NUMBER;
BEGIN
  SELECT COUNT (1)
    INTO dummy
    FROM pendupm.iaal israel
   WHERE CANTIDAD_LOTE IS NULL;

  WHILE (dummy != 0)
  LOOP
     UPDATE pendupm.iaal israel
        SET CANTIDAD_LOTE =
               (SELECT COUNT (DISTINCT NO_LOTE)
                  FROM PENDUPM.PRORRATEOGASTO pr
                 WHERE pr.ID_GASTO = israel.idgasto)
      WHERE CANTIDAD_LOTE IS NULL AND ROWNUM < 2;

     SELECT COUNT (1)
       INTO dummy
       FROM pendupm.iaal israel
      WHERE CANTIDAD_LOTE IS NULL;

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





