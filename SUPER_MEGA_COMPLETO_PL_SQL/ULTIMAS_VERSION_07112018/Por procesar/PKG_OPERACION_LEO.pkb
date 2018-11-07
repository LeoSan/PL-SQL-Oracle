CREATE OR REPLACE PACKAGE BODY OPERACION.PKG_OPERACION_LEO
AS
/******************************************************************************
      NAME:       PKG_PV_COBRANZA
      REVISIONS:
      Ver           Date                    Author           Description
      ---------  ----------         ---------------  ------------------------------------
      1.0           2018-09-28           Ljcuenca     se crea el paquete para mantener la funcionalidad de la interfaz de cobranza para el sistema de plan de viajes
******************************************************************************/

PROCEDURE SP_REPORTE_22_B(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER)

    IS
         consulta            CLOB;
         v_error             VARCHAR2(2000);
         V_FECHAS_INTERVALOS VARCHAR2(10000);
         v_Categorias        VARCHAR2(20);  
         indexInc            INTEGER;
         V_COLLATERALVALUE   FLOAT;
         
        
        CURSOR intervalos_cur  IS
                SELECT
                  A.ID_PRESUPUESTO 
                , A.NUMEROCUENTA
                , A.COLLATERALVALUE
                , A.ESTATUS  
                , B.ETIQUETA
                , B.ID_RECORD ID_PERIODO
                , A.ID_RECORD ID_BASE_CREDITO_REO
                , B.CONSECUTIVO 
                FROM OPERACION.PPTO_BASE_CREDITOS_REO A 
                INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                WHERE A.ID_PRESUPUESTO = P_PRESUPUESTO  /* AND  ROWNUM < 500*/
                ORDER BY A.NUMEROCUENTA, B.ID_RECORD ASC;
                
                         
        TYPE ARREGLOS_INTERVALOS
        IS RECORD (
        rNUMEROCUENTA     VARCHAR2(100),                   
        rID_PRESUPUESTO   INTEGER,
        rETIQUETA         VARCHAR2(100),         
        rCOLLATERALVALUE  FLOAT,
        rID_RECORD        INTEGER,
        rID_BASE_CREDITO  INTEGER
        );

        TYPE TABINTERVALOS IS TABLE OF ARREGLOS_INTERVALOS INDEX BY BINARY_INTEGER;
        
        psDetalle TABINTERVALOS; 

                

    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
        indexInc := 1;
        
        -- Recorremos el cursor con un bucle for - loop
            for u in intervalos_cur loop
             -- OBTENGO EL VALOR DE COLLATERAL POR CUENTAS 
             
             SELECT COLLATERALVALUE INTO V_COLLATERALVALUE FROM OPERACION.PPTO_BASE_CREDITOS_REO WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND NUMEROCUENTA = u.NUMEROCUENTA;
            
              
                IF ( u.CONSECUTIVO = 2 ) THEN
                
                    psDetalle(indexInc).rCOLLATERALVALUE := V_COLLATERALVALUE;                    
                    
                ELSE    
                    psDetalle(indexInc).rCOLLATERALVALUE := psDetalle(indexInc - 1).rCOLLATERALVALUE;
                
                END IF;
                              
               -- MUESTRA EL DETALLE
              /*  consulta := 'INSERT INTO OPERACION.PPTO_PERIODO_BASECREDITOS   (ID_RECORD, ID_PRESUPUESTO, ID_BASE_CREDITO_REO, ID_PERIODO_MES, ORDEN, NOMBRE_AGRUPADOR, VALOR) VALUES  (OPERACION.PPTO_SEQ_PERIODO_BASECREDITOS.NEXTVAL, ' ||  u.ID_PRESUPUESTO || ', '||  u.ID_BASE_CREDITO_REO  ||' , '|| u.ID_PERIODO || ', 99, ''22.B.1'', '|| psDetalle(indexInc).rCOLLATERALVALUE||');';
                  
                 DBMS_OUTPUT.PUT_LINE ( indexInc ||  ' Insert  ->  ' || consulta);  
                 
                 DBMS_OUTPUT.PUT_LINE ( consulta);
              */

                -- insert masivo 
                 INSERT INTO OPERACION.PPTO_PERIODO_BASECREDITOS   (ID_RECORD, ID_PRESUPUESTO, ID_BASE_CREDITO_REO, ID_PERIODO_MES, ORDEN, NOMBRE_AGRUPADOR, VALOR) VALUES (OPERACION.PPTO_SEQ_PERIODO_BASECREDITOS.NEXTVAL,  u.ID_PRESUPUESTO,  u.ID_BASE_CREDITO_REO,  u.ID_PERIODO , 99, '22.B.1', psDetalle(indexInc).rCOLLATERALVALUE );

                indexInc := indexInc + 1;
                
            end loop; 
        -- Fin bucle
        
           
     COMMIT;
     --- OBTIENE  muestra de los valores  
      BEGIN
           SELECT  CHR(39) || LISTAGG(ETIQUETA, ''',''')  WITHIN GROUP (ORDER BY ID_RECORD) || CHR(39)  ETIQUETA  INTO V_FECHAS_INTERVALOS FROM OPERACION.PPTO_PERIODO_ANIO_MES WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ID_RECORD > 1;
            
       EXCEPTION WHEN OTHERS THEN
            v_error := SQLERRM;
            --LLENO MI VARIABLE(CURSOR) DE SALIDA
            OPEN psSalida FOR
                SELECT  -1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO EN PASO 1: '|| v_error);
       END;
 
        DBMS_OUTPUT.PUT_LINE('-->> GENERO REPORTE  << -- ');

        --- OBTIENE  LA FORMA DEL REPORTE CON PIVOT  PASO 2    
        consulta := 'SELECT * FROM (
                                    SELECT C.NUMEROCUENTA, B.ETIQUETA, C.ESTATUS, C.COLLATERALVALUE,   SUM(A.VALOR) TOTAL 
                                    FROM OPERACION.PPTO_PERIODO_BASECREDITOS A 
                                    INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_RECORD = A.ID_PERIODO_MES
                                    INNER JOIN OPERACION.PPTO_BASE_CREDITOS_REO C ON C.ID_RECORD =  A.ID_BASE_CREDITO_REO
                                    WHERE A.ID_PRESUPUESTO = ' || P_PRESUPUESTO || ' AND  A.NOMBRE_AGRUPADOR = ''22.B.1'' GROUP BY C.NUMEROCUENTA, C.ESTATUS, C.COLLATERALVALUE, B.ETIQUETA  
                                    )PIV
                                    PIVOT (  MAX(TOTAL) FOR ETIQUETA IN ('|| V_FECHAS_INTERVALOS ||'))';
                                    
                                    
      COMMIT;
      
      DBMS_OUTPUT.PUT_LINE ( consulta);
         
      OPEN psSalida FOR consulta;
               
    /*FORMA DE LLENAR EL ARREGLO DE SALIDA*/
    DBMS_OUTPUT.PUT_LINE('-->> Proceso finalizado << -- ');

    EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SQLERRM;
         OPEN psSalida FOR
                SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO  EXCEPTION (OTHERS) : '|| v_error || consulta );

    END SP_REPORTE_22_B;



