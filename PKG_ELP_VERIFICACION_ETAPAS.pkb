CREATE OR REPLACE PACKAGE BODY OPERACION.PKG_ELP_VERIFICACION_ETAPAS
AS
   PROCEDURE SP_INSERTA_VERIFICACION (
      PID_PROC_VERIFICA_IN    NUMBER,
      PTASK_PM                VARCHAR2,
      PVERIFICACIONES_DOC     OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.VERIFICACION_DOCUMENTO_TAB,
      PID_RESULTADO           NUMBER,
      PID_RAZON_RESULTADO     NUMBER,
      PVERIFICADOR            VARCHAR2,
      PCOMENTARIO             VARCHAR2)
   IS
      LFECHA_VERIFICACION   DATE;
      LVERIF_DOC            OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.VERIFICACION_DOCUMENTO_REC;
      LVERIFICADOS          NUMBER := 0;
   BEGIN
      LFECHA_VERIFICACION := SYSDATE;

      FOR i IN 1 .. PVERIFICACIONES_DOC.COUNT
      LOOP
         LVERIF_DOC := PVERIFICACIONES_DOC (i);

         IF     LVERIF_DOC.ID_RESULTADO_DOCUMENTO IS NOT NULL
            AND LVERIF_DOC.ID_RESULTADO_DOCUMENTO <> 0
         THEN
            OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.SP_INSERTA_VERIFICACION_DOC (
               PTASK_PM,
               LVERIF_DOC.ID_DOCUMENTO_ETAPA,
               LVERIF_DOC.ID_RESULTADO_DOCUMENTO,
               0,
               PVERIFICADOR,
               LFECHA_VERIFICACION);
            LVERIFICADOS := LVERIFICADOS + 1;
         END IF;
      END LOOP;

      IF LVERIFICADOS = 0
      THEN
         raise_application_error (
            -20002,
            'Es requerido calificar al menos un documento');
      END IF;

      INSERT INTO OPERACION.ELP_VERIFICACION_ETAPA (ID_VERIFICACION_ETAPA,
                                                    ID_PROC_VERIFICACION,
                                                    TASK_PM,
                                                    ID_ETAPA_JUICIO,
                                                    ID_RESULTADO_ETAPA,
                                                    ID_RAZON_RESULTADO,
                                                    FECHA_VERIFICACION,
                                                    VERIFICADOR,
                                                    ES_FINAL,
                                                    COMENTARIO)
         SELECT OPERACION.SEQ_ELP_VERIFICACION_ETAPA.NEXTVAL,
                ID_PROC_VERIFICACION,
                PTASK_PM,
                ID_ETAPA_JUICIO,
                PID_RESULTADO,
                PID_RAZON_RESULTADO,
                LFECHA_VERIFICACION,
                PVERIFICADOR,
                0,
                PCOMENTARIO
           FROM OPERACION.ELP_PROC_VERIFICACION
          WHERE ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN;

      COMMIT;
   END SP_INSERTA_VERIFICACION;

   PROCEDURE SP_INSERTA_VERIFICACION (
      st_cursor              OUT SYS_REFCURSOR,
      PID_PROC_VERIFICA_IN       NUMBER,
      PTASK_PM                   VARCHAR2,
      PVERIFICACIONES_DOC        OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.VERIFICACION_DOCUMENTO_TAB,
      PID_RESULTADO              NUMBER,
      PID_RAZON_RESULTADO        NUMBER,
      PVERIFICADOR               VARCHAR2,
      PCOMENTARIO                VARCHAR2)
   IS
      LCODIGO       NUMBER := 0;
      LMENSAJE      VARCHAR2 (2000) := '';
      LEXISTENTES   NUMBER;
   BEGIN
      BEGIN
         SELECT COUNT (1)
           INTO LEXISTENTES
           FROM OPERACION.ELP_VERIFICACION_ETAPA
          WHERE     ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN
                AND TASK_PM = PTASK_PM;

         IF LEXISTENTES > 0
         THEN
            GOTO CONTINUAR;
         END IF;

         IF PVERIFICADOR IS NULL
         THEN
            LCODIGO := -1;
            LMENSAJE := LMENSAJE || ' EL VERIFICADOR ES REQUERIDO ';
         END IF;

         IF PID_PROC_VERIFICA_IN IS NULL
         THEN
            LCODIGO := -1;
            LMENSAJE :=
                  LMENSAJE
               || ' EL IDENTIFICADOR DEL PROCESO DE VERIFICACION ES REQUERIDO ';
         END IF;

         IF PID_RESULTADO IS NULL
         THEN
            LCODIGO := -1;
            LMENSAJE :=
               LMENSAJE || ' EL RESULTADO DE LA VERIFICACION ES REQUERIDO ';
         END IF;

         IF PVERIFICACIONES_DOC.COUNT = 0
         THEN
            LCODIGO := -1;
            LMENSAJE :=
               LMENSAJE || ' ES REQUERIDO CALIFICAR AL MENOS UN DOCUMENTO ';
         END IF;

         IF LCODIGO = 0
         THEN
            SP_INSERTA_VERIFICACION (PID_PROC_VERIFICA_IN,
                                     PTASK_PM,
                                     PVERIFICACIONES_DOC,
                                     PID_RESULTADO,
                                     PID_RAZON_RESULTADO,
                                     PVERIFICADOR,
                                     PCOMENTARIO);
            LMENSAJE := ' VERIFICACION GUARDADA CORRECTAMENTE';
         END IF;

        <<CONTINUAR>>
         NULL;
      EXCEPTION
         WHEN OTHERS
         THEN
            LCODIGO := -1;
            LMENSAJE := 'Error: ' || SQLERRM;
      END;

      OPEN st_cursor FOR
         SELECT LCODIGO AS CODIGO, LMENSAJE AS MENSAJE FROM DUAL;
   END SP_INSERTA_VERIFICACION;


   PROCEDURE SP_INSERTA_VERIFICACION_FINAL (
      PID_PROC_VERIFICA_IN    NUMBER,
      PTASK_PM                VARCHAR2,
      PVERIFICACIONES_DOC     OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.VERIFICACION_DOCUMENTO_TAB,
      PID_RESULTADO           NUMBER,
      PID_RAZON_RESULTADO     NUMBER,
      PVERIFICADOR            VARCHAR2,
      PCOMENTARIO             VARCHAR2)
   IS
      LVERIF_DOC            OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.VERIFICACION_DOCUMENTO_REC;
      RAZON_RESULTADO       OPERACION.CAT_RAZON_RESULTADO%ROWTYPE;
      LCREDITO              OPERACION.ELP_CREDITO.NUMERO%TYPE;
      LJUICIO               OPERACION.ELP_JUICIO.NUMERO%TYPE;

      LFECHA_VERIFICACION   DATE;

      LID_ETAPA_JUICIO      NUMBER;
      LID_JUICIO            NUMBER;

      LES_CORRECTA          NUMBER;

      LNOMBRE_TABLA         OPERACION.CAT_MONTO.TABLA%TYPE;
      LNOMBRE_CAMPO         OPERACION.CAT_MONTO.CAMPO%TYPE;
      LCAMPO_JUICIO         OPERACION.CAT_MONTO.CAMPO_JUICIO%TYPE;
      LCAMPO_COACREDITADO         VARCHAR2 (500);


      LMONTO                OPERACION.ELP_MONTO_ETAPA_JUICIO.MONTO%TYPE;
      LNUMERO_JUICIO        OPERACION.ELP_JUICIO.NUMERO%TYPE;

      DR_QUERY              VARCHAR2 (2000);
      DR_QUERY_SELECT       VARCHAR2 (2000) := '';

      LFECHA_VERIFICA       DATE;

      LVALOR_PREV           NUMBER;
      LVALOR_POST           NUMBER;
      LNUM_CREDITO    VARCHAR2 (30);

      TYPE cur_typ IS REF CURSOR;

      CUR_MONTO_PREV        cur_typ;

      LVERIFICADOS          NUMBER := 0;

      ---VAR_AUDIT
      EXT_USER              VARCHAR2 (40);
      EXT_HOST              VARCHAR2 (1000);
      EXT_IP_ADDRESS        VARCHAR2 (30);
      EXT_OS_USER           VARCHAR2 (1000);
      EXT_CONCAT_VAL        VARCHAR2 (4000);
      EXT_OBJ               VARCHAR2 (500);
      ---VAR_AUDIT

      LMENSAJE         VARCHAR2 (2000) := '';

      LSOLICITANTE          OPERACION.ELP_PROC_VERIFICACION.SOLICITANTE%TYPE;

      CURSOR CUR_MONTOS_ETAPA (
         PID_PROC_VERIFICA_IN    NUMBER)
      IS
         SELECT CM.TABLA AS TABLA,
                CM.CAMPO AS CAMPO,
                MEJ.MONTO AS MONTO,
                CM.CAMPO_JUICIO AS CAMPO_JUICIO,
                J.NUMERO AS NUMERO_JUICIO,
                J.ID_JUICIO AS ID_JUICIO,
                PV.SOLICITANTE,
                MEJ.COACREDITADO
           FROM OPERACION.ELP_PROC_VERIFICACION PV
                JOIN OPERACION.ELP_MONTO_ETAPA_JUICIO MEJ
                   ON (PV.ID_PROC_VERIFICACION = MEJ.ID_PROC_VERIFICACION)
                JOIN OPERACION.ELP_ETAPA_JUICIO EJ
                   ON (MEJ.ID_ETAPA_JUICIO = EJ.ID_ETAPA_JUICIO)
                JOIN OPERACION.ELP_JUICIO J ON (EJ.ID_JUICIO = J.ID_JUICIO)
                JOIN OPERACION.CAT_MONTO CM ON (MEJ.ID_MONTO = CM.ID_MONTO)
          WHERE PV.ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN;
   BEGIN
      LFECHA_VERIFICACION := SYSDATE;


      SELECT EJ.ID_ETAPA_JUICIO, EJ.ID_JUICIO, PV.FECHA_FIN
        INTO LID_ETAPA_JUICIO, LID_JUICIO, LFECHA_VERIFICA
        FROM OPERACION.ELP_PROC_VERIFICACION PV
             JOIN OPERACION.ELP_ETAPA_JUICIO EJ
                ON (PV.ID_ETAPA_JUICIO = EJ.ID_ETAPA_JUICIO)
       WHERE PV.ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN;

      FOR i IN 1 .. PVERIFICACIONES_DOC.COUNT
      LOOP
         LVERIF_DOC := PVERIFICACIONES_DOC (i);

         IF     LVERIF_DOC.ID_RESULTADO_DOCUMENTO IS NOT NULL
            AND LVERIF_DOC.ID_RESULTADO_DOCUMENTO <> 0
         THEN
            OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.SP_INSERTA_VERIFICACION_DOC (
               PTASK_PM,
               LVERIF_DOC.ID_DOCUMENTO_ETAPA,
               LVERIF_DOC.ID_RESULTADO_DOCUMENTO,
               0,
               PVERIFICADOR,
               LFECHA_VERIFICACION);
            LVERIFICADOS := LVERIFICADOS + 1;
         END IF;
      END LOOP;

