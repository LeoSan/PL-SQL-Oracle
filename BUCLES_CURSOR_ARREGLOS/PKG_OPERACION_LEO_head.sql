CREATE OR REPLACE PACKAGE PENDUPM.PKG_OPERACION_LEO
AS

/******************************************************************************
      NAME:       PKG_PV_COBRANZA
      REVISIONS:
      Ver           Date                    Author           Description
      ---------  ----------         ---------------  ------------------------------------
      1.0           2018-09-28           Ljcuenca     se crea el paquete para mantener la funcionalidad de la interfaz de cobranza para el sistema de plan de viajes
******************************************************************************/

  -- DECLARACIÓN DE VARIABLES Y VALORES
    TYPE T_CURSOR IS REF CURSOR;
   -- FORMA DE DECLARAR ARREGLO EN ORACLE
    TYPE PLANDEVIAJE
    IS RECORD (
                 rIdGasto         GASTOMAIN.IDGASTO%TYPE,                   -- Id del Plan de Viaje
                 rIdConsecutivo   PLANCOBRANZALEGAL.IDCONSEC%TYPE,          -- Id consecutivo
                 rFdFecVisita     VARCHAR2(30),                             -- FECHA DE VISITA  -  DD/MM/YYYY HH24:MI:SS
                 rIdMotivoVis     PLANCOBRANZALEGAL.IDMOTIVOVISITA%TYPE,    -- Motivos particulares del Viaje
                 rFcActividad     PLANCOBRANZALEGAL.FCACTIVIDAD%TYPE       -- Detalle de la Actividad a Realizar
               );

   TYPE TABPLANVIAJE IS TABLE OF PLANDEVIAJE INDEX BY BINARY_INTEGER;


-- FORMA DE DECLARAR PROCEDURE

   PROCEDURE SP_REPORTE(psSalida IN OUT T_CURSOR, P_PRESUPUESTO IN INTEGER);

   
   /*PROCEDURE SP_EDIT_BITA_CREDITO(psDetallePlan PKG_PV_COBRANZA.TABPLANVIAJE, psSalida IN OUT T_CURSOR, P_CASO IN INTEGER, P_FECHA_INI IN VARCHAR2, P_FECHA_FIN IN VARCHAR2);*/

END PKG_OPERACION_LEO;
/