PROCEDURE SP_REPORTE_22_A(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER)

    IS
         consulta            CLOB;
         v_error             VARCHAR2(2000);
         V_FECHAS_INTERVALOS VARCHAR2(10000);
         indexInc            INTEGER;
         V_INSERT_AGRUPADOR  VARCHAR2(10);
 
         V_TOTAL_CUENTAS     FLOAT;   -- CALCULO  1 
         V_SUPUESTO          FLOAT;   -- CALCULO  2
         V_RESP              NUMBER; 
         
         
        CURSOR calculos_cur IS
                  SELECT B.ID_RECORD ID_PERIODO

                      , CASE 
                       WHEN C2.VALOR IS NULL  THEN 0
                       ELSE C2.VALOR  END CALCULO_1
                      
                      , CASE 
                       WHEN C1.VALOR IS NULL  THEN 0
                       ELSE C1.VALOR  END CALCULO_2
                       
                      , CASE 
                       WHEN C5.VALOR IS NULL  THEN 0
                       ELSE C5.VALOR  END CALCULO_3
                       
                      , CASE 
                       WHEN C2.VALOR  <= (SELECT COUNT(ID_RECORD) TOTAL  FROM OPERACION.PPTO_BASE_CREDITOS_REO WHERE ID_PRESUPUESTO = P_PRESUPUESTO)  THEN (C2.VALOR * AVG(C2.VALOR) )
                       ELSE (((SELECT COUNT(ID_RECORD) TOTAL  FROM OPERACION.PPTO_BASE_CREDITOS_REO WHERE ID_PRESUPUESTO = P_PRESUPUESTO) * AVG(C2.VALOR)) + ( C2.VALOR  - (SELECT COUNT(ID_RECORD) TOTAL  FROM OPERACION.PPTO_BASE_CREDITOS_REO WHERE ID_PRESUPUESTO = P_PRESUPUESTO) ) * (SELECT PORCENTAJE FROM OPERACION.PPTO_RESUMEN_CREDITOS WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ORDEN = 4)  ) END CALCULO_4
                      
                      , CASE 
                       WHEN C3.VALOR IS NULL  THEN 0
                       ELSE C3.VALOR * (SELECT PORCENTAJE FROM OPERACION.PPTO_RESUMEN_CREDITOS WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ORDEN = 4)  END CALCULO_5
                       
                      , CASE 
                       WHEN C4.VALOR  < 0.5  THEN 0
                       ELSE 
                       
                            CASE  
                                WHEN (C2.VALOR - ( CASE WHEN C2.VALOR  <= (SELECT COUNT(ID_RECORD) TOTAL  FROM OPERACION.PPTO_BASE_CREDITOS_REO WHERE ID_PRESUPUESTO = P_PRESUPUESTO)  THEN (C2.VALOR * AVG(C2.VALOR) ) ELSE (((SELECT COUNT(ID_RECORD) TOTAL  FROM OPERACION.PPTO_BASE_CREDITOS_REO WHERE ID_PRESUPUESTO = P_PRESUPUESTO) * AVG(C2.VALOR)) + ( C2.VALOR  - (SELECT COUNT(ID_RECORD) TOTAL  FROM OPERACION.PPTO_BASE_CREDITOS_REO WHERE ID_PRESUPUESTO = P_PRESUPUESTO) ) * (SELECT PORCENTAJE FROM OPERACION.PPTO_RESUMEN_CREDITOS WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ORDEN = 4)  ) END  +  CASE  WHEN C3.VALOR IS NULL  THEN 0 ELSE C3.VALOR * (SELECT PORCENTAJE FROM OPERACION.PPTO_RESUMEN_CREDITOS WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ORDEN = 4)  END  ) ) < 0  THEN 0
                                ELSE 
                                 (C2.VALOR - ( CASE WHEN C2.VALOR  <= (SELECT COUNT(ID_RECORD) TOTAL  FROM OPERACION.PPTO_BASE_CREDITOS_REO WHERE ID_PRESUPUESTO = P_PRESUPUESTO)  THEN (C2.VALOR * AVG(C2.VALOR) ) ELSE (((SELECT COUNT(ID_RECORD) TOTAL  FROM OPERACION.PPTO_BASE_CREDITOS_REO WHERE ID_PRESUPUESTO = P_PRESUPUESTO) * AVG(C2.VALOR)) + ( C2.VALOR  - (SELECT COUNT(ID_RECORD) TOTAL  FROM OPERACION.PPTO_BASE_CREDITOS_REO WHERE ID_PRESUPUESTO = P_PRESUPUESTO) ) * (SELECT PORCENTAJE FROM OPERACION.PPTO_RESUMEN_CREDITOS WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ORDEN = 4)  ) END  +  CASE  WHEN C3.VALOR IS NULL  THEN 0 ELSE C3.VALOR * (SELECT PORCENTAJE FROM OPERACION.PPTO_RESUMEN_CREDITOS WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ORDEN = 4)  END  ) ) 
                            END 
                       
                        END CALCULO_6
                       
                  FROM OPERACION.PPTO_BASE_CREDITOS_REO A 
                      INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B  ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.D.1' AND ORDEN = 6)  C1
                         ON C1.ID_PERIODO_MES = B.ID_RECORD
                       
                      LEFT JOIN (SELECT ID_PERIODO_MES, SUM(VALOR) VALOR
                              FROM OPERACION.PPTO_PERIODO_BASECREDITOS 
                             WHERE NOMBRE_AGRUPADOR = '22.B.1' GROUP BY  ID_PERIODO_MES )  C2
                         ON C2.ID_PERIODO_MES = B.ID_RECORD
                         
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.D.1' AND ORDEN = 2)  C3
                         ON C3.ID_PERIODO_MES = B.ID_RECORD
                         
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.D.1' AND ORDEN = 11)  C4
                         ON C4.ID_PERIODO_MES = B.ID_RECORD
                         
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.D.1' AND ORDEN = 6)  C5
                         ON C5.ID_PERIODO_MES = B.ID_RECORD
                         
                      WHERE A.ID_PRESUPUESTO = P_PRESUPUESTO 
                      GROUP BY B.ID_RECORD 
                       , C1.VALOR
                       , C2.VALOR
                       , C3.VALOR
                       , C4.VALOR
                       , C5.VALOR
                      ORDER BY B.ID_RECORD; 
                
                         
        TYPE ARREGLOS_INTERVALOS
        IS RECORD (
            rACUMULA          FLOAT         -- VAR PARA CALCULO 3
        );

        TYPE TABINTERVALOS IS TABLE OF ARREGLOS_INTERVALOS INDEX BY BINARY_INTEGER;
        
        psDetalle TABINTERVALOS; 


    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
        -- DECLARACION DE VARIABLES 
        indexInc := 1;
        V_INSERT_AGRUPADOR := '22.A.1';
 
        
        -- Recorremos el cursor con un bucle for - loop
            for u in calculos_cur loop
         
                    -- PASO 3 - CALCULO  Ventas REO Acumuladas - 3 -
                    IF (indexInc = 1 ) THEN
                    
                        psDetalle(indexInc).rACUMULA := u.CALCULO_3;
                        
                    ELSE    
                        psDetalle(indexInc).rACUMULA := u.CALCULO_3 + psDetalle( indexInc - 1 ).rACUMULA;
                    
                    END IF;
        
                     OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 1, u.CALCULO_1);
                     OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 2, u.CALCULO_2);
                     OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 3, psDetalle(indexInc).rACUMULA);
                     OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 4, u.CALCULO_4);
                     OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 5, u.CALCULO_5);
                     OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 6, u.CALCULO_6);
             
                indexInc := indexInc + 1;
                
            end loop; 
       -- Fin bucle
           
       
      BEGIN
      
      DBMS_OUTPUT.PUT_LINE('-->> GENERO EL REPORTE   << -- ');
            
            SELECT  CHR(39) || LISTAGG(ETIQUETA, ''',''')  WITHIN GROUP (ORDER BY ID_RECORD) || CHR(39)  ETIQUETA  INTO V_FECHAS_INTERVALOS FROM OPERACION.PPTO_PERIODO_ANIO_MES WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ID_RECORD > 1;
               
            consulta := 'SELECT * FROM (
                                            SELECT NOMBRE_SUPUESTOS, ETIQUETA, VALOR  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO A 
                                            INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_RECORD = A.ID_PERIODO_MES
                                            WHERE CLAVE_AGRUPADOR = ''22.A.1'' AND ORDEN IN (1,2,3,4,5,6) order by ORDEN ASC  
                                        )PIV
                                        PIVOT ( MAX(VALOR) FOR ETIQUETA IN (' || V_FECHAS_INTERVALOS || '))';
             
             
           --  consulta := 'SELECT 1 FROM DUAL';
                    
            OPEN psSalida FOR consulta;
            
            DBMS_OUTPUT.PUT_LINE ( consulta);
            
       EXCEPTION WHEN OTHERS THEN
            v_error := SQLERRM;
            OPEN psSalida FOR
                SELECT  -1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
            DBMS_OUTPUT.PUT_LINE ('ERROR PASO 7 - GENERAR REPORTE : '|| v_error);
       END;
 
    DBMS_OUTPUT.PUT_LINE('-->> Proceso finalizado << -- ');
    COMMIT;
    EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SQLERRM;
         OPEN psSalida FOR
                SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO  EXCEPTION (OTHERS) : '|| v_error || consulta );

    END SP_REPORTE_22_A;


PROCEDURE SP_REPORTE_14_D(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER)

    IS
         consulta            CLOB;
         v_error             VARCHAR2(2000);
         V_FECHAS_INTERVALOS VARCHAR2(10000);
         indexInc            INTEGER;
         V_TOTAL_CUENTAS     INTEGER;
         V_CLAVE_AGRUPADOR   VARCHAR2(10); 
         V_INSERT_AGRUPADOR  VARCHAR2(10);
         V_RESP              NUMBER; 
         
         CURSOR intervalos_cur  IS
                    SELECT B.ID_RECORD ID_PERIODO
                    , (C1.VALOR + D1.VALOR) AS CALCULO_2
                    , (C1.VALOR ) AS CALCULO_3
                    , (D1.VALOR ) AS CALCULO_4 
                    , (C4.VALOR ) AS CALCULO_6
                    , (C5.VALOR ) AS CALCULO_7
                    , (C6.VALOR ) AS CALCULO_8
                    , (C7.VALOR ) AS CALCULO_9

                     FROM OPERACION.PPTO_BASE_CREDITOS_REO A
                          INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B
                             ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.C.1' AND ORDEN = 15) C1
                             ON C1.ID_PERIODO_MES = B.ID_RECORD
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.C.1' AND ORDEN = 16) D1
                             ON D1.ID_PERIODO_MES = B.ID_RECORD
                             
                          LEFT JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '15.C.1' AND ORDEN = 1) C4
                             ON C4.ID_PERIODO_MES = B.ID_RECORD

                         LEFT JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '15.C.1' AND ORDEN = 2) C5
                             ON C5.ID_PERIODO_MES = B.ID_RECORD

                         LEFT  JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '15.C.1' AND ORDEN = 3) C6
                             ON C6.ID_PERIODO_MES = B.ID_RECORD
                             
                        LEFT  JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '15.C.1' AND ORDEN = 4) C7
                             ON C7.ID_PERIODO_MES = B.ID_RECORD

                    WHERE A.ID_PRESUPUESTO = P_PRESUPUESTO
                    GROUP BY B.ID_RECORD
                    , C1.VALOR, D1.VALOR
                    , C4.VALOR
                    , C5.VALOR
                    , C6.VALOR
                    , C7.VALOR
                    ORDER BY B.ID_RECORD;   
                
    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');

        -- DECLARACION DE VARIABLES 
         V_INSERT_AGRUPADOR := '14.D.1';
          SELECT COUNT(ID_RECORD) INTO V_TOTAL_CUENTAS FROM OPERACION.PPTO_BASE_CREDITOS_REO WHERE ID_PRESUPUESTO = P_PRESUPUESTO;
       
         for u in intervalos_cur loop
                -- CALCULO  PASO 1
                --INSERT DE CALCULOS 
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 1, V_TOTAL_CUENTAS);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 2, u.CALCULO_2);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 3, u.CALCULO_3);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 4, u.CALCULO_4);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 5, 0);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 6, ( u.CALCULO_6 + u.CALCULO_7 + u.CALCULO_8 + u.CALCULO_9 )  );
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 7, u.CALCULO_6);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 8, u.CALCULO_7);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 9, u.CALCULO_8);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 10, u.CALCULO_9);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 11, V_TOTAL_CUENTAS + ( u.CALCULO_2 - (( u.CALCULO_6 + u.CALCULO_7 + u.CALCULO_8 + u.CALCULO_9 )) ) );
            end loop; 
        -- Fin bucle
     COMMIT;
     --- OBTIENE  muestra de los valores  
      BEGIN
           SELECT  CHR(39) || LISTAGG(ETIQUETA, ''',''')  WITHIN GROUP (ORDER BY ID_RECORD) || CHR(39)  ETIQUETA  INTO V_FECHAS_INTERVALOS FROM OPERACION.PPTO_PERIODO_ANIO_MES WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ID_RECORD > 1;
            
       EXCEPTION WHEN OTHERS THEN
            v_error := SQLERRM;
            OPEN psSalida FOR
                SELECT  -1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO EN PASO 1: '|| v_error);
       END;
 
        DBMS_OUTPUT.PUT_LINE('-->> GENERO REPORTE  << -- ');

        consulta := 'SELECT * FROM (
                                            SELECT NOMBRE_SUPUESTOS, ETIQUETA, VALOR  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO A 
                                            INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_RECORD = A.ID_PERIODO_MES
                                            WHERE CLAVE_AGRUPADOR = ''14.D.1'' AND ORDEN IN (1,2,3,4,5,6,7,8,9,10, 11) order by ORDEN ASC  
                                        )PIV
                                        PIVOT ( MAX(VALOR) FOR ETIQUETA IN (' || V_FECHAS_INTERVALOS || '))';

        -- consulta := 'SELECT 1 FROM DUAL';
      
        DBMS_OUTPUT.PUT_LINE ( consulta);
         
      OPEN psSalida FOR consulta;
               
  
    DBMS_OUTPUT.PUT_LINE('-->> Proceso finalizado << -- ');

    EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SQLERRM;
         OPEN psSalida FOR
                SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO  EXCEPTION (OTHERS) : '|| v_error || consulta );

    END SP_REPORTE_14_D;





