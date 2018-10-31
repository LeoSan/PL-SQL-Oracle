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
         V_CLAVE_AGRUPADOR   VARCHAR2(10);
 
         V_COLLATERALVALUE   FLOAT;   -- CALCULO  1 
         V_VENTAS            FLOAT;   -- CALCULO  2
         V_VENTAS_ACUMULADA  FLOAT;   -- CALCULO  3
         V_TOTAL_CUENTAS     INTEGER; -- CALCULO  4
         V_SUPUESTO          FLOAT;   -- CALCULO  4
         V_SUMA_PERIODOS     FLOAT;   -- CALCULO  4
         V_PROMEDIO          FLOAT;   -- CALCULO  4
         V_VALOR             FLOAT;   -- CALCULO  5  
         V_CONT_ENTRADAS_REO FLOAT;   -- CALCULO  6
         V_VALOR_6           FLOAT;   -- CALCULO  6
         V_GARANTIA_REO      FLOAT;   -- CALCULO  6
         V_GARANTIA_VEN      FLOAT;   -- CALCULO  6 
         V_ENTRADAS_REO      FLOAT;   -- CALCULO  6
         
        CURSOR intervalos_cur  IS
                    SELECT
                    B.ETIQUETA
                    , B.ID_RECORD
                    FROM OPERACION.PPTO_PERIODO_ANIO_MES B 
                    WHERE B.ID_RECORD > 1 AND  B.ID_PRESUPUESTO = P_PRESUPUESTO
                          ORDER BY B.ID_RECORD ASC;
                
                         
        TYPE ARREGLOS_INTERVALOS
        IS RECORD (
            rETIQUETA         VARCHAR2(100),         
            rCOLLATERALVALUE  FLOAT,         -- VAR PARA CALCULO 1 
            rID_RECORD        INTEGER,
            rACUMULA          FLOAT,         -- VAR PARA CALCULO 3
            rCALCULO_4        FLOAT,         -- VAR PARA CALCULO 4
            rENTRADASREO      FLOAT,         -- VAR PARA CALCULO 5
            rGARANTIATOTAL    FLOAT          -- VAR PARA CALCULO 6
        );

        TYPE TABINTERVALOS IS TABLE OF ARREGLOS_INTERVALOS INDEX BY BINARY_INTEGER;
        
        psDetalle TABINTERVALOS; 


    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
        -- DECLARACION DE VARIABLES 
        indexInc := 1;
        V_CONT_ENTRADAS_REO := 0;
        V_CLAVE_AGRUPADOR := '14.D.1';
 
        --  CONSULTAS 
        -- PARA CALCULO 4 
        SELECT COUNT(ID_RECORD) TOTAL INTO V_TOTAL_CUENTAS FROM OPERACION.PPTO_BASE_CREDITOS_REO WHERE ID_PRESUPUESTO = P_PRESUPUESTO;
        
        SELECT PORCENTAJE INTO V_SUPUESTO FROM OPERACION.PPTO_RESUMEN_CREDITOS WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ORDEN = 4;
        
        
        -- Recorremos el cursor con un bucle for - loop
            for u in intervalos_cur loop
             
             -- PASO 1 - CALCULO  Valor Total de Garantias en REO - 1 - 
                    BEGIN
                     
                        SELECT SUM(VALOR) TOTAL INTO V_COLLATERALVALUE  FROM OPERACION.PPTO_PERIODO_BASECREDITOS WHERE NOMBRE_AGRUPADOR = '22.B.1' AND ID_PERIODO_MES = u.ID_RECORD AND ID_PRESUPUESTO = P_PRESUPUESTO GROUP BY ID_PERIODO_MES;
                                
                    EXCEPTION WHEN OTHERS THEN
                        v_error := SQLERRM;
                        OPEN psSalida FOR
                        SELECT  -1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
                        DBMS_OUTPUT.PUT_LINE ('ERROR  - PASO 1: - CALCULO 1 -  '|| v_error);

                    END;
             
                    --INSERT DE CALCULOS 
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_RECORD, 1, '22.A.1', 'Valor Total de Garantias en REO',  V_COLLATERALVALUE);



             -- PASO 2 - CALCULO  Ventas REO - 2 -

                    BEGIN
                     
                     SELECT VALOR INTO V_VENTAS FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = V_CLAVE_AGRUPADOR AND ID_PERIODO_MES = u.ID_RECORD AND ORDEN = 6;
                                
                    EXCEPTION WHEN OTHERS THEN
                        v_error := SQLERRM;
                        OPEN psSalida FOR
                        SELECT  -1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
                        DBMS_OUTPUT.PUT_LINE ('ERROR  - PASO 2: - CALCULO 2 -  '|| v_error);

                    END;
            
                    --INSERT VALORES CALCULADOS 
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS,  VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_RECORD, 2, '22.A.1', 'Ventas REO', V_VENTAS);

             -- PASO 3 - CALCULO  Ventas REO Acumuladas - 3 -
             
                    BEGIN
                     
                        SELECT VALOR INTO V_VENTAS_ACUMULADA FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = V_CLAVE_AGRUPADOR AND ID_PERIODO_MES = u.ID_RECORD AND ORDEN = 6;
                                
                    EXCEPTION WHEN OTHERS THEN
                        v_error := SQLERRM;
                        OPEN psSalida FOR
                        SELECT  -1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
                        DBMS_OUTPUT.PUT_LINE ('ERROR  - PASO 3: - CALCULO 3 -  '|| v_error);
                        
                    END;
            
                    
                    IF (indexInc = 1 ) THEN
                    
                        psDetalle(indexInc).rACUMULA := V_VENTAS_ACUMULADA;
                        
                    ELSE    
                        psDetalle(indexInc).rACUMULA := V_VENTAS_ACUMULADA + psDetalle( indexInc - 1 ).rACUMULA;
                    
                    END IF;
                    
                    --INSERT DE CALCULOS 
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_RECORD, 3, '22.A.1', 'Ventas REO Acumuladas', psDetalle(indexInc).rACUMULA);

             -- PASO 4 - CALCULO  Valor de Garantiaa de las ventas - 4 -
             
                    BEGIN
                    
                        SELECT SUM(VALOR) TOTAL_SUMA_PERIODO INTO V_SUMA_PERIODOS  FROM OPERACION.PPTO_PERIODO_BASECREDITOS WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND ID_PERIODO_MES = u.ID_RECORD AND NOMBRE_AGRUPADOR = '22.B.1';

                        SELECT Avg(VALOR) PROMEDIO INTO V_PROMEDIO FROM OPERACION.PPTO_PERIODO_BASECREDITOS WHERE VALOR > 0 AND ID_PRESUPUESTO = P_PRESUPUESTO AND ID_PERIODO_MES = u.ID_RECORD AND NOMBRE_AGRUPADOR = '22.B.1';
                        
                     
                        IF (V_SUMA_PERIODOS <= V_TOTAL_CUENTAS ) THEN
                            
                            psDetalle(indexInc).rCALCULO_4 :=  V_SUMA_PERIODOS * V_PROMEDIO;
                            
                        ELSE    
                            
                            psDetalle(indexInc).rCALCULO_4 := V_TOTAL_CUENTAS * V_PROMEDIO + ( V_SUMA_PERIODOS - V_TOTAL_CUENTAS ) * V_SUPUESTO;
                        
                        END IF;
                    
                                
                    EXCEPTION WHEN OTHERS THEN
                        v_error := SQLERRM;
                        OPEN psSalida FOR
                        SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
                        DBMS_OUTPUT.PUT_LINE (' PASO 4 - CALCULO 4 -> : '|| v_error  );
                    END;
            
                    --INSERT DE CALCULOS 
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_RECORD, 4, '22.A.1', 'Valor de Garantia de las ventas', psDetalle(indexInc).rCALCULO_4);

             -- PASO 5 - CALCULO  Entradas a REO - 5 -      
             
              BEGIN
              
                     
                    SELECT VALOR INTO V_VALOR  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = V_CLAVE_AGRUPADOR AND ID_PERIODO_MES = u.ID_RECORD AND ORDEN = 2;
                                
              EXCEPTION WHEN OTHERS THEN
                    v_error := SQLERRM;
                    OPEN psSalida FOR
                    SELECT  -1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
                    DBMS_OUTPUT.PUT_LINE ('ERROR  - PASO 5: - CALCULO 5 -  '|| v_error);
              END;
            
                    psDetalle(indexInc).rENTRADASREO := V_VALOR * V_SUPUESTO;
          
                    --INSERT DE CALCULOS 
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_RECORD, 5, '22.A.1', 'Entradas a REO',  psDetalle(indexInc).rENTRADASREO);       
        
             -- PASO 6 - CALCULO  Garantia Remanente Total - 6 -

                BEGIN
                    
                        SELECT VALOR INTO V_VALOR_6 FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = V_CLAVE_AGRUPADOR AND ORDEN = 11 AND ID_PERIODO_MES = u.ID_RECORD; 
                        
                     
                        IF (V_VALOR < 0.5 ) THEN
                            DBMS_OUTPUT.PUT_LINE (' ------  ENTRO AL PRIMER  CONDICIONAL ------- ');
                            psDetalle(indexInc).rGARANTIATOTAL := 0;
                            
                        ELSE
                            
                            SELECT VALOR INTO V_GARANTIA_REO FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '22.A.1' AND ORDEN = 1 AND ID_PERIODO_MES = u.ID_RECORD;
                            
                            SELECT VALOR INTO V_GARANTIA_VEN FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '22.A.1' AND ORDEN = 4 AND ID_PERIODO_MES = u.ID_RECORD;
                            
                            SELECT VALOR INTO V_ENTRADAS_REO FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '22.A.1' AND ORDEN = 5 AND ID_PERIODO_MES = u.ID_RECORD;
                        
                            V_CONT_ENTRADAS_REO := V_CONT_ENTRADAS_REO + V_ENTRADAS_REO;  
                        
                        
                                IF ( (V_GARANTIA_REO - (V_GARANTIA_VEN + V_CONT_ENTRADAS_REO ) ) < 0 ) THEN
                                    DBMS_OUTPUT.PUT_LINE (' ------  ENTRO AL SEGUNDO CONDICIONAL  ------- ');
                                    --DBMS_OUTPUT.PUT_LINE (' CALCULO -> ' || '|V_GARANTIA_REO - ' || V_GARANTIA_REO || '- (V_GARANTIA_VEN ' || V_GARANTIA_VEN || '+ V_CONT_ENTRADAS_REO) ' || V_CONT_ENTRADAS_REO );
                                    psDetalle(indexInc).rGARANTIATOTAL := 0;
                                    
                                ELSE    
                                    DBMS_OUTPUT.PUT_LINE (' ------  ENTRO AL ULTIMO CONDICIONAL  ------- ');
                                    psDetalle(indexInc).rGARANTIATOTAL := (V_GARANTIA_REO - (V_GARANTIA_VEN + V_CONT_ENTRADAS_REO ) );
                                    
                                END IF;    
                        
                        END IF;
                    
                                
                    EXCEPTION WHEN OTHERS THEN
                        v_error := SQLERRM;
                        OPEN psSalida FOR
                        SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
                        DBMS_OUTPUT.PUT_LINE (' ERROR PASO 6 - CALCULO 6 -> : '|| v_error  );
                    END;
            
                    --INSERT DE CALCULOS 
                    INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_RECORD, 6, '22.A.1', 'Garantia Remanente Total', psDetalle(indexInc).rGARANTIATOTAL);

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
               SELECT
                    B.ID_RECORD ID_PERIODO
                    , (SELECT COUNT(ID_RECORD) FROM OPERACION.PPTO_BASE_CREDITOS_REO WHERE ID_PRESUPUESTO = 2000 )  AS CALCULO_1
                    , (SELECT VALOR  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1' AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 15 ) + ( SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1' AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 16 )  AS CALCULO_2
                    , (SELECT VALOR  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1' AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 15 )  AS CALCULO_3
                    , (SELECT VALOR  FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1' AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 16 )  AS CALCULO_4
                    , (SELECT SUM(VALOR) FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '15.C.1' AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN IN (1, 2, 3, 4)) AS CALCULO_5
                    , (SELECT SUM(VALOR) FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '15.C.1' AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN IN (1)) AS CALCULO_6
                    , (SELECT SUM(VALOR) FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '15.C.1' AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN IN (2)) AS CALCULO_7
                    , (SELECT SUM(VALOR) FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '15.C.1' AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN IN (3)) AS CALCULO_8
                    , (SELECT SUM(VALOR) FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '15.C.1' AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN IN (4)) AS CALCULO_9
                                    FROM OPERACION.PPTO_BASE_CREDITOS_REO A 
                                    INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                                    WHERE A.ID_PRESUPUESTO = 2000  
                                    GROUP BY B.ID_RECORD 
                                    ORDER BY B.ID_RECORD ASC;
                
    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');

        -- DECLARACION DE VARIABLES 
         V_INSERT_AGRUPADOR := '14.D.1';
         
       
         for u in intervalos_cur loop
                -- CALCULO  PASO 1
                --INSERT DE CALCULOS 
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 1, u.CALCULO_1);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 2, u.CALCULO_2);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 3, u.CALCULO_3);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 4, u.CALCULO_4);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 5, 0);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 6, u.CALCULO_5);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 7, u.CALCULO_6);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 8, u.CALCULO_7);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 9, u.CALCULO_8);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 10, u.CALCULO_9);
                    OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 11, u.CALCULO_1 + ( u.CALCULO_2 - u.CALCULO_5 ) );
                
            /*                  
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 1,  V_INSERT_AGRUPADOR,  'Créditos REO(inicial)', u.CALCULO_1);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 2,  V_INSERT_AGRUPADOR,  'Entradas',       u.CALCULO_2);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 3,  V_INSERT_AGRUPADOR,  'Dación en Pago', u.CALCULO_3);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 4,  V_INSERT_AGRUPADOR,  'Adjudicaciones', u.CALCULO_4);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 5,  V_INSERT_AGRUPADOR,  'Salidas', 0);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 6,  V_INSERT_AGRUPADOR,  'Ventas REO',    u.CALCULO_5);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 7,  V_INSERT_AGRUPADOR,  'Rematado',      u.CALCULO_6);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 8,  V_INSERT_AGRUPADOR,  'Escriturado',   u.CALCULO_7);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 9,  V_INSERT_AGRUPADOR,  'Con posesión',  u.CALCULO_8);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 10, V_INSERT_AGRUPADOR,  'Caso especial', u.CALCULO_9);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 11, V_INSERT_AGRUPADOR,  'Créditos REO (final)', u.CALCULO_1 + ( u.CALCULO_2 - u.CALCULO_5 ) ); 
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
                SELECT
                    B.ID_RECORD ID_PERIODO
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.A.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 1) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 ) * 100 AS CALCULO_1
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.A.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 2) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 ) * 100 AS CALCULO_2
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.A.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 4) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 ) * 100 AS CALCULO_3
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.A.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 5) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 ) * 100 AS CALCULO_4
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.A.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 6) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 ) * 100 AS CALCULO_5
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.A.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 7) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 ) * 100 AS CALCULO_6

                FROM OPERACION.PPTO_BASE_CREDITOS_REO A 
                INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                WHERE A.ID_PRESUPUESTO = P_PRESUPUESTO  /* AND B.ID_RECORD < 20*/ 
                GROUP BY B.ID_RECORD 
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
                SELECT
                B.ID_RECORD ID_PERIODO
                , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.B.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 1) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_1
                , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.B.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 2) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_2
                , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.B.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 4) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_3
                , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.B.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 5) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_4
                , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.B.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 6) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_5

                                FROM OPERACION.PPTO_BASE_CREDITOS_REO A 
                                INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                                WHERE A.ID_PRESUPUESTO = P_PRESUPUESTO /* AND B.ID_RECORD < 20*/
                                GROUP BY B.ID_RECORD 
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
                
                
                /* INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 1, V_INSERT_AGRUPADOR, 'Creditos Moras Tempranas (inicial)', u.CALCULO_1);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 2, V_INSERT_AGRUPADOR, 'Entradas', u.CALCULO_2);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 4, V_INSERT_AGRUPADOR, 'Migración a corriente', u.CALCULO_3);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 5, V_INSERT_AGRUPADOR, 'Migración a vencido', u.CALCULO_4);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 6, V_INSERT_AGRUPADOR, 'Migración a vencido', u.CALCULO_5);
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
                                            WHERE CLAVE_AGRUPADOR = ''14.G.1'' AND ORDEN IN (1,2,4, 5,6)   
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
               SELECT
                    B.ID_RECORD ID_PERIODO
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 1) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_1
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 2) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_2
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 5) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_3
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 6) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_4
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 7) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_5
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 8) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_6
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 9) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_7
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 ) AS CALCULO_8
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 14) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 ) AS CALCULO_9
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 13) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 ) AS CALCULO_10
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.C.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 18) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 ) AS CALCULO_11
                                    FROM OPERACION.PPTO_BASE_CREDITOS_REO A 
                                    INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                                    WHERE A.ID_PRESUPUESTO = P_PRESUPUESTO  /* AND B.ID_RECORD < 20*/ 
                                    GROUP BY B.ID_RECORD 
                                    ORDER BY B.ID_RECORD ASC; 
                
                         
       

    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
        -- DECLARACION DE VARIABLES 
        V_INSERT_AGRUPADOR := '14.H.1';
        
            for u in intervalos_cur loop
                  
                -- CALCULO  PASO 1
                --INSERT DE CALCULOS 
                
                
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 1,  u.CALCULO_1);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 2,  u.CALCULO_2);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 3,  u.CALCULO_3);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 4, 0);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 5,  u.CALCULO_4);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 6,  u.CALCULO_5);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 7,  u.CALCULO_6);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 8,  u.CALCULO_7);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 9,  u.CALCULO_8);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 10, u.CALCULO_9);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 11, u.CALCULO_10);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 12, u.CALCULO_11);
                /*
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 1, V_INSERT_AGRUPADOR, 'Créditos vencidos (inicial)', u.CALCULO_1);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 2, V_INSERT_AGRUPADOR, 'Entradas', u.CALCULO_2);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 3, V_INSERT_AGRUPADOR, 'Salidas', 0);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 4, V_INSERT_AGRUPADOR, 'Restructuras Corto Plazo', u.CALCULO_3);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 5, V_INSERT_AGRUPADOR, 'Restructuras Largo Plazo', u.CALCULO_4);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 6, V_INSERT_AGRUPADOR, 'Pago Unico deudor', u.CALCULO_5);
                  
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 7, V_INSERT_AGRUPADOR, 'Pago Único cesión', u.CALCULO_6);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 8, V_INSERT_AGRUPADOR, 'Adjudicación', u.CALCULO_7);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 9, V_INSERT_AGRUPADOR, 'Dación en Pago', u.CALCULO_8);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 10, V_INSERT_AGRUPADOR,'Venta de Paquetes', u.CALCULO_9);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 11, V_INSERT_AGRUPADOR,'Diferimiento', u.CALCULO_10);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 12, V_INSERT_AGRUPADOR,'Créditos vencidos (final)', u.CALCULO_11);
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
               SELECT
                    B.ID_RECORD ID_PERIODO
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.D.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 1) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_1
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.D.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 2) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_2
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.D.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 6) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 )  AS CALCULO_3
                    , (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.D.1'  AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 11) / (SELECT VALOR FROM OPERACION.PPTO_PRESUPUESTO_BY_GRUPO WHERE CLAVE_AGRUPADOR = '14.E.1' AND ID_PERIODO_MES = B.ID_RECORD AND ORDEN = 10 ) AS CALCULO_4
                                    FROM OPERACION.PPTO_BASE_CREDITOS_REO A 
                                    INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                                    WHERE A.ID_PRESUPUESTO = P_PRESUPUESTO  /* AND B.ID_RECORD < 20*/ 
                                    GROUP BY B.ID_RECORD 
                                    ORDER BY B.ID_RECORD ASC; 
                
                         
       

    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
        -- DECLARACION DE VARIABLES 
        V_INSERT_AGRUPADOR := '14.I.1';
        
            for u in intervalos_cur loop
                  
                -- CALCULO  PASO 1
                --INSERT DE CALCULOS 
                
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 1,  u.CALCULO_1);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 2,  u.CALCULO_2);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 3,  0);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 4,  u.CALCULO_3);
                OPERACION.PKG_PPTO_PRESUPUESTOS.SP_SET_TBL_ONETONE (V_RESP, u.ID_PERIODO, V_INSERT_AGRUPADOR, 5,  u.CALCULO_4);
                
                
                /*
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 1, V_INSERT_AGRUPADOR, 'Créditos REO(inicial)', u.CALCULO_1);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 2, V_INSERT_AGRUPADOR, 'Entradas', u.CALCULO_2);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 3, V_INSERT_AGRUPADOR, 'Salidas', 0);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 4, V_INSERT_AGRUPADOR, 'Ventas REO', u.CALCULO_3);
                  INSERT INTO OPERACION.PPTO_PRESUPUESTO_BY_GRUPO (ID_RECORD, ID_PERIODO_MES, ORDEN, CLAVE_AGRUPADOR, NOMBRE_SUPUESTOS, VALOR) VALUES (OPERACION.PPTO_SEQ_PRESUPUESTO_BY_GRUPO.NEXTVAL, u.ID_PERIODO, 5, V_INSERT_AGRUPADOR, 'Créditos REO (final)', u.CALCULO_4);
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







PROCEDURE SP_VALIDAR_DATOS_TBL_49A
     IS  
         V_TABLA VARCHAR2(10);
         V_MENSAGE_ERROR VARCHAR2(600);
         V_NUM_REG NUMBER;
         
         CURSOR c1 IS 
              SELECT                                 
                     ID_ETAPA           
                    ,NOM_ETAPA
                    ,COSTO
                    ,ERROR
                    ,ERROR_DESC
              FROM OPERACION.TMP_CARGA_TBL_49AGPPTO2017;
    BEGIN
        dbms_output.put_line  (' --- INICIA PROCESO  --- ');
        
        V_TABLA := '49.A';
        V_NUM_REG := 1;        
        
       --DELETE FROM OPERACION.TMP_CARGA_TBL_VALIDACIONES  WHERE ID_TABLA = V_TABLA;
       
       FOR temporal_rec in c1        
       LOOP  
                V_MENSAGE_ERROR := ''; 
                
               
                    
            IF OPERACION.PKG_PPTO_JAVACLE_UTILS.FN_PPTO_VALIDA_NUMERO (temporal_rec.ID_ETAPA) = 0 THEN
                V_MENSAGE_ERROR := V_MENSAGE_ERROR || '{PERIODO : NO ES NUMERO VALIDO} ';
            END IF;
                
           
            IF OPERACION.PKG_OPERACION_LEO.FN_PPTO_VALIDA_MONEDA (temporal_rec.COSTO) = 0 THEN
                V_MENSAGE_ERROR := V_MENSAGE_ERROR || '{COSTO : NO ES NUMERO VALIDO} ';
            END IF;

 
             dbms_output.put_line  ('V_MENSAGE_ERROR ' || V_MENSAGE_ERROR); 
                
                  IF TRIM(V_MENSAGE_ERROR) IS NOT NULL  THEN  
                  
                      IF temporal_rec.ID_ETAPA IS NOT NULL THEN
                         UPDATE OPERACION.TMP_CARGA_TBL_49AGPPTO2017 
                         SET ERROR = 1, ERROR_DESC = V_MENSAGE_ERROR
                         WHERE TRIM(ID_ETAPA) =  TRIM(temporal_rec.ID_ETAPA);
                      ELSE
                         UPDATE OPERACION.TMP_CARGA_TBL_49AGPPTO2017 
                         SET ERROR = 1, ERROR_DESC = V_MENSAGE_ERROR
                         WHERE ID_ETAPA IS NULL;
                     END IF;
                    
                END IF;     
                
                 COMMIT;
                 
       END LOOP;
   
    dbms_output.put_line  (' --- FIN DE  PROCESO  --- ');
    END SP_VALIDAR_DATOS_TBL_49A;
        


PROCEDURE SP_VALIDAR_DATOS_TBL_49C
     IS  
         V_TABLA VARCHAR2(10);
         V_MENSAGE_ERROR VARCHAR2(600);
         V_NUM_REG NUMBER;
         
         CURSOR c1 IS 
              SELECT                                 
                     ID_ETAPA           
                    ,NOM_ETAPA
                    ,COSTO
                    ,ERROR
                    ,ERROR_DESC
              FROM OPERACION.TMP_CARGA_TBL_49CGPPTO2017;
    BEGIN
        V_TABLA := '49.C';
        V_NUM_REG := 1;        
        
       --DELETE FROM OPERACION.TMP_CARGA_TBL_VALIDACIONES  WHERE ID_TABLA = V_TABLA;
       
       FOR temporal_rec in c1        
       LOOP  
                V_MENSAGE_ERROR := ''; 
                
                
                IF OPERACION.PKG_PPTO_JAVACLE_UTILS.FN_PPTO_VALIDA_NUMERO (temporal_rec.ID_ETAPA) = 0 THEN
                    V_MENSAGE_ERROR := V_MENSAGE_ERROR || '{PERIODO : NO ES NUMERO VALIDO} ';
                END IF;
                
               
                IF OPERACION.PKG_OPERACION_LEO.FN_PPTO_VALIDA_MONEDA (temporal_rec.COSTO) = 0 THEN
                    V_MENSAGE_ERROR := V_MENSAGE_ERROR || '{COSTO : NO ES NUMERO VALIDO} ';
                END IF;



                dbms_output.put_line  ('V_MENSAGE_ERROR ' || V_MENSAGE_ERROR); 
                
                  IF TRIM(V_MENSAGE_ERROR) IS NOT NULL  THEN  
                  
                      IF temporal_rec.ID_ETAPA IS NOT NULL THEN
                         UPDATE OPERACION.TMP_CARGA_TBL_49CGPPTO2017 
                         SET ERROR = 1, ERROR_DESC = V_MENSAGE_ERROR
                         WHERE TRIM(ID_ETAPA) =  TRIM(temporal_rec.ID_ETAPA);
                      ELSE
                         UPDATE OPERACION.TMP_CARGA_TBL_49CGPPTO2017 
                         SET ERROR = 1, ERROR_DESC = V_MENSAGE_ERROR
                         WHERE ID_ETAPA IS NULL;
                     END IF;
                    
                END IF;     
                
                 COMMIT;
                 
       END LOOP;
   
    END SP_VALIDAR_DATOS_TBL_49C;
        


PROCEDURE SP_VALIDAR_DATOS_TBL_44C
     IS  
         V_TABLA VARCHAR2(10);
         V_MENSAGE_ERROR VARCHAR2(600);
         V_NUM_REG NUMBER;
         
         CURSOR c1 IS 
              SELECT                                 
                     ANIO_MES           
                    ,AJUSTADO
                    ,NORMAL
                    ,ANIO
                    ,MES
                    ,ERROR
                    ,ERROR_DESC 
              FROM OPERACION.TMP_CARGA_TBL_44CGPPTO2017;
    BEGIN
        V_TABLA := '44.C';
        V_NUM_REG := 1;        
        
       -- DELETE FROM OPERACION.TMP_CARGA_TBL_VALIDACIONES  WHERE ID_TABLA = V_TABLA;
       
       FOR temporal_rec in c1        
       LOOP  
                V_MENSAGE_ERROR := ''; 
                
                
                IF OPERACION.PKG_PPTO_JAVACLE_UTILS.FN_PPTO_VALIDA_NUMERO (temporal_rec.NORMAL) = 0 THEN
                    V_MENSAGE_ERROR := V_MENSAGE_ERROR || '{NORMAL : NO ES NUMERO VALIDO} ';
                END IF;
                
                IF OPERACION.PKG_PPTO_JAVACLE_UTILS.FN_PPTO_VALIDA_NUMERO (temporal_rec.ANIO) = 0 THEN
                    V_MENSAGE_ERROR := V_MENSAGE_ERROR || '{ANIO : NO ES NUMERO VALIDO} ';
                END IF;
                
                IF OPERACION.PKG_OPERACION_LEO.FN_PPTO_VALIDA_MONEDA (temporal_rec.MES) = 0 THEN
                    V_MENSAGE_ERROR := V_MENSAGE_ERROR || '{MES : NO ES NUMERO VALIDO} ';
                END IF;
                

               dbms_output.put_line  ('V_MENSAGE_ERROR ' || V_MENSAGE_ERROR); 
                
                  IF TRIM(V_MENSAGE_ERROR) IS NOT NULL  THEN  
                  
                      IF temporal_rec.ANIO_MES IS NOT NULL THEN
                         UPDATE OPERACION.TMP_CARGA_TBL_44CGPPTO2017 
                         SET ERROR = 1, ERROR_DESC = V_MENSAGE_ERROR
                         WHERE TRIM(ANIO_MES) =  TRIM(temporal_rec.ANIO_MES);
                      ELSE
                         UPDATE OPERACION.TMP_CARGA_TBL_44CGPPTO2017 
                         SET ERROR = 1, ERROR_DESC = V_MENSAGE_ERROR
                         WHERE ANIO_MES IS NULL;
                     END IF;
                    
                END IF;     
                
                 COMMIT;
                 
       END LOOP;
   
    END SP_VALIDAR_DATOS_TBL_44C;
        



FUNCTION FN_PPTO_VALIDA_MONEDA( P_CADENA IN VARCHAR2 ) RETURN FLOAT
    
    IS
        RESPONSE NUMBER;
        MONEDA FLOAT;
        BEGIN
            RESPONSE := 0; -- Representa que esta mal  
            IF P_CADENA IS NOT NULL THEN
              MONEDA:= REPLACE(REPLACE(REPLACE(P_CADENA,CHR(10),''),CHR(13),''), '%', '');  
              MONEDA:= REPLACE(REPLACE(REPLACE(P_CADENA,CHR(10),''),CHR(13),''), '$', '');
              
              IF TO_NUMBER (MONEDA) >= 0 THEN
                RESPONSE := 1; -- MONEDA; Representa que esta bien
              ELSE
                RESPONSE := 0; -- Representa que esta mal
              END IF;
              
            ELSE
              RESPONSE := 0; -- Representa que esta mal
            END IF;
            
            RETURN RESPONSE;
          
        EXCEPTION
          WHEN value_error
          THEN
             RETURN 0;
             
    END FN_PPTO_VALIDA_MONEDA;




-- insertar input catalogo 
PROCEDURE SP_CARGA_TEMP_PPTO_INPUTS_49A( P_CADENA IN VARCHAR2 )
   IS  
       V_TOTAL_ERROR   NUMBER;
       V_ID_CARTERA    NUMBER;
       V_COSTO         NUMBER;
       
        CURSOR c1 IS
            SELECT                                 
                 ID_ETAPA           
                ,NOM_ETAPA
                ,COSTO
                ,ERROR
                ,ERROR_DESC
            FROM OPERACION.TMP_CARGA_TBL_49AGPPTO2017; 
            
   BEGIN
       dbms_output.put_line  (' 49 SP_CARGA_TEMP_PPTO_INPUTS_49A');
         
        SELECT COUNT(ERROR) TOTAL INTO V_TOTAL_ERROR FROM OPERACION.TMP_CARGA_TBL_49AGPPTO2017 WHERE ERROR = 1 ;
        
        SELECT ID_CARTERA INTO V_ID_CARTERA FROM OPERACION.CAT_CARTERA WHERE IDCARTERAPM = P_CADENA;
       
       IF V_TOTAL_ERROR = 0 THEN 
       
            FOR temporal_rec in c1 LOOP
            
                  V_COSTO:= REPLACE(REPLACE(REPLACE(temporal_rec.COSTO,CHR(10),''),CHR(13),''), '$', '');            
                 -- dbms_output.put_line  ( 'valor costo BD  ->'    || temporal_rec.COSTO || '| valor costo condi  -> ' || V_COSTO );

                 INSERT INTO OPERACION.PPTO_CAT_GASTOS_REEMBOLSABLES (ID_CAT_GASTOS_REEMBOLSABLES, ID_CARTERA, ETAPA, NOMBRE_ETAPA, COSTO_PENDULUM, ESTATUS) VALUES (OPERACION.PPTO_SEQ_CAT_GASTOS_REEMBOL.NEXTVAL, V_ID_CARTERA, to_char(temporal_rec.ID_ETAPA), temporal_rec.NOM_ETAPA, V_COSTO, 2);
                     
            END LOOP; 
       ELSE
        
        dbms_output.put_line  (' No Procede insercion: Se encontro numero total de errore : ' || V_TOTAL_ERROR || ', Por favor validar la tabla OPERACION.TMP_CARGA_TBL_49AGPPTO2017' );
        
       END IF; 

   COMMIT; 
  
   END SP_CARGA_TEMP_PPTO_INPUTS_49A;







PROCEDURE SP_CARGA_TEMP_PPTO_INPUTS_49C( P_CADENA IN VARCHAR2 )
   IS  
       V_TOTAL_ERROR   NUMBER;
       V_ID_CARTERA    NUMBER;
       V_COSTO         NUMBER;
       
        CURSOR c1 IS
            SELECT                                 
                 ID_ETAPA           
                ,NOM_ETAPA
                ,COSTO
                ,ERROR
                ,ERROR_DESC
            FROM OPERACION.TMP_CARGA_TBL_49CGPPTO2017; 
            
   BEGIN
       dbms_output.put_line  (' 49C SP_CARGA_TEMP_PPTO_INPUTS_49C');
         
        SELECT COUNT(ERROR) TOTAL INTO V_TOTAL_ERROR FROM OPERACION.TMP_CARGA_TBL_49CGPPTO2017 WHERE ERROR = 1 ;
        
        SELECT ID_CARTERA INTO V_ID_CARTERA FROM OPERACION.CAT_CARTERA WHERE IDCARTERAPM = P_CADENA;
       
       IF V_TOTAL_ERROR = 0 THEN 
       
            FOR temporal_rec in c1 LOOP
            
                  V_COSTO:= REPLACE(REPLACE(REPLACE(temporal_rec.COSTO,CHR(10),''),CHR(13),''), '$', '');            
                 -- dbms_output.put_line  ( 'valor costo BD  ->'    || temporal_rec.COSTO || '| valor costo condi  -> ' || V_COSTO );

                 INSERT INTO OPERACION.PPTO_CAT_HONORARIOS_X_AVANCE (ID_CAT_HONORARIOS_X_AVANCE, ID_CAT_CARTERA, ETAPA, NOMBRE_ETAPA, COSTO_PENDULUM) VALUES (OPERACION.PPTO_SEQ_CAT_HONORARIOS.NEXTVAL, V_ID_CARTERA, to_char(temporal_rec.ID_ETAPA), temporal_rec.NOM_ETAPA, V_COSTO);
                     
            END LOOP; 
       ELSE
        
        dbms_output.put_line  (' No Procede insercion: Se encontro numero total de errore : ' || V_TOTAL_ERROR || ', Por favor validar la tabla OPERACION.TMP_CARGA_TBL_49AGPPTO2017' );
        
       END IF; 

   COMMIT; 
  
   END SP_CARGA_TEMP_PPTO_INPUTS_49C;






PROCEDURE SP_CARGA_TEMP_PPTO_INPUTS_44C
     IS  
         V_TOTAL_ERROR NUMBER;
         V_MES NUMBER;
         
         CURSOR c1 IS 
              SELECT                                 
                     ANIO_MES           
                    ,AJUSTADO
                    ,NORMAL
                    ,ANIO
                    ,MES
                    ,ERROR
                    ,ERROR_DESC
              FROM OPERACION.TMP_CARGA_TBL_44CGPPTO2017;
     BEGIN
       dbms_output.put_line  (' 44C SP_CARGA_TEMP_PPTO_INPUTS_44C');
         
        SELECT COUNT(ERROR) TOTAL INTO V_TOTAL_ERROR FROM OPERACION.TMP_CARGA_TBL_44CGPPTO2017 WHERE ERROR = 1 ;
        
       
       IF V_TOTAL_ERROR = 0 THEN 
       
            FOR temporal_rec in c1 LOOP
            
                   V_MES:= REPLACE(REPLACE(temporal_rec.MES,CHR(10),''),CHR(13),'');            
                 -- dbms_output.put_line  ( 'valor costo BD  ->'    || temporal_rec.COSTO || '| valor costo condi  -> ' || V_COSTO );

                  INSERT INTO OPERACION.PPTO_CAT_GASTOS_X_RESOLVER (ID_CAT_GASTOS_X_RESOLVER, ANIO_MES, AJUSTADO, NORMAL, ANIO, MES) VALUES (OPERACION.PPTO_SEQ_GASTOS_X_RESOLVER.NEXTVAL, temporal_rec.ANIO_MES, temporal_rec.AJUSTADO, temporal_rec.NORMAL, temporal_rec.ANIO, V_MES);
                 dbms_output.put_line  (' No Procede insercion: Se encontro numero total de errore : ' || V_TOTAL_ERROR || ', Por favor validar la tabla OPERACION.TMP_CARGA_TBL_44CGPPTO2017' );
                     
                 
            END LOOP; 
       ELSE
        
        dbms_output.put_line  (' No Procede insercion: Se encontro numero total de errore : ' || V_TOTAL_ERROR || ', Por favor validar la tabla OPERACION.TMP_CARGA_TBL_44CGPPTO2017' );
        
       END IF; 

   COMMIT; 
  
   END SP_CARGA_TEMP_PPTO_INPUTS_44C;

        





END PKG_OPERACION_LEO;
/