--      IF LVERIFICADOS = 0
--      THEN
--         raise_application_error (
--            -20002,
--            'Es requerido calificar al menos un documento');
--      END IF;

      INSERT INTO OPERACION.ELP_VERIFICACION_ETAPA (ID_VERIFICACION_ETAPA,
                                                    ID_PROC_VERIFICACION,
                                                    TASK_PM,
                                                    ID_ETAPA_JUICIO,
                                                    ID_RESULTADO_ETAPA,
                                                    ID_RAZON_RESULTADO,
                                                    FECHA_VERIFICACION,
                                                    VERIFICADOR,
                                                    ES_FINAL,
                                                    COMENTARIO)
           VALUES (OPERACION.SEQ_ELP_VERIFICACION_ETAPA.NEXTVAL,
                   PID_PROC_VERIFICA_IN,
                   PTASK_PM,
                   LID_ETAPA_JUICIO,
                   PID_RESULTADO,
                   PID_RAZON_RESULTADO,
                   LFECHA_VERIFICACION,
                   PVERIFICADOR,
                   1,
                   PCOMENTARIO);


      UPDATE OPERACION.ELP_ETAPA_JUICIO
         SET ID_RESULTADO_ETAPA = PID_RESULTADO,
             ID_RAZON_RESULTADO = PID_RAZON_RESULTADO,
             COMENTARIO = PCOMENTARIO,
             FECHA_VERIFICACION = LFECHA_VERIFICACION,
             EN_PROCESO = 0,
             VERIFICADOR = PVERIFICADOR
       WHERE ID_ETAPA_JUICIO = LID_ETAPA_JUICIO;

      UPDATE OPERACION.ELP_PROC_VERIFICACION
         SET FECHA_FIN = LFECHA_VERIFICACION
       WHERE ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN;

      IF PID_RAZON_RESULTADO IS NOT NULL
      THEN
         SELECT *
           INTO RAZON_RESULTADO
           FROM OPERACION.CAT_RAZON_RESULTADO
          WHERE ID_RAZON_RESULTADO = PID_RAZON_RESULTADO;

         IF     RAZON_RESULTADO.CODIGO_ACCION IS NOT NULL
            AND RAZON_RESULTADO.CODIGO_RESULTADO IS NOT NULL
         THEN
            SELECT C.NUMERO, J.NUMERO
              INTO LCREDITO, LJUICIO
              FROM OPERACION.ELP_ETAPA_JUICIO EJ
                   JOIN OPERACION.ELP_JUICIO J
                      ON (EJ.ID_JUICIO = J.ID_JUICIO)
                   JOIN OPERACION.ELP_CREDITO_JUICIO JC
                      ON (J.ID_JUICIO = JC.ID_JUICIO)
                   JOIN OPERACION.ELP_CREDITO C
                      ON (JC.ID_CREDITO = C.ID_CREDITO)
             WHERE EJ.ID_ETAPA_JUICIO = LID_ETAPA_JUICIO AND ROWNUM = 1;

            OPERACION.PKG_UTILERIAS.SP_INSERTA_ACTIVIDAD (
               SUBSTR (RAZON_RESULTADO.CODIGO_ACCION, 1, 2),
               SUBSTR (RAZON_RESULTADO.CODIGO_RESULTADO, 1, 2),
               PCOMENTARIO,
               LJUICIO,
               PVERIFICADOR,
               LFECHA_VERIFICACION,
               'j',
               333);
         END IF;
      END IF;

      SELECT COUNT (1)
        INTO LES_CORRECTA
        FROM OPERACION.ELP_CONFIGURACION CF
             JOIN
             (SELECT MAX (ID_CONFIGURACION_EL) AS ID_CONFIGURACION_EL
                FROM OPERACION.ELP_CONFIGURACION) CFM
                ON (CF.ID_CONFIGURACION_EL = CFM.ID_CONFIGURACION_EL)
       WHERE CF.ID_RES_ETAPA_CALCULO = PID_RESULTADO;

      IF LES_CORRECTA <> 0
      THEN
         OPEN CUR_MONTOS_ETAPA (PID_PROC_VERIFICA_IN);

         FETCH CUR_MONTOS_ETAPA
            INTO LNOMBRE_TABLA,
                 LNOMBRE_CAMPO,
                 LMONTO,
                 LCAMPO_JUICIO,
                 LNUMERO_JUICIO,
                 LID_JUICIO,
                 LSOLICITANTE,
                 LCAMPO_COACREDITADO;

         WHILE CUR_MONTOS_ETAPA%FOUND
         LOOP
            IF LCAMPO_COACREDITADO IS NULL THEN
                DR_QUERY_SELECT :=
                      'SELECT '
                   || LNOMBRE_CAMPO
                   || ' FROM '
                   || LNOMBRE_TABLA
                   || ' WHERE '
                   || LCAMPO_JUICIO
                   || '= :JUICIO';
                DR_QUERY :=
                      'UPDATE '
                   || LNOMBRE_TABLA
                   || ' SET '
                   || LNOMBRE_CAMPO
                   || '= :MONTO WHERE '
                   || LCAMPO_JUICIO
                   || '= :JUICIO';

                BEGIN
                   OPEN CUR_MONTO_PREV FOR DR_QUERY_SELECT USING LNUMERO_JUICIO;

                   FETCH CUR_MONTO_PREV INTO LVALOR_PREV;

                   IF CUR_MONTO_PREV%FOUND
                   THEN
                      OPERACION.PKG_ELP_HISTORIAL_JUICIO.SP_CAMPO_JUICIO (
                         LNOMBRE_CAMPO,
                         LNUMERO_JUICIO,
                         TO_CHAR (LVALOR_PREV),
                         TO_CHAR (LMONTO),
                         SYSDATE,
                         LSOLICITANTE);
                   END IF;

                   CLOSE CUR_MONTO_PREV;
                EXCEPTION
                   WHEN OTHERS
                   THEN
                      DBMS_OUTPUT.PUT_LINE (SQLERRM);
                END;

                EXECUTE IMMEDIATE DR_QUERY USING LMONTO, LNUMERO_JUICIO;
            ELSE
              BEGIN
                 SELECT NUMERO_CREDITO
                   INTO LNUM_CREDITO
                   FROM OPERACION.VW_ELP_JUICIO_BANDEJA
                  WHERE NUMERO_JUICIO = LNUMERO_JUICIO;
                IF INSTR(LNOMBRE_TABLA,'UDA1') > 0 OR INSTR(LNOMBRE_TABLA,'UDA2') > 0  THEN
                       DR_QUERY :=
                      'UPDATE RCVRY.UDA1'
                       || ' SET '
                       || 'U1'||SUBSTR(LNOMBRE_CAMPO,3)
                       || '= :COACRED WHERE '
                       || 'U1'||SUBSTR(LCAMPO_JUICIO,3)
                       || '= :JUICIO';
                       EXECUTE IMMEDIATE DR_QUERY USING LCAMPO_COACREDITADO, LNUM_CREDITO;
                         DR_QUERY :=
                      'UPDATE RCVRY.UDA2'
                       || ' SET '
                        || 'U2'||SUBSTR(LNOMBRE_CAMPO,3)
                       || '= :COACRED WHERE '
                        || 'U2'||SUBSTR(LCAMPO_JUICIO,3)
                       || '= :JUICIO';
                       EXECUTE IMMEDIATE DR_QUERY USING LCAMPO_COACREDITADO, LNUM_CREDITO;
                ELSE
                       DR_QUERY :=
                      'UPDATE '
                   || LNOMBRE_TABLA
                   || ' SET '
                   || LNOMBRE_CAMPO
                   || '= :MONTO WHERE '
                   || LCAMPO_JUICIO
                   || '= :JUICIO';
                       EXECUTE IMMEDIATE DR_QUERY USING LCAMPO_COACREDITADO, LNUMERO_JUICIO;
                END IF;
              EXCEPTION
                 WHEN OTHERS
                 THEN
                     OPERACION.PKG_ELP_CORTE_JUICIO.SP_LOG_ERROR (LNUMERO_JUICIO,
                       'VERIFIFINAL',
                       'VERIFIFINAL',
                       SYSDATE || '-->' || LNUMERO_JUICIO||'-'||SUBSTR (SQLERRM, 1, 900));
              END;

            END IF;
            FETCH CUR_MONTOS_ETAPA
               INTO LNOMBRE_TABLA,
                    LNOMBRE_CAMPO,
                    LMONTO,
                    LCAMPO_JUICIO,
                    LNUMERO_JUICIO,
                    LID_JUICIO,
                    LSOLICITANTE,
                    LCAMPO_COACREDITADO;
         END LOOP;

         CLOSE CUR_MONTOS_ETAPA;
      END IF;

      /*
          Actualiza campo de etapa reprocesada a borrado
      */

      UPDATE RCVRY.HIST_ETAPA_VALIDAD
         SET ETAPA_BORRADA = 'BORRADA'
       WHERE     (NO_DE_CREDITO,
                  FOLIO,
                  CONSECUTIVO,
                  CARTTIPO) IN (SELECT C.NUMERO,
                                       J.NUMERO,
                                       CE.NUMERO,
                                       CA.DESCRIPCION
                                  FROM OPERACION.ELP_PROC_VERIFICACION EV
                                       JOIN OPERACION.ELP_ETAPA_JUICIO EJ
                                          ON (EV.ID_ETAPA_JUICIO =
                                                 EJ.ID_ETAPA_JUICIO)
                                       JOIN OPERACION.ELP_JUICIO J
                                          ON (EJ.ID_JUICIO = J.ID_JUICIO)
                                       JOIN OPERACION.CAT_ETAPA_LEGAL CE
                                          ON (EJ.ID_ETAPA_LEGAL =
                                                 CE.ID_ETAPA_LEGAL)
                                       JOIN OPERACION.ELP_CREDITO_JUICIO CJ
                                          ON (J.ID_JUICIO = CJ.ID_JUICIO)
                                       JOIN OPERACION.ELP_CREDITO C
                                          ON (CJ.ID_CREDITO = C.ID_CREDITO)
                                       JOIN OPERACION.CAT_CARTERA CA
                                          ON (C.ID_CARTERA = CA.ID_CARTERA)
                                 WHERE EV.ID_PROC_VERIFICACION =
                                          PID_PROC_VERIFICA_IN)
             AND ETAPA_BORRADA IS NULL;

      INSERT INTO RCVRY.HIST_ETAPA_VALIDAD (NO_DE_CREDITO,
                                            FOLIO,
                                            FECHA_INICIO_ETAPA,
                                            FECHA_FIN_ETAPA,
                                            CONSECUTIVO,
                                            ETAPA,
                                            RESULTADO_VERIFICA,
                                            FECHA_DE_VERIFICACION,
                                            USUARIO_CYBER_LEGAL,
                                            CALIFICACION,
                                            FECHA_CARGA,
                                            CARTTIPO)
         SELECT I.CREDITO,
                I.JUICIO,
                I.FECHA_INICIO,
                I.FECHA_TERMINO,
                I.NUMERO,
                I.ETAPA,
                RE.CLAVE,
                LFECHA_VERIFICACION,
                PVERIFICADOR,
                RR.DESCRIPCION,
                SYSDATE,
                I.CARTERA
           FROM (SELECT C.NUMERO AS CREDITO,
                        J.NUMERO AS JUICIO,
                        EJ.FECHA_INICIO,
                        EJ.FECHA_TERMINO,
                        CE.NUMERO,
                        CE.NOMBRE AS ETAPA,
                        CA.DESCRIPCION AS CARTERA
                   FROM OPERACION.ELP_PROC_VERIFICACION EV
                        JOIN OPERACION.ELP_ETAPA_JUICIO EJ
                           ON (EV.ID_ETAPA_JUICIO = EJ.ID_ETAPA_JUICIO)
                        JOIN OPERACION.ELP_JUICIO J
                           ON (EJ.ID_JUICIO = J.ID_JUICIO)
                        JOIN OPERACION.CAT_ETAPA_LEGAL CE
                           ON (EJ.ID_ETAPA_LEGAL = CE.ID_ETAPA_LEGAL)
                        JOIN OPERACION.ELP_CREDITO_JUICIO CJ
                           ON (J.ID_JUICIO = CJ.ID_JUICIO)
                        JOIN OPERACION.ELP_CREDITO C
                           ON (CJ.ID_CREDITO = C.ID_CREDITO)
                        JOIN OPERACION.CAT_CARTERA CA
                           ON (C.ID_CARTERA = CA.ID_CARTERA)
                  WHERE EV.ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN) I,
                OPERACION.CAT_RESULTADO_ETAPA RE,
                OPERACION.CAT_RAZON_RESULTADO RR
          WHERE     RE.ID_RESULTADO_ETAPA = PID_RESULTADO
                AND RR.ID_RAZON_RESULTADO = PID_RAZON_RESULTADO;


      OPERACION.PKG_ELP_GENERACION_CALCULOS.SP_ACTUALIZA_METRICAS (
         LID_JUICIO);


      COMMIT;
     EXCEPTION
         WHEN OTHERS
         THEN
             LMENSAJE := 'Error: ' || SQLERRM;

              EXT_CONCAT_VAL :=
               'PID_PROC_VERIFICA_IN^^'
            || PID_PROC_VERIFICA_IN
            || '^PTASK_PM^^'
            || PTASK_PM
            || '^PID_RESULTADO^^'
            || PID_RESULTADO
            || '^PID_RAZON_RESULTADO^^'
            || PID_RAZON_RESULTADO
            || '^PVERIFICADOR^^'
            || PVERIFICADOR
            || '^PCOMENTARIO^^'
            || PCOMENTARIO
            || '^LMENSAJE2^^'
            || LMENSAJE;
         EXT_OBJ :=
            'OPERACION.PKG_ELP_VERIFICACION_ETAPAS.SP_INSERTA_VERIFICACION_FINAL2';
         DBA_MONITOREO.PA_INSERTA_AUDIT_PROCESOS (EXT_USER,
                                                  EXT_HOST,
                                                  EXT_IP_ADDRESS,
                                                  EXT_OS_USER,
                                                  EXT_OBJ,
                                                  EXT_CONCAT_VAL);
     -- END;
      /*###########################################
RUTINA DE AUDITORIA ESPECIFICA DEL PROCEDIMIENTO EN CURSO
POR DBA_OCB
        INICIO
      BEGIN
         SELECT SYS_CONTEXT ('USERENV', 'SESSION_USER')
           INTO EXT_USER
           FROM DUAL;

         SELECT SYS_CONTEXT ('USERENV', 'HOST') INTO EXT_HOST FROM DUAL;

         SELECT SYS_CONTEXT ('USERENV', 'IP_ADDRESS')
           INTO EXT_IP_ADDRESS
           FROM DUAL;

         SELECT SYS_CONTEXT ('USERENV', 'OS_USER') INTO EXT_OS_USER FROM DUAL;

         EXT_CONCAT_VAL :=
               'PID_PROC_VERIFICA_IN^^'
            || PID_PROC_VERIFICA_IN
            || '^PTASK_PM^^'
            || PTASK_PM
            || '^PID_RESULTADO^^'
            || PID_RESULTADO
            || '^PID_RAZON_RESULTADO^^'
            || PID_RAZON_RESULTADO
            || '^PVERIFICADOR^^'
            || PVERIFICADOR
            || '^PCOMENTARIO^^'
            || PCOMENTARIO
            || '^LMENSAJE^^'
            || LMENSAJE;
         EXT_OBJ :=
            'OPERACION.PKG_ELP_VERIFICACION_ETAPAS.SP_INSERTA_VERIFICACION_FINAL';
         DBA_MONITOREO.PA_INSERTA_AUDIT_PROCESOS (EXT_USER,
                                                  EXT_HOST,
                                                  EXT_IP_ADDRESS,
                                                  EXT_OS_USER,
                                                  EXT_OBJ,
                                                  EXT_CONCAT_VAL);
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;
   /*###########################################
   RUTINA DE AUDITORIA ESPECIFICA DEL PROCEDIMIENTO EN CURSO
   POR DBA_OCB
           FIN
   ###########################################*/

   END SP_INSERTA_VERIFICACION_FINAL;

   PROCEDURE SP_INSERTA_VERIFICACION_FINAL (
      st_cursor              OUT SYS_REFCURSOR,
      PID_PROC_VERIFICA_IN       NUMBER,
      PTASK_PM                   VARCHAR2,
      PVERIFICACIONES_DOC        OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.VERIFICACION_DOCUMENTO_TAB,
      PID_RESULTADO              NUMBER,
      PID_RAZON_RESULTADO        NUMBER,
      PVERIFICADOR               VARCHAR2,
      PCOMENTARIO                VARCHAR2)
   IS
      LCODIGO          NUMBER := 0;
      LMENSAJE         VARCHAR2 (2000) := '';
      LEXISTENTES      NUMBER;
      ---VAR_AUDIT
      EXT_USER         VARCHAR2 (40);
      EXT_HOST         VARCHAR2 (1000);
      EXT_IP_ADDRESS   VARCHAR2 (30);
      EXT_OS_USER      VARCHAR2 (1000);
      EXT_CONCAT_VAL   VARCHAR2 (4000);
      EXT_OBJ          VARCHAR2 (500);
   ---VAR_AUDIT

   BEGIN
      BEGIN
         SELECT COUNT (1)
           INTO LEXISTENTES
           FROM OPERACION.ELP_PROC_VERIFICACION PV
                JOIN OPERACION.ELP_VERIFICACION_ETAPA VE
                   ON (PV.ID_PROC_VERIFICACION = VE.ID_PROC_VERIFICACION)
          WHERE     PV.ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN
                AND (PV.FECHA_FIN IS NOT NULL OR VE.TASK_PM = PTASK_PM);

         IF LEXISTENTES > 0
         THEN
            LCODIGO := -1;
            LMENSAJE :=
                  LMENSAJE
               || 'LA TAREA YA HA SIDO COMPLETADA PREVIAMENTE PARA EL PROCESO DE VERIFICACION ';
            GOTO CONTINUAR;
         END IF;

         IF PVERIFICADOR IS NULL
         THEN
            LCODIGO := -1;
            LMENSAJE := LMENSAJE || 'EL VERIFICADOR ES REQUERIDO ';
         END IF;

         IF PID_PROC_VERIFICA_IN IS NULL
         THEN
            LCODIGO := -1;
            LMENSAJE :=
                  LMENSAJE
               || 'EL IDENTIFICADOR DEL PROCESO DE VERIFICACION ES REQUERIDO ';
         END IF;

         IF PID_RESULTADO IS NULL
         THEN
            LCODIGO := -1;
            LMENSAJE :=
               LMENSAJE || 'EL RESULTADO DE LA VERIFICACION ES REQUERIDO ';
         END IF;

         IF PVERIFICACIONES_DOC.COUNT = 0
         THEN
            LCODIGO := -1;
            LMENSAJE :=
               LMENSAJE || 'ES REQUERIDO CALIFICAR AL MENOS UN DOCUMENTO ';
         END IF;

         IF LCODIGO = 0
         THEN
            SP_INSERTA_VERIFICACION_FINAL (PID_PROC_VERIFICA_IN,
                                           PTASK_PM,
                                           PVERIFICACIONES_DOC,
                                           PID_RESULTADO,
                                           PID_RAZON_RESULTADO,
                                           PVERIFICADOR,
                                           PCOMENTARIO);
            LMENSAJE := 'VERIFICACION GUARDADA CORRECTAMENTE';
         END IF;

        <<CONTINUAR>>
         NULL;
      EXCEPTION
         WHEN OTHERS
         THEN
            LCODIGO := -1;
            LMENSAJE := 'Error: ' || SQLERRM;
      END;

      OPEN st_cursor FOR
         SELECT LCODIGO AS CODIGO, LMENSAJE AS MENSAJE FROM DUAL;

      /*###########################################
   RUTINA DE AUDITORIA ESPECIFICA DEL PROCEDIMIENTO EN CURSO
   POR DBA_OCB
           INICIO
   ###########################################*/

      BEGIN
         SELECT SYS_CONTEXT ('USERENV', 'SESSION_USER')
           INTO EXT_USER
           FROM DUAL;

         SELECT SYS_CONTEXT ('USERENV', 'HOST') INTO EXT_HOST FROM DUAL;

         SELECT SYS_CONTEXT ('USERENV', 'IP_ADDRESS')
           INTO EXT_IP_ADDRESS
           FROM DUAL;

         SELECT SYS_CONTEXT ('USERENV', 'OS_USER') INTO EXT_OS_USER FROM DUAL;

         EXT_CONCAT_VAL :=
               'PID_PROC_VERIFICA_IN^^'
            || PID_PROC_VERIFICA_IN
            || '^PTASK_PM^^'
            || PTASK_PM
            || '^PID_RESULTADO^^'
            || PID_RESULTADO
            || '^PID_RAZON_RESULTADO^^'
            || PID_RAZON_RESULTADO
            || '^PVERIFICADOR^^'
            || PVERIFICADOR
            || '^PCOMENTARIO^^'
            || PCOMENTARIO
            || '^LMENSAJE^^'
            || LMENSAJE;
         EXT_OBJ :=
            'OPERACION.PKG_ELP_VERIFICACION_ETAPAS.SP_INSERTA_VERIFICACION_FINAL';
         DBA_MONITOREO.PA_INSERTA_AUDIT_PROCESOS (EXT_USER,
                                                  EXT_HOST,
                                                  EXT_IP_ADDRESS,
                                                  EXT_OS_USER,
                                                  EXT_OBJ,
                                                  EXT_CONCAT_VAL);
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;
   /*###########################################
   RUTINA DE AUDITORIA ESPECIFICA DEL PROCEDIMIENTO EN CURSO
   POR DBA_OCB
           FIN
   ###########################################*/

   END SP_INSERTA_VERIFICACION_FINAL;

   PROCEDURE SP_GET_INFO_ETAPA_JUICIO (st_cursor                 OUT SYS_REFCURSOR,
                                       PID_PROC_VERIFICA_IN   IN     NUMBER)
   IS
   BEGIN
      OPEN st_cursor FOR
         SELECT EJ.ID_ETAPA_JUICIO AS idEtapaJuicio,
                VM.TASK_PM as taskPm,
                EJ.ACTIVO as activo,
                J.NUMERO AS numeroJuicio,
                EL.NUMERO AS numeroEtapa,
                EJ.FECHA_INICIO as fechaInicio,
                EJ.FECHA_TERMINO as fechaTermino,
                EL.NOMBRE AS nombreEtapa,
                C.NUMERO AS cuenta,
                CA.CLAVE AS claveCartera,
                CA.DESCRIPCION AS nombreCartera,
                CA.ceextlwyr AS abogadoExterno,
                CLE.CLMAIL AS correoExterno,
                CLE.CLNAME AS nombreExterno,
                CA.CERESPLWYR AS abogadoInterno,
                CA.CENAME AS demandado,
                CA.CEDOSSIERID AS expediente,
                JU.DESCRIPCION AS juzgado,
                CLI.CLMAIL AS correoInterno,
                CLI.CLNAME AS nombreInterno,
                (CASE
                    WHEN     EJ.ID_RESULTADO_ETAPA IS NOT NULL
                         AND CFG.ID_CONFIGURACION_EL IS NOT NULL
                    THEN
                       CLS.CLMAIL
                    ELSE
                       NULL
                 END)
                   AS correoSupervisor,
                CLSS.CLMAIL AS correoSolicitante,
                (CASE
                    WHEN     EJ.ID_RESULTADO_ETAPA IS NOT NULL
                         AND CFG.ID_CONFIGURACION_EL IS NOT NULL
                    THEN
                       1
                    WHEN     EJ.ID_RESULTADO_ETAPA IS NOT NULL
                         AND CFG.ID_CONFIGURACION_EL IS NULL
                    THEN
                       0
                    ELSE
                       NULL
                 END)
                   AS esCorrecta,
                (CASE
                    WHEN     EJ.ID_RESULTADO_ETAPA IS NOT NULL
                         AND CFG.ID_CONFIGURACION_EL IS NOT NULL
                    THEN
                       'En caso de ser etapa de pago, estara disponible para su facturacion en el SGP 2 meses'
                    WHEN     EJ.ID_RESULTADO_ETAPA IS NOT NULL
                         AND CFG.ID_CONFIGURACION_EL IS NULL
                    THEN
                       'Realizar la(s) correcion(es)  respectivas a la etapa para su reproceso'
                    ELSE
                       NULL
                 END)
                   AS mensajeResultado
           FROM OPERACION.ELP_PROC_VERIFICACION PV
                JOIN OPERACION.ELP_ETAPA_JUICIO EJ
                   ON (PV.ID_ETAPA_JUICIO = EJ.ID_ETAPA_JUICIO)
                JOIN OPERACION.CAT_ETAPA_LEGAL EL
                   ON (EJ.ID_ETAPA_LEGAL = EL.ID_ETAPA_LEGAL)
                JOIN OPERACION.ELP_JUICIO J ON (EJ.ID_JUICIO = J.ID_JUICIO)
                LEFT JOIN OPERACION.ELP_CREDITO_JUICIO CJ
                   ON (J.ID_JUICIO = CJ.ID_JUICIO)
                LEFT JOIN OPERACION.ELP_CREDITO C
                   ON (C.ID_CREDITO = CJ.ID_CREDITO)
                LEFT JOIN OPERACION.CAT_CARTERA CA
                   ON (CA.ID_CARTERA = C.ID_CARTERA)
                LEFT JOIN OPERACION.CAT_JUZGADO JU
                   ON (J.ID_JUZGADO = JU.ID_JUZGADO)
                LEFT JOIN RCVRY.CASE CA ON (J.NUMERO = CA.CECASENO)
                LEFT JOIN RCVRY.COLLID CLI ON (CA.CERESPLWYR = CLI.CLCOLLID)
                LEFT JOIN RCVRY.COLLID CLE ON (CA.ceextlwyr = CLE.CLCOLLID)
                LEFT JOIN RCVRY.COLLID CLS ON (CA.CESUPVLWYR = CLS.CLCOLLID)
                LEFT JOIN RCVRY.COLLID CLSS
                   ON (CLSS.clcollid = PV.SOLICITANTE)
                LEFT JOIN
                (SELECT CF.*
                   FROM OPERACION.ELP_CONFIGURACION CF
                        JOIN
                        (SELECT MAX (ID_CONFIGURACION_EL)
                                   AS ID_CONFIGURACION_EL
                           FROM OPERACION.ELP_CONFIGURACION) CFM
                           ON (CF.ID_CONFIGURACION_EL =
                                  CFM.ID_CONFIGURACION_EL)) CFG
                   ON (EJ.ID_RESULTADO_ETAPA = CFG.ID_RES_ETAPA_CALCULO)
                LEFT JOIN (SELECT VE.*
                             FROM OPERACION.ELP_VERIFICACION_ETAPA VE
                                  JOIN
                                  (  SELECT MAX (ID_VERIFICACION_ETAPA)
                                               AS ID_VERIFICACION_ETAPA
                                       FROM OPERACION.ELP_VERIFICACION_ETAPA
                                      WHERE ID_PROC_VERIFICACION IS NOT NULL
                                   GROUP BY ID_PROC_VERIFICACION) VEM
                                     ON (VE.ID_VERIFICACION_ETAPA =
                                            VEM.ID_VERIFICACION_ETAPA)) VM
                   ON (VM.ID_PROC_VERIFICACION = PV.ID_PROC_VERIFICACION)
          WHERE PV.ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN;
   END SP_GET_INFO_ETAPA_JUICIO;

   PROCEDURE SP_GET_RESULTADOS_VERIFICA (
      st_cursor                 OUT SYS_REFCURSOR,
      PID_RESULTADO_DOC_IN   IN     NUMBER)
   IS
   BEGIN
      OPEN st_cursor FOR
         SELECT ID_RESULTADO_ETAPA ID, CLAVE, DESCRIPCION
           FROM OPERACION.CAT_RESULTADO_ETAPA RE,
                (SELECT ID_RES_ETAPA_CALCULO, ID_RES_DOC_CALCULO
                   FROM operacion.elp_configuracion c
                        JOIN
                        (SELECT MAX (ID_CONFIGURACION_EL)
                                   AS ID_CONFIGURACION_EL
                           FROM operacion.elp_configuracion) maxc
                           ON (c.ID_CONFIGURACION_EL =
                                  maxc.ID_CONFIGURACION_EL)) CONF
          WHERE     ACTIVO = 1
                AND (   (conf.ID_RES_DOC_CALCULO = PID_RESULTADO_DOC_IN /* and  conf.ID_RES_ETAPA_CALCULO=RE.ID_RESULTADO_ETAPA */
                                                                       )
                     OR (    conf.ID_RES_DOC_CALCULO <> PID_RESULTADO_DOC_IN
                         AND conf.ID_RES_ETAPA_CALCULO <>
                                RE.ID_RESULTADO_ETAPA));
   END SP_GET_RESULTADOS_VERIFICA;

   PROCEDURE SP_GET_RAZONES_RESULTADO (
      st_cursor                   OUT SYS_REFCURSOR,
      PID_RESULTADO_ETAPA_IN   IN     NUMBER,
      PID_PROC_VERIFICA_IN     IN     NUMBER)
   IS
   BEGIN
      OPEN st_cursor FOR
         SELECT ID_RAZON_RESULTADO ID, DESCRIPCION, DESCRIPCION_CODIGO CLAVE
           FROM OPERACION.CAT_RAZON_RESULTADO rr,
                (SELECT NVL (CANTIDAD, 0) CANTIDAD
                   FROM OPERACION.ELP_PROC_VERIFICACION pv
                        JOIN operacion.elp_etapa_juicio ej
                           ON (pv.id_etapa_juicio = ej.id_etapa_juicio)
                        LEFT JOIN
                        (  SELECT COUNT (1) AS CANTIDAD, ID_ETAPA_LEGAL
                             FROM OPERACION.CAT_ETAPA_MONTO
                         GROUP BY ID_ETAPA_LEGAL) EM
                           ON (EM.ID_ETAPA_LEGAL = ej.ID_ETAPA_LEGAL)
                  WHERE pv.ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN) mc
          WHERE     ACTIVO = 1
                AND ID_RESULTADO_ETAPA = PID_RESULTADO_ETAPA_IN
                AND (mc.cantidad > 0 OR (mc.cantidad = 0 AND RAZON_MONTO = 0));
   END SP_GET_RAZONES_RESULTADO;

   PROCEDURE SP_GET_ULT_VERIFICACIONES (st_cursor                 OUT SYS_REFCURSOR,
                                        PID_PROC_VERIFICA_IN   IN     NUMBER)
   IS
   BEGIN
      OPEN st_cursor FOR
           SELECT *
             FROM OPERACION.ELP_VERIFICACION_ETAPA
            WHERE ES_FINAL = 0 AND ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN
         ORDER BY ID_VERIFICACION_ETAPA DESC;
   END SP_GET_ULT_VERIFICACIONES;

   PROCEDURE SP_GET_MONTOS (st_cursor                 OUT SYS_REFCURSOR,
                            PID_PROC_VERIFICA_IN   IN     NUMBER)
   IS
   BEGIN
      OPEN st_cursor FOR
         SELECT CM.ETIQUETA AS ETIQUETA,
                OPERACION.PKG_UTILERIAS_TEXTO.FORMATO_NUMERO (MEJ.MONTO)
                   AS MONTO
           FROM OPERACION.ELP_MONTO_ETAPA_JUICIO MEJ
                JOIN OPERACION.CAT_MONTO CM ON (MEJ.ID_MONTO = CM.ID_MONTO)
          WHERE MEJ.ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN;
   END SP_GET_MONTOS;

   PROCEDURE SP_GET_MENSAJES_CORREO (st_cursor                 OUT SYS_REFCURSOR,
                                     PID_PROC_VERIFICA_IN   IN     NUMBER)
   IS
   BEGIN
      OPEN st_cursor FOR
         SELECT '' AS TEXTO_MENSAJE
           FROM DUAL
          WHERE 1 <> 1;
   END SP_GET_MENSAJES_CORREO;
   

   -- BEGIN: Metodo consumido en QUASAR de MEsa de Control
   
   
   PROCEDURE SP_GET_DETALLE_VERIFICACION ( st_cursor OUT SYS_REFCURSOR,
                                           PID_CASO   IN  NUMBER )
   IS                                        
   BEGIN
      OPEN st_cursor FOR
         SELECT
                 TAREAS.ID_ASIGNA,
                 verificador1.CLNAME nameVerificador1,
                 resultadoEtapa1.DESCRIPCION resultadoVerificador1,
                 razonResultado1.DESCRIPCION razonVerificador1,
                 tareas.COMENTARIO_VER01 comentarioVerificador1,
                 tareas.FECHA_VERIFICADOR01 fechaInicioVerificador1,
                 tareas.FECHA_FIN_VERIFICADOR01 fechaFinVerificador1,
                 TAREAS.ID_VERIFICADOR01,
                 verificador2.CLNAME nameVerificador2,
                 resultadoEtapa2.DESCRIPCION resultadoVerificador2,
                 razonResultado2.DESCRIPCION razonVerificador2,
                 tareas.COMENTARIO_VER02 comentarioVerificador2,
                 tareas.FECHA_VERIFICADOR02 fechaInicioVerificador2,
                 tareas.FECHA_FIN_VERIFICADOR02 fechaFinVerificador2,
                 TAREAS.ID_VERIFICADOR02,
                 supervisor.CLNAME supervisor,
                 resultadoEtapaSup.DESCRIPCION resultadoSupervisor,
                 razonResultadoSup.DESCRIPCION razonSupervisor,
                 tareas.COMENTARIO_DICTAMEN comentarioSupervisor,
                 TAREAS.FECHA_DICTAMEN fechaInicioSupervisor,
                 TAREAS.FECHA_FIN_DICTAMEN fechaFinSupervisor,
                 TAREAS.ID_VERIFICADOR_DICTAMEN
           FROM
                 OPERACION.VMC_ETAPAS_TAREAS tareas
      LEFT JOIN  OPERACION.CAT_RAZON_RESULTADO razonResultado1 
             ON  ( tareas.RAZON_ETAPA_VER01 = razonResultado1.ID_RAZON_RESULTADO      ) 
      LEFT JOIN  OPERACION.CAT_RAZON_RESULTADO razonResultado2 
             ON  ( tareas.RAZON_ETAPA_VER02 = razonResultado2.ID_RAZON_RESULTADO      ) 
      LEFT JOIN  OPERACION.CAT_RAZON_RESULTADO razonResultadoSup 
             ON  ( tareas.RAZON_ETAPA_DICTAMEN = razonResultadoSup.ID_RAZON_RESULTADO ) 
      LEFT JOIN  OPERACION.CAT_RESULTADO_ETAPA resultadoEtapa1 
             ON  ( tareas.RESULTADO_ETAPA_VER01 = resultadoEtapa1.ID_RESULTADO_ETAPA  ) 
      LEFT JOIN  OPERACION.CAT_RESULTADO_ETAPA resultadoEtapa2 
             ON  ( tareas.RESULTADO_ETAPA_VER02 = resultadoEtapa2.ID_RESULTADO_ETAPA  ) 
      LEFT JOIN  OPERACION.CAT_RESULTADO_ETAPA resultadoEtapaSup 
             ON  ( TAREAS.RESULTADO_ETAPA_DICTAMEN = resultadoEtapaSup.ID_RESULTADO_ETAPA ) 
     LEFT JOIN  RCVRY.COLLID verificador1 
             ON  ( verificador1.CLCOLLID = tareas.ID_VERIFICADOR01                        ) 
     LEFT JOIN  RCVRY.COLLID verificador2 
             ON  ( verificador2.CLCOLLID = tareas.ID_VERIFICADOR02                        ) 
     LEFT JOIN  RCVRY.COLLID supervisor 
             ON  ( supervisor.CLCOLLID = tareas.ID_VERIFICADOR_DICTAMEN                   )
          WHERE  ID_CASO = PID_CASO;

   END SP_GET_DETALLE_VERIFICACION;
   
   
   PROCEDURE SP_GET_SECUENCIA_TAREA_ETAPAS (st_cursor OUT SYS_REFCURSOR )
   IS
   BEGIN
      OPEN st_cursor FOR
         SELECT OPERACION.SEQ_NUMERO_CASO.NEXTVAL FROM DUAL;
   
   
   END SP_GET_SECUENCIA_TAREA_ETAPAS;
   
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
                                            BANDEJA_ASIGNA        VARCHAR2 )
   IS
   --TPO_USER VARCHAR2 (30) := 'GRUPO';
   BEGIN
   /*
      IF BANDEJA IS NOT NULL AND BANDEJA != '' AND BANDEJA != '0'  THEN
         TPO_USER := BANDEJA;
      END IF;
   */
      INSERT INTO OPERACION.VMC_ETAPAS_TAREAS (
          ID_CASO,       ID_TAREA,              FECHA_REGISTRO, 
          ORIGEN,        ID_PROC_VERIFICACION,  JUICIO, 
          ID_JUICIO,     ID_ETAPA,              ETAPA, 
          NOMBRE_ETAPA,  CREDITO,               ID_ASIGNA, 
          BANDEJA) 
      VALUES ( PID_CASO,   PID_TAREA,             SYSDATE,
               'QUASAR',   PID_PROC_VERIFICACION, NUM_JUICIO,
               PID_JUICIO, PID_ETAPA,             NUM_ETAPA,
               NM_ETAPA,   CUENTA,                PID_ASIGNA, 
               BANDEJA_ASIGNA );
      COMMIT;
   
   END SP_SET_INSERTAR_TAREA_ETAPAS;
   
   
   -- BEGIN: SP_INSERTA_VERIFICACION Metodo consumido en QUASAR
   PROCEDURE SP_INSERTA_VERIFICACION (
      st_cursor                  OUT SYS_REFCURSOR,
      PID_PROC_VERIFICA_IN       NUMBER,
      PTASK_PM                   VARCHAR2,
      PID_RESULTADO              NUMBER,
      PID_RAZON_RESULTADO        NUMBER,
      PVERIFICADOR               VARCHAR2,
      PCOMENTARIO                VARCHAR2,
      ESFINAL                   VARCHAR2)
   IS
      LCODIGO             NUMBER := 0;
      LMENSAJE            VARCHAR2 (2000) := '';
      LEXISTENTES         NUMBER;
      BNDFINAL            NUMBER;
   BEGIN
      BEGIN
      
         IF ESFINAL = 'S' THEN 
           BNDFINAL := 1; 
         ELSE 
           BNDFINAL := 0;
         END IF;
        
         SELECT COUNT (1)
           INTO LEXISTENTES
           FROM OPERACION.ELP_VERIFICACION_ETAPA
          WHERE     ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN
                AND TASK_PM = PTASK_PM AND VERIFICADOR = PVERIFICADOR AND ES_FINAL = BNDFINAL;

         IF LEXISTENTES > 0
         THEN
            GOTO CONTINUAR;
         END IF;

         IF PVERIFICADOR IS NULL
         THEN
            LCODIGO := -1;
            LMENSAJE := LMENSAJE || ' EL VERIFICADOR ES REQUERIDO ';
         END IF;

         IF PID_PROC_VERIFICA_IN IS NULL
         THEN
            LCODIGO := -1;
            LMENSAJE :=
                  LMENSAJE
               || ' EL IDENTIFICADOR DEL PROCESO DE VERIFICACION ES REQUERIDO ';
         END IF;

         IF PID_RESULTADO IS NULL
         THEN
            LCODIGO := -1;
            LMENSAJE :=
               LMENSAJE || ' EL RESULTADO DE LA VERIFICACION ES REQUERIDO ';
         END IF;