PROCEDURE SP_REPORTE_14_F(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER)

    IS
         consulta            CLOB;
         v_error             VARCHAR2(2000);
         V_FECHAS_INTERVALOS VARCHAR2(10000);
         indexInc            INTEGER;
         V_CLAVE_AGRUPADOR   VARCHAR2(10); 
         V_INSERT_AGRUPADOR  VARCHAR2(10);
         V_RESP              NUMBER;
         
         CURSOR intervalos_cur  IS
              SELECT B.ID_RECORD ID_PERIODO
                    , (C1.VALOR / D1.VALOR) AS CALCULO_1
                    , (C2.VALOR / D2.VALOR) AS CALCULO_2 
                    , (C3.VALOR / D3.VALOR) AS CALCULO_3 
                    , (C4.VALOR / D4.VALOR) AS CALCULO_4
                    , (C5.VALOR / D5.VALOR) AS CALCULO_5
                    , (C6.VALOR / D5.VALOR) AS CALCULO_6
                     FROM OPERACION.PPTO_BASE_CREDITOS_REO A
                          INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B
                             ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.A.1' AND ORDEN = 1) C1
                             ON C1.ID_PERIODO_MES = B.ID_RECORD
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D1
                             ON D1.ID_PERIODO_MES = B.ID_RECORD
                            
                            JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.A.1' AND ORDEN = 2) C2
                             ON C2.ID_PERIODO_MES = B.ID_RECORD
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D2
                             ON D2.ID_PERIODO_MES = B.ID_RECORD
                             
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.A.1' AND ORDEN = 4) C3
                             ON C3.ID_PERIODO_MES = B.ID_RECORD
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D3
                             ON D3.ID_PERIODO_MES = B.ID_RECORD
                             
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.A.1' AND ORDEN = 5) C4
                             ON C4.ID_PERIODO_MES = B.ID_RECORD
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D4
                             ON D4.ID_PERIODO_MES = B.ID_RECORD          

                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.A.1' AND ORDEN = 6) C5
                             ON C5.ID_PERIODO_MES = B.ID_RECORD
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D5
                             ON D5.ID_PERIODO_MES = B.ID_RECORD          

                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.A.1' AND ORDEN = 7) C6
                             ON C6.ID_PERIODO_MES = B.ID_RECORD
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D6
                             ON D6.ID_PERIODO_MES = B.ID_RECORD          
                    WHERE A.ID_PRESUPUESTO = P_PRESUPUESTO 
                    GROUP BY B.ID_RECORD
                    , C1.VALOR, D1.VALOR
                    , C2.VALOR, D2.VALOR
                    , C3.VALOR, D3.VALOR  
                    , C4.VALOR, D4.VALOR
                    , C5.VALOR, D5.VALOR
                    , C6.VALOR, D6.VALOR
                    ORDER BY B.ID_RECORD;
                
    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');

        -- DECLARACION DE VARIABLES 
        V_INSERT_AGRUPADOR := '14.F.1';
        
            for u in intervalos_cur loop
                  
                -- CALCULO  PASO 1
                --INSERT DE CALCULOS 
                  OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 1, u.CALCULO_1);
                  OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 2, u.CALCULO_2);
                  OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 3, 0);
                  OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 4, u.CALCULO_3);
                  OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 5, u.CALCULO_4);
                  OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 6, u.CALCULO_5);
                  OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 7, u.CALCULO_6);
                  
            end loop; 
        -- Fin bucle
           
     COMMIT;
     --- OBTIENE  muestra de los valores  
      BEGIN
           SELECT  CHR(39) || LISTAGG(ETIQUETA, ''',''')  WITHIN GROUP (ORDER BY ID_RECORD) || CHR(39)  ETIQUETA  INTO V_FECHAS_INTERVALOS FROM OPERACION.PPTO_PERIODO_ANIO_MES WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ID_RECORD > 1;
            
       EXCEPTION WHEN OTHERS THEN
            v_error := SQLERRM;
            OPEN psSalida FOR
                SELECT  -1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO EN PASO 1: '|| v_error);
       END;
 
        DBMS_OUTPUT.PUT_LINE('-->> GENERO REPORTE  << -- ');

        consulta := 'SELECT * FROM (
                                            SELECT NOMBRE_SUPUESTOS, ETIQUETA, VALOR  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO A 
                                            INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_RECORD = A.ID_PERIODO_MES
                                            WHERE CLAVE_AGRUPADOR = ''14.F.1'' AND ORDEN IN (1,2,4,5,6,7)   
                                        )PIV
                                        PIVOT ( MAX(VALOR) FOR ETIQUETA IN (' || V_FECHAS_INTERVALOS || '))';
      
        -- consulta := 'SELECT 1 FROM DUAL';
      
        DBMS_OUTPUT.PUT_LINE ( consulta);
         
      OPEN psSalida FOR consulta;
               
  
    DBMS_OUTPUT.PUT_LINE('-->> Proceso finalizado << -- ');

    EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SQLERRM;
         OPEN psSalida FOR
                SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO  EXCEPTION (OTHERS) : '|| v_error || consulta );


    END SP_REPORTE_14_F;








PROCEDURE SP_REPORTE_14_G(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER)

    IS
         consulta            CLOB;
         v_error             VARCHAR2(2000);
         V_FECHAS_INTERVALOS VARCHAR2(10000);
         indexInc            INTEGER;
         V_CLAVE_AGRUPADOR   VARCHAR2(10); 
         V_INSERT_AGRUPADOR  VARCHAR2(10);
         V_RESP              NUMBER;  
         
         CURSOR intervalos_cur  IS
                SELECT B.ID_RECORD ID_PERIODO
                , (C1.VALOR / D1.VALOR) AS CALCULO_1
                , (C2.VALOR / D2.VALOR) AS CALCULO_2 
                , (C3.VALOR / D3.VALOR) AS CALCULO_3 
                , (C4.VALOR / D4.VALOR) AS CALCULO_4
                , (C5.VALOR / D5.VALOR) AS CALCULO_5
                 FROM OPERACION.PPTO_BASE_CREDITOS_REO A
                      INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B
                         ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.B.1' AND ORDEN = 1)  C1
                         ON C1.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D1
                         ON D1.ID_PERIODO_MES = B.ID_RECORD
                        
                        JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.B.1' AND ORDEN = 2)  C2
                         ON C2.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D2
                         ON D2.ID_PERIODO_MES = B.ID_RECORD
                         
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.B.1' AND ORDEN = 4)  C3
                         ON C3.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D3
                         ON D3.ID_PERIODO_MES = B.ID_RECORD
                         
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.B.1' AND ORDEN = 5)  C4
                         ON C4.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D4
                         ON D4.ID_PERIODO_MES = B.ID_RECORD          

                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.B.1' AND ORDEN = 7)  C5
                         ON C5.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D5
                         ON D5.ID_PERIODO_MES = B.ID_RECORD
                                   
                WHERE A.ID_PRESUPUESTO = P_PRESUPUESTO 
                GROUP BY B.ID_RECORD
                , C1.VALOR, D1.VALOR
                , C2.VALOR, D2.VALOR
                , C3.VALOR, D3.VALOR  
                , C4.VALOR, D4.VALOR
                , C5.VALOR, D5.VALOR
                ORDER BY B.ID_RECORD;

    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
        -- DECLARACION DE VARIABLES 
        V_INSERT_AGRUPADOR := '14.G.1';
        
            for u in intervalos_cur loop
                  
                -- CALCULO  PASO 1
                --INSERT DE CALCULOS 
                
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 1, u.CALCULO_1);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 2, u.CALCULO_2);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 3,0);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 4, u.CALCULO_3);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 5, u.CALCULO_4);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 6, u.CALCULO_5);
                  
            end loop; 
        -- Fin bucle
           
     COMMIT;
     --- OBTIENE  muestra de los valores  
      BEGIN
           SELECT  CHR(39) || LISTAGG(ETIQUETA, ''',''')  WITHIN GROUP (ORDER BY ID_RECORD) || CHR(39)  ETIQUETA  INTO V_FECHAS_INTERVALOS FROM OPERACION.PPTO_PERIODO_ANIO_MES WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ID_RECORD > 1;
            
       EXCEPTION WHEN OTHERS THEN
            v_error := SQLERRM;
            OPEN psSalida FOR
                SELECT  -1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO EN PASO 1: '|| v_error);
       END;
 
        DBMS_OUTPUT.PUT_LINE('-->> GENERO REPORTE  << -- ');

        consulta := 'SELECT * FROM (
                                            SELECT NOMBRE_SUPUESTOS, ETIQUETA, VALOR  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO A 
                                            INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_RECORD = A.ID_PERIODO_MES
                                            WHERE CLAVE_AGRUPADOR = ''14.G.1'' AND ORDEN IN (1,2,3,4,5,6)   
                                        )PIV
                                        PIVOT ( MAX(VALOR) FOR ETIQUETA IN (' || V_FECHAS_INTERVALOS || '))';
      
        -- consulta := 'SELECT 1 FROM DUAL';
      
        DBMS_OUTPUT.PUT_LINE ( consulta);
         
      OPEN psSalida FOR consulta;
               
  
    DBMS_OUTPUT.PUT_LINE('-->> Proceso finalizado << -- ');

    EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SQLERRM;
         OPEN psSalida FOR
                SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO  EXCEPTION (OTHERS) : '|| v_error || consulta );

    END SP_REPORTE_14_G;











