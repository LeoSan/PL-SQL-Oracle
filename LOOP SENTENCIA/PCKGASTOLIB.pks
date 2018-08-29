CREATE OR REPLACE PACKAGE PENDUPM.PCKGASTOLIB  IS
  /* HISTORIAL DE CAMBIOS
   * 20160901--> MAMV-->   Visualizacion de nombres para autorizadores de pagos doble en pantalla de autorizaciones
   * 20160902--> MAMV-->   Se agrega relacion para los conceptos en GETALARMAGASTOTIPO para los comentarios de gastos dobles
   * 20161003--> MAMV-->   Se agrega relacion para los conceptos en GETALARMAGASTOTIPO para los comentarios de etapas legales y getAlarmaGasto para autorizdosres de ETAPA02
   * JMM 20161005 - getAlarmaGasto. Se asegura que los valores de select no sean nulos.
   * 20161129-->MAMV-->    Visualizacion de nombres para autorizadores y se agrega relacion por concepto a las autorizaciones para no marcar error de subconsulta.
   * 20170524-->MAMV-->    Se agrega validacion para cubo de gasto para visualizar los CENTROS de COSTOS para importes generales y carteras.
   * 20180828-->LJCUENCA--> se creo el proceso para insertar masivamente los comentarios y las respuestas de los diferentes tipos de autorizadores
   */


 TYPE T_CURSOR IS REF CURSOR;

 CURSOR cuCamposAlerta ( xsAlerta   INTEGER) IS
      SELECT CASE WHEN xsAlerta = 6 THEN 'fcjustificacionumbral, fcusuumbral03,fcusuumbral04,fcusuumbral05, fcresumbral03,fcresumbral04,fcresumbral05'
                  WHEN xsAlerta = 7 THEN 'fcjustificaetapa, fcusuetapa01,fcusuetapa02, fcresetapa01,fcresetapa02'
                  WHEN xsAlerta = 8 THEN 'fcjustificapagodbl, fcusupgodbl01,fcusupgodbl02, fcrespgodbl01,fcrespgodbl02'
                  WHEN xsAlerta = 9 THEN ''||''''||''''||''' , fcusujfeinmed, fcresultjfeinmed'
                  WHEN xsAlerta = 10 THEN 'fcjustificaempresa, fcusuempresa, fcresempresa'
                  WHEN xsAlerta = 34 THEN 'fcjustificaurgente, fcusuurgente, fcresurgente'
                  WHEN xsAlerta = 44 THEN 'fcjustificaexcgasto, fcusuexcgasto01,fcusuexcgasto02, fcresexcgasto01,fcresexcgasto02'
                  WHEN xsAlerta = 45 THEN 'fcjustificetafinal, fcusuetafinal01,fcusuetafinal02, fcresetafinal01,fcresetafinal02'
                  WHEN xsAlerta = 46 THEN 'fcjustificaliq, fcusuliquidado01,fcusuliquidado02, fcresliq01,fcresliq01'
             END
        FROM DUAL;

  --- Obtiene las Alertas del Gastos - empleado  CABECERO
  PROCEDURE getAlarmaGasto (pnGasto          INTEGER,  /* numero de gasto */
                            pnUsuario        INTEGER,  /* Nuero de empleado */
                            salida        IN OUT T_CURSOR);

  --- Obtiene las Alertas del Gastos - empleado
  PROCEDURE getAlarmaGastoTipo (pnGasto          INTEGER,  /* numero de gasto */
                                pnTipo           INTEGER,  /* Nuero de Alerta */
                                pnUsuario        INTEGER,  /* Nuero de empleado */
                                salida        IN OUT T_CURSOR);

  FUNCTION queUsuarioEs (psNumEmpleado INTEGER) RETURN VARCHAR2 ;

  PROCEDURE setAutorizaResultado ( pnGasto          INTEGER,  /* numero de gasto */
                                   pnTipo           INTEGER,  /* Nuero de Alerta */
                                   pcCredito        VARCHAR2, /* NUMERO DECREDITO */
                                   pnConcepto       INTEGER,  /* numero de concepto */
                                   pnUsuario        INTEGER,  /* Nuero de empleado */
                                   psValor          VARCHAR2, /* Valor del Resultado */
                                   psFechaRegistro  VARCHAR2, /* Fecha Registro */
                                   psError   OUT    VARCHAR2);

  PROCEDURE setAutorizaComentario ( pnGasto          INTEGER,  /* numero de gasto */
                                   pnTipo           INTEGER,  /* Nuero de Alerta */
                                   pcCredito        VARCHAR2, /* NUMERO DECREDITO */
                                   pnConcepto       INTEGER,  /* numero de concepto */
                                   pnUsuario        INTEGER,  /* Nuero de empleado */
                                   psValor          VARCHAR2, /* Valor del comentario */
                                   psFechaRegistro  VARCHAR2, /* Fecha Registro */
                                   psError   OUT    VARCHAR2);

 PROCEDURE getCreaPdfAvaluo (salida        IN OUT T_CURSOR);

 PROCEDURE getExcelCuboGasto (salida        IN OUT T_CURSOR);

 PROCEDURE cargaAvaluosenLW;


 --- Carga Masiva de los comentarios del usuario y las respuestas por todos los creditos asocaidos a un gasto
 PROCEDURE set_comentarios_autorizadores (pnGasto          INTEGER,  /* numero de gasto */
                                             pnTipo        INTEGER,  /* Numero de Alerta */
                                             pnUsuario     INTEGER,  /* Numero de empleado */
                                             pnRespuesta   VARCHAR2, /* Respuesta si/no */
                                             pnComentario  VARCHAR2, /* Comentarrio  */
                                             psError        OUT VARCHAR2);

 --- Consulta Por detalle
 PROCEDURE get_detalle_autorizadores ( pnGasto       INTEGER,  /* numero de gasto */
                                       pnTipo        INTEGER,  /* Numero de Alerta */
                                       pnUsuario     INTEGER,  /* Numero de empleado */
                                       pnConcepto    INTEGER,  /* Numero de concepto */
                                       pnCredito     VARCHAR2,  /* Numero de Credito */
                                       salida       IN OUT T_CURSOR);

--- Ajuste por comentario y respuesta
PROCEDURE set_detalle_autorizadores ( pnGasto        INTEGER,  /* numero de gasto */
                                       pnTipo        INTEGER,  /* Numero de Alerta */
                                       pnUsuario     INTEGER,  /* Numero de empleado */
                                       pnConcepto    INTEGER,  /* Numero de Concepto */
                                       pnCredito     VARCHAR2,  /* Numero de Credito */
                                       pnComentario  VARCHAR2,  /* Comentario */
                                       pnRespuesta   VARCHAR2,  /* Respuesta  */
                                       psError        OUT VARCHAR2);



END PCKGASTOLIB;
/

