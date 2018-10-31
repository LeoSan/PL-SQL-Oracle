CREATE OR REPLACE PACKAGE BODY OPERACION.PKG_PPTO_JAVACLE_UTILS
AS

    FUNCTION FN_PPTO_VALIDA_NUMERO( P_CADENA IN VARCHAR2 ) RETURN NUMBER
    
    IS
        RESPONSE NUMBER;
        NUMERO NUMBER;
        BEGIN
            RESPONSE := 1;
            IF P_CADENA IS NOT NULL THEN
              NUMERO := to_number( P_CADENA );
            ELSE
              RESPONSE := 0;
            END IF;
            
            RETURN RESPONSE;
          
        EXCEPTION
          WHEN value_error
          THEN
             RETURN 0;
             
    END FN_PPTO_VALIDA_NUMERO;
    
    
    FUNCTION FN_PPTO_VALIDA_CADENA( P_CADENA IN VARCHAR2, P_LONGITUD IN NUMBER )  RETURN NUMBER
    IS
        RESPONSE NUMBER;
    BEGIN
        RESPONSE := 1;
        
        IF P_CADENA IS NOT NULL THEN
            IF (LENGTH(P_CADENA) > P_LONGITUD) THEN
                RESPONSE := 0;
            ELSE
                IF(FN_PPTO_VALIDA_NA(P_CADENA) = 0) THEN
                    RESPONSE := 0;  
                END IF;
            END IF;
          
        END IF;
        
        RETURN RESPONSE;
        
    EXCEPTION
          WHEN value_error
          THEN
             RETURN 0;
    END FN_PPTO_VALIDA_CADENA;
    
    FUNCTION FN_PPTO_VALIDA_NA( P_CADENA IN VARCHAR2)  RETURN NUMBER
    IS
        RESPONSE NUMBER;
    BEGIN
        
        RESPONSE := 1;
        
        IF P_CADENA IS NOT NULL THEN
            IF UPPER(P_CADENA) <> 'NA' THEN
                RESPONSE := 0;
            END IF;
        ELSE
          RESPONSE := 0;
        END IF;
        
        RETURN RESPONSE;
        
    EXCEPTION
          WHEN value_error
          THEN
             RETURN 0;
    END FN_PPTO_VALIDA_NA;
    
    
    FUNCTION FN_PPTO_VALIDA_FECHA( P_CADENA IN VARCHAR2, P_MASCARA IN VARCHAR)  RETURN NUMBER
    IS
        RESPONSE NUMBER;
        FECHA DATE;
    BEGIN
        
        RESPONSE := 1;
        
        IF P_CADENA IS NOT NULL THEN
            FECHA := TO_DATE(P_CADENA, P_MASCARA);
        ELSE
          RESPONSE := 0;
        END IF;
        
        RETURN RESPONSE;
        
    EXCEPTION
          WHEN value_error
          THEN
             RETURN 0;
    END FN_PPTO_VALIDA_FECHA;
    
    FUNCTION FN_PPTO_VALIDA_PORCENTAJE( P_CADENA IN VARCHAR2, P_PORCENTAJE IN NUMBER)  RETURN NUMBER
    IS
        RESPONSE NUMBER;
        PORCENTAJE NUMBER;
    BEGIN
        RESPONSE := 1;
        IF P_CADENA IS NOT NULL THEN
             PORCENTAJE := to_number (P_PORCENTAJE) / 100;
        ELSE    
            RESPONSE := 0;
        END IF;
        
        RETURN RESPONSE;
    EXCEPTION
          WHEN value_error
          THEN
             RETURN 0;
    END FN_PPTO_VALIDA_PORCENTAJE;
    
    FUNCTION FN_PPTO_VALIDA_LIMPIAR_CADENA( P_CADENA IN VARCHAR2)  RETURN VARCHAR
    IS
        RESPONSE NUMBER;
        CADENA_LIMPIA VARCHAR2(100);
    BEGIN
        RESPONSE := 1;
        IF P_CADENA IS NOT NULL THEN
             SELECT   REGEXP_REPLACE(P_CADENA, '[^A-Za-z0-9ÁÉÍÓÚáéíóú -]', '') INTO CADENA_LIMPIA
             FROM DUAL;
        ELSE    
            RESPONSE := 0;
        END IF;
        
        RETURN CADENA_LIMPIA;
    EXCEPTION
          WHEN value_error
          THEN
             RETURN 0;
    END FN_PPTO_VALIDA_LIMPIAR_CADENA;
    
END PKG_PPTO_JAVACLE_UTILS;
/