PROCEDURE SP_REPORTE_14_H(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER)

    IS
         consulta            CLOB;
         v_error             VARCHAR2(2000);
         V_FECHAS_INTERVALOS VARCHAR2(10000);
         indexInc            INTEGER;
         V_CLAVE_AGRUPADOR   VARCHAR2(10); 
         V_INSERT_AGRUPADOR  VARCHAR2(10);
         V_RESP              NUMBER;
         
         CURSOR intervalos_cur  IS
                SELECT B.ID_RECORD ID_PERIODO
                , (C1.VALOR / D1.VALOR) AS CALCULO_1
                , (C2.VALOR / D2.VALOR) AS CALCULO_2 
                , (C3.VALOR / D3.VALOR) AS CALCULO_3 
                , (C4.VALOR / D4.VALOR) AS CALCULO_4
                , (C5.VALOR / D5.VALOR) AS CALCULO_5
                , (C6.VALOR / D5.VALOR) AS CALCULO_6
                , (C7.VALOR / D7.VALOR) AS CALCULO_7
                , (C8.VALOR / D8.VALOR) AS CALCULO_8
                , (C9.VALOR / D9.VALOR) AS CALCULO_9
                , (C10.VALOR / D10.VALOR) AS CALCULO_10
                , (C11.VALOR / D11.VALOR) AS CALCULO_11
                 FROM OPERACION.PPTO_BASE_CREDITOS_REO A
                      INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B
                         ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.C.1' AND ORDEN = 1) C1
                         ON C1.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D1
                         ON D1.ID_PERIODO_MES = B.ID_RECORD
                        
                        JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.C.1' AND ORDEN = 2) C2
                         ON C2.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D2
                         ON D2.ID_PERIODO_MES = B.ID_RECORD
                         
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.C.1' AND ORDEN = 5) C3
                         ON C3.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D3
                         ON D3.ID_PERIODO_MES = B.ID_RECORD
                         
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.C.1' AND ORDEN = 6) C4
                         ON C4.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D4
                         ON D4.ID_PERIODO_MES = B.ID_RECORD          

                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.C.1' AND ORDEN = 7) C5
                         ON C5.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D5
                         ON D5.ID_PERIODO_MES = B.ID_RECORD          

                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.C.1' AND ORDEN = 8) C6
                         ON C6.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D6
                         ON D6.ID_PERIODO_MES = B.ID_RECORD  
                         
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.C.1' AND ORDEN = 9) C7
                         ON C7.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D7
                         ON D7.ID_PERIODO_MES = B.ID_RECORD  

                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.C.1' AND ORDEN = 10) C8
                         ON C8.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D8
                         ON D8.ID_PERIODO_MES = B.ID_RECORD  

                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.C.1' AND ORDEN = 14) C9
                         ON C9.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D9
                         ON D9.ID_PERIODO_MES = B.ID_RECORD
                         
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.C.1' AND ORDEN = 13) C10
                         ON C10.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D10
                         ON D10.ID_PERIODO_MES = B.ID_RECORD  

                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.C.1' AND ORDEN = 18) C11
                         ON C11.ID_PERIODO_MES = B.ID_RECORD
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D11
                         ON D11.ID_PERIODO_MES = B.ID_RECORD  
                 
                WHERE A.ID_PRESUPUESTO = P_PRESUPUESTO 
                GROUP BY B.ID_RECORD
                , C1.VALOR, D1.VALOR
                , C2.VALOR, D2.VALOR
                , C3.VALOR, D3.VALOR  
                , C4.VALOR, D4.VALOR
                , C5.VALOR, D5.VALOR
                , C6.VALOR, D6.VALOR
                , C7.VALOR, D7.VALOR
                , C8.VALOR, D8.VALOR
                , C9.VALOR, D9.VALOR
                , C10.VALOR, D10.VALOR
                , C11.VALOR, D11.VALOR
                ORDER BY B.ID_RECORD;                

    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
        -- DECLARACION DE VARIABLES 
        V_INSERT_AGRUPADOR := '14.H.1';
        
            for u in intervalos_cur loop
                  
                -- CALCULO  PASO 1
                --INSERT DE CALCULOS 
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 1,  u.CALCULO_1);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 2,  u.CALCULO_2);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 3,  0);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 4,  u.CALCULO_3);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 5,  u.CALCULO_4);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 6,  u.CALCULO_5);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 7,  u.CALCULO_6);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 8,  u.CALCULO_7);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 9,  u.CALCULO_8);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 10, u.CALCULO_9);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 11, u.CALCULO_10);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 12, u.CALCULO_11);
            end loop; 
        -- Fin bucle
           
     COMMIT;
     --- OBTIENE  muestra de los valores  
      BEGIN
           SELECT  CHR(39) || LISTAGG(ETIQUETA, ''',''')  WITHIN GROUP (ORDER BY ID_RECORD) || CHR(39)  ETIQUETA  INTO V_FECHAS_INTERVALOS FROM OPERACION.PPTO_PERIODO_ANIO_MES WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ID_RECORD > 1;
            
       EXCEPTION WHEN OTHERS THEN
            v_error := SQLERRM;
            OPEN psSalida FOR
                SELECT  -1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO EN PASO 1: '|| v_error);
       END;
 
        DBMS_OUTPUT.PUT_LINE('-->> GENERO REPORTE  << -- ');

        consulta := 'SELECT * FROM (
                                            SELECT NOMBRE_SUPUESTOS, ETIQUETA, VALOR  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO A 
                                            INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_RECORD = A.ID_PERIODO_MES
                                            WHERE CLAVE_AGRUPADOR = ''14.H.1'' AND ORDEN IN (1,2,3,4,5,6,7,8,9,10,11,12)   
                                        )PIV
                                        PIVOT ( MAX(VALOR) FOR ETIQUETA IN (' || V_FECHAS_INTERVALOS || '))';
      
        -- consulta := 'SELECT 1 FROM DUAL';
      
        DBMS_OUTPUT.PUT_LINE ( consulta);
         
      OPEN psSalida FOR consulta;
               
  
    DBMS_OUTPUT.PUT_LINE('-->> Proceso finalizado << -- ');

    EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SQLERRM;
         OPEN psSalida FOR
                SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO  EXCEPTION (OTHERS) : '|| v_error || consulta );

    END SP_REPORTE_14_H;
PROCEDURE SP_REPORTE_14_I(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER)

    IS
         consulta            CLOB;
         v_error             VARCHAR2(2000);
         V_FECHAS_INTERVALOS VARCHAR2(10000);
         indexInc            INTEGER;
         V_CLAVE_AGRUPADOR   VARCHAR2(10); 
         V_INSERT_AGRUPADOR  VARCHAR2(10);
         V_RESP              NUMBER;
         
         CURSOR intervalos_cur  IS
                    SELECT B.ID_RECORD ID_PERIODO
                    , (C1.VALOR / D1.VALOR) AS CALCULO_1
                    , (C2.VALOR / D2.VALOR) AS CALCULO_2 
                    , (C3.VALOR / D3.VALOR) AS CALCULO_3 
                    , (C4.VALOR / D4.VALOR) AS CALCULO_4
                     FROM OPERACION.PPTO_BASE_CREDITOS_REO A
                          INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B
                             ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.D.1' AND ORDEN = 1) C1
                             ON C1.ID_PERIODO_MES = B.ID_RECORD
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D1
                             ON D1.ID_PERIODO_MES = B.ID_RECORD
                            
                            JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.D.1' AND ORDEN = 2) C2
                             ON C2.ID_PERIODO_MES = B.ID_RECORD
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D2
                             ON D2.ID_PERIODO_MES = B.ID_RECORD
                             
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.D.1' AND ORDEN = 6) C3
                             ON C3.ID_PERIODO_MES = B.ID_RECORD
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D3
                             ON D3.ID_PERIODO_MES = B.ID_RECORD
                             
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.D.1' AND ORDEN = 11) C4
                             ON C4.ID_PERIODO_MES = B.ID_RECORD
                          JOIN (SELECT *
                                  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                                 WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 10) D4
                             ON D4.ID_PERIODO_MES = B.ID_RECORD          
                    WHERE A.ID_PRESUPUESTO = P_PRESUPUESTO 
                    GROUP BY B.ID_RECORD
                    , C1.VALOR, D1.VALOR
                    , C2.VALOR, D2.VALOR
                    , C3.VALOR, D3.VALOR  
                    , C4.VALOR, D4.VALOR
                    ORDER BY B.ID_RECORD;

    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
        -- DECLARACION DE VARIABLES 
        V_INSERT_AGRUPADOR := '14.I.1';
        
            for u in intervalos_cur loop
                  
                -- CALCULO  PASO 1
                --INSERT DE CALCULOS 
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 1,  u.CALCULO_1);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 2,  u.CALCULO_2);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 3,  NULL);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 4,  u.CALCULO_3);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 5,  u.CALCULO_4);
                
            end loop; 
        -- Fin bucle
           
     COMMIT;
     --- OBTIENE  muestra de los valores  
      BEGIN
           SELECT  CHR(39) || LISTAGG(ETIQUETA, ''',''')  WITHIN GROUP (ORDER BY ID_RECORD) || CHR(39)  ETIQUETA  INTO V_FECHAS_INTERVALOS FROM OPERACION.PPTO_PERIODO_ANIO_MES WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ID_RECORD > 1;
            
       EXCEPTION WHEN OTHERS THEN
            v_error := SQLERRM;
            OPEN psSalida FOR
                SELECT  -1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO EN PASO 1: '|| v_error);
       END;
 
        DBMS_OUTPUT.PUT_LINE('-->> GENERO REPORTE  << -- ');

        consulta := 'SELECT * FROM (
                                            SELECT NOMBRE_SUPUESTOS, ETIQUETA, VALOR  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO A 
                                            INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_RECORD = A.ID_PERIODO_MES
                                            WHERE CLAVE_AGRUPADOR = ''14.I.1'' AND ORDEN IN (1,2,3,4,5)   
                                        )PIV
                                        PIVOT ( MAX(VALOR) FOR ETIQUETA IN (' || V_FECHAS_INTERVALOS || '))';
      
        -- consulta := 'SELECT 1 FROM DUAL';
      
        DBMS_OUTPUT.PUT_LINE ( consulta);
         
      OPEN psSalida FOR consulta;
               
  
    DBMS_OUTPUT.PUT_LINE('-->> Proceso finalizado << -- ');

    EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SQLERRM;
         OPEN psSalida FOR
                SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO  EXCEPTION (OTHERS) : '|| v_error || consulta );

    END SP_REPORTE_14_I;

