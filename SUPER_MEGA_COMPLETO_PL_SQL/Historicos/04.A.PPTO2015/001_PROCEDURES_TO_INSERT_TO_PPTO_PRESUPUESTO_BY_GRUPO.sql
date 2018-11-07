-- Validaciones de datos 
-- RECIBE: ID_CARGA 
BEGIN OPERACION.PKG_OPERACION_LEO.SP_VALIDAR_DATOS_04APPTO2015(10); END;

-- RECIBE COMO ID_PRESUPUESTO, esto permite cargar los periodos de los historicos no existente  
BEGIN OPERACION.PKG_OPERACION_LEO.SP_INSERTHIST_4_A(1); END; -- Tiempo -> 6S

-- RECIBE: ID_PRESUPUESTO, permite realizar la carga historica 
BEGIN OPERACION.PKG_OPERACION_LEO.SP_REPORTE_4_A( 1); END;    -- Tiempo -> Despues -> 5S