--         IF ID_DOCUMENTO_ETAPA IS NULL
  --       THEN
 --           LCODIGO := -1;
 --           LMENSAJE :=
  --             LMENSAJE || ' ES REQUERIDO CALIFICAR AL MENOS UN DOCUMENTO ';
  --       END IF;

         IF LCODIGO = 0 AND ( ESFINAL = 'N' OR BNDFINAL = 0 ) 
         THEN
            SP_INSERTA_VERIFICACIONQ ( PID_PROC_VERIFICA_IN,
                                       PTASK_PM            ,
                                       PID_RESULTADO       ,
                                       PID_RAZON_RESULTADO ,
                                       PVERIFICADOR        ,
                                       PCOMENTARIO          );
            LMENSAJE := ' VERIFICACION GUARDADA CORRECTAMENTE';
         ELSE
         
            SP_INSERTA_VERIFICACION_FINAL (
                                       PID_PROC_VERIFICA_IN,
                                       PTASK_PM            ,
                                       PID_RESULTADO       ,
                                       PID_RAZON_RESULTADO ,
                                       PVERIFICADOR        ,
                                       PCOMENTARIO          );
            LMENSAJE := ' VERIFICACION FINAL GUARDADA CORRECTAMENTE';
         
         END IF;

        <<CONTINUAR>>
         NULL;
      EXCEPTION
         WHEN OTHERS
         THEN
            LCODIGO := -1;
            LMENSAJE := 'Error: ' || SQLERRM;
      END;

      OPEN st_cursor FOR
         SELECT LCODIGO AS CODIGO, LMENSAJE AS MENSAJE FROM DUAL;
   END SP_INSERTA_VERIFICACION;