PROCEDURE SP_REPORTE_7_E(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER)

    IS
         consulta            CLOB;
         v_error             VARCHAR2(2000);
         V_FECHAS_INTERVALOS VARCHAR2(10000);
         indexInc            INTEGER;
         V_CLAVE_AGRUPADOR   VARCHAR2(10); 
         V_INSERT_AGRUPADOR  VARCHAR2(10);
         V_RESP              NUMBER;
         CALCULO_1           FLOAT;
         CALCULO_12           FLOAT;
         
         CURSOR intervalos_cur IS
                  SELECT  B.ID_RECORD ID_PERIODO
                     , CASE 
                       WHEN C1.VALOR IS NULL  THEN 0
                       ELSE C1.VALOR  END CALCULO_2
                     , CASE 
                       WHEN C2.VALOR IS NULL  THEN 0
                       ELSE C2.VALOR  END CALCULO_3 
                     , CASE 
                       WHEN (C3.VALOR) < 0.5  THEN 0
                       ELSE (SELECT PORCENTAJE FROM OPERACION.PPTO_GASTOS_DIR_ADM WHERE ID_PRESUPUESTO = 2000 AND ORDEN = 1)  * (1 + D3.VALOR)  END CALCULO_4
                     , CASE 
                       WHEN (C4.VALOR) < 0.5  THEN 0
                       ELSE (SELECT PORCENTAJE FROM OPERACION.PPTO_GASTOS_DIR_ADM WHERE ID_PRESUPUESTO = 2000 AND ORDEN = 2)  * (1 + D3.VALOR)  END CALCULO_5
                     , CASE 
                       WHEN C5.VALOR IS NULL THEN 0
                       ELSE C5.VALOR  END CALCULO_6
                     , CASE 
                       WHEN C5.VALOR IS NULL  THEN 0
                       ELSE C5.VALOR  END CALCULO_7 /*47.NOTIFICACION*/
                     , CASE 
                       WHEN 0 * (SELECT PORCENTAJE FROM OPERACION.PPTO_GASTOS_DIR_ADM WHERE ID_PRESUPUESTO = 2000 AND ORDEN = 4) IS NULL  THEN 0 /* FALTA 47.NOTIFICACION */
                       ELSE 0 * (SELECT PORCENTAJE FROM OPERACION.PPTO_GASTOS_DIR_ADM WHERE ID_PRESUPUESTO = 2000 AND ORDEN = 4)  END AS CALCULO_8
                     , (1+ C6.VALOR) AS CALCULO_9 
                     , CASE 
                       WHEN (C7.VALOR) < 0.5 OR C7.VALOR IS NULL THEN 0
                       ELSE (C7.VALOR) * (SELECT PORCENTAJE FROM OPERACION.PPTO_GASTOS_DIR_ADM WHERE ID_PRESUPUESTO = 2000 AND ORDEN = 15) END CALCULO_10
                     , (SELECT PORCENTAJE FROM OPERACION.PPTO_GASTOS_DIR_ADM WHERE ID_PRESUPUESTO = 2000 AND ORDEN = 15) AS CALCULO_11 -- /* FALTA 47.notificación */ 
                     , ((C8.VALOR + D8.VALOR + F8.VALOR + G8.VALOR) * (SELECT PORCENTAJE FROM OPERACION.PPTO_GASTOS_DIR_ADM WHERE ID_PRESUPUESTO = 2000 AND ORDEN = 6) ) AS CALCULO_13
                     , CASE 
                       WHEN G9.VALOR IS NULL  THEN 0
                       ELSE G9.VALOR  END CALCULO_14
                     , CASE 
                       WHEN C9.VALOR * (SELECT PORCENTAJE FROM OPERACION.PPTO_GASTOS_DIR_ADM WHERE ID_PRESUPUESTO = 2000 AND ORDEN = 7) IS NULL THEN 0
                       ELSE C9.VALOR  * (SELECT PORCENTAJE FROM OPERACION.PPTO_GASTOS_DIR_ADM WHERE ID_PRESUPUESTO = 2000 AND ORDEN = 7) END CALCULO_15
                  FROM OPERACION.PPTO_BASE_CREDITOS_REO A
                      INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B  ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                       
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '35.E.1' AND ORDEN = 1)  C1
                         ON C1.ID_PERIODO_MES = B.ID_RECORD
                       
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '35.E.1' AND ORDEN = 2)  C2
                         ON C2.ID_PERIODO_MES = B.ID_RECORD
                         
                       
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.C.1' AND ORDEN = 18) C3
                         ON C3.ID_PERIODO_MES = B.ID_RECORD
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 9)  D3
                         ON D3.ID_PERIODO_MES = B.ID_RECORD
                         
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.A.1' AND ORDEN = 7)  C4
                         ON C4.ID_PERIODO_MES = B.ID_RECORD
                         
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '35.E.1' AND ORDEN = 3)  C5
                         ON C5.ID_PERIODO_MES = B.ID_RECORD
                         
                      JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.E.1' AND ORDEN = 9)  C6
                         ON C6.ID_PERIODO_MES = B.ID_RECORD
                         
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '13.J.1' AND ORDEN = 9)  C7 /* hay que validar el orden */
                         ON C7.ID_PERIODO_MES = B.ID_RECORD          
                         
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '15.A.1' AND ORDEN = 5)  C8 
                         ON C8.ID_PERIODO_MES = B.ID_RECORD
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '15.A.1' AND ORDEN = 13) D8 /* hay que validar el orden */
                         ON D8.ID_PERIODO_MES = B.ID_RECORD          
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '15.B.1' AND ORDEN = 5)  F8
                         ON F8.ID_PERIODO_MES = B.ID_RECORD
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '15.B.1' AND ORDEN = 8)  G8
                         ON G8.ID_PERIODO_MES = B.ID_RECORD
                        
                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '35.F.1' AND ORDEN = 7)  G9
                         ON G9.ID_PERIODO_MES = B.ID_RECORD          

                      LEFT JOIN (SELECT *
                              FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO
                             WHERE CLAVE_AGRUPADOR = '14.D.1' AND ORDEN = 3)  C9
                         ON C9.ID_PERIODO_MES = B.ID_RECORD          
                         
                      WHERE A.ID_PRESUPUESTO = 2000 
                      GROUP BY B.ID_RECORD 
                      , C1.VALOR
                      , C2.VALOR
                      , C3.VALOR
                      , D3.VALOR
                      , C4.VALOR
                      , C5.VALOR
                      , C6.VALOR
                      , C7.VALOR
                      , C8.VALOR, D8.VALOR, F8.VALOR, G8.VALOR
                      , G9.VALOR
                      , C9.VALOR
                      ORDER BY B.ID_RECORD; 
                
    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
        -- DECLARACION DE VARIABLES 
        V_INSERT_AGRUPADOR := '7.E.1';
        
            for u in intervalos_cur loop
                -- CALCULO  PASO 1
                --INSERT DE CALCULOS 
                 CALCULO_12 := u.CALCULO_13 + u.CALCULO_14 + u.CALCULO_15;
                 CALCULO_1  := u.CALCULO_2 + u.CALCULO_3 + u.CALCULO_4 + u.CALCULO_5 + u.CALCULO_6 + u.CALCULO_7 + u.CALCULO_8 + u.CALCULO_9 + u.CALCULO_10 + u.CALCULO_11 + CALCULO_12;
                 
                -- insert masivo 
                -- DBMS_OUTPUT.PUT_LINE('INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, '|| u.ID_PERIODO ||', 1, '|| V_INSERT_AGRUPADOR ||', ''Gastos Directos'', '|| CALCULO_1 );
                -- insert masivo 
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 1,  V_INSERT_AGRUPADOR, 'Gastos Directos', CALCULO_1); 
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 2,  V_INSERT_AGRUPADOR, 'Honorarios por avances legales', u.CALCULO_2);
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 3,  V_INSERT_AGRUPADOR, 'Reembolso de gastos legales', u.CALCULO_3);
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 4,  V_INSERT_AGRUPADOR, 'Viáticos ', u.CALCULO_4);
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 5,  V_INSERT_AGRUPADOR, 'Seguros ', u.CALCULO_5);
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 6,  V_INSERT_AGRUPADOR, 'Certificaciones Contables ', u.CALCULO_6);
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 7,  V_INSERT_AGRUPADOR, 'Valuaciones', u.CALCULO_7);
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 8,  V_INSERT_AGRUPADOR, 'Notificaciones Judiciales', u.CALCULO_8);
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 9,  V_INSERT_AGRUPADOR, 'Mensajería', u.CALCULO_9);
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 10, V_INSERT_AGRUPADOR, 'Estados de Cuenta', u.CALCULO_10);
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 11, V_INSERT_AGRUPADOR, 'Gastos de Cobranza', u.CALCULO_11);
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 12, V_INSERT_AGRUPADOR, 'Convenio Notarial', CALCULO_12);
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 13, V_INSERT_AGRUPADOR, 'Convenio Judicial', u.CALCULO_13);
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 14, V_INSERT_AGRUPADOR, 'Dación de Pago', u.CALCULO_14);
                   INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.ID_PERIODO, 15, V_INSERT_AGRUPADOR, 'Cobranza neta', u.CALCULO_15);
                 
                 
              --  OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 1,  CALCULO_1);  
            /*  OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 2,  u.CALCULO_2);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 3,  u.CALCULO_3);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 4,  u.CALCULO_4);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 5,  u.CALCULO_5);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 6,  u.CALCULO_6);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 7,  u.CALCULO_7);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 8,  u.CALCULO_8);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 9,  u.CALCULO_9);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 10, u.CALCULO_10);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 11, u.CALCULO_11);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 12, u.CALCULO_12);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 13, u.CALCULO_13);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 14, u.CALCULO_14);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 15, u.CALCULO_15);
             */  
            end loop; 
        -- Fin bucle
           
        COMMIT;
        --- OBTIENE  muestra de los valores  
      BEGIN
           SELECT  CHR(39) || LISTAGG(ETIQUETA, ''',''')  WITHIN GROUP (ORDER BY ID_RECORD) || CHR(39)  ETIQUETA  INTO V_FECHAS_INTERVALOS FROM OPERACION.PPTO_PERIODO_ANIO_MES WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ID_RECORD > 1;
            
       EXCEPTION WHEN OTHERS THEN
            v_error := SQLERRM;
            OPEN psSalida FOR
                SELECT  -1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO EN PASO 1: '|| v_error);
       END;
 
        DBMS_OUTPUT.PUT_LINE('-->> GENERO REPORTE  << -- ');

        consulta := 'SELECT * FROM (
                                      SELECT NOMBRE_SUPUESTOS, ETIQUETA, VALOR  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO A 
                                      INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_RECORD = A.ID_PERIODO_MES
                                      WHERE CLAVE_AGRUPADOR = ''7.E.1'' AND ORDEN IN (1,2,3,4,5,6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 )   
                                   )PIV
                                     PIVOT ( MAX(VALOR) FOR ETIQUETA IN (' || V_FECHAS_INTERVALOS || '))';
      
      --   consulta := 'SELECT 1 FROM DUAL';
      
        DBMS_OUTPUT.PUT_LINE ( consulta );
         
      OPEN psSalida FOR consulta;
               
  
    DBMS_OUTPUT.PUT_LINE('-->> Proceso finalizado << -- ');

    EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SQLERRM;
         OPEN psSalida FOR
                SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO  EXCEPTION (OTHERS) : '|| v_error || consulta );

    END SP_REPORTE_7_E;






