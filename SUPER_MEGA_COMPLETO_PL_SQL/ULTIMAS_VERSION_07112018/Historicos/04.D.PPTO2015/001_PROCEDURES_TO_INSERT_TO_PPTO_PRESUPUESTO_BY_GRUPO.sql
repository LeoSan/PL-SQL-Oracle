-- RECIBE : ID_CARGA 
BEGIN OPERACION.PKG_OPERACION_LEO.SP_VALIDAR_DATOS_04DPPTO2015(4); END;

-- RECIBE : ID_PRESUPUESTO, ID_CARGA 
BEGIN OPERACION.PKG_OPERACION_LEO.SP_REPORTE_4_D(1, 110); END;  -- Antes ->Tiempo 3 min    | Despues -> 10S