-- END: Metodo consumido en QUASAR
   
-- BEGIN: SP_INSERTA_VERIFICACION  Metodo consumido en QUASAR
   PROCEDURE SP_INSERTA_VERIFICACIONQ (
      PID_PROC_VERIFICA_IN    NUMBER,
      PTASK_PM                VARCHAR2,
      PID_RESULTADO           NUMBER,
      PID_RAZON_RESULTADO     NUMBER,
      PVERIFICADOR            VARCHAR2,
      PCOMENTARIO             VARCHAR2)
   IS
      LFECHA_VERIFICACION   DATE;
      LVERIFICADOS          NUMBER := 0;
   BEGIN
      LFECHA_VERIFICACION := SYSDATE;

      INSERT INTO OPERACION.ELP_VERIFICACION_ETAPA (ID_VERIFICACION_ETAPA,
                                                    ID_PROC_VERIFICACION,
                                                    TASK_PM,
                                                    ID_ETAPA_JUICIO,
                                                    ID_RESULTADO_ETAPA,
                                                    ID_RAZON_RESULTADO,
                                                    FECHA_VERIFICACION,
                                                    VERIFICADOR,
                                                    ES_FINAL,
                                                    COMENTARIO)
         SELECT OPERACION.SEQ_ELP_VERIFICACION_ETAPA.NEXTVAL,
                ID_PROC_VERIFICACION,
                PTASK_PM,
                ID_ETAPA_JUICIO,
                PID_RESULTADO,
                PID_RAZON_RESULTADO,
                LFECHA_VERIFICACION,
                PVERIFICADOR,
                0,
                PCOMENTARIO
           FROM OPERACION.ELP_PROC_VERIFICACION
          WHERE ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN;

      COMMIT;
   END SP_INSERTA_VERIFICACIONQ;