PROCEDURE SP_INSERTHIST_4_A(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER)

    IS
         consulta            CLOB;
         v_error             VARCHAR2(2000);
         V_FECHAS_INTERVALOS VARCHAR2(10000);
         indexInc            INTEGER;
         V_CLAVE_AGRUPADOR   VARCHAR2(10); 
         V_INSERT_AGRUPADOR  VARCHAR2(10);
         V_RESP              NUMBER;
          
         V_ID_RECOR          NUMBER;
         V_ETIQUETA          VARCHAR2(10000);
         
         CURSOR cur_peri_mes  IS
                 SELECT PERIODO, OPERACION.PKG_OPERACION_LEO.FN_GET_FORMATO_PERIODO( PERIODO, 'Mon-YY' ) AS ID_PERIODO  FROM OPERACION.TMP_CARGA_TBL_04BPPTO20151 WHERE ID_CARGA = 0 AND PERIODO != 'Periodo' ORDER BY ID_RECORD ASC; 

    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
            -- DECLARACION DE VARIABLES 
            V_INSERT_AGRUPADOR := '01.A.1';
            indexInc := 1;
            for u in cur_peri_mes loop
                -- PASO 1 - INSERTAR PERIODOS 
                 --DBMS_OUTPUT.PUT_LINE('-->> Periodos insertados  << -- ' || u.ID_PERIODO);
                 INSERT INTO OPERACION.PPTO_PERIODO_ANIO_MES (ID_RECORD, ID_PRESUPUESTO, PERIODO_ANIO, PERIODO_MES, CONSECUTIVO, CONSECUTIVO_MES, CONSECUTIVO_ANIO, ETIQUETA) VALUES (OPERACION.PPTO_SEQ_PERIODO_ANIO_MES.NEXTVAL, P_PRESUPUESTO, OPERACION.PKG_PPTO_UTILS.FN_GET_YEAR(u.ID_PERIODO), OPERACION.PKG_PPTO_UTILS.FN_GET_MONTH(u.ID_PERIODO), OPERACION.PPTO_SEQ_PERIODO_ANIO_MES.NEXTVAL, indexInc, SUBSTR(OPERACION.PKG_PPTO_UTILS.FN_GET_YEAR(u.ID_PERIODO),3,4), u.ID_PERIODO);
                 DBMS_OUTPUT.PUT_LINE(' INSERT INTO OPERACION.PPTO_PERIODO_ANIO_MES (ID_RECORD, ID_PRESUPUESTO, PERIODO_ANIO, PERIODO_MES, CONSECUTIVO, CONSECUTIVO_MES, CONSECUTIVO_ANIO, ETIQUETA) VALUES (OPERACION.PPTO_SEQ_PERIODO_ANIO_MES.NEXTVAL, '|| P_PRESUPUESTO ||', OPERACION.PKG_PPTO_UTILS.FN_GET_YEAR('|| u.ID_PERIODO ||'), OPERACION.PKG_PPTO_UTILS.FN_GET_MONTH('|| u.ID_PERIODO ||'), OPERACION.PPTO_SEQ_PERIODO_ANIO_MES.NEXTVAL, '|| indexInc  ||', '|| SUBSTR(OPERACION.PKG_PPTO_UTILS.FN_GET_YEAR(u.ID_PERIODO),3,4) || ', '|| u.ID_PERIODO || ');  ');    
                 indexInc := indexInc + 1;
            end loop;     
             
        -- Fin bucle
           
     COMMIT;
         consulta := 'SELECT 1 FROM DUAL';
      
        DBMS_OUTPUT.PUT_LINE ( consulta);
         
      OPEN psSalida FOR consulta;
               
  
    DBMS_OUTPUT.PUT_LINE('-->> Proceso finalizado << -- ');

    EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SQLERRM;
         OPEN psSalida FOR
                SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO  EXCEPTION (OTHERS) : '|| v_error || consulta );

    END SP_INSERTHIST_4_A;






PROCEDURE SP_REPORTE_4_A(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER)

    IS
         consulta            CLOB;
         v_error             VARCHAR2(2000);
         V_FECHAS_INTERVALOS VARCHAR2(10000);
         indexInc            INTEGER;
         V_CLAVE_AGRUPADOR   VARCHAR2(10); 
         V_INSERT_AGRUPADOR  VARCHAR2(10);
         V_RESP              NUMBER;
         
         CURSOR cur_peri_mes  IS
                    SELECT 
                      B.ID_RECORD ID_PERIODO
                    , B.ETIQUETA
                    , VIGENTES_02MV
                    , CREDITOS_MORA_TEMPRANA_36MV
                    , VENCIDOS_6MV
                    , TOTAL_VENCIDOS
                    , REO
                    , REO_COMERCIAL
                    , COMERCIAL
                    , IRR
                    , LIQ_ACUMULADOS
                    , TOTAL_CREDITOS
                    , LIQ_NAT_CREDITOS_VIG
                    , LIQ_ANTI_CREDITOS_VIG
                    , PAGO_UNICO_DEUDOR
                    , PAGO_UNICO_CESION
                    , RESTRUCTURA_CORTOP
                    , RESTRUCTURA_LARGOP
                    , DACION
                    , VENTA_REO
                    , COM_V_REO_RES_NPL
                    , TOTAL_RESOLUCIONES
                    , UPB_REMANENTE_CVV
                    , VAL_COLATERAL_CVV
                    , VAL_COLATERAL_BIENES_ADJ
                    , VAL_COLATERAL_REO_COMS
                    , UPB_REMANENTE_CRE_COMS 
                    FROM OPERACION.TMP_CARGA_TBL_04BPPTO20151 A
                    LEFT JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ETIQUETA = OPERACION.PKG_OPERACION_LEO.FN_GET_FORMATO_PERIODO( A.PERIODO, 'Mon-YY' )  
                    WHERE A.ID_CARGA = 0 
                    AND A.PERIODO != 'Periodo' 
                    AND B.ID_PRESUPUESTO = P_PRESUPUESTO
                    ORDER BY B.ID_RECORD;  

    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
            -- DECLARACION DE VARIABLES 
            V_INSERT_AGRUPADOR := '01.A.1';
            
                 
            for u in cur_peri_mes loop
                 
                    -- PASO 2 - CONSULTA VALORES 
                        
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 1,  u.VIGENTES_02MV);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 2,  u.CREDITOS_MORA_TEMPRANA_36MV);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 3,  u.VENCIDOS_6MV);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 4,  u.TOTAL_VENCIDOS);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 5,  u.REO);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 6,  u.REO_COMERCIAL);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 7,  u.COMERCIAL);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 8,  u.IRR);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 9,  u.LIQ_ACUMULADOS);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 10,  u.TOTAL_CREDITOS);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 11,  u.LIQ_NAT_CREDITOS_VIG);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 12,  u.LIQ_ANTI_CREDITOS_VIG);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 13,  u.PAGO_UNICO_DEUDOR);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 14,  u.PAGO_UNICO_CESION);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 15,  u.RESTRUCTURA_CORTOP);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 16,  u.RESTRUCTURA_LARGOP);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 17,  u.DACION);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 18,  u.VENTA_REO);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 19,  u.COM_V_REO_RES_NPL);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 20,  u.TOTAL_RESOLUCIONES);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 21,  u.UPB_REMANENTE_CVV);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 22,  u.VAL_COLATERAL_CVV);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 23,  u.VAL_COLATERAL_BIENES_ADJ);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 24,  u.VAL_COLATERAL_REO_COMS);
                        
                 
                   -- PASO 3 - INSERT VALORES EN LA TABLA DE REPORTES 
                    
                   /*  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 1, V_INSERT_AGRUPADOR, 'Vigentes (0-2 MV)', u.VIGENTES_02MV);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 2,   V_INSERT_AGRUPADOR, 'Créditos en Mora Temprana (3-6 MV)', V_VALOR_2);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 3,   V_INSERT_AGRUPADOR, 'Vencidos (+ 6 MV)', V_VALOR_3);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 4,   V_INSERT_AGRUPADOR, 'Total vencidos', V_VALOR_4);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 5,   V_INSERT_AGRUPADOR, 'REO', V_VALOR_5);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 6,   V_INSERT_AGRUPADOR, 'REO Comercial', V_VALOR_6);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 7,   V_INSERT_AGRUPADOR, 'Comercial', V_VALOR_7);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 8,   V_INSERT_AGRUPADOR, 'IRR', V_VALOR_8);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 9,   V_INSERT_AGRUPADOR, 'Liquidados acumulados', V_VALOR_9);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 10,  V_INSERT_AGRUPADOR, 'Total de creditos', V_VALOR_10);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 11,  V_INSERT_AGRUPADOR, 'Liquidaciones naturales de creditos vigentes', V_VALOR_11);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 12,  V_INSERT_AGRUPADOR, 'Liquidaciones anticipadas de creditos vigentes', V_VALOR_12);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 13,  V_INSERT_AGRUPADOR, 'Pago unico deudor', V_VALOR_13);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 14,  V_INSERT_AGRUPADOR, 'Pago unico cesion', V_VALOR_14);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 15,  V_INSERT_AGRUPADOR, 'Restructura corto plazo', V_VALOR_15);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 16,  V_INSERT_AGRUPADOR, 'Restructura largo plazo', V_VALOR_16);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 17,  V_INSERT_AGRUPADOR, 'Dacion', V_VALOR_17);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 18,  V_INSERT_AGRUPADOR, 'Venta REO ', V_VALOR_18);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 19,  V_INSERT_AGRUPADOR, 'Comercial (venta REO o resolucion NPL)', V_VALOR_19);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 20,  V_INSERT_AGRUPADOR, 'Total resoluciones', V_VALOR_20);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 21,  V_INSERT_AGRUPADOR, 'UPB remanente de la cartera vigente y vencida', V_VALOR_21);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 22,  V_INSERT_AGRUPADOR, 'Valor colateral de la cartera vigente y vencida', V_VALOR_22);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 23,  V_INSERT_AGRUPADOR, 'Valor colateral de los bienes adjudicados', V_VALOR_23);
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL,u.PERIODO, 24,  V_INSERT_AGRUPADOR, 'Valor colateral de REO Comercial', V_VALOR_24);
                    
              */ 
                
            end loop;
        -- Fin bucle
           
     COMMIT;
     --- OBTIENE  muestra de los valores  
      BEGIN
           SELECT  CHR(39) || LISTAGG(ETIQUETA, ''',''')  WITHIN GROUP (ORDER BY ID_RECORD) || CHR(39)  ETIQUETA  INTO V_FECHAS_INTERVALOS FROM OPERACION.PPTO_PERIODO_ANIO_MES WHERE ID_PRESUPUESTO = P_PRESUPUESTO;
            
       EXCEPTION WHEN OTHERS THEN
            v_error := SQLERRM;
            OPEN psSalida FOR
                SELECT  -1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO EN PASO 1: '|| v_error);
       END;
 
        DBMS_OUTPUT.PUT_LINE('-->> GENERO REPORTE  << -- ');

        consulta := 'SELECT * FROM (
                                            SELECT NOMBRE_SUPUESTOS, ETIQUETA, VALOR  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO A 
                                            INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_RECORD = A.ID_PERIODO_MES
                                            WHERE CLAVE_AGRUPADOR = ''01.A.1'' AND ORDEN IN (1,2,3,4,5,5,6,7,8,9,10,11,12.13,14,15,16,17,18,19,20,21,22,23,24,25)   
                                        )PIV
                                        PIVOT ( MAX(VALOR) FOR ETIQUETA IN (' || V_FECHAS_INTERVALOS || '))';
       
       --  consulta := 'SELECT 1 FROM DUAL';
      
        DBMS_OUTPUT.PUT_LINE ( consulta);
         
      OPEN psSalida FOR consulta;
               
  
    DBMS_OUTPUT.PUT_LINE('-->> Proceso finalizado << -- ');

    EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SQLERRM;
         OPEN psSalida FOR
                SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO  EXCEPTION (OTHERS) : '|| v_error || consulta );

    END SP_REPORTE_4_A;



    
    
    
