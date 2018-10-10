CREATE OR REPLACE PACKAGE BODY PENDUPM.PKG_OPERACION_LEO
AS
/******************************************************************************
      NAME:       PKG_PV_COBRANZA
      REVISIONS:
      Ver           Date                    Author           Description
      ---------  ----------         ---------------  ------------------------------------
      1.0           2018-09-28           Ljcuenca     se crea el paquete para mantener la funcionalidad de la interfaz de cobranza para el sistema de plan de viajes
******************************************************************************/

PROCEDURE SP_REPORTE(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER)

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
                , A.CARTERA
                , A.COLLATERALVALUE
                , A.ESTATUS  
                , B.ETIQUETA
                , B.ID_RECORD 
                FROM OPERACION.PPTO_BASE_CREDITOS A 
                INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                WHERE A.ID_PRESUPUESTO = P_PRESUPUESTO  AND  ROWNUM <  5000
                ORDER BY B.ID_RECORD ASC;
                
                         
        TYPE ARREGLOS_INTERVALOS
        IS RECORD (
        rNUMEROCUENTA     VARCHAR2(100),                   
        rID_PRESUPUESTO   INTEGER,
        rETIQUETA         VARCHAR2(100),         
        rCOLLATERALVALUE  FLOAT,
        rID_RECORD        INTEGER
        );

        TYPE TABINTERVALOS IS TABLE OF ARREGLOS_INTERVALOS INDEX BY BINARY_INTEGER;
        
        psDetalle TABINTERVALOS; 

                

    BEGIN
        DBMS_OUTPUT.PUT_LINE('-->> Iniciando << -- ');
        indexInc := 1;
        
        -- Recorremos el cursor con un bucle for - loop
            for u in intervalos_cur loop
             -- OBTENGO EL VALOR DE COLLATERAL POR CUENTAS 
             
             SELECT COLLATERALVALUE INTO V_COLLATERALVALUE FROM OPERACION.PPTO_BASE_CREDITOS WHERE ID_PRESUPUESTO = P_PRESUPUESTO AND NUMEROCUENTA = u.NUMEROCUENTA;
            
            -- DBMS_OUTPUT.PUT_LINE('-->> SELECT COLLATERALVALUE INTO V_COLLATERALVALUE FROM OPERACION.PPTO_BASE_CREDITOS WHERE ID_PRESUPUESTO = 1 AND NUMEROCUENTA =  ' || u.NUMEROCUENTA || ' ;  << -- ');
            
                -- dbms_output.put_line(u.NUMEROCUENTA||' '||u.CARTERA ||' '||u.COLLATERALVALUE ||' '||u.ID_PRESUPUESTO ||' '||u.ETIQUETA );
                    psDetalle(indexInc).rID_PRESUPUESTO  := u.ID_PRESUPUESTO; 
                    psDetalle(indexInc).rNUMEROCUENTA    := u.NUMEROCUENTA;
                    psDetalle(indexInc).rETIQUETA        := u.ETIQUETA;
                    psDetalle(indexInc).rCOLLATERALVALUE := V_COLLATERALVALUE;
                    psDetalle(indexInc).rID_RECORD       := u.ID_RECORD;
                    

               /* IF (indexInc = 0 ) THEN
                
                    psDetalle(indexInc).rCOLLATERALVALUE := V_COLLATERALVALUE;                    
                    
                ELSE    
                   
                    psDetalle(indexInc).rCOLLATERALVALUE := psDetalle(indexInc - 1).rCOLLATERALVALUE;
                
                END IF;
                */
                indexInc := indexInc + 1;
                
            end loop; 
        -- Fin bucle
        
        DBMS_OUTPUT.PUT_LINE('-->> total << -- ' || psDetalle.count);
        
         -- Recorremos el cursor con un bucle for - loop
            for i in 1.. psDetalle.count loop
               -- IF (i < indexInc ) THEN
                    dbms_output.put_line( psDetalle(i).rID_PRESUPUESTO || ' |  '|| psDetalle(i).rNUMEROCUENTA || ' |  '|| psDetalle(i).rETIQUETA || ' |  '||psDetalle(i).rCOLLATERALVALUE  || ' | ' || psDetalle(i).rID_RECORD );
               -- END IF;
                
            end loop; 
        -- Fin bucle
           

     
     
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
 
        --- OBTIENE  LA FORMA DEL REPORTE CON PIVOT  PASO 2    
        consulta := 'SELECT * FROM  (
                                    SELECT 
                                      A.NUMEROCUENTA
                                    , A.CARTERA
                                    , A.COLLATERALVALUE
                                    , A.ESTATUS  
                                    , B.ETIQUETA 
                                    FROM OPERACION.PPTO_BASE_CREDITOS A 
                                    INNER JOIN OPERACION.PPTO_PERIODO_ANIO_MES B ON B.ID_PRESUPUESTO = A.ID_PRESUPUESTO AND B.ID_RECORD > 1
                                    WHERE A.ID_PRESUPUESTO = 1  
                                    ORDER BY 5 ASC 
                                    )PIV
                                    PIVOT ( MAX(COLLATERALVALUE) FOR ETIQUETA IN (' || V_FECHAS_INTERVALOS || '))';
     
      COMMIT;
    /*FORMA DE LLENAR EL ARREGLO DE SALIDA*/
      
      OPEN psSalida FOR consulta;
                
    /*FORMA DE LLENAR EL ARREGLO DE SALIDA*/
    DBMS_OUTPUT.PUT_LINE('-->> Proceso finalizado << -- ');

    EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SQLERRM;
         OPEN psSalida FOR
                SELECT  1 "ERROR", '*ERROR* '|| v_error "MSG" FROM DUAL ;
            DBMS_OUTPUT.PUT_LINE ('ERROR ENCONTRADO  EXCEPTION (OTHERS) : '|| v_error || consulta );

    END SP_REPORTE;

END PKG_OPERACION_LEO;
/