-- END: Metodo consumido en QUASAR

-- BEGIN: SP_INSERTA_VERIFICACION_DOCUMENTOS Metodo consumido en QUASAR
   PROCEDURE SP_INSERTA_VERIFICA_DOC (
      PTASK_PM                VARCHAR2,
      ID_DOCUMENTO_ETAPA      NUMBER,
      ID_RESULTADO_DOCUMENTO  NUMBER,
      PVERIFICADOR            VARCHAR2,
      PCOMENTARIO             VARCHAR2)
   IS
      LFECHA_VERIFICACION   DATE;
      LVERIFICADOS          NUMBER := 0;
   BEGIN
      LFECHA_VERIFICACION := SYSDATE;

      IF     ID_RESULTADO_DOCUMENTO IS NOT NULL
         AND ID_RESULTADO_DOCUMENTO <> 0
      THEN
            OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.SP_INSERTA_VERIFICACION_DOC (
               PTASK_PM,
               ID_DOCUMENTO_ETAPA,
               ID_RESULTADO_DOCUMENTO,
               0,
               PVERIFICADOR,
               LFECHA_VERIFICACION);
            LVERIFICADOS := LVERIFICADOS + 1;
      END IF;

      IF LVERIFICADOS = 0
      THEN
         raise_application_error (
            -20002,
            'Es requerido calificar al menos un documento');
      END IF;


   END SP_INSERTA_VERIFICA_DOC;