PROCEDURE SP_REPORTE_4_B(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER, P_ID_CARGA IN INTEGER)

    IS
         consulta            CLOB;
         v_error             VARCHAR2(2000);
         V_FECHAS_INTERVALOS VARCHAR2(10000);
         indexInc            INTEGER;
         V_CLAVE_AGRUPADOR   VARCHAR2(10); 
         V_INSERT_AGRUPADOR  VARCHAR2(10);
         V_RESP              NUMBER;
         
         CURSOR cur_peri_mes  IS
                SELECT 
                      B.ID_RECORD ID_PERIODO
                    , B.ETIQUETA
                    , A.CREDITOS_VIGENTES
                    , A.CREDITOS_MORA_TEMPRANA
                    , A.CREDITOS_VENCIDOS
                    , A.VENTAS_REO
                    , A.COMERCIAL
                    , A.COBRANZA_NUM_IDEN
                    , A.GASTOS_DIRECTOS
                    , A.PENDULUM_FEES
                    , A.PROMOTE
                    , A.GASTOS_ADMINISTRATIVOS
                    , A.OTROS
                    , A.COBRANZA_BRUTA
                    , A.GASTOS_TOTALES_IVA
                    , A.FLUJO_OP_DES_IMPS
                    , A.FLUJO_OP_ACUMU
                    , A.TIR_INVERSION
                    , A.CAPI_RECUPERADO_INV_INI
                    , A.IMPUESTOS_IVA
                    FROM OPERACION.TMP_CARGA_TBL_04APPTO20152 A
                    LEFT JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ETIQUETA = OPERACION.PKG_OPERACION_LEO.FN_GET_FORMATO_PERIODO( A.PERIODO, 'Mon-YY' ) AND A.ID_CARGA = P_ID_CARGA
                    WHERE  B.ID_PRESUPUESTO = P_PRESUPUESTO AND A.PERIODO != 'Periodo' 
                    ORDER BY B.ID_RECORD;  
                    
    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
            -- DECLARACION DE VARIABLES 
            V_INSERT_AGRUPADOR := '01.B.1';
            
                 
            for u in cur_peri_mes loop
                 
                    -- PASO 2 - CONSULTA VALORES 
                        
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 1,  u.CREDITOS_VIGENTES);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 2,  u.CREDITOS_MORA_TEMPRANA);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 3,  u.CREDITOS_VENCIDOS);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 4,  u.COMERCIAL);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 5,  u.VENTAS_REO);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 6,  u.COBRANZA_NUM_IDEN);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 7,  u.GASTOS_DIRECTOS);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 8,  u.PENDULUM_FEES);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 9,  u.PROMOTE);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 10,  u.GASTOS_ADMINISTRATIVOS);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 11,  u.OTROS);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 12,  u.IMPUESTOS_IVA);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 13,  u.COBRANZA_BRUTA);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 14,  u.GASTOS_TOTALES_IVA);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 15,  u.FLUJO_OP_DES_IMPS);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 16,  u.FLUJO_OP_ACUMU);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 17,  u.TIR_INVERSION);
                       OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 18, REPLACE(REPLACE(u.CAPI_RECUPERADO_INV_INI,CHR(10),''),CHR(13),'') );
                    
            end loop;
        -- Fin bucle
           
     COMMIT;
     --- OBTIENE  muestra de los valores  
      
      BEGIN
           SELECT CHR(39) || LISTAGG(SUPUESTO, ''',''')  WITHIN GROUP (ORDER BY SUPUESTO) || CHR(39)  SUPUESTO INTO V_FECHAS_INTERVALOS FROM OPERACION.VW_PPTO_SUPUESTOS_TABLES WHERE CVE_GRUPO = '01.B.1';
            
       EXCEPTION WHEN OTHERS THEN
            v_error := SQLERRM;
            OPEN psSalida FOR
                SELECT  -1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO EN PASO 1: '|| v_error);
       END;
 
        DBMS_OUTPUT.PUT_LINE('-->> GENERO REPORTE  << -- ');

        consulta := 'SELECT * FROM (
                                            SELECT NOMBRE_SUPUESTOS,  B.CONSECUTIVO_MES || B.ETIQUETA AS PERIODO, VALOR  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO A 
                                            LEFT JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_RECORD = A.ID_PERIODO_MES
                                            WHERE CLAVE_AGRUPADOR = ''01.B.1'' ORDER BY PERIODO ASC  
                                        )PIV 
                                        PIVOT ( MAX(VALOR) FOR NOMBRE_SUPUESTOS IN ( '|| V_FECHAS_INTERVALOS ||' ))';
       
       --  consulta := 'SELECT 1 FROM DUAL';
       --PIVOT ( MAX(VALOR) FOR NOMBRE_SUPUESTOS IN ( ''Vigentes (0-2 MV)'',''Créditos en Mora Temprana (3-6 MV)'',''Vencidos (+6 MV)'',''Venta REO'',''Comercial'',''Cobranza no Identificada'',''Gastos Directos'',''Pendulum Fees'',''Promote'',''Gastos administrativos'',''Otros'',''Impuestos (IVA)'', ''Cobranza Bruta'', ''Gastos totales con IVA'', ''Flujo operativo después de impuestos'',''Flujo operativo Acumulado'', ''TIR de inversión'', ''Capital recuperado de la inv. inicial'' ))';
      
        DBMS_OUTPUT.PUT_LINE ( consulta);
         
      OPEN psSalida FOR consulta;
               
  
    DBMS_OUTPUT.PUT_LINE('-->> Proceso finalizado << -- ');

    EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SQLERRM;
         OPEN psSalida FOR
                SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO  EXCEPTION (OTHERS) : '|| v_error || consulta );

    END SP_REPORTE_4_B;


PROCEDURE SP_REPORTE_4_D(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER, P_ID_CARGA IN INTEGER)

    IS
         consulta            CLOB;
         v_error             VARCHAR2(2000);
         V_FECHAS_INTERVALOS VARCHAR2(10000);
         indexInc            INTEGER;
         V_CLAVE_AGRUPADOR   VARCHAR2(10); 
         V_INSERT_AGRUPADOR  VARCHAR2(10);
         V_RESP              NUMBER;
         V_IND                NUMBER;
         V_FLAG_TAG           VARCHAR2(200);
         
         CURSOR cur_peri_mes  IS
                SELECT PERIODO, CAJA_FIN_PERIODO, DISTRIBUCIONES,  DIST_ACUMULADAS, OPERACION.PKG_OPERACION_LEO.FN_VAL_TAG(PERIODO) AS TAG FROM OPERACION.TMP_CARGA_TBL_04DPPTO2015 WHERE ID_CARGA = P_ID_CARGA AND PERIODO !='Periodo';
                    
    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
            -- DECLARACION DE VARIABLES 
            V_INSERT_AGRUPADOR := '04.D.1';
            V_IND := 0;
            V_FLAG_TAG :='';
            
            DBMS_OUTPUT.PUT_LINE('-->> INSERT  << -- ');     
            for u in cur_peri_mes loop
                IF(V_FLAG_TAG IS NULL OR V_FLAG_TAG != u.TAG) THEN 
                      V_FLAG_TAG := u.TAG;        
                      V_IND := V_IND + 1 ;
                END IF;  
            
                -- OPERACION.PPTO_PRESUPUESTO_BY_TAG
                -- DBMS_OUTPUT.PUT_LINE('-->> '|| u.TAG ||'  << -- ' || u.CAJA_FIN_PERIODO);
               OPERACION.PKG_OPERACION_LEO.SET_PPTO_PRESUPUESTO_BY_TAG(P_PRESUPUESTO, V_INSERT_AGRUPADOR, 313, u.TAG, V_IND, 1, u.CAJA_FIN_PERIODO);
               OPERACION.PKG_OPERACION_LEO.SET_PPTO_PRESUPUESTO_BY_TAG(P_PRESUPUESTO, V_INSERT_AGRUPADOR, 314, u.TAG, V_IND, 2, u.DISTRIBUCIONES);
               OPERACION.PKG_OPERACION_LEO.SET_PPTO_PRESUPUESTO_BY_TAG(P_PRESUPUESTO, V_INSERT_AGRUPADOR, 315, u.TAG, V_IND, 3,  REPLACE(REPLACE(u.DIST_ACUMULADAS,CHR(10),''),CHR(13),'')  );
                
            end loop;
        -- Fin bucle
           
     COMMIT;
     --- OBTIENE  muestra de los valores  
      
        DBMS_OUTPUT.PUT_LINE('-->> GENERO REPORTE  << -- ');

         consulta := 'SELECT * FROM (
                                        SELECT A.ETIQUETA, A.VALOR, B.DESCRIPCION, ORDEN_ETIQUETA  FROM OPERACION.PPTO_PRESUPUESTO_BY_TAG A 
                                            INNER JOIN OPERACION.PPTO_CAT_SUPUESTOS B ON A.CLAVE_SUPUESTO = B.ID_RECORD
                                        WHERE CLAVE_AGRUPADOR = ''04.D.1'' 
                                   )PIV 
                                        PIVOT ( MAX(VALOR) FOR DESCRIPCION IN ( ''Caja al final del periodo'', ''Distribuciones'', ''Distribuciones acumuladas'')) ORDER BY ORDEN_ETIQUETA ASC';
       
         -- consulta := 'SELECT 1 FROM DUAL';
      
        DBMS_OUTPUT.PUT_LINE ( consulta);
         
        OPEN psSalida FOR consulta;
               
  
    DBMS_OUTPUT.PUT_LINE('-->> Proceso finalizado << -- ');

    EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SQLERRM;
         OPEN psSalida FOR
                SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO  EXCEPTION (OTHERS) : '|| v_error || consulta );

    END SP_REPORTE_4_D;

    
    
    



   
