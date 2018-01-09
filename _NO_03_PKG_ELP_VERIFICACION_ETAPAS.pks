CREATE OR REPLACE PACKAGE OPERACION.PKG_ELP_VERIFICACION_ETAPAS
AS
   PROCEDURE SP_INSERTA_VERIFICACION (
      PID_PROC_VERIFICA_IN     NUMBER,
      PTASK_PM                 VARCHAR2,
      PVERIFICACIONES_DOC      OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.VERIFICACION_DOCUMENTO_TAB,
      PID_RESULTADO            NUMBER,
      PID_RAZON_RESULTADO      NUMBER,
      PVERIFICADOR             VARCHAR2,
      PCOMENTARIO              VARCHAR2  );

   PROCEDURE SP_INSERTA_VERIFICACION (
      st_cursor            OUT SYS_REFCURSOR,
      PID_PROC_VERIFICA_IN     NUMBER,
      PTASK_PM                 VARCHAR2,
      PVERIFICACIONES_DOC      OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.VERIFICACION_DOCUMENTO_TAB,
      PID_RESULTADO            NUMBER,
      PID_RAZON_RESULTADO      NUMBER,
      PVERIFICADOR             VARCHAR2,
      PCOMENTARIO              VARCHAR2  );

   PROCEDURE SP_INSERTA_VERIFICACION_FINAL (
      PID_PROC_VERIFICA_IN     NUMBER,
      PTASK_PM                 VARCHAR2,
      PVERIFICACIONES_DOC      OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.VERIFICACION_DOCUMENTO_TAB,
      PID_RESULTADO            NUMBER,
      PID_RAZON_RESULTADO      NUMBER,
      PVERIFICADOR             VARCHAR2,
      PCOMENTARIO              VARCHAR2  );

   PROCEDURE SP_INSERTA_VERIFICACION_FINAL (
      st_cursor            OUT SYS_REFCURSOR,
      PID_PROC_VERIFICA_IN     NUMBER,
      PTASK_PM                 VARCHAR2,
      PVERIFICACIONES_DOC      OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.VERIFICACION_DOCUMENTO_TAB,
      PID_RESULTADO            NUMBER,
      PID_RAZON_RESULTADO      NUMBER,
      PVERIFICADOR             VARCHAR2,
      PCOMENTARIO              VARCHAR2  );

   PROCEDURE SP_GET_INFO_ETAPA_JUICIO (
      st_cursor            OUT SYS_REFCURSOR,
      PID_PROC_VERIFICA_IN  IN NUMBER    );

   PROCEDURE SP_GET_RESULTADOS_VERIFICA (
      st_cursor            OUT SYS_REFCURSOR,
      PID_RESULTADO_DOC_IN  IN NUMBER);

   PROCEDURE SP_GET_RAZONES_RESULTADO (
      st_cursor              OUT SYS_REFCURSOR,
      PID_RESULTADO_ETAPA_IN  IN NUMBER,
      PID_PROC_VERIFICA_IN    IN NUMBER  );

   PROCEDURE SP_GET_ULT_VERIFICACIONES (st_cursor            OUT SYS_REFCURSOR,
                                        PID_PROC_VERIFICA_IN  IN NUMBER);

   PROCEDURE SP_GET_MONTOS (st_cursor            OUT SYS_REFCURSOR,
                            PID_PROC_VERIFICA_IN  IN NUMBER);

   PROCEDURE SP_GET_MENSAJES_CORREO (st_cursor            OUT SYS_REFCURSOR,
                                     PID_PROC_VERIFICA_IN  IN NUMBER);
                                     
   PROCEDURE SP_GET_DETALLE_VERIFICACION ( st_cursor OUT SYS_REFCURSOR,
                                           PID_CASO   IN NUMBER );
 
   PROCEDURE SP_GET_SECUENCIA_TAREA_ETAPAS (st_cursor OUT SYS_REFCURSOR );
   
   PROCEDURE SP_SET_INSERTAR_TAREA_ETAPAS ( PID_CASO              NUMBER,
                                            PID_TAREA             NUMBER,
                                            PID_PROC_VERIFICACION NUMBER,
                                            PID_JUICIO            NUMBER,
                                            NUM_JUICIO            VARCHAR2,
                                            PID_ETAPA             NUMBER,
                                            NUM_ETAPA             VARCHAR2,
                                            NM_ETAPA              VARCHAR2,
                                            CUENTA                VARCHAR2,
                                            PID_ASIGNA            VARCHAR2,
                                            BANDEJA_ASIGNA        VARCHAR2 );       
                                            
   PROCEDURE SP_INSERTA_VERIFICACION (
      st_cursor            OUT SYS_REFCURSOR,
      PID_PROC_VERIFICA_IN     NUMBER,
      PTASK_PM                 VARCHAR2,
      PID_RESULTADO            NUMBER,
      PID_RAZON_RESULTADO      NUMBER,
      PVERIFICADOR             VARCHAR2,
      PCOMENTARIO              VARCHAR2,
      ESFINAL                  VARCHAR2);      
      
      
  PROCEDURE SP_INSERTA_VERIFICACIONQ (
      PID_PROC_VERIFICA_IN     NUMBER,
      PTASK_PM                 VARCHAR2,
      PID_RESULTADO            NUMBER,
      PID_RAZON_RESULTADO      NUMBER,
      PVERIFICADOR             VARCHAR2,
      PCOMENTARIO              VARCHAR2);   
      
  PROCEDURE SP_INSERTA_VERIFICA_DOC (
      PTASK_PM                 VARCHAR2,
      ID_DOCUMENTO_ETAPA       NUMBER,
      ID_RESULTADO_DOCUMENTO   NUMBER,
      PVERIFICADOR             VARCHAR2,
      PCOMENTARIO              VARCHAR2);
      
PROCEDURE SP_INSERTA_VERIFICACION_FINAL (
      PID_PROC_VERIFICA_IN     NUMBER,
      PTASK_PM                 VARCHAR2,
      PID_RESULTADO            NUMBER,
      PID_RAZON_RESULTADO      NUMBER,
      PVERIFICADOR             VARCHAR2,
      PCOMENTARIO              VARCHAR2);
-- END QUASAR                 
         
END PKG_ELP_VERIFICACION_ETAPAS;
/