-- END: Metodo consumido en QUASAR

-- BEGIN: SP_INSERTA_VERIFICACION_FINAL Metodo consumido en QUASAR
PROCEDURE SP_INSERTA_VERIFICACION_FINAL (
      PID_PROC_VERIFICA_IN    NUMBER,
      PTASK_PM                VARCHAR2,
      PID_RESULTADO           NUMBER,
      PID_RAZON_RESULTADO     NUMBER,
      PVERIFICADOR            VARCHAR2,
      PCOMENTARIO             VARCHAR2)
   IS
      LVERIF_DOC            OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.VERIFICACION_DOCUMENTO_REC;
      RAZON_RESULTADO       OPERACION.CAT_RAZON_RESULTADO%ROWTYPE;
      LCREDITO              OPERACION.ELP_CREDITO.NUMERO%TYPE;
      LJUICIO               OPERACION.ELP_JUICIO.NUMERO%TYPE;

      LFECHA_VERIFICACION   DATE;

      LID_ETAPA_JUICIO      NUMBER;
      LID_JUICIO            NUMBER;

      LES_CORRECTA          NUMBER;

      LNOMBRE_TABLA         OPERACION.CAT_MONTO.TABLA%TYPE;
      LNOMBRE_CAMPO         OPERACION.CAT_MONTO.CAMPO%TYPE;
      LCAMPO_JUICIO         OPERACION.CAT_MONTO.CAMPO_JUICIO%TYPE;
      LCAMPO_COACREDITADO         VARCHAR2 (500);


      LMONTO                OPERACION.ELP_MONTO_ETAPA_JUICIO.MONTO%TYPE;
      LNUMERO_JUICIO        OPERACION.ELP_JUICIO.NUMERO%TYPE;

      DR_QUERY              VARCHAR2 (2000);
      DR_QUERY_SELECT       VARCHAR2 (2000) := '';

      LFECHA_VERIFICA       DATE;

      LVALOR_PREV           NUMBER;
      LVALOR_POST           NUMBER;
      LNUM_CREDITO    VARCHAR2 (30);

      TYPE cur_typ IS REF CURSOR;

      CUR_MONTO_PREV        cur_typ;

      LVERIFICADOS          NUMBER := 0;

      ---VAR_AUDIT
      EXT_USER              VARCHAR2 (40);
      EXT_HOST              VARCHAR2 (1000);
      EXT_IP_ADDRESS        VARCHAR2 (30);
      EXT_OS_USER           VARCHAR2 (1000);
      EXT_CONCAT_VAL        VARCHAR2 (4000);
      EXT_OBJ               VARCHAR2 (500);
      ---VAR_AUDIT

      LMENSAJE         VARCHAR2 (2000) := '';

      LSOLICITANTE          OPERACION.ELP_PROC_VERIFICACION.SOLICITANTE%TYPE;

      CURSOR CUR_MONTOS_ETAPA (
         PID_PROC_VERIFICA_IN    NUMBER)
      IS
         SELECT CM.TABLA AS TABLA,
                CM.CAMPO AS CAMPO,
                MEJ.MONTO AS MONTO,
                CM.CAMPO_JUICIO AS CAMPO_JUICIO,
                J.NUMERO AS NUMERO_JUICIO,
                J.ID_JUICIO AS ID_JUICIO,
                PV.SOLICITANTE,
                MEJ.COACREDITADO
           FROM OPERACION.ELP_PROC_VERIFICACION PV
                JOIN OPERACION.ELP_MONTO_ETAPA_JUICIO MEJ
                   ON (PV.ID_PROC_VERIFICACION = MEJ.ID_PROC_VERIFICACION)
                JOIN OPERACION.ELP_ETAPA_JUICIO EJ
                   ON (MEJ.ID_ETAPA_JUICIO = EJ.ID_ETAPA_JUICIO)
                JOIN OPERACION.ELP_JUICIO J ON (EJ.ID_JUICIO = J.ID_JUICIO)
                JOIN OPERACION.CAT_MONTO CM ON (MEJ.ID_MONTO = CM.ID_MONTO)
          WHERE PV.ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN;
   BEGIN
      LFECHA_VERIFICACION := SYSDATE;


      SELECT EJ.ID_ETAPA_JUICIO, EJ.ID_JUICIO, PV.FECHA_FIN
        INTO LID_ETAPA_JUICIO, LID_JUICIO, LFECHA_VERIFICA
        FROM OPERACION.ELP_PROC_VERIFICACION PV
             JOIN OPERACION.ELP_ETAPA_JUICIO EJ
                ON (PV.ID_ETAPA_JUICIO = EJ.ID_ETAPA_JUICIO)
       WHERE PV.ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN;