PROCEDURE SP_REPORTE_4_E(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER, P_ID_CARGA IN INTEGER)

    IS
         consulta            CLOB;
         v_error             VARCHAR2(2000);
         V_FECHAS_INTERVALOS VARCHAR2(10000);
         indexInc            INTEGER;
         V_CLAVE_AGRUPADOR   VARCHAR2(10); 
         V_INSERT_AGRUPADOR  VARCHAR2(10);
         V_RESP              NUMBER;
         V_IND                NUMBER;
         V_FLAG_TAG           VARCHAR2(200);

         
         CURSOR cur_peri_mes  IS
                SELECT PERIODO, CAJA_FIN_PERIODO, DISTRIBUCIONES, DIST_ACUMULADAS, OPERACION.PKG_OPERACION_LEO.FN_VAL_TAG(PERIODO) AS TAG FROM OPERACION.TMP_CARGA_TBL_04EPPTO2015 WHERE ID_CARGA = P_ID_CARGA AND PERIODO !='Periodo';
                    
    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
           -- DECLARACION DE VARIABLES 
            V_INSERT_AGRUPADOR := '04.E.1';
            V_IND := 0;
            V_FLAG_TAG :='';

            
            DBMS_OUTPUT.PUT_LINE('-->> INSERT  << -- ');     
            for u in cur_peri_mes loop
                IF(V_FLAG_TAG IS NULL OR V_FLAG_TAG != u.TAG) THEN 
                      V_FLAG_TAG := u.TAG;        
                      V_IND := V_IND + 1 ;
                END IF;  
            
                -- OPERACION.PPTO_PRESUPUESTO_BY_TAG
                -- DBMS_OUTPUT.PUT_LINE('-->> '|| u.TAG ||'  << -- ' || u.CAJA_FIN_PERIODO);
               OPERACION.PKG_OPERACION_LEO.SET_PPTO_PRESUPUESTO_BY_TAG(P_PRESUPUESTO, V_INSERT_AGRUPADOR, 316, u.TAG, V_IND, 1, u.CAJA_FIN_PERIODO);
               OPERACION.PKG_OPERACION_LEO.SET_PPTO_PRESUPUESTO_BY_TAG(P_PRESUPUESTO, V_INSERT_AGRUPADOR, 317, u.TAG, V_IND, 2, u.DISTRIBUCIONES);
               OPERACION.PKG_OPERACION_LEO.SET_PPTO_PRESUPUESTO_BY_TAG(P_PRESUPUESTO, V_INSERT_AGRUPADOR, 318, u.TAG, V_IND, 3,  REPLACE(REPLACE(u.DIST_ACUMULADAS,CHR(10),''),CHR(13),'')  );
                
                    
            end loop;
        -- Fin bucle
           
     COMMIT;
     --- OBTIENE  muestra de los valores  
      
        DBMS_OUTPUT.PUT_LINE('-->> GENERO REPORTE  << -- ');

         consulta := 'SELECT * FROM (
                                        SELECT A.ETIQUETA, A.VALOR, B.DESCRIPCION, ORDEN_ETIQUETA  FROM OPERACION.PPTO_PRESUPUESTO_BY_TAG A 
                                            INNER JOIN OPERACION.PPTO_CAT_SUPUESTOS B ON A.CLAVE_SUPUESTO = B.ID_RECORD
                                        WHERE CLAVE_AGRUPADOR = ''04.E.1'' 
                                   )PIV 
                                        PIVOT ( MAX(VALOR) FOR DESCRIPCION IN ( ''Caja al final del periodo'', ''Distribuciones'', ''Distribuciones acumuladas'')) ORDER BY ORDEN_ETIQUETA ASC';      
        DBMS_OUTPUT.PUT_LINE ( consulta);
         
      OPEN psSalida FOR consulta;
               
  
    DBMS_OUTPUT.PUT_LINE('-->> Proceso finalizado << -- ');

    EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SQLERRM;
         OPEN psSalida FOR
                SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO  EXCEPTION (OTHERS) : '|| v_error || consulta );

    END SP_REPORTE_4_E;

    
    
    



   

FUNCTION FN_GET_FORMATO_PERIODO(P_CADENA IN VARCHAR2, P_MASCARA IN VARCHAR2) RETURN VARCHAR2
    IS
        V_MES VARCHAR2(15);
    BEGIN
        V_MES := '';
        
        --DBMS_OUTPUT.PUT_LINE ('FN_MES_CORTO_FROM_NUMBER, P_CADENA : ' || P_CADENA);
         
        IF P_CADENA IS NOT NULL THEN
             SELECT TO_CHAR ( TO_DATE ('01-1900', 'MM-YY', 'NLS_DATE_LANGUAGE = SPANISH') + P_CADENA - 2, P_MASCARA, 'NLS_DATE_LANGUAGE = SPANISH')
             INTO V_MES
             FROM DUAL;
        END IF;
        
      --  DBMS_OUTPUT.PUT_LINE ('return V_MES ----->  : ' || V_MES);
        
        RETURN V_MES;
    
    EXCEPTION
          WHEN value_error
          THEN
             RETURN V_MES;
    END FN_GET_FORMATO_PERIODO;


FUNCTION FN_VAL_TAG(P_CADENA IN VARCHAR2) RETURN VARCHAR2
      IS
          V_MES         VARCHAR2(15);
          P_MASCARA     VARCHAR2(2000);
          P_RETURN      VARCHAR2(2000);
          P_NUMBER_FEC  NUMBER;
          P_IS_NUMBER  NUMBER;
          
      BEGIN
      V_MES := '';
      P_MASCARA := 'Mon-YY';
      
      --VALIDO SI ES CADENA O NUMERO
          BEGIN
                           
               SELECT TO_NUMBER(P_CADENA) VAL INTO P_IS_NUMBER FROM DUAL; 
               
          EXCEPTION WHEN OTHERS THEN
                         
               P_IS_NUMBER := 0;
                              
          END;
              
          IF (P_IS_NUMBER != 0) THEN --SI ES NUMERO
              
              IF P_CADENA IS NOT NULL AND  LENGTH(P_CADENA) = 4 THEN
                  
                  IF (P_CADENA >= 2000 )THEN
                      
                       P_RETURN := P_CADENA;
                      
                  ELSIF (P_CADENA < 2000)THEN
                      
                       P_RETURN := '0';
                      
                  ELSE
                      
                     P_RETURN := P_CADENA;   
                      
                  END IF;
                  
                 DBMS_OUTPUT.PUT_LINE ('CONDI 1 VALIDA ANIO  ----->  : ' || P_RETURN);
                             
                   
              ELSIF P_CADENA IS NOT NULL AND LENGTH(P_CADENA) > 4  THEN
                 
                 SELECT OPERACION.PKG_OPERACION_LEO.FN_GET_FORMATO_PERIODO(P_CADENA,P_MASCARA) INTO V_MES FROM DUAL; 
                 P_RETURN := V_MES;
                 
              ELSE
                   
                   P_RETURN := '0';
                  DBMS_OUTPUT.PUT_LINE ('CONDI 3 ----->  : ' || P_RETURN);

              END IF;
              
          ELSE
              DBMS_OUTPUT.PUT_LINE ('es varchar');
            P_RETURN := P_CADENA; 
              
          END IF;     
      DBMS_OUTPUT.PUT_LINE ('END FN_VAL_TAG');
      RETURN P_RETURN;
      
  
  EXCEPTION
        WHEN value_error
        THEN
           RETURN P_CADENA;
           DBMS_OUTPUT.PUT_LINE ('ERROR ----->  : ' || P_RETURN);
  END FN_VAL_TAG;



PROCEDURE SET_PPTO_PRESUPUESTO_BY_TAG(PA_ID_PRESUPUESTO  IN NUMBER, PA_CLAVE_AGRUPADOR IN VARCHAR2, PA_CLAVE_SUPUESTO IN VARCHAR2, PA_ETIQUETA IN VARCHAR2, PA_ORDEN_ETIQUETA  IN NUMBER, PA_ORDEN_SUPUESTO IN NUMBER, PA_VALOR IN NUMBER)
/***********************************************************************************************
*DECRIPCION:              PROCEDIMIENTO ENCARGADO DE VAIDAR LA TABLA 4.C
*PARAMETROS DE ENTRADA:   P_ID_CARGA          - VARIABLE QUE CONTIENE EL IDENTIFICADOR DE LA CARGA A VALIDAR
*PARAMETROS DE SALIDA:    
*CREADOR:                 OSCAR TZOMPANTZI    
*FECHA:                   06/11/2018         
*MODIFICO:                
*FECHA MODIFICACION:  
********************************************************************************************************/
     IS  
     BEGIN
            INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_TAG ( ID_RECORD
                                                           ,ID_PRESUPUESTO
                                                           ,CLAVE_AGRUPADOR
                                                           ,CLAVE_SUPUESTO
                                                           ,ETIQUETA
                                                           ,ORDEN_ETIQUETA
                                                           ,ORDEN_SUPUESTO
                                                           ,VALOR  )
                 VALUES ( OPERACION.PPTO_SEQ_PRESUPUESTO_BY_TAG.NEXTVAL
                         ,PA_ID_PRESUPUESTO
                         ,PA_CLAVE_AGRUPADOR
                         ,PA_CLAVE_SUPUESTO
                         ,PA_ETIQUETA
                         ,PA_ORDEN_ETIQUETA
                         ,PA_ORDEN_SUPUESTO
                         ,PA_VALOR 
                        ); 
                        COMMIT;
END SET_PPTO_PRESUPUESTO_BY_TAG;


END PKG_OPERACION_LEO;
/