--      FOR i IN 1 .. PVERIFICACIONES_DOC.COUNT
 --     LOOP
 --        LVERIF_DOC := PVERIFICACIONES_DOC (i);

--         IF     LVERIF_DOC.ID_RESULTADO_DOCUMENTO IS NOT NULL
  --          AND LVERIF_DOC.ID_RESULTADO_DOCUMENTO <> 0
--         THEN
  --          OPERACION.PKG_ELP_VERIFICACION_DOCUMENTO.SP_INSERTA_VERIFICACION_DOC (
--               PTASK_PM,
  --             LVERIF_DOC.ID_DOCUMENTO_ETAPA,
--               LVERIF_DOC.ID_RESULTADO_DOCUMENTO,
  --             0,
 --              PVERIFICADOR,
   --            LFECHA_VERIFICACION);
 --           LVERIFICADOS := LVERIFICADOS + 1;
  --       END IF;
 --     END LOOP;

--      IF LVERIFICADOS = 0
--      THEN
--         raise_application_error (
--            -20002,
--            'Es requerido calificar al menos un documento');
--      END IF;

      INSERT INTO OPERACION.ELP_VERIFICACION_ETAPA (ID_VERIFICACION_ETAPA,
                                                    ID_PROC_VERIFICACION,
                                                    TASK_PM,
                                                    ID_ETAPA_JUICIO,
                                                    ID_RESULTADO_ETAPA,
                                                    ID_RAZON_RESULTADO,
                                                    FECHA_VERIFICACION,
                                                    VERIFICADOR,
                                                    ES_FINAL,
                                                    COMENTARIO)
           VALUES (OPERACION.SEQ_ELP_VERIFICACION_ETAPA.NEXTVAL,
                   PID_PROC_VERIFICA_IN,
                   PTASK_PM,
                   LID_ETAPA_JUICIO,
                   PID_RESULTADO,
                   PID_RAZON_RESULTADO,
                   LFECHA_VERIFICACION,
                   PVERIFICADOR,
                   1,
                   PCOMENTARIO);


      UPDATE OPERACION.ELP_ETAPA_JUICIO
         SET ID_RESULTADO_ETAPA = PID_RESULTADO,
             ID_RAZON_RESULTADO = PID_RAZON_RESULTADO,
             COMENTARIO = PCOMENTARIO,
             FECHA_VERIFICACION = LFECHA_VERIFICACION,
             EN_PROCESO = 0,
             VERIFICADOR = PVERIFICADOR
       WHERE ID_ETAPA_JUICIO = LID_ETAPA_JUICIO;

      UPDATE OPERACION.ELP_PROC_VERIFICACION
         SET FECHA_FIN = LFECHA_VERIFICACION
       WHERE ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN;

      IF PID_RAZON_RESULTADO IS NOT NULL
      THEN
         SELECT *
           INTO RAZON_RESULTADO
           FROM OPERACION.CAT_RAZON_RESULTADO
          WHERE ID_RAZON_RESULTADO = PID_RAZON_RESULTADO;

         IF     RAZON_RESULTADO.CODIGO_ACCION IS NOT NULL
            AND RAZON_RESULTADO.CODIGO_RESULTADO IS NOT NULL
         THEN
            SELECT C.NUMERO, J.NUMERO
              INTO LCREDITO, LJUICIO
              FROM OPERACION.ELP_ETAPA_JUICIO EJ
                   JOIN OPERACION.ELP_JUICIO J
                      ON (EJ.ID_JUICIO = J.ID_JUICIO)
                   JOIN OPERACION.ELP_CREDITO_JUICIO JC
                      ON (J.ID_JUICIO = JC.ID_JUICIO)
                   JOIN OPERACION.ELP_CREDITO C
                      ON (JC.ID_CREDITO = C.ID_CREDITO)
             WHERE EJ.ID_ETAPA_JUICIO = LID_ETAPA_JUICIO AND ROWNUM = 1;

            OPERACION.PKG_UTILERIAS.SP_INSERTA_ACTIVIDAD (
               SUBSTR (RAZON_RESULTADO.CODIGO_ACCION, 1, 2),
               SUBSTR (RAZON_RESULTADO.CODIGO_RESULTADO, 1, 2),
               PCOMENTARIO,
               LJUICIO,
               PVERIFICADOR,
               LFECHA_VERIFICACION,
               'j',
               333);
         END IF;
      END IF;

      SELECT COUNT (1)
        INTO LES_CORRECTA
        FROM OPERACION.ELP_CONFIGURACION CF
             JOIN
             (SELECT MAX (ID_CONFIGURACION_EL) AS ID_CONFIGURACION_EL
                FROM OPERACION.ELP_CONFIGURACION) CFM
                ON (CF.ID_CONFIGURACION_EL = CFM.ID_CONFIGURACION_EL)
       WHERE CF.ID_RES_ETAPA_CALCULO = PID_RESULTADO;

      IF LES_CORRECTA <> 0
      THEN
         OPEN CUR_MONTOS_ETAPA (PID_PROC_VERIFICA_IN);

         FETCH CUR_MONTOS_ETAPA
            INTO LNOMBRE_TABLA,
                 LNOMBRE_CAMPO,
                 LMONTO,
                 LCAMPO_JUICIO,
                 LNUMERO_JUICIO,
                 LID_JUICIO,
                 LSOLICITANTE,
                 LCAMPO_COACREDITADO;

         WHILE CUR_MONTOS_ETAPA%FOUND
         LOOP
            IF LCAMPO_COACREDITADO IS NULL THEN
                DR_QUERY_SELECT :=
                      'SELECT '
                   || LNOMBRE_CAMPO
                   || ' FROM '
                   || LNOMBRE_TABLA
                   || ' WHERE '
                   || LCAMPO_JUICIO
                   || '= :JUICIO';
                DR_QUERY :=
                      'UPDATE '
                   || LNOMBRE_TABLA
                   || ' SET '
                   || LNOMBRE_CAMPO
                   || '= :MONTO WHERE '
                   || LCAMPO_JUICIO
                   || '= :JUICIO';

                BEGIN
                   OPEN CUR_MONTO_PREV FOR DR_QUERY_SELECT USING LNUMERO_JUICIO;

                   FETCH CUR_MONTO_PREV INTO LVALOR_PREV;

                   IF CUR_MONTO_PREV%FOUND
                   THEN
                      OPERACION.PKG_ELP_HISTORIAL_JUICIO.SP_CAMPO_JUICIO (
                         LNOMBRE_CAMPO,
                         LNUMERO_JUICIO,
                         TO_CHAR (LVALOR_PREV),
                         TO_CHAR (LMONTO),
                         SYSDATE,
                         LSOLICITANTE);
                   END IF;

                   CLOSE CUR_MONTO_PREV;
                EXCEPTION
                   WHEN OTHERS
                   THEN
                      DBMS_OUTPUT.PUT_LINE (SQLERRM);
                END;

                EXECUTE IMMEDIATE DR_QUERY USING LMONTO, LNUMERO_JUICIO;
            ELSE
              BEGIN
                 SELECT NUMERO_CREDITO
                   INTO LNUM_CREDITO
                   FROM OPERACION.VW_ELP_JUICIO_BANDEJA
                  WHERE NUMERO_JUICIO = LNUMERO_JUICIO;
                IF INSTR(LNOMBRE_TABLA,'UDA1') > 0 OR INSTR(LNOMBRE_TABLA,'UDA2') > 0  THEN
                       DR_QUERY :=
                      'UPDATE RCVRY.UDA1'
                       || ' SET '
                       || 'U1'||SUBSTR(LNOMBRE_CAMPO,3)
                       || '= :COACRED WHERE '
                       || 'U1'||SUBSTR(LCAMPO_JUICIO,3)
                       || '= :JUICIO';
                       EXECUTE IMMEDIATE DR_QUERY USING LCAMPO_COACREDITADO, LNUM_CREDITO;
                         DR_QUERY :=
                      'UPDATE RCVRY.UDA2'
                       || ' SET '
                        || 'U2'||SUBSTR(LNOMBRE_CAMPO,3)
                       || '= :COACRED WHERE '
                        || 'U2'||SUBSTR(LCAMPO_JUICIO,3)
                       || '= :JUICIO';
                       EXECUTE IMMEDIATE DR_QUERY USING LCAMPO_COACREDITADO, LNUM_CREDITO;
                ELSE
                       DR_QUERY :=
                      'UPDATE '
                   || LNOMBRE_TABLA
                   || ' SET '
                   || LNOMBRE_CAMPO
                   || '= :MONTO WHERE '
                   || LCAMPO_JUICIO
                   || '= :JUICIO';
                       EXECUTE IMMEDIATE DR_QUERY USING LCAMPO_COACREDITADO, LNUMERO_JUICIO;
                END IF;
              EXCEPTION
                 WHEN OTHERS
                 THEN
                     OPERACION.PKG_ELP_CORTE_JUICIO.SP_LOG_ERROR (LNUMERO_JUICIO,
                       'VERIFIFINAL',
                       'VERIFIFINAL',
                       SYSDATE || '-->' || LNUMERO_JUICIO||'-'||SUBSTR (SQLERRM, 1, 900));
              END;

            END IF;
            FETCH CUR_MONTOS_ETAPA
               INTO LNOMBRE_TABLA,
                    LNOMBRE_CAMPO,
                    LMONTO,
                    LCAMPO_JUICIO,
                    LNUMERO_JUICIO,
                    LID_JUICIO,
                    LSOLICITANTE,
                    LCAMPO_COACREDITADO;
         END LOOP;

         CLOSE CUR_MONTOS_ETAPA;
      END IF;

      
      --    Actualiza campo de etapa reprocesada a borrado
      

      UPDATE RCVRY.HIST_ETAPA_VALIDAD
         SET ETAPA_BORRADA = 'BORRADA'
       WHERE     (NO_DE_CREDITO,
                  FOLIO,
                  CONSECUTIVO,
                  CARTTIPO) IN (SELECT C.NUMERO,
                                       J.NUMERO,
                                       CE.NUMERO,
                                       CA.DESCRIPCION
                                  FROM OPERACION.ELP_PROC_VERIFICACION EV
                                       JOIN OPERACION.ELP_ETAPA_JUICIO EJ
                                          ON (EV.ID_ETAPA_JUICIO =
                                                 EJ.ID_ETAPA_JUICIO)
                                       JOIN OPERACION.ELP_JUICIO J
                                          ON (EJ.ID_JUICIO = J.ID_JUICIO)
                                       JOIN OPERACION.CAT_ETAPA_LEGAL CE
                                          ON (EJ.ID_ETAPA_LEGAL =
                                                 CE.ID_ETAPA_LEGAL)
                                       JOIN OPERACION.ELP_CREDITO_JUICIO CJ
                                          ON (J.ID_JUICIO = CJ.ID_JUICIO)
                                       JOIN OPERACION.ELP_CREDITO C
                                          ON (CJ.ID_CREDITO = C.ID_CREDITO)
                                       JOIN OPERACION.CAT_CARTERA CA
                                          ON (C.ID_CARTERA = CA.ID_CARTERA)
                                 WHERE EV.ID_PROC_VERIFICACION =
                                          PID_PROC_VERIFICA_IN)
             AND ETAPA_BORRADA IS NULL;

      INSERT INTO RCVRY.HIST_ETAPA_VALIDAD (NO_DE_CREDITO,
                                            FOLIO,
                                            FECHA_INICIO_ETAPA,
                                            FECHA_FIN_ETAPA,
                                            CONSECUTIVO,
                                            ETAPA,
                                            RESULTADO_VERIFICA,
                                            FECHA_DE_VERIFICACION,
                                            USUARIO_CYBER_LEGAL,
                                            CALIFICACION,
                                            FECHA_CARGA,
                                            CARTTIPO)
         SELECT I.CREDITO,
                I.JUICIO,
                I.FECHA_INICIO,
                I.FECHA_TERMINO,
                I.NUMERO,
                I.ETAPA,
                RE.CLAVE,
                LFECHA_VERIFICACION,
                PVERIFICADOR,
                RR.DESCRIPCION,
                SYSDATE,
                I.CARTERA
           FROM (SELECT C.NUMERO AS CREDITO,
                        J.NUMERO AS JUICIO,
                        EJ.FECHA_INICIO,
                        EJ.FECHA_TERMINO,
                        CE.NUMERO,
                        CE.NOMBRE AS ETAPA,
                        CA.DESCRIPCION AS CARTERA
                   FROM OPERACION.ELP_PROC_VERIFICACION EV
                        JOIN OPERACION.ELP_ETAPA_JUICIO EJ
                           ON (EV.ID_ETAPA_JUICIO = EJ.ID_ETAPA_JUICIO)
                        JOIN OPERACION.ELP_JUICIO J
                           ON (EJ.ID_JUICIO = J.ID_JUICIO)
                        JOIN OPERACION.CAT_ETAPA_LEGAL CE
                           ON (EJ.ID_ETAPA_LEGAL = CE.ID_ETAPA_LEGAL)
                        JOIN OPERACION.ELP_CREDITO_JUICIO CJ
                           ON (J.ID_JUICIO = CJ.ID_JUICIO)
                        JOIN OPERACION.ELP_CREDITO C
                           ON (CJ.ID_CREDITO = C.ID_CREDITO)
                        JOIN OPERACION.CAT_CARTERA CA
                           ON (C.ID_CARTERA = CA.ID_CARTERA)
                  WHERE EV.ID_PROC_VERIFICACION = PID_PROC_VERIFICA_IN) I,
                OPERACION.CAT_RESULTADO_ETAPA RE,
                OPERACION.CAT_RAZON_RESULTADO RR
          WHERE     RE.ID_RESULTADO_ETAPA = PID_RESULTADO
                AND RR.ID_RAZON_RESULTADO = PID_RAZON_RESULTADO;


      OPERACION.PKG_ELP_GENERACION_CALCULOS.SP_ACTUALIZA_METRICAS (
         LID_JUICIO);


      COMMIT;
     EXCEPTION
         WHEN OTHERS
         THEN
             LMENSAJE := 'Error: ' || SQLERRM;

              EXT_CONCAT_VAL :=
               'PID_PROC_VERIFICA_IN^^'
            || PID_PROC_VERIFICA_IN
            || '^PTASK_PM^^'
            || PTASK_PM
            || '^PID_RESULTADO^^'
            || PID_RESULTADO
            || '^PID_RAZON_RESULTADO^^'
            || PID_RAZON_RESULTADO
            || '^PVERIFICADOR^^'
            || PVERIFICADOR
            || '^PCOMENTARIO^^'
            || PCOMENTARIO
            || '^LMENSAJE2^^'
            || LMENSAJE;
         EXT_OBJ :=
            'OPERACION.PKG_ELP_VERIFICACION_ETAPAS.SP_INSERTA_VERIFICACION_FINAL2';
         DBA_MONITOREO.PA_INSERTA_AUDIT_PROCESOS (EXT_USER,
                                                  EXT_HOST,
                                                  EXT_IP_ADDRESS,
                                                  EXT_OS_USER,
                                                  EXT_OBJ,
                                                  EXT_CONCAT_VAL);

   END SP_INSERTA_VERIFICACION_FINAL;
   
-- END: Metodo consumido en QUASAR de MEsa de Control 

END PKG_ELP_VERIFICACION_ETAPAS;
/
