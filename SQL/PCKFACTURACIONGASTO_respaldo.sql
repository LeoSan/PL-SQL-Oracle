CREATE OR REPLACE PACKAGE BODY PENDUPM.PCKFACTURACIONGASTO
IS
/*
    HISTORIAL DE CAMBIOS
    20160329-->MAMB--> SE VALIDAN LOS EXCEDENTES DE GASTOS, LOS COMPROBANTES DEBEN SER MAYORES QUE LO SOLICITADO
    20160401-->MAMB--> SI NO HAY DOCUMENTOS DE SOPORTE A VALIDAR TERMINO EL PROCESO
    20160405-->MAMB--> AL INICIO DE LA COMPROBACION, EL IMPORTE COMPROBADO DEBE SER CERO CAMPO FNIMPORTECOMPROBA
    20160518-->MAMV--> SE ACTUALIZAN LOS PROCEDIMIENTOS  validaMasivaCreditoAsigna Y validaArchivoAsigna PARA CARGAS MASIVAS DE CREDITOS
    20160811-->MAMB--> AJUSTE AL VALIDAR EXCEDENTE DEL GASTO, SOLO IMPORTES SIN IVA
    20160825-->MAMB--> VALIDACION DE PAGOS DOBLES SERVICIOS ABA
    20160831-->MAMV--> Se agrega ORDER BY a la funcion queConceptoGasto para evitar mostrar registros duplicados en pantallas de tesoreria.
    20160914-->MAMV--> Se agrega metodo para reasignacion de autorizadores.
    20160927-->MAMV-->    Se modifica logica para la regla de autorizaciones de Etapas de Juicio.
    20160929-->MARAGON--> Se agregan formato de fechas y homologacion a montos.
    20160929-->MAMV-->    Se modifica mensaje para etapas abiertas.
    20161011-->MAMV--> Se actualiza GETDETALLEASIGNACION para solicitar solo supervisores de juicios activos.
    20161013-->MAMV--> Se actualiza regla para gastos dobles omitiendo gastos cancelados
    20161101-->MAMV--> Se valida estatus de credito para ABA y no marque pago doble, y los casos sin fechas de pago de servicios se cuentan como pago doble
    20161103-->MAMV--> Actualizacion de regla de umbrales para tomar conceptos con umbral CERO.
    20161213-->MAMV--> Actualizacion de regla de Etapa final.
    20160112-->MAMV--> Se cambia de dblink vistaAsociados@puntula.com a pendupm.VISTAASOCIADOS
    20170123-->MAMV--> Se quita la autorizacion por URGENTE
    20170127-->MAMV--> Se agrega metodo para busqueda por niveles
    20170207-->MAMV--> Se valida que el concepto este configurado para pago doble
    20170216-->MAMV--> Se agrega actualziacion de banderas para autorizadores de Etapas y PD.
    20170309-->MAMV--> Se agrega pagos parcilaes
    20170517-->MAMV--> Se agrega validacion para pagos dobles para vista en BI
   */

   FUNCTION queUsuarioMail (psEmail VARCHAR2)
      RETURN INTEGER
   IS
      quienEs   INTEGER := 0;
   BEGIN
      SELECT "cvetra"
        INTO quienEs
        FROM PENDUPM.VISTAASOCIADOS
       WHERE "email" = psEmail;

      RETURN quienEs;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN '-1';
   END queUsuarioMail;

   FUNCTION queEmpleadoMail (pnUsuario INTEGER)
      RETURN VARCHAR2
   IS
      quienEs   VARCHAR2 (50) := '';
   BEGIN
      SELECT "email"
        INTO quienEs
        FROM PENDUPM.VISTAASOCIADOS
       WHERE "cvetra" = pnUsuario;

      RETURN quienEs;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN '**ERROR**';
   END queEmpleadoMail;

   FUNCTION queEmpleadoMailPuesto (quePuesto INTEGER)
      RETURN VARCHAR2
   IS
      quienEs           VARCHAR2 (50) := '';
      queEmpleadoMail   INTEGER := 0;
   BEGIN
      SELECT IDNUMEMPLEADO
        INTO queEmpleadoMail
        FROM CTPUESTOEMPLEADO
       WHERE     IDPUESTOASIGNA = quePuesto
             AND FCSTATUS = 'A'
             AND FDFECREGISTRO =
                    (SELECT MIN (FDFECREGISTRO)
                       FROM CTPUESTOEMPLEADO
                      WHERE IDPUESTOASIGNA = quePuesto AND FCSTATUS = 'A')
             AND ROWNUM = 1;

      SELECT "email"
        INTO quienEs
        FROM PENDUPM.VISTAASOCIADOS
       WHERE "cvetra" = queEmpleadoMail;

      RETURN quienEs;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN '-1';
   END queEmpleadoMailPuesto;

   FUNCTION queCorreoAutoriza (gasto INTEGER, puesto INTEGER)
      RETURN VARCHAR2
   IS
      correosalida   VARCHAR2 (100) := '';
      existe         INTEGER := 0;
   BEGIN

      SELECT COUNT (1)
        INTO existe
        FROM gastoestructura
       WHERE     idgastomain = gasto
             AND clavepuesto IN (SELECT fcnumpuestorh
                                   FROM puestocatalcuentas
                                  WHERE idcatpuesto = puesto);

      IF (existe = 0)
      THEN
         SELECT EMAILPUESTO
           INTO correosalida
           FROM GASTOESTRUCTURA
          WHERE     IDGASTOMAIN = gasto
                AND IDCONSECUTIVO = (SELECT MAX (IDCONSECUTIVO)
                                       FROM GASTOESTRUCTURA
                                      WHERE IDGASTOMAIN = gasto);

      ELSE
         SELECT EMAILPUESTO
           INTO correosalida
           FROM gastoestructura
          WHERE     idgastomain = gasto
                AND IDCONSECUTIVO =
                       (SELECT MAX (IDCONSECUTIVO)
                          FROM gastoestructura
                         WHERE     idgastomain = gasto
                               AND clavepuesto IN (SELECT fcnumpuestorh
                                                     FROM puestocatalcuentas
                                                    WHERE idcatpuesto =
                                                             puesto));

      END IF;

      RETURN correosalida;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN '**ERROR**';
   END queCorreoAutoriza;


   FUNCTION queCorreoNiveles (pnUsuario INTEGER, puntos INTEGER)
      RETURN VARCHAR2
   IS
      quienEs            INTEGER := 0;
      mailQuienEs        VARCHAR2(50) := 0;
      quienEsJefe        INTEGER := 0;
      puestoJefe         VARCHAR2(50) := '';
      existeAutorizador  INTEGER := 0;

   BEGIN

      SELECT "cvetra_jefe"
        INTO quienEsJefe
        FROM PENDUPM.VISTAASOCIADOS
       WHERE "cvetra" = pnUsuario;

      SELECT "cvepue"
        INTO puestoJefe
        FROM PENDUPM.VISTAASOCIADOS
       WHERE "cvetra" = quienEsJefe;

      SELECT COUNT(1) TOTAL
        INTO existeAutorizador
        FROM PENDUPM.CTCATALOGONIVELES
       WHERE CVEPUE = puestoJefe AND PESO >= puntos;

      IF ( pnUsuario = quienEsJefe ) THEN
         mailQuienEs := quienEsJefe;
      ELSIF (existeAutorizador = 0) THEN
         mailQuienEs := queCorreoNiveles( quienEsJefe, puntos);
      ELSE
         SELECT "email"
           INTO mailQuienEs
           FROM PENDUPM.VISTAASOCIADOS
          WHERE "cvetra" = quienEsJefe;
      END IF;

      RETURN mailQuienEs;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN 0;
   END queCorreoNiveles;


   PROCEDURE addConceptoGasto (pnCaso             INTEGER,
                               pnconcepto         INTEGER,
                               psQueTramite       VARCHAR2,
                               quienSolic         INTEGER,
                               queUsuPM           VARCHAR2,
                               quetipoEs          VARCHAR2,
                               psAPPUID           VARCHAR2,
                               psSalida       OUT VARCHAR2)
   IS
      vsExiste           INTEGER := 0;
      vsExiste1          INTEGER := 0;
      vnsucursal         INTEGER := 0;
      queelemento        INTEGER := 0;
      numConsec          INTEGER := 0;
      queHistorico       INTEGER := 0;
      vnHayUno           INTEGER := 0;
      esConcepto         INTEGER := 0;
      esIgual            INTEGER := 0;
      queTpoTram         VARCHAR2 (50) := '';
      hayOtros           INTEGER := 0;
      esImpFacturado     VARCHAR2 (3) := '';
      esCuentaContable   VARCHAR2 (30) := '';
      otroTiposolic      INTEGER := 0;
      esTpoSolicAct      VARCHAR2 (30) := '';
      queSucursal        VARCHAR2 (30) := '';

      CURSOR cuPrimero (queConc INTEGER)
      IS
         SELECT *
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = queConc;

      CURSOR cuSegundo (queConc INTEGER)
      IS
         SELECT *
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = queConc;
   BEGIN
      psSalida := '0';

      SELECT FCCUENTACONTABLE
        INTO esCuentaContable
        FROM CTCATALOGOCUENTAS
       WHERE IDCONCEPTO = pnconcepto;

      SELECT COUNT (1)
        INTO vsExiste
        FROM FACTURACIONMAIN
       WHERE IDGASTOMAIN = pnCaso AND IDCONCEPTO = pnconcepto;

      SELECT COUNT (1), MAX (IDCONCEPTO), MAX (TPOMOVIMIENTO)
        INTO vnHayUno, esConcepto, queTpoTram
        FROM FACTURACIONMAIN
       WHERE     IDGASTOMAIN = pnCaso
             AND FDFECREGISTRO = (SELECT MIN (FDFECREGISTRO)
                                    FROM FACTURACIONMAIN
                                   WHERE IDGASTOMAIN = pnCaso);

      BEGIN
         SELECT NVL (FCIMPFACTTRAMITE, 'N')
           INTO esImpFacturado
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = esConcepto;
      EXCEPTION
         WHEN OTHERS
         THEN
            esImpFacturado := 'N';
      END;

      BEGIN
         SELECT "cveUbicacion"
           INTO queSucursal
           FROM PENDUPM.VISTAASOCIADOS
          WHERE "cvetra" = quienSolic;
      EXCEPTION
         WHEN OTHERS
         THEN
            queSucursal := '001';
      END;

      SELECT COUNT (1)
        INTO hayOtros
        FROM FACTURAGASTO
       WHERE IDGASTOMAIN = pnCaso;

      IF (hayOtros = 0)
      THEN
         INSERT INTO FACTURAGASTO
              VALUES (pnCaso,
                      SYSDATE,
                      NULL,
                      psAPPUID,
                      quienSolic);
      ELSE
         UPDATE FACTURAGASTO
            SET FCUSUARIO = quienSolic
          WHERE IDGASTOMAIN = pnCaso;
      END IF;

      BEGIN
         SELECT IDSUCURSAL
           INTO vnsucursal
           FROM CTSUCURSALPENDULUM
          WHERE CVEUBICACION = queSucursal;
      EXCEPTION
         WHEN OTHERS
         THEN
            vnsucursal := NULL;
      END;

      BEGIN
         SELECT MAX (IDHISTORICO) CUALES
           INTO queHistorico
           FROM HISTORICOCATALCUENTAS
          WHERE IDCONCEPTO = pnconcepto;
      EXCEPTION
         WHEN OTHERS
         THEN

            INSERT INTO HISTORICOCATALCUENTAS
               SELECT SEQHISTCATCTAS.NEXTVAL, A.*
                 FROM CTCATALOGOCUENTAS A
                WHERE IDCONCEPTO = pnconcepto;

            SELECT MAX (IDHISTORICO) CUALES
              INTO queHistorico
              FROM HISTORICOCATALCUENTAS
             WHERE IDCONCEPTO = pnconcepto;
      END;

      IF (queHistorico IS NULL)
      THEN

         INSERT INTO HISTORICOCATALCUENTAS
            SELECT SEQHISTCATCTAS.NEXTVAL, A.*
              FROM CTCATALOGOCUENTAS A
             WHERE IDCONCEPTO = pnconcepto;

         SELECT MAX (IDHISTORICO) CUALES
           INTO queHistorico
           FROM HISTORICOCATALCUENTAS
          WHERE IDCONCEPTO = pnconcepto;
      END IF;

      ---  Verifica que el Concepto no exista en la solicitud
      IF (vsExiste = 0)
      THEN

         SELECT COUNT (1)
           INTO otroTiposolic
           FROM FACTURACIONMAIN
          WHERE     IDGASTOMAIN = pnCaso
                AND UPPER (TPOMOVIMIENTO) != UPPER (psQueTramite);

         BEGIN
            SELECT DISTINCT TPOMOVIMIENTO
              INTO esTpoSolicAct
              FROM FACTURACIONMAIN
             WHERE IDGASTOMAIN = pnCaso;
         EXCEPTION
            WHEN OTHERS
            THEN
               esTpoSolicAct := 0;
         END;

         IF (otroTiposolic = 0)
         THEN
            ---- so ya Existe un Concepto valida que sean Iguales en Configuracion
            IF (vnHayUno > 0)
            THEN
               esIgual := 0;
               psSalida := '0';

               FOR regValida IN cuPrimero (esConcepto)
               LOOP
                  FOR regActual IN cuSegundo (pnconcepto)
                  LOOP
                     IF (regValida.FCJEFEINMEDIATO != regActual.FCJEFEINMEDIATO)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion JEFE INMEDIATO NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCTIPOJEFEIN != regActual.FCTIPOJEFEIN)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion JEFE INMEDIATO TIPO AUTORIZADOR NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTMONTO01 != regActual.AUTMONTO01)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR MONTO 01 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTMONTO02 != regActual.AUTMONTO02)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR MONTO 02 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTMONTO03 != regActual.AUTMONTO03)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR MONTO 03 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTMONTO03A != regActual.AUTMONTO03A)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR MONTO 03A NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTMONTO03B != regActual.AUTMONTO03B)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR MONTO 03B NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTETAPA01 != regActual.AUTETAPA01)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR ETAPA 01 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTETAPA02 != regActual.AUTETAPA02)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR ETAPA 02 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTPGODBL01 != regActual.AUTPGODBL01)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR PAGO DOBLE 01 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTPGODBL02 != regActual.AUTPGODBL02)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR PAGO DOBLE 02 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCVERIFFINAL01 !=
                               regActual.FCVERIFFINAL01)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR FINAL 01 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCVERIFFINAL02 !=
                               regActual.FCVERIFFINAL02)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR FINAL 02 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCVERIFFINAL03 !=
                               regActual.FCVERIFFINAL03)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR FINAL 03 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCANTICIPO != regActual.FCANTICIPO)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion MARCA ANTICIPO NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCREEMBOLSO != regActual.FCREEMBOLSO)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion MARCA REEMBOLSO NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCTRAMITE != regActual.FCTRAMITE)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion MARCA TRAMITE NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCIMPFACTTRAMITE !=
                               regActual.FCIMPFACTTRAMITE)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion MARCA TRAMITE - FACTURACION NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.IDTITULARAREACONC !=
                               regActual.IDTITULARAREACONC)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion TITULAR AREA CONCENT NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCTITAREACONC !=
                               regActual.FCTITAREACONC)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion TITULAR AREA CONCENT NO es igual para esta Solicitud ';
                        EXIT;
                     ELSE
                        psSalida := '0';
                     END IF;

                     IF (regValida.FCREQNOFACT != regActual.FCREQNOFACT)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZA NO FACTURABLE NO es igual para esta Solicitud ';
                        EXIT;
                     ELSE
                        IF (regValida.FCREQNOFACT = 'S' )
                        THEN
                            IF (   regValida.IDREQNOFACT1 != regActual.IDREQNOFACT1 OR regValida.FCTIPONOFACT1 != regActual.FCTIPONOFACT1
                                OR regValida.IDREQNOFACT2 != regActual.IDREQNOFACT2 OR regValida.FCTIPONOFACT2 != regActual.FCTIPONOFACT2 OR regValida.FCNOMBRENOFACT2 != regActual.FCNOMBRENOFACT2 )
                            THEN
                                psSalida :=
                                '*ALERTA* La Configuracion AUTORIZA NO FACTURABLE NO es igual para esta Solicitud, autorizadores ';
                            ELSE
                                psSalida := '0';
                            END IF;

                        ELSE
                            psSalida := '0';
                        END IF;

                     END IF;

                  END LOOP;
               END LOOP;
            END IF;

            ---- si no hay diferencias en Catalogo Agrega elConcepto
            IF (psSalida = '0')
            THEN
               psSalida := '0';

               INSERT INTO FACTURACIONMAIN (IDGASTOMAIN,
                                            IDCONCEPTO,
                                            IDPROCESO,
                                            FDFECREGISTRO,
                                            FNNUMEMPLEADO,
                                            IDSOLICITANTE,
                                            IDSUCURSAL,
                                            FCSTATUS,
                                            TPOMOVIMIENTO,
                                            APP_UID,
                                            IDHISTORICO,
                                            IDPROVEEDORGTO,
                                            FCCUENTACONTABLE,
                                            FCTRAMITEFACTURADO)
                    VALUES (pnCaso,
                            pnconcepto,
                            8,
                            SYSDATE,
                            quienSolic,
                            queUsuPM,
                            vnsucursal,
                            'R',
                            psQueTramite,
                            psAPPUID,
                            queHistorico,
                            NULL,
                            esCuentaContable,
                            esImpFacturado);

               IF (UPPER (queTpoTram) = 'TRAMITE')
               THEN
                  UPDATE FACTURACIONMAIN
                     SET FCTRAMITEFACTURADO = esImpFacturado
                   WHERE IDGASTOMAIN = pnCaso;
               END IF;
            --              ELSE
            --                  COMMIT;
            END IF;
         ELSE
            psSalida :=
                  '*ALERTA* NO se pueden Combinar Diferentes Tipos de Solicitud ['
               || esTpoSolicAct
               || '] Si desea Cambiarlo Elimine los Conceptos Existentes';
         END IF;
      ELSE
         SELECT COUNT (1)
           INTO otroTiposolic
           FROM FACTURACIONMAIN
          WHERE     IDGASTOMAIN = pnCaso
                AND UPPER (TPOMOVIMIENTO) != UPPER (psQueTramite);

         IF (otroTiposolic > 0)
         THEN
            BEGIN
               SELECT DISTINCT TPOMOVIMIENTO
                 INTO esTpoSolicAct
                 FROM FACTURACIONMAIN
                WHERE IDGASTOMAIN = pnCaso;
            EXCEPTION
               WHEN OTHERS
               THEN
                  esTpoSolicAct := 0;
            END;

            psSalida :=
                  '*ALERTA* NO se pueden Combinar Diferentes Tipos de Solicitud ['
               || esTpoSolicAct
               || '] Si desea Cambiarlo Elimine los Conceptos Existentes';
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         --     ROLLBACK;
         psSalida :=
            '*ERROR*' || pnCaso || '-' || pnconcepto || '-**' || SQLERRM;
         DBMS_OUTPUT.PUT_LINE (
               '*ERROR* '
            || pnCaso
            || '-'
            || pnconcepto
            || '-'
            || '8'
            || '-**'
            || SQLERRM);
   END addConceptoGasto;

   PROCEDURE delConceptoGasto (pnCaso           INTEGER,
                               pnconcepto       INTEGER,
                               psSalida     OUT VARCHAR2)
   IS
      vsExiste       INTEGER := 0;
      vsExiste1      INTEGER := 0;
      vnsucursal     INTEGER := 0;
      queelemento    INTEGER := 0;
      numConsec      INTEGER := 0;
      queHistorico   INTEGER := 0;
   BEGIN
      SELECT COUNT (1)
        INTO vsExiste
        FROM FACTURACIONMAIN
       WHERE IDGASTOMAIN = pnCaso AND IDCONCEPTO = pnconcepto;

      IF (vsExiste = 0)
      THEN
         psSalida := '*ERROR* El Concepto NO existe en la Solicitud';
      ELSE
         DELETE FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnCaso AND IDCONCEPTO = pnconcepto;

         DELETE FACTURADCSOPORTE
          WHERE IDGASTOMAIN = pnCaso AND IDCONCEPTO = pnconcepto;

         DELETE FACTURADCINICIO
          WHERE IDGASTOMAIN = pnCaso AND IDCONCEPTO = pnconcepto;

         DELETE FACTURACIONCOTIZA
          WHERE IDGASTOMAIN = pnCaso AND IDCONCEPTO = pnconcepto;

         --            DELETE BITACORATRANSACCION WHERE  IDGASTOMAIN = pnCaso;
         DELETE GASTOESTRUCTURA
          WHERE IDGASTOMAIN = pnCaso;

         DELETE FACTURACIONMAIN
          WHERE IDGASTOMAIN = pnCaso AND IDCONCEPTO = pnconcepto;

         COMMIT;
         psSalida := '0';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         DBMS_OUTPUT.PUT_LINE ('*ERROR* ' || SQLERRM);
   END delConceptoGasto;

   PROCEDURE setSolicitudGasto (pnCaso              INTEGER,
                                quienSolic          INTEGER,
                                queJefeInmed        VARCHAR2,
                                quetipoEs           VARCHAR2,
                                queSeveridad        VARCHAR2,
                                queEmpresaFact      VARCHAR2,
                                queOtEmpresaFact    VARCHAR2,
                                queFormaPago        VARCHAR2,
                                queTipoCuenta       VARCHAR2,
                                psCadenaEjecuta     VARCHAR2,
                                psAPPUID            VARCHAR2,
                                pdFecRequerida      VARCHAR2,
                                estructuraJer       VARCHAR2)
   IS
      vsExiste       INTEGER := 0;
      vsExiste1      INTEGER := 0;
      vnsucursal     INTEGER := 0;
      queelemento    INTEGER := 0;
      numConsec      INTEGER := 0;
      queHistorico   INTEGER := 0;
      --FecRequerida   DATE := TO_DATE (pdFecRequerida, 'DD/MM/YYYY');
      FecRequerida   DATE := TO_DATE (pdFecRequerida, 'YYYY/MM/DD');
      psErrorD       VARCHAR2 (500) := '';
   BEGIN
      DBMS_OUTPUT.PUT_LINE ('INICIO...');

      SELECT COUNT (1)
        INTO vsExiste
        FROM FACTURACIONMAIN
       WHERE IDGASTOMAIN = pnCaso;

      IF (vsExiste = 0)
      THEN
         INSERT INTO BITACORATRANSACCION
              VALUES (pnCaso,
                      queelemento,
                      psCadenaEjecuta,
                      SYSDATE,
                      SYSDATE,
                      '**ERROR** NO EXISTE LASOLICITUD ' || pnCaso);
      ELSE
         UPDATE FACTURACIONMAIN
            SET FNNUMEMPLEADO = quienSolic,
                IDSOLICITANTE = queJefeInmed,
                TPOMOVIMIENTO = quetipoEs,
                FCSEVERIDADGASTO = queSeveridad,
                IDEMPRESAFACTURACION = queEmpresaFact,
                IDOTEMPRESAFACTURACION = queOtEmpresaFact,
                IDFORMAPAGO = queFormaPago,
                FCTIPOCUENTA = queTipoCuenta,
                APP_UID = psAPPUID,
                FDFECHAREQUERIDA = FecRequerida,
                FCESTRUCTURAJER = estructuraJer
          WHERE IDGASTOMAIN = pnCaso;

         DBMS_OUTPUT.PUT_LINE ('UPDATE FACTURACIONMAIN....');

         --           UPDATE FACTURACIONAUT SET FCAUTORIZADOR =queJefeInmed, FDFECREGISTRO = SYSDATE
         --              WHERE IDGASTOMAIN = pnCaso AND IDTIPOAUTORIZA = 10;

         SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

         INSERT INTO BITACORATRANSACCION
              VALUES (pnCaso,
                      queelemento,
                      psCadenaEjecuta,
                      SYSDATE,
                      SYSDATE,
                      '0');
      END IF;

      DBMS_OUTPUT.PUT_LINE ('EXITOSO....');

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         INSERT INTO BITACORATRANSACCION
              VALUES (pnCaso,
                      queelemento,
                      psCadenaEjecuta,
                      SYSDATE,
                      SYSDATE,
                      psErrorD);

         COMMIT;
         DBMS_OUTPUT.PUT_LINE ('-1 ' || SQLERRM);
   END setSolicitudGasto;

  PROCEDURE setAutAdicionales (pnCaso              INTEGER,
                                quienSolic          INTEGER,
                                psCadenaEjecuta     VARCHAR2,
                                psIdTask            VARCHAR2 DEFAULT '1',
                                psDelindex          INTEGER DEFAULT 1,
                                psTipomovimiento    VARCHAR2)
   IS
      hayUmbrales       INTEGER := 0;
      hayPgodup         INTEGER := 0;
      hayEtapaProc      INTEGER := 0;
      idConcepto        INTEGER := 0;
      idConcepto        NUMBER (12, 2) := 0;
      importeTOT        NUMBER (12, 2) := 0;
      importeIVA        NUMBER (12, 2) := 0;
      importeNETO       NUMBER (12, 2) := 0;
      esPgoDbl          CHAR (1) := NULL;
      vsError           VARCHAR2 (4000) := NULL;
      vdEmailPgo        VARCHAR2 (80) := NULL;
      vdEmailPgo1       VARCHAR2 (80) := NULL;
      vsValorPaso       VARCHAR2 (20) := NULL;
      vsValorPaso1      VARCHAR2 (20) := NULL;
      umbral1           NUMBER (10, 2) := NULL;
      umbral2           NUMBER (10, 2) := NULL;
      umbral1a          NUMBER (10, 2) := NULL;
      umbral2a          NUMBER (10, 2) := NULL;
      vcEmailUmb        VARCHAR2 (80) := NULL;
      vcEmailUmb1       VARCHAR2 (80) := NULL;
      vcEmailUmb2       VARCHAR2 (80) := NULL;
      etapaClose        VARCHAR2 (150) := NULL;
      etapaopen         VARCHAR2 (50) := NULL;
      vdEmailTapa       VARCHAR2 (80) := NULL;
      vdEmailTapa1      VARCHAR2 (80) := NULL;
      queelemento       INTEGER := 0;
      existeEtapas      INTEGER := 0;
      existeMonto       INTEGER := 0;
      numConsec         INTEGER := 0;
      tipoAlerta        INTEGER := 0;
      jefeInmediato     VARCHAR (80) := '';
      umbralMaximo      INTEGER := 0;
      consecutivo       INTEGER := 1;
      esUnTramite       INTEGER := 0;
      psErrorD          VARCHAR2 (500) := '';
      pnconcepto        INTEGER := 0;
      existeJefeInmed   INTEGER := 0;
      dondeEstoy        INTEGER := 0;
      queEmpPuesto      INTEGER := 0;
      cualEsElError     VARCHAR2 (500) := '0';
      hayError          INTEGER := 0;
      existeStatus      INTEGER := 0;
      existeUmbral      INTEGER := 0;
      psCatEtaCraVer    VARCHAR2 (2000) := '';
      psCatEtaAbi       VARCHAR2 (2000) := '';
      psCatCodAcc       VARCHAR2 (2000) := '';
      psCatCodRes       VARCHAR2 (2000) := '';
      psCatEtaFinal     VARCHAR2 (2000) := '';
      queEtapaCRAVER    VARCHAR2 (2000) := '';
      queEtapaABTA      VARCHAR2 (2000) := '';
       psCredito         VARCHAR2 (150) := '';
      hayJuicioCred     INTEGER := 0;
      queCodAccion      VARCHAR2 (150) := '';
      queCodResultado   VARCHAR2 (150) := '';
      queTipoJuicio      NUMBER (5) := '';
      queTipoDemanda     NUMBER (5) := '';
      existeEtapaCrra    INTEGER := 0;
      existeEtapaAbie    INTEGER := 0;
      ubica              INTEGER := 0;
      vnBarre            INTEGER := 0;
      cadena1            VARCHAR2 (4000) := '';
      valor              VARCHAR2 (4000) := '';
      contador           INTEGER := 0;
      sqmlEtapasLegales VARCHAR2 (2000) := '';
      strElementos       STRING_FNC.t_array;
      totalEtapasCerradas INTEGER     := 0;
      totalEtapasAbiertas INTEGER     := 0;
      fnmontoTotal      INTEGER     := 0;
      cadenaArma         VARCHAR2 (4000) := '';
      fntipomov          INTEGER     := 0;
      pnPagoDoble        NUMBER (5) := 0;
      pnPagoDoblePM      NUMBER (5) := 0;
      pnPagoDobleDYN     NUMBER (5) := 0;
      psCuentaContable   VARCHAR2 (30) := '';
      fecha_pago_ini    DATE;
      fecha_pago_fin    DATE;
      esPagoServicio    INTEGER := 0;
      esPagoDoble       INTEGER := 0;
      pnImporte       NUMBER (5) := 0;
      pnQueUmbral        INTEGER := 0;
      importeUmbral      NUMBER (10, 2) := 0;
      importeRebasado    NUMBER (10, 2) := 0;
      queUmbralRebaso    NUMBER (10) := 0;
      esTramFact         VARCHAR2 (30) := '';

      TYPE CUR_TYP IS REF CURSOR;
      cursor_Legales   CUR_TYP;

      CURSOR cuConcepto
      IS
         SELECT *
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO IN (SELECT IDCONCEPTO
                                 FROM FACTURACIONMAIN
                                WHERE IDGASTOMAIN = pnCaso);

        CURSOR cuQueAsignacion
      IS
           SELECT *
             FROM FACTURAASIGNACION
            WHERE IDGASTOMAIN = pnCaso
         ORDER BY IDCONCEPTO, IDTIPOMOVTO, FCCREDITOCARTERA;

       CURSOR cuJuicios (tpoDem NUMBER)
      IS
         SELECT CCCASENO, CCCASENO CCCASENODESC
           FROM RCVRY.CASEACCT
          WHERE     CCACCT = psCredito
                AND CCCASENO IN (SELECT CECASENO
                                   FROM RCVRY.CASE
                                  WHERE CESTATUS = 'A')
                AND CCCASENO IN (SELECT NUMERO
                                   FROM OPERACION.ELP_JUICIO
                                  WHERE ID_TIPO_DEMANDA = tpoDem);

      CURSOR cuEtapaCrraVerif(
         psjuicio    INTEGER,
         psEtapa     VARCHAR2)
         IS
           SELECT *
             FROM OPERACION.VW_ELP_ETAPAS_LEGALES
            WHERE     NUMERO_JUICIO = psjuicio
                  AND EN_PROCESO = 0
                  AND EN_PROCESO_PM = 0
                  AND ES_RETROCESO_ETAPAS= 0
                  AND FECHA_TERMINO IS NOT NULL
                  AND RESULTADO_VERIFICACION = 'CORRECTO'
                  AND NUMERO_ETAPA = psEtapa
         ORDER BY ORDEN DESC;

      CURSOR cuEtapaAbierta (
         psjuicio    INTEGER,
         psEtapa     VARCHAR2)
      IS
           SELECT *
             FROM OPERACION.VW_ELP_ETAPAS_LEGALES
            WHERE     NUMERO_JUICIO = psjuicio
                  AND EN_PROCESO = 0
                  AND FECHA_TERMINO IS NULL
                  AND NUMERO_ETAPA = psEtapa
                  AND ORDEN =
                         (SELECT MAX (ORDEN)
                            FROM OPERACION.VW_ELP_ETAPAS_LEGALES
                           WHERE     NUMERO_JUICIO = psjuicio
                                 AND EN_PROCESO = 0
                                 AND FECHA_TERMINO IS NULL
                                 AND NUMERO_ETAPA = psEtapa)
         ORDER BY ORDEN DESC;


      CURSOR cuUmbral (
         psConcepto    INTEGER)
      IS
         SELECT DISTINCT
                FCCREDITOCARTERA,
                FCQUEUMBRAL CUALUMBRAL,
                FNUMBRALREBASADO REBASADO
           FROM FACTURAASIGNACION
          WHERE     IDGASTOMAIN = pnCaso
                AND IDCONCEPTO = psConcepto
                AND FCQUEUMBRAL > 0;

      CURSOR cuCarteraNoFact (
         psConcepto    INTEGER)
      IS
         SELECT DISTINCT
                FCCREDITOCARTERA,
                FCESFACTURABLE ESFACTURABLE,
                FCESREEMBOLSABLE ESREEMBOLSABLE,
                FCUSUPM USUPM
           FROM FACTURAASIGNACION
          WHERE     IDGASTOMAIN = pnCaso
                AND IDCONCEPTO = psConcepto
                AND ( ( FCESFACTURABLE = 'N' AND FCESREEMBOLSABLE = 'N'   ) OR 
                      ( FCESFACTURABLE = 'N' AND FCESREEMBOLSABLE IS NULL ) OR
                      ( FCESFACTURABLE IS NULL AND FCESREEMBOLSABLE = 'N' ) ) ;

      CURSOR cuCreditosPagados ( psCredito VARCHAR2, psConcepto VARCHAR2 ) IS
         SELECT * FROM (SELECT FA.IDGASTOMAIN, FA.IDCONCEPTO, FA.FCCREDITOCARTERA,
            FDFECREALPAGO, FCREMESA, FDFECSERVPAGADODEL, FDFECSERVPAGADOAL,
            ( CASE WHEN ( SELECT COUNT(1) FROM PENDUPM.FACTURACIONBITACORA
                           WHERE IDGASTOMAIN = FA.IDGASTOMAIN AND IDTASKGASTO = '4515947455273e63c4198f0073790158'
                                                  AND FCRESULTADO = 'Autorizado' ) > 0
                   THEN FNIMPORTECOMPROBA
                   ELSE FNIMPORTE END ) MONTO_TOTAL
            FROM PENDUPM.FACTURAASIGNACION FA INNER JOIN PENDUPM.FACTURACIONMAIN FM ON (FA.IDGASTOMAIN = FM.IDGASTOMAIN AND FA.IDCONCEPTO = FM.IDCONCEPTO)
                                              INNER JOIN PENDUPM.CTCATALOGOCUENTAS CT ON ( FA.IDCONCEPTO = CT.IDCONCEPTO )
            WHERE
            FA.FCCREDITOCARTERA = psCredito
            AND FA.IDCONCEPTO = psConcepto
            AND (FA.FDFECSERVPAGADODEL IS NOT NULL OR FA.FDFECSERVPAGADOAL IS NOT NULL)
            AND FA.IDGASTOMAIN != pnCaso AND FM.FCSTATUS NOT IN ('Z','R')
            AND FA.STATUS = 'A' AND CT.FCPAGODOBLE = 'S'
            ) WHERE MONTO_TOTAL > 0 ORDER BY FDFECSERVPAGADODEL;


        CURSOR cuCreditosPagadosSinFechas ( psCredito VARCHAR2, psConcepto VARCHAR2) IS
         SELECT * FROM (SELECT FA.IDGASTOMAIN, FA.IDCONCEPTO, FA.FCCREDITOCARTERA,
            FDFECREALPAGO, FCREMESA, FDFECSERVPAGADODEL, FDFECSERVPAGADOAL,
            ( CASE WHEN ( SELECT COUNT(1) FROM PENDUPM.FACTURACIONBITACORA
                           WHERE IDGASTOMAIN = FA.IDGASTOMAIN AND IDTASKGASTO = '4515947455273e63c4198f0073790158'
                                                  AND FCRESULTADO = 'Autorizado' ) > 0
                   THEN FNIMPORTECOMPROBA
                   ELSE FNIMPORTE END ) MONTO_TOTAL
            FROM PENDUPM.FACTURAASIGNACION FA INNER JOIN PENDUPM.FACTURACIONMAIN FM ON (FA.IDGASTOMAIN = FM.IDGASTOMAIN AND FA.IDCONCEPTO = FM.IDCONCEPTO)
                                              INNER JOIN PENDUPM.CTCATALOGOCUENTAS CT ON ( FA.IDCONCEPTO = CT.IDCONCEPTO )
            WHERE
            FA.FCCREDITOCARTERA = psCredito
            AND FA.IDCONCEPTO = psConcepto
            AND (FA.FDFECSERVPAGADODEL IS NULL AND FA.FDFECSERVPAGADOAL IS NULL)
            AND FA.IDGASTOMAIN != pnCaso AND FM.FCSTATUS NOT IN ('Z','R')
            AND FA.STATUS = 'A' AND CT.FCPAGODOBLE = 'S'
            ) WHERE MONTO_TOTAL > 0 ORDER BY FDFECSERVPAGADODEL;

   BEGIN
      --- elimina las Autorizaciones  de la solicitud
      DELETE FACTURACIONAUT
       WHERE     IDGASTOMAIN = pnCaso
             AND IDTASKPM = psIdTask
             AND IDDELINDEX = psDelindex;

      UPDATE FACTURAASIGNACION
         SET FCUSUJFEINMED = NULL,
             FCRESULTJFEINMED = NULL,
             FCUSUUMBRAL03 = NULL,
             FCUSUUMBRAL04 = NULL,
             FCUSUUMBRAL05 = NULL,
             FCRESUMBRAL03 = NULL,
             FCRESUMBRAL04 = NULL,
             FCRESUMBRAL05 = NULL,
             FCUSUETAPA01 = NULL,
             FCUSUETAPA02 = NULL,
             FCRESETAPA01 = NULL,
             FCRESETAPA02 = NULL,
             FCUSUPGODBL01 = NULL,
             FCUSUPGODBL02 = NULL,
             FCRESPGODBL01 = NULL,
             FCRESPGODBL02 = NULL,
             FCUSUEMPRESA = NULL,
             FCRESEMPRESA = NULL,
             FCUSUURGENTE = NULL,
             FCRESURGENTE = NULL
       WHERE IDGASTOMAIN = pnCaso;


      --- Obtiene el Primer Concepto Capturado que sirvio de base para Autoriaciones  ctcatalogogastos
      SELECT IDCONCEPTO
        INTO pnconcepto
        FROM FACTURACIONMAIN
       WHERE     FDFECREGISTRO = (SELECT MIN (FDFECREGISTRO)
                                    FROM FACTURACIONMAIN
                                   WHERE IDGASTOMAIN = pnCaso)
             AND IDGASTOMAIN = pnCaso;



      --- Barre todos los Conceptos / Cr?ditos de la Solicitud
      FOR alerta IN cuConcepto
      LOOP

        


         ---- ****  JEFE INMEDIATO *****
         
         IF alerta.FCTIPOJEFEIN = 'S'
         THEN
            BEGIN
               SELECT EMAILPUESTO
                 INTO vdEmailPgo
                 FROM GASTOESTRUCTURA
                WHERE IDGASTOMAIN = pnCaso AND IDCONSECUTIVO = 2;
            EXCEPTION
               WHEN OTHERS
               THEN
                  SELECT EMAILPUESTO
                    INTO vdEmailPgo
                    FROM GASTOESTRUCTURA
                   WHERE     IDGASTOMAIN = pnCaso
                         AND IDCONSECUTIVO = (SELECT MAX (IDCONSECUTIVO)
                                                FROM GASTOESTRUCTURA
                                               WHERE IDGASTOMAIN = pnCaso);
            END;
         ELSIF alerta.FCTIPOJEFEIN = 'O'
         THEN

            IF (alerta.FCTIPOJEFEINMED = 'E')
            THEN
               vdEmailPgo := alerta.IDJEFEINMEDIATO;
            ELSIF (alerta.FCTIPOJEFEINMED = 'T')
            THEN
               vdEmailPgo :=
                  PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                    alerta.IDJEFEINMEDIATO
                  );
            ELSIF (alerta.FCTIPOJEFEINMED = 'P')
            THEN
               vdEmailPgo := PENDUPM.PCKFACTURACIONGASTO.QUECORREONIVELES (
                    quienSolic, alerta.FCJEFEINMEDIATO
               );
            END IF;

         ELSE
            vdEmailPgo := NULL;
         END IF;

         IF (vdEmailPgo IS NOT NULL)
         THEN

            SELECT COUNT (1)
              INTO existeJefeInmed
              FROM FACTURACIONAUT
             WHERE     IDGASTOMAIN = pnCaso
                   AND FCAUTORIZADOR = vdEmailPgo
                   AND IDTIPOAUTORIZA = 9
                   AND IDTASKPM = psIdTask
                   AND IDDELINDEX = psDelindex;

            IF (existeJefeInmed = 0)
            THEN
               INSERT INTO FACTURACIONAUT
                    VALUES (pnCaso,
                            vdEmailPgo,
                            9,
                            consecutivo,
                            'JFE INMED',
                            SYSDATE,
                            NULL,
                            quienSolic,
                            NULL,
                            NULL,
                            NULL,
                            NULL,
                            psIdTask,
                            psDelindex,
                            NULL,
                            NULL);

               UPDATE FACTURAASIGNACION
                  SET FCUSUJFEINMED =
                         PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                WHERE IDGASTOMAIN = pnCaso;

               consecutivo := consecutivo + 1;
            ELSE
               UPDATE FACTURAASIGNACION
                  SET FCUSUJFEINMED =
                         PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                WHERE IDGASTOMAIN = pnCaso;
            END IF;
         END IF;





         ---- *** AUTORIZACION POR CAMBIO DE EMPRESA A FACTURAR -- SE ASIGNA A ELDA
         SELECT DISTINCT IDEMPRESAFACTURACION, IDOTEMPRESAFACTURACION
           INTO vsValorPaso, vsValorPaso1
           FROM FACTURACIONMAIN
          WHERE IDGASTOMAIN = pnCaso AND IDCONCEPTO = alerta.IDCONCEPTO;

         vdEmailPgo := NULL;

         IF (vsValorPaso = '0' AND vsValorPaso1 != '0')
         THEN
            vdEmailPgo := 'eramirez@pendulum.com.mx';


            SELECT COUNT (1)
              INTO existeJefeInmed
              FROM FACTURACIONAUT
             WHERE     IDGASTOMAIN = pnCaso
                   AND FCAUTORIZADOR = vdEmailPgo
                   AND IDTIPOAUTORIZA = 10
                   AND IDTASKPM = psIdTask
                   AND IDDELINDEX = psDelindex;

            IF (existeJefeInmed = 0)
            THEN
               UPDATE FACTURAASIGNACION
                  SET FCUSUEMPRESA =
                         PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                WHERE IDGASTOMAIN = pnCaso;

               INSERT INTO FACTURACIONAUT
                    VALUES (pnCaso,
                            vdEmailPgo,
                            10,
                            consecutivo,
                            'EMP FACT',
                            SYSDATE,
                            NULL,
                            quienSolic,
                            NULL,
                            NULL,
                            NULL,
                            NULL,
                            psIdTask,
                            psDelindex,
                            NULL,
                            NULL);

               consecutivo := consecutivo + 1;
            END IF;
         END IF;


         ---- **** ETAPAS PROCESALES Y CODIGOS DE ACCION *****    /*CTCATALOGOCUENTAS  ctcatalogogastos  FACTURACIONMAIN */
         SELECT COUNT (1) TOTAL
           INTO existeEtapas
            FROM FACTURAASIGNACION
            WHERE (IDGASTOMAIN = pnCaso AND IDCONCEPTO = alerta.IDCONCEPTO  AND (VERETAPACDACHKNO IS NOT NULL OR VERETAPAABIERTANO IS NOT NULL) )
                OR (IDGASTOMAIN = pnCaso AND IDCONCEPTO = alerta.IDCONCEPTO AND (FCCODACCEXTNO IS NOT NULL OR FCCODRESEXTNO IS NOT NULL) );

           SELECT IDTIPOMOVTO
           INTO fntipomov
            FROM FACTURAASIGNACION
            WHERE IDGASTOMAIN = pnCaso AND IDCONCEPTO = alerta.IDCONCEPTO
            GROUP BY IDTIPOMOVTO;



-- Actualiza Etapas

        FOR regAsignacion IN cuQueAsignacion
         LOOP
        IF (fntipomov = 2 OR fntipomov = 3)
        THEN
                  
                  psCredito := regAsignacion.FCCREDITOCARTERA;
                  psCatEtaCraVer := alerta.VERETAPACDACHK;
                  psCatEtaAbi    := alerta.VERETAPAABIERTA;
                  psCatCodAcc    := alerta.FCCODACCEXT;
                  psCatCodRes    := alerta.FCCODRESEXT;                  
                  psCatEtaFinal  := alerta.VERETAPACDACHKFIN;
       
                  --****** Verifica Etapas Procesales / JUICIOS ACTIVOS ********

                     queEtapaCRAVER := '';
                     queEtapaABTA   := '';

                     SELECT COUNT (1)
                       INTO hayJuicioCred
                       FROM RCVRY.CASEACCT
                      WHERE     CCACCT = regAsignacion.FCCREDITOCARTERA
                            AND CCCASENO IN (SELECT CECASENO
                                               FROM RCVRY.CASE
                                              WHERE CESTATUS = 'A')
                            AND CCCASENO IN (SELECT NUMERO
                                               FROM OPERACION.ELP_JUICIO
                                              WHERE ID_TIPO_DEMANDA = 2);

                     IF (hayJuicioCred = 0)
                     THEN
                        queEtapaCRAVER :=
                              queEtapaCRAVER
                           || 'EL CREDITO '
                           || regAsignacion.FCCREDITOCARTERA
                           || ' NO TIENE JUICIOS ACTIVOS<BR/>';
                        queEtapaABTA :=
                              queEtapaABTA
                           || 'EL CREDITO '
                           || regAsignacion.FCCREDITOCARTERA
                           || ' NO TIENE JUICIOS ACTIVOS<BR/>';
                     END IF;

                     FOR regjuicios IN cuJuicios (2)
                     LOOP
                        /*  IDTIPODEMANDA = 1  EN CONTRA   /  IDTIPODEMANDA = 2  DEMANDA NUESTRA */
                        /*  OPERACION.ELP_JUICIO campo  ID_TIPO_DEMANDA del catalogo OPERACION.CAT_TIPO_DEMANDA */
                        --- Obtiene el Tipo de Demanda del Juicio
                        --- Obtiene Valores para juicio
                        BEGIN
                           SELECT ID_TIPO_DEMANDA, ID_TIPO_JUICIO
                             INTO queTipoJuicio, queTipoDemanda
                             FROM OPERACION.ELP_JUICIO
                            WHERE NUMERO = regjuicios.CCCASENO;
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              queTipoJuicio := NULL;
                              queTipoDemanda := NULL;
                        END;

                        ---  Barre para Validar las ETAPAS CERADAS Y VERIFICADAS del JUICIO
                        queEtapaCRAVER := '';
                        queEtapaABTA := '';
                        existeEtapaCrra := 0;

                        IF ( (alerta.VERETAPACDACHK IS NOT NULL))
                        THEN
                           existeEtapaCrra := 0;

                           sqmlEtapasLegales := 'SELECT COUNT(1) TOTAL FROM OPERACION.VW_ELP_ETAPAS_LEGALES WHERE NUMERO_JUICIO = '|| regjuicios.CCCASENO ||'
                                AND EN_PROCESO = 0
                                AND EN_PROCESO_PM = 0
                                AND ES_RETROCESO_ETAPAS= 0
                                AND FECHA_TERMINO IS NOT NULL
                                AND RESULTADO_VERIFICACION = ''CORRECTO''
                                AND NUMERO_ETAPA IN ('|| replace(alerta.VERETAPACDACHK,'|',',') ||')
                              ORDER BY ORDEN DESC';

                           open cursor_Legales for sqmlEtapasLegales;
                            LOOP
                              FETCH cursor_Legales INTO fnmontoTotal;
                                EXIT WHEN cursor_Legales%NOTFOUND;
                                totalEtapasCerradas := fnmontoTotal;
                            END LOOP;
                           CLOSE cursor_Legales;

                            IF ( totalEtapasCerradas > 0 ) THEN
                              existeEtapaCrra := 0;

                            ELSE
                             existeEtapaCrra := existeEtapaCrra;
                             cadena1 := alerta.VERETAPACDACHK || '|';
                             ubica := INSTR (cadena1, '|');

                            WHILE (ubica > 0)
                            LOOP
                              valor := SUBSTR (cadena1, 1, ubica - 1);
                              contador := 0;

                              FOR regEtapa
                                 IN cuEtapaCrraVerif (regjuicios.CCCASENO,
                                                      valor)
                              LOOP
                                 contador := contador + 1;
                                 queEtapaCRAVER := '';

                                 IF (regEtapa.RESULTADO_VERIFICACION !=
                                        'CORRECTO')
                                 THEN
                                    queEtapaCRAVER :=
                                          queEtapaCRAVER
                                       || 'LA ETAPA ['
                                       || valor
                                       || '] FUE CALIFICADA COMO '
                                       || regEtapa.RESULTADO_VERIFICACION
                                       || ' EL DIA '
                                       || PCKCTRLDOCUMENTAL01.aplFecha (
                                             regEtapa.FECHA_VERIFICACION)
                                       || '<BR/>';
                                 ELSIF (regEtapa.RESULTADO_VERIFICACION =
                                           'CORRECTO')
                                 THEN
                                    --- Si se cumple al menos una de las etapas se sale
                                    existeEtapaCrra := 1;
                                    queEtapaCRAVER := '';
                                    EXIT;
                                 END IF;
                              END LOOP;

                              IF (existeEtapaCrra = 0)
                              THEN
                                 queEtapaCRAVER :=
                                       queEtapaCRAVER
                                    || 'LA ETAPA ['
                                    || valor
                                    || '] NO SE ENCUENTRA CERRADA Y VERIFICADA'
                                    || '<BR/>';
                              END IF;

                              cadena1 := SUBSTR (cadena1, ubica + 1);
                              ubica := INSTR (cadena1, '|');

                            END LOOP;

                           END IF;

                        END IF;

                        IF ( (alerta.VERETAPAABIERTA IS NOT NULL))
                        THEN
                        
                           cadena1 := alerta.VERETAPAABIERTA || '|';
                           existeEtapaAbie := 0;
                           queEtapaABTA := 'LAS SIGUIENTES ETAPAS NO ESTAN ABIERTAS: ';
                           ubica := INSTR (cadena1, '|');

                           WHILE (ubica > 0)
                           LOOP
                              valor := SUBSTR (cadena1, 1, ubica - 1);
                              contador := 0;

                              FOR regEtapa
                                 IN cuEtapaAbierta (regjuicios.CCCASENO,
                                                    valor)
                              LOOP
                                 contador := contador + 1;
                              END LOOP;

                              IF (contador = 0)
                              THEN
                                 queEtapaABTA :=
                                       queEtapaABTA
                                    || '['
                                    || valor
                                    || ']'
                                    || ' | ';
                              END IF;

                              IF (contador > 0)
                                 THEN
                                    --- Si se cumple al menos una de las etapas se sale
                                    queEtapaABTA := '';
                                    EXIT;
                              END IF;

                              cadena1 := SUBSTR (cadena1, ubica + 1);
                              ubica := INSTR (cadena1, '|');
                                     --DBMS_OUTPUT.PUT_LINE ('etapas procedure R10'|| ubica );                     
                           END LOOP;
                        END IF;
                     END LOOP;                     
                  --****** Verifica Codigos de Accion y Resultados del Cr?dito ********
                  queCodAccion := '';
                  queCodResultado := '';

                  IF (   (alerta.FCCODACCEXT IS NOT NULL)
                      OR (alerta.FCCODRESEXT IS NOT NULL))
                  THEN
                     IF (    (alerta.FCCODACCEXT IS NOT NULL)
                         AND (alerta.FCCODRESEXT IS NOT NULL))
                     THEN
                        FOR regjuicios IN cuJuicios (2)
                        LOOP
                            SELECT COUNT(*) INTO contador FROM OPERACION.VW_ELP_BITACORA_GESTION
                            WHERE NUMERO_JUICIO = regjuicios.CCCASENO AND CA = alerta.FCCODACCEXT AND CR = alerta.FCCODRESEXT
                            AND FECHA BETWEEN (  SYSDATE
                                                     - CASE
                                                          WHEN alerta.FNVIGENCIA
                                                                  IS NULL
                                                          THEN
                                                             30
                                                          ELSE
                                                             alerta.FNVIGENCIA
                                                       END)
                                                AND SYSDATE;

                            IF (contador = 0)
                            THEN
                               queCodAccion :=
                                     'NO Existe gestion del CA['
                                  || alerta.FCCODACCEXT
                                  || ']';
                               queCodResultado :=
                                     'NO Existe gestion del CR['
                                  || alerta.FCCODRESEXT
                                  || ']';
                            ELSE
                                queCodAccion := '';
                                queCodResultado := '';
                                EXIT;
                            END IF;
                        END LOOP;
                     ELSIF (    (alerta.FCCODACCEXT IS NOT NULL)
                            AND (alerta.FCCODRESEXT IS NULL))
                     THEN
                        FOR regjuicios IN cuJuicios (2)
                        LOOP
                            SELECT COUNT(*) INTO contador FROM OPERACION.VW_ELP_BITACORA_GESTION
                            WHERE NUMERO_JUICIO = regjuicios.CCCASENO AND CA = alerta.FCCODACCEXT
                            AND FECHA BETWEEN (  SYSDATE
                                                     - CASE
                                                          WHEN alerta.FNVIGENCIA
                                                                  IS NULL
                                                          THEN
                                                             30
                                                          ELSE
                                                             alerta.FNVIGENCIA
                                                       END)
                                                AND SYSDATE;
                            IF (contador = 0)
                            THEN
                               queCodAccion :=
                                     'NO Existe gestion del CA['
                                  || alerta.FCCODACCEXT
                                  || ']';
                               queCodResultado := '';
                            ELSE
                               queCodAccion := '';
                               queCodResultado := '';
                               EXIT;
                            END IF;
                        END LOOP;
                     ELSIF (    (alerta.FCCODACCEXT IS NULL)
                            AND (alerta.FCCODRESEXT IS NOT NULL))
                     THEN
                        FOR regjuicios IN cuJuicios (2)
                        LOOP
                            SELECT COUNT(*) INTO contador FROM OPERACION.VW_ELP_BITACORA_GESTION
                            WHERE NUMERO_JUICIO = regjuicios.CCCASENO AND CR = alerta.FCCODRESEXT
                            AND FECHA BETWEEN (  SYSDATE
                                                     - CASE
                                                          WHEN alerta.FNVIGENCIA
                                                                  IS NULL
                                                          THEN
                                                             30
                                                          ELSE
                                                             alerta.FNVIGENCIA
                                                       END)
                                                AND SYSDATE;
                            IF (contador = 0)
                            THEN
                               queCodAccion := '';
                               queCodResultado :=
                                     'NO Existe gestion del CR['
                                  || alerta.FCCODRESEXT
                                  || ']';
                            ELSE
                               queCodAccion := '';
                               queCodResultado := '';
                               EXIT;
                            END IF;
                        END LOOP;
                     ELSE
                        queCodAccion :=
                              'NO Existe gestion del CA['
                           || alerta.FCCODACCEXT
                           || ']';
                        queCodResultado :=
                              'NO Existe gestion del CR['
                           || alerta.FCCODRESEXT
                           || ']';
                     END IF;
                  END IF;

        ELSE
                  psCatEtaCraVer := NULL;
                  psCatEtaAbi := NULL;
                  psCatCodAcc := NULL;
                  psCatCodRes := NULL;
                  psCatEtaFinal := NULL;
                  queCodAccion := NULL;
                  queCodResultado := NULL;
                  queEtapaABTA := NULL;
                  queEtapaCRAVER := NULL;
                  cadenaArma := NULL;
        END IF;


        UPDATE FACTURAASIGNACION SET VERETAPACDACHKNO = queEtapaCRAVER ,
                                     VERETAPAABIERTANO =   queEtapaABTA, FCCODACCEXT =psCatCodAcc,
                                     FCCODACCEXTNO =  queCodAccion     , FCCODRESEXT =psCatCodRes,
                                     FCCODRESEXTNO =  queCodResultado  , VERETAPAFIN =psCatEtaFinal
                    WHERE IDGASTOMAIN = pnCaso AND FCCREDITOCARTERA = regAsignacion.FCCREDITOCARTERA AND IDCONCEPTO = alerta.IDCONCEPTO;

      END LOOP;

-----



         vdEmailPgo := NULL;

         IF (existeEtapas > 0)
         THEN
          

            IF (    alerta.FCTIPOAUTETAPA01 = 'E'
                AND alerta.AUTETAPA01 IS NOT NULL)
            THEN
               vdEmailPgo := alerta.AUTETAPA01;
            ELSIF (    alerta.FCTIPOAUTETAPA01 = 'T'
                AND (alerta.AUTETAPA01 IS NOT NULL))
            THEN
               vdEmailPgo :=
                  PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                     alerta.AUTETAPA01);
            ELSIF (    alerta.FCTIPOAUTETAPA01 = 'P'
                AND (alerta.AUTETAPA01 IS NOT NULL))
            THEN
         
               vdEmailPgo := PENDUPM.PCKFACTURACIONGASTO.QUECORREONIVELES (
                    quienSolic, alerta.AUTETAPA01
               );
            END IF;

            IF ( (vdEmailPgo IS NOT NULL OR vdEmailPgo != ''))
            THEN
              

               SELECT COUNT (1)
                 INTO existeJefeInmed
                 FROM FACTURACIONAUT
                WHERE     IDGASTOMAIN = pnCaso
                      AND FCAUTORIZADOR = vdEmailPgo
                      AND IDTIPOAUTORIZA = 7
                      AND IDTASKPM = psIdTask
                      AND IDDELINDEX = psDelindex;

               IF (existeJefeInmed = 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUETAPA01 =
                            PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                   WHERE     IDGASTOMAIN = pnCaso
                         AND (   VERETAPACDACHKNO IS NOT NULL
                              OR VERETAPAABIERTANO IS NOT NULL
                              OR FCCODACCEXTNO IS NOT NULL
                              OR FCCODRESEXTNO IS NOT NULL);

                  INSERT INTO FACTURACIONAUT
                       VALUES (pnCaso,
                               vdEmailPgo,
                               7,
                               consecutivo,
                               'ETAPA PROC',
                               SYSDATE,
                               NULL,
                               quienSolic,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               psIdTask,
                               psDelindex,
                               NULL,
                               NULL);

                  consecutivo := consecutivo + 1;
               END IF;
            END IF;

            vdEmailPgo := NULL;

            IF (    alerta.FCTIPOAUTETAPA02 = 'E'
                AND (alerta.AUTETAPA02 IS NOT NULL OR alerta.AUTETAPA02 != ''))
            THEN
               vdEmailPgo := alerta.AUTETAPA02;
            ELSIF (    alerta.FCTIPOAUTETAPA02 = 'T'
                AND (alerta.AUTETAPA02 IS NOT NULL OR alerta.AUTETAPA02 != ''))
            THEN
               vdEmailPgo :=
                  PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                     alerta.AUTETAPA02);
            ELSIF (    alerta.FCTIPOAUTETAPA02 = 'P'
                AND (alerta.AUTETAPA02 IS NOT NULL OR alerta.AUTETAPA02 <> ''))
            THEN
          
               vdEmailPgo := PENDUPM.PCKFACTURACIONGASTO.QUECORREONIVELES (
                    quienSolic, alerta.AUTETAPA02
               );
            END IF;

            IF ( (vdEmailPgo IS NOT NULL OR vdEmailPgo <> ''))
            THEN
               

               SELECT COUNT (1)
                 INTO existeJefeInmed
                 FROM FACTURACIONAUT
                WHERE     IDGASTOMAIN = pnCaso
                      AND FCAUTORIZADOR = vdEmailPgo
                      AND IDTIPOAUTORIZA = 7
                      AND IDTASKPM = psIdTask
                      AND IDDELINDEX = psDelindex;

               IF (existeJefeInmed = 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUETAPA02 =
                            PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                   WHERE     IDGASTOMAIN = pnCaso
                         AND (   VERETAPACDACHKNO IS NOT NULL
                              OR VERETAPAABIERTANO IS NOT NULL
                              OR FCCODACCEXTNO IS NOT NULL
                              OR FCCODRESEXTNO IS NOT NULL);

                  INSERT INTO FACTURACIONAUT
                       VALUES (pnCaso,
                               vdEmailPgo,
                               7,
                               consecutivo,
                               'ETAPA PROC',
                               SYSDATE,
                               NULL,
                               quienSolic,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               psIdTask,
                               psDelindex,
                               NULL,
                               NULL);

                  consecutivo := consecutivo + 1;
               END IF;
            END IF;
         END IF;

         -- FIN ETAPAS PROCESALES

         psCuentaContable := alerta.FCCUENTACONTABLE;

---- PAGOS DOBLES RECALCULO
FOR regAsignacion IN cuQueAsignacion
         LOOP

                pnPagoDobleDYN := 0;

            -- Valido que el concepto sea de pago de servicios
                SELECT COUNT(*) INTO esPagoServicio FROM CTCATALOGOCUENTAS WHERE FCREQPAGSERV = 'S'
                AND IDCONCEPTO = alerta.IDCONCEPTO;
                
            -- Valido que el concepto este configurado como PagoDoble
                SELECT COUNT(*) INTO esPagoDoble FROM CTCATALOGOCUENTAS WHERE FCPAGODOBLE = 'S'
                AND IDCONCEPTO = alerta.IDCONCEPTO;

            IF ( (fntipomov = 2 OR fntipomov = 3) AND esPagoServicio = 0 AND esPagoDoble > 0 )
            THEN
               --- Obtiene el numero de Pagos Dobles Encontrados
               ---  TONA LA INFO DE BI  DEL ACCESSS
               SELECT COUNT (1)
                 INTO pnPagoDobleDYN
                 FROM BI_DIMGASTOS@PENDUBI.COM
                WHERE CREDITO_CYBER = psCredito
                  AND CUENTA_CONTABLE = psCuentaContable
                  AND (PROVEEDOR IS NULL OR PROVEEDOR NOT LIKE '%PENDULUM%')
                  AND TO_NUMBER(NVL(NUMERO_CASO,0)) != pnCaso
                  AND TO_NUMBER(NVL(NUMERO_CASO,0)) NOT IN ( 
                         SELECT B.IDGASTOMAIN 
                           FROM PENDUPM.FACTURAASIGNACION A 
                     INNER JOIN PENDUPM.FACTURACIONMAIN B ON ( A.IDGASTOMAIN = B.IDGASTOMAIN AND A.IDCONCEPTO = B.IDCONCEPTO) 
                          WHERE     A.IDGASTOMAIN != pnCaso AND FCCREDITOCARTERA = psCredito AND FCSTATUS NOT IN ( 'Z','R') 
                                AND FCCUENTACONTABLE = psCuentaContable AND A.STATUS = 'A'
                  );

            ELSE
               pnPagoDoblePM := 0;
            END IF;

            --   COLUMNAS PAGO DOBLE ***   SELECT "Acct", "ProjectID" ,"Id", "Name", "OrigAcct", "RefNbr", "TranDesc", "TranDate", "DrAmt"
            IF (esPagoServicio = 0 AND esPagoDoble > 0)    THEN
                SELECT COUNT (1)
                 INTO pnPagoDoblePM
                 FROM FACTURAASIGNACION FA INNER JOIN PENDUPM.CTCATALOGOCUENTAS CT ON ( FA.IDCONCEPTO = CT.IDCONCEPTO )
                WHERE IDGASTOMAIN != pnCaso
                  AND FCCREDITOCARTERA = regAsignacion.FCCREDITOCARTERA
                  AND STATUS = 'A' AND CT.FCPAGODOBLE = 'S'
                  AND (IDGASTOMAIN) IN (SELECT IDGASTOMAIN
                                          FROM FACTURACIONBITACORA
                                         WHERE IDGASTOMAIN != pnCaso
                                           AND (IDGASTOMAIN,DEL_INDEX) IN (SELECT IDGASTOMAIN,MAX(DEL_INDEX)
                                                               FROM FACTURACIONBITACORA
                                                              WHERE IDGASTOMAIN != pnCaso
                                                                AND IDTASKGASTO NOT IN ('974392365525c7af897e890053564163','8433500185372a3c766b298052315707')
                                                           GROUP BY IDGASTOMAIN)
                                        )
                   AND (IDGASTOMAIN,psCuentaContable,FA.IDCONCEPTO) IN (SELECT IDGASTOMAIN,FCCUENTACONTABLE,IDCONCEPTO FROM FACTURACIONMAIN WHERE FCSTATUS != 'Z')
                   AND (IDGASTOMAIN, FNIMPORTE) NOT IN (SELECT IDGASTOMAIN, FNIMPORTE FROM FACTURACIONCOMPROBA WHERE FCTIPOCOMPROBANTE IN ('Ficha de Deposito','Descuento de nomina' ) );
            END IF;
            --////// Validamos los pagos dobles de Pago de servicios
            IF (esPagoServicio > 0 AND esPagoDoble > 0) THEN
                 fecha_pago_ini := regAsignacion.FDFECSERVPAGADODEL;
                 fecha_pago_fin := regAsignacion.FDFECSERVPAGADOAL;

                 FOR regSalida IN cuCreditosPagados( regAsignacion.FCCREDITOCARTERA, regAsignacion.IDCONCEPTO ) LOOP
                     IF (fecha_pago_ini <= regSalida.FDFECSERVPAGADODEL AND regSalida.FDFECSERVPAGADODEL <= fecha_pago_fin )
                        OR (fecha_pago_ini <= regSalida.FDFECSERVPAGADOAL AND regSalida.FDFECSERVPAGADOAL <= fecha_pago_fin)
                        THEN
                        pnPagoDoblePM := pnPagoDoblePM + 1;
                     EXIT;
                     END IF;
                 END LOOP;

                 FOR regSalida IN cuCreditosPagadosSinFechas( regAsignacion.FCCREDITOCARTERA, regAsignacion.IDCONCEPTO ) LOOP
                        pnPagoDoblePM := pnPagoDoblePM + 1;
                 END LOOP;

             END IF;
            pnPagoDoble := pnPagoDobleDYN + pnPagoDoblePM;


            UPDATE FACTURAASIGNACION SET FNPAGODOBLE = pnPagoDoble
                    WHERE IDGASTOMAIN = pnCaso AND FCCREDITOCARTERA = regAsignacion.FCCREDITOCARTERA AND IDCONCEPTO = alerta.IDCONCEPTO;
                    
            COMMIT;
END LOOP;
-----



         ---- **** PAGOS DOBLES  CTCATALOGOCUENTAS
         SELECT COUNT (1) TOTAL
           INTO existeEtapas
           FROM FACTURAASIGNACION
          WHERE     IDGASTOMAIN = pnCaso
                AND IDCONCEPTO = alerta.IDCONCEPTO
                AND FNPAGODOBLE > 0;

         DBMS_OUTPUT.PUT_LINE ('INSERTA PD :'||existeEtapas);

         vdEmailPgo := NULL;

         IF (existeEtapas > 0)
         THEN
            IF (    alerta.FCPAGODOBLE = 'S'
                AND alerta.TIPOAUTPGODBL01 = 'E'
                AND alerta.AUTPGODBL01 IS NOT NULL)
            THEN
               vdEmailPgo := alerta.AUTPGODBL01;
            ELSIF (    alerta.FCPAGODOBLE = 'S'
                AND alerta.TIPOAUTPGODBL01 = 'T'
                AND alerta.AUTPGODBL01 IS NOT NULL)
            THEN
               vdEmailPgo :=
                  PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                     alerta.AUTPGODBL01);
            ELSIF (    alerta.FCPAGODOBLE = 'S'
                AND alerta.TIPOAUTPGODBL01 = 'P'
                AND alerta.AUTPGODBL01 IS NOT NULL)
            THEN
               vdEmailPgo := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, alerta.AUTPGODBL01);
            END IF;

            DBMS_OUTPUT.PUT_LINE (' ES 8a -- ' || vdEmailPgo);

            IF (vdEmailPgo IS NOT NULL)
            THEN
               SELECT COUNT (1)
                 INTO existeJefeInmed
                 FROM FACTURACIONAUT
                WHERE     IDGASTOMAIN = pnCaso
                      AND FCAUTORIZADOR = vdEmailPgo
                      AND IDTIPOAUTORIZA = 8
                      AND IDTASKPM = psIdTask
                      AND IDDELINDEX = psDelindex;

               IF (existeJefeInmed = 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUPGODBL01 =
                            PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                   WHERE IDGASTOMAIN = pnCaso AND FNPAGODOBLE > 0;

                  INSERT INTO FACTURACIONAUT
                       VALUES (pnCaso,
                               vdEmailPgo,
                               8,
                               consecutivo,
                               'PGO DBL',
                               SYSDATE,
                               NULL,
                               quienSolic,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               psIdTask,
                               psDelindex,
                               NULL,
                               NULL);

                  consecutivo := consecutivo + 1;
               END IF;
            END IF;

            vdEmailPgo := NULL;

            IF (    alerta.FCPAGODOBLE = 'S'
                AND alerta.TIPOAUTPGODBL02 = 'E'
                AND alerta.AUTPGODBL02 IS NOT NULL)
            THEN
               vdEmailPgo := alerta.AUTPGODBL02;
            ELSIF (    alerta.FCPAGODOBLE = 'S'
                AND alerta.TIPOAUTPGODBL02 = 'T'
                AND alerta.AUTPGODBL02 IS NOT NULL)
            THEN
               vdEmailPgo :=
                  PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                     alerta.AUTPGODBL02);
            ELSIF (    alerta.FCPAGODOBLE = 'S'
                AND alerta.TIPOAUTPGODBL02 = 'P'
                AND alerta.AUTPGODBL02 IS NOT NULL)
            THEN
               vdEmailPgo := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, alerta.AUTPGODBL02);
            END IF;

            DBMS_OUTPUT.PUT_LINE (' ES **** 8b -- ' || vdEmailPgo);

            IF (vdEmailPgo IS NOT NULL)
            THEN
               SELECT COUNT (1)
                 INTO existeJefeInmed
                 FROM FACTURACIONAUT
                WHERE     IDGASTOMAIN = pnCaso
                      AND FCAUTORIZADOR = vdEmailPgo
                      AND IDTIPOAUTORIZA = 8
                      AND IDTASKPM = psIdTask
                      AND IDDELINDEX = psDelindex;

               IF (existeJefeInmed = 0)
               THEN
                  DBMS_OUTPUT.PUT_LINE (
                     ' ES **** 8b UPDATE-- ' || vdEmailPgo);

                  UPDATE FACTURAASIGNACION
                     SET FCUSUPGODBL02 =
                            PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                   WHERE IDGASTOMAIN = pnCaso AND FNPAGODOBLE > 0;

                  DBMS_OUTPUT.PUT_LINE (
                     ' ES **** 8b INSERT-- ' || vdEmailPgo);

                  INSERT INTO FACTURACIONAUT
                       VALUES (pnCaso,
                               vdEmailPgo,
                               8,
                               consecutivo,
                               'PGO DBL',
                               SYSDATE,
                               NULL,
                               quienSolic,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               psIdTask,
                               psDelindex,
                               NULL,
                               NULL);

                  consecutivo := consecutivo + 1;
               END IF;
            END IF;
         END IF;

         DBMS_OUTPUT.PUT_LINE ('***fin pagos dobles');


         ---******  STATUS DE CREDITOS EXCEPCIONALES 46  CTCATALOGOCUENTAS
         SELECT COUNT (1) TOTAL
           INTO existeStatus
           FROM FACTURAASIGNACION
          WHERE     IDGASTOMAIN = pnCaso
                AND IDCONCEPTO = alerta.IDCONCEPTO
                AND (FCCREDSTATUS IS NOT NULL OR FCCREDCOLA IS NOT NULL);

         DBMS_OUTPUT.PUT_LINE (
               'HAY STATUS X AUTORIZAR'
            || pnCaso
            || '****'
            || alerta.IDCONCEPTO
            || '****'
            || existeStatus);
         vdEmailPgo := NULL;

         IF (existeStatus > 0)
         THEN
            IF (    alerta.TPOAUTLIQUIDADO01 = 'E'
                AND alerta.AUTLIQUIDADO01 IS NOT NULL)
            THEN
               vdEmailPgo := alerta.AUTLIQUIDADO01;
            END IF;

            IF (    alerta.TPOAUTLIQUIDADO01 = 'T'
                AND (alerta.AUTLIQUIDADO01 IS NOT NULL))
            THEN
               vdEmailPgo :=
                  PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                     alerta.AUTLIQUIDADO01);
            END IF;

            IF (    alerta.TPOAUTLIQUIDADO01 = 'P'
                AND (alerta.AUTLIQUIDADO01 IS NOT NULL))
            THEN
       --        vdEmailPgo :=
         --         PCKFACTURACIONGASTO.queCorreoAutoriza (
           --          pnCaso,
             --        alerta.AUTLIQUIDADO01);
                vdEmailPgo := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, alerta.AUTLIQUIDADO01);
            END IF;

            IF ( (vdEmailPgo IS NOT NULL OR vdEmailPgo != ''))
            THEN
               DBMS_OUTPUT.PUT_LINE (' ES 46a -- ' || vdEmailPgo);

               SELECT COUNT (1)
                 INTO existeJefeInmed
                 FROM FACTURACIONAUT
                WHERE     IDGASTOMAIN = pnCaso
                      AND FCAUTORIZADOR = vdEmailPgo
                      AND IDTIPOAUTORIZA = 46
                      AND IDTASKPM = psIdTask
                      AND IDDELINDEX = psDelindex;

               IF (existeJefeInmed = 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSULIQUIDADO01 =
                            PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                   WHERE     IDGASTOMAIN = pnCaso
                         AND (   FCCREDSTATUS IS NOT NULL
                              OR FCCREDCOLA IS NOT NULL);

                  INSERT INTO FACTURACIONAUT
                       VALUES (pnCaso,
                               vdEmailPgo,
                               46,
                               consecutivo,
                               'STATUS / COLA CREDITO',
                               SYSDATE,
                               NULL,
                               quienSolic,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               psIdTask,
                               psDelindex,
                               NULL,
                               NULL);

                  consecutivo := consecutivo + 1;
               END IF;
            END IF;

            vdEmailPgo := NULL;

            IF (    alerta.TPOAUTLIQUIDADO02 = 'E'
                AND (   alerta.AUTLIQUIDADO02 IS NOT NULL
                     OR alerta.AUTLIQUIDADO02 != ''))
            THEN
               vdEmailPgo := alerta.AUTLIQUIDADO02;
            END IF;

            IF (    alerta.TPOAUTLIQUIDADO02 = 'T'
                AND (   alerta.AUTLIQUIDADO02 IS NOT NULL
                     OR alerta.AUTLIQUIDADO02 != ''))
            THEN
               vdEmailPgo :=
                  PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                     alerta.AUTLIQUIDADO02);
            END IF;

            IF (    alerta.TPOAUTLIQUIDADO02 = 'P'
                AND (   alerta.AUTLIQUIDADO02 IS NOT NULL
                     OR alerta.AUTLIQUIDADO02 <> ''))
            THEN
        --       DBMS_OUTPUT.PUT_LINE ('***ENTRO PUES 7B');
          --     vdEmailPgo :=
            --      PCKFACTURACIONGASTO.queCorreoAutoriza (
              --       pnCaso,
                --     alerta.AUTLIQUIDADO02);
                vdEmailPgo := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, alerta.AUTLIQUIDADO02);
            END IF;

            IF ( (vdEmailPgo IS NOT NULL OR vdEmailPgo <> ''))
            THEN
               DBMS_OUTPUT.PUT_LINE (
                     ' ES 46B -- '
                  || vdEmailPgo
                  || ' ** '
                  || alerta.FCTIPOAUTETAPA02
                  || ' ** '
                  || alerta.AUTETAPA02
                  || ';;** ');

               SELECT COUNT (1)
                 INTO existeJefeInmed
                 FROM FACTURACIONAUT
                WHERE     IDGASTOMAIN = pnCaso
                      AND FCAUTORIZADOR = vdEmailPgo
                      AND IDTIPOAUTORIZA = 46
                      AND IDTASKPM = psIdTask
                      AND IDDELINDEX = psDelindex;

               IF (existeJefeInmed = 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSULIQUIDADO02 =
                            PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                   WHERE     IDGASTOMAIN = pnCaso
                         AND (   FCCREDSTATUS IS NOT NULL
                              OR FCCREDCOLA IS NOT NULL);

                  INSERT INTO FACTURACIONAUT
                       VALUES (pnCaso,
                               vdEmailPgo,
                               46,
                               consecutivo,
                               'STATUS / COLA CREDITO',
                               SYSDATE,
                               NULL,
                               quienSolic,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               psIdTask,
                               psDelindex,
                               NULL,
                               NULL);

                  consecutivo := consecutivo + 1;
               END IF;
            END IF;
         END IF;

         DBMS_OUTPUT.PUT_LINE ('fin STATUS CREDITO');
      END LOOP;

      --- Barre todos los Conceptos / Cr?ditos de la Solicitud
      FOR alerta IN cuConcepto
      LOOP
         DBMS_OUTPUT.PUT_LINE ('completaautorizaciones');
/*
         ---- *** AUTORIZACION POR URGENCIA DEL GASTO -- MARCA DE SEVERIDAD ES URGENTE
         SELECT DISTINCT FCSEVERIDADGASTO
           INTO vsValorPaso
           FROM FACTURACIONMAIN
          WHERE IDGASTOMAIN = pnCaso AND IDCONCEPTO = alerta.IDCONCEPTO;

         vdEmailPgo := NULL;

         IF (vsValorPaso = 'Urgente')
         THEN
            vdEmailPgo := 'ehhernandez@pendulum.com.mx';
            DBMS_OUTPUT.PUT_LINE (' ES 34 -- ' || vdEmailPgo);

            SELECT COUNT (1)
              INTO existeJefeInmed
              FROM FACTURACIONAUT
             WHERE     IDGASTOMAIN = pnCaso
                   AND FCAUTORIZADOR = vdEmailPgo
                   AND IDTIPOAUTORIZA = 34
                   AND IDTASKPM = psIdTask
                   AND IDDELINDEX = psDelindex;

            IF (existeJefeInmed = 0)
            THEN
               UPDATE FACTURAASIGNACION
                  SET FCUSUURGENTE =
                         PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                WHERE IDGASTOMAIN = pnCaso;

               INSERT INTO FACTURACIONAUT
                    VALUES (pnCaso,
                            vdEmailPgo,
                            34,
                            consecutivo,
                            'SEVERIDAD',
                            SYSDATE,
                            NULL,
                            quienSolic,
                            NULL,
                            NULL,
                            NULL,
                            NULL,
                            psIdTask,
                            psDelindex,
                            NULL,
                            NULL);

               consecutivo := consecutivo + 1;
            END IF;
         END IF;
*/
         -------- VALIDO PROYECT MANAGER ----------------
         -- OBTENGO SI EL CREDITO ES FACTURABLE
         FOR regNoFact IN cuCarteraNoFact (alerta.IDCONCEPTO)
            LOOP
               dondeEstoy := 0;
               vdEmailPgo := NULL;
             IF (alerta.FCREQNOFACT = 'S')
                 THEN
                    -- Primer autorizador
                vdEmailPgo := NULL;

                IF (    alerta.FCTIPONOFACT1 = 'E'
                    AND (alerta.IDREQNOFACT1 IS NOT NULL OR alerta.IDREQNOFACT1 != ''))
                THEN
                    vdEmailPgo := alerta.IDREQNOFACT1;
                END IF;

                IF (    alerta.FCTIPONOFACT1 = 'T'
                    AND (alerta.IDREQNOFACT1 IS NOT NULL OR alerta.IDREQNOFACT1 != ''))
                THEN
                    vdEmailPgo :=
                          PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                             alerta.IDREQNOFACT1);
                END IF;

                IF (    alerta.FCTIPONOFACT1 = 'P'
                    AND (alerta.IDREQNOFACT1 IS NOT NULL OR alerta.IDREQNOFACT1 != ''))
                THEN
                    DBMS_OUTPUT.PUT_LINE ('***ENTRO AUTORIZADOR1 NO FACTURABLE');
                       vdEmailPgo :=
                          PCKFACTURACIONGASTO.queCorreoAutoriza (pnCaso,
                                                                 alerta.IDREQNOFACT1);
                END IF;

                IF ( alerta.FCTIPONOFACT1 = 'PM' )
                    THEN
                    DBMS_OUTPUT.PUT_LINE ('***ENTRO AUTORIZADOR1 PM NO FACTURABLE');
                    vdEmailPgo := regNoFact.USUPM;

                    SELECT "email"
                    INTO vdEmailPgo
                    FROM PENDUPM.VISTAASOCIADOS
                    WHERE "cvetra" = vdEmailPgo;
                END IF;


                IF (vdEmailPgo IS NOT NULL )
                 THEN
                    SELECT COUNT (1)
                      INTO existeJefeInmed
                      FROM FACTURACIONAUT
                     WHERE     IDGASTOMAIN = pnCaso
                           AND FCCREDITOCARTERA = regNoFact.FCCREDITOCARTERA
                           AND FCAUTORIZADOR = vdEmailPgo
                           AND IDTIPOAUTORIZA = 65
                           AND IDTASKPM = psIdTask
                           AND IDDELINDEX = psDelindex;

                    IF (existeJefeInmed = 0)
                    THEN

                       INSERT INTO FACTURACIONAUT
                            VALUES (pnCaso,
                                    vdEmailPgo,
                                    65,
                                    consecutivo,
                                    regNoFact.FCCREDITOCARTERA,
                                    SYSDATE,
                                    NULL,
                                    quienSolic,
                                    NULL,
                                    NULL,
                                    NULL,
                                    NULL,
                                    psIdTask,
                                    psDelindex,
                                    NULL,
                                    NULL);

                       consecutivo := consecutivo + 1;
                    END IF;
                END IF;
            END IF;
         END LOOP;


         -------- AUTORIZADOR 2 GASTO NO FACTURABLE ----------------
         -- OBTENGO SI EL CREDITO ES FACTURABLE
         FOR regNoFact IN cuCarteraNoFact (alerta.IDCONCEPTO)
            LOOP
               dondeEstoy := 0;
               vdEmailPgo := NULL;
             IF (alerta.FCREQNOFACT = 'S')
                 THEN
                -- AUTORIZADOR 2 GASTO NO FACTURABLE
                vdEmailPgo := NULL;

                IF (    alerta.FCTIPONOFACT2 = 'E'
                    AND (alerta.IDREQNOFACT2 IS NOT NULL OR alerta.IDREQNOFACT2 != ''))
                THEN
                    vdEmailPgo := alerta.IDREQNOFACT2;
                END IF;

                IF (    alerta.FCTIPONOFACT2 = 'T'
                    AND (alerta.IDREQNOFACT2 IS NOT NULL OR alerta.IDREQNOFACT2 != ''))
                THEN
                    vdEmailPgo :=
                          PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                             alerta.IDREQNOFACT2);
                END IF;

                IF (    alerta.FCTIPONOFACT2 = 'P' )
                THEN
                  vdEmailPgo :=
                  PENDUPM.PCKFACTURACIONGASTO.QUECORREONIVELES (
                      quienSolic, alerta.FCNOMBRENOFACT2
                  );
                END IF;

                IF ( alerta.FCTIPONOFACT2 = 'PM' )
                    THEN
                   vdEmailPgo := regNoFact.USUPM;

                   SELECT "email"
                    INTO vdEmailPgo
                    FROM PENDUPM.VISTAASOCIADOS
                   WHERE "cvetra" = vdEmailPgo;
                END IF;


                IF (vdEmailPgo IS NOT NULL )
                 THEN
                    SELECT COUNT (1)
                      INTO existeJefeInmed
                      FROM FACTURACIONAUT
                     WHERE     IDGASTOMAIN = pnCaso
                           AND FCCREDITOCARTERA = regNoFact.FCCREDITOCARTERA
                           AND FCAUTORIZADOR = vdEmailPgo
                           AND IDTIPOAUTORIZA = 64
                           AND IDTASKPM = psIdTask
                           AND IDDELINDEX = psDelindex;

                    IF (existeJefeInmed = 0)
                        THEN
                           UPDATE FACTURAASIGNACION
                          SET FCUSUNOFACT =
                                 PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                            WHERE IDGASTOMAIN = pnCaso;

                           INSERT INTO FACTURACIONAUT
                            VALUES (pnCaso,
                                    vdEmailPgo,
                                    64,
                                    consecutivo,
                                    regNoFact.FCCREDITOCARTERA,
                                    SYSDATE,
                                    NULL,
                                    quienSolic,
                                    NULL,
                                    NULL,
                                    NULL,
                                    NULL,
                                    psIdTask,
                                    psDelindex,
                                    NULL,
                                    NULL);

                       consecutivo := consecutivo + 1;
                    END IF;

                END IF;

            END IF;
         END LOOP;








         DBMS_OUTPUT.PUT_LINE ('** TERMINO ANTES DEVALIDACION ');


      --- Solo Aplica Umbrales SI ES ANTICIPO / PAGO
         IF (UPPER (psTipomovimiento) != 'TRAMITE')
         THEN
            ---- **** UMBRALES *****
            FOR regUmbral IN cuUmbral (alerta.IDCONCEPTO)
            LOOP
               dondeEstoy := 0;
               vdEmailPgo := NULL;
               IF regUmbral.CUALUMBRAL >= 1
               THEN
                  DBMS_OUTPUT.PUT_LINE ('es umbral 01');
                  dondeEstoy := 1;

                  IF (    alerta.FCTIPOAUTMTO01 = 'E'
                      AND alerta.AUTMONTO01 IS NOT NULL)
                  THEN
                     vdEmailPgo := alerta.AUTMONTO01;
                  END IF;

                  IF (    alerta.FCTIPOAUTMTO01 = 'T'
                      AND alerta.AUTMONTO01 IS NOT NULL)
                  THEN
                     vdEmailPgo :=
                        PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                           alerta.AUTMONTO01);
                  END IF;

                  IF (    alerta.FCTIPOAUTMTO01 = 'P'
                      AND alerta.AUTMONTO01 IS NOT NULL)
                  THEN
                     vdEmailPgo := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, alerta.AUTMONTO01);
                     --DEVELOPER
                  END IF;

                  IF( vdEmailPgo != '-1' ) THEN
                  DBMS_OUTPUT.PUT_LINE ('vdEmailPgo: '||vdEmailPgo);
                     UPDATE FACTURAASIGNACION
                     SET FCUSUUMBRAL03 =
                            PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                     WHERE IDGASTOMAIN = pnCaso AND FCQUEUMBRAL > 0;

                     INSERT INTO FACTURACIONAUT
                       VALUES (pnCaso,
                               vdEmailPgo,
                               6,
                               consecutivo,
                               regUmbral.FCCREDITOCARTERA,
                               SYSDATE,
                               NULL,
                               quienSolic,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               psIdTask,
                               psDelindex,
                               NULL,
                               NULL);

                     consecutivo := consecutivo + 1;
                  END IF;
               END IF;
               IF regUmbral.CUALUMBRAL >= 2
               THEN
                  DBMS_OUTPUT.PUT_LINE ('es umbral 02');
                  dondeEstoy := 2;

                  --Autorizador 2
                  IF (    alerta.FCTIPOAUTMTO02 = 'E'
                      AND alerta.AUTMONTO01 IS NOT NULL)
                  THEN
                     vdEmailPgo := alerta.AUTMONTO01;
                  END IF;

                  IF (    alerta.FCTIPOAUTMTO02 = 'T'
                      AND alerta.AUTMONTO01 IS NOT NULL)
                  THEN
                     vdEmailPgo :=
                        PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                           alerta.AUTMONTO02);
                  END IF;

                  IF (    alerta.FCTIPOAUTMTO02 = 'P'
                      AND alerta.AUTMONTO02 IS NOT NULL)
                  THEN
                     vdEmailPgo := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, alerta.AUTMONTO02);
                  END IF;

                  IF( vdEmailPgo != '-1' ) THEN

                     UPDATE FACTURAASIGNACION
                     SET FCUSUUMBRAL04 =
                            PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                     WHERE IDGASTOMAIN = pnCaso AND FCQUEUMBRAL > 0;

                     INSERT INTO FACTURACIONAUT
                       VALUES (pnCaso,
                               vdEmailPgo,
                               6,
                               consecutivo,
                               regUmbral.FCCREDITOCARTERA,
                               SYSDATE,
                               NULL,
                               quienSolic,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               psIdTask,
                               psDelindex,
                               NULL,
                               NULL);
                        consecutivo := consecutivo + 1;
                  END IF;

               END IF;

               IF regUmbral.CUALUMBRAL = 3
               THEN
                  dondeEstoy := 3;
                  DBMS_OUTPUT.PUT_LINE ('es umbral 03');
                  IF (    alerta.FCTIPOAUTMTO03 = 'E'
                      AND alerta.AUTMONTO03 IS NOT NULL)
                  THEN
                     vdEmailPgo := alerta.AUTMONTO03;
                  END IF;

                  IF (    alerta.FCTIPOAUTMTO03 = 'T'
                      AND alerta.AUTMONTO03 IS NOT NULL)
                  THEN
                     vdEmailPgo :=
                        PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                           alerta.AUTMONTO03);
                  END IF;

                  IF (    alerta.FCTIPOAUTMTO03 = 'P'
                      AND alerta.AUTMONTO03 IS NOT NULL)
                  THEN
                     vdEmailPgo := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, alerta.AUTMONTO03);
                  END IF;

                  IF( vdEmailPgo != '-1' ) THEN

                     UPDATE FACTURAASIGNACION
                     SET FCUSUUMBRAL05 =
                            PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                      WHERE IDGASTOMAIN = pnCaso AND FCQUEUMBRAL > 0;

                     INSERT INTO FACTURACIONAUT
                       VALUES (pnCaso,
                               vdEmailPgo,
                               6,
                               consecutivo,
                               regUmbral.FCCREDITOCARTERA,
                               SYSDATE,
                               NULL,
                               quienSolic,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               psIdTask,
                               psDelindex,
                               NULL,
                               NULL);
                        consecutivo := consecutivo + 1;
                  END IF;

               ELSE
                  vdEmailPgo := NULL;
               END IF;

            END LOOP;
         END IF;

         -- FIN UMBRALES

      END LOOP;

      --- VERIFICA QUE NO EXISTAN DATOS DE AUTORIZADORES ERRONEOS
      SELECT COUNT (1)
        INTO hayError
        FROM FACTURACIONAUT
       WHERE IDGASTOMAIN = pnCaso AND FCAUTORIZADOR = '**ERROR**';

      IF (hayError > 0)
      THEN
         cualEsElError := '*ERROR* Hay Info Erronea en Autorizadores';
      --      ROLLBACK;
      ELSE
         cualEsElError := '0';
      END IF;

      ---  actualiza con el numero de empleado
      UPDATE FACTURACIONAUT XX
         SET FCUSUARIOAUTORIZA =
                (SELECT "cvetra"
                   FROM PENDUPM.VISTAASOCIADOS A
                  WHERE "email" = XX.FCAUTORIZADOR AND "status" = 'A')
       WHERE IDGASTOMAIN = pnCaso;

      DBMS_OUTPUT.PUT_LINE ('** TERMINO ANTES BITACORA ' || cualEsElError);

      ---- INSERTA EL DETALLE DE LA TRANSACCION
      SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

      INSERT INTO BITACORATRANSACCION
           VALUES (pnCaso,
                   queelemento,
                   psCadenaEjecuta,
                   SYSDATE,
                   SYSDATE,
                   cualEsElError);

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         vsError := SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('** ERROR ** ' || SQLERRM);
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

         INSERT INTO BITACORATRANSACCION
              VALUES (pnCaso,
                      queelemento,
                      psCadenaEjecuta,
                      SYSDATE,
                      SYSDATE,
                      psErrorD);

         COMMIT;
   END setAutAdicionales;

   PROCEDURE getChequeCatalogo (salida IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;
   BEGIN
      OPEN procesa FOR
           SELECT IDCATGASTO, NMDESCRIPCION
             FROM CTCATALOGOGASTOS
            WHERE IDCATGASTO IN (37, 38, 39)
         ORDER BY NMDESCRIPCION DESC;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getChequeCatalogo;

   PROCEDURE getChequesAnticipo (queCheque          INTEGER DEFAULT 0,
                                 salida      IN OUT T_CURSOR,
                                 pnEmpFact          INTEGER)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;                        /*  600Castelo600  aislas  */
   BEGIN
      OPEN procesa FOR
      SELECT *
        FROM (
            SELECT  GASTO,CONCEPTO,
                    QUIESES,        AQUIEN,
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'AN'
                         WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '656925561529384c6847c88021053266' THEN 'RE'
                         WHEN TPOMOVIMIENTO = 'Reembolso' AND ETAPA = '656925561529384c6847c88021053266' THEN 'RE'
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'AN'
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '656925561529384c6847c88021053266' THEN 'RE'
                    END TIPOMOVTO,
                    NMPROVEEDOR,
                    (SELECT "nombreCompleto"
                                     FROM PENDUPM.VISTAASOCIADOS
                                    WHERE "cvetra" = FNNUMEMPLEADO
                    ) SOLICITANTE,
                   (SELECT "status"
                     FROM PENDUPM.VISTAASOCIADOS
                    WHERE "cvetra" = FNNUMEMPLEADO
                   ) STATUSEMP,
                    TOTAL,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN 'Subtotal $'||PCKCONVENIOS.formatComas(FNIMPORTEANTICIPO)||'<BR/>'||
                                                                              'Comision $'||PCKCONVENIOS.formatComas(COMISION)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN 'Subtotal $'||PCKCONVENIOS.formatComas(FNIMPORTEREEMBOLSO)||'<BR/>'||
                                                                              'Comision $'||PCKCONVENIOS.formatComas(COMISION)
                    END DETMONTO,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (FNIMPORTEANTICIPO+COMISION)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (FNIMPORTEREEMBOLSO+COMISION)
                    END ANTICIPO,
                    URGENCIA,
                    ' <B>'||
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'Anticipo'
                         WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '656925561529384c6847c88021053266' THEN 'Reembolso'
                         WHEN TPOMOVIMIENTO = 'Reembolso' AND ETAPA = '656925561529384c6847c88021053266' THEN 'Reembolso'
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'Tramite-Anticipo'
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '656925561529384c6847c88021053266' THEN 'Tramite-Reembolso'
                    END||' </B>' ||
                    (SELECT NMEMPRESA
                       FROM EMPRESAFACTURACION D
                      WHERE D.IDEMPRESA = EMPRESA
                    ) EMPFACT,
                    COMISION COMISIONCHEQUE,
                    TPOCUENTA,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END   FECPAGO   ,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT FDFECPARAPAGO FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT FDFECPARAPAGO FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END PARAORDEN, 
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN REFERENCIA
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN REFERENCIAPGO
                    END REFERENCIA
              FROM (
                   SELECT DISTINCT
                          IDGASTOMAIN GASTO,
                          PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN) CONCEPTO,
                          IDPROVEEDORDEPOSITO QUIESES,
                          FCASIGNADEPOSITO AQUIEN,
                          TPOMOVIMIENTO,
                          (SELECT NMPROVEEDOR FROM CTPROVEEDORGASTO F WHERE F.IDPROVEEDORGTO = A.IDPROVEEDORDEPOSITO )||
                          CASE WHEN IDFORMAPAGO = 38 THEN '<BR/>A nombre de : '||FCNMPAGOCHQCAJA END NMPROVEEDOR,
                          FNNUMEMPLEADO,
                          FNIMPORTESOLICITADO TOTAL,
                         (SELECT IDTASKGASTO
                            FROM FACTURACIONBITACORA XX
                           WHERE XX.IDGASTOMAIN = A.IDGASTOMAIN
                             AND xx.DEL_INDEX = (SELECT MAX(DEL_INDEX)
                                                   FROM FACTURACIONBITACORA DD
                                                  WHERE XX.IDGASTOMAIN = DD.IDGASTOMAIN
                                                )
                          ) ETAPA,
                          FNIMPORTEREEMBOLSO,
                          FNIMPORTEANTICIPO,
                          FCSEVERIDADGASTO,
                          CASE WHEN IDEMPRESAFACTURACION = 0 THEN IDOTEMPRESAFACTURACION ELSE IDEMPRESAFACTURACION END EMPRESA,
                          (SELECT (FCVALOR+FCVALOR1) FROM CTCATALOGOGASTOS F WHERE F.IDCATGASTO= A.IDFORMAPAGO) COMISION,
                          CASE WHEN FCTIPOCUENTA = '1' THEN 'Fiscal' ELSE 'No Fiscal' END  TPOCUENTA,
                          CASE
                             WHEN FCSEVERIDADGASTO NOT IN ('Normal', 'Urgente')
                             THEN
                                PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA)
                             ELSE
                                FCSEVERIDADGASTO
                          END URGENCIA,
                          (SELECT FCREFERDYN  FROM FACTURACIONPAGOS DD WHERE  DD.IDGASTOMAIN = A.IDGASTOMAIN AND FNCONSEC = 2) REFERENCIA,
                           (SELECT FCREFERDYN  FROM FACTURACIONPAGOS DD WHERE  DD.IDGASTOMAIN = A.IDGASTOMAIN AND FNCONSEC = 6) REFERENCIAPGO
                     FROM FACTURACIONMAIN A
                    WHERE IDFORMAPAGO = queCheque AND FCSTATUS NOT IN('F', 'Z')
                      AND IDGASTOMAIN IN (SELECT ZZ.IDGASTOMAIN
                                            FROM FACTURACIONBITACORA ZZ
                                      INNER JOIN (SELECT IDGASTOMAIN,
                                                         MAX (DEL_INDEX) DONDEESTA
                                                    FROM FACTURACIONBITACORA
                                                GROUP BY IDGASTOMAIN
                                                 ) CC ON ( ZZ.IDGASTOMAIN = CC.IDGASTOMAIN AND DEL_INDEX = DONDEESTA)
                                           WHERE IDTASKGASTO IN ('2082181485273e6002e4959086601056','656925561529384c6847c88021053266')
                                          )
                      AND IDGASTOMAIN IN (SELECT IDGASTOMAIN
                                            FROM FACTURACIONPAGOS
                                           WHERE     FNCONSEC IN (2, 6)
                                                 AND FDFECPAGADO IS NULL)
                       AND CASE
                              WHEN IDEMPRESAFACTURACION = 0 THEN A.IDOTEMPRESAFACTURACION
                              WHEN (IDEMPRESAFACTURACION != 0 OR IDEMPRESAFACTURACION IS NOT NULL) THEN A.IDEMPRESAFACTURACION
                              END = pnEmpFact
                 ) PASO
           ) TODOJUNTO
         ORDER BY PARAORDEN ASC;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getChequesAnticipo;

   PROCEDURE setAplicaTesoreria (
      arrDetalle       PCKFACTURACIONGASTO.TABGTOTESORERIA,
      psQueEtapa       VARCHAR2,    /* [AN] ANTICIPO   [RE]  REEMBOLOS/PAGO */
      pstipoPago       INTEGER, /* [37-38-39] CHEQUE    [36]  TRANSFERENCIA  [40]  SERVICIOS */
      usuSolic         VARCHAR2,
      psError      OUT VARCHAR2)
   IS
      ubica                     INTEGER := 0;
      ubica1                    INTEGER := 0;
      ubica2                    INTEGER := 0;
      ubica3                    INTEGER := 0;
      ubica4                    INTEGER := 0;
      ubica5                    INTEGER := 0;
      ubica6                    INTEGER := 0;
      ubica7                    INTEGER := 0;
      ubica8                    INTEGER := 0;
      ubica9                    INTEGER := 0;
      valor                     VARCHAR2 (20) := '';
      valor1                    VARCHAR2 (20) := '';
      valor2                    VARCHAR2 (20) := '';
      valor3                    VARCHAR2 (20) := '';
      valor4                    VARCHAR2 (20) := '';
      valor5                    VARCHAR2 (20) := '';
      valor6                    VARCHAR2 (20) := '';
      valor7                    VARCHAR2 (20) := '';
      valor8                    VARCHAR2 (20) := '';
      valor9                    VARCHAR2 (20) := '';
      cadena                    VARCHAR2 (4000) := psQueEtapa;
      cadena1                   VARCHAR2 (4000) := psQueEtapa;
      cadena2                   VARCHAR2 (4000) := psQueEtapa;
      cadena3                   VARCHAR2 (4000) := psQueEtapa;
      cadena4                   VARCHAR2 (4000) := psQueEtapa;
      cadena5                   VARCHAR2 (4000) := psQueEtapa;
      cadena6                   VARCHAR2 (4000) := psQueEtapa;
      cadena7                   VARCHAR2 (4000) := psQueEtapa;
      cadena8                   VARCHAR2 (4000) := psQueEtapa;
      detGastos                 VARCHAR2 (4000) := psQueEtapa;
      erroneo                   VARCHAR2 (4000) := '';
      existe                    INTEGER := 0;
      queCorreo                 INTEGER := 0;
      archControl               INTEGER := 0;
      impComision               NUMBER (10, 2) := 0;
      impIvaComision            NUMBER (10, 2) := 0;
      vsNmProv                  VARCHAR2 (250) := '';

      vnConsec                  INTEGER := 0;
      vnOrden                   INTEGER := 1;
      vsCadenaArch              VARCHAR2 (400) := NULL;
      vsImporte                 VARCHAR2 (15) := NULL;
      vsRFCEmpleado             VARCHAR2 (20) := NULL;
      vsNomEmpleado             VARCHAR2 (40) := NULL;
      vsRefPago                 VARCHAR2 (16) := NULL;
      vsRefTemp                 VARCHAR2 (99) := NULL;
      vsCtaDeposito             VARCHAR2 (20) := NULL;
      csBcoReceptor             VARCHAR2 (4) := '0012';
      vnImporteTotal            NUMERIC (18, 2) := 0;
      montoEmpleado             NUMERIC (18, 2) := 0;
      impVerifica               NUMERIC (18, 2) := 0;
      vnTotaltas                INTEGER := 0;
      vnImporteAltas            NUMERIC (18, 2) := 0;
      vnTotalBajas              INTEGER := 0;
      vnImporteBajas            NUMERIC (18, 2) := 0;
      empTemporal               VARCHAR2 (10) := '';
      cnChkSize        CONSTANT SMALLINT := 370;
      csFechaArchivo   CONSTANT VARCHAR2 (8)
         :=    TO_CHAR (SYSDATE, 'YYYY')
            || TO_CHAR (SYSDATE, 'MM')
            || TO_CHAR (SYSDATE, 'DD') ;
      csMoneda         CONSTANT CHAR (2) := '00';
      cscTAcARGO       CONSTANT VARCHAR2 (11) := '00105059011';
      csRefEmpresa     CONSTANT VARCHAR2 (10)
         := LPAD (
                  TO_CHAR (SYSDATE, 'YYYY')
               || TO_CHAR (SYSDATE, 'MM')
               || TO_CHAR (SYSDATE, 'DD'),
               10,
               '0') ;
      csServConc       CONSTANT VARCHAR2 (2) := '03';
      csRFC            CONSTANT CHAR (13) := '            ';
      csPlzaPago       CONSTANT CHAR (5) := '00000';
      csSucPago        CONSTANT CHAR (5) := '00000';
      csPais           CONSTANT CHAR (5) := '00000';
      csCiudadEstado   CONSTANT CHAR (40) := '';
      cnTpoCuenta      CONSTANT SMALLINT := 9;
      csBcoEmisor      CONSTANT CHAR (3) := '044';
      csDiasVig        CONSTANT CHAR (3) := '001';
      csConceptoPgo    CONSTANT CHAR (50) := '';
      csusoEmp01       CONSTANT CHAR (20) := '';
      csusoEmp02       CONSTANT CHAR (20) := '';
      csusoEmp03       CONSTANT CHAR (20) := '';
      csFiller25       CONSTANT CHAR (25) := LPAD ('0', 25, '0');
      csFiller22       CONSTANT CHAR (22) := LPAD (' ', 22, ' ');
      csFiller195      CONSTANT CHAR (195) := LPAD ('0', 195, '0');
      csFiller123      CONSTANT CHAR (123) := LPAD (' ', 123, ' ');
      csFiller120      CONSTANT CHAR (120) := LPAD (' ', 120, ' ');
      csFiller198      CONSTANT CHAR (198) := LPAD ('0', 195, '0');
      vnConsecutivo             INTEGER := 0;
      vsTpomovto                VARCHAR2 (10) := '';
      vsclobDoby                CLOB := EMPTY_CLOB;
      queUsuEs                  VARCHAR2 (50) := '';
      NMSOLIC                   VARCHAR2 (400) := '';
      NMCORREO                  VARCHAR2 (400) := '';
      SOLICCORREO               VARCHAR2 (400) := '';
      quienEsSol                INTEGER := 0;
      quePaso                   VARCHAR2 (1000) := 0;
      sbCuentaEmpFact           VARCHAR2(20) := '';
      CtaBancoEmpFact           VARCHAR2(40) := '';
      vnNumeroConsecEmp         INTEGER := 0;
      emailUsuApicaEs           VARCHAR2(50) := '';

      CURSOR cuDetalle (
         idGasto    NUMBER)
      IS
         SELECT *
           FROM FACTURACIONMAIN A, FACTURACIONPAGOS B
          WHERE     A.IDGASTOMAIN = idGasto
                AND A.IDGASTOMAIN = B.IDGASTOMAIN
                AND FNCONSEC IN (2, 6)
                AND (A.IDGASTOMAIN, A.FDFECREGISTRO) IN (  SELECT IDGASTOMAIN,
                                                                  MIN (
                                                                     FDFECREGISTRO)
                                                             FROM FACTURACIONMAIN H
                                                         GROUP BY IDGASTOMAIN);

      CURSOR cuAgrpPago (folCOntrol INTEGER)
      IS
           SELECT IDPROVEEDORGTO,
                  FCNUMCTADEPOSITO FCCUENTADEPOSITO,
                  SUM (FNIMPORTEDEPOSITO) * 1.00 IMPTOTAL,
                  COUNT (1) TOTGASTOS
             FROM FACTURACIONDEPOSITO
            WHERE FNNUMARCHCONTROL = folCOntrol
              AND FCSTATUS = 'A'
         GROUP BY IDPROVEEDORGTO, FCNUMCTADEPOSITO;

      CURSOR cuDetDeposito (folControl    INTEGER,
                            psDyn         VARCHAR2,
                            psCta         VARCHAR2)
      IS
           SELECT DISTINCT IDPROVEEDORGTO,
                           FCBANCO,
                           FCRFC,
                           FCNOMBRE,
                           FCREFERENCIA,
                           FCNUMCTADEPOSITO FCCUENTADEPOSITO
             FROM FACTURACIONDEPOSITO
            WHERE FNNUMARCHCONTROL = folCOntrol
              AND FCNUMCTADEPOSITO = psCta
              AND IDPROVEEDORGTO = psDyn
              AND FCSTATUS = 'A'
         ORDER BY IDPROVEEDORGTO, FCNUMCTADEPOSITO;
   BEGIN
      ---- Recupera el Numero de Archivo de Control Aplicado
      SELECT SEQCTRLDEPOSITO.NEXTVAL INTO archControl FROM DUAL;

      SELECT "nombreCompleto", "email"
        INTO NMSOLIC, NMCORREO
        FROM PENDUPM.VISTAASOCIADOS A
       WHERE "cvetra" = usuSolic;

       --- colocar elemail en bitacoratransaccion
       emailUsuApicaEs := NMCORREO;

      DBMS_OUTPUT.PUT_LINE ( 'quien solic  ....' || usuSolic || ' ES EL NUM  ....');
      psError := '0';

      FOR i IN 1 .. arrDetalle.COUNT
      LOOP

        --************************************************************
        --**** AJUSTE PARA DETALLE DE LO DE CUENTAS DE LA EMPRESA Y
        --**** LO DE LOS IMPORTES DE LA COMISION
        --****************************************************************

         SELECT FCVALOR, FCVALOR1
           INTO impComision, impIvaComision
           FROM CTCATALOGOGASTOS WHERE IDCATGASTO = pstipoPago;

                DBMS_OUTPUT.PUT_LINE ( '** tipo de pago '||pstipoPago);

         BEGIN
         SELECT FCSBCUENTA, FCCUENTA, IDCONSEC
           INTO sbCuentaEmpFact,CtaBancoEmpFact, vnNumeroConsecEmp
           FROM EMPFACTURADETALLE
          WHERE IDEMPRESA = arrDetalle (i).rEmpFactura AND FCCUENTA = arrDetalle (i).rQueCuenta;
        EXCEPTION WHEN OTHERS THEN
           sbCuentaEmpFact :=NULL;
           CtaBancoEmpFact :=NULL;
           vnNumeroConsecEmp  :=NULL;
        END;

                DBMS_OUTPUT.PUT_LINE ( '** valores de comision y emprsa');

         --  SELECT DISTINCT TPOMOVIMIENTO INTO vsTpomovto FROM FACTURACIONMAIN WHERE IDGASTOMAIN = arrDetalle(i).rIdGasto ;
         SELECT DISTINCT FNNUMEMPLEADO
           INTO quienEsSol
           FROM FACTURACIONMAIN
          WHERE IDGASTOMAIN = arrDetalle (i).rIdGasto;

         SELECT "email"
           INTO SOLICCORREO
           FROM PENDUPM.VISTAASOCIADOSCOMPLETA A
          WHERE "cvetra" = quienEsSol;

         IF (arrDetalle (i).rIdTask = '656925561529384c6847c88021053266')
         THEN
            vsTpomovto := 'RE';
         ELSE
            vsTpomovto := 'AN';
         END IF;

         DBMS_OUTPUT.PUT_LINE (
            'ESTE SI ES  ....' || vsTpomovto || ' ES EL NUM  ....' || i);


         ---- si es Anticipo
         --             IF (vsTpomovto = 'Anticipo' ) THEN
         IF (vsTpomovto = 'AN')
         THEN
            SELECT COUNT (1)
              INTO existe
              FROM FACTURACIONPAGOS
             WHERE IDGASTOMAIN = arrDetalle (i).rIdGasto AND FNCONSEC = 2;

            DBMS_OUTPUT.PUT_LINE ('EISTE ANTOC ....' || existe || vsTpomovto);

            IF (existe > 0)
            THEN

            DBMS_OUTPUT.PUT_LINE ('CORREO ....' || NMCORREO ||'-'|| NMSOLIC||'-'|| arrDetalle (i).rQueRefer||'-'|| arrDetalle (i).rIdGasto||'-'||arrDetalle (i).rIdDelindex );

               IF (   pstipoPago = 37 OR pstipoPago = 38 OR pstipoPago = 39 OR pstipoPago = 40) THEN
                           --*****************************************************************************************************************
                           ----  agrega el Correo a Enviar Y Recupera el ID del Correo AL SOLICITANTE PARA QUE COMPRUEBE EL GASTO ANTICIPO
                           --*****************************************************************************************************************
                           PCKENVIOCORREO.setMailSpeimovto (
                              arrDetalle (i).rIdGasto,
                              '2147619945273e5a68478d0053334276',
                              NMCORREO,
                              NMSOLIC,
                              CASE
                                 WHEN (   pstipoPago = 37
                                       OR pstipoPago = 38
                                       OR pstipoPago = 39)
                                 THEN
                                       'EL CHEQUE ENTREGADO ES  '
                                    || arrDetalle (i).rQueRefer
                                 WHEN (pstipoPago = 36)
                                 THEN
                                    'LA TRANSFERENCIA SPEI FUE REALIZADA'
                                 WHEN (pstipoPago = 40)
                                 THEN
                                    'EL PAGO CIE APLICADO ' || arrDetalle (i).rQueRefer
                              END,
                              CASE
                                 WHEN (   pstipoPago = 37
                                       OR pstipoPago = 38
                                       OR pstipoPago = 39)
                                 THEN
                                    'ENTREGADO'
                                 WHEN (pstipoPago = 36)
                                 THEN
                                    'APLICADO'
                                 WHEN (pstipoPago = 40)
                                 THEN
                                    'APLICADO'
                              END,
                              SOLICCORREO,
                              'DEPOSITO',
                              arrDetalle (i).rIdApp,
                              (arrDetalle (i).rIdDelindex + 1));

                               DBMS_OUTPUT.PUT_LINE ('***AGREGA CORREO**');

                           --- vERIFICA QUE EL GUARDADO DEL CORREO SEA CORRECTO
                           SELECT FCERROR
                             INTO quePaso
                             FROM BITACORATRANSACCION
                            WHERE     IDGASTOMAIN = arrDetalle (i).rIdGasto
                                  AND IDCONSEC =
                                         (SELECT MAX (IDCONSEC)
                                            FROM BITACORATRANSACCION
                                           WHERE IDGASTOMAIN = arrDetalle (i).rIdGasto);

                           queCorreo := quePaso;
                           DBMS_OUTPUT.PUT_LINE ('guarda correo...' || queCorreo);
               ELSE
                  queCorreo := '0';
               END IF;

               ----  PCKENVIOCORREO.TESOCorreoGastos ( arrDetalle(i).rIdGasto,'TESO',arrDetalle(i).rIdTask,arrDetalle(i).rIdDelindex,queCorreo);
               --   DBMS_OUTPUT.PUT_LINE('PREVIO CORREO REEMBOLSO..'||queCorreo||' ... ' ||arrDetalle(i).rIdGasto);
               IF (queCorreo = '0') THEN
                  psError := '0';
                  --  DBMS_OUTPUT.PUT_LINE('inserta  FACTURACIONDEPOSITO 0001');  empresafacturacion
                  DBMS_OUTPUT.PUT_LINE ('INSERTA FACTURACIONDEPOSITO');

                  INSERT INTO FACTURACIONDEPOSITO
                       VALUES (arrDetalle (i).rIdGasto,
                               2,
                               queCorreo,
                               arrDetalle (i).rEmpFactura,
                               pstipoPago,
                               arrDetalle (i).rDepositaA,
                               arrDetalle (i).rQueRefer,
                               arrDetalle (i).rQueCuenta,  /*rDepositaA,*/
                               SYSDATE,
                               arrDetalle (i).rImporte,
                               usuSolic,
                               (impComision+impIvaComision),
                               archControl,
                               arrDetalle (i).rQueBanco,
                               arrDetalle (i).rRfc,
                               arrDetalle (i).rNombre,
                               arrDetalle (i).rDepositaA,
                               arrDetalle (i).rIdApp,
                               arrDetalle (i).rIdTask,
                               arrDetalle (i).rIdDelindex,
                               SYSDATE,
                               'A', SYSDATE, NULL,NULL,impIvaComision,vnNumeroConsecEmp,
                               arrDetalle (i).rCuentaDepo,NULL);

                  --   DBMS_OUTPUT.PUT_LINE('inserta  FACTURACION PAGO ACTUALIZA 0002....'||usuSolic||' .... '||arrDetalle(i).rIdGasto);
                  UPDATE FACTURACIONPAGOS
                     SET FDFECPAGADO = SYSDATE, IDUSUARIO = usuSolic
                   WHERE     IDGASTOMAIN = arrDetalle (i).rIdGasto
                         AND FNCONSEC = 2;

                  --                             DBMS_OUTPUT.PUT_LINE('inserta  FACTURACIONDEPOSITO');

                  -- pstipoPago      INTEGER,  /* [37-38-39] CHEQUE    [36]  TRANSFERENCIA  [40]  SERVICIOS */
                  DBMS_OUTPUT.PUT_LINE (
                     'INSERTA FACTURACIONBITACORA ..' || NMCORREO);

                  UPDATE FACTURACIONBITACORA
                     SET FDFECREGISTRO = SYSDATE,
                         FCUSUARIO = emailUsuApicaEs,
                         FCRESULTADO =
                            CASE
                               WHEN (   pstipoPago = 37
                                     OR pstipoPago = 38
                                     OR pstipoPago = 39)
                               THEN
                                  'ENTREGADO'
                               WHEN (pstipoPago = 36)
                               THEN
                                  'APLICADO'
                               WHEN (pstipoPago = 40)
                               THEN
                                  'APLICADO'
                            END,
                         FCCOMENTARIOS =
                            CASE
                               WHEN (   pstipoPago = 37
                                     OR pstipoPago = 38
                                     OR pstipoPago = 39)
                               THEN
                                     'EL CHEQUE ENTREGADO ES  '
                                  || arrDetalle (i).rQueRefer
                               WHEN (pstipoPago = 36)
                               THEN
                                  'TRANSFERENCIA SPEI REALIZADA FALTA CONFIRMACION'
                               WHEN (pstipoPago = 40)
                               THEN
                                     'EL PAGO CIE APLICADO '
                                  || arrDetalle (i).rQueRefer
                            END,
                         NMETAPA = 'DEPOSITO ANTICIPO / PAGO'
                   WHERE     IDGASTOMAIN = arrDetalle (i).rIdGasto
                         AND APP_UID = arrDetalle (i).rIdApp
                         AND IDTASKGASTO = arrDetalle (i).rIdTask
                         AND DEL_INDEX = arrDetalle (i).rIdDelindex;

                  DBMS_OUTPUT.PUT_LINE (
                     'INSERTA FACTURACIONBITACORA **** ..' || NMCORREO);

                  SELECT FCUSUARIO
                    INTO queUsuEs
                    FROM FACTURACIONBITACORA
                   WHERE IDGASTOMAIN = arrDetalle (i).rIdGasto
                         AND APP_UID = arrDetalle (i).rIdApp
                         AND DEL_INDEX = 1;

                  DBMS_OUTPUT.PUT_LINE (
                     'ANTES TERMINAR INSERT FACTURACIONBITACORA ');

                  IF (   pstipoPago = 37
                      OR pstipoPago = 38
                      OR pstipoPago = 39
                      OR pstipoPago = 40)
                  THEN
                     INSERT INTO FACTURACIONBITACORA
                          VALUES (arrDetalle (i).rIdGasto,
                                  arrDetalle (i).rIdApp,
                                  '2147619945273e5a68478d0053334276',
                                  (arrDetalle (i).rIdDelindex + 1),
                                  'COMPROBACION DEL GASTO',
                                  SYSDATE,
                                  queUsuEs,
                                  NULL,
                                  NULL);
                  END IF;

                  DBMS_OUTPUT.PUT_LINE (
                        'INSERTA FACTURACIONBITACORA **** FACTURACIONBITACORA ..'
                     || emailUsuApicaEs);
               ELSE
                  psError :=
                     '-1 *ERROR CORREO* CHECAR LA TRANSACCION setGuardaCorreo ';
               END IF;
            ELSE
               psError := '-1 *NO EXISTE PARTIDA DE ANTICIPO* ';
               EXIT;
            END IF;
         END IF;

         DBMS_OUTPUT.PUT_LINE ('ANTES REEMBOLSO');

         ---- si es Reembolso / pago
         --             IF (psQueEtapa = 'Reembolso' ) THEN
         IF (vsTpomovto = 'RE')
         THEN
            SELECT COUNT (1)
              INTO existe
              FROM FACTURACIONPAGOS
             WHERE IDGASTOMAIN = arrDetalle (i).rIdGasto AND FNCONSEC = 6;

            SELECT DISTINCT FNNUMEMPLEADO
              INTO quienEsSol
              FROM FACTURACIONMAIN
             WHERE IDGASTOMAIN = arrDetalle (i).rIdGasto;

            SELECT "email"
              INTO SOLICCORREO
              FROM PENDUPM.VISTAASOCIADOSCOMPLETA A
             WHERE "cvetra" = quienEsSol;

            DBMS_OUTPUT.PUT_LINE ('REEMBOLSO ....' || existe || vsTpomovto);

            IF (existe > 0)
            THEN
               queCorreo := 0;
               --*****************************************************************************************************************
               ----  agrega el Correo a Enviar Y Recupera el ID del Correo AL SOLICITANTE PARA QUE COMPRUEBE EL GASTO ANTICIPO
               --*****************************************************************************************************************
               PCKENVIOCORREO.setMailSpeimovto (
                  arrDetalle (i).rIdGasto,
                  '656925561529384c6847c88021053266',
                  NMCORREO,
                  NMSOLIC,
                  CASE
                     WHEN (   pstipoPago = 37
                           OR pstipoPago = 38
                           OR pstipoPago = 39)
                     THEN
                           'EL CHEQUE ENTREGADO ES  '
                        || arrDetalle (i).rQueRefer
                     WHEN (pstipoPago = 36)
                     THEN
                        'TRANSFERENCIA SPEI REALIZADA FALTA CONFIRMACION'
                     WHEN (pstipoPago = 40)
                     THEN
                        'EL PAGO CIE APLICADO ' || arrDetalle (i).rQueRefer
                  END,
                  CASE
                     WHEN (   pstipoPago = 37
                           OR pstipoPago = 38
                           OR pstipoPago = 39)
                     THEN
                        'ENTREGADO'
                     WHEN (pstipoPago = 36)
                     THEN
                        'APLICADO'
                     WHEN (pstipoPago = 40)
                     THEN
                        'APLICADO'
                  END,
                  SOLICCORREO,
                  'PAGOS / REEMBOLSO',
                  arrDetalle (i).rIdApp,
                  (arrDetalle (i).rIdDelindex));

               --- vERIFICA QUE EL GUARDADO DEL CORREO SEA CORRECTO
               SELECT FCERROR
                 INTO quePaso
                 FROM BITACORATRANSACCION
                WHERE     IDGASTOMAIN = arrDetalle (i).rIdGasto
                      AND IDCONSEC =
                             (SELECT MAX (IDCONSEC)
                                FROM BITACORATRANSACCION
                               WHERE IDGASTOMAIN = arrDetalle (i).rIdGasto);

               queCorreo := quePaso;

               --  agrega el Correo a Enviar Y Recupera el ID del Correo
               --  PCKENVIOCORREO.TESOCorreoGastos ( arrDetalle(i).rIdGasto,'TESO',arrDetalle(i).rIdTask,arrDetalle(i).rIdDelindex,queCorreo);
               DBMS_OUTPUT.PUT_LINE (
                     'PREVIO CORREO REEMBOLSO..'
                  || queCorreo
                  || ' ... '
                  || arrDetalle (i).rIdGasto);

               IF (queCorreo = '0')
               THEN
                  psError := '0';

                 BEGIN
                  INSERT INTO FACTURACIONDEPOSITO
                       VALUES (arrDetalle (i).rIdGasto,
                               6,
                               queCorreo,
                               arrDetalle (i).rEmpFactura,
                               pstipoPago,
                               arrDetalle (i).rDepositaA,
                               arrDetalle (i).rQueRefer,
                               arrDetalle (i).rQueCuenta,  /*rDepositaA,*/
                               SYSDATE,
                               arrDetalle (i).rImporte,
                               usuSolic,
                               (impComision+impIvaComision),
                               archControl,
                               arrDetalle (i).rQueBanco,
                               arrDetalle (i).rRfc,
                               arrDetalle (i).rNombre,
                               arrDetalle (i).rDepositaA,
                               arrDetalle (i).rIdApp,
                               arrDetalle (i).rIdTask,
                               arrDetalle (i).rIdDelindex,
                               SYSDATE,
                               'A', SYSDATE, NULL,NULL, impIvaComision,vnNumeroConsecEmp,
                               arrDetalle (i).rCuentaDepo,NULL);
                   EXCEPTION WHEN OTHERS THEN
                      NULL;
                   END;

                  UPDATE FACTURACIONPAGOS
                     SET FDFECPAGADO = SYSDATE, IDUSUARIO = usuSolic
                   WHERE     IDGASTOMAIN = arrDetalle (i).rIdGasto
                         AND FNCONSEC = 6;

                  UPDATE FACTURACIONBITACORA
                     SET FDFECREGISTRO = SYSDATE,
                         FCUSUARIO = emailUsuApicaEs,
                         FCRESULTADO =
                            CASE
                               WHEN (   pstipoPago = 37
                                     OR pstipoPago = 38
                                     OR pstipoPago = 39)
                               THEN
                                  'ENTREGADO'
                               WHEN (pstipoPago = 36)
                               THEN
                                  'APLICADO'
                               WHEN (pstipoPago = 40)
                               THEN
                                  'APLICADO'
                            END,
                         FCCOMENTARIOS =
                            CASE
                               WHEN (   pstipoPago = 37
                                     OR pstipoPago = 38
                                     OR pstipoPago = 39)
                               THEN
                                     'EL CHEQUE ENTREGADO ES  '
                                  || arrDetalle (i).rQueRefer
                               WHEN (pstipoPago = 36)
                               THEN
                                  'TRANSFERENCIA SPEI REALIZADA FALTA CONFIRMACION'
                               WHEN (pstipoPago = 40)
                               THEN
                                     'EL PAGO CIE APLICADO '
                                  || arrDetalle (i).rQueRefer
                            END,
                         NMETAPA = 'PAGOS / REEMBOLSO'
                   WHERE     IDGASTOMAIN = arrDetalle (i).rIdGasto
                         AND APP_UID = arrDetalle (i).rIdApp
                         AND IDTASKGASTO = arrDetalle (i).rIdTask
                         AND DEL_INDEX = arrDetalle (i).rIdDelindex;

                  SELECT FCUSUARIO
                    INTO queUsuEs
                    FROM FACTURACIONBITACORA
                   WHERE     IDGASTOMAIN = arrDetalle (i).rIdGasto
                         AND APP_UID = arrDetalle (i).rIdApp
                         AND DEL_INDEX = 1;
               --                           IF (pstipoPago = 37 OR pstipoPago = 38 OR pstipoPago = 39 OR pstipoPago = 40) THEN
               --
               --                                 INSERT INTO FACTURACIONBITACORA VALUES (arrDetalle(i).rIdGasto, arrDetalle(i).rIdApp, '2147619945273e5a68478d0053334276',
               --                                                                        (arrDetalle(i).rIdDelindex+1),'COMPROBACION DEL GASTO',SYSDATE,queUsuEs,NULL,NULL );
               --                           END IF;

               ELSE
                  psError :=
                     '-1 *ERROR CORREO* CHECAR LA TRANSACCION setGuardaCorreo ';
               END IF;
            ELSE
               psError := '-1 *NO EXISTE PARTIDA DE REEMBOLSO* ';
               EXIT;
            END IF;
         END IF;

         DBMS_OUTPUT.PUT_LINE ('ANTES DE FACTURACIONMAIN');

         ---- ACTUALIZA FACTURACIONMAIN
         UPDATE FACTURACIONMAIN MAIN
            SET FCSTATUS =
                   CASE
                      WHEN vsTpomovto = 'RE' THEN 'F'
                      ELSE CASE WHEN IDFORMAPAGO = 36 THEN 'DP' ELSE 'DC' END
                   END,
                FDFECTERMINO =
                   CASE WHEN vsTpomovto = 'RE' THEN SYSDATE ELSE NULL END,
                FDDYNAMICSREEMB =
                   CASE WHEN vsTpomovto = 'RE' THEN SYSDATE ELSE NULL END,
                FDDYNAMICSREEMBCONF =
                   CASE WHEN vsTpomovto = 'RE' THEN SYSDATE ELSE NULL END,
                FDDYNAMICSGASTOCONF =
                   CASE WHEN IDFORMAPAGO = 36 THEN NULL ELSE SYSDATE END,
                FDDYNAMICSGASTO =
                   CASE WHEN vsTpomovto = 'AN' THEN SYSDATE ELSE NULL END
          WHERE IDGASTOMAIN = arrDetalle (i).rIdGasto;

         DBMS_OUTPUT.PUT_LINE (
            'actualiza  FACTURACIONMAIN ..' || arrDetalle (i).rIdGasto);
      END LOOP;

      DBMS_OUTPUT.PUT_LINE ('sale loop...' || psError);

      IF (psError = '0')
      THEN
         psError := archControl;
         /* *****  GUARDA INFORMACION DEL ARCHIVO DE DEPOSITO O PAGOS/REEMBOLSO */
         --          IF ( psQueEtapa = 'AN' OR psQueEtapa = 'RE' ) THEN
         DBMS_OUTPUT.PUT_LINE ('***ENTRO A CREACION DEL ARCHIVO *****');

         --- OBTIENE EL CONSECUTIVO DEL ARCHIVO GENERADO
         --        SELECT SEQSPEIGASTO.NEXTVAL INTO vnConsec FROM DUAL;
         SELECT NVL (MAX (FNCONSEC), 0) + 1
           INTO vnConsec
           FROM FACTSPEIBANCO
          WHERE FCFECGENCTRL = csFechaArchivo;

           DBMS_OUTPUT.PUT_LINE ('***valores empresa facturacion *****'||sbCuentaEmpFact||'-'||CtaBancoEmpFact);
         --- ARMA DETALLE DEL REGISTRO  -  PARTE  01
         vsCadenaArch :=
               'EE'
            || 'HA'
            || sbCuentaEmpFact
            || LPAD (vnConsec, 2, '0')
            || '000000000000000000000000000'
            || RPAD (' ', 332, ' ');

         INSERT INTO FACTSPEIBANCO
              VALUES (archControl,
                      psQueEtapa,
                      csFechaArchivo,
                      vnConsec,
                      vsCadenaArch,
                      SYSDATE,
                      vnOrden,
                      usuSolic);

         vnOrden := vnOrden + 1;
         --- ARMA DETALLE DEL REGISTRO  -  PARTE  02
         vsCadenaArch :=
               'EE'
            || 'HB'
            || csMoneda
            || '0000'
            || LPAD(CtaBancoEmpFact,11,'0')
            || csRefEmpresa
            || '000'
            || RPAD (' ', 236, ' ');

         INSERT INTO FACTSPEIBANCO
              VALUES (archControl,
                      psQueEtapa,
                      csFechaArchivo,
                      vnConsec,
                      vsCadenaArch,
                      SYSDATE,
                      vnOrden,
                      usuSolic);

         vnOrden := vnOrden + 1;
         vsCadenaArch := '';

         --- Obtiene el Detalle del Registro unico a Generar
         FOR regAnticipo IN cuAgrpPago (archControl)
         LOOP
            DBMS_OUTPUT.PUT_LINE (
                  '** AGRUPA cuAgrpPago ...'
               || archControl
               || '-'
               || regAnticipo.IDPROVEEDORGTO
               || '-'
               || regAnticipo.FCCUENTADEPOSITO);

               vnTotaltas := vnTotaltas + 1;

            FOR regDetalle
               IN cuDetDeposito (archControl,
                                 regAnticipo.IDPROVEEDORGTO,
                                 regAnticipo.FCCUENTADEPOSITO)
            LOOP
               DBMS_OUTPUT.PUT_LINE ('** AGRUPA cuDetDeposito ...');

               vsNmProv := SUBSTR (regAnticipo.IDPROVEEDORGTO, 2);
              DBMS_OUTPUT.PUT_LINE ('** AGRUPA cuDetDeposito es vsRefPago...');
               vsRefPago := LPAD (vsNmProv, 8, '0');
               vsRefPago := vsRefPago || LPAD (vnConsec, 5, '0');
               vsRefPago := vsRefPago || LPAD (regAnticipo.TOTGASTOS, 3, '0');



               vsImporte :=
                  LPAD (
                        TO_CHAR (FLOOR (regAnticipo.IMPTOTAL))
                     || LPAD (
                           TO_CHAR (
                                (  regAnticipo.IMPTOTAL
                                 - FLOOR (regAnticipo.IMPTOTAL))
                              * 100),
                           2,
                           '0'),
                     15,
                     '0');
               DBMS_OUTPUT.PUT_LINE (
                  '** AGRUPA cuDetDeposito es vsImporte...'||regDetalle.FCBANCO);
               csBcoReceptor := TRIM (regDetalle.FCBANCO);
               DBMS_OUTPUT.PUT_LINE ('** AGRUPA cuDetDeposito es csBcoReceptor...');
               vsCtaDeposito :=
                  LPAD (TRIM (regAnticipo.FCCUENTADEPOSITO), 20, '0');
               DBMS_OUTPUT.PUT_LINE (
                  '** AGRUPA cuDetDeposito es vsCtaDeposito...');
               vsNomEmpleado := RPAD (TRIM (regDetalle.FCNOMBRE), 40, ' ');
               DBMS_OUTPUT.PUT_LINE (
                  '** AGRUPA cuDetDeposito es vsNomEmpleado...');
               vsRFCEmpleado := RPAD (TRIM (regDetalle.FCRFC), 20, ' ');
               DBMS_OUTPUT.PUT_LINE (
                  '** AGRUPA cuDetDeposito es vsRFCEmpleado...');

               DBMS_OUTPUT.PUT_LINE (
                  '** AGRUPA cuDetDeposito SON VARIABLES...');

               vsCadenaArch :=
                     'EE'
                  || 'DA'
                  || '04'
                  || csMoneda
                  || vsImporte
                  || csFechaArchivo
                  || csServConc
                  || vsRFCEmpleado
                  || csRFC
                  || SUBSTR (vsNomEmpleado, 1, 40)
                  || vsRefPago
                  || LPAD (csPlzaPago, 5, '0')
                  || LPAD (csSucPago, 5, '0')
                  || LPAD (vsCtaDeposito, 20, '0')
                  || csPais
                  || LPAD (csCiudadEstado, 40, ' ')
                  || cnTpoCuenta
                  || ' 00000'
                  || csBcoEmisor
                  || SUBSTR (csBcoReceptor, 2)
                  || csDiasVig
                  || csConceptoPgo
                  || csusoEmp01
                  || csusoEmp02
                  || csusoEmp03
                  || csFiller25
                  || csFiller22;
               DBMS_OUTPUT.put_line (
                  ' es la cadena de guardar ....' || vsCadenaArch);

               INSERT INTO FACTSPEIBANCO
                    VALUES (archControl,
                            psQueEtapa,
                            csFechaArchivo,
                            vnConsec,
                            vsCadenaArch,
                            SYSDATE,
                            vnOrden,
                            usuSolic);

               DBMS_OUTPUT.put_line (
                  ' ***inserta en FACTSPEIBANCO ....' || vsCadenaArch);
            END LOOP;

            vnImporteTotal := vnImporteTotal + regAnticipo.IMPTOTAL;
            montoEmpleado := montoEmpleado + regAnticipo.IMPTOTAL;
         END LOOP;

         vnImporteAltas := vnImporteTotal;
         vnOrden := vnOrden + 1;
         --- ARMA DETALLE DEL REGISTRO  -  PARTE  04
         vsCadenaArch :=
               'EE'
            || 'TB'
            || LPAD (vnTotaltas, 7, '0')
            || LPAD (
                     TO_CHAR (FLOOR (vnImporteAltas))
                  || LPAD (
                        TO_CHAR (
                           (vnImporteAltas - FLOOR (vnImporteAltas)) * 100),
                        2,
                        '0'),
                  17,
                  '0')
            || LPAD (vnTotalBajas, 7, '0')
            || LPAD (
                     TO_CHAR (FLOOR (vnImporteBajas))
                  || LPAD (
                        TO_CHAR (
                           (vnImporteBajas - FLOOR (vnImporteBajas)) * 100),
                        2,
                        '0'),
                  17,
                  '0')
            || csFiller195
            || csFiller120;

         INSERT INTO FACTSPEIBANCO
              VALUES (archControl,
                      psQueEtapa,
                      csFechaArchivo,
                      vnConsec,
                      vsCadenaArch,
                      SYSDATE,
                      vnOrden,
                      usuSolic);

         vnOrden := vnOrden + 1;
         --- ARMA DETALLE DEL REGISTRO  -  PARTE  05
         vsCadenaArch :=
               'EE'
            || 'TA'
            || LPAD (vnTotaltas, 7, '0')
            || LPAD (
                     TO_CHAR (FLOOR (vnImporteAltas))
                  || LPAD (
                        TO_CHAR (
                           (vnImporteAltas - FLOOR (vnImporteAltas)) * 100),
                        2,
                        '0'),
                  17,
                  '0')
            || LPAD (vnTotalBajas, 7, '0')
            || LPAD (
                     TO_CHAR (FLOOR (vnImporteBajas))
                  || LPAD (
                        TO_CHAR (
                           (vnImporteBajas - FLOOR (vnImporteBajas)) * 100),
                        2,
                        '0'),
                  17,
                  '0')
            || csFiller198
            || csFiller120;

         INSERT INTO FACTSPEIBANCO
              VALUES (archControl,
                      psQueEtapa,
                      csFechaArchivo,
                      vnConsec,
                      vsCadenaArch,
                      SYSDATE,
                      vnOrden,
                      usuSolic);

         --        END IF;  /* -- Aplica solo para Anticipo y reembolso */

         IF (vsTpomovto = 'RE')
         THEN
            SELECT SUM (FNIMPORTEDEPOSITO) * 1.00 IMPTOTAL
              INTO impVerifica
              FROM FACTURACIONDEPOSITO
             WHERE FNCONSEC = archControl AND FNCONSEC = 6
               AND FCSTATUS = 'A';
         ELSE
            SELECT SUM (FNIMPORTEDEPOSITO) * 1.00 IMPTOTAL
              INTO impVerifica
              FROM FACTURACIONDEPOSITO
             WHERE FNCONSEC = archControl AND FNCONSEC = 2
               AND FCSTATUS = 'A';
         END IF;

         IF (vnImporteAltas != impVerifica)
         THEN
            ROLLBACK;
            psError :=
                  '-1 ERROR NO CUADRAN LOS IMPORTES .. '
               || TO_CHAR (vnImporteAltas)
               || ' Y '
               || TO_CHAR (impVerifica);
         ELSE
            COMMIT;
         END IF;
      ELSE
         ROLLBACK;
      END IF;                              /* -- verifica la Variable ERROR */

       DBMS_OUTPUT.put_line ('al final es ****'||psError);
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         erroneo := SQLERRM;
         psError := '-1 ' || erroneo;
         DBMS_OUTPUT.PUT_LINE ('valor -->' || erroneo);
   END setAplicaTesoreria;

   PROCEDURE getDerivaCasos (pnControl INTEGER, salida IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;
   BEGIN
      OPEN procesa FOR
           SELECT IDGASTOMAIN, IDTASK, IDDELINDEX
             FROM FACTURACIONDEPOSITO
            WHERE FNNUMARCHCONTROL = pnControl
              AND FCSTATUS = 'A'
         ORDER BY IDGASTOMAIN DESC;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getDerivaCasos;

   PROCEDURE getTransAnticipo (salida IN OUT T_CURSOR, pnEmpFact INTEGER)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;
   BEGIN
      OPEN procesa FOR
      SELECT *
        FROM (
            SELECT  GASTO,CONCEPTO,
                    QUIESES,
                    AQUIEN,
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'AN'
                         WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '656925561529384c6847c88021053266' THEN 'RE'
                         WHEN TPOMOVIMIENTO = 'Reembolso' AND ETAPA = '656925561529384c6847c88021053266' THEN 'RE'
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'AN'
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '656925561529384c6847c88021053266' THEN 'RE'
                    END TIPOMOVTO,
                    NMPROVEEDOR,
                    SOLICITANTE,
                    STATUSEMP,
                    TOTAL,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (FNIMPORTEANTICIPO+COMISION)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN FNIMPORTEREEMBOLSO
                    END ANTICIPO,
                    URGENCIA,
                    ' <B>'||
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'Anticipo'
                         WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '656925561529384c6847c88021053266' THEN 'Reembolso'
                         WHEN TPOMOVIMIENTO = 'Reembolso' AND ETAPA = '656925561529384c6847c88021053266' THEN 'Reembolso'
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'Tramite-Anticipo'
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '656925561529384c6847c88021053266' THEN 'Tramite-Reembolso'
                    END||' </B>' ||
                    (SELECT NMEMPRESA
                       FROM EMPRESAFACTURACION D
                      WHERE D.IDEMPRESA = EMPRESA
                    ) EMPFACT,
                    COMISION COMISIONCHEQUE,
                    TPOCUENTA,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END   FECPAGO   ,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT FDFECPARAPAGO FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT FDFECPARAPAGO FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END PARAORDEN   ,
                    '<B>'||CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT FCREFERDYN  FROM FACTURACIONPAGOS DD WHERE  DD.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT FCREFERDYN  FROM FACTURACIONPAGOS DD WHERE  DD.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END||'</B><BR/>'||
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END  REFERENCIA,
                    CARTERA
              FROM (
                   SELECT IDGASTOMAIN GASTO,
                          PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN) CONCEPTO,
                          IDPROVEEDORDEPOSITO||(select decode ("Status" ,'H','-BAJA')from vendor@erpbase.com where  "VendId" = IDPROVEEDORDEPOSITO ) QUIESES,
                          FCASIGNADEPOSITO AQUIEN,
                          TPOMOVIMIENTO,
                          (SELECT NMPROVEEDOR FROM CTPROVEEDORGASTO F WHERE F.IDPROVEEDORGTO = A.IDPROVEEDORDEPOSITO ) NMPROVEEDOR,
                          FNNUMEMPLEADO,
                          "nombreCompleto" SOLICITANTE,
                          "status" STATUSEMP,
                          FNIMPORTESOLICITADO TOTAL,
                         (SELECT IDTASKGASTO
                            FROM FACTURACIONBITACORA XX
                           WHERE XX.IDGASTOMAIN = A.IDGASTOMAIN
                             AND xx.DEL_INDEX = (SELECT MAX(DEL_INDEX)
                                                   FROM FACTURACIONBITACORA DD
                                                  WHERE XX.IDGASTOMAIN = DD.IDGASTOMAIN
                                                )
                          ) ETAPA,
                          FNIMPORTEREEMBOLSO,
                          FNIMPORTEANTICIPO,
                          FCSEVERIDADGASTO,
                          CASE WHEN IDEMPRESAFACTURACION = 0 THEN IDOTEMPRESAFACTURACION ELSE IDEMPRESAFACTURACION END EMPRESA,
                          (SELECT (FCVALOR+FCVALOR1) FROM CTCATALOGOGASTOS F WHERE F.IDCATGASTO= A.IDFORMAPAGO) COMISION,
                          CASE WHEN FCTIPOCUENTA = '1' THEN 'Fiscal' ELSE 'No Fiscal' END  TPOCUENTA,
                          CASE
                             WHEN FCSEVERIDADGASTO NOT IN ('Normal', 'Urgente')
                             THEN  'Fec Asig'
                                /*PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA,'N')*/
                             ELSE
                                FCSEVERIDADGASTO
                          END URGENCIA,
                          (
                          SELECT  CASE
                                    WHEN IDTIPOMOVTO IN (2, 3)
                                    THEN
                                       (SELECT NVL (U1CARTERA, U2CARTERA)
                                          FROM         RCVRY.DELQMST A
                                                    LEFT JOIN
                                                       RCVRY.UDA1 B
                                                    ON (A.DMACCT = B.U1ACCT)
                                                 LEFT JOIN
                                                    RCVRY.UDA2 C
                                                 ON (A.DMACCT = C.U2ACCT)
                                         WHERE   A.DMACCT = X.FCCREDITOCARTERA)
                                    WHEN IDTIPOMOVTO IN (4)
                                    THEN
                                       (SELECT   NMDESCRIPCION
                                          FROM   PENDUPM.CTCARTERA A
                                         WHERE   A.IDCARTERA = X.FCCREDITOCARTERA)
                                    ELSE
                                       'IMPORTE GENERAL'
                                 END NMCARTERA
                          FROM   PENDUPM.FACTURAASIGNACION X
                          WHERE   IDGASTOMAIN = A.IDGASTOMAIN
                          AND ROWNUM = 1
                          ) CARTERA
                     FROM FACTURACIONMAIN A  INNER JOIN  (select * from  PENDUPM.VISTAASOCIADOSCOMPLETA )
                                    ON ( "cvetra" = FNNUMEMPLEADO)
                    WHERE IDGASTOMAIN IN (SELECT ZZ.IDGASTOMAIN
                                            FROM FACTURACIONBITACORA ZZ
                                      INNER JOIN (SELECT IDGASTOMAIN,
                                                         MAX (DEL_INDEX) DONDEESTA
                                                    FROM FACTURACIONBITACORA
                                                GROUP BY IDGASTOMAIN
                                                 ) CC ON ( ZZ.IDGASTOMAIN = CC.IDGASTOMAIN AND DEL_INDEX = DONDEESTA)
                                           WHERE IDTASKGASTO IN ('2082181485273e6002e4959086601056','656925561529384c6847c88021053266')
                                        )
                      AND IDFORMAPAGO = 36 AND FCSTATUS = 'D'
                      AND CASE WHEN IDEMPRESAFACTURACION = 0 THEN A.IDOTEMPRESAFACTURACION
                               WHEN (IDEMPRESAFACTURACION != 0 OR IDEMPRESAFACTURACION IS NOT NULL) THEN A.IDEMPRESAFACTURACION
                      END = pnEmpFact
                 ) PASO GROUP BY GASTO, CONCEPTO, QUIESES, AQUIEN, TPOMOVIMIENTO, NMPROVEEDOR, FNNUMEMPLEADO, SOLICITANTE, STATUSEMP, TOTAL, ETAPA,FNIMPORTEREEMBOLSO, FNIMPORTEANTICIPO, FCSEVERIDADGASTO, EMPRESA, COMISION, TPOCUENTA, URGENCIA, CARTERA
           ) TODOJUNTO
        WHERE TRUNC(PARAORDEN) <= TRUNC(SYSDATE)
         ORDER BY PARAORDEN ASC;
      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getTransAnticipo;

   PROCEDURE getConfTransAnticipo (salida IN OUT T_CURSOR, pnEmpFact INTEGER)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;
   BEGIN
      OPEN procesa FOR
     SELECT *
        FROM (
            SELECT  GASTO,CONCEPTO,
                    QUIESES,
                    AQUIEN,
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'AN'
                         WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '656925561529384c6847c88021053266' THEN 'RE'
                         WHEN TPOMOVIMIENTO = 'Reembolso' AND ETAPA = '656925561529384c6847c88021053266' THEN 'RE'
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'AN'
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '656925561529384c6847c88021053266' THEN 'RE'
                    END TIPOMOVTO,
                    NMPROVEEDOR,
                    SOLICITANTE,
                    STATUSEMP,
                    TOTAL,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (FNIMPORTEANTICIPO+COMISION)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN FNIMPORTEREEMBOLSO
                    END ANTICIPO,
                    URGENCIA,
                    ' <B>'||
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'Anticipo'
                         WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '656925561529384c6847c88021053266' THEN 'Reembolso'
                         WHEN TPOMOVIMIENTO = 'Reembolso' AND ETAPA = '656925561529384c6847c88021053266' THEN 'Reembolso'
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'Tramite-Anticipo'
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '656925561529384c6847c88021053266' THEN 'Tramite-Reembolso'
                    END||' </B>' ||
                    (SELECT NMEMPRESA
                       FROM EMPRESAFACTURACION D
                      WHERE D.IDEMPRESA = EMPRESA
                    ) EMPFACT,
                    COMISION COMISIONCHEQUE,
                    TPOCUENTA,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END   FECPAGO   ,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT FDFECPARAPAGO FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT FDFECPARAPAGO FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END PARAORDEN   ,
                    '<B>'||CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT FCREFERDYN  FROM FACTURACIONPAGOS DD WHERE  DD.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT FCREFERDYN  FROM FACTURACIONPAGOS DD WHERE  DD.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END||'</B><BR/>'||
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END  REFERENCIA,
                    FECHAANTICIPO       , QUEEMPRESAES
              FROM (
                   SELECT DISTINCT
                          IDGASTOMAIN GASTO,
                          PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN) CONCEPTO,
                          IDPROVEEDORDEPOSITO QUIESES,
                          FCASIGNADEPOSITO AQUIEN,
                          TPOMOVIMIENTO,
                          (SELECT NMPROVEEDOR FROM CTPROVEEDORGASTO F WHERE F.IDPROVEEDORGTO = A.IDPROVEEDORDEPOSITO ) NMPROVEEDOR,
                          FNNUMEMPLEADO,
                             (SELECT "nombreCompleto"
                                FROM PENDUPM.VISTAASOCIADOSCOMPLETA
                               WHERE "cvetra" = FNNUMEMPLEADO)
                                SOLICITANTE,
                             (SELECT "status"
                                FROM PENDUPM.VISTAASOCIADOSCOMPLETA
                               WHERE "cvetra" = FNNUMEMPLEADO)
                                STATUSEMP,
                          FNIMPORTESOLICITADO TOTAL,
                         (SELECT IDTASKGASTO
                            FROM FACTURACIONBITACORA XX
                           WHERE XX.IDGASTOMAIN = A.IDGASTOMAIN
                             AND xx.DEL_INDEX = (SELECT MAX(DEL_INDEX)
                                                   FROM FACTURACIONBITACORA DD
                                                  WHERE XX.IDGASTOMAIN = DD.IDGASTOMAIN
                                                )
                          ) ETAPA,
                          FNIMPORTEREEMBOLSO,
                          FNIMPORTEANTICIPO,
                          FCSEVERIDADGASTO,
                          CASE WHEN IDEMPRESAFACTURACION = 0 THEN IDOTEMPRESAFACTURACION ELSE IDEMPRESAFACTURACION END EMPRESA,
                          (SELECT (FCVALOR+FCVALOR1) FROM CTCATALOGOGASTOS F WHERE F.IDCATGASTO= A.IDFORMAPAGO) COMISION,
                          CASE WHEN FCTIPOCUENTA = '1' THEN 'Fiscal' ELSE 'No Fiscal' END  TPOCUENTA,
                          CASE
                             WHEN FCSEVERIDADGASTO NOT IN ('Normal', 'Urgente')
                             THEN  'Fec Asig'
                                /*PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA,'N')*/
                             ELSE
                                FCSEVERIDADGASTO
                          END URGENCIA,
                          PCKENVIOCORREO.aplFecha (FDDYNAMICSGASTO) FECHAANTICIPO,
                          CASE  WHEN A.IDEMPRESAFACTURACION > 0 THEN A.IDEMPRESAFACTURACION
                         ELSE A.IDOTEMPRESAFACTURACION
                         END QUEEMPRESAES
                     FROM FACTURACIONMAIN A
                    WHERE IDGASTOMAIN IN (SELECT ZZ.IDGASTOMAIN
                                            FROM FACTURACIONBITACORA ZZ
                                      INNER JOIN (SELECT IDGASTOMAIN,
                                                         MAX (DEL_INDEX) DONDEESTA
                                                    FROM FACTURACIONBITACORA
                                                GROUP BY IDGASTOMAIN
                                                 ) CC ON ( ZZ.IDGASTOMAIN = CC.IDGASTOMAIN AND DEL_INDEX = DONDEESTA)
                                           WHERE IDTASKGASTO IN ('2082181485273e6002e4959086601056','656925561529384c6847c88021053266')
                                        )
                     AND A.IDFORMAPAGO = 36
                    AND (FNIMPORTEANTICIPO > 0 OR FNIMPORTEREEMBOLSO > 0)
                    AND FCSTATUS = 'DP'
                        OR (    FCSTATUS = 'F'
                            AND (SELECT COUNT (1)
                                   FROM FACTURACIONBITACORA X
                                  WHERE     X.IDGASTOMAIN = A.IDGASTOMAIN
                                        AND FCCOMENTARIOS IN ('LA TRANSFERENCIA SPEI FUE REALIZADA','TRANSFERENCIA SPEI REALIZADA FALTA CONFIRMACION')) >
                                   0)
                 ) PASO
           ) TODOJUNTO
          WHERE QUEEMPRESAES = pnEmpFact
         ORDER BY PARAORDEN ASC;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getConfTransAnticipo;

   PROCEDURE setConfTransAnticipo (psGastos         VARCHAR2, /* CADENA DE IDGASTO SEPARADO POR PIPES */
                                   usuSolic         VARCHAR2,
                                   queFolioEs       VARCHAR2,
                                   psError      OUT VARCHAR2,
                                   pnempresaFact    INTEGER)
   IS
      ubica        INTEGER := 0;
      ubicaCred    INTEGER := 0;
      valor        VARCHAR2 (20) := '';
      cadena       VARCHAR2 (4000) := psGastos;
      cadena1      VARCHAR2 (4000) := psGastos;
      DeRR         VARCHAR2 (4000) := psGastos;
      psApp        VARCHAR2 (40) := '';
      psTask       VARCHAR2 (40) := '';
      psIndex      INTEGER := 0;
      queUsuEs     VARCHAR2 (50) := '';
      queTipoEs    VARCHAR2 (50) := '';
      pstipoPago   INTEGER := 0;
      queTipoMovto VARCHAR2 (50) := '';
   BEGIN
      psError := '0';
      ubica := INSTR (cadena1, '|');

      WHILE (ubica > 0)
      LOOP
         valor := SUBSTR (cadena1, 1, ubica - 1);

         SELECT DISTINCT CASE
                            WHEN     TPOMOVIMIENTO = 'Anticipo'
                                 AND (SELECT COUNT (1)
                                        FROM FACTURACIONPAGOS X
                                       WHERE     IDGASTOMAIN = A.IDGASTOMAIN
                                             AND FNCONSEC = 2
                                             AND FNIMPORTE > 0) > 0
                                 AND (SELECT COUNT (1)
                                        FROM FACTURACIONPAGOS X
                                       WHERE     IDGASTOMAIN = A.IDGASTOMAIN
                                             AND FNCONSEC = 6
                                             AND FNIMPORTE > 0) = 0
                            THEN
                               'AN'
                            WHEN     TPOMOVIMIENTO = 'Anticipo'
                                 AND (SELECT COUNT (1)
                                        FROM FACTURACIONPAGOS X
                                       WHERE     IDGASTOMAIN = A.IDGASTOMAIN
                                             AND FNCONSEC = 2
                                             AND FNIMPORTE > 0
                                             AND FDFECPAGADO IS NOT NULL) > 0
                                 AND (SELECT COUNT (1)
                                        FROM FACTURACIONPAGOS X
                                       WHERE     IDGASTOMAIN = A.IDGASTOMAIN
                                             AND FNCONSEC = 6
                                             AND FNIMPORTE > 0) > 0
                            THEN
                               'RE'
                            WHEN     TPOMOVIMIENTO = 'Reembolso'
                                 AND (SELECT COUNT (1)
                                        FROM FACTURACIONPAGOS X
                                       WHERE     IDGASTOMAIN = A.IDGASTOMAIN
                                             AND FNCONSEC = 6
                                             AND FNIMPORTE > 0) > 0
                            THEN
                               'RE'
                            WHEN     TPOMOVIMIENTO = 'Tramite'
                                 AND (SELECT COUNT (1)
                                        FROM FACTURACIONPAGOS X
                                       WHERE     IDGASTOMAIN = A.IDGASTOMAIN
                                             AND FNCONSEC = 2
                                             AND FNIMPORTE > 0
                                             AND FDFECPAGADO IS NOT NULL) > 0
                                 AND (SELECT COUNT (1)
                                        FROM FACTURACIONPAGOS X
                                       WHERE     IDGASTOMAIN = A.IDGASTOMAIN
                                             AND FNCONSEC = 6
                                             AND FNIMPORTE > 0) = 0
                            THEN
                               'AN'
                            WHEN     TPOMOVIMIENTO = 'Tramite'
                                 AND (SELECT COUNT (1)
                                        FROM FACTURACIONPAGOS X
                                       WHERE     IDGASTOMAIN = A.IDGASTOMAIN
                                             AND FNCONSEC = 2
                                             AND FNIMPORTE > 0
                                             AND FDFECPAGADO IS NOT NULL) > 0
                                 AND (SELECT COUNT (1)
                                        FROM FACTURACIONPAGOS X
                                       WHERE     IDGASTOMAIN = A.IDGASTOMAIN
                                             AND FNCONSEC = 6
                                             AND FNIMPORTE > 0) > 0
                            THEN
                               'RE'
                            WHEN     TPOMOVIMIENTO = 'Tramite'
                                 AND (SELECT COUNT (1)
                                        FROM FACTURACIONPAGOS X
                                       WHERE     IDGASTOMAIN = A.IDGASTOMAIN
                                             AND FNCONSEC = 6
                                             AND FNIMPORTE > 0) > 0
                            THEN
                               'RE'
                            ELSE
                               'RE'
                         END
                            TIPOMOVTO,
                         IDFORMAPAGO
           INTO queTipoEs, pstipoPago
           FROM FACTURACIONMAIN A
          WHERE A.IDGASTOMAIN = valor;

         SELECT MAX(APP_UID), MAX(IDTASKGASTO), MAX(DEL_INDEX)
           INTO psApp, psTask, psIndex
           FROM FACTURACIONBITACORA X
          WHERE X.IDGASTOMAIN = valor
                AND (X.IDGASTOMAIN,X.DEL_INDEX) = (SELECT IDGASTOMAIN,MAX (DEL_INDEX)
                                     FROM FACTURACIONBITACORA P
                                    WHERE P.IDGASTOMAIN = valor
                                  GROUP BY IDGASTOMAIN);

         SELECT DISTINCT TPOMOVIMIENTO INTO queTipoMovto FROM PENDUPM.FACTURACIONMAIN A
          WHERE A.IDGASTOMAIN = valor;

         UPDATE FACTURACIONMAIN
            SET FCSTATUS = CASE WHEN queTipoEs = 'RE' THEN 'F' ELSE 'DC' END,
                FDFECTERMINO = CASE WHEN queTipoEs = 'RE' THEN SYSDATE END,
                FDDYNAMICSREEMB = CASE WHEN queTipoEs = 'RE' THEN SYSDATE END,
                FDDYNAMICSREEMBCONF =
                   CASE WHEN queTipoEs = 'RE' THEN SYSDATE END,
                FDDYNAMICSGASTOCONF =
                   CASE
                      WHEN IDFORMAPAGO = 36 AND FNIMPORTEANTICIPO > 0
                      THEN
                         SYSDATE
                      ELSE
                         NULL
                   END,
                FDDYNAMICSGASTO = CASE WHEN queTipoEs = 'AN' THEN SYSDATE END,
                FCUSUCONF = usuSolic
          WHERE IDGASTOMAIN = valor;

         IF (queTipoEs = 'RE')
         THEN
            UPDATE FACTURACIONMAIN
               SET FCSTATUS = 'F'
             WHERE IDGASTOMAIN = valor;
         ELSE
            UPDATE FACTURACIONMAIN
               SET FCSTATUS = 'T'
             WHERE IDGASTOMAIN = valor;
         END IF;

         UPDATE FACTURACIONDEPOSITO
            SET FDFECDERIVACION = SYSDATE,
                FCREFERENCIA    =  queFolioEs
          WHERE IDGASTOMAIN = valor
                AND FNCONSEC = CASE WHEN queTipoEs = 'RE' THEN 6 ELSE 2 END
                AND FCSTATUS = 'A';

         UPDATE FACTURACIONBITACORA
            SET FCRESULTADO =
                   CASE WHEN (pstipoPago = 36) THEN 'CONFIRMADO' END,
                FCCOMENTARIOS =
                   CASE
                      WHEN (pstipoPago = 36)
                      THEN
                         'LA TRANSFERENCIA SPEI FUE CONFIRMADA'
                   END,
                FDFECREGISTRO = SYSDATE,
                FCUSUARIO = usuSolic
          WHERE     IDGASTOMAIN = valor
                AND APP_UID = psApp
                AND IDTASKGASTO = psTask
                AND DEL_INDEX = psIndex;

         SELECT FCUSUARIO
           INTO queUsuEs
           FROM FACTURACIONBITACORA
          WHERE IDGASTOMAIN = valor AND APP_UID = psApp AND DEL_INDEX = 1;
        DBMS_OUTPUT.PUT_LINE ('queUsuEs -->' || queUsuEs);
         IF (queTipoEs = 'AN' AND queTipoMovto = 'Tramite')
         THEN
         DBMS_OUTPUT.PUT_LINE ('Inicio busqueda de area concentradora -->');
            SELECT FCUSUARIO INTO queUsuEs
           FROM PENDUPM.FACTURACIONBITACORA X
          WHERE X.IDGASTOMAIN = valor
                AND (X.IDGASTOMAIN,X.DEL_INDEX) = (SELECT IDGASTOMAIN,MAX (DEL_INDEX)
                                     FROM PENDUPM.FACTURACIONBITACORA P
                                    WHERE P.IDGASTOMAIN = valor AND P.IDTASKGASTO = '43704322352eae467857576064357523'
                                  GROUP BY IDGASTOMAIN);

            DBMS_OUTPUT.PUT_LINE ('Tramite queUsuEs -->' || queUsuEs);
            INSERT INTO FACTURACIONBITACORA
                 VALUES (valor,
                         psApp,
                         '2147619945273e5a68478d0053334276',
                         (psIndex + 1),
                         'COMPROBACION DEL GASTO',
                         SYSDATE,
                         queUsuEs,
                         NULL,
                         NULL);
         END IF;

         IF (queTipoEs = 'AN' AND queTipoMovto != 'Tramite')
         THEN
            INSERT INTO FACTURACIONBITACORA
                 VALUES (valor,
                         psApp,
                         '2147619945273e5a68478d0053334276',
                         (psIndex + 1),
                         'COMPROBACION DEL GASTO',
                         SYSDATE,
                         queUsuEs,
                         NULL,
                         NULL);
         END IF;

         cadena1 := SUBSTR (cadena1, ubica + 1);
         ubica := INSTR (cadena1, '|');
      END LOOP;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         DeRR := SQLERRM;
         psError := '-1 ' || DeRR;
   END setConfTransAnticipo;

   PROCEDURE getArchivoPoliza (salida IN OUT T_CURSOR, pnEmpFact INTEGER)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;
   BEGIN
      OPEN procesa FOR
     SELECT *
        FROM (
            SELECT  GASTO,CONCEPTO,
                    QUIESES,        AQUIEN,
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN 'RE'
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN 'AN'
                                                             END
                         WHEN TPOMOVIMIENTO = 'Reembolso' THEN 'RE'
                         WHEN TPOMOVIMIENTO = 'Tramite' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN 'RE'
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN 'AN'
                                                             END
                    END TIPOMOVTO,
                    NMPROVEEDOR,
                    (SELECT "nombreCompleto"
                                     FROM PENDUPM.VISTAASOCIADOS
                                    WHERE "cvetra" = 1471
                    ) SOLICITANTE,
                   (SELECT "status"
                     FROM PENDUPM.VISTAASOCIADOS
                    WHERE "cvetra" = FNNUMEMPLEADO
                   ) STATUSEMP,
                    TOTAL,
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN  'Subtotal..'||PCKCONVENIOS.formatComas(FNIMPORTEREEMBOLSO)||'<BR/>'||
                                                                                                  'Comision..'||PCKCONVENIOS.formatComas(COMISION)
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN 'Subtotal..'||PCKCONVENIOS.formatComas(FNIMPORTEANTICIPO)||'<BR/>'||
                                                                                                'Comision..'||PCKCONVENIOS.formatComas(COMISION)
                                                             END
                         WHEN TPOMOVIMIENTO = 'Reembolso' THEN  'Subtotal..'||PCKCONVENIOS.formatComas(FNIMPORTEREEMBOLSO)||'<BR/>'||
                                                               'Comision..'||PCKCONVENIOS.formatComas(COMISION)
                         WHEN TPOMOVIMIENTO = 'Tramite' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN  'Subtotal..'||PCKCONVENIOS.formatComas(FNIMPORTEREEMBOLSO)||'<BR/>'||
                                                                                                  'Comision..'||PCKCONVENIOS.formatComas(COMISION)
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN 'Subtotal..'||PCKCONVENIOS.formatComas(FNIMPORTEANTICIPO)||'<BR/>'||
                                                                                                'Comision..'||PCKCONVENIOS.formatComas(COMISION)
                                                             END
                    END DETMONTO,
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN  (FNIMPORTEREEMBOLSO+COMISION)
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN (FNIMPORTEANTICIPO+COMISION)
                                                             END
                         WHEN TPOMOVIMIENTO = 'Reembolso' THEN (FNIMPORTEREEMBOLSO+COMISION)
                         WHEN TPOMOVIMIENTO = 'Tramite' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN (FNIMPORTEREEMBOLSO+COMISION)
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN (FNIMPORTEANTICIPO+COMISION)
                                                             END
                    END  ANTICIPO,
                    (SELECT NMDESCRIPCION FROM CTCATALOGOGASTOS WHERE IDCATGASTO = IDFORMAPAGO ) URGENCIA,
                    ' <B>'||
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN 'Anticipo-Reembolso'
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN 'Anticipo'
                                                             END
                         WHEN TPOMOVIMIENTO = 'Reembolso' THEN 'Reembolso'
                         WHEN TPOMOVIMIENTO = 'Tramite' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN 'Tramite-Reembolso'
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN 'Tramite-Anticipo'
                                                             END
                    END||' </B>' ||
                    (SELECT NMEMPRESA
                       FROM EMPRESAFACTURACION D
                      WHERE D.IDEMPRESA = EMPRESA
                    ) EMPFACT,
                    COMISION COMISIONCHEQUE,
                    TPOCUENTA,
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                                                             END
                         WHEN TPOMOVIMIENTO = 'Reembolso' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                         WHEN TPOMOVIMIENTO = 'Tramite' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                                                             END
                    END  FECHAANTICIPO   ,
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN (SELECT FDFECPARAPAGO FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN (SELECT FDFECPARAPAGO FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                                                             END
                         WHEN TPOMOVIMIENTO = 'Reembolso' THEN (SELECT FDFECPARAPAGO FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                         WHEN TPOMOVIMIENTO = 'Tramite' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN (SELECT FDFECPARAPAGO FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN (SELECT FDFECPARAPAGO FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                                                             END
                    END FECHAORDEN
              FROM (
                   SELECT DISTINCT
                          IDGASTOMAIN GASTO,
                          PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN) CONCEPTO,
                          IDPROVEEDORDEPOSITO QUIESES,
                          FCASIGNADEPOSITO AQUIEN,
                          TPOMOVIMIENTO,
                          (SELECT NMPROVEEDOR FROM CTPROVEEDORGASTO F WHERE F.IDPROVEEDORGTO = A.IDPROVEEDORDEPOSITO ) NMPROVEEDOR,
                          FNNUMEMPLEADO,
                          FNIMPORTESOLICITADO TOTAL,
                          CASE WHEN ( SELECT COUNT(1)
                                        FROM FACTURACIONBITACORA XX
                                       WHERE XX.IDGASTOMAIN = A.IDGASTOMAIN
                                         AND IDTASKGASTO = '2082181485273e6002e4959086601056'
                                    ) > 0 THEN 'ANTICIPO' ELSE NULL
                          END ETAPA1,
                          CASE WHEN ( SELECT COUNT(1)
                                        FROM FACTURACIONBITACORA XX
                                       WHERE XX.IDGASTOMAIN = A.IDGASTOMAIN
                                         AND IDTASKGASTO = '656925561529384c6847c88021053266'
                                    ) > 0 THEN 'REEMBOLSO' ELSE NULL
                          END  ETAPA2,
                          FNIMPORTEREEMBOLSO,
                          FNIMPORTEANTICIPO,
                          FCSEVERIDADGASTO,
                          CASE WHEN IDEMPRESAFACTURACION = 0 THEN IDOTEMPRESAFACTURACION ELSE IDEMPRESAFACTURACION END EMPRESA,
                          (SELECT (FCVALOR+FCVALOR1) FROM CTCATALOGOGASTOS F WHERE F.IDCATGASTO= A.IDFORMAPAGO) COMISION,
                          CASE WHEN FCTIPOCUENTA = '1' THEN 'Fiscal' ELSE 'No Fiscal' END  TPOCUENTA,
                          CASE
                             WHEN FCSEVERIDADGASTO NOT IN ('Normal', 'Urgente')
                             THEN
                                PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA)
                             ELSE
                                FCSEVERIDADGASTO
                          END URGENCIA1,
                          IDFORMAPAGO
                     FROM FACTURACIONMAIN A
                    WHERE ( FNIMPORTEANTICIPO > 0 OR FNIMPORTEREEMBOLSO > 0)
                      AND ((FNIMPORTEANTICIPO IS NOT NULL OR FNIMPORTEANTICIPO != '') or (FNIMPORTEREEMBOLSO IS NOT NULL OR FNIMPORTEREEMBOLSO != ''))
                      AND CASE
                              WHEN IDEMPRESAFACTURACION = 0 THEN A.IDOTEMPRESAFACTURACION
                              WHEN (IDEMPRESAFACTURACION != 0 OR IDEMPRESAFACTURACION IS NOT NULL) THEN A.IDEMPRESAFACTURACION
                              END = pnEmpFact
                      AND A.IDGASTOMAIN NOT IN (SELECT IDGASTOMAIN FROM CIRCUITOCONTABLE WHERE FCQUEARCHIVO = 'PRVANTCGO')
                      AND  A.IDGASTOMAIN IN (SELECT IDGASTOMAIN FROM FACTURACIONPAGOS WHERE FNCONSEC IN ( 2,6) AND FNIMPORTE > 0 ) /* AND FDFECPAGADO IS NULL)*/
                 ) PASO
            WHERE ETAPA2 IS NOT NULL OR ETAPA1 IS NOT NULL
           ) TODOJUNTO
         ORDER BY FECHAANTICIPO ASC;
--         SELECT DISTINCT
--                IDGASTOMAIN GASTO,
--                PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN) CONCEPTO,
--                IDPROVEEDORDEPOSITO QUIESES,
--                FCASIGNADEPOSITO AQUIEN,
--                (SELECT "nombreCompleto"
--                   from pendupm.vistaasociadoscompleta
--                  WHERE "cvetra" = FNNUMEMPLEADO)
--                   SOLICITANTE,
--                (SELECT "status"
--                   from pendupm.vistaasociadoscompleta
--                  WHERE "cvetra" = FNNUMEMPLEADO)
--                   STATUSEMP,
--                FNIMPORTESOLICITADO TOTAL,
--                FNIMPORTEANTICIPO ANTICIPO,
--                CASE
--                   WHEN FCSEVERIDADGASTO NOT IN ('Normal', 'Urgente') THEN PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA)
--                   ELSE FCSEVERIDADGASTO
--                END URGENCIA,
--                   '<B>'|| CASE
--                      WHEN (SELECT IDTASKGASTO FROM FACTURACIONBITACORA XX WHERE     XX.IDGASTOMAIN = A.IDGASTOMAIN
--                                   AND xx.DEL_INDEX = A.DELINDEX_ETAPA) = '656925561529384c6847c88021053266' THEN 'Reembolso'
--                      ELSE 'Anticipo' END
--                || ' </B>'
--                || NVL (CASE WHEN IDEMPRESAFACTURACION = 0 THEN (SELECT NMEMPRESA
--                                                                   FROM EMPRESAFACTURACION D
--                                                                  WHERE D.IDEMPRESA = A.IDOTEMPRESAFACTURACION)
--                             WHEN (IDEMPRESAFACTURACION != 0 OR IDEMPRESAFACTURACION IS NOT NULL) THEN
--                                                (SELECT NMEMPRESA
--                                                   FROM EMPRESAFACTURACION D WHERE D.IDEMPRESA = A.IDEMPRESAFACTURACION)
--                             WHEN (IDEMPRESAFACTURACION IS NULL OR IDEMPRESAFACTURACION = '') THEN 'SIN EMPRESA DE FACTURACION'
--                      END,'SIN EMPRESA DE FACTURACION') EMPFACT,
--                NVL ( CASE WHEN IDEMPRESAFACTURACION = 0 THEN (SELECT FNIMPCOMISION
--                                                                 FROM EMPRESAFACTURACION D
--                                                                WHERE D.IDEMPRESA = A.IDOTEMPRESAFACTURACION)
--                           WHEN (IDEMPRESAFACTURACION != 0  OR IDEMPRESAFACTURACION IS NOT NULL) THEN
--                                                 (SELECT FNIMPCOMISION FROM EMPRESAFACTURACION D WHERE D.IDEMPRESA = A.IDEMPRESAFACTURACION)
--                           WHEN (IDEMPRESAFACTURACION IS NULL OR IDEMPRESAFACTURACION = '') THEN -1 END, -1) COMISIONCHEQUE,
--                PCKENVIOCORREO.aplFecha (FDDYNAMICSGASTOCONF) FECHAANTICIPO
--           FROM FACTURACIONMAIN A
--          WHERE     FNIMPORTEANTICIPO > 0
--                AND (FNIMPORTEANTICIPO IS NOT NULL OR FNIMPORTEANTICIPO != '')
--                AND CASE    WHEN (IDEMPRESAFACTURACION = 0 OR IDEMPRESAFACTURACION IS NULL) THEN A.IDOTEMPRESAFACTURACION
--                            WHEN (IDEMPRESAFACTURACION != 0 OR IDEMPRESAFACTURACION IS NOT NULL) THEN A.IDEMPRESAFACTURACION
--                    END = pnEmpFact
--                AND A.IDGASTOMAIN NOT IN (SELECT IDGASTOMAIN
--                                            FROM CIRCUITOCONTABLE
--                                           WHERE FCQUEARCHIVO = 'PRVANTCGO')
--                AND A.IDGASTOMAIN IN (SELECT IDGASTOMAIN
--                                        FROM FACTURACIONPAGOS
--                                       WHERE     FNCONSEC = 2
--                                             AND FNIMPORTE > 0)
--                AND A.IDGASTOMAIN IN (SELECT IDGASTOMAIN FROM FACTURACIONBITACORA WHERE IDTASKGASTO = '2082181485273e6002e4959086601056');

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getArchivoPoliza;

   PROCEDURE setArchivoPoliza (psGastos       VARCHAR2,
                               usuSolic       VARCHAR2,
                               psError    OUT VARCHAR2)
   IS
      ubica        INTEGER := 0;
      queElemento  INTEGER := 1;
      ubicaCred    INTEGER := 0;
      contmaster   INTEGER := 0;
      valor        VARCHAR2 (20) := '';
      cadena       VARCHAR2 (4000) := psGastos;
      cadena1      VARCHAR2 (4000) := REPLACE (psGastos, '|', ',');
      DeRR         VARCHAR2 (4000) := psGastos;
      psEjecuta    VARCHAR2 (4000) := '';
      arrDetalle   POLIZACONTABLEGASTOS.TABdetalleGastos;

   BEGIN
      psError := '0';
      ubica := INSTR (cadena, '|');

      WHILE (ubica > 0)
      LOOP
         valor := SUBSTR (cadena, 1, ubica - 1);
         arrDetalle(queElemento).rIdGasto := valor;
         queElemento := queElemento +1;
         cadena := substr(cadena, (ubica+1),4000);
         ubica := INSTR (cadena, '|');
      END LOOP;

      POLIZACONTABLEGASTOS.setProvisionAnticipo(arrDetalle,usuSolic,psEjecuta);
      psError := psEjecuta;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         DeRR := SQLERRM;
         psError := '**ERROR* ' || DeRR;
   END setArchivoPoliza;


   PROCEDURE getChequesReembolso (queCheque          INTEGER DEFAULT 0,
                                  pnEmpFact          INTEGER,
                                  salida      IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;
   BEGIN
      IF (queCheque = 0)
      THEN
         OPEN procesa FOR
              SELECT *
                FROM (SELECT DISTINCT
                             IDGASTOMAIN GASTO,
                             PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN)
                                CONCEPTO,
                             IDPROVEEDORDEPOSITO QUIESES,
                             FCASIGNADEPOSITO AQUIEN,
                             (SELECT "nombreCompleto"
                                FROM PENDUPM.VISTAASOCIADOS
                               WHERE "cvetra" = FNNUMEMPLEADO)
                                SOLICITANTE,
                             (SELECT "status"
                                FROM PENDUPM.VISTAASOCIADOS
                               WHERE "cvetra" = FNNUMEMPLEADO)
                                STATUSEMP,
                             FNIMPORTESOLICITADO TOTAL,
                             CASE
                                WHEN (    FNIMPORTEANTICIPO > 0
                                      AND (   FNIMPORTEANTICIPO IS NOT NULL
                                           OR FNIMPORTEANTICIPO != ''))
                                THEN
                                   FNIMPORTEANTICIPO
                                WHEN (    FNIMPORTEREEMBOLSO > 0
                                      AND (   FNIMPORTEREEMBOLSO IS NOT NULL
                                           OR FNIMPORTEREEMBOLSO != ''))
                                THEN
                                   FNIMPORTEREEMBOLSO
                             END
                                ANTICIPO,
                             CASE
                                WHEN FCSEVERIDADGASTO NOT IN ('Normal',
                                                              'Urgente')
                                THEN
                                   PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA)
                                ELSE
                                   FCSEVERIDADGASTO
                             END
                                URGENCIA,
                                '<B>'
                             || CASE
                                   WHEN (    FNIMPORTEANTICIPO > 0
                                         AND (   FNIMPORTEREEMBOLSO > 0
                                              OR FNIMPORTEREEMBOLSO IS NULL))
                                   THEN
                                      'Anticipo'
                                   ELSE
                                      'Pago/Reembolso'
                                END
                             || ' </B>'
                             || NVL (
                                   CASE
                                      WHEN IDEMPRESAFACTURACION = 0
                                      THEN
                                         (SELECT NMEMPRESA
                                            FROM EMPRESAFACTURACION D
                                           WHERE D.IDEMPRESA =
                                                    A.IDOTEMPRESAFACTURACION)
                                      WHEN (   IDEMPRESAFACTURACION != 0
                                            OR IDEMPRESAFACTURACION IS NOT NULL)
                                      THEN
                                         (SELECT NMEMPRESA
                                            FROM EMPRESAFACTURACION D
                                           WHERE D.IDEMPRESA =
                                                    A.IDEMPRESAFACTURACION)
                                      WHEN (   IDEMPRESAFACTURACION IS NULL
                                            OR IDEMPRESAFACTURACION = '')
                                      THEN
                                         'SIN EMPRESA DE FACTURACION'
                                   END,
                                   'SIN EMPRESA DE FACTURACION')
                                EMPFACT,
                             NVL (
                                CASE
                                   WHEN IDEMPRESAFACTURACION = 0
                                   THEN
                                      (SELECT FNIMPCOMISION
                                         FROM EMPRESAFACTURACION D
                                        WHERE D.IDEMPRESA =
                                                 A.IDOTEMPRESAFACTURACION)
                                   WHEN (   IDEMPRESAFACTURACION != 0
                                         OR IDEMPRESAFACTURACION IS NOT NULL)
                                   THEN
                                      (SELECT FNIMPCOMISION
                                         FROM EMPRESAFACTURACION D
                                        WHERE D.IDEMPRESA =
                                                 A.IDEMPRESAFACTURACION)
                                   WHEN (   IDEMPRESAFACTURACION IS NULL
                                         OR IDEMPRESAFACTURACION = '')
                                   THEN
                                      -1
                                END,
                                -1)
                                COMISIONCHEQUE,
                             CASE
                                WHEN FCTIPOCUENTA = '1' THEN 'Fiscal'
                                ELSE 'No Fiscal'
                             END
                                TPOCUENTA,
                             CASE
                                WHEN (SELECT ZZ.IDTASKGASTO
                                        FROM FACTURACIONBITACORA ZZ
                                             INNER JOIN
                                             (  SELECT IDGASTOMAIN,
                                                       MAX (DEL_INDEX) DONDEESTA
                                                  FROM FACTURACIONBITACORA
                                              GROUP BY IDGASTOMAIN) CC
                                                ON (    ZZ.IDGASTOMAIN =
                                                           CC.IDGASTOMAIN
                                                    AND ZZ.DEL_INDEX =
                                                           CC.DONDEESTA)
                                       WHERE     IDTASKGASTO IN ('2082181485273e6002e4959086601056',
                                                                 '656925561529384c6847c88021053266')
                                             AND ZZ.IDGASTOMAIN = A.IDGASTOMAIN) =
                                        '2082181485273e6002e4959086601056'
                                THEN
                                   (SELECT FDFECPARAPAGO
                                      FROM FACTURACIONPAGOS H
                                     WHERE     H.IDGASTOMAIN = A.IDGASTOMAIN
                                           AND H.FNCONSEC = 2)
                                WHEN (SELECT ZZ.IDTASKGASTO
                                        FROM FACTURACIONBITACORA ZZ
                                             INNER JOIN
                                             (  SELECT IDGASTOMAIN,
                                                       MAX (DEL_INDEX) DONDEESTA
                                                  FROM FACTURACIONBITACORA
                                              GROUP BY IDGASTOMAIN) CC
                                                ON (    ZZ.IDGASTOMAIN =
                                                           CC.IDGASTOMAIN
                                                    AND ZZ.DEL_INDEX =
                                                           CC.DONDEESTA)
                                       WHERE     IDTASKGASTO IN ('2082181485273e6002e4959086601056',
                                                                 '656925561529384c6847c88021053266')
                                             AND ZZ.IDGASTOMAIN = A.IDGASTOMAIN) =
                                        '656925561529384c6847c88021053266'
                                THEN
                                   (SELECT FDFECPARAPAGO
                                      FROM FACTURACIONPAGOS H
                                     WHERE     H.IDGASTOMAIN = A.IDGASTOMAIN
                                           AND H.FNCONSEC = 6)
                             END FECPAGO,
                            (SELECT FCREFERDYN  FROM FACTURACIONPAGOS DD WHERE  DD.IDGASTOMAIN = A.IDGASTOMAIN AND FNCONSEC = 2) REFERENCIA
                        FROM FACTURACIONMAIN A
                       WHERE     FDDYNAMICSGASTO IS NULL
                             AND IDFORMAPAGO IN (SELECT IDCATGASTO
                                                   FROM CTCATALOGOGASTOS
                                                  WHERE IDCATGASTO IN (37,
                                                                       38,
                                                                       39))
                             AND FNIMPORTEANTICIPO > 0
                             AND (   FNIMPORTEANTICIPO IS NOT NULL
                                  OR FNIMPORTEANTICIPO != '')
                             AND IDGASTOMAIN IN (SELECT ZZ.IDGASTOMAIN
                                                   FROM FACTURACIONBITACORA ZZ
                                                        INNER JOIN
                                                        (  SELECT IDGASTOMAIN,
                                                                  MAX (DEL_INDEX)
                                                                     DONDEESTA
                                                             FROM FACTURACIONBITACORA
                                                         GROUP BY IDGASTOMAIN)
                                                        CC
                                                           ON (    ZZ.IDGASTOMAIN =
                                                                      CC.IDGASTOMAIN
                                                               AND ZZ.DEL_INDEX =
                                                                      CC.DONDEESTA)
                                                  WHERE IDTASKGASTO IN ('2082181485273e6002e4959086601056',
                                                                        '656925561529384c6847c88021053266'))
                             AND IDGASTOMAIN IN (SELECT IDGASTOMAIN
                                                   FROM FACTURACIONPAGOS
                                                  WHERE     FNCONSEC IN (2, 6)
                                                        AND FDFECPAGADO IS NULL)
                             AND CASE
                                    WHEN (   IDEMPRESAFACTURACION = 0
                                          OR IDEMPRESAFACTURACION IS NULL)
                                    THEN
                                       A.IDOTEMPRESAFACTURACION
                                    WHEN (   IDEMPRESAFACTURACION != 0
                                          OR IDEMPRESAFACTURACION IS NOT NULL)
                                    THEN
                                       A.IDEMPRESAFACTURACION
                                 END = pnEmpFact) SAIDA
            ORDER BY FECPAGO;
      --             ORDER BY FDDYNAMICSGASTO DESC;
      ELSE
         OPEN procesa FOR
              SELECT *
                FROM (SELECT DISTINCT
                             IDGASTOMAIN GASTO,
                             PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN)
                                CONCEPTO,
                             IDPROVEEDORDEPOSITO QUIESES,
                             FCASIGNADEPOSITO AQUIEN,
                             (SELECT "nombreCompleto"
                                FROM PENDUPM.VISTAASOCIADOS
                               WHERE "cvetra" = FNNUMEMPLEADO)
                                SOLICITANTE,
                             (SELECT "status"
                                FROM PENDUPM.VISTAASOCIADOS
                               WHERE "cvetra" = FNNUMEMPLEADO)
                                STATUSEMP,
                             FNIMPORTESOLICITADO TOTAL,
                             CASE
                                WHEN (    FNIMPORTEANTICIPO > 0
                                      AND (   FNIMPORTEANTICIPO IS NOT NULL
                                           OR FNIMPORTEANTICIPO != ''))
                                THEN
                                   FNIMPORTEANTICIPO
                                WHEN (    FNIMPORTEREEMBOLSO > 0
                                      AND (   FNIMPORTEREEMBOLSO IS NOT NULL
                                           OR FNIMPORTEREEMBOLSO != ''))
                                THEN
                                   FNIMPORTEREEMBOLSO
                             END
                                ANTICIPO,
                             CASE
                                WHEN FCSEVERIDADGASTO NOT IN ('Normal',
                                                              'Urgente')
                                THEN
                                   PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA)
                                ELSE
                                   FCSEVERIDADGASTO
                             END
                                URGENCIA,
                                '<B>'
                             || CASE
                                   WHEN (    FNIMPORTEANTICIPO > 0
                                         AND (   FNIMPORTEREEMBOLSO > 0
                                              OR FNIMPORTEREEMBOLSO IS NULL))
                                   THEN
                                      'Anticipo'
                                   ELSE
                                      'Pago/Reembolso'
                                END
                             || ' </B>'
                             || NVL (
                                   CASE
                                      WHEN IDEMPRESAFACTURACION = 0
                                      THEN
                                         (SELECT NMEMPRESA
                                            FROM EMPRESAFACTURACION D
                                           WHERE D.IDEMPRESA =
                                                    A.IDOTEMPRESAFACTURACION)
                                      WHEN (   IDEMPRESAFACTURACION != 0
                                            OR IDEMPRESAFACTURACION IS NOT NULL)
                                      THEN
                                         (SELECT NMEMPRESA
                                            FROM EMPRESAFACTURACION D
                                           WHERE D.IDEMPRESA =
                                                    A.IDEMPRESAFACTURACION)
                                      WHEN (   IDEMPRESAFACTURACION IS NULL
                                            OR IDEMPRESAFACTURACION = '')
                                      THEN
                                         'SIN EMPRESA DE FACTURACION'
                                   END,
                                   'SIN EMPRESA DE FACTURACION')
                                EMPFACT,
                             NVL (
                                CASE
                                   WHEN IDEMPRESAFACTURACION = 0
                                   THEN
                                      (SELECT FNIMPCOMISION
                                         FROM EMPRESAFACTURACION D
                                        WHERE D.IDEMPRESA =
                                                 A.IDOTEMPRESAFACTURACION)
                                   WHEN (   IDEMPRESAFACTURACION != 0
                                         OR IDEMPRESAFACTURACION IS NOT NULL)
                                   THEN
                                      (SELECT FNIMPCOMISION
                                         FROM EMPRESAFACTURACION D
                                        WHERE D.IDEMPRESA =
                                                 A.IDEMPRESAFACTURACION)
                                   WHEN (   IDEMPRESAFACTURACION IS NULL
                                         OR IDEMPRESAFACTURACION = '')
                                   THEN
                                      -1
                                END,
                                -1)
                                COMISIONCHEQUE,
                             CASE
                                WHEN FCTIPOCUENTA = '1' THEN 'Fiscal'
                                ELSE 'No Fiscal'
                             END
                                TPOCUENTA,
                             CASE
                                WHEN (SELECT ZZ.IDTASKGASTO
                                        FROM FACTURACIONBITACORA ZZ
                                             INNER JOIN
                                             (  SELECT IDGASTOMAIN,
                                                       MAX (DEL_INDEX) DONDEESTA
                                                  FROM FACTURACIONBITACORA
                                              GROUP BY IDGASTOMAIN) CC
                                                ON (    ZZ.IDGASTOMAIN =
                                                           CC.IDGASTOMAIN
                                                    AND ZZ.DEL_INDEX =
                                                           CC.DONDEESTA)
                                       WHERE     IDTASKGASTO IN ('2082181485273e6002e4959086601056',
                                                                 '656925561529384c6847c88021053266')
                                             AND ZZ.IDGASTOMAIN = A.IDGASTOMAIN) =
                                        '2082181485273e6002e4959086601056'
                                THEN
                                   (SELECT FDFECPARAPAGO
                                      FROM FACTURACIONPAGOS H
                                     WHERE     H.IDGASTOMAIN = A.IDGASTOMAIN
                                           AND H.FNCONSEC = 2)
                                WHEN (SELECT ZZ.IDTASKGASTO
                                        FROM FACTURACIONBITACORA ZZ
                                             INNER JOIN
                                             (  SELECT IDGASTOMAIN,
                                                       MAX (DEL_INDEX) DONDEESTA
                                                  FROM FACTURACIONBITACORA
                                              GROUP BY IDGASTOMAIN) CC
                                                ON (    ZZ.IDGASTOMAIN =
                                                           CC.IDGASTOMAIN
                                                    AND ZZ.DEL_INDEX =
                                                           CC.DONDEESTA)
                                       WHERE     IDTASKGASTO IN ('2082181485273e6002e4959086601056',
                                                                 '656925561529384c6847c88021053266')
                                             AND ZZ.IDGASTOMAIN = A.IDGASTOMAIN) =
                                        '656925561529384c6847c88021053266'
                                THEN
                                   (SELECT FDFECPARAPAGO
                                      FROM FACTURACIONPAGOS H
                                     WHERE     H.IDGASTOMAIN = A.IDGASTOMAIN
                                           AND H.FNCONSEC = 6)
                             END FECPAGO,
                             (SELECT FCREFERDYN  FROM FACTURACIONPAGOS DD WHERE  DD.IDGASTOMAIN = A.IDGASTOMAIN AND FNCONSEC = 2) REFERENCIA
                        FROM FACTURACIONMAIN A
                       WHERE     FDDYNAMICSGASTO IS NULL
                             AND IDFORMAPAGO = queCheque
                             AND FNIMPORTEANTICIPO > 0
                             AND (   FNIMPORTEANTICIPO IS NOT NULL
                                  OR FNIMPORTEANTICIPO != '')
                             AND IDGASTOMAIN IN (SELECT ZZ.IDGASTOMAIN
                                                   FROM FACTURACIONBITACORA ZZ
                                                        INNER JOIN
                                                        (  SELECT IDGASTOMAIN,
                                                                  MAX (DEL_INDEX)
                                                                     DONDEESTA
                                                             FROM FACTURACIONBITACORA
                                                         GROUP BY IDGASTOMAIN)
                                                        CC
                                                           ON (    ZZ.IDGASTOMAIN =
                                                                      CC.IDGASTOMAIN
                                                               AND ZZ.DEL_INDEX =
                                                                      CC.DONDEESTA)
                                                  WHERE IDTASKGASTO IN ('2082181485273e6002e4959086601056',
                                                                        '656925561529384c6847c88021053266'))
                             AND IDGASTOMAIN IN (SELECT IDGASTOMAIN
                                                   FROM FACTURACIONPAGOS
                                                  WHERE     FNCONSEC IN (2, 6)
                                                        AND FDFECPAGADO IS NULL)
                             AND CASE
                                    WHEN (   IDEMPRESAFACTURACION = 0
                                          OR IDEMPRESAFACTURACION IS NULL)
                                    THEN
                                       A.IDOTEMPRESAFACTURACION
                                    WHEN (   IDEMPRESAFACTURACION != 0
                                          OR IDEMPRESAFACTURACION IS NOT NULL)
                                    THEN
                                       A.IDEMPRESAFACTURACION
                                 END = pnEmpFact) SAIDA
            ORDER BY FECPAGO;
      --             ORDER BY FDDYNAMICSGASTO DESC;

      END IF;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getChequesReembolso;

   PROCEDURE getTransReembolso (salida IN OUT T_CURSOR, pnEmpFact INTEGER)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;
   BEGIN
      OPEN procesa FOR
           SELECT *
             FROM (SELECT DISTINCT
                          IDGASTOMAIN GASTO,
                          PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN)
                             CONCEPTO,
                          IDPROVEEDORDEPOSITO QUIESES,
                          FCASIGNADEPOSITO AQUIEN,
                          (SELECT "nombreCompleto"
                             FROM PENDUPM.VISTAASOCIADOS
                            WHERE "cvetra" = FNNUMEMPLEADO)
                             SOLICITANTE,
                          (SELECT "status"
                             FROM PENDUPM.VISTAASOCIADOS
                            WHERE "cvetra" = FNNUMEMPLEADO)
                             STATUSEMP,
                          FNIMPORTESOLICITADO TOTAL,
                          --                 CASE WHEN (FNIMPORTEANTICIPO > 0 AND (FNIMPORTEANTICIPO IS NOT NULL OR FNIMPORTEANTICIPO != '')) THEN FNIMPORTEANTICIPO
                          --                      WHEN (FNIMPORTEREEMBOLSO > 0 AND (FNIMPORTEREEMBOLSO IS NOT NULL OR FNIMPORTEREEMBOLSO != '')) THEN FNIMPORTEREEMBOLSO
                          --                 END ANTICIPO,
                          CASE
                             WHEN (SELECT IDTASKGASTO
                                     FROM FACTURACIONBITACORA XX
                                    WHERE     XX.IDGASTOMAIN = A.IDGASTOMAIN
                                          AND xx.DEL_INDEX = A.DELINDEX_ETAPA) =
                                     '656925561529384c6847c88021053266'
                             THEN
                                FNIMPORTEREEMBOLSO
                             ELSE
                                FNIMPORTEANTICIPO
                          END
                             ANTICIPO,
                          CASE
                             WHEN FCSEVERIDADGASTO NOT IN ('Normal', 'Urgente')
                             THEN
                                PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA)
                             ELSE
                                FCSEVERIDADGASTO
                          END
                             URGENCIA,
                             '<B>'
                          || CASE
                                WHEN (SELECT IDTASKGASTO
                                        FROM FACTURACIONBITACORA XX
                                       WHERE     XX.IDGASTOMAIN = A.IDGASTOMAIN
                                             AND xx.DEL_INDEX =
                                                    A.DELINDEX_ETAPA) =
                                        '656925561529384c6847c88021053266'
                                THEN
                                   'Reembolso'
                                ELSE
                                   'Anticipo'
                             END
                          || ' </B>'
                          || NVL (
                                CASE
                                   WHEN IDEMPRESAFACTURACION = 0
                                   THEN
                                      (SELECT NMEMPRESA
                                         FROM EMPRESAFACTURACION D
                                        WHERE D.IDEMPRESA =
                                                 A.IDOTEMPRESAFACTURACION)
                                   WHEN (   IDEMPRESAFACTURACION != 0
                                         OR IDEMPRESAFACTURACION IS NOT NULL)
                                   THEN
                                      (SELECT NMEMPRESA
                                         FROM EMPRESAFACTURACION D
                                        WHERE D.IDEMPRESA =
                                                 A.IDEMPRESAFACTURACION)
                                   WHEN (   IDEMPRESAFACTURACION IS NULL
                                         OR IDEMPRESAFACTURACION = '')
                                   THEN
                                      'SIN EMPRESA DE FACTURACION'
                                END,
                                'SIN EMPRESA DE FACTURACION')
                             EMPFACT,
                          NVL (
                             CASE
                                WHEN IDEMPRESAFACTURACION = 0
                                THEN
                                   (SELECT FNIMPCOMISION
                                      FROM EMPRESAFACTURACION D
                                     WHERE D.IDEMPRESA =
                                              A.IDOTEMPRESAFACTURACION)
                                WHEN (   IDEMPRESAFACTURACION != 0
                                      OR IDEMPRESAFACTURACION IS NOT NULL)
                                THEN
                                   (SELECT FNIMPCOMISION
                                      FROM EMPRESAFACTURACION D
                                     WHERE D.IDEMPRESA = A.IDEMPRESAFACTURACION)
                                WHEN (   IDEMPRESAFACTURACION IS NULL
                                      OR IDEMPRESAFACTURACION = '')
                                THEN
                                   -1
                             END,
                             -1)
                             COMISIONCHEQUE,
                          CASE
                             WHEN FCTIPOCUENTA = '1' THEN 'Fiscal'
                             ELSE 'No Fiscal'
                          END
                             TPOCUENTA,
                          CASE
                             WHEN (SELECT ZZ.IDTASKGASTO
                                     FROM FACTURACIONBITACORA ZZ
                                          INNER JOIN
                                          (  SELECT IDGASTOMAIN,
                                                    MAX (DEL_INDEX) DONDEESTA
                                               FROM FACTURACIONBITACORA
                                           GROUP BY IDGASTOMAIN) CC
                                             ON (    ZZ.IDGASTOMAIN =
                                                        CC.IDGASTOMAIN
                                                 AND ZZ.DEL_INDEX =
                                                        CC.DONDEESTA)
                                    WHERE     IDTASKGASTO IN ('2082181485273e6002e4959086601056',
                                                              '656925561529384c6847c88021053266')
                                          AND ZZ.IDGASTOMAIN = A.IDGASTOMAIN) =
                                     '2082181485273e6002e4959086601056'
                             THEN
                                (SELECT FDFECPARAPAGO
                                   FROM FACTURACIONPAGOS H
                                  WHERE     H.IDGASTOMAIN = A.IDGASTOMAIN
                                        AND H.FNCONSEC = 2)
                             WHEN (SELECT ZZ.IDTASKGASTO
                                     FROM FACTURACIONBITACORA ZZ
                                          INNER JOIN
                                          (  SELECT IDGASTOMAIN,
                                                    MAX (DEL_INDEX) DONDEESTA
                                               FROM FACTURACIONBITACORA
                                           GROUP BY IDGASTOMAIN) CC
                                             ON (    ZZ.IDGASTOMAIN =
                                                        CC.IDGASTOMAIN
                                                 AND ZZ.DEL_INDEX =
                                                        CC.DONDEESTA)
                                    WHERE     IDTASKGASTO IN ('2082181485273e6002e4959086601056',
                                                              '656925561529384c6847c88021053266')
                                          AND ZZ.IDGASTOMAIN = A.IDGASTOMAIN) =
                                     '656925561529384c6847c88021053266'
                             THEN
                                (SELECT FDFECPARAPAGO
                                   FROM FACTURACIONPAGOS H
                                  WHERE     H.IDGASTOMAIN = A.IDGASTOMAIN
                                        AND H.FNCONSEC = 6)
                          END FECPAGO,
                          (SELECT FCREFERDYN  FROM FACTURACIONPAGOS DD WHERE  DD.IDGASTOMAIN = A.IDGASTOMAIN AND FNCONSEC = 2) REFERENCIA
                     FROM FACTURACIONMAIN A
                    WHERE     FDDYNAMICSGASTO IS NULL
                          AND IDFORMAPAGO = 36
                          AND (FNIMPORTEANTICIPO > 0 OR FNIMPORTEREEMBOLSO > 0)
--                          AND (   FNIMPORTEANTICIPO IS NOT NULL
--                               OR FNIMPORTEANTICIPO != '')
                          AND IDGASTOMAIN IN (SELECT ZZ.IDGASTOMAIN
                                                FROM FACTURACIONBITACORA ZZ
                                                     INNER JOIN
                                                     (  SELECT IDGASTOMAIN,
                                                               MAX (DEL_INDEX)
                                                                  DONDEESTA
                                                          FROM FACTURACIONBITACORA
                                                      GROUP BY IDGASTOMAIN) CC
                                                        ON (    ZZ.IDGASTOMAIN =
                                                                   CC.IDGASTOMAIN
                                                            AND ZZ.DEL_INDEX =
                                                                   CC.DONDEESTA)
                                               WHERE IDTASKGASTO IN ('2082181485273e6002e4959086601056',
                                                                     '656925561529384c6847c88021053266','4515947455273e63c4198f0073790158'))
                          AND IDGASTOMAIN IN (SELECT IDGASTOMAIN
                                                FROM FACTURACIONPAGOS
                                               WHERE     FNCONSEC IN (2, 6)
                                                     AND FDFECPAGADO IS NULL)
                          AND CASE
                                 WHEN (   IDEMPRESAFACTURACION = 0
                                       OR IDEMPRESAFACTURACION IS NULL)
                                 THEN
                                    A.IDOTEMPRESAFACTURACION
                                 WHEN (   IDEMPRESAFACTURACION != 0
                                       OR IDEMPRESAFACTURACION IS NOT NULL)
                                 THEN
                                    A.IDEMPRESAFACTURACION
                              END = pnEmpFact) SAIDA
         ORDER BY FECPAGO;

      --         ORDER BY FDDYNAMICSGASTO DESC;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getTransReembolso;

   PROCEDURE getCIEReembolso (salida IN OUT T_CURSOR, pnEmpFact INTEGER)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;
   BEGIN
      OPEN procesa FOR
           SELECT *
             FROM (SELECT DISTINCT
                          IDGASTOMAIN GASTO,
                          PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN)
                             CONCEPTO,
                          IDPROVEEDORDEPOSITO QUIESES,
                          FCASIGNADEPOSITO AQUIEN,
                          CASE
                             WHEN     TPOMOVIMIENTO = 'Anticipo'
                                  AND (SELECT COUNT (1)
                                         FROM FACTURACIONPAGOS X
                                        WHERE     IDGASTOMAIN = A.IDGASTOMAIN
                                              AND FNCONSEC = 2
                                              AND FNIMPORTE > 0
                                              AND FDFECPAGADO IS NULL) > 0
                             THEN
                                'AN'
                             WHEN     TPOMOVIMIENTO = 'Reembolso'
                                  AND (SELECT COUNT (1)
                                         FROM FACTURACIONPAGOS X
                                        WHERE     IDGASTOMAIN = A.IDGASTOMAIN
                                              AND FNCONSEC = 6
                                              AND FNIMPORTE > 0
                                              AND FDFECPAGADO IS NULL) > 0
                             THEN
                                'RE'
                             WHEN     TPOMOVIMIENTO = 'Tramite'
                                  AND (SELECT COUNT (1)
                                         FROM FACTURACIONPAGOS X
                                        WHERE     IDGASTOMAIN = A.IDGASTOMAIN
                                              AND FNCONSEC = 2
                                              AND FNIMPORTE > 0
                                              AND FDFECPAGADO IS NULL) > 0
                             THEN
                                'AN'
                             WHEN     TPOMOVIMIENTO = 'Tramite'
                                  AND (SELECT COUNT (1)
                                         FROM FACTURACIONPAGOS X
                                        WHERE     IDGASTOMAIN = A.IDGASTOMAIN
                                              AND FNCONSEC = 6
                                              AND FNIMPORTE > 0
                                              AND FDFECPAGADO IS NULL) > 0
                             THEN
                                'RE'
                          END
                             TIPOMOVTO,
                          NMPROVEEDOR,
                          (SELECT "nombreCompleto"
                             FROM PENDUPM.VISTAASOCIADOS
                            WHERE "cvetra" = FNNUMEMPLEADO)
                             SOLICITANTE,
                          (SELECT "status"
                             FROM PENDUPM.VISTAASOCIADOS
                            WHERE "cvetra" = FNNUMEMPLEADO)
                             STATUSEMP,
                          FNIMPORTESOLICITADO TOTAL,
                          CASE
                             WHEN (SELECT IDTASKGASTO
                                     FROM FACTURACIONBITACORA XX
                                    WHERE     XX.IDGASTOMAIN = A.IDGASTOMAIN
                                          AND xx.DEL_INDEX = A.DELINDEX_ETAPA) =
                                     '656925561529384c6847c88021053266'
                             THEN
                                FNIMPORTEREEMBOLSO
                             ELSE
                                FNIMPORTEANTICIPO
                          END
                             ANTICIPO,
                          --                     CASE WHEN FNIMPORTEANTICIPO > 0 AND (SELECT COUNT(1) FROM FACTURACIONPAGOS H WHERE H.IDGASTOMAIN = A.IDGASTOMAIN AND FNCONSEC = 2 AND FDFECPAGADO IS NULL) = 1 THEN FNIMPORTEANTICIPO
                          --                          WHEN FNIMPORTEREEMBOLSO > 0 AND (SELECT COUNT(1) FROM FACTURACIONPAGOS H WHERE H.IDGASTOMAIN = A.IDGASTOMAIN AND FNCONSEC = 6 AND FDFECPAGADO IS NULL) = 1 THEN FNIMPORTEREEMBOLSO
                          --                          ELSE -1 END ANTICIPO,
                          CASE
                             WHEN FCSEVERIDADGASTO NOT IN ('Normal', 'Urgente')
                             THEN
                                PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA)
                             ELSE
                                FCSEVERIDADGASTO
                          END
                             URGENCIA,
                             '<B>'
                          || CASE
                                WHEN (SELECT IDTASKGASTO
                                        FROM FACTURACIONBITACORA XX
                                       WHERE     XX.IDGASTOMAIN = A.IDGASTOMAIN
                                             AND xx.DEL_INDEX =
                                                    A.DELINDEX_ETAPA) =
                                        '656925561529384c6847c88021053266'
                                THEN
                                   'Reembolso'
                                ELSE
                                   'Anticipo'
                             END
                          || ' </B>'
                          || NVL (
                                CASE
                                   WHEN IDEMPRESAFACTURACION = 0
                                   THEN
                                      (SELECT NMEMPRESA
                                         FROM EMPRESAFACTURACION D
                                        WHERE D.IDEMPRESA =
                                                 A.IDOTEMPRESAFACTURACION)
                                   WHEN (   IDEMPRESAFACTURACION != 0
                                         OR IDEMPRESAFACTURACION IS NOT NULL)
                                   THEN
                                      (SELECT NMEMPRESA
                                         FROM EMPRESAFACTURACION D
                                        WHERE D.IDEMPRESA =
                                                 A.IDEMPRESAFACTURACION)
                                   WHEN (   IDEMPRESAFACTURACION IS NULL
                                         OR IDEMPRESAFACTURACION = '')
                                   THEN
                                      'SIN EMPRESA DE FACTURACION'
                                END,
                                'SIN EMPRESA DE FACTURACION')
                             EMPFACT,
                          NVL (
                             CASE
                                WHEN IDEMPRESAFACTURACION = 0
                                THEN
                                   (SELECT FNIMPCOMISION
                                      FROM EMPRESAFACTURACION D
                                     WHERE D.IDEMPRESA =
                                              A.IDOTEMPRESAFACTURACION)
                                WHEN (   IDEMPRESAFACTURACION != 0
                                      OR IDEMPRESAFACTURACION IS NOT NULL)
                                THEN
                                   (SELECT FNIMPCOMISION
                                      FROM EMPRESAFACTURACION D
                                     WHERE D.IDEMPRESA = A.IDEMPRESAFACTURACION)
                                WHEN (   IDEMPRESAFACTURACION IS NULL
                                      OR IDEMPRESAFACTURACION = '')
                                THEN
                                   -1
                             END,
                             -1)
                             COMISIONCHEQUE,
                          CASE
                             WHEN FCTIPOCUENTA = '1' THEN 'Fiscal'
                             ELSE 'No Fiscal'
                          END
                             TPOCUENTA,
                          CASE
                             WHEN (SELECT ZZ.IDTASKGASTO
                                     FROM FACTURACIONBITACORA ZZ
                                          INNER JOIN
                                          (  SELECT IDGASTOMAIN,
                                                    MAX (DEL_INDEX) DONDEESTA
                                               FROM FACTURACIONBITACORA
                                           GROUP BY IDGASTOMAIN) CC
                                             ON (    ZZ.IDGASTOMAIN =
                                                        CC.IDGASTOMAIN
                                                 AND ZZ.DEL_INDEX =
                                                        CC.DONDEESTA)
                                    WHERE     IDTASKGASTO IN ('2082181485273e6002e4959086601056',
                                                              '656925561529384c6847c88021053266')
                                          AND ZZ.IDGASTOMAIN = A.IDGASTOMAIN) =
                                     '2082181485273e6002e4959086601056'
                             THEN
                                (SELECT TO_CHAR(FDFECPARAPAGO,'DD-Mon-YY','nls_date_language=Spanish') FDFECPARAPAGO
                                   FROM FACTURACIONPAGOS H
                                  WHERE     H.IDGASTOMAIN = A.IDGASTOMAIN
                                        AND H.FNCONSEC = 2)
                             WHEN (SELECT ZZ.IDTASKGASTO
                                     FROM FACTURACIONBITACORA ZZ
                                          INNER JOIN
                                          (  SELECT IDGASTOMAIN,
                                                    MAX (DEL_INDEX) DONDEESTA
                                               FROM FACTURACIONBITACORA
                                           GROUP BY IDGASTOMAIN) CC
                                             ON (    ZZ.IDGASTOMAIN =
                                                        CC.IDGASTOMAIN
                                                 AND ZZ.DEL_INDEX =
                                                        CC.DONDEESTA)
                                    WHERE     IDTASKGASTO IN ('2082181485273e6002e4959086601056',
                                                              '656925561529384c6847c88021053266')
                                          AND ZZ.IDGASTOMAIN = A.IDGASTOMAIN) =
                                     '656925561529384c6847c88021053266'
                             THEN
                                (SELECT TO_CHAR(FDFECPARAPAGO,'DD-Mon-YY','nls_date_language=Spanish') FDFECPARAPAGO
                                   FROM FACTURACIONPAGOS H
                                  WHERE     H.IDGASTOMAIN = A.IDGASTOMAIN
                                        AND H.FNCONSEC = 6)
                          END  FECPAGO,
                          (SELECT FCREFERDYN  FROM FACTURACIONPAGOS DD WHERE  DD.IDGASTOMAIN = A.IDGASTOMAIN AND FNCONSEC = CASE TPOMOVIMIENTO WHEN 'Anticipo' THEN 2 ELSE 6 END) REFERENCIA,
                          (SELECT REPLACE(COMPR.FCARCHIVOPDF, 'http://quantum1.pendulum.com.mx/sysworkflow/es/classic/cases/cases_ShowGastosComp.php?archivo=','http://doc.pendulum.com.mx/PM/gastos/comprobacion/') FCARCHIVOPDF
                                FROM PENDUPM.FACTURACIONCOMPROBA COMPR
                                WHERE COMPR.IDGASTOMAIN = A.IDGASTOMAIN AND ROWNUM = 1) FCARCHIVOPDF,
                          (SELECT LISTAGG(ANEX.FCRUTAFILE, '|') WITHIN GROUP (ORDER BY IDCONSEC) AS ANEXOS FROM PENDUPM.FACTURACIONANEXOS ANEX WHERE IDGASTOMAIN = A.IDGASTOMAIN GROUP BY IDGASTOMAIN) ANEXOS
                     FROM FACTURACIONMAIN A
                    WHERE     IDFORMAPAGO = 40
                          AND FCSTATUS = 'D'
                          AND (   (    (    FNIMPORTEANTICIPO > 0
                                        AND FDDYNAMICSGASTO IS NULL)
                                   AND (   FNIMPORTEANTICIPO IS NOT NULL
                                        OR FNIMPORTEANTICIPO != ''))
                               OR (    (    FNIMPORTEREEMBOLSO > 0
                                        AND FDDYNAMICSREEMB IS NULL)
                                   AND (   FNIMPORTEREEMBOLSO IS NOT NULL
                                        OR FNIMPORTEREEMBOLSO != '')))
                          AND IDGASTOMAIN IN (SELECT ZZ.IDGASTOMAIN
                                                FROM FACTURACIONBITACORA ZZ
                                                     INNER JOIN
                                                     (  SELECT IDGASTOMAIN,
                                                               MAX (DEL_INDEX)
                                                                  DONDEESTA
                                                          FROM FACTURACIONBITACORA
                                                      GROUP BY IDGASTOMAIN) CC
                                                        ON (    ZZ.IDGASTOMAIN =
                                                                   CC.IDGASTOMAIN
                                                            AND ZZ.DEL_INDEX =
                                                                   CC.DONDEESTA)
                                               WHERE IDTASKGASTO IN ('2082181485273e6002e4959086601056',
                                                                     '656925561529384c6847c88021053266'))
                          AND IDGASTOMAIN IN (SELECT IDGASTOMAIN
                                                FROM FACTURACIONPAGOS
                                               WHERE     FNCONSEC IN (2, 6)
                                                     AND FDFECPAGADO IS NULL)
                          AND CASE
                                 WHEN (   IDEMPRESAFACTURACION = 0
                                       OR IDEMPRESAFACTURACION IS NULL)
                                 THEN
                                    A.IDOTEMPRESAFACTURACION
                                 WHEN (   IDEMPRESAFACTURACION != 0
                                       OR IDEMPRESAFACTURACION IS NOT NULL)
                                 THEN
                                    A.IDEMPRESAFACTURACION
                              END = pnEmpFact) SAIDA
         ORDER BY FECPAGO;

      --         ORDER BY FDDYNAMICSGASTO DESC;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getCIEReembolso;

   PROCEDURE setDoctoSoporte (pnCaso             INTEGER,
                              quienSolic         INTEGER,
                              psCadenaEjecuta    VARCHAR2,
                              psIdTask           VARCHAR2 DEFAULT '1',
                              psDelindex         INTEGER DEFAULT 1)
   IS
      hayUmbrales       INTEGER := 0;
      hayPgodup         INTEGER := 0;
      hayEtapaProc      INTEGER := 0;
      idConcepto        INTEGER := 0;
      idConcepto        NUMBER (12, 2) := 0;
      importeTOT        NUMBER (12, 2) := 0;
      importeIVA        NUMBER (12, 2) := 0;
      importeNETO       NUMBER (12, 2) := 0;
      esPgoDbl          CHAR (1) := NULL;
      vsError           VARCHAR2 (4000) := NULL;
      vdEmailPgo        VARCHAR2 (80) := NULL;
      vdEmailPgo1       VARCHAR2 (80) := NULL;
      vsValorPaso       VARCHAR2 (20) := NULL;
      vsValorPaso1      VARCHAR2 (20) := NULL;
      umbral1           NUMBER (10, 2) := NULL;
      umbral2           NUMBER (10, 2) := NULL;
      umbral1a          NUMBER (10, 2) := NULL;
      umbral2a          NUMBER (10, 2) := NULL;
      vcEmailUmb        VARCHAR2 (80) := NULL;
      vcEmailUmb1       VARCHAR2 (80) := NULL;
      vcEmailUmb2       VARCHAR2 (80) := NULL;
      etapaClose        VARCHAR2 (150) := NULL;
      etapaopen         VARCHAR2 (50) := NULL;
      vdEmailTapa       VARCHAR2 (80) := NULL;
      vdEmailTapa1      VARCHAR2 (80) := NULL;
      queelemento       INTEGER := 0;
      existeEtapas      INTEGER := 0;
      existeMonto       INTEGER := 0;
      numConsec         INTEGER := 0;
      tipoAlerta        INTEGER := 0;
      jefeInmediato     VARCHAR (80) := '';
      umbralMaximo      INTEGER := 0;
      consecutivo       INTEGER := 1;
      psErrorD          VARCHAR2 (80) := NULL;
      existeJefeInmed   INTEGER := 0;

      CURSOR cuConcepto
      IS
         SELECT *
           FROM CTCATALOGOCUENTAS
          WHERE     IDCONCEPTO IN (SELECT IDCONCEPTO
                                     FROM FACTURADCSOPORTE
                                    WHERE IDGASTOMAIN = pnCaso)
                AND FCDOCUMENTOSOPORTE IS NOT NULL;

      CURSOR cuUmbral
      IS
         SELECT DISTINCT FNUMBRAL CUALUMBRAL
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnCaso;
   BEGIN
      DELETE FACTURACIONAUT
       WHERE     IDGASTOMAIN = pnCaso
             AND IDTASKPM = psIdTask
             AND IDDELINDEX = psDelindex
             AND IDTIPOAUTORIZA = 41
             AND FCRESULTADO IS NULL;

      DBMS_OUTPUT.PUT_LINE ('borrooooooo');

      BEGIN
         SELECT NVL (MAX (IDCONSEC), 0) + 1
           INTO consecutivo
           FROM FACTURACIONAUT
          WHERE IDGASTOMAIN = pnCaso;
      EXCEPTION
         WHEN OTHERS
         THEN
            consecutivo := 1;
      END;

      DBMS_OUTPUT.PUT_LINE ('consecutivo ....' || consecutivo);

      FOR alerta IN cuConcepto
      LOOP
         ---- ****  VERIFICACION DOCUMENTOS DE SOPORTE*****

         DBMS_OUTPUT.PUT_LINE (
               'entre concepto '
            || alerta.NMCONCEPTO
            || '*****'
            || alerta.IDCONCEPTO);
         DBMS_OUTPUT.PUT_LINE (
               'tipoverif01 '
            || alerta.TIPOVERIFFINAL01
            || '****'
            || 'verif01 '
            || alerta.TIPOVERIFFINAL01);

         vdEmailPgo := NULL;

         IF (    (   alerta.TIPOVERIFFINAL01 = 'E'
                  OR INSTR (alerta.FCVERIFFINAL01, '@') > 0)
             AND alerta.FCVERIFFINAL01 IS NOT NULL)
         THEN
            vdEmailPgo := alerta.FCVERIFFINAL01;
         END IF;

         IF (    (alerta.TIPOVERIFFINAL01 = 'T')
             AND (   alerta.FCVERIFFINAL01 IS NOT NULL
                  OR alerta.FCVERIFFINAL01 != ''))
         THEN
            vdEmailPgo :=
               PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                  alerta.FCVERIFFINAL01);
         END IF;

         IF (    (alerta.TIPOVERIFFINAL01 = 'P')
             AND (   alerta.FCVERIFFINAL01 IS NOT NULL
                  OR alerta.FCVERIFFINAL01 != ''))
         THEN
            vdEmailPgo :=
               PCKFACTURACIONGASTO.queCorreoAutoriza (pnCaso,
                                                      alerta.FCVERIFFINAL01);
         END IF;

         IF ( (vdEmailPgo IS NOT NULL OR vdEmailPgo != ''))
         THEN
            DBMS_OUTPUT.PUT_LINE (' ES 41 -- ' || vdEmailPgo);

            SELECT COUNT (1)
              INTO existeJefeInmed
              FROM FACTURACIONAUT
             WHERE     IDGASTOMAIN = pnCaso
                   AND FCAUTORIZADOR = vdEmailPgo
                   AND IDTIPOAUTORIZA = 41
                   AND IDTASKPM = psIdTask
                   AND IDDELINDEX = psDelindex;

            IF (existeJefeInmed = 0)
            THEN
               UPDATE FACTURADCSOPORTE
                  SET FCUSUARIO01 =
                         PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                WHERE IDGASTOMAIN = pnCaso;

               INSERT INTO FACTURACIONAUT
                    VALUES (pnCaso,
                            vdEmailPgo,
                            41,
                            consecutivo,
                            'DOC SOPORTE',
                            SYSDATE,
                            NULL,
                            quienSolic,
                            NULL,
                            NULL,
                            NULL,
                            NULL,
                            psIdTask,
                            psDelindex,
                            NULL,
                            NULL);

               consecutivo := consecutivo + 1;
            END IF;
         END IF;

         vdEmailPgo := NULL;

         IF (    (   alerta.TIPOVERIFFINAL02 = 'E'
                  OR INSTR (alerta.FCVERIFFINAL02, '@') > 0)
             AND alerta.FCVERIFFINAL02 IS NOT NULL)
         THEN
            vdEmailPgo := alerta.FCVERIFFINAL02;
         END IF;

         IF (    (alerta.TIPOVERIFFINAL02 = 'T')
             AND (   alerta.FCVERIFFINAL02 IS NOT NULL
                  OR alerta.FCVERIFFINAL02 != ''))
         THEN
            vdEmailPgo :=
               PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                  alerta.FCVERIFFINAL02);
         END IF;

         IF (    (alerta.TIPOVERIFFINAL02 = 'P')
             AND (   alerta.FCVERIFFINAL02 IS NOT NULL
                  OR alerta.FCVERIFFINAL02 != ''))
         THEN
            vdEmailPgo :=
               PCKFACTURACIONGASTO.queCorreoAutoriza (pnCaso,
                                                      alerta.FCVERIFFINAL02);
         END IF;

         IF ( (vdEmailPgo IS NOT NULL OR vdEmailPgo != ''))
         THEN
            DBMS_OUTPUT.PUT_LINE (' ES 41 -- ' || vdEmailPgo);

            SELECT COUNT (1)
              INTO existeJefeInmed
              FROM FACTURACIONAUT
             WHERE     IDGASTOMAIN = pnCaso
                   AND FCAUTORIZADOR = vdEmailPgo
                   AND IDTIPOAUTORIZA = 41
                   AND IDTASKPM = psIdTask
                   AND IDDELINDEX = psDelindex;

            IF (existeJefeInmed = 0)
            THEN
               UPDATE FACTURADCSOPORTE
                  SET FCUSUARIO02 =
                         PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                WHERE IDGASTOMAIN = pnCaso;

               INSERT INTO FACTURACIONAUT
                    VALUES (pnCaso,
                            vdEmailPgo,
                            41,
                            consecutivo,
                            'DOC SOPORTE',
                            SYSDATE,
                            NULL,
                            quienSolic,
                            NULL,
                            NULL,
                            NULL,
                            NULL,
                            psIdTask,
                            psDelindex,
                            NULL,
                            NULL);

               consecutivo := consecutivo + 1;
            END IF;
         END IF;

         vdEmailPgo := NULL;

         IF (    (   alerta.TIPOVERIFFINAL03 = 'E'
                  OR INSTR (alerta.FCVERIFFINAL03, '@') > 0)
             AND alerta.FCVERIFFINAL03 IS NOT NULL)
         THEN
            vdEmailPgo := alerta.FCVERIFFINAL03;
         END IF;

         IF (    (alerta.TIPOVERIFFINAL03 = 'T')
             AND (   alerta.FCVERIFFINAL03 IS NOT NULL
                  OR alerta.FCVERIFFINAL03 != ''))
         THEN
            vdEmailPgo :=
               PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                  alerta.FCVERIFFINAL03);
         END IF;

         IF (    (alerta.TIPOVERIFFINAL03 = 'P')
             AND (   alerta.FCVERIFFINAL03 IS NOT NULL
                  OR alerta.FCVERIFFINAL03 != ''))
         THEN
            vdEmailPgo :=
               PCKFACTURACIONGASTO.queCorreoAutoriza (pnCaso,
                                                      alerta.FCVERIFFINAL03);
         END IF;

         IF ( (vdEmailPgo IS NOT NULL OR vdEmailPgo != ''))
         THEN
            DBMS_OUTPUT.PUT_LINE (' ES 41 -- ' || vdEmailPgo);

            SELECT COUNT (1)
              INTO existeJefeInmed
              FROM FACTURACIONAUT
             WHERE     IDGASTOMAIN = pnCaso
                   AND FCAUTORIZADOR = vdEmailPgo
                   AND IDTIPOAUTORIZA = 41
                   AND IDTASKPM = psIdTask
                   AND IDDELINDEX = psDelindex;

            IF (existeJefeInmed = 0)
            THEN
               UPDATE FACTURADCSOPORTE
                  SET FCUSUARIO03 =
                         PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                WHERE IDGASTOMAIN = pnCaso;

               INSERT INTO FACTURACIONAUT
                    VALUES (pnCaso,
                            vdEmailPgo,
                            41,
                            consecutivo,
                            'DOC SOPORTE',
                            SYSDATE,
                            NULL,
                            quienSolic,
                            NULL,
                            NULL,
                            NULL,
                            NULL,
                            psIdTask,
                            psDelindex,
                            NULL,
                            NULL);

               consecutivo := consecutivo + 1;
            END IF;
         END IF;
      END LOOP;

      SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

      INSERT INTO BITACORATRANSACCION
           VALUES (pnCaso,
                   queelemento,
                   psCadenaEjecuta,
                   SYSDATE,
                   SYSDATE,
                   '0');

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         vsError := SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('** ERROR ** ' || SQLERRM);
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         INSERT INTO BITACORATRANSACCION
              VALUES (pnCaso,
                      queelemento,
                      psCadenaEjecuta,
                      SYSDATE,
                      SYSDATE,
                      psErrorD);

         COMMIT;
   END setDoctoSoporte;


   PROCEDURE getEmpresaFact (salida IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;
   BEGIN
      OPEN procesa FOR
           SELECT IDEMPRESA, NMEMPRESA, FCCUENTA
             FROM EMPRESAFACTURACION
            WHERE FCSTATUS = 'A'
         ORDER BY NMEMPRESA ASC;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getEmpresaFact;

   PROCEDURE getEmpresaFactChq (pnEmpresa  INTEGER, salida IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;
   BEGIN
      OPEN procesa FOR
           SELECT FCCUENTA IDEMPRESA, FCCUENTA
             FROM EMPFACTURADETALLE
          WHERE IDEMPRESA = pnEmpresa AND FCSTATUS = 'A'
         ORDER BY FCCUENTA DESC;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getEmpresaFactChq;

   PROCEDURE setUmbralTramite (pnCaso             INTEGER,
                               quienSolic         INTEGER,
                               psCadenaEjecuta    VARCHAR2,
                               psIdTask           VARCHAR2 DEFAULT '1',
                               psDelindex         INTEGER DEFAULT 1)
   IS
      hayUmbrales       INTEGER := 0;
      hayPgodup         INTEGER := 0;
      hayEtapaProc      INTEGER := 0;
      idConcepto        INTEGER := 0;
      idConcepto        NUMBER (12, 2) := 0;
      importeTOT        NUMBER (12, 2) := 0;
      importeIVA        NUMBER (12, 2) := 0;
      importeNETO       NUMBER (12, 2) := 0;
      esPgoDbl          CHAR (1) := NULL;
      vsError           VARCHAR2 (4000) := NULL;
      vdEmailPgo        VARCHAR2 (80) := NULL;
      vdEmailPgo1       VARCHAR2 (80) := NULL;
      vsValorPaso       VARCHAR2 (20) := NULL;
      vsValorPaso1      VARCHAR2 (20) := NULL;
      umbral1           NUMBER (10, 2) := NULL;
      umbral2           NUMBER (10, 2) := NULL;
      umbral1a          NUMBER (10, 2) := NULL;
      umbral2a          NUMBER (10, 2) := NULL;
      vcEmailUmb        VARCHAR2 (80) := NULL;
      vcEmailUmb1       VARCHAR2 (80) := NULL;
      vcEmailUmb2       VARCHAR2 (80) := NULL;
      etapaClose        VARCHAR2 (150) := NULL;
      etapaopen         VARCHAR2 (50) := NULL;
      vdEmailTapa       VARCHAR2 (80) := NULL;
      vdEmailTapa1      VARCHAR2 (80) := NULL;
      queelemento       INTEGER := 0;
      existeEtapas      INTEGER := 0;
      existeMonto       INTEGER := 0;
      numConsec         INTEGER := 0;
      tipoAlerta        INTEGER := 0;
      jefeInmediato     VARCHAR (80) := '';
      umbralMaximo      INTEGER := 0;
      consecutivo       INTEGER := 1;
      impFacturado      NUMBER (10, 2) := 0;
      psErrorD          VARCHAR2 (500) := '';
      pnconcepto        INTEGER := 0;
      existeJefeInmed   INTEGER := 0;
      cualEsElError     VARCHAR2 (500) := '0';
      hayError          INTEGER := 0;
      delIndexSel       INTEGER := 1;

      CURSOR cuConcepto
      IS
         SELECT *
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO IN (SELECT DISTINCT IDCONCEPTO
                                 FROM FACTURACIONMAIN
                                WHERE IDGASTOMAIN = pnCaso);

      CURSOR cuUmbral (
         psConcepto    INTEGER)
      IS
         SELECT DISTINCT
                FCCREDITOCARTERA,
                FCQUEUMBRAL CUALUMBRAL,
                FNUMBRALREBASADO REBASADO
           FROM FACTURAASIGNACION
          WHERE     IDGASTOMAIN = pnCaso
                AND IDCONCEPTO = psConcepto
                AND FCQUEUMBRAL > 0;
   BEGIN

      SELECT NVL(MAX(IDDELINDEX),1)
        INTO delIndexSel 
        FROM PENDUPM.FACTURACIONAUT 
       WHERE IDGASTOMAIN = pnCaso AND FCRESULTADO IS NULL;   
   
      DELETE FACTURACIONAUT
       WHERE     IDGASTOMAIN = pnCaso
             AND IDTASKPM = psIdTask
             AND IDDELINDEX = delIndexSel AND IDTIPOAUTORIZA = 6;

      --- limpia los campos para ls nuevas actualizaciones y su procesamiento
      UPDATE FACTURAASIGNACION
         SET FCUSUUMBRAL03 = NULL, FCUSUUMBRAL04 = NULL, FCUSUUMBRAL05 = NULL
       WHERE IDGASTOMAIN = pnCaso;

      SELECT DISTINCT FNIMPTRAFACT
        INTO impFacturado
        FROM FACTURACIONMAIN
       WHERE IDGASTOMAIN = pnCaso;

      SELECT IDCONCEPTO
        INTO pnconcepto
        FROM FACTURACIONMAIN
       WHERE     FDFECREGISTRO = (SELECT MIN (FDFECREGISTRO)
                                    FROM FACTURACIONMAIN
                                   WHERE IDGASTOMAIN = pnCaso)
             AND IDGASTOMAIN = pnCaso;

      BEGIN
         SELECT NVL (MAX (IDCONSEC), 0) + 0
           INTO consecutivo
           FROM FACTURACIONAUT
          WHERE IDGASTOMAIN = pnCaso;
      EXCEPTION
         WHEN OTHERS
         THEN
            consecutivo := 1;
      END;

      FOR alerta IN cuConcepto
      LOOP
         ---- **** UMBRALES *****       facturacionmain
         DBMS_OUTPUT.PUT_LINE ('*CONCEPTO*' || alerta.IDCONCEPTO || '**');

         FOR regUmbral IN cuUmbral (alerta.IDCONCEPTO)
         LOOP
            DBMS_OUTPUT.PUT_LINE ('*UMBRAL*' || regUmbral.CUALUMBRAL || '**');

            IF regUmbral.CUALUMBRAL >= 1
            THEN
               vdEmailPgo := NULL;

               IF (    alerta.FCTIPOAUTMTO01 = 'E'
                   AND alerta.AUTMONTO01 IS NOT NULL)
               THEN
                  vdEmailPgo := alerta.AUTMONTO01;
               END IF;

               IF (    alerta.FCTIPOAUTMTO01 = 'T'
                   AND alerta.AUTMONTO01 IS NOT NULL)
               THEN
                  vdEmailPgo :=
                     PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                        alerta.AUTMONTO01);
               END IF;

               IF (    alerta.FCTIPOAUTMTO01 = 'P'
                   AND alerta.AUTMONTO01 IS NOT NULL)
               THEN
                  vdEmailPgo := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, alerta.AUTMONTO01);
               END IF;

               IF (vdEmailPgo IS NOT NULL)
               THEN
                  SELECT COUNT (1)
                    INTO existeJefeInmed
                    FROM FACTURACIONAUT
                   WHERE     IDGASTOMAIN = pnCaso
                         AND FCAUTORIZADOR = vdEmailPgo
                         AND IDTIPOAUTORIZA = 6
                         AND IDTASKPM = psIdTask
                         AND IDDELINDEX = delIndexSel;

                  IF (existeJefeInmed = 0)
                  THEN
                     UPDATE FACTURAASIGNACION
                        SET FCUSUUMBRAL03 =
                               PCKFACTURACIONGASTO.queUsuarioMail (
                                  vdEmailPgo)
                      WHERE IDGASTOMAIN = pnCaso AND FCQUEUMBRAL >= 1;

                     INSERT INTO FACTURACIONAUT
                          VALUES (pnCaso,
                                  vdEmailPgo,
                                  6,
                                  consecutivo,
                                  regUmbral.FCCREDITOCARTERA,
                                  SYSDATE,
                                  NULL,
                                  quienSolic,
                                  NULL,
                                  NULL,
                                  NULL,
                                  NULL,
                                  psIdTask,
                                  delIndexSel,
                                  NULL,
                                  NULL);

                     consecutivo := consecutivo + 1;
                  END IF;

                  vdEmailPgo := NULL;
               END IF;
            END IF;
            
            IF regUmbral.CUALUMBRAL >= 2
            THEN
               vdEmailPgo := NULL;

               IF (    alerta.FCTIPOAUTMTO02 = 'E'
                   AND alerta.AUTMONTO02 IS NOT NULL)
               THEN
                  vdEmailPgo := alerta.AUTMONTO02;
               END IF;

               IF (    alerta.FCTIPOAUTMTO02 = 'T'
                   AND alerta.AUTMONTO02 IS NOT NULL)
               THEN
                  vdEmailPgo :=
                     PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                        alerta.AUTMONTO02);
               END IF;

               IF (    alerta.FCTIPOAUTMTO02 = 'P'
                   AND alerta.AUTMONTO02 IS NOT NULL)
               THEN
                  vdEmailPgo := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, alerta.AUTMONTO02);
               END IF;

               IF (vdEmailPgo IS NOT NULL)
               THEN
                  DBMS_OUTPUT.PUT_LINE ('*correo*' || vdEmailPgo || '**');

                  SELECT COUNT (1)
                    INTO existeJefeInmed
                    FROM FACTURACIONAUT
                   WHERE     IDGASTOMAIN = pnCaso
                         AND FCAUTORIZADOR = vdEmailPgo
                         AND IDTIPOAUTORIZA = 6
                         AND IDTASKPM = psIdTask
                         AND IDDELINDEX = delIndexSel;

                  IF (existeJefeInmed = 0)
                  THEN
                     DBMS_OUTPUT.PUT_LINE ('*agregar*' || vdEmailPgo || '**');

                     UPDATE FACTURAASIGNACION
                        SET FCUSUUMBRAL04 =
                               PCKFACTURACIONGASTO.queUsuarioMail (
                                  vdEmailPgo)
                      WHERE IDGASTOMAIN = pnCaso AND FCQUEUMBRAL >= 2;

                     INSERT INTO FACTURACIONAUT
                          VALUES (pnCaso,
                                  vdEmailPgo,
                                  6,
                                  consecutivo,
                                  regUmbral.FCCREDITOCARTERA,
                                  SYSDATE,
                                  NULL,
                                  quienSolic,
                                  NULL,
                                  NULL,
                                  NULL,
                                  NULL,
                                  psIdTask,
                                  delIndexSel,
                                  NULL,
                                  NULL);

                     consecutivo := consecutivo + 1;
                  END IF;

                  vdEmailPgo := NULL;
               END IF;
            END IF;
            
            IF regUmbral.CUALUMBRAL >= 3
            THEN
               vdEmailPgo := NULL;

               IF (    alerta.FCTIPOAUTMTO03 = 'E'
                   AND alerta.AUTMONTO03 IS NOT NULL)
               THEN
                  vdEmailPgo := alerta.AUTMONTO03;
               END IF;

               IF (    alerta.FCTIPOAUTMTO03 = 'T'
                   AND alerta.AUTMONTO03 IS NOT NULL)
               THEN
                  vdEmailPgo :=
                     PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                        alerta.AUTMONTO03);
               END IF;

               IF (    alerta.FCTIPOAUTMTO03 = 'P'
                   AND alerta.AUTMONTO03 IS NOT NULL)
               THEN
                  vdEmailPgo := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, alerta.AUTMONTO03);
               END IF;
            ELSE
               vdEmailPgo := NULL;
            END IF;

            DBMS_OUTPUT.PUT_LINE (
               ' ES 6 -- ' || vdEmailPgo || ' --- ' || regUmbral.CUALUMBRAL);

            IF (vdEmailPgo IS NOT NULL)
            THEN
               IF (regUmbral.CUALUMBRAL >= 3)
               THEN
                  SELECT COUNT (1)
                    INTO existeJefeInmed
                    FROM FACTURACIONAUT
                   WHERE     IDGASTOMAIN = pnCaso
                         AND FCAUTORIZADOR = vdEmailPgo
                         AND IDTIPOAUTORIZA = 6
                         AND IDTASKPM = psIdTask
                         AND IDDELINDEX = delIndexSel;

                  IF (existeJefeInmed = 0)
                  THEN
                     UPDATE FACTURAASIGNACION
                        SET FCUSUUMBRAL05 =
                               PCKFACTURACIONGASTO.queUsuarioMail (
                                  vdEmailPgo)
                      WHERE IDGASTOMAIN = pnCaso AND FCQUEUMBRAL >= 3;

                     INSERT INTO FACTURACIONAUT
                          VALUES (pnCaso,
                                  vdEmailPgo,
                                  6,
                                  consecutivo,
                                  regUmbral.FCCREDITOCARTERA,
                                  SYSDATE,
                                  NULL,
                                  quienSolic,
                                  NULL,
                                  NULL,
                                  NULL,
                                  NULL,
                                  psIdTask,
                                  delIndexSel,
                                  NULL,
                                  NULL);

                     consecutivo := consecutivo + 1;
                  END IF;

                  vdEmailPgo := NULL;
/*
                  IF (    alerta.FCTIPOAUTMTO03A = 'E'
                      AND alerta.AUTMONTO03A IS NOT NULL)
                  THEN
                     vdEmailPgo := alerta.AUTMONTO03A;
                  END IF;

                  IF (    alerta.FCTIPOAUTMTO03A = 'T'
                      AND alerta.AUTMONTO03A IS NOT NULL)
                  THEN
                     vdEmailPgo :=
                        PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                           alerta.AUTMONTO03A);
                  END IF;

                  IF (    alerta.FCTIPOAUTMTO03A = 'P'
                      AND alerta.AUTMONTO03A IS NOT NULL)
                  THEN
                     vdEmailPgo :=
                        PCKFACTURACIONGASTO.QUECORREONIVELES (
                           pnCaso,
                           alerta.AUTMONTO03A);
                  END IF;

                  IF (vdEmailPgo IS NOT NULL)
                  THEN
                     SELECT COUNT (1)
                       INTO existeJefeInmed
                       FROM FACTURACIONAUT
                      WHERE     IDGASTOMAIN = pnCaso
                            AND FCAUTORIZADOR = vdEmailPgo
                            AND IDTIPOAUTORIZA = 6
                            AND IDTASKPM = psIdTask
                            AND IDDELINDEX = delIndexSel;

                     IF (existeJefeInmed = 0)
                     THEN
                        UPDATE FACTURAASIGNACION
                           SET FCUSUUMBRAL04 =
                                  PCKFACTURACIONGASTO.queUsuarioMail (
                                     vdEmailPgo)
                         WHERE IDGASTOMAIN = pnCaso AND FCQUEUMBRAL = 3;

                        INSERT INTO FACTURACIONAUT
                             VALUES (pnCaso,
                                     vdEmailPgo,
                                     6,
                                     consecutivo,
                                     regUmbral.FCCREDITOCARTERA,
                                     SYSDATE,
                                     NULL,
                                     quienSolic,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     psIdTask,
                                     psDelindex,
                                     NULL,
                                     NULL);

                        consecutivo := consecutivo + 1;
                     END IF;

                     vdEmailPgo := NULL;
                  END IF;
*//*
                  IF (    alerta.FCTIPOAUTMTO03B = 'E'
                      AND alerta.AUTMONTO03B IS NOT NULL)
                  THEN
                     vdEmailPgo := alerta.AUTMONTO03B;
                  END IF;

                  IF (    alerta.FCTIPOAUTMTO03B = 'T'
                      AND alerta.AUTMONTO03B IS NOT NULL)
                  THEN
                     vdEmailPgo :=
                        PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                           alerta.AUTMONTO03B);
                  END IF;

                  IF (    alerta.FCTIPOAUTMTO03B = 'P'
                      AND alerta.AUTMONTO03B IS NOT NULL)
                  THEN
                     vdEmailPgo :=
                        PCKFACTURACIONGASTO.queCorreoAutoriza (
                           pnCaso,
                           alerta.AUTMONTO03B);
                  END IF;

                  IF (vdEmailPgo IS NOT NULL)
                  THEN
                     SELECT COUNT (1)
                       INTO existeJefeInmed
                       FROM FACTURACIONAUT
                      WHERE     IDGASTOMAIN = pnCaso
                            AND FCAUTORIZADOR = vdEmailPgo
                            AND IDTIPOAUTORIZA = 6
                            AND IDTASKPM = psIdTask
                            AND IDDELINDEX = psDelindex;

                     IF (existeJefeInmed = 0)
                     THEN
                        UPDATE FACTURAASIGNACION
                           SET FCUSUUMBRAL05 =
                                  PCKFACTURACIONGASTO.queUsuarioMail (
                                     vdEmailPgo)
                         WHERE IDGASTOMAIN = pnCaso AND FCQUEUMBRAL = 3;

                        INSERT INTO FACTURACIONAUT
                             VALUES (pnCaso,
                                     vdEmailPgo,
                                     6,
                                     consecutivo,
                                     regUmbral.FCCREDITOCARTERA,
                                     SYSDATE,
                                     NULL,
                                     quienSolic,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     psIdTask,
                                     psDelindex,
                                     NULL,
                                     NULL);

                        consecutivo := consecutivo + 1;
                     END IF;

                     vdEmailPgo := NULL;
                  END IF;
  */             
               END IF;
            END IF;
         END LOOP;
      END LOOP;

      --- VERIFICA QUE NO EXISTAN DATOS DE AUTORIZADORES ERRONEOS
      SELECT COUNT (1)
        INTO hayError
        FROM FACTURACIONAUT
       WHERE IDGASTOMAIN = pnCaso AND FCAUTORIZADOR = '**ERROR**';

      IF (hayError > 0)
      THEN
         cualEsElError := '*ERROR* Hay Info Erronea en Autorizadores';
         ROLLBACK;
      ELSE
         cualEsElError := '0';
      END IF;

      ---- INSERTA EL DETALLE DE LA TRANSACCION
      SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

      INSERT INTO BITACORATRANSACCION
           VALUES (pnCaso,
                   queelemento,
                   psCadenaEjecuta,
                   SYSDATE,
                   SYSDATE,
                   cualEsElError);

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         vsError := SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('** ERROR ** ' || SQLERRM);
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

         INSERT INTO BITACORATRANSACCION
              VALUES (pnCaso,
                      queelemento,
                      psCadenaEjecuta,
                      SYSDATE,
                      SYSDATE,
                      psErrorD);

         COMMIT;
   END setUmbralTramite;



   PROCEDURE setDoctoExcGtoEtaFinal (pnCaso             INTEGER,
                                     quienSolic         INTEGER,
                                     psCadenaEjecuta    VARCHAR2,
                                     psIdTask           VARCHAR2 DEFAULT '1',
                                     psDelindex         INTEGER DEFAULT 1,
                                     donde              VARCHAR2, /* COMPROBACION  / TRAMITE */
                                     queProcesa         VARCHAR2)
   IS                                            /* Anticipo  /  Reembolso  */
      hayUmbrales       INTEGER := 0;
      hayPgodup         INTEGER := 0;
      hayEtapaProc      INTEGER := 0;
      idConcepto        INTEGER := 0;
      idConcepto        NUMBER (12, 2) := 0;
      importeTOT        NUMBER (12, 2) := 0;
      importeIVA        NUMBER (12, 2) := 0;
      importeNETO       NUMBER (12, 2) := 0;
      esPgoDbl          CHAR (1) := NULL;
      vsError           VARCHAR2 (4000) := NULL;
      cadena1           VARCHAR2 (4000) := NULL;
      vdEmailPgo        VARCHAR2 (80) := NULL;
      vdEmailPgo1       VARCHAR2 (80) := NULL;
      vsValorPaso       VARCHAR2 (20) := NULL;
      vsValorPaso1      VARCHAR2 (20) := NULL;
      umbral1           NUMBER (10, 2) := NULL;
      umbral2           NUMBER (10, 2) := NULL;
      umbral1a          NUMBER (10, 2) := NULL;
      umbral2a          NUMBER (10, 2) := NULL;
      vcEmailUmb        VARCHAR2 (80) := NULL;
      vcEmailUmb1       VARCHAR2 (80) := NULL;
      vcEmailUmb2       VARCHAR2 (80) := NULL;
      etapaClose        VARCHAR2 (150) := NULL;
      etapaopen         VARCHAR2 (50) := NULL;
      vdEmailTapa       VARCHAR2 (80) := NULL;
      vdEmailTapa1      VARCHAR2 (80) := NULL;
      queTipoJuicio     NUMBER (5) := '';
      queEtapaCRAVER    VARCHAR2 (1000) := '';
      ubica             INTEGER := 0;
      queelemento       INTEGER := 0;
      existeEtapas      INTEGER := 0;
      existeMonto       INTEGER := 0;
      numConsec         INTEGER := 0;
      tipoAlerta        INTEGER := 0;
      valor             INTEGER := 0;
      contador          INTEGER := 0;
      hayJuicioCred     INTEGER := 0;
      jefeInmediato     VARCHAR (80) := '';
      umbralMaximo      INTEGER := 0;
      consecutivo       INTEGER := 1;
      impFacturado      NUMBER (10, 2) := 0;
      psErrorD          VARCHAR2 (500) := '';
      pnconcepto        INTEGER := 0;
      existeJefeInmed   INTEGER := 0;
      montoMaximo       NUMBER (12, 2) := 0;
      montoAnticipo     NUMBER (12, 2) := 0;
      montoComprobado   NUMBER (12, 2) := 0;
      queConceptoEs     INTEGER := 0;
      queTipoDemanda    NUMBER (5) := '';

      CURSOR cuConcepto (cualEs INTEGER)
      IS
         SELECT *
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = cualEs;

      CURSOR cuUmbral (
         psConcepto    INTEGER)
      IS
         SELECT DISTINCT
                FCCREDITOCARTERA,
                FCQUEUMBRAL CUALUMBRAL,
                FNUMBRALREBASADO REBASADO
           FROM FACTURAASIGNACION
          WHERE IDCONCEPTO = psConcepto AND FCQUEUMBRAL > 0;

      CURSOR cuQueAsignacion
      IS
           SELECT *
             FROM FACTURAASIGNACION
            WHERE IDGASTOMAIN = pnCaso
         ORDER BY IDCONCEPTO, IDTIPOMOVTO, FCCREDITOCARTERA;

      CURSOR cuEtapaCrraVerif (
         psjuicio    INTEGER,
         psEtapa     VARCHAR2)
      IS
           SELECT *
             FROM OPERACION.VW_ELP_ETAPAS_LEGALES
            WHERE     NUMERO_JUICIO = psjuicio
                  AND EN_PROCESO = 0
                  AND FECHA_TERMINO IS NOT NULL
                  AND RESULTADO_VERIFICACION = 'CORRECTO'
                  AND NUMERO_ETAPA = psEtapa
                  AND ORDEN =
                         (SELECT MAX (ORDEN)
                            FROM OPERACION.VW_ELP_ETAPAS_LEGALES
                           WHERE     NUMERO_JUICIO = psjuicio
                                 AND EN_PROCESO = 0
                                 AND FECHA_TERMINO IS NOT NULL
                                 AND NUMERO_ETAPA = psEtapa)
         ORDER BY ORDEN DESC;

      CURSOR cuJuicios (tpoDem NUMBER, queCredito VARCHAR2)
      IS
         SELECT CCCASENO, CCCASENO CCCASENODESC, CCACCT CREDITO
           FROM RCVRY.CASEACCT
          WHERE     CCACCT = queCredito
                AND CCCASENO IN (SELECT CECASENO
                                   FROM RCVRY.CASE
                                  WHERE CESTATUS = 'A')
                AND CCCASENO IN (SELECT NUMERO
                                   FROM OPERACION.ELP_JUICIO
                                  WHERE ID_TIPO_DEMANDA = tpoDem);
   BEGIN
      DELETE FACTURACIONAUT
       WHERE     IDGASTOMAIN = pnCaso
             AND IDTASKPM = psIdTask
             AND IDDELINDEX = psDelindex
             AND IDTIPOAUTORIZA IN (41, 44, 45);

      --- limpia los campos para ls nuevas actualizaciones y su procesamiento
      UPDATE FACTURAASIGNACION
         SET FCUSUEXCGASTO01 = NULL,
             FCUSUEXCGASTO02 = NULL,
             FCUSUETAFINAL01 = NULL,
             FCUSUETAFINAL02 = NULL
       WHERE IDGASTOMAIN = pnCaso;

      --- OBTIENE LOS DATOS DE EL MONTO MAXIMO Y DEL MONTO COMPROBADO
      SELECT DISTINCT
             (SELECT FNIMPORTE
                FROM FACTURACIONPAGOS FP
               WHERE FP.IDGASTOMAIN = A.IDGASTOMAIN AND FNCONSEC = 1),
             FNIMPORTEANTICIPO
        INTO montoMaximo, montoAnticipo
        FROM FACTURACIONMAIN A
       WHERE A.IDGASTOMAIN = pnCaso;

      SELECT SUM (FNIMPORTE)
        INTO montoComprobado
        FROM FACTURACIONCOMPROBA
       WHERE IDGASTOMAIN = pnCaso;

      SELECT MAX (IDCONCEPTO)
        INTO queConceptoEs
        FROM FACTURACIONMAIN
       WHERE IDGASTOMAIN = pnCaso;

      ---- Completa de acuerdo al tipo de tramite y su forma como se pago
      IF (donde = 'TRAMITE')
      THEN
         UPDATE FACTURACIONMAIN
            SET FCPAGOADICIONAL = queProcesa
          WHERE IDGASTOMAIN = pnCaso;
      END IF;

      SELECT DISTINCT FNIMPTRAFACT
        INTO impFacturado
        FROM FACTURACIONMAIN
       WHERE IDGASTOMAIN = pnCaso;

      SELECT IDCONCEPTO
        INTO pnconcepto
        FROM FACTURACIONMAIN
       WHERE     FDFECREGISTRO = (SELECT MIN (FDFECREGISTRO)
                                    FROM FACTURACIONMAIN
                                   WHERE IDGASTOMAIN = pnCaso)
             AND IDGASTOMAIN = pnCaso;

      BEGIN
         SELECT NVL (MAX (IDCONSEC), 0) + 1
           INTO consecutivo
           FROM FACTURACIONAUT
          WHERE IDGASTOMAIN = pnCaso;
      EXCEPTION
         WHEN OTHERS
         THEN
            consecutivo := 1;
      END;

      --     FCESTRUCTURACONCEPTO


      IF (donde = 'COMPROBACION')
      THEN
         ---- **** Arma Detalle de ls Auutorizaciones de Excedentes de Gastos ****
         FOR alerta IN cuConcepto (queConceptoEs)
         LOOP
            vdEmailPgo := NULL;

            IF (    montoComprobado > (montoMaximo + 5)
                AND montoComprobado > (montoAnticipo  + 5) )
            THEN
               IF (    alerta.TPOAUTEXCEDGSTO01 = 'E'
                   AND alerta.AUTEXCEDGSTO01 IS NOT NULL)
               THEN
                  vdEmailPgo := alerta.AUTEXCEDGSTO01;
               END IF;

               IF (alerta.TPOAUTEXCEDGSTO01 = 'T')
               THEN
                  vdEmailPgo :=
                     PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                        alerta.AUTEXCEDGSTO01);
               END IF;

               IF (    alerta.TPOAUTEXCEDGSTO01 = 'P'
                   AND alerta.AUTEXCEDGSTO01 IS NOT NULL)
               THEN
                  -- vdEmailPgo := PCKFACTURACIONGASTO.queCorreoAutoriza (pnCaso,alerta.AUTEXCEDGSTO01);
                  vdEmailPgo := queCorreoNiveles( quienSolic , alerta.AUTEXCEDGSTO01 );
               END IF;

               IF (vdEmailPgo IS NOT NULL)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUEXCGASTO01 =
                            PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                   WHERE IDGASTOMAIN = pnCaso;

                  INSERT INTO FACTURACIONAUT
                       VALUES (pnCaso,
                               vdEmailPgo,
                               44,
                               consecutivo,
                               'AUTORIZA EXCEDENTE GASTO',
                               SYSDATE,
                               NULL,
                               quienSolic,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               psIdTask,
                               psDelindex,
                               NULL,
                               NULL);

                  consecutivo := consecutivo + 1;
               END IF;

               vdEmailPgo := NULL;

               IF (    alerta.TPOAUTEXCEDGSTO02 = 'E'
                   AND alerta.AUTEXCEDGSTO02 IS NOT NULL)
               THEN
                  vdEmailPgo := alerta.AUTEXCEDGSTO02;
               END IF;

               IF (alerta.TPOAUTEXCEDGSTO02 = 'T')
               THEN
                  vdEmailPgo :=
                     PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                        alerta.AUTEXCEDGSTO02);
               END IF;

               IF (    alerta.TPOAUTEXCEDGSTO02 = 'P'
                   AND alerta.AUTEXCEDGSTO02 IS NOT NULL)
               THEN
                  -- vdEmailPgo := PCKFACTURACIONGASTO.queCorreoAutoriza ( pnCaso, alerta.AUTEXCEDGSTO02);
                  vdEmailPgo := queCorreoNiveles( quienSolic , alerta.AUTEXCEDGSTO02 );
               END IF;

               IF (vdEmailPgo IS NOT NULL)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUEXCGASTO02 =
                            PCKFACTURACIONGASTO.queUsuarioMail (vdEmailPgo)
                   WHERE IDGASTOMAIN = pnCaso;

                  INSERT INTO FACTURACIONAUT
                       VALUES (pnCaso,
                               vdEmailPgo,
                               44,
                               consecutivo,
                               'AUTORIZA EXCEDENTE GASTO',
                               SYSDATE,
                               NULL,
                               quienSolic,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               psIdTask,
                               psDelindex,
                               NULL,
                               NULL);

                  consecutivo := consecutivo + 1;
               END IF;
            END IF;

            DBMS_OUTPUT.PUT_LINE (' ** ENTRO EXCEDENTE COMPROBACION ');
         END LOOP;
      END IF;

      --- Solo Verifica que no aplique cuando sea anticipo
      IF (queProcesa != 'Anticipo')
      THEN
         ---- **** Arma Detalle de ls Auutorizaciones de Cierre de Etapa Cerrada Final ****  CTCATALOGOCUENTAS  VERETAPACDACHKFIN
         FOR regAsignacion IN cuQueAsignacion
         LOOP
            DBMS_OUTPUT.PUT_LINE (' ** ASIGNACION ETAPA FINAL ');

            FOR alerta IN cuConcepto (regAsignacion.IDCONCEPTO)
            LOOP
               DBMS_OUTPUT.PUT_LINE (
                  ' ** CONCEPTO ETAPA FINAL ' || alerta.VERETAPACDACHKFIN);

               IF (alerta.VERETAPACDACHKFIN IS NOT NULL)
               THEN
                  queEtapaCRAVER := '';

                  DBMS_OUTPUT.PUT_LINE (' ** ENTRO ETAPAS FINALES ');

                  ---- **** ETAPAS PROCESALES Y CODIGOS DE ACCION *****
                  SELECT COUNT (1)
                    INTO hayJuicioCred
                    FROM RCVRY.CASEACCT
                   WHERE     CCACCT = regAsignacion.FCCREDITOCARTERA
                         AND CCCASENO IN (SELECT CECASENO
                                            FROM RCVRY.CASE
                                           WHERE CESTATUS = 'A')
                         AND CCCASENO IN (SELECT NUMERO
                                            FROM OPERACION.ELP_JUICIO
                                           WHERE ID_TIPO_DEMANDA = 2);

                  IF (hayJuicioCred = 0)
                  THEN
                     queEtapaCRAVER :=
                        queEtapaCRAVER || 'NO TIENEN JUICIOS ACTIVOS<BR/>';

                     IF (    alerta.FCTIPOAUTETAPA01 = 'E'
                         AND alerta.AUTETAPA01 IS NOT NULL)
                     THEN
                        vdEmailPgo := alerta.AUTETAPA01;
                     END IF;
                     DBMS_OUTPUT.PUT_LINE (' ** ENTRO ETAPAS FINALES  EMPLEADO '||vdEmailPgo);
                     IF (alerta.FCTIPOAUTETAPA01 = 'T')
                     THEN
                        vdEmailPgo :=
                           PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                              alerta.AUTETAPA01);
                     END IF;
                     DBMS_OUTPUT.PUT_LINE (' ** ENTRO ETAPAS FINALES  PUESTO '||vdEmailPgo);
                     IF (    alerta.FCTIPOAUTETAPA01 = 'P'
                         AND (   alerta.AUTETAPA01 IS NOT NULL
                              OR alerta.AUTETAPA02 != ''))
                     THEN
                        vdEmailPgo :=
                           PCKFACTURACIONGASTO.queCorreoAutoriza (
                              pnCaso,
                              alerta.AUTETAPA01);
                     END IF;
                     DBMS_OUTPUT.PUT_LINE (' ** ENTRO ETAPAS FINALES  NIVEL '||vdEmailPgo);
                     IF ( (vdEmailPgo IS NOT NULL OR vdEmailPgo != ''))
                     THEN
                        DBMS_OUTPUT.PUT_LINE (
                           ' ES FINA SINJ UICIOS 01 -- ' || vdEmailPgo);

                        SELECT COUNT (1)
                          INTO existeJefeInmed
                          FROM FACTURACIONAUT
                         WHERE     IDGASTOMAIN = pnCaso
                               AND FCAUTORIZADOR = vdEmailPgo
                               AND IDTIPOAUTORIZA = 45
                               AND IDTASKPM = psIdTask
                               AND IDDELINDEX = psDelindex;

                        IF (existeJefeInmed = 0)
                        THEN
                           UPDATE FACTURAASIGNACION
                              SET FCUSUETAFINAL01 =
                                     PCKFACTURACIONGASTO.queUsuarioMail (
                                        vdEmailPgo)
                            WHERE     IDGASTOMAIN = pnCaso
                                  AND IDCONCEPTO = regAsignacion.IDCONCEPTO
                                  AND FCCREDITOCARTERA =
                                         regAsignacion.FCCREDITOCARTERA;

                           INSERT INTO FACTURACIONAUT
                                VALUES (pnCaso,
                                        vdEmailPgo,
                                        45,
                                        consecutivo,
                                        'ETAPA PROC FINAL',
                                        SYSDATE,
                                        NULL,
                                        quienSolic,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL,
                                        psIdTask,
                                        psDelindex,
                                        NULL,
                                        NULL);

                           consecutivo := consecutivo + 1;
                        END IF;
                     END IF;

                     vdEmailPgo := NULL;

                     IF (    alerta.FCTIPOAUTETAPA02 = 'E'
                         AND (   alerta.AUTETAPA02 IS NOT NULL
                              OR alerta.AUTETAPA02 != ''))
                     THEN
                        vdEmailPgo := alerta.AUTETAPA02;
                     END IF;

                     IF (alerta.FCTIPOAUTETAPA02 = 'T')
                     THEN
                        vdEmailPgo :=
                           PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                              alerta.AUTETAPA02);
                     END IF;

                     IF (    alerta.FCTIPOAUTETAPA02 = 'P'
                         AND (   alerta.AUTETAPA02 IS NOT NULL
                              OR alerta.AUTETAPA02 <> ''))
                     THEN
                        DBMS_OUTPUT.PUT_LINE ('***ENTRO PUES 45B');
                        vdEmailPgo :=
                           PCKFACTURACIONGASTO.queCorreoAutoriza (
                              pnCaso,
                              alerta.AUTETAPA02);
                     END IF;

                     IF ( (vdEmailPgo IS NOT NULL OR vdEmailPgo <> ''))
                     THEN
                        DBMS_OUTPUT.PUT_LINE (
                              ' ES 7b -- '
                           || vdEmailPgo
                           || ' ** '
                           || alerta.FCTIPOAUTETAPA02
                           || ' ** '
                           || alerta.AUTETAPA02
                           || ';;** ');

                        SELECT COUNT (1)
                          INTO existeJefeInmed
                          FROM FACTURACIONAUT
                         WHERE     IDGASTOMAIN = pnCaso
                               AND FCAUTORIZADOR = vdEmailPgo
                               AND IDTIPOAUTORIZA = 45
                               AND IDTASKPM = psIdTask
                               AND IDDELINDEX = psDelindex;

                        IF (existeJefeInmed = 0)
                        THEN
                           UPDATE FACTURAASIGNACION
                              SET FCUSUETAFINAL02 =
                                     PCKFACTURACIONGASTO.queUsuarioMail (
                                        vdEmailPgo)
                            WHERE     IDGASTOMAIN = pnCaso
                                  AND IDCONCEPTO = regAsignacion.IDCONCEPTO
                                  AND FCCREDITOCARTERA =
                                         regAsignacion.FCCREDITOCARTERA;

                           INSERT INTO FACTURACIONAUT
                                VALUES (pnCaso,
                                        vdEmailPgo,
                                        45,
                                        consecutivo,
                                        'ETAPA PROC FINAL',
                                        SYSDATE,
                                        NULL,
                                        quienSolic,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL,
                                        psIdTask,
                                        psDelindex,
                                        NULL,
                                        NULL);

                           consecutivo := consecutivo + 1;
                        END IF;
                     END IF;

                     consecutivo := consecutivo + 1;
                  END IF;

                  DBMS_OUTPUT.PUT_LINE ( ' hay juicios  -- ' || queEtapaCRAVER);

                  FOR regjuicios
                     IN cuJuicios (2, regAsignacion.FCCREDITOCARTERA)
                  LOOP
                     BEGIN
                        SELECT ID_TIPO_DEMANDA, ID_TIPO_JUICIO
                          INTO queTipoJuicio, queTipoDemanda
                          FROM OPERACION.ELP_JUICIO
                         WHERE NUMERO = regjuicios.CCCASENO;
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           queTipoJuicio := NULL;
                           queTipoDemanda := NULL;
                     END;

                     ---  Barre para Validar las ETAPAS CERADAS Y VERIFICADAS del JUICIO
                     queEtapaCRAVER := '';
                     cadena1 := alerta.VERETAPACDACHKFIN || '|';
                     ubica := INSTR (cadena1, '|');
contador := 0;
                     WHILE (ubica > 0)
                     LOOP
                        valor := SUBSTR (cadena1, 1, ubica - 1);


                        FOR regEtapa
                           IN cuEtapaCrraVerif (regjuicios.CCCASENO, valor)
                        LOOP
                           contador := contador + 1;

                           IF (regEtapa.RESULTADO_VERIFICACION != 'CORRECTO')
                           THEN
                              queEtapaCRAVER :=
                                    queEtapaCRAVER
                                 || 'LA ETAPA ['
                                 || valor
                                 || '] FUE CALIFICADA COMO '
                                 || regEtapa.RESULTADO_VERIFICACION
                                 || ' EL DIA '
                                 || PCKCTRLDOCUMENTAL01.aplFecha (
                                       regEtapa.FECHA_VERIFICACION)
                                 || '<BR/>';
                           END IF;
                        END LOOP;

                        IF (contador = 0)
                        THEN
                           queEtapaCRAVER :=
                                 queEtapaCRAVER
                              || 'LA ETAPA ['
                              || valor
                              || '] NO SE ENCUENTRA CERRADA Y VERIFICADA'
                              || '<BR/>';
                        END IF;

                        ---- Agrega informacion a Factur Asignacion para Completarla
                        UPDATE FACTURAASIGNACION
                           SET VERETAPAFIN = alerta.VERETAPACDACHKFIN,
                               VERETAPAFINVAL = queEtapaCRAVER
                         WHERE     IDGASTOMAIN = pnCaso
                               AND IDCONCEPTO = regAsignacion.IDCONCEPTO
                               AND FCCREDITOCARTERA =
                                      regAsignacion.FCCREDITOCARTERA;

                        ---- **** ETAPAS PROCESALES Y CODIGOS DE ACCION *****   ctcatalogocuentas
                        SELECT COUNT (1) TOTAL
                          INTO existeEtapas
                          FROM FACTURAASIGNACION
                         WHERE     IDGASTOMAIN = pnCaso
                               AND IDCONCEPTO = alerta.IDCONCEPTO
                               AND VERETAPAFINVAL IS NOT NULL;

                        vdEmailPgo := NULL;

                        IF (existeEtapas > 0)
                        THEN
                           DBMS_OUTPUT.PUT_LINE ( ' checa** etapas ** -- ' || existeEtapas);
                           IF (    alerta.FCTIPOAUTETAPA01 = 'E'
                               AND alerta.AUTETAPA01 IS NOT NULL)
                           THEN
                              vdEmailPgo := alerta.AUTETAPA01;
                           END IF;
                           DBMS_OUTPUT.PUT_LINE ( ' checa** etapas EMPLEADO ** -- ' || vdEmailPgo||'-'||alerta.AUTETAPA01 );

                           IF (    alerta.FCTIPOAUTETAPA01 = 'P'
                               AND (   alerta.AUTETAPA01 IS NOT NULL
                                    OR alerta.AUTETAPA02 != ''))
                           THEN
                              vdEmailPgo :=
                                 PCKFACTURACIONGASTO.queCorreoAutoriza (
                                    pnCaso,
                                    alerta.AUTETAPA01);
                           END IF;
                           DBMS_OUTPUT.PUT_LINE ( ' checa** etapas NIVEL ** -- ' || vdEmailPgo||'-'||alerta.AUTETAPA01 );

                           IF (alerta.FCTIPOAUTETAPA01 = 'T')
                           THEN
                              vdEmailPgo :=
                                 PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                                    alerta.AUTETAPA01);
                           END IF;
                           DBMS_OUTPUT.PUT_LINE ( ' checa** etapas PUESTO ** -- ' || vdEmailPgo||'-'||alerta.AUTETAPA01 );

                           IF ( (vdEmailPgo IS NOT NULL OR vdEmailPgo != ''))
                           THEN
                              DBMS_OUTPUT.PUT_LINE (
                                 ' ES 7a -- ' || vdEmailPgo);

                              SELECT COUNT (1)
                                INTO existeJefeInmed
                                FROM FACTURACIONAUT
                               WHERE     IDGASTOMAIN = pnCaso
                                     AND FCAUTORIZADOR = vdEmailPgo
                                     AND IDTIPOAUTORIZA = 45
                                     AND IDTASKPM = psIdTask
                                     AND IDDELINDEX = psDelindex;

                              IF (existeJefeInmed = 0)
                              THEN
                                 DBMS_OUTPUT.PUT_LINE (
                                       ' primer autorizador etapas-- '
                                    || vdEmailPgo);

                                 UPDATE FACTURAASIGNACION
                                    SET FCUSUETAFINAL01 =
                                           PCKFACTURACIONGASTO.queUsuarioMail (
                                              vdEmailPgo)
                                  WHERE     IDGASTOMAIN = pnCaso
                                        AND IDCONCEPTO =
                                               regAsignacion.IDCONCEPTO
                                        AND FCCREDITOCARTERA =
                                               regAsignacion.FCCREDITOCARTERA;

                                 INSERT INTO FACTURACIONAUT
                                      VALUES (pnCaso,
                                              vdEmailPgo,
                                              45,
                                              consecutivo,
                                              'ETAPA PROC FINAL',
                                              SYSDATE,
                                              NULL,
                                              quienSolic,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              psIdTask,
                                              psDelindex,
                                              NULL,
                                              NULL);

                                 consecutivo := consecutivo + 1;
                              END IF;
                           END IF;

                           vdEmailPgo := NULL;

                           IF (    alerta.FCTIPOAUTETAPA02 = 'E'
                               AND (   alerta.AUTETAPA02 IS NOT NULL
                                    OR alerta.AUTETAPA02 != ''))
                           THEN
                              vdEmailPgo := alerta.AUTETAPA02;
                           END IF;

                           IF (alerta.FCTIPOAUTETAPA02 = 'T')
                           THEN
                              vdEmailPgo :=
                                 PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                                    alerta.AUTETAPA02);
                           END IF;

                           IF (    alerta.FCTIPOAUTETAPA02 = 'P'
                               AND (   alerta.AUTETAPA02 IS NOT NULL
                                    OR alerta.AUTETAPA02 <> ''))
                           THEN
                              DBMS_OUTPUT.PUT_LINE ('***ENTRO PUES 45B');
                              vdEmailPgo :=
                                 PCKFACTURACIONGASTO.queCorreoAutoriza (
                                    pnCaso,
                                    alerta.AUTETAPA02);
                           END IF;

                           IF ( (vdEmailPgo IS NOT NULL OR vdEmailPgo <> ''))
                           THEN
                              DBMS_OUTPUT.PUT_LINE (
                                    ' ES 7b -- '
                                 || vdEmailPgo
                                 || ' ** '
                                 || alerta.FCTIPOAUTETAPA02
                                 || ' ** '
                                 || alerta.AUTETAPA02
                                 || ';;** ');

                              SELECT COUNT (1)
                                INTO existeJefeInmed
                                FROM FACTURACIONAUT
                               WHERE     IDGASTOMAIN = pnCaso
                                     AND FCAUTORIZADOR = vdEmailPgo
                                     AND IDTIPOAUTORIZA = 45
                                     AND IDTASKPM = psIdTask
                                     AND IDDELINDEX = psDelindex;

                              IF (existeJefeInmed = 0)
                              THEN
                                 DBMS_OUTPUT.PUT_LINE (
                                       ' SEGUNDO autorizador etapas-- '
                                    || vdEmailPgo);

                                 UPDATE FACTURAASIGNACION
                                    SET FCUSUETAFINAL02 =
                                           PCKFACTURACIONGASTO.queUsuarioMail (
                                              vdEmailPgo)
                                  WHERE     IDGASTOMAIN = pnCaso
                                        AND IDCONCEPTO =
                                               regAsignacion.IDCONCEPTO
                                        AND FCCREDITOCARTERA =
                                               regAsignacion.FCCREDITOCARTERA;

                                 INSERT INTO FACTURACIONAUT
                                      VALUES (pnCaso,
                                              vdEmailPgo,
                                              45,
                                              consecutivo,
                                              'ETAPA PROC FINAL',
                                              SYSDATE,
                                              NULL,
                                              quienSolic,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              psIdTask,
                                              psDelindex,
                                              NULL,
                                              NULL);

                                 consecutivo := consecutivo + 1;
                              END IF;
                           END IF;
                        END IF;

                        cadena1 := SUBSTR (cadena1, ubica + 1);
                        ubica := INSTR (cadena1, '|');
                     END LOOP;                    --//---  WHILE ( ubica > 0 )
                  END LOOP;                               --//--FOR regjuicios
               END IF;  ---//--IF ((regConcepto.VERETAPACDACHKFIN IS NOT NULL)
            END LOOP;                                         --//--FOR alerta
         END LOOP;                                    --//-- FOR regAsignacion
      END IF;

      --- guarda la Transaccionn para validar su Procesamiento
      SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

      INSERT INTO BITACORATRANSACCION
           VALUES (pnCaso,
                   queelemento,
                   psCadenaEjecuta,
                   SYSDATE,
                   SYSDATE,
                   '0');

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         vsError := SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('** ERROR ** ' || SQLERRM);
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

         INSERT INTO BITACORATRANSACCION
              VALUES (pnCaso,
                      queelemento,
                      psCadenaEjecuta,
                      SYSDATE,
                      SYSDATE,
                      psErrorD);

         COMMIT;
   END setDoctoExcGtoEtaFinal;

   PROCEDURE getEmpresaCIE (salida IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;
   BEGIN
      OPEN procesa FOR
           SELECT IDEMPRESA, NMEMPRESA, FCCUENTASERVICIOS FCCUENTA
             FROM EMPRESAFACTURACION
            WHERE FCSTATUS = 'A'
            AND FCCUENTA IS NOT NULL
         ORDER BY NMEMPRESA ASC;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getEmpresaCIE;

   PROCEDURE getArchSPEI (psUsuario VARCHAR2, salida IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa        T_CURSOR;
      cualEs         INTEGER := 0;
      fechaCtrl      VARCHAR2(100) := '';
      empresaCtrl    VARCHAR2(100) := '';
      archivoNm      VARCHAR2(100) := '';
   BEGIN
      SELECT MAX (IDCONTROLLOTE), MAX(FCFECGENCTRL)
        INTO cualEs, fechaCtrl
        FROM FACTSPEIBANCO;
--       WHERE FCUSUARIO = psUsuario;

       --- obtiene datos de la empresa
       SELECT DISTINCT (SELECT FCALIASEMP FROM EMPRESAFACTURACION X
           WHERE A.IDEMPRESA = X.IDEMPRESA)
        INTO empresaCtrl
        FROM FACTURACIONDEPOSITO A
            WHERE FNNUMARCHCONTROL = cualEs AND FCSTATUS = 'A';

        ----arma el nombre del archivo
        archivoNm := TRIM(empresaCtrl)||'_'||fechaCtrl||'_'||cualEs||'.txt';

      OPEN procesa FOR
           SELECT FCDETALLE, archivoNm ARCHIVO
             FROM FACTSPEIBANCO
            WHERE IDCONTROLLOTE = cualEs   /*AND FCUSUARIO = psUsuario*/
         ORDER BY IDCONTROLLOTE, FNORDEN;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getArchSPEI;


   PROCEDURE getArchPOLIZADyn (psUsuario VARCHAR2, salida IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;
      cualEs    INTEGER := 0;
   BEGIN

      DBMS_OUTPUT.PUT_LINE ('>>>> ' || cualEs);

      OPEN procesa FOR
          SELECT  TRIM(FCCUENTACONTABLE)||','||FCCREDITO||','||CASE WHEN FCQUEARCHIVO ='COMPGASTO' THEN TRIM(FCCUENTACONTABLE) ELSE '' END||','||
                  ''''||FCCENTROCOSTOS||','||CAMPO01||','||FCFECHADEPOSITO||','||CAMPO02||','||
                  CAMPO03||','||CAMPO04||','||CAMPO05||','||FNCARGO||','||FNABONO||','||
                  FCREFERENCIA||','||CAMPO06||','||CAMPO07||','||CAMPO08||','||CAMPO09||','||
                  FCRFC||','||FCRAZONSOCIAL DETALLE
             FROM CIRCUITOCONTABLE
            WHERE FCUSUAPLICA = psUsuario
              AND FNBLOQUE = (SELECT MAX(FNBLOQUE) FROM CIRCUITOCONTABLE WHERE FCUSUAPLICA = psUsuario)
              AND (FNCARGO+FNABONO) > 0
           ORDER BY IDGASTOMAIN,FCCREDITO;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getArchPOLIZADyn;

   FUNCTION queConceptoGasto (pnGasto INTEGER)
      RETURN VARCHAR2
   IS
      CURSOR cuConcepto
      IS
         SELECT DISTINCT A.IDCONCEPTO IDCONCEPTO, B.NMCONCEPTO
           FROM FACTURACIONMAIN A
                INNER JOIN CTCATALOGOCUENTAS B
                   ON (A.IDCONCEPTO = B.IDCONCEPTO)
          WHERE A.IDGASTOMAIN = pnGasto
          ORDER BY B.NMCONCEPTO;

      vsSalida   VARCHAR2 (4000) := '';
   BEGIN
      FOR regConcepto IN cuConcepto
      LOOP
         vsSalida := vsSalida || regConcepto.NMCONCEPTO || '<BR/>';
      END LOOP;

      RETURN vsSalida;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN '*ERROR* ' || SQLERRM;
   END queConceptoGasto;

   PROCEDURE getHistGastos (pncualDetalle          INTEGER,
                            salida          IN OUT T_CURSOR,
                            queusuario             INTEGER DEFAULT NULL)
   IS
      queEtapa   VARCHAR2 (70) := '';

      TYPE T_CURSOR IS REF CURSOR;

      procesa    T_CURSOR;
      queQuery   VARCHAR2 (10000) := '';
      otroErr    VARCHAR2 (4000) := '';
   BEGIN
      queQuery :=
            'SELECT IDGASTOMAIN GASTO,
                         PCKFACTURACIONGASTO.queConceptoGasto(IDGASTOMAIN) CONCEPTO,
                         IDPROVEEDORDEPOSITO QUIESES ,
                         NMPROVEEDOR AQUIEN,
                         PCKENVIOCORREO.aplFecha(FDFECREGISTRO) FECREGISTRO,
                        (SELECT "nombreCompleto"
                           FROM PENDUPM.VISTAASOCIADOS
                          WHERE "cvetra" = A.FNNUMEMPLEADO) SOLICITANTE,
                        (SELECT "status"
                           FROM PENDUPM.VISTAASOCIADOS
                          WHERE "cvetra" = A.FNNUMEMPLEADO) STATUSEMP,
                         FNIMPORTESOLICITADO TOTAL,
                         CASE WHEN FNIMPORTEANTICIPO > 0 AND (SELECT COUNT(1) FROM FACTURACIONPAGOS H WHERE H.IDGASTOMAIN = A.IDGASTOMAIN AND FNCONSEC = 2) = 1 THEN FNIMPORTEANTICIPO
                              WHEN FNIMPORTEREEMBOLSO > 0 AND (SELECT COUNT(1) FROM FACTURACIONPAGOS H WHERE H.IDGASTOMAIN = A.IDGASTOMAIN AND FNCONSEC = 6) = 1 THEN FNIMPORTEREEMBOLSO
                              ELSE 0 END  ANTICIPO,
                         CASE WHEN FCSEVERIDADGASTO NOT IN (''Normal'',''Urgente'') THEN  PCKENVIOCORREO.aplFecha(FDFECHAREQUERIDA)
                              ELSE FCSEVERIDADGASTO END URGENCIA,
                     ''<B>''||TPOMOVIMIENTO||'' </B>''||NVL(CASE WHEN IDEMPRESAFACTURACION = 0 THEN (SELECT NMEMPRESA FROM EMPRESAFACTURACION D WHERE D.IDEMPRESA = A.IDOTEMPRESAFACTURACION)
                              WHEN (IDEMPRESAFACTURACION != 0 OR IDEMPRESAFACTURACION IS NOT NULL)  THEN (SELECT NMEMPRESA FROM EMPRESAFACTURACION D WHERE D.IDEMPRESA = A.IDEMPRESAFACTURACION)
                              WHEN (IDEMPRESAFACTURACION IS  NULL OR IDEMPRESAFACTURACION = '''') THEN ''SIN EMPRESA DE FACTURACION''
                         END,''SIN EMPRESA DE FACTURACION'') EMPFACT,
                     NVL(CASE WHEN IDEMPRESAFACTURACION = 0 THEN (SELECT FNIMPCOMISION FROM EMPRESAFACTURACION D WHERE D.IDEMPRESA = A.IDOTEMPRESAFACTURACION)
                              WHEN (IDEMPRESAFACTURACION != 0 OR IDEMPRESAFACTURACION IS NOT NULL)  THEN (SELECT FNIMPCOMISION FROM EMPRESAFACTURACION D WHERE D.IDEMPRESA = A.IDEMPRESAFACTURACION)
                              WHEN (IDEMPRESAFACTURACION IS  NULL OR IDEMPRESAFACTURACION = '''') THEN -1
                         END,-1) COMISIONCHEQUE,
                     CASE WHEN  FCTIPOCUENTA = ''1'' THEN ''Fiscal'' ELSE ''No Fiscal'' END TPOCUENTA
                    FROM FACTURACIONMAIN A WHERE (IDGASTOMAIN,FDFECREGISTRO) IN (SELECT IDGASTOMAIN ,MIN(FDFECREGISTRO) FROM FACTURACIONMAIN WHERE FNNUMEMPLEADO = '
         || queusuario
         || ' GROUP BY IDGASTOMAIN) ';

      IF (pncualDetalle < 15)
      THEN
         SELECT IDTASKGASTO
           INTO queEtapa
           FROM ETAPAFACTURACION
          WHERE FNORDEN = pncualDetalle;

         IF (pncualDetalle = 9 OR pncualDetalle = 11)
         THEN
            queQuery :=
                  queQuery
               || ' AND (A.IDGASTOMAIN, A.APP_UID) IN (SELECT IDGASTOMAIN, APP_UID
                                                                  FROM FACTURACIONBITACORA K
                                                                 WHERE DEL_INDEX = (SELECT MAX(DEL_INDEX)
                                                                                      FROM FACTURACIONBITACORA L
                                                                                     WHERE L.IDGASTOMAIN = K.IDGASTOMAIN
                                                                                    )
                                                                   AND IDTASKGASTO IN (''10516340652ead549865439008696454'',''43704322352eae467857576064357523'')
                                                                )
                         ORDER BY FDFECREGISTRO ASC';
         ELSE
            queQuery :=
                  queQuery
               || ' AND (A.IDGASTOMAIN, A.APP_UID) IN (SELECT IDGASTOMAIN, APP_UID
                                                                  FROM FACTURACIONBITACORA K
                                                                 WHERE DEL_INDEX = (SELECT MAX(DEL_INDEX)
                                                                                      FROM FACTURACIONBITACORA L
                                                                                     WHERE L.IDGASTOMAIN = K.IDGASTOMAIN
                                                                                    )
                                                                   AND IDTASKGASTO = '''
               || queEtapa
               || '''
                                                                )
                         ORDER BY FDFECREGISTRO ASC';
         END IF;
      ELSE
         queQuery :=
               queQuery
            || '  AND FCSTATUS = ''F''
                            ORDER BY FDFECREGISTRO ASC';
      END IF;

      DBMS_OUTPUT.PUT_LINE ('>>>> ' || queQuery);


      OPEN procesa FOR queQuery;


      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         otroErr := SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('>>>> ' || SQLERRM);

         OPEN procesa FOR SELECT 'ERRROR ' || otroErr FROM DUAL;

         salida := procesa;
   END getHistGastos;

   PROCEDURE getMisGestiones (salida       IN OUT T_CURSOR,
                              queusuario          INTEGER DEFAULT NULL)
   IS
      queEtapa   VARCHAR2 (70) := '';

      TYPE T_CURSOR IS REF CURSOR;

      procesa    T_CURSOR;
      queQuery   VARCHAR2 (10000) := '';
      otroErr    VARCHAR2 (4000) := '';
      Korreo     VARCHAR2 (100) := '';
   BEGIN
      SELECT "email"
        INTO Korreo
        FROM PENDUPM.VISTAASOCIADOS
       WHERE "cvetra" = queusuario;

      OPEN procesa FOR
           SELECT A.IDGASTOMAIN GASTO,
                  PCKFACTURACIONGASTO.queConceptoGasto (A.IDGASTOMAIN)
                     QUECONCEPTO,
                  (SELECT "nombreCompleto"
                     FROM PENDUPM.VISTAASOCIADOS
                    WHERE "cvetra" = A.FNNUMEMPLEADO)
                     QUIENSOLICITO,
                  PCKENVIOCORREO.aplFecha (A.FDFECREGISTRO) CUANDOREGISTRO,
                  (SELECT NMTASK
                     FROM ETAPAFACTURACION ET
                    WHERE ET.IDTASKGASTO = UBICACION.IDTASKGASTO)
                     QUEPROCEDE,
                  PCKENVIOCORREO.aplFecha (UBICACION.FDFECREGISTRO) DESDECUANDO,
                     'http://quantum1.pendulum.com.mx/sysworkflow/es/classic/cases/cases_Open?APP_UID='
                  || A.APP_UID
                  || '&'
                  || 'DEL_INDEX='
                  || A.DELINDEX_ETAPA
                     LINKETAPA
             FROM FACTURACIONMAIN A,
                  (SELECT DISTINCT ZZ.IDGASTOMAIN,
                                   DONDEESTA,
                                   FCUSUARIO,
                                   IDTASKGASTO,
                                   FDFECREGISTRO
                     FROM FACTURACIONBITACORA ZZ
                          INNER JOIN
                          (  SELECT IDGASTOMAIN, MAX (DEL_INDEX) DONDEESTA
                               FROM FACTURACIONBITACORA
                           GROUP BY IDGASTOMAIN) CC
                             ON (    ZZ.IDGASTOMAIN = CC.IDGASTOMAIN
                                 AND ZZ.DEL_INDEX = CC.DONDEESTA)) UBICACION
            WHERE     (    A.IDGASTOMAIN = UBICACION.IDGASTOMAIN
                       AND A.DELINDEX_ETAPA = UBICACION.DONDEESTA)
                  AND UBICACION.FCUSUARIO = Korreo
         ORDER BY A.FDFECREGISTRO;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         otroErr := SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('>>>> ' || SQLERRM);

         OPEN procesa FOR SELECT 'ERRROR ' || otroErr FROM DUAL;

         salida := procesa;
   END getMisGestiones;

   PROCEDURE getReasignacion (salida IN OUT T_CURSOR, pnGasto  INTEGER)
   IS
      queEtapa   VARCHAR2 (70) := '';

      TYPE T_CURSOR IS REF CURSOR;

      procesa    T_CURSOR;
      queQuery   VARCHAR2 (10000) := '';
   BEGIN
      OPEN procesa FOR
         SELECT *
           FROM (  SELECT DISTINCT
                          A.IDGASTOMAIN GASTO,
                          PCKFACTURACIONGASTO.queConceptoGasto (A.IDGASTOMAIN)
                             CONCEPTO,
                          IDPROVEEDORDEPOSITO QUIESES,
                          FCASIGNADEPOSITO AQUIEN,
                          PCKENVIOCORREO.aplFecha (FDFECREGISTRO) FDFECREGISTRO,
                          (SELECT "nombreCompleto"
        FROM PENDUPM.VISTAASOCIADOSCOMPLETA
       WHERE "cvetra" in (SELECT max("cvetra") clave
        FROM PENDUPM.VISTAASOCIADOSCOMPLETA
       WHERE "email" = (SELECT FCUSUARIO
        FROM FACTURACIONBITACORA C
        WHERE     C.IDGASTOMAIN =
        A.IDGASTOMAIN
        AND C.DEL_INDEX = B.DELINDEX)))
                             SOLICITANTE,
                          (SELECT "status"
                             FROM PENDUPM.VISTAASOCIADOSCOMPLETA
                            WHERE "cvetra" = FNNUMEMPLEADO)
                             STATUSEMP,
                          FNIMPORTESOLICITADO TOTAL,
                          FNIMPORTEANTICIPO ANTICIPO,
                          CASE
                             WHEN FCSEVERIDADGASTO NOT IN ('Normal', 'Urgente')
                             THEN
                                PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA)
                             ELSE
                                FCSEVERIDADGASTO
                          END
                             URGENCIA,
                             '<B>'
                          || TPOMOVIMIENTO
                          || ' </B>'
                          || NVL (
                                CASE
                                   WHEN IDEMPRESAFACTURACION = 0
                                   THEN
                                      (SELECT NMEMPRESA
                                         FROM EMPRESAFACTURACION D
                                        WHERE D.IDEMPRESA =
                                                 A.IDOTEMPRESAFACTURACION)
                                   WHEN (   IDEMPRESAFACTURACION != 0
                                         OR IDEMPRESAFACTURACION IS NOT NULL)
                                   THEN
                                      (SELECT NMEMPRESA
                                         FROM EMPRESAFACTURACION D
                                        WHERE D.IDEMPRESA =
                                                 A.IDEMPRESAFACTURACION)
                                   WHEN (   IDEMPRESAFACTURACION IS NULL
                                         OR IDEMPRESAFACTURACION = '')
                                   THEN
                                      'SIN EMPRESA DE FACTURACION'
                                END,
                                'SIN EMPRESA DE FACTURACION')
                             EMPFACT,
                          NVL (
                             CASE
                                WHEN IDEMPRESAFACTURACION = 0
                                THEN
                                   (SELECT FNIMPCOMISION
                                      FROM EMPRESAFACTURACION D
                                     WHERE D.IDEMPRESA =
                                              A.IDOTEMPRESAFACTURACION)
                                WHEN (   IDEMPRESAFACTURACION != 0
                                      OR IDEMPRESAFACTURACION IS NOT NULL)
                                THEN
                                   (SELECT FNIMPCOMISION
                                      FROM EMPRESAFACTURACION D
                                     WHERE D.IDEMPRESA = A.IDEMPRESAFACTURACION)
                                WHEN (   IDEMPRESAFACTURACION IS NULL
                                      OR IDEMPRESAFACTURACION = '')
                                THEN
                                   -1
                             END,
                             -1)
                             COMISIONCHEQUE,
                          CASE
                             WHEN FCTIPOCUENTA = '1' THEN 'Fiscal'
                             ELSE 'No Fiscal'
                          END
                             TPOCUENTA,
                          (SELECT NMTASK
                             FROM ETAPAFACTURACION C
                            WHERE C.IDTASKGASTO =
                                     (SELECT IDTASKGASTO
                                        FROM FACTURACIONBITACORA BIT
                                       WHERE     BIT.IDGASTOMAIN =
                                                    B.IDGASTOMAIN
                                             AND BIT.DEL_INDEX = B.DELINDEX))
                             DONDEESTA,
                          B.DELINDEX IDUBICA,
                          (SELECT IDTASKGASTO
                             FROM FACTURACIONBITACORA C
                            WHERE     C.IDGASTOMAIN = A.IDGASTOMAIN
                                  AND C.DEL_INDEX = B.DELINDEX)
                             TSK,
                          A.APP_UID
                     FROM FACTURACIONMAIN A
                          INNER JOIN
                          (  SELECT IDGASTOMAIN,
                                    APP_UID,
                                    MAX (DEL_INDEX) DELINDEX
                               FROM FACTURACIONBITACORA
                              WHERE IDTASKGASTO NOT IN ('2082181485273e6002e4959086601056',
                                                        '656925561529384c6847c88021053266')
                           GROUP BY IDGASTOMAIN, APP_UID) B
                             ON (    A.IDGASTOMAIN = B.IDGASTOMAIN
                                 AND A.APP_UID = B.APP_UID)
                    WHERE A.IDGASTOMAIN = pnGasto AND A.FCSTATUS NOT IN ('F', 'Z') AND A.DELINDEX_ETAPA > 1
                 ORDER BY FDFECREGISTRO ASC) PASO;

      ---- DEPOSITO ANTICIPO / PAGO   '2082181485273e6002e4959086601056'
      ---- PAGOS / REEMBOLSO '656925561529384c6847c88021053266'

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getReasignacion;

   PROCEDURE getCancelacion (salida IN OUT T_CURSOR, pnGasto  INTEGER)
   IS
      queEtapa   VARCHAR2 (70) := '';

      TYPE T_CURSOR IS REF CURSOR;

      procesa    T_CURSOR;
      queQuery   VARCHAR2 (10000) := '';
   BEGIN
      OPEN procesa FOR
         SELECT *
           FROM (  SELECT DISTINCT
                          A.IDGASTOMAIN GASTO,
                          PCKFACTURACIONGASTO.queConceptoGasto (A.IDGASTOMAIN)
                             CONCEPTO,
                          IDPROVEEDORDEPOSITO QUIESES,
                          FCASIGNADEPOSITO AQUIEN,
                          PCKENVIOCORREO.aplFecha (FDFECREGISTRO) FDFECREGISTRO,
                          CASE WHEN (SELECT COUNT(1) FROM FACTURACIONBITACORA H WHERE B.IDGASTOMAIN = H.IDGASTOMAIN AND DEL_INDEX = B.DELINDEX
                                        AND IDTASKGASTO  IN ('2082181485273e6002e4959086601056', '656925561529384c6847c88021053266')) > 0 THEN 'En Tesoreria'
                          ELSE
                              (SELECT "nombreCompleto" FROM PENDUPM.VISTAASOCIADOS  WHERE     "email" =
                                             (SELECT FCUSUARIO FROM FACTURACIONBITACORA C
                                               WHERE C.IDGASTOMAIN = A.IDGASTOMAIN  AND C.DEL_INDEX = B.DELINDEX)
                                                 AND "status" = 'A')
                          END SOLICITANTE,
                          (SELECT "status" FROM PENDUPM.VISTAASOCIADOS WHERE "cvetra" = FNNUMEMPLEADO AND "status" = 'A') STATUSEMP,
                          FNIMPORTESOLICITADO TOTAL,
                          FNIMPORTEANTICIPO ANTICIPO,
                          CASE
                             WHEN FCSEVERIDADGASTO NOT IN ('Normal', 'Urgente')
                             THEN
                                PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA)
                             ELSE
                                FCSEVERIDADGASTO
                          END
                             URGENCIA,
                             '<B>'
                          || TPOMOVIMIENTO
                          || ' </B>'
                          || NVL (
                                CASE
                                   WHEN IDEMPRESAFACTURACION = 0
                                   THEN
                                      (SELECT NMEMPRESA
                                         FROM EMPRESAFACTURACION D
                                        WHERE D.IDEMPRESA =
                                                 A.IDOTEMPRESAFACTURACION)
                                   WHEN (   IDEMPRESAFACTURACION != 0
                                         OR IDEMPRESAFACTURACION IS NOT NULL)
                                   THEN
                                      (SELECT NMEMPRESA
                                         FROM EMPRESAFACTURACION D
                                        WHERE D.IDEMPRESA =
                                                 A.IDEMPRESAFACTURACION)
                                   WHEN (   IDEMPRESAFACTURACION IS NULL
                                         OR IDEMPRESAFACTURACION = '')
                                   THEN
                                      'SIN EMPRESA DE FACTURACION'
                                END,
                                'SIN EMPRESA DE FACTURACION')
                             EMPFACT,
                          NVL (
                             CASE
                                WHEN IDEMPRESAFACTURACION = 0
                                THEN
                                   (SELECT FNIMPCOMISION
                                      FROM EMPRESAFACTURACION D
                                     WHERE D.IDEMPRESA =
                                              A.IDOTEMPRESAFACTURACION)
                                WHEN (   IDEMPRESAFACTURACION != 0
                                      OR IDEMPRESAFACTURACION IS NOT NULL)
                                THEN
                                   (SELECT FNIMPCOMISION
                                      FROM EMPRESAFACTURACION D
                                     WHERE D.IDEMPRESA = A.IDEMPRESAFACTURACION)
                                WHEN (   IDEMPRESAFACTURACION IS NULL
                                      OR IDEMPRESAFACTURACION = '')
                                THEN
                                   -1
                             END,
                             -1)
                             COMISIONCHEQUE,
                          CASE
                             WHEN FCTIPOCUENTA = '1' THEN 'Fiscal'
                             ELSE 'No Fiscal'
                          END
                             TPOCUENTA,
                          (SELECT NMTASK
                             FROM ETAPAFACTURACION C
                            WHERE C.IDTASKGASTO =
                                     (SELECT IDTASKGASTO
                                        FROM FACTURACIONBITACORA BIT
                                       WHERE     BIT.IDGASTOMAIN =
                                                    B.IDGASTOMAIN
                                         AND BIT.DEL_INDEX = B.DELINDEX))||CASE WHEN (FDDYNAMICSGASTO IS NOT NULL OR FDDYNAMICSREEMB IS NOT NULL) THEN
                                         ' <BR/><B>**Hay DEPOSITO de DINERO**</B>'  END||'<BR/> STATUS : '||CASE WHEN FCSTATUS = 'F' THEN  '<font color="red">FINALIZADO</font>'
                                                                                              WHEN FCSTATUS = 'Z' THEN  '<font color="red">CANCELADO</font>'
                                                                                         ELSE '<font color="red">EN SOLUCION</font>'  END
                             DONDEESTA,
                          B.DELINDEX IDUBICA,
                          (SELECT IDTASKGASTO
                             FROM FACTURACIONBITACORA C
                            WHERE     C.IDGASTOMAIN = A.IDGASTOMAIN
                                  AND C.DEL_INDEX = B.DELINDEX)
                             TSK,
                          A.APP_UID
                     FROM FACTURACIONMAIN A
                          INNER JOIN
                          (  SELECT IDGASTOMAIN,
                                    APP_UID,
                                    MAX (DEL_INDEX) DELINDEX
                               FROM FACTURACIONBITACORA
                           GROUP BY IDGASTOMAIN, APP_UID) B
                             ON (    A.IDGASTOMAIN = B.IDGASTOMAIN
                                 AND A.APP_UID = B.APP_UID)
                    WHERE A.IDGASTOMAIN = pnGasto AND A.FCSTATUS NOT IN ('Z') /*AND A.DELINDEX_ETAPA > 1*/
                 ORDER BY FDFECREGISTRO ASC) PASO;


      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getCancelacion;

   PROCEDURE setReasignacion (pnGasto            INTEGER,
                              psaQuien           VARCHAR2, /* nombre del usuario */
                              psEmailQuien       VARCHAR2, /* email del usuario */
                              noTicket           VARCHAR2,
                              indexEtapa         INTEGER,
                              quienEsta          VARCHAR2,
                              usuSolic           VARCHAR2,
                              comentario         VARCHAR2,
                              psError        OUT VARCHAR2)
   IS
      psDetError      VARCHAR2 (4000) := '';
      queTaskEs       VARCHAR2 (50) := '';
      queEmailAnt     VARCHAR2 (50) := '';
      queDelindexEs   INTEGER := 0;
      quienEsAct      INTEGER := 0;
      quienEsAnt      INTEGER := 0;
      queelemento     INTEGER := 0;
      existeSi        INTEGER := 0;
      psErrorD        VARCHAR2 (4000) := '';
      queEjecuta      VARCHAR2 (4000)
         :=    'PCKFACTURACIONGASTO.setReasignacion ('
            || pnGasto
            || ','
            || psaQuien
            || ','
            || psEmailQuien
            || ','
            || noTicket
            || ','
            || indexEtapa
            || ','
            || quienEsta
            || ','
            || usuSolic
            || ','
            || comentario
            || ')';

      CURSOR cuAutoriza (gasto INTEGER, quien VARCHAR2)
      IS
         SELECT *
           FROM FACTURACIONAUT
          WHERE IDGASTOMAIN = gasto AND FCAUTORIZADOR = quien;
   BEGIN
      --  OBTIENE EL ID TASK DE LA TAREA ACTUAL
      SELECT IDTASKGASTO, FCUSUARIO, DEL_INDEX
        INTO queTaskEs, queEmailAnt, queDelindexEs
        FROM FACTURACIONBITACORA
       WHERE IDGASTOMAIN = pnGasto AND DEL_INDEX = indexEtapa;

      ---- numero empleado del nuevo empleado
      SELECT "cvetra"
        INTO quienEsAct
        FROM PENDUPM.VISTAASOCIADOS
       WHERE "email" = psEmailQuien;

      ---- numero empleado del nuevo anterior
      BEGIN
          SELECT "cvetra"
            INTO quienEsAnt
            FROM PENDUPM.VISTAASOCIADOS
           WHERE "email" = queEmailAnt;
       EXCEPTION
         WHEN OTHERS
         THEN
            SELECT "cvetra"
            INTO quienEsAnt
            FROM PENDUPM.VISTAASOCIADOSCOMPLETA
           WHERE "email" = queEmailAnt;
      END;


      DBMS_OUTPUT.PUT_LINE (
         '** ACTUAL ** ' || quienEsAct || '** ANTERIOR ** ' || quienEsAnt);

      psError := '0';

      --- si es de una Autorizacion AUTORIZACIONES DEL GASTO
      IF (queTaskEs = '8961359245370cf9de08e25000253648')
      THEN
         DBMS_OUTPUT.PUT_LINE (
            '--- ENTRO A AUTORIZACIONES 01 ---' || quienEsAnt || '**');

         --- barre todas las autorizaciones
         FOR regAplica IN cuAutoriza (pnGasto, queEmailAnt)
         LOOP
            DBMS_OUTPUT.PUT_LINE (
               '--- BARRE AUTORIZACIONES  ---' || regAplica.IDTIPOAUTORIZA);

            IF (regAplica.IDTIPOAUTORIZA = 6)
            THEN                                                /* umbrales */
               SELECT COUNT (1)
                 INTO existeSi
                 FROM FACTURAASIGNACION
                WHERE IDGASTOMAIN = pnGasto AND FCUSUUMBRAL03 = quienEsAnt;

               IF (existeSi > 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUUMBRAL03 = quienEsAct
                   WHERE IDGASTOMAIN = pnGasto AND FCUSUUMBRAL03 = quienEsAnt;
               END IF;

               SELECT COUNT (1)
                 INTO existeSi
                 FROM FACTURAASIGNACION
                WHERE IDGASTOMAIN = pnGasto AND FCUSUUMBRAL04 = quienEsAnt;

               IF (existeSi > 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUUMBRAL04 = quienEsAct
                   WHERE IDGASTOMAIN = pnGasto AND FCUSUUMBRAL04 = quienEsAnt;
               END IF;

               SELECT COUNT (1)
                 INTO existeSi
                 FROM FACTURAASIGNACION
                WHERE IDGASTOMAIN = pnGasto AND FCUSUUMBRAL05 = quienEsAnt;

               IF (existeSi > 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUUMBRAL05 = quienEsAct
                   WHERE IDGASTOMAIN = pnGasto AND FCUSUUMBRAL05 = quienEsAnt;
               END IF;
            END IF;

            IF (regAplica.IDTIPOAUTORIZA = 7)
            THEN                                                  /* ETAPAS */
               SELECT COUNT (1)
                 INTO existeSi
                 FROM FACTURAASIGNACION
                WHERE IDGASTOMAIN = pnGasto AND FCUSUETAPA01 = quienEsAnt;

               IF (existeSi > 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUETAPA01 = quienEsAct
                   WHERE IDGASTOMAIN = pnGasto AND FCUSUETAPA01 = quienEsAnt;
               END IF;

               SELECT COUNT (1)
                 INTO existeSi
                 FROM FACTURAASIGNACION
                WHERE IDGASTOMAIN = pnGasto AND FCUSUETAPA02 = quienEsAnt;

               IF (existeSi > 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUETAPA02 = quienEsAct
                   WHERE IDGASTOMAIN = pnGasto AND FCUSUETAPA02 = quienEsAnt;
               END IF;
            END IF;

            IF (regAplica.IDTIPOAUTORIZA = 8)
            THEN                                              /* AUTPAGODBL */
               SELECT COUNT (1)
                 INTO existeSi
                 FROM FACTURAASIGNACION
                WHERE IDGASTOMAIN = pnGasto AND FCUSUPGODBL01 = quienEsAnt;

               IF (existeSi > 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUPGODBL01 = quienEsAct
                   WHERE IDGASTOMAIN = pnGasto AND FCUSUPGODBL01 = quienEsAnt;
               END IF;

               SELECT COUNT (1)
                 INTO existeSi
                 FROM FACTURAASIGNACION
                WHERE IDGASTOMAIN = pnGasto AND FCUSUPGODBL02 = quienEsAnt;

               IF (existeSi > 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUPGODBL02 = quienEsAct
                   WHERE IDGASTOMAIN = pnGasto AND FCUSUPGODBL02 = quienEsAnt;
               END IF;
            END IF;

            IF (regAplica.IDTIPOAUTORIZA = 9)
            THEN                                              /* JEFE INMED */
               SELECT COUNT (1)
                 INTO existeSi
                 FROM FACTURAASIGNACION
                WHERE IDGASTOMAIN = pnGasto AND FCUSUJFEINMED = quienEsAnt;

               IF (existeSi > 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUJFEINMED = quienEsAct
                   WHERE IDGASTOMAIN = pnGasto AND FCUSUJFEINMED = quienEsAnt;
               END IF;
            END IF;

            IF (regAplica.IDTIPOAUTORIZA = 10)
            THEN                                                 /* EMPRESA */
               SELECT COUNT (1)
                 INTO existeSi
                 FROM FACTURAASIGNACION
                WHERE IDGASTOMAIN = pnGasto AND FCUSUEMPRESA = quienEsAnt;

               IF (existeSi > 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUEMPRESA = quienEsAct
                   WHERE IDGASTOMAIN = pnGasto AND FCUSUEMPRESA = quienEsAnt;
               END IF;
            END IF;

            IF (regAplica.IDTIPOAUTORIZA = 34)
            THEN                                                /* URGENCIA */
               SELECT COUNT (1)
                 INTO existeSi
                 FROM FACTURAASIGNACION
                WHERE IDGASTOMAIN = pnGasto AND FCUSUURGENTE = quienEsAnt;

               IF (existeSi > 0)
               THEN
                  UPDATE FACTURAASIGNACION
                     SET FCUSUURGENTE = quienEsAct
                   WHERE IDGASTOMAIN = pnGasto AND FCUSUURGENTE = quienEsAnt;
               END IF;
            END IF;

            UPDATE FACTURACIONAUT
               SET FCAUTORIZADOR = psEmailQuien
             WHERE     IDGASTOMAIN = pnGasto
                   AND FCAUTORIZADOR = queEmailAnt
                   AND IDTIPOAUTORIZA = regAplica.IDTIPOAUTORIZA;
         END LOOP;
      END IF;

      --- si es de una Autorizacion  AUTORIZACION MONTO UMBRAL
      IF (queTaskEs = '3110185545273e52138dd65097769484')
      THEN
         SELECT COUNT (1)
           INTO existeSi
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnGasto AND FCUSUUMBRAL03 = quienEsAnt;

         IF (existeSi > 0)
         THEN
            UPDATE FACTURAASIGNACION
               SET FCUSUUMBRAL03 = quienEsAct
             WHERE IDGASTOMAIN = pnGasto AND FCUSUUMBRAL03 = quienEsAnt;
         END IF;

         SELECT COUNT (1)
           INTO existeSi
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnGasto AND FCUSUUMBRAL04 = quienEsAnt;

         IF (existeSi > 0)
         THEN
            UPDATE FACTURAASIGNACION
               SET FCUSUUMBRAL04 = quienEsAct
             WHERE IDGASTOMAIN = pnGasto AND FCUSUUMBRAL04 = quienEsAnt;
         END IF;

         SELECT COUNT (1)
           INTO existeSi
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnGasto AND FCUSUUMBRAL05 = quienEsAnt;

         IF (existeSi > 0)
         THEN
            UPDATE FACTURAASIGNACION
               SET FCUSUUMBRAL05 = quienEsAct
             WHERE IDGASTOMAIN = pnGasto AND FCUSUUMBRAL05 = quienEsAnt;
         END IF;

         UPDATE FACTURACIONAUT
            SET FCAUTORIZADOR = psEmailQuien
          WHERE     IDGASTOMAIN = pnGasto
                AND FCAUTORIZADOR = queEmailAnt
                AND IDDELINDEX = queDelindexEs
                AND IDTIPOAUTORIZA = 6;
      END IF;

      ---- Comprobacion del Gasto
      ---IF (QUEETAPA = '2147619945273e5a68478d0053334276') THEN
      ---- Area Concentradora
      -- IF (QUEETAPA = '10516340652ead549865439008696454') THEN
      ----PErsonal Solucion del Tramite
      --    IF (QUEETAPA = '43704322352eae467857576064357523') THEN
      ---- VERIF COMPROBANTES FISCALES
      ---IF (QUEETAPA = '4515947455273e63c4198f0073790158') THEN
      ----    ---- modificacion  de la solicitud
      --IF (QUEETAPA = '8433500185372a3c766b298052315707') THEN

      ---- AUTORIZACION EXCEPCIONAL GASTOS
      IF (queTaskEs = '62915318153faff251c0553039135422')
      THEN
         --***  actualiza si es exceso de comprobacion
         SELECT COUNT (1)
           INTO existeSi
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnGasto AND FCUSUEXCGASTO01 = quienEsAnt;

         IF (existeSi > 0)
         THEN
            UPDATE FACTURAASIGNACION
               SET FCUSUEXCGASTO01 = quienEsAct
             WHERE IDGASTOMAIN = pnGasto AND FCUSUEXCGASTO01 = quienEsAnt;
         END IF;

         SELECT COUNT (1)
           INTO existeSi
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnGasto AND FCUSUEXCGASTO02 = quienEsAnt;

         IF (existeSi > 0)
         THEN
            UPDATE FACTURAASIGNACION
               SET FCUSUEXCGASTO02 = quienEsAct
             WHERE IDGASTOMAIN = pnGasto AND FCUSUEXCGASTO02 = quienEsAnt;
         END IF;

         UPDATE FACTURACIONAUT
            SET FCAUTORIZADOR = psEmailQuien
          WHERE     IDGASTOMAIN = pnGasto
                AND FCAUTORIZADOR = queEmailAnt
                AND IDDELINDEX = queDelindexEs
                AND IDTIPOAUTORIZA = 44;

         --***  actualiza si es que no secumpli la ultima estapa cerrada esperada
         SELECT COUNT (1)
           INTO existeSi
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnGasto AND FCUSUETAFINAL01 = quienEsAnt;

         IF (existeSi > 0)
         THEN
            UPDATE FACTURAASIGNACION
               SET FCUSUETAFINAL01 = quienEsAct
             WHERE IDGASTOMAIN = pnGasto AND FCUSUETAFINAL01 = quienEsAnt;
         END IF;

         SELECT COUNT (1)
           INTO existeSi
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnGasto AND FCUSUETAFINAL02 = quienEsAnt;

         IF (existeSi > 0)
         THEN
            UPDATE FACTURAASIGNACION
               SET FCUSUETAFINAL02 = quienEsAct
             WHERE IDGASTOMAIN = pnGasto AND FCUSUETAFINAL02 = quienEsAnt;
         END IF;

         UPDATE FACTURACIONAUT
            SET FCAUTORIZADOR = psEmailQuien
          WHERE     IDGASTOMAIN = pnGasto
                AND FCAUTORIZADOR = queEmailAnt
                AND IDDELINDEX = queDelindexEs
                AND IDTIPOAUTORIZA = 45;
      END IF;

      --
      ----    ---- VALIDACION DE DOCTOS SOPORTE
      IF (queTaskEs = '18385767052f0fe4c52e5a1077764896')
      THEN
         SELECT COUNT (1)
           INTO existeSi
           FROM FACTURADCSOPORTE
          WHERE IDGASTOMAIN = pnGasto AND FCUSUARIO = quienEsAnt;

         IF (existeSi > 0)
         THEN
            UPDATE FACTURADCSOPORTE
               SET FCUSUARIO = quienEsAct
             WHERE IDGASTOMAIN = pnGasto AND FCUSUARIO = quienEsAnt;
         END IF;

         SELECT COUNT (1)
           INTO existeSi
           FROM FACTURADCSOPORTE
          WHERE IDGASTOMAIN = pnGasto AND FCUSUARIO01 = quienEsAnt;

         IF (existeSi > 0)
         THEN
            UPDATE FACTURADCSOPORTE
               SET FCUSUARIO01 = quienEsAct
             WHERE IDGASTOMAIN = pnGasto AND FCUSUARIO01 = quienEsAnt;
         END IF;

         SELECT COUNT (1)
           INTO existeSi
           FROM FACTURADCSOPORTE
          WHERE IDGASTOMAIN = pnGasto AND FCUSUARIO02 = quienEsAnt;

         IF (existeSi > 0)
         THEN
            UPDATE FACTURADCSOPORTE
               SET FCUSUARIO02 = quienEsAct
             WHERE IDGASTOMAIN = pnGasto AND FCUSUARIO02 = quienEsAnt;
         END IF;

         UPDATE FACTURACIONAUT
            SET FCAUTORIZADOR = psEmailQuien
          WHERE     IDGASTOMAIN = pnGasto
                AND FCAUTORIZADOR = queEmailAnt
                AND IDDELINDEX = queDelindexEs
                AND IDTIPOAUTORIZA = 41;
      END IF;

      --- Actualiza la bitacora de seguimeinto de etapas ajuste de usuario nuevo
      UPDATE FACTURACIONBITACORA
         SET FCUSUARIO = psEmailQuien
       WHERE IDGASTOMAIN = pnGasto AND DEL_INDEX = indexEtapa;

      --- bitacora de moviemintos de eventos
      INSERT INTO FACTURACIONEVENTO
           VALUES (pnGasto,
                   8,
                   'REASIGNA',
                   noTicket,
                   indexEtapa,
                   psaQuien,
                   usuSolic,
                   psEmailQuien,
                   queEmailAnt,
                   quienEsta,
                   comentario,
                   SYSDATE);

      ---- INSERTA EL DETALLE DE LA TRANSACCION
      SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

      INSERT INTO BITACORATRANSACCION
           VALUES (pnGasto,
                   queelemento,
                   queEjecuta,
                   SYSDATE,
                   SYSDATE,
                   psError);

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         psDetError := SQLERRM;
         ROLLBACK;
         psError := '**ERROR** ' || psDetError;
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

         INSERT INTO BITACORATRANSACCION
              VALUES (pnGasto,
                      queelemento,
                      queEjecuta,
                      SYSDATE,
                      SYSDATE,
                      psErrorD);

         COMMIT;
   END setReasignacion;

   PROCEDURE setCancelacion (pnGasto            INTEGER,
                             psQuienSol         VARCHAR2, /* nombre del usuario */
                             psEmailQuien       VARCHAR2, /* email del usuario */
                             noTicket           VARCHAR2,
                             indexEtapa         INTEGER,
                             quienEsta          VARCHAR2,
                             usuSolic           VARCHAR2,
                             comentario         VARCHAR2,
                             psError        OUT VARCHAR2)
   IS
      psDetError      VARCHAR2 (4000) := '';
      queTaskEs       VARCHAR2 (50) := '';
      queEmailAnt     VARCHAR2 (50) := '';
      queDelindexEs   INTEGER := 0;
   BEGIN
      --  OBTIENE EL ID TASK DE LA TAREA ACTUAL
      SELECT IDTASKGASTO
        INTO queTaskEs
        FROM FACTURACIONBITACORA
       WHERE IDGASTOMAIN = pnGasto AND DEL_INDEX = indexEtapa;

       UPDATE FACTURACIONBITACORA SET FCRESULTADO = 'CANCELADO',
                                      FCCOMENTARIOS = 'SE CANCELO POR '||SUBSTR(comentario,1,700)
        WHERE IDGASTOMAIN = pnGasto  AND DEL_INDEX = indexEtapa;

      psError := '0';

      UPDATE FACTURACIONMAIN
         SET FCSTATUS = 'Z'
       WHERE IDGASTOMAIN = pnGasto;

      INSERT INTO FACTURACIONEVENTO
           VALUES (pnGasto,
                   8,
                   'CANCELATOT',
                   noTicket,
                   indexEtapa,
                   psQuienSol,
                   usuSolic,
                   psEmailQuien,
                   NULL,
                   quienEsta,
                   comentario,
                   SYSDATE);

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         psDetError := SQLERRM;
         ROLLBACK;
         psError := '**ERROR** ' || psDetError;
   END setCancelacion;

   PROCEDURE setSolicitudDocInicio (pnCaso INTEGER, psCadenaEjecuta VARCHAR2)
   IS
      pnConcepto     INTEGER := 0;
      vsDocumentos   VARCHAR2 (2000) := '';
      queelemento    INTEGER := 0;
      psErrorD       VARCHAR2 (500) := '';
      psCredito      VARCHAR2 (500) := '';
      quienEs        INTEGER := 0;
      existeIni      INTEGER := 0;
      queTipoEs      CHAR (1) := '';
      existeTipoEs   INTEGER := 0;
      psQueDoctoEs   VARCHAR2 (500) := '';
      pasoDoctoEs    VARCHAR2 (500) := '';
      existePrevio   INTEGER := 0;
      str            string_fnc.t_array;

      CURSOR c1
      IS
         SELECT IDCONCEPTO, FCCREDITOCARTERA
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnCaso;
   BEGIN
      -- DELETE FACTURADCINICIO WHERE IDGASTOMAIN = pnCaso AND ;
      SELECT DISTINCT FNNUMEMPLEADO
        INTO quienEs
        FROM FACTURACIONMAIN
       WHERE IDGASTOMAIN = pnCaso;

      FOR concepto IN c1
      LOOP
         pnConcepto := concepto.IDCONCEPTO;
         psCredito := concepto.FCCREDITOCARTERA;
         DBMS_OUTPUT.put_line ('concepto:' || pnConcepto);

         SELECT FCARCHINIREQ
           INTO vsDocumentos
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = pnConcepto;

         DBMS_OUTPUT.put_line (vsDocumentos);
         str := string_fnc.split (vsDocumentos, '|');

         FOR i IN 1 .. str.COUNT
         LOOP
            SELECT COUNT (1)
              INTO existeIni
              FROM FACTURADCINICIO
             WHERE     IDGASTOMAIN = pnCaso
                   AND IDCONCEPTO = pnConcepto
                   AND FCNOMBRE = SUBSTR (str (i), 1, LENGTH (str (i)) - 1)
                   AND FCCREDITO = psCredito;

            IF (existeIni = 0)
            THEN
               pasoDoctoEs := SUBSTR (str (i), 1, LENGTH (str (i)) - 1);
               existeTipoEs := INSTR (pasoDoctoEs, '[R]');

               IF (existeTipoEs > 0)
               THEN
                  queTipoEs := 'R';
               ELSE
                  queTipoEs := 'O';
               END IF;

               psQueDoctoEs :=
                  SUBSTR (pasoDoctoEs, 1, INSTR (pasoDoctoEs, '[') - 1);

               SELECT COUNT (1)
                 INTO existePrevio
                 FROM FACTURADCINICIO
                WHERE     IDGASTOMAIN = pnCaso
                      AND IDCONCEPTO = pnConcepto
                      AND FCNOMBRE = psQueDoctoEs
                      AND FCCREDITO = psCredito;

               IF (existePrevio = 0)
               THEN
                  INSERT INTO FACTURADCINICIO (IDGASTOMAIN,
                                               IDCONCEPTO,
                                               IDCONSEC,
                                               FCNOMBRE,
                                               FCCREDITO,
                                               FDFECREGISTRO,
                                               FCUSUARIO,
                                               FCTIPOALTA)
                       VALUES (pnCaso,
                               pnConcepto,
                               SEQDOCTOINICIO.NEXTVAL,
                               psQueDoctoEs,
                               psCredito,
                               SYSDATE,
                               quienEs,
                               queTipoEs);
               END IF;
            END IF;

            DBMS_OUTPUT.put_line (SUBSTR (str (i), 1, LENGTH (str (i)) - 1));
         END LOOP;
      END LOOP;

      SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

      INSERT INTO BITACORATRANSACCION
           VALUES (pnCaso,
                   queelemento,
                   psCadenaEjecuta,
                   SYSDATE,
                   SYSDATE,
                   '0');

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         DBMS_OUTPUT.PUT_LINE ('-1 ' || SQLERRM);
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         INSERT INTO BITACORATRANSACCION
              VALUES (pnCaso,
                      queelemento,
                      psCadenaEjecuta,
                      SYSDATE,
                      SYSDATE,
                      psErrorD);

         COMMIT;
   END setSolicitudDocInicio;

   PROCEDURE setSolicitudDocSoporte (pnCaso             INTEGER,
                                     psCadenaEjecuta    VARCHAR2)
   IS
      pnConcepto     INTEGER := 0;
      vsDocumentos   VARCHAR2 (2000) := '';
      queelemento    INTEGER := 0;
      psErrorD       VARCHAR2 (500) := '';
      psCredito      VARCHAR2 (500) := '';
      psAut1         VARCHAR2 (500) := '';
      psAut2         VARCHAR2 (500) := '';
      psAut3         VARCHAR2 (500) := '';
      emp1           INTEGER := 0;
      emp2           INTEGER := 0;
      emp3           INTEGER := 0;
      vdEmailPgo     VARCHAR2 (500) := '';
      quienEs        INTEGER := 0;
      str            string_fnc.t_array;
      queTipoEs      CHAR (1) := '';
      existeTipoEs   INTEGER := 0;
      psQueDoctoEs   VARCHAR2 (500) := '';
      pasoDoctoEs    VARCHAR2 (500) := '';

      CURSOR c1
      IS
         SELECT IDCONCEPTO, FCCREDITOCARTERA
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnCaso;

      CURSOR detConcepto (cualEs INTEGER)
      IS
         SELECT *
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = cualEs;

      FUNCTION queCorreoAutoriza (gasto INTEGER, puesto INTEGER)
         RETURN VARCHAR2
      IS
         correosalida   VARCHAR2 (100) := '';
         existe         INTEGER := 0;
      BEGIN
         DBMS_OUTPUT.PUT_LINE ('queCorreoAutoriza .. puesto');

         SELECT COUNT (1)
           INTO existe
           FROM gastoestructura
          WHERE     idgastomain = gasto
                AND clavepuesto IN (SELECT fcnumpuestorh
                                      FROM puestocatalcuentas
                                     WHERE idcatpuesto = puesto);

         DBMS_OUTPUT.PUT_LINE (
               'queCorreoAutoriza .. puesto ::::'
            || puesto
            || '-'
            || gasto
            || '-'
            || existe);

         IF (existe = 0)
         THEN
            SELECT EMAILPUESTO
              INTO correosalida
              FROM GASTOESTRUCTURA
             WHERE     IDGASTOMAIN = gasto
                   AND IDCONSECUTIVO = (SELECT MAX (IDCONSECUTIVO)
                                          FROM GASTOESTRUCTURA
                                         WHERE IDGASTOMAIN = gasto);

            DBMS_OUTPUT.PUT_LINE ('existe cero .. puesto');
         ELSE
            SELECT EMAILPUESTO
              INTO correosalida
              FROM gastoestructura
             WHERE     idgastomain = gasto
                   AND IDCONSECUTIVO =
                          (SELECT MAX (IDCONSECUTIVO)
                             FROM gastoestructura
                            WHERE     idgastomain = gasto
                                  AND clavepuesto IN (SELECT fcnumpuestorh
                                                        FROM puestocatalcuentas
                                                       WHERE idcatpuesto =
                                                                puesto));

            DBMS_OUTPUT.PUT_LINE ('existe MAYOR .. puesto');
         END IF;

         RETURN correosalida;
      END queCorreoAutoriza;
   BEGIN
      DELETE FACTURADCSOPORTE
       WHERE IDGASTOMAIN = pnCaso;

      SELECT DISTINCT FNNUMEMPLEADO
        INTO quienEs
        FROM FACTURACIONMAIN
       WHERE IDGASTOMAIN = pnCaso;

      FOR Asignacion IN c1
      LOOP
         pnConcepto := Asignacion.IDCONCEPTO;
         psCredito := Asignacion.FCCREDITOCARTERA;

         FOR alerta IN detConcepto (pnConcepto)
         LOOP
            vsDocumentos := alerta.FCDOCUMENTOSOPORTE;
            vdEmailPgo := NULL;

            IF (vsDocumentos IS NULL) THEN
                EXIT;
            END IF;

            IF (    (   alerta.TIPOVERIFFINAL01 = 'E'
                     OR INSTR (alerta.FCVERIFFINAL01, '@') > 0)
                AND alerta.FCVERIFFINAL01 IS NOT NULL)
            THEN
               vdEmailPgo := alerta.FCVERIFFINAL01;
            END IF;

            IF (    (   alerta.TIPOVERIFFINAL01 = 'P'
                     OR INSTR (alerta.FCVERIFFINAL01, '@') = 0)
                AND (   alerta.FCVERIFFINAL01 IS NOT NULL
                     OR alerta.FCVERIFFINAL01 != ''))
            THEN
               vdEmailPgo := queCorreoAutoriza (pnCaso, alerta.FCVERIFFINAL01);
            END IF;

            IF (    alerta.TIPOVERIFFINAL01 = 'T'
                AND alerta.TIPOVERIFFINAL01 IS NOT NULL)
            THEN
               vdEmailPgo :=
                  PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                     alerta.FCVERIFFINAL01);
            END IF;

            IF ( (vdEmailPgo IS NOT NULL OR vdEmailPgo != ''))
            THEN
               DBMS_OUTPUT.PUT_LINE (' ES AUT 1 -- ' || vdEmailPgo);
               psAut1 := vdEmailPgo;
            ELSE
               psAut1 := NULL;
            END IF;

            DBMS_OUTPUT.PUT_LINE (
               ' ** SALIO 01 ****' || alerta.TIPOVERIFFINAL02);
            vdEmailPgo := NULL;

            IF (    (   alerta.TIPOVERIFFINAL02 = 'E'
                     OR INSTR (alerta.FCVERIFFINAL02, '@') > 0)
                AND alerta.FCVERIFFINAL02 IS NOT NULL)
            THEN
               vdEmailPgo := alerta.FCVERIFFINAL02;
            END IF;

            DBMS_OUTPUT.PUT_LINE (
                  ' ES EMPLEADO 02 -- '
               || vdEmailPgo
               || '---'
               || pnCaso
               || '---'
               || alerta.FCVERIFFINAL02);

            IF (    (   alerta.TIPOVERIFFINAL02 = 'P'
                     OR INSTR (alerta.FCVERIFFINAL02, '@') = 0)
                AND (   alerta.FCVERIFFINAL02 IS NOT NULL
                     OR alerta.FCVERIFFINAL02 != ''))
            THEN
               vdEmailPgo :=
                  PCKFACTURACIONGASTO.queCorreoAutoriza (
                     pnCaso,
                     alerta.FCVERIFFINAL02);
            END IF;

            DBMS_OUTPUT.PUT_LINE (' ES NIVEL 02 -- ' || vdEmailPgo);

            IF (    alerta.TIPOVERIFFINAL02 = 'T'
                AND alerta.TIPOVERIFFINAL02 IS NOT NULL)
            THEN
               vdEmailPgo :=
                  PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                     alerta.FCVERIFFINAL02);
            END IF;

            IF ( (vdEmailPgo IS NOT NULL OR vdEmailPgo != ''))
            THEN
               DBMS_OUTPUT.PUT_LINE (' ES AUT 2 -- ' || vdEmailPgo);
               psAut2 := vdEmailPgo;
            ELSE
               psAut2 := NULL;
            END IF;

            DBMS_OUTPUT.PUT_LINE (' ** SALIO 02 ****');
            vdEmailPgo := NULL;

            IF (    (   alerta.TIPOVERIFFINAL03 = 'E'
                     OR INSTR (alerta.FCVERIFFINAL03, '@') > 0)
                AND alerta.FCVERIFFINAL03 IS NOT NULL)
            THEN
               vdEmailPgo := alerta.FCVERIFFINAL03;
            END IF;

            IF (    (   alerta.TIPOVERIFFINAL03 = 'P'
                     OR INSTR (alerta.FCVERIFFINAL03, '@') = 0)
                AND (   alerta.FCVERIFFINAL03 IS NOT NULL
                     OR alerta.FCVERIFFINAL03 != ''))
            THEN
               vdEmailPgo := queCorreoAutoriza (pnCaso, alerta.FCVERIFFINAL03);
            END IF;

            IF (    alerta.TIPOVERIFFINAL03 = 'T'
                AND alerta.TIPOVERIFFINAL03 IS NOT NULL)
            THEN
               vdEmailPgo :=
                  PCKFACTURACIONGASTO.queEmpleadoMailPuesto (
                     alerta.FCVERIFFINAL03);
            END IF;

            IF ( (vdEmailPgo IS NOT NULL OR vdEmailPgo != ''))
            THEN
               DBMS_OUTPUT.PUT_LINE (' ES AUT 3 -- ' || vdEmailPgo);
               psAut3 := vdEmailPgo;
            ELSE
               psAut3 := NULL;
            END IF;

            DBMS_OUTPUT.PUT_LINE (' ** ANTES RH ****');

            ---- Obtiene los numeros de empleado de los utorizadores
            IF (psAut1 IS NOT NULL)
            THEN
               BEGIN
                  SELECT "cvetra"
                    INTO emp1
                    FROM PENDUPM.VISTAASOCIADOS
                   WHERE "email" = psAut1;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     emp1 := -1;
               END;
            END IF;

            IF (psAut2 IS NOT NULL)
            THEN
               BEGIN
                  SELECT "cvetra"
                    INTO emp2
                    FROM PENDUPM.VISTAASOCIADOS
                   WHERE "email" = psAut2;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     emp2 := -1;
               END;
            END IF;

            IF (psAut3 IS NOT NULL)
            THEN
               BEGIN
                  SELECT "cvetra"
                    INTO emp3
                    FROM PENDUPM.VISTAASOCIADOS
                   WHERE "email" = psAut3;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     emp3 := -1;
               END;
            END IF;

            DBMS_OUTPUT.PUT_LINE (
                  ' **QUEDARN *** -- '
               || psAut1
               || '-'
               || psAut2
               || '-'
               || psAut3
               || '***'
               || emp1
               || '-'
               || emp2
               || '-'
               || emp3);
         END LOOP;

         str := string_fnc.split (vsDocumentos, '|');

         FOR i IN 1 .. str.COUNT
         LOOP
            pasoDoctoEs := SUBSTR (str (i), 1, LENGTH (str (i)) - 1);
            existeTipoEs := INSTR (pasoDoctoEs, '[R]');

            IF (existeTipoEs > 0)
            THEN
               queTipoEs := 'R';
            ELSE
               queTipoEs := 'O';
            END IF;

            psQueDoctoEs :=
               SUBSTR (pasoDoctoEs, 1, INSTR (pasoDoctoEs, '[') - 1);
            DBMS_OUTPUT.PUT_LINE (' **INSERT  FACTURADCSOPORTE*');

            INSERT INTO FACTURADCSOPORTE (IDGASTOMAIN,
                                          IDCONCEPTO,
                                          IDCONSEC,
                                          FCNOMBRE,
                                          FCCREDITO,
                                          FCUSUARIO,
                                          FDFECREGISTRO,
                                          FCUSUARIO01,
                                          FCUSUARIO02,
                                          FCUSUARIO03,
                                          FCTIPOALTA)
                 VALUES (pnCaso,
                         pnConcepto,
                         SEQDOCTOSOPORTE.NEXTVAL,
                         pasoDoctoEs,
                         psCredito,
                         quienEs,
                         SYSDATE,
                         emp1,
                         emp2,
                         emp3,
                         queTipoEs);

            DBMS_OUTPUT.put_line (SUBSTR (str (i), 1, LENGTH (str (i)) - 1));
         END LOOP;
      END LOOP;

      SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

      INSERT INTO BITACORATRANSACCION
           VALUES (pnCaso,
                   queelemento,
                   psCadenaEjecuta,
                   SYSDATE,
                   SYSDATE,
                   '0');

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         DBMS_OUTPUT.PUT_LINE ('-1 ' || SQLERRM);
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

         INSERT INTO BITACORATRANSACCION
              VALUES (pnCaso,
                      queelemento,
                      psCadenaEjecuta,
                      SYSDATE,
                      SYSDATE,
                      psErrorD);

         COMMIT;
   END setSolicitudDocSoporte;

   PROCEDURE getLimiteCredito (pnSolicitud        INTEGER,
                               psUbicacion        VARCHAR2, /* Registro Solicitud, Rechazo Autorizacion, Pago x Tramite, Rechazo de Tramite, finalizado */
                               psUsuario          VARCHAR2,
                               psCadenaEjecuta    VARCHAR2)
   IS
      queelemento        INTEGER := 0;
      psErrorD           VARCHAR2 (500) := '';
      psTipomovto        VARCHAR2 (15) := '';
      queTipo            CHAR (1) := '';
      vnImporteBase      NUMBER (10, 2) := 0;
      vnImporteConsumo   NUMBER (15, 2) := 0;
      vnImporteQueda     NUMBER (15, 2) := 0;
      pnAnticipo         NUMBER (10, 2) := 0;
      psProveedor        VARCHAR2 (25) := '';
      psProvAnt          VARCHAR2 (25) := '';
      psMovimiento       VARCHAR2 (25) := '';
      psSeveridad        VARCHAR2 (25) := '';
      queDiaSePaga       DATE := SYSDATE;
      cuantosDias        INTEGER := 0;
      queFecRequerida    DATE := NULL;
      queTipoSolicEs       VARCHAR2 (9) := '';


   BEGIN
      psErrorD := '0';

      IF (psUbicacion = '2082181485273e6002e4959086601056')
      THEN                                             /* DEPOSITO ANTICIPO */
         DBMS_OUTPUT.PUT_LINE ('DEPOSITO ANTICIPO');

         --- Recupera Datos del Registro Principal
         SELECT DISTINCT FNIMPORTEANTICIPO,
                         UPPER (TPOMOVIMIENTO),
                         IDPROVEEDORDEPOSITO,
                         FCSEVERIDADGASTO,
                         TPOMOVIMIENTO,
                         FDFECHAREQUERIDA
           INTO pnAnticipo,
                psTipomovto,
                psProveedor,
                psSeveridad,
                psMovimiento,
                queFecRequerida
           FROM FACTURACIONMAIN
          WHERE IDGASTOMAIN = pnSolicitud;

         ---  obtiene los montos del proveedor a descontar
         SELECT FNIMPORTECREDITO, FNIMPORTECONSUMIDO
           INTO vnImporteBase, vnImporteConsumo
           FROM CTPROVEEDORGASTO
          WHERE IDPROVEEDORGTO = psProveedor;

         --- Actualizael monto delProveedor
         UPDATE CTPROVEEDORGASTO
            SET FNIMPORTECONSUMIDO = (FNIMPORTECONSUMIDO - pnAnticipo),
                FNIMPORTEANTICIPO = (FNIMPORTEANTICIPO + pnAnticipo),
                FNTOTEVENTOS = NVL (FNTOTEVENTOS, 0) + 1
          WHERE     (FNIMPORTECONSUMIDO - pnAnticipo) >= 0
                AND IDPROVEEDORGTO = psProveedor;

         vnImporteQueda := vnImporteConsumo - pnAnticipo;

         --- Verifica si es Anticipo , Reembolso / Tramite y su subtipo
         SELECT DISTINCT TPOMOVIMIENTO  INTO queTipoSolicEs
           FROM FACTURACIONMAIN
          WHERE IDGASTOMAIN = pnSolicitud;

         --- Obtiene la Fevha para PAgo del movimiento
         SELECT CASE
                   WHEN psSeveridad = 'FechaPago' THEN queFecRequerida
                   ELSE (SYSDATE + FCVALOR)
                END
           INTO queDiaSePaga
           FROM PARAMETROGASTO
          WHERE IDPARAMETRO =
               CASE
                  WHEN psSeveridad = 'FechaPago' THEN 3
                  ELSE
                     CASE WHEN queTipoSolicEs = 'Anticipo' THEN 4
                          WHEN queTipoSolicEs = 'Reembolso' THEN 6
                          WHEN queTipoSolicEs = 'Tramite' THEN
                              CASE WHEN (SELECT COUNT(1) FROM FACTURATRAMITE WHERE IDGASTOMAIN = pnSolicitud
                                          AND FCTIPOSOLUCION != 'INTERNO' AND FCTIPOPAGO = 'Anticipo' AND TIPOPAGOADD IS NULL) > 0 THEN 4
                                   WHEN (SELECT COUNT(1) FROM FACTURATRAMITE WHERE IDGASTOMAIN = pnSolicitud
                                          AND FCTIPOSOLUCION != 'INTERNO' AND FCTIPOPAGO = 'Anticipo' AND TIPOPAGOADD IS NOT NULL) > 0 THEN 4
                                   WHEN (SELECT COUNT(1) FROM FACTURATRAMITE WHERE IDGASTOMAIN = pnSolicitud
                                          AND FCTIPOSOLUCION != 'INTERNO' AND FCTIPOPAGO != 'Anticipo') > 0 THEN 6
                              END
                     END
               END;

         --- Actualiza en FavtracionPAgos
         UPDATE FACTURACIONPAGOS
            SET FDFECPARAPAGO = queDiaSePaga
          WHERE IDGASTOMAIN = pnSolicitud AND FNCONSEC = 2;

         INSERT INTO BITACORAPROVEEDORGTO
              VALUES (PENDUPM.SEQBITAPROVEEDOR.NEXTVAL,
                      pnSolicitud,
                      psProveedor,
                      psUbicacion,
                      SYSDATE,
                      psUsuario,
                      vnImporteConsumo,
                      'C',
                      pnAnticipo,
                      vnImporteQueda);
      END IF;

      IF (psUbicacion = '656925561529384c6847c88021053266')
      THEN                                              /* PAGO / REEMBOLSO */
         DBMS_OUTPUT.PUT_LINE ('PAGO / REEMBOLSO');

         --- Recupera Datos del Registro Principal
         SELECT DISTINCT FNIMPORTEANTICIPO,
                         UPPER (TPOMOVIMIENTO),
                         IDPROVEEDORGTO,
                         FCSEVERIDADGASTO,
                         TPOMOVIMIENTO,
                         IDPROVEEDORDEPOSITO
           INTO pnAnticipo,
                psTipomovto,
                psProveedor,
                psSeveridad,
                psMovimiento,
                psProvAnt
           FROM FACTURACIONMAIN
          WHERE IDGASTOMAIN = pnSolicitud;

         ---  obtiene los montos del proveedor a descontar
         SELECT FNIMPORTECREDITO, FNIMPORTECONSUMIDO
           INTO vnImporteBase, vnImporteConsumo
           FROM CTPROVEEDORGASTO
          WHERE IDPROVEEDORGTO = psProvAnt;

         --- Actualizael monto delProveedor
         UPDATE CTPROVEEDORGASTO
            SET FNIMPORTECONSUMIDO = (FNIMPORTECONSUMIDO + pnAnticipo),
                FNIMPORTEANTICIPO = (FNIMPORTEANTICIPO - pnAnticipo),
                FNTOTEVENTOS = NVL (FNTOTEVENTOS, 0) - 1
          WHERE     (FNIMPORTECONSUMIDO + pnAnticipo) <= FNIMPORTECREDITO
                AND IDPROVEEDORGTO = psProvAnt;

         vnImporteQueda := vnImporteConsumo + pnAnticipo;

         --- Obtiene la Fevha para PAgo del movimiento
         SELECT (SYSDATE + FCVALOR)
           INTO queDiaSePaga
           FROM PARAMETROGASTO
          WHERE IDPARAMETRO =
                   CASE WHEN psProveedor = psProvAnt THEN 7 ELSE 6 END;

         --- Actualiza en FavtracionPAgos
         UPDATE FACTURACIONPAGOS
            SET FDFECPARAPAGO = queDiaSePaga
          WHERE IDGASTOMAIN = pnSolicitud AND FNCONSEC = 6;

         INSERT INTO BITACORAPROVEEDORGTO
              VALUES (PENDUPM.SEQBITAPROVEEDOR.NEXTVAL,
                      pnSolicitud,
                      psProveedor,
                      psUbicacion,
                      SYSDATE,
                      psUsuario,
                      vnImporteConsumo,
                      'A',
                      pnAnticipo,
                      vnImporteQueda);
      END IF;

      SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

      INSERT INTO BITACORATRANSACCION
           VALUES (pnSolicitud,
                   queelemento,
                   psCadenaEjecuta,
                   SYSDATE,
                   SYSDATE,
                   '0');

      DBMS_OUTPUT.PUT_LINE ('0 EXITOSO');
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

         INSERT INTO BITACORATRANSACCION
              VALUES (pnSolicitud,
                      queelemento,
                      psCadenaEjecuta,
                      SYSDATE,
                      SYSDATE,
                      '-1' || psErrorD);

         DBMS_OUTPUT.PUT_LINE ('-1 ' || psErrorD);
   END getLimiteCredito;

   PROCEDURE validaTipoMovimiento (pnSolicitud       INTEGER,
                                   psTipomovto       INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL */
                                   psError       OUT VARCHAR2)
   IS
      existeAlgo    INTEGER := 0;
      queMovtoHay   INTEGER := 0;
      buscaValor    INTEGER := psTipomovto;
   BEGIN
      psError := '0';

      IF (psTipomovto = 2 OR psTipomovto = 3)
      THEN
         SELECT COUNT (1)
           INTO existeAlgo
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnSolicitud AND IDTIPOMOVTO NOT IN (2, 3);
      ELSE
         SELECT COUNT (1)
           INTO existeAlgo
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnSolicitud AND IDTIPOMOVTO != buscaValor;
      END IF;

      IF (existeAlgo > 0)
      THEN
         psError :=
            '*ERROR* Existe Informacion con Otro Tipo de Asignacion, Desea Eliminarla y capturar esta nueva ?';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         psError := '*ERROR* ' || SQLERRM;
   END validaTipoMovimiento;

   PROCEDURE borraAsignacionsolic (pnSolicitud       INTEGER,
                                   pnConcepto        INTEGER,
                                   psCredito         VARCHAR2,
                                   psError       OUT VARCHAR2)
   IS
      yaNoHay   INTEGER := 0;
   BEGIN
      psError := '0';

      DELETE FACTURADCINICIO
       WHERE     IDGASTOMAIN = pnSolicitud
             AND IDCONCEPTO = pnConcepto
             AND FCCREDITO = psCredito;

      DELETE FACTURADCSOPORTE
       WHERE     IDGASTOMAIN = pnSolicitud
             AND IDCONCEPTO = pnConcepto
             AND FCCREDITO = psCredito;

      DELETE FACTURAASIGNACION
       WHERE     IDGASTOMAIN = pnSolicitud
             AND IDCONCEPTO = pnConcepto
             AND FCCREDITOCARTERA = psCredito;

      SELECT COUNT (1)
        INTO yaNoHay
        FROM FACTURAASIGNACION
       WHERE IDGASTOMAIN = pnSolicitud AND IDCONCEPTO = pnConcepto;

      IF (yaNoHay = 0)
      THEN
         --          DELETE FACTURACIONDETALLE  WHERE IDGASTOMAIN = pnSolicitud AND IDCONCEPTO = pnConcepto;
         DELETE FACTURACIONCOTIZA
          WHERE IDGASTOMAIN = pnSolicitud AND IDCONCEPTO = pnConcepto;

         DELETE FACTURADCINICIO
          WHERE IDGASTOMAIN = pnSolicitud AND IDCONCEPTO = pnConcepto;

         DELETE FACTURADCSOPORTE
          WHERE IDGASTOMAIN = pnSolicitud AND IDCONCEPTO = pnConcepto;

         DELETE FACTURACIONMAIN
          WHERE IDGASTOMAIN = pnSolicitud AND IDCONCEPTO = pnConcepto;

        DELETE FACTURACIONANEXOS
         WHERE     IDGASTOMAIN = pnSolicitud;

      END IF;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psError := '*ERROR* ' || SQLERRM;
   END borraAsignacionsolic;

   PROCEDURE getConceptosolicitud (pnSolicitud          INTEGER,
                                   psTipomovto          INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL  [43] X IMP FACT*/
                                   salida        IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa         T_CURSOR;
      cadenaEjecuta   VARCHAR2 (4000) := '';
   BEGIN
      cadenaEjecuta :=
            'SELECT DISTINCT IDCONCEPTO IDCONCEPTO,
                               (SELECT NMCONCEPTO FROM CTCATALOGOCUENTAS C WHERE A.IDCONCEPTO = C.IDCONCEPTO) NMCONCEPTO,
                               (SELECT FCCUENTACONTABLE FROM CTCATALOGOCUENTAS C WHERE A.IDCONCEPTO = C.IDCONCEPTO) NUMCUENTA
                          FROM FACTURACIONMAIN A
                         WHERE IDGASTOMAIN = '
         || pnSolicitud
         || ' AND IDCONCEPTO IN (SELECT IDCONCEPTO FROM CTCATALOGOCUENTAS WHERE';

      IF (psTipomovto = 2)
      THEN
         cadenaEjecuta := cadenaEjecuta || ' FCAPLCREDITO = ''S'')';
      ELSIF (psTipomovto = 3)
      THEN
         cadenaEjecuta := cadenaEjecuta || ' FCAPLMCREDITO = ''S'')';
      ELSIF (psTipomovto = 4)
      THEN
         cadenaEjecuta := cadenaEjecuta || ' FCAPLCARTERA = ''S'')';
      ELSE
         cadenaEjecuta := cadenaEjecuta || ' 1=1)';
      END IF;

      DBMS_OUTPUT.PUT_LINE ('ejecuta: ' || cadenaEjecuta);

      OPEN procesa FOR cadenaEjecuta;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         DBMS_OUTPUT.PUT_LINE ('ejecuta: ' || SQLERRM);
         NULL;
   END getConceptosolicitud;

   PROCEDURE getCategoriaCC (salida IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;
   BEGIN
      OPEN procesa FOR
         SELECT IDCATEGORIA IDCATEGORIA, NMCATEGORIA NMCATEGORIA
           FROM CATEGORIACENTROCOSTO
          WHERE IDCATEGORIA != 3 AND FCSTATUS = 'A';

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getCategoriaCC;

   PROCEDURE getCCsolic (pnCategoria VARCHAR2, salida IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa   T_CURSOR;
   BEGIN
      OPEN procesa FOR
           SELECT IDCENTROCOSTO IDCENTROCOSTO, NMCENTROCOSTO NMCENTROCOSTO
             FROM CENTROCOSTOGASTO
            WHERE FCSTATUS = 'A' AND IDCATEGORIA = pnCategoria
         ORDER BY NMCENTROCOSTO;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getCCsolic;

   FUNCTION getValorConcatenado (psCadena VARCHAR2)
      RETURN TABVALORCONCATENA
      PIPELINED
   IS
      vrec             VALORCONCATENA;
      strElementos     STRING_FNC.t_array;
      ubica            INTEGER := 0;
      vnBarre          INTEGER := 0;
      esCArtera        VARCHAR2 (50) := '';
      esIndicador      VARCHAR2 (50) := '';
      queVALCarteras   VARCHAR2 (550) := '';
      psNmCartera      VARCHAR2 (550) := '';
   BEGIN
      --- Verifica que el Cr?dito se permita agregar por Configuracion
      strElementos := STRING_FNC.split (psCadena, '|');

      FOR vnBarre IN 1 .. strElementos.COUNT
      LOOP
         queVALCarteras :=
            SUBSTR (strElementos (vnBarre),
                    1,
                    LENGTH (strElementos (vnBarre)) - 1);
         ubica := INSTR (queVALCarteras, '-');
         esCArtera := SUBSTR (queVALCarteras, 1, (ubica - 1)); /* Regresa la CArtera Valida */
         esIndicador := SUBSTR (queVALCarteras, (ubica + 1)); /* SI - NO - NOAPLICA - FORMULA */

         SELECT NMCARTERA
           INTO psNmCartera
           FROM CTCARTERA
          WHERE IDCARTERA = esCartera;

         IF (esIndicador = 'SI' OR esIndicador = 'NO')
         THEN
            vrec.rIdValor := esCArtera;
            vrec.rNMValor := psNmCartera;
            PIPE ROW (vrec);
         END IF;

         DBMS_OUTPUT.PUT_LINE (
            '===:: ' || esCArtera || '---' || psNmCartera || '---');
      END LOOP;

      RETURN;
   END getValorConcatenado;

   FUNCTION getValorArchIniSop (pnConsecutivo INTEGER, cualEs VARCHAR2)
      RETURN VARCHAR2
   IS
      /*
         cualEs    'INI'  ARCHIVOS DE INICIO      'SOP'  DOCTOS DE SOPORTE
      */
      vrec           VALORCONCATENA;
      strElementos   STRING_FNC.t_array;
      ubica          INTEGER := 0;
      vnBarre        INTEGER := 0;
      esCArtera      VARCHAR2 (5000) := '';
      esTipoDocto    VARCHAR2 (5000) := '';
      esRuta         VARCHAR2 (5000) := '';
      psCadena       VARCHAR2 (4000) := '';
      salidaCad      VARCHAR2 (4000) := '';

      TYPE cur_typ IS REF CURSOR;

      cuBarre        cur_typ;
   BEGIN
      IF (cualEs = 'INI')
      THEN
         psCadena :=
               'SELECT IDCONSEC, FCNOMBRE , FCTIPOALTA, NVL(REPLACE(FCRUTAFILE,''/opt/processmaker/workflow/public_html/'',''http://quantum1.pendulum.com.mx/''),''#'') FCRUTAFILE
         FROM FACTURADCINICIO WHERE (IDGASTOMAIN,IDCONCEPTO,FCCREDITO) IN (SELECT IDGASTOMAIN,IDCONCEPTO,FCCREDITO
                                                                             FROM FACTURADCINICIO
                                                                            WHERE IDCONSEC = '
            || pnConsecutivo
            || ')';
      ELSIF (cualEs = 'SOP')
      THEN
         psCadena :=
               'SELECT IDCONSEC, FCNOMBRE, FCTIPOALTA, NVL(REPLACE(FCRUTAFILE,''/opt/processmaker/workflow/public_html/'',''http://quantum1.pendulum.com.mx/''),''#'') FCRUTAFILE
         FROM FACTURADCSOPORTE WHERE (IDGASTOMAIN,IDCONCEPTO,FCCREDITO) IN (SELECT IDGASTOMAIN,IDCONCEPTO,FCCREDITO
                                                                             FROM FACTURADCSOPORTE
                                                                            WHERE IDCONSEC = '
            || pnConsecutivo
            || ')';
      END IF;

      --- Verifica que el Cr?dito se permita agregar por Configuracion
      OPEN cuBarre FOR psCadena;

      LOOP
         FETCH cuBarre
            INTO vnBarre,
                 esCArtera,
                 esTipoDocto,
                 esRuta;

         EXIT WHEN cuBarre%NOTFOUND;
         salidaCad :=
               salidaCad
            || esCArtera
            || '@'
            || vnBarre
            || '@'
            || esRuta
            || '@'
            || esTipoDocto
            || '|';
         DBMS_OUTPUT.PUT_LINE ('===:: ' || salidaCad);
      END LOOP;

      CLOSE cuBarre;

      RETURN salidaCad;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN '*ERROR*';
   END getValorArchIniSop;

   FUNCTION getValorArchIniSopUnif (pnConsecutivo INTEGER, cualEs VARCHAR2)
      RETURN VARCHAR2
   IS
      /*
         cualEs    'INI'  ARCHIVOS DE INICIO      'SOP'  DOCTOS DE SOPORTE
      */
      vrec           VALORCONCATENA;
      strElementos   STRING_FNC.t_array;
      ubica          INTEGER := 0;
      vnBarre        INTEGER := 0;
      esCArtera      VARCHAR2 (5000) := '';
      esRuta         VARCHAR2 (5000) := '';
      psCadena       VARCHAR2 (4000) := '';
      salidaCad      VARCHAR2 (4000) := '';

      TYPE cur_typ IS REF CURSOR;

      cuBarre        cur_typ;
   BEGIN
      IF (cualEs = 'INI')
      THEN
         psCadena :=
               'SELECT IDCONSEC, FCNOMBRE, FCRUTAFILE
         FROM FACTURADCINICIO WHERE (IDGASTOMAIN,IDCONCEPTO,FCCREDITO) IN (SELECT IDGASTOMAIN,IDCONCEPTO,FCCREDITO
                                                                             FROM FACTURADCINICIO
                                                                            WHERE IDCONSEC = '
            || pnConsecutivo
            || ')';
      ELSIF (cualEs = 'SOP')
      THEN
         psCadena :=
               'SELECT IDCONSEC, SUBSTR(FCNOMBRE,1,INSTR(FCNOMBRE,''['')-1) FCNOMBRE,  FCRUTAFILE
         FROM FACTURADCSOPORTE WHERE (IDGASTOMAIN,IDCONCEPTO,FCCREDITO) IN (SELECT IDGASTOMAIN,IDCONCEPTO,FCCREDITO
                                                                             FROM FACTURADCSOPORTE
                                                                            WHERE IDCONSEC = '
            || pnConsecutivo
            || ')';
      END IF;

      --- Verifica que el Cr?dito se permita agregar por Configuracion
      OPEN cuBarre FOR psCadena;

      LOOP
         FETCH cuBarre INTO vnBarre, esCArtera, esRuta;

         EXIT WHEN cuBarre%NOTFOUND;
         IF esRuta IS NULL THEN
            salidaCad := 'SIN ARCHIVO';
         ELSE
            salidaCad :=
               salidaCad
            || '<A href="'
            || esRuta
            || '" target="_blank">'
            || esCArtera
            || '</A><BR/>';
         END IF;
         DBMS_OUTPUT.PUT_LINE ('===:: ' || salidaCad);
      END LOOP;

      CLOSE cuBarre;

      RETURN salidaCad;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN '*ERROR*';
   END getValorArchIniSopUnif;

   PROCEDURE getCarteraConcepto (pnConcepto INTEGER, salida IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa            T_CURSOR;
      psCadenaCarteras   VARCHAR2 (4000) := '';
   BEGIN
      BEGIN
         SELECT NVL (FCCARTERAASIGNADA, 'NO')
           INTO psCadenaCarteras
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = pnConcepto;
      EXCEPTION
         WHEN OTHERS
         THEN
            psCadenaCarteras := 'NO';
      END;

      DBMS_OUTPUT.put_line ('-----' || psCadenaCarteras);

      IF (psCadenaCarteras != 'NO')
      THEN
         OPEN procesa FOR
            SELECT rIdValor IDVALOR, rNMValor NMVALOR
              FROM TABLE (
                      PCKFACTURACIONGASTO.getValorConcatenado (
                         psCadenaCarteras));
      ELSE
         OPEN procesa FOR
            SELECT 1 IDVALOR, '1' NMVALOR
              FROM DUAL
             WHERE 1 = 2;
      END IF;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         DBMS_OUTPUT.put_line ('-----' || SQLERRM);
         NULL;
   END getCarteraConcepto;

   PROCEDURE getTipomovimiento (pnSolicitud INTEGER, salida IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa            T_CURSOR;
      psCadenaCarteras   VARCHAR2 (4000) := '';
      existe             INTEGER := 0;
   BEGIN
      SELECT COUNT (1)
        INTO existe
        FROM CTCATALOGOCUENTAS
       WHERE     IDCONCEPTO IN (SELECT IDCONCEPTO
                                  FROM FACTURACIONMAIN
                                 WHERE IDGASTOMAIN = pnSolicitud)
             AND FCAPLCREDITO = 'S';

      IF (existe > 0)
      THEN
         DBMS_OUTPUT.PUT_LINE (
            'EXISTE 2 ....' || existe || '-' || psCadenaCarteras);
         psCadenaCarteras :=
               psCadenaCarteras
            || 'SELECT ''2'' IDTIPO, ''x Credito individual'' NMTIPO FROM DUAL ';
      END IF;

      SELECT COUNT (1)
        INTO existe
        FROM CTCATALOGOCUENTAS
       WHERE     IDCONCEPTO IN (SELECT IDCONCEPTO
                                  FROM FACTURACIONMAIN
                                 WHERE IDGASTOMAIN = pnSolicitud)
             AND FCAPLMCREDITO = 'S';

      IF (existe > 0)
      THEN
         DBMS_OUTPUT.PUT_LINE (
            'EXISTE 3 ....' || existe || '-' || psCadenaCarteras);

         IF (LENGTH (psCadenaCarteras) > 0)
         THEN
            psCadenaCarteras := psCadenaCarteras || ' UNION ALL ';
         END IF;

         psCadenaCarteras :=
               psCadenaCarteras
            || 'SELECT ''3'' IDTIPO, ''Carga Masiva Creditos'' NMTIPO FROM DUAL ';
      END IF;

      SELECT COUNT (1)
        INTO existe
        FROM CTCATALOGOCUENTAS
       WHERE     IDCONCEPTO IN (SELECT IDCONCEPTO
                                  FROM FACTURACIONMAIN
                                 WHERE IDGASTOMAIN = pnSolicitud)
             AND FCAPLCARTERA = 'S';

      IF (existe > 0)
      THEN
         DBMS_OUTPUT.PUT_LINE ('EXISTE 4 ....' || existe);

         IF (LENGTH (psCadenaCarteras) > 0)
         THEN
            psCadenaCarteras := psCadenaCarteras || ' UNION ALL ';
         END IF;

         psCadenaCarteras :=
               psCadenaCarteras
            || 'SELECT ''4'' IDTIPO, ''x Cartera'' NMTIPO FROM DUAL ';
      END IF;

      ---- si no hay nda seleccionado se Activa Importe General
      IF (psCadenaCarteras = '')
      THEN
         IF (LENGTH (psCadenaCarteras) > 0)
         THEN
            psCadenaCarteras := psCadenaCarteras || ' UNION ALL ';
         END IF;

         psCadenaCarteras :=
               psCadenaCarteras
            || 'SELECT ''42'' IDTIPO, ''Importe General'' NMTIPO FROM DUAL ';
      END IF;

      DBMS_OUTPUT.PUT_LINE (psCadenaCarteras);

      OPEN procesa FOR psCadenaCarteras;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getTipomovimiento;

   PROCEDURE getDetalleAsignacion (pnSolicitud          INTEGER,
                                   salida        IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa            T_CURSOR;
      psCadenaCarteras   VARCHAR2 (4000) := '';
      existe             INTEGER := 0;
      importeComproba    NUMBER(10,2) :=0;
      importeProrrateo   NUMBER(10,2) :=0;
      queEtapaEs         VARCHAR2 (4000) := '';
      cuantosCred       INTEGER     := 0;
   BEGIN

       BEGIN
       SELECT IDTASKGASTO INTO queEtapaEs
         FROM FACTURACIONBITACORA
        WHERE IDGASTOMAIN = pnSolicitud AND (IDGASTOMAIN,DEL_INDEX) IN (SELECT IDGASTOMAIN, MAX(DEL_INDEX)
                                                                         FROM FACTURACIONBITACORA
                                                                        WHERE IDGASTOMAIN = pnSolicitud
                                                                        GROUP BY IDGASTOMAIN
                                                                        );
        EXCEPTION WHEN OTHERS THEN
          queEtapaEs:= '';
        END;

        BEGIN SELECT SUM(FNTOTAL) INTO importeComproba FROM FACTURACIONCOMPROBA WHERE IDGASTOMAIN = pnSolicitud AND FCTIPOCOMPROBANTE != 'Ficha de Deposito' AND FCTIPOCOMPROBANTE != 'Descuento de nomina' ;
        EXCEPTION WHEN OTHERS THEN
          importeComproba:= 0;
        END;
        SELECT COUNT(1) INTO  cuantosCred FROM FACTURAASIGNACION WHERE IDGASTOMAIN = pnSolicitud ;
        importeProrrateo := importeComproba/  cuantosCred;

      OPEN procesa FOR
           SELECT    '--> '
                  || (SELECT NMDESCRIP
                        FROM CTCUENTACATEGORIA C
                       WHERE C.IDCUENTACAT =
                                (SELECT IDCATEGORIA
                                   FROM CTCATALOGOCUENTAS H
                                  WHERE A.IDCONCEPTO = H.IDCONCEPTO))
                  || '<BR/>'
                  || '--> '
                  || (SELECT NMDESCRIP
                        FROM CTCUENTACATEGORIA C
                       WHERE C.IDCUENTACAT =
                                (SELECT IDSUBCATEGORIA
                                   FROM CTCATALOGOCUENTAS H
                                  WHERE A.IDCONCEPTO = H.IDCONCEPTO))
                     CATEGSUB,
                  (SELECT NMCONCEPTO
                     FROM CTCATALOGOCUENTAS C
                    WHERE A.IDCONCEPTO = C.IDCONCEPTO)
                     NMCONCEPTO,
                  A.IDCONCEPTO IDCONCEPTO,
                  IDTIPOMOVTO,
                  FCCREDITOCARTERA VALOR,
                  ( SELECT USR_SUPERVISOR.CLMAIL
                    FROM   RCVRY.CASE,
                        RCVRY.CASEACCT,
                        RCVRY.COLLID USR_EXTERNO,
                        RCVRY.COLLID USR_SUPERVISOR
                    WHERE   (CASE.CECASENO = CASEACCT.CCCASENO)
                        AND (USR_EXTERNO.CLCOLLID = CASE.CEEXTLWYR)
                        AND (USR_SUPERVISOR.CLCOLLID = CASE.CESUPVLWYR)
                        AND CASE.CESTATUS = 'A'
                        AND CASEACCT.CCACCT = A.FCCREDITOCARTERA
                   GROUP BY USR_SUPERVISOR.CLMAIL ) MAIL_SUPERVISOR,
                  CASE WHEN queEtapaEs = '43704322352eae467857576064357523' THEN NVL(importeProrrateo,0) ELSE  NVL(FNIMPORTE,0) END  IMPORTE,
                  CASE
                     WHEN FNIMPORTECOMPROBA = 0 THEN CASE WHEN queEtapaEs = '43704322352eae467857576064357523' THEN NVL(importeProrrateo,0) ELSE  NVL(FNIMPORTE,0) END
                     ELSE FNIMPORTECOMPROBA
                  END IMPORTEREAL,
                  CASE WHEN queEtapaEs = '43704322352eae467857576064357523' THEN '$' || PCKCONVENIOS.formatComas (NVL(importeProrrateo,0)) ELSE  '$' || PCKCONVENIOS.formatComas (NVL(FNIMPORTE,0)) END IMPORTECOMAS,
                  /*'$' || PCKCONVENIOS.formatComas (NVL(FNIMPORTE,0)) IMPORTECOMAS,*/
                  FCCENTROCOSTOS CENTROCOSTOS,
                  CASE
                     WHEN IDTIPOMOVTO IN (4,50)
                     THEN
                        FCCREDITOCARTERA
                     WHEN IDTIPOMOVTO = 42
                     THEN
                        'IMPORTE GENERAL'
                     WHEN IDTIPOMOVTO = 43
                     THEN
                        'IMPORTE FACTURACION'
                     ELSE
                        SUBSTR (FCDETALLECREDITO,
                                1,
                                INSTR (FCDETALLECREDITO, '|') - 1)
                  END
                     CREDITO,
                  CASE
                     WHEN IDTIPOMOVTO IN (4,50)
                     THEN
                        (SELECT NMDESCRIPCION
                           FROM CTCARTERA SS
                          WHERE SS.IDCARTERA = A.FCCREDITOCARTERA)
                     WHEN IDTIPOMOVTO = 42
                     THEN
                        ''
                     WHEN IDTIPOMOVTO = 43
                     THEN
                        ''
                     ELSE
                        SUBSTR (FCDETALLECREDITO,
                                  INSTR (FCDETALLECREDITO,
                                         '|',
                                         1,
                                         1)
                                + 1,
                                  INSTR (FCDETALLECREDITO,
                                         '|',
                                         1,
                                         2)
                                - INSTR (FCDETALLECREDITO,
                                         '|',
                                         1,
                                         1)
                                - 1)
                  END
                     DEUDOR
             FROM FACTURAASIGNACION A
            WHERE IDGASTOMAIN = pnSolicitud
         ORDER BY 1, 2, FDFECREGISTRO DESC;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getDetalleAsignacion;

   PROCEDURE validaArchivoAsigna (pnSolicitud          INTEGER,
                                  pnConcepto           NUMBER,
                                  psQueTramite         VARCHAR2,
                                  psTipomovto          INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL [43] X IMP FACTURACION*/
                                  psNmFile             VARCHAR2,
                                  quienSolic           INTEGER,
                                  queUsuPM             VARCHAR2,
                                  psAPPUID             VARCHAR2,
                                  psError          OUT VARCHAR2,
                                  psTotRegistros   OUT INTEGER)
   IS
      vsError            VARCHAR2 (4000) := '0';
      vsQueHay           VARCHAR2 (4000) := '0';
      creaLoder          VARCHAR2 (4000) := '0';
      nmTabla            VARCHAR2 (40) := '';
      vnconcepto         INTEGER := 0;
      vnCredito          VARCHAR2 (30) := '';
      vnimporte          NUMBER (15, 2) := 0;
      cuantos            INTEGER := 0;
      cuantos1           INTEGER := 0;
      cuantos2           INTEGER := 0;
      verConcepto        INTEGER := 0;
      cuantosSon         INTEGER := 0;
      ConceptoSon        INTEGER := 0;
      ConcepSon1         INTEGER := 0;
      psTotros1          INTEGER := 0;
      hayFactmain        INTEGER := 0;
      numConceptos       VARCHAR2 (4000) := '0';
      cuadraConceptos    VARCHAR2 (4000) := '0';
      numCreditos        VARCHAR2 (4000) := '0';
      numImportes        VARCHAR2 (4000) := '0';
      numTotal           VARCHAR2 (4000) := '0';
      numValido          VARCHAR2 (4000) := '0';
      quePasoConc        VARCHAR2 (4000) := '0';
      nmConcepto         VARCHAR2 (4000) := '0';
      quePuesto          VARCHAR2 (4000) := '0';
      valConcep          VARCHAR2 (4000) := '0';
      ErrConcep          VARCHAR2 (4000) := '0';
      ErrAddConcep       VARCHAR2 (4000) := '0';
      psCadenaCarteras   VARCHAR2 (4000) := '';
      F1                 UTL_FILE.FILE_TYPE;
      vexists            BOOLEAN := NULL;
      vfile_length       NUMBER := NULL;
      vblocksize         BINARY_INTEGER := NULL;

      TYPE cur_typ IS REF CURSOR;

      cuBarre            cur_typ;
      cuBarConc          cur_typ;
      cuConcepto         cur_typ;
   BEGIN
      psTotRegistros := 0;
      nmTabla := 'GTO' || pnSolicitud || 'PASO';

      -- BORRA LA TABLA SI EXISTE POR SI SE REPITIESE EL PROCESO
      BEGIN
         EXECUTE IMMEDIATE ('DROP TABLE PENDUPM.' || nmTabla);
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;

      psError := '0';
      creaLoder :=
            'CREATE TABLE PENDUPM.'
         || nmTabla
         || '
                (
                  CONCEPTO          INTEGER,
                  CREDITO           VARCHAR2(50 BYTE),
                  IMPORTE           NUMBER(15,2),
                  DESCRIPCION       VARCHAR2(500 BYTE)
                )
                ORGANIZATION EXTERNAL
                (
                    TYPE ORACLE_LOADER
                    DEFAULT DIRECTORY GASTOS
                    ACCESS PARAMETERS
                    (
                       RECORDS DELIMITED BY NEWLINE SKIP 1
                       CHARACTERSET "UTF8"
                       fields terminated by "," LRTRIM
                       REJECT ROWS WITH ALL NULL FIELDS
                    )
                    location ('''
         || psNmFile
         || ''')
                ) REJECT LIMIT UNLIMITED';

      --- crea la tabla  externa
      EXECUTE IMMEDIATE (creaLoder);

      --DBMS_OUTPUT.PUT_LINE('se ejecuta    '||creaLoder);

      -- obtiene el puesto del solicitante
      SELECT "cvepue"
        INTO quePuesto
        FROM PENDUPM.VISTAASOCIADOS
       WHERE "cvetra" = quienSolic;

      --- borra por si se quedo algun concepto sin creditos
      --     DELETE FACTURACIONMAIN WHERE IDGASTOMAIN = pnSolicitud AND IDGASTOMAIN NOT IN (SELECT IDGASTOMAIN FROM FACTURAASIGNACION WHERE IDGASTOMAIN = pnSolicitud);

      --- verifica conceptos
      numTotal := 'SELECT DISTINCT CONCEPTO FROM PENDUPM.' || nmTabla;
      DBMS_OUTPUT.put_line ('query  conceptoees  es ...** ' || numTotal);
      psTotRegistros := 0;

      OPEN cuBarConc FOR numTotal;

      LOOP
         FETCH cuBarConc INTO ConceptoSon;

         valConcep :=
               'SELECT IDCONCEPTO
              FROM CTCATALOGOCUENTAS A
             WHERE IDCONCEPTO = '
            || ConceptoSon
            || '
               AND FCPUESTOGASTO LIKE ''%'
            || quePuesto
            || '%''
               AND FCSTATUS = ''A'' AND APLICAPROCESO = ''S''';

         IF UPPER (psQueTramite) = 'ANTICIPO'
         THEN
            psCadenaCarteras := psCadenaCarteras || ' AND FCANTICIPO = ''S'' ';
         ELSIF UPPER (psQueTramite) = 'REEMBOLSO'
         THEN
            psCadenaCarteras :=
               psCadenaCarteras || ' AND FCREEMBOLSO = ''S'' ';
         ELSIF UPPER (psQueTramite) = 'TRAMITE'
         THEN
            psCadenaCarteras := psCadenaCarteras || ' AND FCTRAMITE = ''S'' ';
         ELSE
            psCadenaCarteras := psCadenaCarteras || ' AND FCTRAMITE = ''X'' ';
         END IF;

         --             IF ( psTipomovto = 2 OR psTipomovto = 3 ) THEN  psCadenaCarteras := psCadenaCarteras||' AND FCAPLCREDITO = ''S'''; END IF;
         --             IF ( psTipomovto = 3 ) THEN  psCadenaCarteras := psCadenaCarteras||' AND FCAPLMCREDITO = ''S'''; END IF;
         psTotros1 := 0;
         valConcep := valConcep || ' ' || psCadenaCarteras;

         DBMS_OUTPUT.put_line (
            'cadena es ...** ' || valConcep || '----' || psTotros1);

         ---- Se verifica si hay
         OPEN cuConcepto FOR valConcep;

         LOOP
            FETCH cuConcepto INTO ConcepSon1;

            DBMS_OUTPUT.put_line (
               'el valor del concepto ...** ' || ConcepSon1 || '***');
            EXIT WHEN cuConcepto%NOTFOUND;
            psTotros1 := psTotros1 + 1;
         END LOOP;

         CLOSE cuConcepto;

         DBMS_OUTPUT.put_line ('existe el concepto ...** ' || psTotros1);

         IF (psTotros1 > 0)
         THEN
            DBMS_OUTPUT.put_line (
                  '}} agrega concepto }} ...** '
               || ConceptoSon
               || '-'
               || psQueTramite);
            PCKFACTURACIONGASTO.addConceptoGasto (pnSolicitud,
                                                  ConceptoSon,
                                                  psQueTramite,
                                                  quienSolic,
                                                  queUsuPM,
                                                  3,
                                                  psAPPUID,
                                                  quePasoConc);
            DBMS_OUTPUT.put_line (
               '[[se agrego CONCEPTO ]] ...** ' || quePasoConc);

            IF (quePasoConc != '0')
            THEN
               ErrConcep := quePasoConc;
               EXIT;
            ELSE
               ErrConcep := quePasoConc;
            END IF;
         ELSE
            SELECT COUNT (1)
              INTO hayFactmain
              FROM CTCATALOGOCUENTAS
             WHERE IDCONCEPTO = ConceptoSon;

            IF (hayFactmain > 0)
            THEN
               BEGIN
                  SELECT NMCONCEPTO
                    INTO nmConcepto
                    FROM CTCATALOGOCUENTAS
                   WHERE IDCONCEPTO = ConceptoSon;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     nmConcepto := 'INDEFINIDO';
               END;

               ErrConcep :=
                     'EL Concepto '
                  || nmConcepto
                  || ' NO es valido para el Usuario, Tipo de Solicitud y Tipo de Captura';
               EXIT;
            END IF;
         END IF;

         psTotRegistros := psTotRegistros + 1;
         EXIT WHEN cuBarConc%NOTFOUND;
      END LOOP;

      CLOSE cuBarConc;

      DBMS_OUTPUT.put_line ('***RESULTADO es  ...** ' || ErrConcep);

      --     --- VALIDA QUE EL ARCHIVO TENGA LA INFORMACION DEL CONCEPTO
      --     SELECT NMCONCEPTO INTO nmConcepto FROM CTCATALOGOCUENTAS WHERE IDCONCEPTO = pnConcepto ;
      --     cuadraConceptos := 'SELECT COUNT(1) INTO :cuantosSon FROM PENDUPM.'||nmTabla||' WHERE CONCEPTO != '||pnConcepto||'';
      --     EXECUTE IMMEDIATE cuadraConceptos INTO cuantosSon;
      IF (ErrConcep = '0')
      THEN
         --          PCKFACTURACIONGASTO.addConceptoGasto(pnSolicitud,pnConcepto,psQueTramite, quienSolic,queUsuPM,3,psAPPUID,quePasoConc);
         --          IF ( quePasoConc = '0') THEN

         psError := '0';
         psTotRegistros := 0;
         ---  Total de Registros de la tabla
         numTotal := 'SELECT CREDITO FROM PENDUPM.' || nmTabla;

         OPEN cuBarre FOR numTotal;

         LOOP
            FETCH cuBarre INTO vnCredito;

            EXIT WHEN cuBarre%NOTFOUND;
            psTotRegistros := psTotRegistros + 1;
         END LOOP;

         CLOSE cuBarre;

         DBMS_OUTPUT.put_line ('checa creditos1');

         IF (psTotRegistros > 0)
         THEN
            ---- Valida conceptos
            numConceptos :=
                  'SELECT CREDITO,CONCEPTO FROM PENDUPM.'
               || nmTabla
               || ' WHERE CONCEPTO NOT IN (SELECT IDCONCEPTO FROM CTCATALOGOCUENTAS)';
            cuantos := 0;

            OPEN cuBarre FOR numConceptos;

            LOOP
               FETCH cuBarre INTO vnCredito, vnconcepto;

               EXIT WHEN cuBarre%NOTFOUND;
               cuantos := cuantos + 1;

               IF (cuantos = 1)
               THEN
                  psError := psError || ' *ERROR CONCEPTOS* ';
               END IF;

               psError := psError || vnCredito || '(' || vnconcepto || '),';
            END LOOP;

            CLOSE cuBarre;

            DBMS_OUTPUT.put_line ('checa conceptos1');

            IF (psError = '0')
            THEN
               ---- Verifica si hay conceptos que NO existan en la solicitud
               numValido :=
                     'SELECT CONCEPTO FROM PENDUPM.'
                  || nmTabla
                  || ' WHERE CONCEPTO NOT IN (SELECT IDCONCEPTO FROM FACTURACIONMAIN WHERE IDGASTOMAIN = '
                  || pnSolicitud
                  || ')';
               DBMS_OUTPUT.put_line ('::::::' || numValido);
               cuantos := 0;

               OPEN cuBarre FOR numValido;

               LOOP
                  FETCH cuBarre INTO cuantos2;

                  EXIT WHEN cuBarre%NOTFOUND;
                  cuantos := cuantos + 1;

                  IF (cuantos = 1)
                  THEN
                     psError := psError || ' *CONCEPTOS INEXISTENTES* ';
                  END IF;

                  psError := psError || '[' || cuantos2 || '],';
               END LOOP;

               CLOSE cuBarre;

               DBMS_OUTPUT.put_line ('checa ceonto vs conceptos solicitud');
            END IF;

            --- Valida Creditos
            IF (psError = '0')
            THEN
               numCreditos :=
                     'SELECT CREDITO FROM PENDUPM.'
                  || nmTabla
                  || ' WHERE CREDITO NOT IN (SELECT DMACCT FROM RCVRY.DELQMST)';
               cuantos := 0;

               OPEN cuBarre FOR numCreditos;

               LOOP
                  FETCH cuBarre INTO vnCredito;

                  EXIT WHEN cuBarre%NOTFOUND;
                  cuantos := cuantos + 1;

                  IF (cuantos = 1)
                  THEN
                     psError := psError || ' *CREDITOS INVALIDOS* ';
                  END IF;

                  psError := psError || '[' || vnCredito || '],';
               END LOOP;

               CLOSE cuBarre;

               DBMS_OUTPUT.put_line ('checa creditos n master');
            END IF;

            --- Valida inportes
            IF (psError = '0')
            THEN
               numImportes :=
                     'SELECT CREDITO , NVL(IMPORTE,0) FROM PENDUPM.'
                  || nmTabla
                  || ' WHERE IMPORTE < 0';
               cuantos := 0;

               OPEN cuBarre FOR numImportes;

               LOOP
                  FETCH cuBarre INTO vnCredito, vnimporte;

                  EXIT WHEN cuBarre%NOTFOUND;
                  cuantos := cuantos + 1;

                  IF (cuantos = 1)
                  THEN
                     psError := psError || ' *ERROR IMPORTES* ';
                  END IF;

                  psError := psError || vnCredito || '(' || vnimporte || '),';
               END LOOP;

               CLOSE cuBarre;
            END IF;
         ELSE
            psError := '*ERROR* NO HAY INFORMACION EN EL ARCHIVO';
         END IF;

         DBMS_OUTPUT.put_line ('*** SE GRABA O NNO QUEDA -----' || psError);

         IF (psError = '0')
         THEN
            COMMIT;
         ELSE
            ROLLBACK;
            psError := psError;
         END IF;
      ELSE
         ROLLBACK;
         psError := ErrConcep;
      --        'Existen Registros NO validos para el Concepto '||nmConcepto||' verifique ..!! '||cuadraConceptos;
      END IF;
   --      dbms_output.put_line('checa importes');
   --     IF ( psError != '0') THEN
   --           --- BORRA LA TABLA DE PASO
   --           EXECUTE IMMEDIATE ('DROP TABLE PENDUPM.'||nmTabla);
   --           --- BORRA EL ARCHIVO FISICO
   --           UTL_FILE.FGETATTR('GASTOS',psNmFile,vexists,vfile_length,vblocksize);
   --           IF vexists THEN
   --             UTL_FILE.FREMOVE ('GASTOS',psNmFile);
   --           ELSE
   --             DBMS_OUTPUT.PUT_LINE('NO EXISTE EL ARCHIVO '||'PASO100_18148.log');
   --           END IF;
   --     END IF;

   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;

         IF (INSTR (SQLERRM, 'ODCIEXTTABLEOPEN') > 0)
         THEN
            psError :=
               '**ERROR** En la Carga del Archivo, Inconsistencia de Datos';
         ELSE
            psError := '**ERROR** ' || SQLERRM;
         END IF;

         DBMS_OUTPUT.PUT_LINE ('-1 ' || SQLERRM);
   END validaArchivoAsigna;

   PROCEDURE validaCreditoAsigna (pnSolicitud         INTEGER,
                                  psCredito           VARCHAR2, /* SI  es psTipomovto = 4 [valor CARTERA]  psTipomovto = 42 [CONCEPTO ]*/
                                  pnConcepto          NUMBER,
                                  pnImporte           NUMBER,
                                  psTipomovto         INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL */
                                  psCentroCosto       VARCHAR2, /* Solo valido si es CArtera ? Importe General */
                                  psFechaPgoIni      VARCHAR2,
                                  psFechaPgoFin      VARCHAR2,
                                  idplanviaje        NUMBER,
                                  psError         OUT VARCHAR2)
   IS
      queTipoJuicio      NUMBER (5) := '';
      queTipoDemanda     NUMBER (5) := '';
      queUmbralRebaso    NUMBER (10) := 0;
      queCodAccion       VARCHAR2 (1000) := 'N';
      queCodResultado    VARCHAR2 (1000) := 'N';
      quePagoDoble       NUMBER (10) := 0;
      queEtapaCRAVER     VARCHAR2 (2000) := '';
      queEtapaABTA       VARCHAR2 (2000) := '';
      queEtapaFinal      VARCHAR2 (20) := '';
      cuantosSon         INTEGER := 0;
      psQuery            VARCHAR2 (4000) := '';
      ubica              INTEGER := 0;
      vnBarre            INTEGER := 0;
      cadena1            VARCHAR2 (4000) := '';
      valor              VARCHAR2 (4000) := '';
      contador           INTEGER := 0;
      usuSolic           VARCHAR2 (15) := '';
      importeUmbral      NUMBER (10, 2) := 0;
      importeRebasado    NUMBER (10, 2) := 0;
      psCatEtaCraVer     VARCHAR2 (500) := '';
      psCatEtaAbi        VARCHAR2 (500) := '';
      psCatCodAcc        VARCHAR2 (6) := '';
      psCatCodRes        VARCHAR2 (6) := '';
      psCatEtaFinal      VARCHAR2 (500) := '';
      vsCentroCostos     VARCHAR2 (10) := '';
      psQueJuicios       VARCHAR2 (500) := '';
      cadenaArma         VARCHAR2 (4000) := '';
      verCreditoOk       VARCHAR2 (4000) := '0';
      verCreditoOkFac    VARCHAR2 (4000) := '';
      verCreditoOkRee    VARCHAR2 (4000) := '';
      queCarterasRee     VARCHAR2 (4000) := '';
      queCarterasFac     VARCHAR2 (4000) := '';
      queVALCarteras     VARCHAR2 (4000) := '';
      esCArtera          VARCHAR2 (4000) := '';
      suCArtera          VARCHAR2 (15) := '';
      esIndicador        VARCHAR2 (4000) := '';
      cualOtroTipo       VARCHAR2 (4000) := '';
      esFacturable       CHAR (1) := 'N';
      esReembolsable     CHAR (1) := 'N';
      esLIQUIDADO        VARCHAR2 (10) := '';
      queEstatusEs       VARCHAR2 (15) := '';
      queColaEs          VARCHAR2 (15) := '';
      queEstatusEs1      VARCHAR2 (15) := '';
      queColaEs1         VARCHAR2 (15) := '';
      existeColaStat     INTEGER := 0;
      idDynamics         VARCHAR2 (30) := '';
      esTramFact         VARCHAR2 (30) := '';
      pnPagoDoble        NUMBER (5) := 0;
      pnPagoDoblePM      NUMBER (5) := 0;
      pnPagoDobleDYN     NUMBER (5) := 0;
      psCuentaContable   VARCHAR2 (30) := '';
      queOperacion       VARCHAR2 (30) := '';
      yaExiste           INTEGER := 0;
      pnQueUmbral        INTEGER := 0;
      existeConc         INTEGER := 0;
      hayCabecero        INTEGER := 0;
      hayOtroTipo        INTEGER := 0;
      hayJuicioCred      INTEGER := 0;
      existeEtapaCrra    INTEGER := 0;
      existeEtapaAbie    INTEGER := 0;
      existeCA           INTEGER := 0;
      existeCR           INTEGER := 0;
      pnActimporte       NUMBER (10, 2) := pnImporte;
      permiteStatus      VARCHAR2 (500) := '';
      permiteCola        VARCHAR2 (500) := '';
      statusValido       INTEGER := 0;
      debeStatusValido   INTEGER := 0;
      unificaCredito     INTEGER := CASE WHEN psTipomovto = 3 THEN 2 ELSE psTipomovto END;
      exiteEnAsigna      INTEGER := 0;
      correoProjMang     VARCHAR2 (50) := '';
      tipoNoFactura1     VARCHAR2 (15) := '';
      tipoNoFactura2     VARCHAR2 (15) := '';
      CARTERA_NOVALIDA   EXCEPTION;
        fecha_pago_ini    DATE;
      fecha_pago_fin    DATE;
      esPagoServicio    INTEGER := 0;
      esPagoDoble       INTEGER := 0;
      sqmlEtapasLegales VARCHAR2 (2000) := '';
      strElementos       STRING_FNC.t_array;
      totalEtapasCerradas INTEGER     := 0;
      totalEtapasAbiertas INTEGER     := 0;
      fnmontoTotal      INTEGER     := 0;

      TYPE CUR_TYP IS REF CURSOR;
      cursor_Legales   CUR_TYP;


      CURSOR cuConcepto
      IS
         SELECT *
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = pnConcepto;

      CURSOR cuJuicios (tpoDem NUMBER)
      IS
         SELECT CCCASENO, CCCASENO CCCASENODESC
           FROM RCVRY.CASEACCT
          WHERE     CCACCT = psCredito
                AND CCCASENO IN (SELECT CECASENO
                                   FROM RCVRY.CASE
                                  WHERE CESTATUS = 'A')
                AND CCCASENO IN (SELECT NUMERO
                                   FROM OPERACION.ELP_JUICIO
                                  WHERE ID_TIPO_DEMANDA = tpoDem);

      CURSOR cuEtapaCrraVerif(
         psjuicio    INTEGER,
         psEtapa     VARCHAR2)
         IS
           SELECT *
             FROM OPERACION.VW_ELP_ETAPAS_LEGALES
            WHERE     NUMERO_JUICIO = psjuicio
                  AND EN_PROCESO = 0
                  AND EN_PROCESO_PM = 0
                  AND ES_RETROCESO_ETAPAS= 0
                  --AND ES_RETROCESO= 0
                  AND FECHA_TERMINO IS NOT NULL
                  AND RESULTADO_VERIFICACION = 'CORRECTO'
                  AND NUMERO_ETAPA = psEtapa
         ORDER BY ORDEN DESC;

      CURSOR cuEtapaAbierta (
         psjuicio    INTEGER,
         psEtapa     VARCHAR2)
      IS
           SELECT *
             FROM OPERACION.VW_ELP_ETAPAS_LEGALES
            WHERE     NUMERO_JUICIO = psjuicio
                  AND EN_PROCESO = 0
                  AND FECHA_TERMINO IS NULL
                  AND NUMERO_ETAPA = psEtapa
                  AND ORDEN =
                         (SELECT MAX (ORDEN)
                            FROM OPERACION.VW_ELP_ETAPAS_LEGALES
                           WHERE     NUMERO_JUICIO = psjuicio
                                 AND EN_PROCESO = 0
                                 AND FECHA_TERMINO IS NULL
                                 AND NUMERO_ETAPA = psEtapa)
         ORDER BY ORDEN DESC;

      CURSOR cuDetCredito
      IS
         SELECT DM.DMACCT credito,
                DM.DMNAME deudor,
                DM.DMQUE cola,
                NVL (UPPER (U1CARTERA), UPPER (U2CARTERA)) CARTERA,
                DM.DMBRANCH CCOSTO,
                NVL (U1STATUS, U2STATUS) STATUS,
                FCDYNAMICS IDDYNAMICS
           FROM RCVRY.DELQMST DM
                LEFT JOIN RCVRY.UDA1 U1 ON (DM.DMACCT = U1.U1ACCT)
                LEFT JOIN RCVRY.UDA2 U2 ON (DM.DMACCT = U2.U2ACCT)
                LEFT JOIN CTCREDITODYNAMICS CD ON (CD.FCCREDITO = DM.DMACCT)
          WHERE DM.DMACCT = psCredito;

        CURSOR cuCreditosPagados IS
         SELECT * FROM (SELECT FA.IDGASTOMAIN, FA.IDCONCEPTO, FA.FCCREDITOCARTERA,
            FDFECREALPAGO, FCREMESA, FDFECSERVPAGADODEL, FDFECSERVPAGADOAL,
            ( CASE WHEN ( SELECT COUNT(1) FROM PENDUPM.FACTURACIONBITACORA
                           WHERE IDGASTOMAIN = FA.IDGASTOMAIN AND IDTASKGASTO = '4515947455273e63c4198f0073790158'
                                                  AND FCRESULTADO = 'Autorizado' ) > 0
                   THEN FNIMPORTECOMPROBA
                   ELSE FNIMPORTE END ) MONTO_TOTAL
            FROM PENDUPM.FACTURAASIGNACION FA INNER JOIN PENDUPM.FACTURACIONMAIN FM ON (FA.IDGASTOMAIN = FM.IDGASTOMAIN AND FA.IDCONCEPTO = FM.IDCONCEPTO)
                                              INNER JOIN PENDUPM.CTCATALOGOCUENTAS CT ON ( FA.IDCONCEPTO = CT.IDCONCEPTO )
            WHERE
            FA.FCCREDITOCARTERA = psCredito
            AND FA.IDCONCEPTO = pnConcepto
            AND (FA.FDFECSERVPAGADODEL IS NOT NULL OR FA.FDFECSERVPAGADOAL IS NOT NULL)
            AND FA.IDGASTOMAIN != pnSolicitud AND FM.FCSTATUS NOT IN ('Z','R')
            AND FA.STATUS = 'A' AND CT.FCPAGODOBLE = 'S'
            ) WHERE MONTO_TOTAL > 0 ORDER BY FDFECSERVPAGADODEL;


        CURSOR cuCreditosPagadosSinFechas IS
         SELECT * FROM (SELECT FA.IDGASTOMAIN, FA.IDCONCEPTO, FA.FCCREDITOCARTERA,
            FDFECREALPAGO, FCREMESA, FDFECSERVPAGADODEL, FDFECSERVPAGADOAL,
            ( CASE WHEN ( SELECT COUNT(1) FROM PENDUPM.FACTURACIONBITACORA
                           WHERE IDGASTOMAIN = FA.IDGASTOMAIN AND IDTASKGASTO = '4515947455273e63c4198f0073790158'
                                                  AND FCRESULTADO = 'Autorizado' ) > 0
                   THEN FNIMPORTECOMPROBA
                   ELSE FNIMPORTE END ) MONTO_TOTAL
            FROM PENDUPM.FACTURAASIGNACION FA INNER JOIN PENDUPM.FACTURACIONMAIN FM ON (FA.IDGASTOMAIN = FM.IDGASTOMAIN AND FA.IDCONCEPTO = FM.IDCONCEPTO)
                                              INNER JOIN PENDUPM.CTCATALOGOCUENTAS CT ON ( FA.IDCONCEPTO = CT.IDCONCEPTO )
            WHERE
            FA.FCCREDITOCARTERA = psCredito
            AND FA.IDCONCEPTO = pnConcepto
            AND (FA.FDFECSERVPAGADODEL IS NULL AND FA.FDFECSERVPAGADOAL IS NULL)
            AND FA.IDGASTOMAIN != pnSolicitud AND FM.FCSTATUS NOT IN ('Z','R')
            AND FA.STATUS = 'A' AND CT.FCPAGODOBLE = 'S'
            ) WHERE MONTO_TOTAL > 0 ORDER BY FDFECSERVPAGADODEL;

   BEGIN

      BEGIN
         SELECT DISTINCT TPOMOVIMIENTO
           INTO queOperacion
           FROM FACTURACIONMAIN
          WHERE IDGASTOMAIN = pnSolicitud;
      EXCEPTION
         WHEN OTHERS
         THEN
            queOperacion := NULL;
      END;

      SELECT COUNT (1)
        INTO hayOtroTipo
        FROM FACTURAASIGNACION
       WHERE IDGASTOMAIN = pnSolicitud AND IDTIPOMOVTO != unificaCredito;

      IF (hayOtroTipo = 0)
      THEN
         SELECT COUNT (1)
           INTO yaExiste
           FROM FACTURAASIGNACION
          WHERE     IDGASTOMAIN = pnSolicitud
                AND IDCONCEPTO = pnConcepto
                AND IDTIPOMOVTO = unificaCredito
                AND FCCREDITOCARTERA = psCredito;

         IF (yaExiste = 0 OR psTipomovto = 42 OR psTipomovto = 4)
         THEN
            psError := '0';

            ---  Carga informacion del Concepto con que se va a Validar
            FOR regConcepto IN cuConcepto
            LOOP
               queCarterasRee := regConcepto.FCCARTERAASIGNADA;
               queCarterasFac := regConcepto.FCCARTERAASIGFAC;
               psCuentaContable := regConcepto.FCCUENTACONTABLE;

               IF (UPPER (queOperacion) != 'TRAMITE')
               THEN
                  --****** Verifica umbral de importe ********
                  IF (   (    regConcepto.VERMONTO01 IS NOT NULL )
                      OR (    regConcepto.VERMONTO02 IS NOT NULL )
                      OR (    regConcepto.VERMONTO03 IS NOT NULL )
                     )
                  THEN
                     -- Revisa contra primer monto
                     IF (pnImporte <= regConcepto.VERMONTO01)
                     THEN
                        queUmbralRebaso := 0;
                        importeUmbral := regConcepto.VERMONTO01;
                        pnQueUmbral := 0;
           END IF;
                     -- Revisa contra segundo monto
                     IF (pnImporte > regConcepto.VERMONTO01 AND regConcepto.AUTMONTO01 IS NOT NULL)
                     THEN
                        queUmbralRebaso := pnImporte;
                        importeUmbral := regConcepto.VERMONTO01;
                        pnQueUmbral := 1;
           END IF;
                     -- Revisa contra tercer monto
                     IF (pnImporte > regConcepto.VERMONTO02 AND regConcepto.AUTMONTO02 IS NOT NULL)
                     THEN
                        queUmbralRebaso := pnImporte;
                        importeUmbral := regConcepto.VERMONTO02;
                        pnQueUmbral := 2;
           END IF;
                     --- si rebasa el Tercer Monto
                     IF (pnImporte > regConcepto.VERMONTO03 AND regConcepto.AUTMONTO03 IS NOT NULL)
                     THEN
                        queUmbralRebaso := pnImporte;
                        importeUmbral := regConcepto.VERMONTO03;
                        pnQueUmbral := 3;
                     END IF;
                  END IF;

                  esTramFact := regConcepto.FCIMPFACTTRAMITE;
               ELSE
                  esTramFact := regConcepto.FCIMPFACTTRAMITE;
                  queUmbralRebaso := 0;
                  importeUmbral := 0;
                  pnQueUmbral := 0;
               END IF;                               --- SOLO SI NO ES TRAMITE

               IF (psTipomovto = 2 OR psTipomovto = 3)
               THEN
                  psCatEtaCraVer := regConcepto.VERETAPACDACHK;
                  psCatEtaAbi := regConcepto.VERETAPAABIERTA;
                  psCatCodAcc := regConcepto.FCCODACCEXT;
                  psCatCodRes := regConcepto.FCCODRESEXT;
                  psCatEtaFinal := regConcepto.VERETAPACDACHKFIN;

                  DBMS_OUTPUT.PUT_LINE ('ETAPAS  psCatEtaCraVer' || psCatEtaCraVer);
                  DBMS_OUTPUT.PUT_LINE ('ETAPAS  psCatEtaAbi' || psCatEtaAbi);
                  DBMS_OUTPUT.PUT_LINE ('ETAPAS  psCatCodAcc' || psCatCodAcc);
                  DBMS_OUTPUT.PUT_LINE ('ETAPAS  psCatCodRes' || psCatCodRes);
                  DBMS_OUTPUT.PUT_LINE ('ETAPAS  psCatEtaFinal' || psCatEtaFinal);

                  --****** Verifica Etapas Procesales / JUICIOS ACTIVOS ********
                  IF (   (regConcepto.VERETAPACDACHK IS NOT NULL)
                      OR (regConcepto.VERETAPAABIERTA IS NOT NULL)
                      OR (regConcepto.FCCODACCEXT IS NOT NULL)
                      OR (regConcepto.FCCODRESEXT IS NOT NULL))
                  THEN
                     DBMS_OUTPUT.PUT_LINE ('ETAPAS ENTRO A VALIDAR');

                     --DBMS_OUTPUT.PUT_LINE('ENTRO ETAPAS---');
                     queEtapaCRAVER := '';
                     queEtapaABTA := '';

                     SELECT COUNT (1)
                       INTO hayJuicioCred
                       FROM RCVRY.CASEACCT
                      WHERE     CCACCT = psCredito
                            AND CCCASENO IN (SELECT CECASENO
                                               FROM RCVRY.CASE
                                              WHERE CESTATUS = 'A')
                            AND CCCASENO IN (SELECT NUMERO
                                               FROM OPERACION.ELP_JUICIO
                                              WHERE ID_TIPO_DEMANDA = 2);

                     IF (hayJuicioCred = 0)
                     THEN
                        queEtapaCRAVER :=
                              queEtapaCRAVER
                           || 'EL CREDITO '
                           || psCredito
                           || ' NO TIENE JUICIOS ACTIVOS<BR/>';
                        queEtapaABTA :=
                              queEtapaABTA
                           || 'EL CREDITO '
                           || psCredito
                           || ' NO TIENE JUICIOS ACTIVOS<BR/>';
                     END IF;

                     DBMS_OUTPUT.PUT_LINE (
                        'VERIFICA JUICIOS ACTIVOS ' || queEtapaCRAVER);

                     FOR regjuicios IN cuJuicios (2)
                     LOOP
                        /*  IDTIPODEMANDA = 1  EN CONTRA   /  IDTIPODEMANDA = 2  DEMANDA NUESTRA */
                        /*  OPERACION.ELP_JUICIO campo  ID_TIPO_DEMANDA del catalogo OPERACION.CAT_TIPO_DEMANDA */
                        --- Obtiene el Tipo de Demanda del Juicio
                        --- Obtiene Valores para juicio
                        BEGIN
                           SELECT ID_TIPO_DEMANDA, ID_TIPO_JUICIO
                             INTO queTipoJuicio, queTipoDemanda
                             FROM OPERACION.ELP_JUICIO
                            WHERE NUMERO = regjuicios.CCCASENO;
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              queTipoJuicio := NULL;
                              queTipoDemanda := NULL;
                        END;

                        ---  Barre para Validar las ETAPAS CERADAS Y VERIFICADAS del JUICIO
                        queEtapaCRAVER := '';
                        queEtapaABTA := '';
                        existeEtapaCrra := 0;

                        IF ( (regConcepto.VERETAPACDACHK IS NOT NULL))
                        THEN
                           existeEtapaCrra := 0;

                           sqmlEtapasLegales := 'SELECT COUNT(1) TOTAL FROM OPERACION.VW_ELP_ETAPAS_LEGALES WHERE NUMERO_JUICIO = '|| regjuicios.CCCASENO ||'
                                AND EN_PROCESO = 0
                                AND EN_PROCESO_PM = 0
                                AND ES_RETROCESO_ETAPAS= 0
                                AND FECHA_TERMINO IS NOT NULL
                                AND RESULTADO_VERIFICACION = ''CORRECTO''
                                AND NUMERO_ETAPA IN ('|| replace(regConcepto.VERETAPACDACHK,'|',',') ||')
                              ORDER BY ORDEN DESC';

                           open cursor_Legales for sqmlEtapasLegales;
                            LOOP
                              FETCH cursor_Legales INTO fnmontoTotal;
                                EXIT WHEN cursor_Legales%NOTFOUND;
                                totalEtapasCerradas := fnmontoTotal;
                            END LOOP;
                           CLOSE cursor_Legales;

                            IF ( totalEtapasCerradas > 0 ) THEN
                              existeEtapaCrra := 0;

                            ELSE
                             existeEtapaCrra := existeEtapaCrra;
                             cadena1 := regConcepto.VERETAPACDACHK || '|';
                             ubica := INSTR (cadena1, '|');

                            WHILE (ubica > 0)
                            LOOP
                              valor := SUBSTR (cadena1, 1, ubica - 1);
                              contador := 0;

                              FOR regEtapa
                                 IN cuEtapaCrraVerif (regjuicios.CCCASENO,
                                                      valor)
                              LOOP
                                 contador := contador + 1;
                                 queEtapaCRAVER := '';

                                 IF (regEtapa.RESULTADO_VERIFICACION !=
                                        'CORRECTO')
                                 THEN
                                    queEtapaCRAVER :=
                                          queEtapaCRAVER
                                       || 'LA ETAPA ['
                                       || valor
                                       || '] FUE CALIFICADA COMO '
                                       || regEtapa.RESULTADO_VERIFICACION
                                       || ' EL DIA '
                                       || PCKCTRLDOCUMENTAL01.aplFecha (
                                             regEtapa.FECHA_VERIFICACION)
                                       || '<BR/>';
                                 ELSIF (regEtapa.RESULTADO_VERIFICACION =
                                           'CORRECTO')
                                 THEN
                                    --- Si se cumple al menos una de las etapas se sale
                                    existeEtapaCrra := 1;
                                    queEtapaCRAVER := '';
                                    EXIT;
                                 END IF;
                              END LOOP;

                              IF (existeEtapaCrra = 0)
                              THEN
                                 queEtapaCRAVER :=
                                       queEtapaCRAVER
                                    || 'LA ETAPA ['
                                    || valor
                                    || '] NO SE ENCUENTRA CERRADA Y VERIFICADA'
                                    || '<BR/>';
                              END IF;

                              cadena1 := SUBSTR (cadena1, ubica + 1);
                              ubica := INSTR (cadena1, '|');
                              DBMS_OUTPUT.PUT_LINE (
                                 'EN EL JUICIO QUE PASO ' || queEtapaCRAVER);
                            END LOOP;

                           END IF;

                        END IF;

                        IF ( (regConcepto.VERETAPAABIERTA IS NOT NULL))
                        THEN
                           cadena1 := regConcepto.VERETAPAABIERTA || '|';
                           existeEtapaAbie := 0;
                           queEtapaABTA := 'LAS SIGUIENTES ETAPAS NO ESTAN ABIERTAS: ';
                           ubica := INSTR (cadena1, '|');

                           WHILE (ubica > 0)
                           LOOP
                              valor := SUBSTR (cadena1, 1, ubica - 1);
                              contador := 0;

                              FOR regEtapa
                                 IN cuEtapaAbierta (regjuicios.CCCASENO,
                                                    valor)
                              LOOP
                                 contador := contador + 1;
                              END LOOP;

                              IF (contador = 0)
                              THEN
                                 queEtapaABTA :=
                                       queEtapaABTA
                                    || '['
                                    || valor
                                    || ']'
                                    || ' | ';
                              END IF;

                              IF (contador > 0)
                                 THEN
                                    --- Si se cumple al menos una de las etapas se sale
                                    queEtapaABTA := '';
                                    EXIT;
                              END IF;

                              cadena1 := SUBSTR (cadena1, ubica + 1);
                              ubica := INSTR (cadena1, '|');
                           END LOOP;
                        END IF;
                     END LOOP;
                  END IF;

                  --****** Verifica Codigos de Accion y Resultados del Cr?dito ********
                  queCodAccion := '';
                  queCodResultado := '';

                  IF (   (regConcepto.FCCODACCEXT IS NOT NULL)
                      OR (regConcepto.FCCODRESEXT IS NOT NULL))
                  THEN
                     IF (    (regConcepto.FCCODACCEXT IS NOT NULL)
                         AND (regConcepto.FCCODRESEXT IS NOT NULL))
                     THEN
                        FOR regjuicios IN cuJuicios (2)
                        LOOP
                            SELECT COUNT(*) INTO contador FROM OPERACION.VW_ELP_BITACORA_GESTION
                            WHERE NUMERO_JUICIO = regjuicios.CCCASENO AND CA = regConcepto.FCCODACCEXT AND CR = regConcepto.FCCODRESEXT
                            AND FECHA BETWEEN (  SYSDATE
                                                     - CASE
                                                          WHEN regConcepto.FNVIGENCIA
                                                                  IS NULL
                                                          THEN
                                                             30
                                                          ELSE
                                                             regConcepto.FNVIGENCIA
                                                       END)
                                                AND SYSDATE;

                            IF (contador = 0)
                            THEN
                               queCodAccion :=
                                     'NO Existe gestion del CA['
                                  || regConcepto.FCCODACCEXT
                                  || ']';
                               queCodResultado :=
                                     'NO Existe gestion del CR['
                                  || regConcepto.FCCODRESEXT
                                  || ']';
                            ELSE
                                queCodAccion := '';
                                queCodResultado := '';
                                EXIT;
                            END IF;
                        END LOOP;
                     ELSIF (    (regConcepto.FCCODACCEXT IS NOT NULL)
                            AND (regConcepto.FCCODRESEXT IS NULL))
                     THEN
                        FOR regjuicios IN cuJuicios (2)
                        LOOP
                            SELECT COUNT(*) INTO contador FROM OPERACION.VW_ELP_BITACORA_GESTION
                            WHERE NUMERO_JUICIO = regjuicios.CCCASENO AND CA = regConcepto.FCCODACCEXT
                            AND FECHA BETWEEN (  SYSDATE
                                                     - CASE
                                                          WHEN regConcepto.FNVIGENCIA
                                                                  IS NULL
                                                          THEN
                                                             30
                                                          ELSE
                                                             regConcepto.FNVIGENCIA
                                                       END)
                                                AND SYSDATE;
                            IF (contador = 0)
                            THEN
                               queCodAccion :=
                                     'NO Existe gestion del CA['
                                  || regConcepto.FCCODACCEXT
                                  || ']';
                               queCodResultado := '';
                            ELSE
                               queCodAccion := '';
                               queCodResultado := '';
                               EXIT;
                            END IF;
                        END LOOP;
                     ELSIF (    (regConcepto.FCCODACCEXT IS NULL)
                            AND (regConcepto.FCCODRESEXT IS NOT NULL))
                     THEN
                        FOR regjuicios IN cuJuicios (2)
                        LOOP
                            SELECT COUNT(*) INTO contador FROM OPERACION.VW_ELP_BITACORA_GESTION
                            WHERE NUMERO_JUICIO = regjuicios.CCCASENO AND CR = regConcepto.FCCODRESEXT
                            AND FECHA BETWEEN (  SYSDATE
                                                     - CASE
                                                          WHEN regConcepto.FNVIGENCIA
                                                                  IS NULL
                                                          THEN
                                                             30
                                                          ELSE
                                                             regConcepto.FNVIGENCIA
                                                       END)
                                                AND SYSDATE;
                            IF (contador = 0)
                            THEN
                               queCodAccion := '';
                               queCodResultado :=
                                     'NO Existe gestion del CR['
                                  || regConcepto.FCCODRESEXT
                                  || ']';
                            ELSE
                               queCodAccion := '';
                               queCodResultado := '';
                               EXIT;
                            END IF;
                        END LOOP;
                     ELSE
                        queCodAccion :=
                              'NO Existe gestion del CA['
                           || regConcepto.FCCODACCEXT
                           || ']';
                        queCodResultado :=
                              'NO Existe gestion del CR['
                           || regConcepto.FCCODRESEXT
                           || ']';
                     END IF;
                  END IF;

                  DBMS_OUTPUT.PUT_LINE (
                        'EN EL JUICIO COD ACCION RES  '
                     || queCodAccion
                     || '-'
                     || queCodResultado);
               ELSE
                  psCatEtaCraVer := NULL;
                  psCatEtaAbi := NULL;
                  psCatCodAcc := NULL;
                  psCatCodRes := NULL;
                  psCatEtaFinal := NULL;
                  queCodAccion := NULL;
                  queCodResultado := NULL;
                  queEtapaABTA := NULL;
                  queEtapaCRAVER := NULL;
                  cadenaArma := NULL;
               END IF;
            END LOOP;

            IF (psTipomovto = 2 OR psTipomovto = 3)
            THEN
               FOR regjuicios IN cuJuicios (2)
               LOOP
                  psQueJuicios :=
                     psQueJuicios || '[' || regjuicios.CCCASENO || '] ';
               END LOOP;

               FOR regCredito IN cuDetCredito
               LOOP
                  cadenaArma :=
                        cadenaArma
                     || regCredito.credito
                     || '|'
                     || regCredito.deudor
                     || '|'
                     || regCredito.cola
                     || '|'
                     || regCredito.CARTERA
                     || '|'
                     || regCredito.CCOSTO
                     || '|'
                     || '|'
                     || regCredito.STATUS
                     || '|'
                     || regCredito.IDDYNAMICS
                     || '|'
                     || psQueJuicios;
                  suCArtera := regCredito.CARTERA;
                  vsCentroCostos := regCredito.CCOSTO;
               END LOOP;

               --- Verifica que el Cr?dito se permita agregar por Configuracion
               strElementos := STRING_FNC.split (queCarterasRee, '|');
               verCreditoOkRee := '*';

               FOR vnBarre IN 1 .. strElementos.COUNT
               LOOP
                  queVALCarteras :=
                     SUBSTR (strElementos (vnBarre),
                             1,
                             LENGTH (strElementos (vnBarre)) - 1);
                  ubica := INSTR (queVALCarteras, '-');
                  esCArtera := SUBSTR (queVALCarteras, 1, (ubica - 1)); /* Regresa la CArtera Valida */
                  esIndicador := SUBSTR (queVALCarteras, (ubica + 1)); /* SI - NO - NOAPLICA - FORMULA */

                  IF (suCArtera = esCArtera)
                  THEN
                     IF (esIndicador = 'SI' OR esIndicador = 'NO')
                     THEN
                        verCreditoOkRee := '0';
                        esReembolsable :=
                           CASE WHEN esIndicador = 'SI' THEN 'S' ELSE 'N' END;
                     ELSIF (esIndicador = 'NOAPLICA')
                     THEN
                        verCreditoOkRee :=
                              '*ERROR* El Credito de la CARTERA '
                           || esCArtera
                           || ' NO esta permitido para esta Operacion';
                        esReembolsable := 'N';
                     ELSE
                        verCreditoOkRee :=
                              '*ERROR* El Credito de la CARTERA '
                           || esCArtera
                           || ' NO esta permitido para esta Operacion';
                        esReembolsable := 'N';
                     END IF;

                     EXIT;
                  ELSE
                     verCreditoOkRee := '*';
                     esReembolsable := 'N';
                  END IF;
               ---DBMS_OUTPUT.PUT_LINE('===:: '||suCArtera||'---'||esCArtera||'---'||esIndicador||'---'||verCreditoOk||'---'||esFacturable);
               END LOOP;

               --- Verifica que el Cr?dito se permita agregar por Configuracion
               strElementos := STRING_FNC.split (queCarterasFac, '|');
               verCreditoOkFac := '*';
               FOR vnBarre IN 1 .. strElementos.COUNT
               LOOP
                  queVALCarteras :=
                     SUBSTR (strElementos (vnBarre),
                             1,
                             LENGTH (strElementos (vnBarre)) - 1);
                  ubica := INSTR (queVALCarteras, '-');
                  esCArtera := SUBSTR (queVALCarteras, 1, (ubica - 1)); /* Regresa la CArtera Valida */
                  esIndicador := SUBSTR (queVALCarteras, (ubica + 1)); /* SI - NO - NOAPLICA - FORMULA */

                  IF (suCArtera = esCArtera)
                  THEN
                     IF (esIndicador = 'SI' OR esIndicador = 'NO')
                     THEN
                        esFacturable :=
                           CASE WHEN esIndicador = 'SI' THEN 'S' ELSE 'N' END;
                     ELSIF (esIndicador = 'NOAPLICA')
                     THEN
                        verCreditoOkFac :=
                              '*ERROR* El Credito de la CARTERA '
                           || esCArtera
                           || ' NO esta permitido para esta Operacion';
                        esFacturable := 'N';
                     ELSE
                        verCreditoOkFac :=
                              '*ERROR* El Credito de la CARTERA '
                           || esCArtera
                           || ' NO esta permitido para esta Operacion';
                        esFacturable := 'N';
                     END IF;

                     EXIT;
                  ELSE
                     verCreditoOkFac := '*';
                     esFacturable := 'N';
                  END IF;
               END LOOP;

               DBMS_OUTPUT.PUT_LINE ('verCreditoOkRee**' || verCreditoOkRee);
               DBMS_OUTPUT.PUT_LINE ('verCreditoOkFac**' || verCreditoOkFac);
               
               
               IF (verCreditoOkRee = '*' AND verCreditoOkFac = '*' )
               THEN
                  verCreditoOk :=
                        '*ERROR* El Credito '
                     || psCredito
                     || ' NO esta permitido para esta Operacion,CARTERA no valida';
                  esReembolsable := 'N';
                  esFacturable := 'N';
               END IF;
               
               psError := verCreditoOk;
               
            ELSE
               vsCentroCostos := psCentroCosto;
            END IF;
            
            DBMS_OUTPUT.PUT_LINE ('psError00**' || psError );

      -- VALIDAMOS SI LA CARTERA ES FACTURABLE
            IF (psTipomovto = 4)
            THEN
                suCArtera := psCredito;
                strElementos := STRING_FNC.split (queCarterasRee, '|');
                verCreditoOk := '0';

               FOR vnBarre IN 1 .. strElementos.COUNT
               LOOP
                  queVALCarteras :=
                     SUBSTR (strElementos (vnBarre),
                             1,
                             LENGTH (strElementos (vnBarre)) - 1);
                  ubica := INSTR (queVALCarteras, '-');
                  esCArtera := SUBSTR (queVALCarteras, 1, (ubica - 1)); /* Regresa la CArtera Valida */
                  esIndicador := SUBSTR (queVALCarteras, (ubica + 1)); /* SI - NO - NOAPLICA - FORMULA */
                  DBMS_OUTPUT.PUT_LINE('===::esCArtera:'||esCArtera||'---esCArtera');
                  IF (suCArtera = esCArtera)
                  THEN
                     IF (esIndicador = 'SI' OR esIndicador = 'NO')
                     THEN
                        verCreditoOk := '0';
                        esReembolsable :=
                           CASE WHEN esIndicador = 'SI' THEN 'S' ELSE 'N' END;
                           DBMS_OUTPUT.PUT_LINE('===::esIndicador-->EsFacturable:'||esFacturable||'---endesFacturable');
                     ELSIF (esIndicador = 'NOAPLICA')
                     THEN
                        verCreditoOk :=
                              '*ERROR* El Credito de la CARTERA '
                           || esCArtera
                           || ' NO esta permitido para esta Operacion';
                        esReembolsable := 'N';
                     ELSE
                        verCreditoOk :=
                              '*ERROR* El Credito de la CARTERA '
                           || esCArtera
                           || ' NO esta permitido para esta Operacion';
                        esReembolsable := 'N';
                     END IF;

                     EXIT;
                  ELSE
                     verCreditoOk := '*';
                     esReembolsable := 'N';
                  END IF;
               DBMS_OUTPUT.PUT_LINE('===:: '||suCArtera||'---'||esCArtera||'---'||esIndicador||'---'||verCreditoOk||'---esFacturable:'||esFacturable||'endesFacturable:');
               END LOOP;
               
               strElementos := STRING_FNC.split (queCarterasFac, '|');
               FOR vnBarre IN 1 .. strElementos.COUNT
               LOOP
                  queVALCarteras :=
                     SUBSTR (strElementos (vnBarre),
                             1,
                             LENGTH (strElementos (vnBarre)) - 1);
                  ubica := INSTR (queVALCarteras, '-');
                  esCArtera := SUBSTR (queVALCarteras, 1, (ubica - 1)); /* Regresa la CArtera Valida */
                  esIndicador := SUBSTR (queVALCarteras, (ubica + 1)); /* SI - NO - NOAPLICA - FORMULA */
                  DBMS_OUTPUT.PUT_LINE('===::esCArtera:'||esCArtera||'---esCArtera');
                  IF (suCArtera = esCArtera)
                  THEN
                     IF (esIndicador = 'SI' OR esIndicador = 'NO')
                     THEN
                        esFacturable :=
                           CASE WHEN esIndicador = 'SI' THEN 'S' ELSE 'N' END;
                           DBMS_OUTPUT.PUT_LINE('===::esIndicador-->EsFacturable:'||esFacturable||'---endesFacturable');
                     ELSIF (esIndicador = 'NOAPLICA')
                     THEN
                        esFacturable := 'N';
                     ELSE
                        esFacturable := 'N';
                     END IF;

                     EXIT;
                  ELSE
                     esFacturable := 'N';
                  END IF;
               END LOOP;
               
               
               
               
            END IF;

            DBMS_OUTPUT.PUT_LINE ('psError01**' || psError );

            DBMS_OUTPUT.PUT_LINE (
               'OBTUENE DISTINCT FNNUMEMPLEADO INTO usuSolic FROM FACTURACIONMAIN ***');

            --- obtiene el usuario que Agrega
            SELECT DISTINCT FCUSUARIO
              INTO usuSolic
              FROM FACTURAGASTO
             WHERE IDGASTOMAIN = pnSolicitud;

            DBMS_OUTPUT.PUT_LINE (
                  'OBTIENE DISTINCT FNNUMEMPLEADO INTO usuSolic FROM FACTURACIONMAIN ***'
               || usuSolic);

            -- Valido que el concepto sea de pago de servicios
                SELECT COUNT(*) INTO esPagoServicio FROM CTCATALOGOCUENTAS WHERE FCREQPAGSERV = 'S'
                AND IDCONCEPTO = pnConcepto;
                
            -- Valido que el concepto este configurado como PagoDoble
                SELECT COUNT(*) INTO esPagoDoble FROM CTCATALOGOCUENTAS WHERE FCPAGODOBLE = 'S'
                AND IDCONCEPTO = pnConcepto;
                
                
            DBMS_OUTPUT.PUT_LINE ('esPagoServicio ***' || esPagoServicio);

            IF ( (psTipomovto = 2 OR psTipomovto = 3) AND esPagoServicio = 0 AND esPagoDoble > 0 )
            THEN
               DBMS_OUTPUT.PUT_LINE ('ENTROPAGO DOBLE');

               --- obtiene el Id de dynamics del Credito
               BEGIN
                  SELECT FCDYNAMICS
                    INTO idDynamics
                    FROM CTCREDITODYNAMICS
                   WHERE FCCREDITO = psCredito;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     idDynamics := 'NOEXISTE';
               END;

               DBMS_OUTPUT.PUT_LINE (
                     'EL ID DYNAMICS ES..'
                  || idDynamics
                  || ' .. cuenta ...'
                  || psCuentaContable);

               --- Obtiene el numero de Pagos Dobles Encontrados
               ---  TONA LA INFO DE BI  DEL ACCESSS
               SELECT COUNT (1)
                 INTO pnPagoDobleDYN
                 FROM BI_DIMGASTOS@PENDUBI.COM
                WHERE CREDITO_CYBER = psCredito
                  AND CUENTA_CONTABLE = psCuentaContable
                  AND (PROVEEDOR IS NULL OR PROVEEDOR NOT LIKE '%PENDULUM%')
                  AND TO_NUMBER(NVL(NUMERO_CASO,0)) != pnSolicitud
                  AND TO_NUMBER(NVL(NUMERO_CASO,0)) NOT IN ( 
                         SELECT B.IDGASTOMAIN 
                           FROM PENDUPM.FACTURAASIGNACION A 
                     INNER JOIN PENDUPM.FACTURACIONMAIN B ON ( A.IDGASTOMAIN = B.IDGASTOMAIN AND A.IDCONCEPTO = B.IDCONCEPTO) 
                          WHERE     A.IDGASTOMAIN != pnSolicitud AND FCCREDITOCARTERA = psCredito AND FCSTATUS NOT IN ( 'Z','R') 
                                AND FCCUENTACONTABLE = psCuentaContable AND A.STATUS = 'A'
                  );

               DBMS_OUTPUT.PUT_LINE ('EL TOT PGO DBL ES..' || pnPagoDoble);

            ELSE
               idDynamics := NULL;
               pnPagoDoblePM := 0;
            END IF;


            --   COLUMNAS PAGO DOBLE ***   SELECT "Acct", "ProjectID" ,"Id", "Name", "OrigAcct", "RefNbr", "TranDesc", "TranDate", "DrAmt"
            IF (esPagoServicio = 0 AND esPagoDoble > 0)    THEN
                SELECT COUNT (1)
                 INTO pnPagoDoblePM
                 FROM FACTURAASIGNACION
                WHERE IDGASTOMAIN != pnSolicitud
                  AND FCCREDITOCARTERA = psCredito
                  AND STATUS = 'A'
                  AND (IDGASTOMAIN) IN (SELECT IDGASTOMAIN
                                          FROM FACTURACIONBITACORA
                                         WHERE IDGASTOMAIN != pnSolicitud
                                           AND (IDGASTOMAIN,DEL_INDEX) IN (SELECT IDGASTOMAIN,MAX(DEL_INDEX)
                                                               FROM FACTURACIONBITACORA
                                                              WHERE IDGASTOMAIN != pnSolicitud
                                                                AND IDTASKGASTO NOT IN ('974392365525c7af897e890053564163','8433500185372a3c766b298052315707')
                                                           GROUP BY IDGASTOMAIN)
                                        )
                   AND (IDGASTOMAIN,psCuentaContable,IDCONCEPTO) IN (SELECT IDGASTOMAIN,FCCUENTACONTABLE,IDCONCEPTO FROM FACTURACIONMAIN WHERE FCSTATUS != 'Z')
                   AND (IDGASTOMAIN, FNIMPORTE) NOT IN (SELECT IDGASTOMAIN, FNIMPORTE FROM FACTURACIONCOMPROBA WHERE FCTIPOCOMPROBANTE IN ('Ficha de Deposito','Descuento de nomina')  );
            END IF;
            --////// Validamos los pagos dobles de Pago de servicios
            IF (esPagoServicio > 0 AND esPagoDoble > 0) THEN
                 fecha_pago_ini := TO_DATE(psFechaPgoIni,'DD-MM-YYYY');
                 fecha_pago_fin := TO_DATE(psFechaPgoFin,'DD-MM-YYYY');

                 dbms_output.put_line('PD servicios Fecha ini:'||fecha_pago_ini||' And Fecha fin:'||fecha_pago_fin);

                 FOR regSalida IN cuCreditosPagados LOOP
                     IF (fecha_pago_ini <= regSalida.FDFECSERVPAGADODEL AND regSalida.FDFECSERVPAGADODEL <= fecha_pago_fin )
                        OR (fecha_pago_ini <= regSalida.FDFECSERVPAGADOAL AND regSalida.FDFECSERVPAGADOAL <= fecha_pago_fin)
                        THEN
                        pnPagoDoblePM := pnPagoDoblePM + 1;
                        --salida := 'En fechas: '||regSalida.FDFECSERVPAGADODEL||' al '||regSalida.FDFECSERVPAGADOAL||' Hay pago doble';
                        --dbms_output.put_line(salida);
                     EXIT;
                     END IF;
                 END LOOP;

                 FOR regSalida IN cuCreditosPagadosSinFechas LOOP
                        pnPagoDoblePM := pnPagoDoblePM + 1;
                 END LOOP;

             END IF;
            pnPagoDoble := pnPagoDobleDYN + pnPagoDoblePM;

            SELECT COUNT (1)
              INTO existeConc
              FROM FACTURACIONMAIN
             WHERE IDGASTOMAIN = pnSolicitud AND IDCONCEPTO = pnConcepto;

            ----- IF ( existeConc = 0) THEN  psError :='El Concepto '||pnConcepto||' NO Existe en la solicitud '; END IF;
            IF (UPPER (queOperacion) = 'TRAMITE')
            THEN
               pnActimporte :=
                  CASE WHEN esTramFact = 'S' THEN pnImporte ELSE 0 END;
            ELSE
               pnActimporte := pnImporte;
            END IF;

            queColaEs1 := NULL;
            queEstatusEs1 := NULL;

            --***************************************************************
            --*******************
            ---******   REVISA  SI ESTA LIQUIDADO VALIDA SOBRE ESTATUS VALIDOS EL CREDITO *****
            --**********************************************************************************
            IF (psTipomovto = 2 OR psTipomovto = 3)
            THEN                                        /* SI ES UN CREDITO */
               SELECT FCCREDITOSTATUS, FCCREDITOCOLA
                 INTO permiteStatus, permiteCola
                 FROM CTCATALOGOCUENTAS
                WHERE IDCONCEPTO = pnConcepto;

               --- Obtiene el status del Credito
               BEGIN
                   SELECT NVL (U1STATUS, U2STATUS)
                     INTO queEstatusEs
                     FROM RCVRY.DELQMST DM
                          LEFT JOIN RCVRY.UDA1 UD1 ON (DM.DMACCT = UD1.U1ACCT)
                          LEFT JOIN RCVRY.UDA2 UD2 ON (DM.DMACCT = UD2.U2ACCT)
                    WHERE DM.DMACCT = psCredito;
               EXCEPTION WHEN OTHERS THEN
                 queEstatusEs := NULL;
               END;
               --- Obtiene la COLA del credito
               BEGIN
                   SELECT NVL (DMQUE, '')
                     INTO queColaEs
                     FROM RCVRY.DELQMST DM
                    WHERE DM.DMACCT = psCredito;
               EXCEPTION WHEN OTHERS THEN
                 queColaEs := NULL;
               END;
               --- Verifica si el Estatus debe obligarse a que se Autorice
               IF (INSTR (permiteStatus || '|', queEstatusEs || '|') > 0)
               THEN
                  queEstatusEs1 := queEstatusEs;
               ELSE
                  queEstatusEs1 := NULL;
               END IF;

               IF (INSTR (permiteCola || '|', queColaEs || '|') > 0)
               THEN
                  queColaEs1 := queColaEs;
               ELSE
                  queColaEs1 := NULL;
               END IF;
            END IF;

            DBMS_OUTPUT.PUT_LINE (
               'QUE VALOR TRAE LIQUIDADOR  psError ' || esLIQUIDADO);

            --- OBTENEMOS PROJECT MANAGER DEL CREDITO/CARTERA

            IF (suCArtera IS NOT NULL)
            THEN
                SELECT IMPM INTO correoProjMang FROM PENDUPM.CTCARTERA WHERE NMCARTERA LIKE suCArtera;
            END IF;
            DBMS_OUTPUT.PUT_LINE ('correoProjMang**' || correoProjMang||'**suCArtera**'||suCArtera);
            DBMS_OUTPUT.PUT_LINE ('psError02**' || psError );

            IF (psError = '0') THEN
               DBMS_OUTPUT.PUT_LINE (
                  'al grabar es el EL TOT PGO DBL ES..' || pnPagoDoble);

               --  VERIFICA SI EXISTE EN ASIGNACION, SE AJUSTA PARA QUE ACTUALICE
               SELECT COUNT(1) INTO exiteEnAsigna
                 FROM FACTURAASIGNACION
                WHERE IDGASTOMAIN = pnSolicitud AND FCCREDITOCARTERA = psCredito AND IDCONCEPTO = pnConcepto;

               IF (  exiteEnAsigna = 0 OR psTipomovto = 42 OR psTipomovto = 4) THEN

                   /*  2 X CREDITO  2 X CRED MULT  4 X CARTERA  42 IMP GENERAL  */
                   INSERT INTO FACTURAASIGNACION(IDGASTOMAIN,IDCONCEPTO,IDTIPOMOVTO,FCCREDITOCARTERA,FCUSUARIO,FDFECREGISTRO,FCDETALLECAMPOS,
FNIMPORTE,FCCOMENTARIOS,FCQUEUMBRAL,FNUMBRAL,FNUMBRALREBASADO,FNPAGODOBLE,VERETAPACDACHK,VERETAPACDACHKNO,
VERETAPAABIERTA,VERETAPAABIERTANO,FCCODACCEXT,FCCODACCEXTNO,FCCODRESEXT,FCCODRESEXTNO,VERETAPAFIN,
VERETAPAFINVAL,FNIMPORTECOMPROBA,FDFECCOMPROBA,FCCENTROCOSTOS,FCDETALLECREDITO,FCESFACTURABLE,FCDYNAMICS,
FCRESETAFINAL,FCUSUJFEINMED,FCRESULTJFEINMED,FCUSUUMBRAL03,FCUSUUMBRAL04,FCUSUUMBRAL05,FCJUSTIFICACIONUMBRAL,
FCRESUMBRAL03,FCRESUMBRAL04,FCRESUMBRAL05,FCUSUETAPA01,FCUSUETAPA02,FCJUSTIFICAETAPA,FCJUSTIFICACODIGOS,
FCRESETAPA01,FCRESETAPA02,FCUSUPGODBL01,FCUSUPGODBL02,FCJUSTIFICAPAGODBL,FCRESPGODBL01,FCRESPGODBL02,
FDULTFECACTUALIZA,FCUSUEMPRESA,FCJUSTIFICAEMPRESA,FCRESEMPRESA,FCUSUURGENTE,FCJUSTIFICAURGENTE,FCRESURGENTE,
FCUSUEXCGASTO01,FCUSUEXCGASTO02,FCJUSTIFICAEXCGASTO,FCRESEXCGASTO01,FCRESEXCGASTO02,FCUSUETAFINAL01,
FCUSUETAFINAL02,FCJUSTIFICETAFINAL,FCRESETAFINAL01,FCRESETAFINAL02,FCUSULIQUIDADO01,FCUSULIQUIDADO02,
FCJUSTIFICALIQ,FCRESLIQ01,FCRESLIQ02,FCCREDSTATUS,FCCREDCOLA,IDCOMPROBACION,FCUSUPM,FDFECSERVPAGADODEL,
FDFECSERVPAGADOAL,IDPLANVIAJE, FCESREEMBOLSABLE )
                        VALUES (pnSolicitud,
                                pnConcepto,
                                unificaCredito,
                                psCredito,
                                usuSolic,
                                SYSDATE,
                                NULL,
                                pnActimporte,
                                cadenaArma,
                                pnQueUmbral,
                                importeUmbral,
                                queUmbralRebaso,
                                pnPagoDoble,
                                psCatEtaCraVer,
                                queEtapaCRAVER,
                                psCatEtaAbi,
                                queEtapaABTA,
                                psCatCodAcc,
                                queCodAccion,
                                psCatCodRes,
                                queCodResultado,
                                psCatEtaFinal,
                                NULL,
                                0,
                                NULL,
                                vsCentroCostos,
                                cadenaArma,
                                esFacturable,
                                idDynamics,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                queEstatusEs1,
                                queColaEs1,NULL,
                                correoProjMang,
                                TO_DATE(psFechaPgoIni, 'DD/MM/YYYY'),
                                TO_DATE(psFechaPgoFin, 'DD/MM/YYYY'),
                                idplanviaje,
                                esReembolsable
                                );

               ELSE

                   UPDATE FACTURAASIGNACION SET FDFECREGISTRO = SYSDATE,            FNIMPORTE = pnActimporte,
                                                FCCOMENTARIOS =  cadenaArma,        FCQUEUMBRAL =pnQueUmbral,
                                                FNUMBRAL =   importeUmbral ,        FNUMBRALREBASADO = queUmbralRebaso,
                                                FNPAGODOBLE =  pnPagoDoble        , VERETAPACDACHK =psCatEtaCraVer,
                                                VERETAPACDACHKNO = queEtapaCRAVER , VERETAPAABIERTA =psCatEtaAbi,
                                                VERETAPAABIERTANO =   queEtapaABTA, FCCODACCEXT =psCatCodAcc,
                                                FCCODACCEXTNO =  queCodAccion     , FCCODRESEXT =psCatCodRes,
                                                FCCODRESEXTNO =  queCodResultado  , VERETAPAFIN =psCatEtaFinal,
                                                FCCENTROCOSTOS =  vsCentroCostos  , FCDETALLECREDITO =cadenaArma,
                                                FCESFACTURABLE =  esFacturable    , FCDYNAMICS = idDynamics,
                                                FCCREDSTATUS = queEstatusEs1      , FCCREDCOLA = queColaEs1,
                                                IDPLANVIAJE = idplanviaje         , FCESREEMBOLSABLE = esReembolsable
                    WHERE IDGASTOMAIN = pnSolicitud AND FCCREDITOCARTERA = psCredito AND IDCONCEPTO = pnConcepto;


               END IF;

               DBMS_OUTPUT.PUT_LINE ('SE INSERTO EL REGISTRO');
            --------            COMMIT;
            END IF;
         ELSE
            IF (psTipomovto = 2 OR psTipomovto = 3)
            THEN
               psError :=
                     'El Credito '
                  || psCredito
                  || ' ya fue Registrado Previamente';
            ELSIF (psTipomovto = 4)
            THEN
               psError :=
                     'La Cartera'
                  || psCredito
                  || ' ya fue Registrado Previamente';
            ELSIF (psTipomovto = 42)
            THEN
               psError := 'El Importe General ya fue Registrado Previamente';
            ELSIF (psTipomovto = 43)
            THEN
               psError := 'El Monto Facturacion ya fue Registrado Previamente';
            END IF;
         END IF;
      ELSE
         SELECT DISTINCT (SELECT NMDESCRIPCION
                            FROM CTCATALOGOGASTOS
                           WHERE IDCATGASTO = IDTIPOMOVTO)
           INTO cualOtroTipo
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnSolicitud AND IDTIPOMOVTO != unificaCredito;

         psError :=
               'Existe el tipo de Asignacion '
            || cualOtroTipo
            || ' Debe Eliminar antes de Agregar de este nuevo tipo';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ------ROLLBACK;  FACTURACIONMAIN  CTCATALOGOCUENTAS
         psError :=
               '**ERROR CHECA ASIGNACION** --'
            || unificaCredito
            || '-'
            || psCredito
            || '-'
            || pnSolicitud
            || '-'
            || pnConcepto
            || '-'
            || pnImporte
            || '-'
            || psTipomovto
            || '-'
            || psCentroCosto
            || '****'
            || SQLERRM;
         --     psError := '**ERROR** --'||pnSolicitud||'=='||pnConcepto||'=='||psTipomovto||'=='||psCredito||'=='||SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('-1 ' || SQLERRM);
   END validaCreditoAsigna;

   PROCEDURE addCreditoAsigna (pnSolicitud        INTEGER,
                               psCredito          VARCHAR2,
                               pnConcepto         NUMBER,
                               psQueTramite       VARCHAR2,
                               pnImporte          NUMBER,
                               psTipomovto        INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL */
                               quienSolic         INTEGER,
                               queUsuPM           VARCHAR2,
                               psAPPUID           VARCHAR2,
                               psFechaPgoIni      VARCHAR2,
                               psFechaPgoFin      VARCHAR2,
                               psError        OUT VARCHAR2)
   IS
      quePaso       VARCHAR2 (4000) := '';
      quePasoConc   VARCHAR2 (4000) := '';
   BEGIN
      psError := '0';
      PCKFACTURACIONGASTO.addConceptoGasto (pnSolicitud,
                                            pnConcepto,
                                            psQueTramite,
                                            quienSolic,
                                            queUsuPM,
                                            psTipomovto,
                                            psAPPUID,
                                            quePasoConc);
      DBMS_OUTPUT.PUT_LINE ('QUE REGRESO  ' || quePasoConc);

      IF (quePasoConc = '0')
      THEN
         PCKFACTURACIONGASTO.validaCreditoAsigna (pnSolicitud,
                                                  psCredito,
                                                  pnConcepto,
                                                  pnImporte,
                                                  psTipomovto,
                                                  NULL,
                                                  psFechaPgoIni,
                                                  psFechaPgoFin,
                                                  NULL,
                                                  quePaso);

         IF (quePaso != '0')
         THEN
            ROLLBACK;
            psError := quePaso;
         ELSE
            COMMIT;
            psError := '0';
         END IF;
      ELSE
         psError := quePasoConc;
         ROLLBACK;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psError := '**ERROR** ' || SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('-1 ' || SQLERRM);
   END addCreditoAsigna;

   PROCEDURE addCarteraAsigna (pnSolicitud         INTEGER,
                               psCartera           VARCHAR2, /* SI  es psTipomovto = 4 [valor CARTERA]  psTipomovto = 42 [CONCEPTO ]*/
                               pnConcepto          NUMBER,
                               psQueTramite        VARCHAR2,
                               pnImporte           NUMBER,
                               psTipomovto         INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL */
                               quienSolic          INTEGER,
                               queUsuPM            VARCHAR2,
                               psAPPUID            VARCHAR2,
                               psCentroCosto       VARCHAR2,
                               psError         OUT VARCHAR2)
   IS
      quePaso       VARCHAR2 (4000) := '';
      quePasoConc   VARCHAR2 (4000) := '';
   BEGIN
      psError := '0';
      PCKFACTURACIONGASTO.addConceptoGasto (pnSolicitud,
                                            pnConcepto,
                                            psQueTramite,
                                            quienSolic,
                                            queUsuPM,
                                            psTipomovto,
                                            psAPPUID,
                                            quePasoConc);

      IF (quePasoConc = '0')
      THEN
         PCKFACTURACIONGASTO.validaCreditoAsigna (pnSolicitud,
                                                  psCartera,
                                                  pnConcepto,
                                                  pnImporte,
                                                  psTipomovto,
                                                  psCentroCosto,
                                                  NULL,
                                                  NULL,
                                                  NULL,
                                                  quePaso);

         IF (quePaso != '0')
         THEN
            ROLLBACK;
            psError := quePaso;
         ELSE
            COMMIT;
            psError := '0';
         END IF;
      ELSE
         psError := quePasoConc;
         ROLLBACK;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psError := '**ERROR** ' || SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('-1 ' || SQLERRM);
   END addCarteraAsigna;

   PROCEDURE addimporteAsigna (pnSolicitud         INTEGER,
                               pnConcepto          NUMBER,
                               psQueTramite        VARCHAR2,
                               pnImporte           NUMBER,
                               psTipomovto         INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL */
                               quienSolic          INTEGER,
                               queUsuPM            VARCHAR2,
                               psAPPUID            VARCHAR2,
                               psCentroCosto       VARCHAR2,
                               idplanviaje         NUMBER,
                               psError         OUT VARCHAR2)
   IS
      quePaso       VARCHAR2 (4000) := '';
      quePasoConc   VARCHAR2 (4000) := '';
   BEGIN
      psError := '0';
      PCKFACTURACIONGASTO.addConceptoGasto (pnSolicitud,
                                            pnConcepto,
                                            psQueTramite,
                                            quienSolic,
                                            queUsuPM,
                                            psTipomovto,
                                            psAPPUID,
                                            quePasoConc);

      IF (quePasoConc = '0')
      THEN
         PCKFACTURACIONGASTO.validaCreditoAsigna (pnSolicitud,
                                                  'IMPORTE GENERAL',
                                                  pnConcepto,
                                                  pnImporte,
                                                  psTipomovto,
                                                  psCentroCosto,
                                                  NULL,
                                                  NULL,
                                                  idplanviaje,
                                                  quePaso);

         IF (quePaso != '0')
         THEN
            ROLLBACK;
            psError := quePaso;
         ELSE
            COMMIT;
            psError := '0';
         END IF;
      ELSE
         psError := quePasoConc;
         ROLLBACK;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psError := '**ERROR** ' || SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('-1 ' || SQLERRM);
   END addimporteAsigna;

   PROCEDURE addimporteFactura (pnSolicitud         INTEGER,
                                pnConcepto          NUMBER,
                                pnImporte           NUMBER,
                                psQueTramite        VARCHAR2,
                                psTipomovto         INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL [43] X IMP FACTURACION*/
                                quienSolic          INTEGER,
                                queUsuPM            VARCHAR2,
                                psAPPUID            VARCHAR2,
                                psCentroCosto       VARCHAR2,
                                psError         OUT VARCHAR2)
   IS
      quePaso       VARCHAR2 (4000) := '';
      quePasoConc   VARCHAR2 (4000) := '';
   BEGIN
      psError := '0';
      PCKFACTURACIONGASTO.addConceptoGasto (pnSolicitud,
                                            pnConcepto,
                                            psQueTramite,
                                            quienSolic,
                                            queUsuPM,
                                            psTipomovto,
                                            psAPPUID,
                                            quePasoConc);

      IF (quePasoConc = '0')
      THEN
         PCKFACTURACIONGASTO.validaCreditoAsigna (pnSolicitud,
                                                  'IMPORTE FACTURACION',
                                                  pnConcepto,
                                                  pnImporte,
                                                  psTipomovto,
                                                  psCentroCosto,
                                                  NULL,NULL,NULL,
                                                  quePaso);

         IF (quePaso != '0')
         THEN
            ROLLBACK;
            psError := quePaso;
         ELSE
            COMMIT;
            psError := '0';
         END IF;
      ELSE
         psError := quePasoConc;
         ROLLBACK;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psError := '**ERROR** ' || SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('-1 ' || SQLERRM);
   END addimporteFactura;

   PROCEDURE validaMasivaCreditoAsigna (pnSolicitud       INTEGER,
                                        psTipomovto       INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL */
                                        psNmFile          VARCHAR2,
                                        psError       OUT VARCHAR2)
   IS
      vsError        VARCHAR2 (4000) := '0';
      vsQueHay       VARCHAR2 (4000) := '0';
      creaLoder      VARCHAR2 (4000) := '0';
      detSalida      VARCHAR2 (4000) := '';
      nmTabla        VARCHAR2 (40) := '';
      vnconcepto     INTEGER := 0;
      vnCredito      VARCHAR2 (30) := '';
      vnimporte      NUMBER (15, 2) := 0;
      vndescripcion VARCHAR2 (500) :='';

      TYPE cur_typ IS REF CURSOR;

      cuBarre        cur_typ;

      F1             UTL_FILE.FILE_TYPE;
      vexists        BOOLEAN := NULL;
      vfile_length   NUMBER := NULL;
      vblocksize     BINARY_INTEGER := NULL;
   BEGIN
      nmTabla := 'GTO' || pnSolicitud || 'PASO';

      -- BORRA LA TABLA SI EXISTE POR SI SE REPITIESE EL PROCESO
      BEGIN
         EXECUTE IMMEDIATE ('DROP TABLE PENDUPM.' || nmTabla);
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;

      creaLoder :=
            'CREATE TABLE PENDUPM.'
         || nmTabla
         || '
                (
                  CONCEPTO          INTEGER,
                  CREDITO           VARCHAR2(50 BYTE),
                  IMPORTE           NUMBER(15,2),
                  DESCRIPCION       VARCHAR2(500 BYTE)
                )
                ORGANIZATION EXTERNAL
                (
                    TYPE ORACLE_LOADER
                    DEFAULT DIRECTORY GASTOS
                    ACCESS PARAMETERS
                    (
                       RECORDS DELIMITED BY NEWLINE SKIP 1
                       CHARACTERSET "UTF8"
                       fields terminated by "," LRTRIM
                       REJECT ROWS WITH ALL NULL FIELDS
                    )
                    location ('''
         || psNmFile
         || ''')
                ) REJECT LIMIT UNLIMITED';

      --- crea la tabla  externa
      EXECUTE IMMEDIATE (creaLoder);

      detSalida := '';

      OPEN cuBarre FOR 'SELECT CONCEPTO, CREDITO, IMPORTE, DESCRIPCION FROM PENDUPM.' || nmTabla;

      LOOP
         FETCH cuBarre INTO vnconcepto, vnCredito, vnimporte, vndescripcion;

         EXIT WHEN cuBarre%NOTFOUND;
         PCKFACTURACIONGASTO.validaCreditoAsigna (pnSolicitud,
                                                  vnCredito,
                                                  vnconcepto,
                                                  vnimporte,
                                                  psTipomovto,
                                                  NULL,NULL,NULL,NULL,
                                                  detSalida);
            UPDATE PENDUPM.FACTURAASIGNACION
            SET
            FCJUSTIFICACIONUMBRAL = vndescripcion,
            FCJUSTIFICAETAPA = vndescripcion,
            FCJUSTIFICACODIGOS = vndescripcion,
            FCJUSTIFICAPAGODBL = vndescripcion,
            FCJUSTIFICAEMPRESA = vndescripcion,
            FCJUSTIFICAURGENTE = vndescripcion,
            FCJUSTIFICAEXCGASTO = vndescripcion,
            FCJUSTIFICETAFINAL = vndescripcion,
            FCJUSTIFICALIQ = vndescripcion
            WHERE IDGASTOMAIN = pnSolicitud AND FCCREDITOCARTERA = vnCredito;

         IF (detSalida != '0')
         THEN
            EXIT;
         END IF;
      END LOOP;

      CLOSE cuBarre;

      DBMS_OUTPUT.PUT_LINE ('SALIDA DE BARRIDO');
      DBMS_OUTPUT.PUT_LINE ('QUEDO ...' || detSalida);

      --- BORRA LA TABLA DE PASO
      EXECUTE IMMEDIATE ('DROP TABLE PENDUPM.' || nmTabla);

      DBMS_OUTPUT.PUT_LINE ('PASO BORRADO TABLA ' || psNmFile);

      IF (detSalida != '0')
      THEN
         DBMS_OUTPUT.PUT_LINE ('ES ROLLBACK');
         psError := detSalida;
         ROLLBACK;
      ELSE
         DBMS_OUTPUT.PUT_LINE ('ES COMMIT');
         psError := '0';
         COMMIT;
      END IF;
   --- BORRA EL ARCHIVO FISICO
   --       UTL_FILE.FGETATTR('GASTOS',psNmFile,vexists,vfile_length,vblocksize);
   --       IF vexists THEN
   --         UTL_FILE.FREMOVE ('GASTOS',psNmFile);
   --       ELSE
   --         DBMS_OUTPUT.PUT_LINE('NO EXISTE EL ARCHIVO A ELIMINAR');
   --       END IF;

   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psError := '**ERROR** ' || SQLERRM;
         --- BORRA LA TABLA DE PASO
         --     EXECUTE IMMEDIATE ('DROP TABLE PENDUPM.'||nmTabla);
         --- BORRA EL ARCHIVO FISICO
         --     UTL_FILE.FGETATTR('GASTOS',psNmFile,vexists,vfile_length,vblocksize);
         --     IF vexists THEN
         --       UTL_FILE.FREMOVE ('GASTOS',psNmFile);
         --     ELSE
         --       DBMS_OUTPUT.PUT_LINE('NO EXISTE EL ARCHIVO '||'PASO100_18148.log');
         --     END IF;
         DBMS_OUTPUT.PUT_LINE ('-1 ' || SQLERRM);
   END validaMasivaCreditoAsigna;

   PROCEDURE getDetPagodoble (pnSolicitud          INTEGER,
                              pnConcepto           NUMBER,
                              psCredito            VARCHAR2,
                              salida        IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa            T_CURSOR;
      psCadenaCarteras   VARCHAR2 (4000) := '';
      existe             INTEGER := 0;
      idDynamics         VARCHAR2 (30) := '';
      pnPagoDoble        NUMBER (5) := 0;
      psCuentaContable   VARCHAR2 (30) := '';
      psIdDynamics       VARCHAR2 (30) := '';
   BEGIN
      SELECT FCCUENTACONTABLE
        INTO psCuentaContable
        FROM CTCATALOGOCUENTAS
       WHERE IDCONCEPTO = pnConcepto;
       /*
      SELECT FCDYNAMICS
        INTO psIdDynamics
        FROM CTCREDITODYNAMICS
       WHERE FCCREDITO = psCredito; */

         OPEN procesa FOR
                 SELECT 1 IND,
                        'DYNAMICS' ORIGEN,      '0' ProjectID,     ID_GASTO IDHISTORICO,
                        CUENTA_CONTABLE,        CONCEPTO,                   PCKCTRLDOCUMENTAL01.aplFecha (FECHA_DE_PAGO,'2') FECHA_DE_PAGO,
                        PROVEEDOR,              POLIZA,                     FACTURA,
                        PCKCONVENIOS.formatComas(MONTO_TOTAL ) MONTO_TOTAL
                   FROM BI_DIMGASTOS@PENDUBI.COM
                  WHERE CREDITO_CYBER = psCredito
                    AND CUENTA_CONTABLE = psCuentaContable
                    AND (PROVEEDOR IS NULL OR PROVEEDOR NOT LIKE '%PENDULUM%')
                    AND TO_NUMBER(NVL(NUMERO_CASO,0)) != pnSolicitud
                    AND TO_NUMBER(NVL(NUMERO_CASO,0)) NOT IN ( 
                         SELECT B.IDGASTOMAIN 
                           FROM PENDUPM.FACTURAASIGNACION A 
                     INNER JOIN PENDUPM.FACTURACIONMAIN B ON ( A.IDGASTOMAIN = B.IDGASTOMAIN AND A.IDCONCEPTO = B.IDCONCEPTO) 
                          WHERE     A.IDGASTOMAIN != pnSolicitud AND FCCREDITOCARTERA = psCredito AND FCSTATUS NOT IN ( 'Z','R') 
                                AND FCCUENTACONTABLE = psCuentaContable AND A.STATUS = 'A'
                  )
               UNION ALL
                SELECT 2 IND,
                       'PM' ORIGEN,
                       A.FCDYNAMICS ProjectID,
                       A.IDGASTOMAIN IDHISTORICO,
                       FCCUENTACONTABLE CUENTA_CONTABLE,
                       (SELECT NMCONCEPTO
                          FROM CTCATALOGOCUENTAS C
                         WHERE A.IDCONCEPTO = C.IDCONCEPTO)
                          CONCEPTO,
                       PCKCTRLDOCUMENTAL01.aplFecha (B.FDFECREGISTRO, '2') FECHA_DE_PAGO,
                       NVL(B.NMPROVEEDOR,'--SIN PROVEEDOR...') PROVEEDOR,
                       '0' POLIZA, '0' FACTURA,
                       PCKCONVENIOS.formatComas(FNIMPORTE)  MONTO_TOTAL
                  FROM FACTURAASIGNACION A
                       INNER JOIN FACTURACIONMAIN B
                          ON (    A.IDGASTOMAIN = B.IDGASTOMAIN
                              AND A.IDCONCEPTO = B.IDCONCEPTO)
                 WHERE A.IDGASTOMAIN != pnSolicitud
                  AND FCCREDITOCARTERA = psCredito
                       AND B.FCSTATUS != 'Z'
                       AND FCCUENTACONTABLE = psCuentaContable
                  AND (a.IDGASTOMAIN) IN (SELECT IDGASTOMAIN
                                          FROM FACTURACIONBITACORA
                                         WHERE IDGASTOMAIN != pnSolicitud
                                           AND (IDGASTOMAIN,DEL_INDEX) IN (SELECT IDGASTOMAIN,MAX(DEL_INDEX)
                                                                           FROM FACTURACIONBITACORA
                                                                          WHERE IDGASTOMAIN != pnSolicitud
                                                                            AND IDTASKGASTO NOT IN ('974392365525c7af897e890053564163','8433500185372a3c766b298052315707')
                                                                           GROUP BY IDGASTOMAIN
                                                                          )
                                            AND IDTASKGASTO NOT IN ('974392365525c7af897e890053564163','8433500185372a3c766b298052315707')
                                        )
                ORDER BY 1 ASC;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         OPEN procesa FOR SELECT 'ERROR' QUEPASO FROM DUAL;

         salida := procesa;
   END getDetPagodoble;

   --- Regresa el Detalle del Grid de Asignacion para Completar la comprobacion
   PROCEDURE getDetalleParaComproba (pnSolicitud          INTEGER,
                                     salida        IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa            T_CURSOR;
      psCadenaCarteras   VARCHAR2 (4000) := '';
      existe             INTEGER := 0;
      esTramite          INTEGER := 0;
      queSolucion        VARCHAR2 (4000) := '';
   BEGIN
      SELECT COUNT (1)
        INTO esTramite
        FROM FACTURATRAMITE
       WHERE IDGASTOMAIN = pnSolicitud;

      --- actualiza valores de inicio
      IF (esTramite = 0)
      THEN
         UPDATE FACTURAASIGNACION
            SET FNIMPORTECOMPROBA =
                   CASE
                      WHEN FNIMPORTECOMPROBA = 0 THEN 0
                      ELSE FNIMPORTECOMPROBA
                   END,
                FDFECCOMPROBA = SYSDATE
          WHERE IDGASTOMAIN = pnSolicitud;
      ELSE
         SELECT NVL (FCTIPOSOLUCION, 'SIN SOLUCION')
           INTO queSolucion
           FROM FACTURATRAMITE
          WHERE IDGASTOMAIN = pnSolicitud;

         IF (queSolucion = 'INTERNO')
         THEN
            UPDATE FACTURAASIGNACION A
               SET FNIMPORTECOMPROBA =
                      (SELECT FNCOSTOINTERNO
                         FROM CTCATALOGOCUENTAS CT
                        WHERE CT.IDCONCEPTO = A.IDCONCEPTO),
                   FDFECCOMPROBA = SYSDATE
             WHERE IDGASTOMAIN = pnSolicitud;
         ELSE
            UPDATE FACTURAASIGNACION
               SET FNIMPORTECOMPROBA =
                      CASE
                         WHEN FNIMPORTECOMPROBA = 0 THEN FNIMPORTE
                         ELSE FNIMPORTECOMPROBA
                      END,
                   FDFECCOMPROBA = SYSDATE
             WHERE IDGASTOMAIN = pnSolicitud;
         END IF;
      END IF;

      OPEN procesa FOR
           SELECT IDGASTOMAIN IDSOLICITUD,
                     '--> '
                  || (SELECT NMDESCRIP
                        FROM CTCUENTACATEGORIA C
                       WHERE C.IDCUENTACAT =
                                (SELECT IDCATEGORIA
                                   FROM CTCATALOGOCUENTAS H
                                  WHERE A.IDCONCEPTO = H.IDCONCEPTO))
                  || '<BR/>'
                  || '--> '
                  || (SELECT NMDESCRIP
                        FROM CTCUENTACATEGORIA C
                       WHERE C.IDCUENTACAT =
                                (SELECT IDSUBCATEGORIA
                                   FROM CTCATALOGOCUENTAS H
                                  WHERE A.IDCONCEPTO = H.IDCONCEPTO))
                   || '<BR/>'
                   || '--> '
                   || (SELECT NMCONCEPTO
                     FROM CTCATALOGOCUENTAS C
                    WHERE A.IDCONCEPTO = C.IDCONCEPTO)
                     CATEGSUB,
                   IDCONCEPTO NMCONCEPTO,
                  IDTIPOMOVTO,
                  A.IDCONCEPTO IDCONCEPTO,
                  FCCREDITOCARTERA VALOR,
                  CASE
                     WHEN FCRESETAFINAL IS NULL THEN 'CORRECTO'
                     ELSE '<FONT COLOR="RED">' || FCRESETAFINAL || '<FONT>'
                  END
                     VERIFFINAL,
                  FNIMPORTE IMPORTESOLIC,
                  FNIMPORTECOMPROBA IMPORTEREAL,
                  '$' || PCKCONVENIOS.formatComas (FNIMPORTE) IMPORTECOMAS,
                  FCCENTROCOSTOS CENTROCOSTOS,
                  SUBSTR (FCDETALLECREDITO,
                          1,
                          INSTR (FCDETALLECREDITO, '|') - 1)
                     CREDITO,
                  SUBSTR (FCDETALLECREDITO,
                            INSTR (FCDETALLECREDITO,
                                   '|',
                                   1,
                                   1)
                          + 1,
                            INSTR (FCDETALLECREDITO,
                                   '|',
                                   1,
                                   2)
                          - INSTR (FCDETALLECREDITO,
                                   '|',
                                   1,
                                   1)
                          - 1)
                     DEUDOR,IDCOMPROBACION, TO_CHAR(FDFECREGISTRO, 'DDMMYYYYHH24MISS') FECHAREGISTRO,
                     TO_CHAR(FDFECREALPAGO, 'DD/MM/YYYY') FDFECREALPAGO, FCREMESA,TO_CHAR(FDFECSERVPAGADODEL, 'DD/MM/YYYY') FDFECSERVPAGADODEL, TO_CHAR(FDFECSERVPAGADOAL, 'DD/MM/YYYY') FDFECSERVPAGADOAL,FCPAGADOPREVIAMENTE,TO_CHAR(FDFECCUMBREPAGO, 'DD/MM/YYYY') FDFECCUMBREPAGO,FCCOMENTARIOPAGOSERV,
                     ( SELECT COUNT(1) 
                         FROM PENDUPM.FACTURACIONCOMPROBA 
                        WHERE     IDGASTOMAIN = pnSolicitud AND IDCOMPROBACION = A.IDCOMPROBACION
                              AND (FCTIPOCOMPROBANTE != 'Ficha de Deposito' AND FCTIPOCOMPROBANTE != 'Descuento de nomina') 
                              AND ( (FCARCHIVOXML IS NOT NULL AND FCVALXML = 'S')
                                 OR (FCARCHIVOPDF IS NOT NULL AND FCVALPDF = 'S')
                                 OR (FCARCHIVOPDFC IS NOT NULL AND FCVALPDFC = 'S') ) ) VALIDA
             FROM FACTURAASIGNACION A
            WHERE IDGASTOMAIN = pnSolicitud
            AND STATUS = 'A'
         ORDER BY 1, 2, FDFECREGISTRO DESC;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getDetalleParaComproba;

   PROCEDURE setAsignacomprobacion (
      arrDetalle       PCKFACTURACIONGASTO.TABASIGNACOMP,
      psError      OUT VARCHAR2)
   IS
      quePaso           VARCHAR2 (4000) := '';
      queOperacion      VARCHAR2 (4000) := '';
      pnBarre           INTEGER := 1;
      vdEmailPgo        VARCHAR2 (400) := '';
      queUmbralRebaso   NUMBER (12, 2) := 0;
      importeUmbral     NUMBER (12, 2) := 0;
      pnQueUmbral       NUMBER (12) := 0;

      CURSOR cuConcepto (cualEs INTEGER)
      IS
         SELECT *
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = cualEs;
   BEGIN
      psError := '0';

      FOR regPaso IN pnBarre .. arrDetalle.COUNT
      LOOP
         SELECT DISTINCT UPPER (TPOMOVIMIENTO)
           INTO queOperacion
           FROM FACTURACIONMAIN
          WHERE IDGASTOMAIN = arrDetalle (regPaso).rIdGasto;

         ---- **** Arma Detalle de ls Auutorizaciones de Umbrales por TRAMITE ****
         FOR regConcepto IN cuConcepto (arrDetalle (regPaso).rConcepto)
         LOOP
            --****** Verifica umbral de importe ********
            IF (   (    regConcepto.VERMONTO01 IS NOT NULL
                    AND regConcepto.VERMONTO01 > 0)
                OR (    regConcepto.VERMONTO02 IS NOT NULL
                    AND regConcepto.VERMONTO02 > 0)
                OR (    regConcepto.VERMONTO03 IS NOT NULL
                    AND regConcepto.VERMONTO03 > 0))
            THEN
               -- Revisa contra primer monto
               IF (arrDetalle (regPaso).rImporteCom <= regConcepto.VERMONTO01)
               THEN
                  queUmbralRebaso := 0;
                  importeUmbral := regConcepto.VERMONTO01;
                  pnQueUmbral := 0;
               -- Revisa contra segundo monto
               ELSIF (    arrDetalle (regPaso).rImporteCom >
                             regConcepto.VERMONTO01
                      AND arrDetalle (regPaso).rImporteCom <=
                             regConcepto.VERMONTO02)
               THEN
                  queUmbralRebaso := arrDetalle (regPaso).rImporteCom;
                  importeUmbral := regConcepto.VERMONTO01;
                  pnQueUmbral := 1;
               -- Revisa contra tercer monto
               ELSIF (    arrDetalle (regPaso).rImporteCom >
                             regConcepto.VERMONTO02
                      AND arrDetalle (regPaso).rImporteCom <=
                             regConcepto.VERMONTO03)
               THEN
                  queUmbralRebaso := arrDetalle (regPaso).rImporteCom;
                  importeUmbral := regConcepto.VERMONTO02;
                  pnQueUmbral := 2;
               --- si rebasa el Tercer Monto
               ELSIF (arrDetalle (regPaso).rImporteCom >
                         regConcepto.VERMONTO03)
               THEN
                  queUmbralRebaso := arrDetalle (regPaso).rImporteCom;
                  importeUmbral := regConcepto.VERMONTO03;
                  pnQueUmbral := 3;
               END IF;
            ELSE
               queUmbralRebaso := 0;
               importeUmbral := 0;
               pnQueUmbral := 0;
            END IF;
         END LOOP;

         --- Actualiza elDetalle de FActura Asignacion del Credito etc
         DBMS_OUTPUT.PUT_LINE ('DATOS A ACTUALIZAR' || arrDetalle (regPaso).rIdGasto || '-'|| arrDetalle (regPaso).rConcepto || '-'|| arrDetalle (regPaso).rCredito || '-' || '-'|| arrDetalle (regPaso).rFechaComproba);
         UPDATE FACTURAASIGNACION
            SET FNIMPORTECOMPROBA = arrDetalle (regPaso).rImporteCom,
                IDCOMPROBACION = arrDetalle (regPaso).rComprobanteId,
                FNIMPORTE =
                   CASE
                      WHEN queOperacion = 'TRAMITE'
                      THEN
                         arrDetalle (regPaso).rImporteCom
                      ELSE
                         FNIMPORTE
                   END,
                FDFECCOMPROBA = SYSDATE,
                FCQUEUMBRAL =
                   CASE
                      WHEN queOperacion = 'TRAMITE' THEN pnQueUmbral
                      ELSE FCQUEUMBRAL
                   END,
                FNUMBRAL =
                   CASE
                      WHEN queOperacion = 'TRAMITE' THEN importeUmbral
                      ELSE FNUMBRAL
                   END,
                FNUMBRALREBASADO =
                   CASE
                      WHEN queOperacion = 'TRAMITE' THEN queUmbralRebaso
                      ELSE FNUMBRALREBASADO
                   END
          WHERE     IDGASTOMAIN = arrDetalle (regPaso).rIdGasto
                AND IDCONCEPTO = arrDetalle (regPaso).rConcepto
                AND FCCREDITOCARTERA = arrDetalle (regPaso).rCredito
                AND TO_CHAR(FDFECREGISTRO, 'DDMMYYYYHH24MISS') = arrDetalle (regPaso).rFechaComproba;
      END LOOP;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         quePaso := SQLERRM;
         psError := '*ERROR* ' || quePaso;
   END setAsignacomprobacion;

   FUNCTION siExisteArchivo (psFileName VARCHAR2)
      RETURN VARCHAR2
   IS
      F1             UTL_FILE.FILE_TYPE;
      vexists        BOOLEAN := NULL;
      vfile_length   NUMBER := NULL;
      vblocksize     BINARY_INTEGER := NULL;
      psNmFile       VARCHAR2 (4000) := psFileName;
   BEGIN
      --- VERIFICA QUE EXISTA ELARCHIVO FISICAMENTE
      UTL_FILE.FGETATTR ('GASTOS',
                         psNmFile,
                         vexists,
                         vfile_length,
                         vblocksize);

      IF vexists
      THEN
         RETURN 'S';
      ELSE
         RETURN 'N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN '*ERROR*' || SQLERRM;
   END siExisteArchivo;


   -- Regresa si la etapa esta Verificada y Cerrada  [CORRECTO] [*ERROR* Descripcion]
   FUNCTION etaCerradaFin (psCredito VARCHAR2, pnConcepto NUMBER)
      RETURN VARCHAR2
   IS
      queTipoJuicio    NUMBER (5) := '';
      queTipoDemanda   NUMBER (5) := '';
      ubica            INTEGER := 0;
      vnBarre          INTEGER := 0;
      cadena1          VARCHAR2 (4000) := '';
      valor            VARCHAR2 (4000) := '';
      contador         INTEGER := 0;
      salida           VARCHAR2 (4000) := '';
      queEtapaCRAVER   VARCHAR2 (4000) := '';
      hayJuicios       INTEGER := 0;

      CURSOR cuConcepto
      IS
         SELECT *
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = pnConcepto;

      CURSOR cuJuicios (tpoDem NUMBER)
      IS
         SELECT CCCASENO, CCCASENO CCCASENODESC
           FROM RCVRY.CASEACCT
          WHERE     CCACCT = psCredito
                AND CCCASENO IN (SELECT CECASENO
                                   FROM RCVRY.CASE
                                  WHERE CESTATUS = 'A')
                AND CCCASENO IN (SELECT NUMERO
                                   FROM OPERACION.ELP_JUICIO
                                  WHERE ID_TIPO_DEMANDA = tpoDem);

      CURSOR cuEtapaCrraVerif (
         psjuicio    INTEGER,
         psEtapa     VARCHAR2)
      IS
           SELECT *
             FROM OPERACION.VW_ELP_ETAPAS_LEGALES
            WHERE     NUMERO_JUICIO = psjuicio
                  AND EN_PROCESO = 0
                  AND FECHA_TERMINO IS NOT NULL
                  AND RESULTADO_VERIFICACION = 'CORRECTO'
                  AND NUMERO_ETAPA = psEtapa
                  AND ORDEN =
                         (SELECT MAX (ORDEN)
                            FROM OPERACION.VW_ELP_ETAPAS_LEGALES
                           WHERE     NUMERO_JUICIO = psjuicio
                                 AND EN_PROCESO = 0
                                 AND FECHA_TERMINO IS NOT NULL
                                 AND NUMERO_ETAPA = psEtapa)
         ORDER BY ORDEN DESC;
   BEGIN
      ---  Carga informacion del Concepto con que se va a Validar
      FOR regConcepto IN cuConcepto
      LOOP
         --****** Verifica Etapas Procesales / JUICIOS ACTIVOS ********
         IF ( (regConcepto.VERETAPACDACHKFIN IS NOT NULL))
         THEN
            queEtapaCRAVER := '';

            SELECT COUNT (1)
              INTO hayJuicios
              FROM RCVRY.CASEACCT
             WHERE     CCACCT = psCredito
                   AND CCCASENO IN (SELECT CECASENO
                                      FROM RCVRY.CASE
                                     WHERE CESTATUS = 'A')
                   AND CCCASENO IN (SELECT NUMERO
                                      FROM OPERACION.ELP_JUICIO
                                     WHERE ID_TIPO_DEMANDA = 2);

            IF (hayJuicios = 0)
            THEN
               queEtapaCRAVER :=
                     queEtapaCRAVER
                  || 'EL CREDITO '
                  || psCredito
                  || ' NO TIENE JUICIOS ACTIVOS<BR/>';
            END IF;

            FOR regjuicios IN cuJuicios (2)
            LOOP
               /*  IDTIPODEMANDA = 1  EN CONTRA   /  IDTIPODEMANDA = 2  DEMANDA NUESTRA */
               /*  OPERACION.ELP_JUICIO campo  ID_TIPO_DEMANDA del catalogo OPERACION.CAT_TIPO_DEMANDA */
               --- Obtiene el Tipo de Demanda del Juicio
               --- Obtiene Valores para juicio
               SELECT ID_TIPO_DEMANDA, ID_TIPO_JUICIO
                 INTO queTipoJuicio, queTipoDemanda
                 FROM OPERACION.ELP_JUICIO
                WHERE NUMERO = regjuicios.CCCASENO;

               ---  Barre para Validar las ETAPAS CERADAS Y VERIFICADAS del JUICIO
               queEtapaCRAVER := '';

               IF ( (regConcepto.VERETAPACDACHKFIN IS NOT NULL))
               THEN
                  cadena1 := regConcepto.VERETAPACDACHKFIN || '|';
                  ubica := INSTR (cadena1, '|');

                  WHILE (ubica > 0)
                  LOOP
                     valor := SUBSTR (cadena1, 1, ubica - 1);
                     contador := 0;

                     FOR regEtapa
                        IN cuEtapaCrraVerif (regjuicios.CCCASENO, valor)
                     LOOP
                        contador := contador + 1;

                        IF (regEtapa.RESULTADO_VERIFICACION != 'CORRECTO')
                        THEN
                           queEtapaCRAVER :=
                                 queEtapaCRAVER
                              || 'LA ETAPA ['
                              || valor
                              || '] CALIFICADA '
                              || regEtapa.RESULTADO_VERIFICACION
                              || '<BR/>';
                        END IF;
                     END LOOP;

                     IF (contador = 0)
                     THEN
                        queEtapaCRAVER :=
                              queEtapaCRAVER
                           || 'LA ETAPA ['
                           || valor
                           || '] NO CUMPLE'
                           || '<BR/>';
                     END IF;

                     cadena1 := SUBSTR (cadena1, ubica + 1);
                     ubica := INSTR (cadena1, '|');
                  END LOOP;
               END IF;
            END LOOP;                                              --- JUICIOS
         END IF;
      END LOOP;                                                   --- CONCEPTO

      RETURN queEtapaCRAVER;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN '*ERROR*';
   END etaCerradaFin;

   --- Actualiza Valor de la etapa final si  se Aplico
   PROCEDURE setVerifEtaCerradaFin (pnSolicitud        INTEGER,
                                    psCadenaEjecuta    VARCHAR2)
   IS
      queelemento   INTEGER := 0;
      vsError       VARCHAR2 (4000) := '';
      psErrorD      VARCHAR2 (4000) := '';

      CURSOR cuCreditos
      IS
         SELECT F.FCCREDITOCARTERA,
                F.IDCONCEPTO,
                PCKFACTURACIONGASTO.etaCerradaFin (F.FCCREDITOCARTERA,
                                                   F.IDCONCEPTO)
                   RESULTADO,
                (SELECT VERETAPACDACHKFIN
                   FROM CTCATALOGOCUENTAS H
                  WHERE H.IDCONCEPTO = F.IDCONCEPTO)
                   QUEVALORES
           FROM FACTURAASIGNACION F
          WHERE F.IDGASTOMAIN = pnSolicitud AND F.IDTIPOMOVTO IN (2, 3);
   BEGIN
      FOR regCredito IN cuCreditos
      LOOP
         UPDATE FACTURAASIGNACION
            SET VERETAPAFIN = regCredito.QUEVALORES,
                VERETAPAFINVAL = regCredito.RESULTADO
          WHERE     IDGASTOMAIN = pnSolicitud
                AND IDCONCEPTO = regCredito.IDCONCEPTO
                AND FCCREDITOCARTERA = regCredito.FCCREDITOCARTERA;
      END LOOP;

      SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

      -----INSERTA BITACORA DE VALIDACION DE PROCESO
      INSERT INTO BITACORATRANSACCION
           VALUES (pnSolicitud,
                   queelemento,
                   psCadenaEjecuta,
                   SYSDATE,
                   SYSDATE,
                   '0');

      COMMIT;
      DBMS_OUTPUT.PUT_LINE ('E X I T O S O');
   EXCEPTION
      WHEN OTHERS
      THEN
         vsError := SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('** ERROR ** ' || SQLERRM);
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

         INSERT INTO BITACORATRANSACCION
              VALUES (pnSolicitud,
                      queelemento,
                      psCadenaEjecuta,
                      SYSDATE,
                      SYSDATE,
                      psErrorD);

         COMMIT;
   END setVerifEtaCerradaFin;

   --- Elimna el Registro del Valor dela Asignacion
   PROCEDURE delAsignacionsolicitud (pnSolicitud       INTEGER,
                                     pnConcepto        INTEGER,
                                     psCredito         VARCHAR2,
                                     psError       OUT VARCHAR2)
   IS
      yaNoHay    INTEGER := 0;
      psErrorD   VARCHAR2 (4000) := '';
   BEGIN
      psError := '0';

      DELETE FACTURADCINICIO
       WHERE IDGASTOMAIN = pnSolicitud
             AND IDCONCEPTO = pnConcepto
             AND FCCREDITO = psCredito;

      INSERT INTO ASIGNACIONCOMENTAHIST
      SELECT A.*, SYSDATE
        FROM ASIGNACIONCOMENTA A
       WHERE IDGASTOMAIN = pnSolicitud
             AND IDCONCEPTO = pnConcepto
             AND FCCREDITOCARTERA = psCredito;

      DELETE ASIGNACIONCOMENTA
       WHERE IDGASTOMAIN = pnSolicitud
             AND IDCONCEPTO = pnConcepto
             AND FCCREDITOCARTERA = psCredito;

      DELETE FACTURADCSOPORTE
       WHERE IDGASTOMAIN = pnSolicitud
             AND IDCONCEPTO = pnConcepto
             AND FCCREDITO = psCredito;

      DELETE FACTURAASIGNACION
       WHERE IDGASTOMAIN = pnSolicitud
             AND IDCONCEPTO = pnConcepto
             AND FCCREDITOCARTERA = psCredito;

      SELECT COUNT (1)
        INTO yaNoHay
        FROM FACTURAASIGNACION
       WHERE IDGASTOMAIN = pnSolicitud AND IDCONCEPTO = pnConcepto;

      IF (yaNoHay = 0)
      THEN
         --          DELETE FACTURACIONDETALLE  WHERE IDGASTOMAIN = pnSolicitud AND IDCONCEPTO = pnConcepto;
         DELETE FACTURACIONCOTIZA
          WHERE IDGASTOMAIN = pnSolicitud AND IDCONCEPTO = pnConcepto;

         DELETE FACTURADCINICIO
          WHERE IDGASTOMAIN = pnSolicitud AND IDCONCEPTO = pnConcepto;

         DELETE FACTURADCSOPORTE
          WHERE IDGASTOMAIN = pnSolicitud AND IDCONCEPTO = pnConcepto;

         DELETE FACTURACIONMAIN
          WHERE IDGASTOMAIN = pnSolicitud AND IDCONCEPTO = pnConcepto;
      END IF;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);
         psError := '*ERROR* ' || psErrorD;
   END delAsignacionsolicitud;

   FUNCTION getDetArchivosini (queConcepto INTEGER)
      RETURN VARCHAR2
   IS
      queRegresa     VARCHAR2 (4000) := '';
      vsDocumentos   VARCHAR2 (4000) := '';
      str            string_fnc.t_array;
   BEGIN
      SELECT FCARCHINIREQ
        INTO vsDocumentos
        FROM CTCATALOGOCUENTAS
       WHERE IDCONCEPTO = queConcepto;

      DBMS_OUTPUT.put_line (vsDocumentos);
      str := string_fnc.split (vsDocumentos, '|');

      FOR i IN 1 .. str.COUNT
      LOOP
         queRegresa :=
               queRegresa
            || SUBSTR (str (i), 1, LENGTH (str (i)) - 1)
            || '<BR/>';
      END LOOP;

      RETURN queRegresa;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN '*ERROR*';
   END GETDETARCHIVOSINI;

   PROCEDURE getDetalleDocIni (pnSolicitud INTEGER, salida IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa            T_CURSOR;
      psCadenaCarteras   VARCHAR2 (4000) := '';
      existe             INTEGER := 0;
   BEGIN
      OPEN procesa FOR
           SELECT CATEGSUB,
                  NMCONCEPTO,
                  IDCONCEPTO,
                  VALOR,
                  CENTROCOSTOS,
                  CREDITO,
                  DEUDOR,
                  NMARCHIVOSINI,
                  MAX (CONSECUTIVO) CONSEC
             FROM (  SELECT    'Categ --> '
                            || (SELECT NMDESCRIP
                                  FROM CTCUENTACATEGORIA C
                                 WHERE C.IDCUENTACAT =
                                          (SELECT IDCATEGORIA
                                             FROM CTCATALOGOCUENTAS H
                                            WHERE A.IDCONCEPTO = H.IDCONCEPTO))
                            || '<BR/>'
                            || 'Subcateg --> '
                            || (SELECT NMDESCRIP
                                  FROM CTCUENTACATEGORIA C
                                 WHERE C.IDCUENTACAT =
                                          (SELECT IDSUBCATEGORIA
                                             FROM CTCATALOGOCUENTAS H
                                            WHERE A.IDCONCEPTO = H.IDCONCEPTO))
                               CATEGSUB,
                            (SELECT NMCONCEPTO
                               FROM CTCATALOGOCUENTAS C
                              WHERE A.IDCONCEPTO = C.IDCONCEPTO)
                               NMCONCEPTO,
                            A.IDCONCEPTO IDCONCEPTO,
                            FCCREDITOCARTERA VALOR,
                            B.IDCONSEC CONSECUTIVO,
                            FCCENTROCOSTOS CENTROCOSTOS,
                            CASE
                               WHEN IDTIPOMOVTO IN (2, 3)
                               THEN
                                  SUBSTR (FCDETALLECREDITO,
                                          1,
                                          INSTR (FCDETALLECREDITO, '|') - 1)
                               WHEN IDTIPOMOVTO = 4
                               THEN
                                  FCCREDITOCARTERA
                               ELSE
                                  FCCREDITOCARTERA
                            END
                               CREDITO,
                            CASE
                               WHEN IDTIPOMOVTO IN (2, 3)
                               THEN
                                  SUBSTR (FCDETALLECREDITO,
                                            INSTR (FCDETALLECREDITO,
                                                   '|',
                                                   1,
                                                   1)
                                          + 1,
                                            INSTR (FCDETALLECREDITO,
                                                   '|',
                                                   1,
                                                   2)
                                          - INSTR (FCDETALLECREDITO,
                                                   '|',
                                                   1,
                                                   1)
                                          - 1)
                               WHEN IDTIPOMOVTO = 4
                               THEN
                                  (SELECT NMDESCRIPCION
                                     FROM CTCARTERA V
                                    WHERE V.IDCARTERA = A.FCCREDITOCARTERA)
                               ELSE
                                  'SOLICITANTE'
                            END
                               DEUDOR,
                            PCKFACTURACIONGASTO.getValorArchIniSop (B.IDCONSEC,
                                                                    'INI')
                               NMARCHIVOSINI,
                            FCTIPOALTA
                       FROM FACTURAASIGNACION A
                            INNER JOIN FACTURADCINICIO B
                               ON (    A.IDGASTOMAIN = B.IDGASTOMAIN
                                   AND A.IDCONCEPTO = B.IDCONCEPTO
                                   AND A.FCCREDITOCARTERA = B.FCCREDITO)
                      WHERE A.IDGASTOMAIN = pnSolicitud
                   ORDER BY 1, 2, A.FDFECREGISTRO DESC)
         GROUP BY CATEGSUB,
                  NMCONCEPTO,
                  IDCONCEPTO,
                  VALOR,
                  CENTROCOSTOS,
                  CREDITO,
                  DEUDOR,
                  NMARCHIVOSINI
         ORDER BY CATEGSUB, NMCONCEPTO, CREDITO;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getDetalleDocIni;

   PROCEDURE getDetDocIniArchS (pnSolicitud          INTEGER,
                                pnConcepto           INTEGER,
                                psNmArchivo          VARCHAR2,
                                salida        IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa            T_CURSOR;
      psCadenaCarteras   VARCHAR2 (4000) := '';
      existe             INTEGER := 0;
   BEGIN
      OPEN procesa FOR
           SELECT    SUBSTR (FCDETALLECREDITO,
                             1,
                             INSTR (FCDETALLECREDITO, '|') - 1)
                  || '-'
                  || CASE
                        WHEN IDTIPOMOVTO IN (2, 3)
                        THEN
                           SUBSTR (FCDETALLECREDITO,
                                   1,
                                   INSTR (FCDETALLECREDITO, '|') - 1)
                        WHEN IDTIPOMOVTO = 4
                        THEN
                           FCCREDITOCARTERA
                        ELSE
                           FCCREDITOCARTERA
                     END
                     CREDITO,
                  B.IDCONSEC CONSECUTIVO
             FROM FACTURAASIGNACION A
                  INNER JOIN FACTURADCINICIO B
                     ON (    A.IDGASTOMAIN = B.IDGASTOMAIN
                         AND A.IDCONCEPTO = B.IDCONCEPTO
                         AND A.FCCREDITOCARTERA = B.FCCREDITO)
            WHERE     A.IDGASTOMAIN = pnSolicitud
                  AND A.IDCONCEPTO = pnConcepto
                  AND FCNOMBRE = psNmArchivo
         ORDER BY 1, 2, A.FDFECREGISTRO DESC;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getDetDocIniArchS;

   FUNCTION getDetArchivosSoporte (queConcepto INTEGER)
      RETURN VARCHAR2
   IS
      queRegresa     VARCHAR2 (4000) := '';
      vsDocumentos   VARCHAR2 (4000) := '';
      str            string_fnc.t_array;
   BEGIN
      SELECT FCDOCUMENTOSOPORTE
        INTO vsDocumentos
        FROM CTCATALOGOCUENTAS
       WHERE IDCONCEPTO = queConcepto;

      DBMS_OUTPUT.put_line (vsDocumentos);
      str := string_fnc.split (vsDocumentos, '|');

      FOR i IN 1 .. str.COUNT
      LOOP
         queRegresa :=
               queRegresa
            || SUBSTR (str (i), 1, LENGTH (str (i)) - 1)
            || '<BR/>';
      END LOOP;

      RETURN queRegresa;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN '*ERROR*';
   END getDetArchivosSoporte;

   PROCEDURE getDetalleDocSoporte (pnSolicitud          INTEGER,
                                   salida        IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa            T_CURSOR;
      psCadenaCarteras   VARCHAR2 (4000) := '';
      existe             INTEGER := 0;
   BEGIN
      OPEN procesa FOR
           SELECT CATEGSUB,
                  NMCONCEPTO,
                  IDCONCEPTO,
                  VALOR,
                  CENTROCOSTOS,
                  CREDITO,
                  DEUDOR,
                  NMARCHIVOSINI,
                  MAX (CONSECUTIVO) CONSEC
             FROM (  SELECT    'Categ --> '
                            || (SELECT NMDESCRIP
                                  FROM CTCUENTACATEGORIA C
                                 WHERE C.IDCUENTACAT =
                                          (SELECT IDCATEGORIA
                                             FROM CTCATALOGOCUENTAS H
                                            WHERE A.IDCONCEPTO = H.IDCONCEPTO))
                            || '<BR/>'
                            || 'Subcateg --> '
                            || (SELECT NMDESCRIP
                                  FROM CTCUENTACATEGORIA C
                                 WHERE C.IDCUENTACAT =
                                          (SELECT IDSUBCATEGORIA
                                             FROM CTCATALOGOCUENTAS H
                                            WHERE A.IDCONCEPTO = H.IDCONCEPTO))
                               CATEGSUB,
                            (SELECT NMCONCEPTO
                               FROM CTCATALOGOCUENTAS C
                              WHERE A.IDCONCEPTO = C.IDCONCEPTO)
                               NMCONCEPTO,
                            A.IDCONCEPTO IDCONCEPTO,
                            FCCREDITOCARTERA VALOR,
                            B.IDCONSEC CONSECUTIVO,
                            FCCENTROCOSTOS CENTROCOSTOS,
                            CASE
                               WHEN IDTIPOMOVTO IN (2, 3)
                               THEN
                                  SUBSTR (FCDETALLECREDITO,
                                          1,
                                          INSTR (FCDETALLECREDITO, '|') - 1)
                               WHEN IDTIPOMOVTO = 4
                               THEN
                                  FCCREDITOCARTERA
                               ELSE
                                  FCCREDITOCARTERA
                            END
                               CREDITO,
                            CASE
                               WHEN IDTIPOMOVTO IN (2, 3)
                               THEN
                                  SUBSTR (FCDETALLECREDITO,
                                            INSTR (FCDETALLECREDITO,
                                                   '|',
                                                   1,
                                                   1)
                                          + 1,
                                            INSTR (FCDETALLECREDITO,
                                                   '|',
                                                   1,
                                                   2)
                                          - INSTR (FCDETALLECREDITO,
                                                   '|',
                                                   1,
                                                   1)
                                          - 1)
                               WHEN IDTIPOMOVTO = 4
                               THEN
                                  (SELECT NMDESCRIPCION
                                     FROM CTCARTERA V
                                    WHERE V.IDCARTERA = A.FCCREDITOCARTERA)
                               ELSE
                                  'SOLICITANTE'
                            END
                               DEUDOR,
                            PCKFACTURACIONGASTO.getValorArchIniSop (B.IDCONSEC,
                                                                    'SOP')
                               NMARCHIVOSINI
                       FROM FACTURAASIGNACION A
                            INNER JOIN FACTURADCSOPORTE B
                               ON (    A.IDGASTOMAIN = B.IDGASTOMAIN
                                   AND A.IDCONCEPTO = B.IDCONCEPTO
                                   AND A.FCCREDITOCARTERA = B.FCCREDITO)
                      WHERE A.IDGASTOMAIN = pnSolicitud
                   ORDER BY 1, 2, A.FDFECREGISTRO DESC)
         GROUP BY CATEGSUB,
                  NMCONCEPTO,
                  IDCONCEPTO,
                  VALOR,
                  CENTROCOSTOS,
                  CREDITO,
                  DEUDOR,
                  NMARCHIVOSINI
         ORDER BY CATEGSUB, NMCONCEPTO, CREDITO;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getDetalleDocSoporte;

   PROCEDURE getDetDocSopArchS (pnSolicitud          INTEGER,
                                pnConcepto           INTEGER,
                                psNmArchivo          VARCHAR2,
                                salida        IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa            T_CURSOR;
      psCadenaCarteras   VARCHAR2 (4000) := '';
      existe             INTEGER := 0;
   BEGIN
      OPEN procesa FOR
           SELECT CASE
                     WHEN IDTIPOMOVTO IN (2, 3)
                     THEN
                           SUBSTR (FCDETALLECREDITO,
                                   1,
                                   INSTR (FCDETALLECREDITO, '|') - 1)
                        || ' - '
                        || SUBSTR (FCDETALLECREDITO,
                                     INSTR (FCDETALLECREDITO,
                                            '|',
                                            1,
                                            1)
                                   + 1,
                                     INSTR (FCDETALLECREDITO,
                                            '|',
                                            1,
                                            2)
                                   - INSTR (FCDETALLECREDITO,
                                            '|',
                                            1,
                                            1)
                                   - 1)
                     WHEN IDTIPOMOVTO = 4
                     THEN
                           FCCREDITOCARTERA
                        || ' - '
                        || (SELECT NMDESCRIPCION
                              FROM CTCARTERA V
                             WHERE V.IDCARTERA = A.FCCREDITOCARTERA)
                     ELSE
                        FCCREDITOCARTERA
                  END
                     CREDITO,
                  B.IDCONSEC CONSECUTIVO
             FROM FACTURAASIGNACION A
                  INNER JOIN FACTURADCSOPORTE B
                     ON (    A.IDGASTOMAIN = B.IDGASTOMAIN
                         AND A.IDCONCEPTO = B.IDCONCEPTO
                         AND A.FCCREDITOCARTERA = B.FCCREDITO)
            WHERE     A.IDGASTOMAIN = pnSolicitud
                  AND A.IDCONCEPTO = pnConcepto
                  AND TRIM (FCNOMBRE) = psNmArchivo
         ORDER BY 1, 2, A.FDFECREGISTRO DESC;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getDetDocSopArchS;

   PROCEDURE setAddDoctoInicio (
      arrDetalle       PCKFACTURACIONGASTO.TABDOCTOINI,
      pnUsuario        INTEGER,
      psError      OUT VARCHAR2)
   IS
      psErrorD      VARCHAR2 (4000) := '';
      liBarre       INTEGER := 0;
      queConcec     INTEGER := 0;
      queCredito    VARCHAR2 (4000) := '';
      queSolic      INTEGER := 0;
      queConcepto   INTEGER := 0;
      siEsError     VARCHAR2 (4000) := '';
      queArchivo    VARCHAR2 (4000) := '';
   BEGIN
      FOR liBarre IN 1 .. arrDetalle.COUNT
      LOOP
         siEsError := '';

         SELECT FCCREDITO, IDGASTOMAIN, IDCONCEPTO
           INTO queCredito, queSolic, queConcepto
           FROM FACTURADCINICIO
          WHERE IDCONSEC = arrDetalle (liBarre).rconsecutivo;

         queConcec := arrDetalle (liBarre).rconsecutivo;

         UPDATE FACTURADCINICIO
            SET FCORIGENDOCTO = arrDetalle (liBarre).rQueEs,
                FCRUTAFILE = arrDetalle (liBarre).rRuta,
                FCUSUARIO = pnUsuario,
                FDFECREGISTRO = SYSDATE
          WHERE IDCONSEC = queConcec;
      END LOOP;

      psError := '0';
      DBMS_OUTPUT.put_line ('los valores son ' || psError);
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);
         psError := '*ERROR* ' || psErrorD;
   END setAddDoctoInicio;

   PROCEDURE setAddDoctoSoporte (
      arrDetalle       PCKFACTURACIONGASTO.TABDOCTOINI,
      pnUsuario        INTEGER,
      psError      OUT VARCHAR2)
   IS
      psErrorD      VARCHAR2 (4000) := '';
      liBarre       INTEGER := 0;
      queConcec     INTEGER := 0;
      queCredito    VARCHAR2 (4000) := '';
      queSolic      INTEGER := 0;
      queConcepto   INTEGER := 0;
   BEGIN
      FOR liBarre IN 1 .. arrDetalle.COUNT
      LOOP
         SELECT FCCREDITO, IDGASTOMAIN, IDCONCEPTO
           INTO queCredito, queSolic, queConcepto
           FROM FACTURADCSOPORTE
          WHERE IDCONSEC = arrDetalle (liBarre).rconsecutivo;

         queConcec := arrDetalle (liBarre).rconsecutivo;

         UPDATE FACTURADCSOPORTE
            SET FCORIGENDOCTO = arrDetalle (liBarre).rQueEs,
                FCRUTAFILE = arrDetalle (liBarre).rRuta,
                FCUSUARIO = pnUsuario,
                FDFECREGISTRO = SYSDATE
          WHERE IDCONSEC = queConcec;
      END LOOP;

      psError := '0';
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);
         psError := '*ERROR* ' || psErrorD;
   END setAddDoctoSoporte;

   PROCEDURE setVerifDoctoSoporte (
      arrDetalle       PCKFACTURACIONGASTO.TABVERIFDOCTOSOPORTE,
      pnUsuario        INTEGER,
      psError      OUT VARCHAR2)
   IS
      psErrorD      VARCHAR2 (4000) := '';
      liBarre       INTEGER := 0;
      identUsu      INTEGER := 0;
      elUsuEs       INTEGER := 0;
      queConcepto   INTEGER := 0;
      vdEmailPgo    VARCHAR2 (4000) := NULL;
      elCorreoEs    VARCHAR2 (4000) := NULL;
   BEGIN
      DBMS_OUTPUT.PUT_LINE ('entro..' || pnUsuario);

      SELECT CASE
                WHEN (SELECT COUNT (1)
                        FROM FACTURADCSOPORTE
                       WHERE     FCUSUARIO01 = TO_CHAR (pnUsuario)
                             AND IDCONSEC = arrDetalle (1).rconsecutivo) > 0
                THEN
                   1
                WHEN (SELECT COUNT (1)
                        FROM FACTURADCSOPORTE
                       WHERE     FCUSUARIO02 = TO_CHAR (pnUsuario)
                             AND IDCONSEC = arrDetalle (1).rconsecutivo) > 0
                THEN
                   2
                WHEN (SELECT COUNT (1)
                        FROM FACTURADCSOPORTE
                       WHERE     FCUSUARIO03 = TO_CHAR (pnUsuario)
                             AND IDCONSEC = arrDetalle (1).rconsecutivo) > 0
                THEN
                   3
                ELSE
                   NULL
             END
        INTO identUsu
        FROM DUAL;

      DBMS_OUTPUT.PUT_LINE ('quien es...' || pnUsuario || '----' || identUsu);

      FOR liBarre IN 1 .. arrDetalle.COUNT
      LOOP
         IF (identUsu = 1)
         THEN
            UPDATE FACTURADCSOPORTE
               SET FCRESULTADO01 = arrDetalle (liBarre).rResultado,
                   FCCOMENTARIO01 = arrDetalle (liBarre).rComentario,
                   FDFECREGISTRO01 = SYSDATE
             WHERE IDCONSEC = arrDetalle (liBarre).rconsecutivo;

            DBMS_OUTPUT.PUT_LINE ('entro 1');
         ELSIF (identUsu = 2)
         THEN
            UPDATE FACTURADCSOPORTE
               SET FCRESULTADO02 = arrDetalle (liBarre).rResultado,
                   FCCOMENTARIO02 = arrDetalle (liBarre).rComentario,
                   FDFECREGISTRO02 = SYSDATE
             WHERE IDCONSEC = arrDetalle (liBarre).rconsecutivo;

            DBMS_OUTPUT.PUT_LINE ('entro 2');
         ELSIF (identUsu = 3)
         THEN
            UPDATE FACTURADCSOPORTE
               SET FCRESULTADO03 = arrDetalle (liBarre).rResultado,
                   FCCOMENTARIO03 = arrDetalle (liBarre).rComentario,
                   FDFECREGISTRO03 = SYSDATE
             WHERE IDCONSEC = arrDetalle (liBarre).rconsecutivo;

            DBMS_OUTPUT.PUT_LINE ('entro 3');
         END IF;
      END LOOP;

      psError := '0';
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);
         psError := '*ERROR* ' || psErrorD;
   END setVerifDoctoSoporte;

   PROCEDURE setJustificaAlerta (
      arrDetalle       PCKFACTURACIONGASTO.TABJUSTIFICAALERTA,
      pnUsuario        INTEGER,
      psError      OUT VARCHAR2)
   IS
      psErrorD   VARCHAR2 (4000) := '';
      liBarre    INTEGER := 0;
   BEGIN
      FOR liBarre IN 1 .. arrDetalle.COUNT
      LOOP
         IF (arrDetalle (liBarre).rAlerta = 6)
         THEN                                                     /* UMBRAL */
            DBMS_OUTPUT.PUT_LINE (
                  '6----'
               || arrDetalle (liBarre).rIdGasto
               || '-'
               || arrDetalle (liBarre).rConcepto
               || '-'
               || arrDetalle (liBarre).rCredito
               || '-'
               || arrDetalle (liBarre).rComentario);

            UPDATE FACTURAASIGNACION
               SET FCJUSTIFICACIONUMBRAL = arrDetalle (liBarre).rComentario
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND IDCONCEPTO = arrDetalle (liBarre).rConcepto
                   AND FCCREDITOCARTERA = arrDetalle (liBarre).rCredito
                   AND TO_CHAR(FDFECREGISTRO, 'DDMMYYYYHH24MISS') =  arrDetalle (liBarre).rFechaRegistro;
         ELSIF (arrDetalle (liBarre).rAlerta = 7)
         THEN                                                     /* ETAPAS */
            DBMS_OUTPUT.PUT_LINE (
                  '7----'
               || arrDetalle (liBarre).rIdGasto
               || '-'
               || arrDetalle (liBarre).rConcepto
               || '-'
               || arrDetalle (liBarre).rCredito
               || '-'
               || arrDetalle (liBarre).rComentario);

            UPDATE FACTURAASIGNACION
               SET FCJUSTIFICAETAPA = arrDetalle (liBarre).rComentario
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND IDCONCEPTO = arrDetalle (liBarre).rConcepto
                   AND FCCREDITOCARTERA = arrDetalle (liBarre).rCredito
                   AND TO_CHAR(FDFECREGISTRO, 'DDMMYYYYHH24MISS') =  arrDetalle (liBarre).rFechaRegistro;
         ELSIF (arrDetalle (liBarre).rAlerta = 8)
         THEN                                                 /* PAGO DOBLE */
            DBMS_OUTPUT.PUT_LINE (
                  '8----'
               || arrDetalle (liBarre).rIdGasto
               || '-'
               || arrDetalle (liBarre).rConcepto
               || '-'
               || arrDetalle (liBarre).rCredito
               || '-'
               || arrDetalle (liBarre).rComentario);

            UPDATE FACTURAASIGNACION
               SET FCJUSTIFICAPAGODBL = arrDetalle (liBarre).rComentario
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND IDCONCEPTO = arrDetalle (liBarre).rConcepto
                   AND TO_CHAR(FDFECREGISTRO, 'DDMMYYYYHH24MISS') =  arrDetalle (liBarre).rFechaRegistro;
         ELSIF (arrDetalle (liBarre).rAlerta = 10)
         THEN                                                     /* EMPRESA*/
            DBMS_OUTPUT.PUT_LINE (
                  '10----'
               || arrDetalle (liBarre).rIdGasto
               || '-'
               || arrDetalle (liBarre).rConcepto
               || '-'
               || arrDetalle (liBarre).rCredito
               || '-'
               || arrDetalle (liBarre).rComentario);

            UPDATE FACTURAASIGNACION
               SET FCJUSTIFICAEMPRESA = arrDetalle (liBarre).rComentario
             WHERE IDGASTOMAIN = arrDetalle (liBarre).rIdGasto;
         ELSIF (arrDetalle (liBarre).rAlerta = 34)
         THEN                                                    /* URGENTE */
            DBMS_OUTPUT.PUT_LINE (
                  '34----'
               || arrDetalle (liBarre).rIdGasto
               || '-'
               || arrDetalle (liBarre).rConcepto
               || '-'
               || arrDetalle (liBarre).rCredito
               || '-'
               || arrDetalle (liBarre).rComentario);

            UPDATE FACTURAASIGNACION
               SET FCJUSTIFICAURGENTE = arrDetalle (liBarre).rComentario
             WHERE IDGASTOMAIN = arrDetalle (liBarre).rIdGasto;
         ELSIF (arrDetalle (liBarre).rAlerta = 44)
         THEN                                  /* EXCEPCION DE COMPROBACION */
            DBMS_OUTPUT.PUT_LINE (
                  '44----'
               || arrDetalle (liBarre).rIdGasto
               || '-'
               || arrDetalle (liBarre).rConcepto
               || '-'
               || arrDetalle (liBarre).rCredito
               || '-'
               || arrDetalle (liBarre).rComentario);

            UPDATE FACTURAASIGNACION
               SET FCJUSTIFICAEXCGASTO = arrDetalle (liBarre).rComentario
             WHERE IDGASTOMAIN = arrDetalle (liBarre).rIdGasto;
         ELSIF (arrDetalle (liBarre).rAlerta = 45)
         THEN                                   /* ETAPA FINAL COMPROBACION */
            DBMS_OUTPUT.PUT_LINE (
                  '45----'
               || arrDetalle (liBarre).rIdGasto
               || '-'
               || arrDetalle (liBarre).rConcepto
               || '-'
               || arrDetalle (liBarre).rCredito
               || '-'
               || arrDetalle (liBarre).rComentario);

            UPDATE FACTURAASIGNACION
               SET FCJUSTIFICETAFINAL = arrDetalle (liBarre).rComentario
             WHERE IDGASTOMAIN = arrDetalle (liBarre).rIdGasto;
         ELSIF (arrDetalle (liBarre).rAlerta = 46)
         THEN                                 /* CREDITOS LIQ  EXCEPCIONA?ES*/
            DBMS_OUTPUT.PUT_LINE (
                  '46----'
               || arrDetalle (liBarre).rIdGasto
               || '-'
               || arrDetalle (liBarre).rConcepto
               || '-'
               || arrDetalle (liBarre).rCredito
               || '-'
               || arrDetalle (liBarre).rComentario);

            UPDATE FACTURAASIGNACION
               SET FCJUSTIFICALIQ = arrDetalle (liBarre).rComentario
             WHERE IDGASTOMAIN = arrDetalle (liBarre).rIdGasto;
         END IF;
      END LOOP;

      psError := '0';
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);
         psError := '*ERROR* ' || psErrorD;
   END setJustificaAlerta;

   PROCEDURE setAutorizaAlerta (
      arrDetalle       PCKFACTURACIONGASTO.TABAUTORIZAALERTA,
      pnUsuario        INTEGER,
      psError      OUT VARCHAR2)
   IS
      psErrorD      VARCHAR2 (4000) := '';
      liBarre       INTEGER := 0;
      identUsu      INTEGER := 0;
      elUsuEs       INTEGER := 0;
      queConcepto   INTEGER := 0;
      vdEmailPgo    VARCHAR2 (4000) := NULL;
      elCorreoEs    VARCHAR2 (4000) := NULL;
   BEGIN
      FOR liBarre IN 1 .. arrDetalle.COUNT
      LOOP
         IF (arrDetalle (liBarre).rAlerta = 6)
         THEN                                                     /* UMBRAL */
            UPDATE FACTURAASIGNACION
               SET FCRESUMBRAL03 = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND IDCONCEPTO = arrDetalle (liBarre).rConcepto
                   AND FCCREDITOCARTERA = arrDetalle (liBarre).rCredito
                   AND FCUSUUMBRAL03 = pnUsuario;

            UPDATE FACTURAASIGNACION
               SET FCRESUMBRAL04 = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND IDCONCEPTO = arrDetalle (liBarre).rConcepto
                   AND FCCREDITOCARTERA = arrDetalle (liBarre).rCredito
                   AND FCUSUUMBRAL04 = pnUsuario;

            UPDATE FACTURAASIGNACION
               SET FCRESUMBRAL05 = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND IDCONCEPTO = arrDetalle (liBarre).rConcepto
                   AND FCCREDITOCARTERA = arrDetalle (liBarre).rCredito
                   AND FCUSUUMBRAL05 = pnUsuario;
         ELSIF (arrDetalle (liBarre).rAlerta = 7)
         THEN                                                     /* ETAPAS */
            UPDATE FACTURAASIGNACION
               SET FCRESETAPA01 = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND IDCONCEPTO = arrDetalle (liBarre).rConcepto
                   AND FCCREDITOCARTERA = arrDetalle (liBarre).rCredito
                   AND FCUSUETAPA01 = pnUsuario;

            UPDATE FACTURAASIGNACION
               SET FCRESETAPA02 = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND IDCONCEPTO = arrDetalle (liBarre).rConcepto
                   AND FCCREDITOCARTERA = arrDetalle (liBarre).rCredito
                   AND FCUSUETAPA02 = pnUsuario;
         ELSIF (arrDetalle (liBarre).rAlerta = 8)
         THEN                                                 /* PAGO DOBLE */
            UPDATE FACTURAASIGNACION
               SET FCRESPGODBL01 = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND IDCONCEPTO = arrDetalle (liBarre).rConcepto
                   AND FCCREDITOCARTERA = arrDetalle (liBarre).rCredito
                   AND FCUSUPGODBL01 = pnUsuario;

            UPDATE FACTURAASIGNACION
               SET FCRESPGODBL02 = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND IDCONCEPTO = arrDetalle (liBarre).rConcepto
                   AND FCCREDITOCARTERA = arrDetalle (liBarre).rCredito
                   AND FCUSUPGODBL02 = pnUsuario;
         ELSIF (arrDetalle (liBarre).rAlerta = 9)
         THEN                                              /* JEFE INMEDIATO*/
            UPDATE FACTURAASIGNACION
               SET FCRESULTJFEINMED = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND FCUSUJFEINMED = pnUsuario;
         ELSIF (arrDetalle (liBarre).rAlerta = 10)
         THEN                                                     /* EMPRESA*/
            UPDATE FACTURAASIGNACION
               SET FCRESEMPRESA = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND FCUSUEMPRESA = pnUsuario;
         ELSIF (arrDetalle (liBarre).rAlerta = 34)
         THEN                                                    /* URGENTE */
            UPDATE FACTURAASIGNACION
               SET FCRESURGENTE = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND FCUSUURGENTE = pnUsuario;
         ELSIF (arrDetalle (liBarre).rAlerta = 44)
         THEN                                     /* EXCESO DE COMPROBACION */
            UPDATE FACTURAASIGNACION
               SET FCRESEXCGASTO01 = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND FCUSUEXCGASTO01 = pnUsuario;

            UPDATE FACTURAASIGNACION
               SET FCRESEXCGASTO02 = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND FCUSUEXCGASTO02 = pnUsuario;
         ELSIF (arrDetalle (liBarre).rAlerta = 45)
         THEN                                         /* ULTIMA ETAPA FINAL */
            UPDATE FACTURAASIGNACION
               SET FCRESETAFINAL01 = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND IDCONCEPTO = arrDetalle (liBarre).rConcepto
                   AND FCCREDITOCARTERA = arrDetalle (liBarre).rCredito
                   AND FCUSUETAFINAL01 = pnUsuario;

            UPDATE FACTURAASIGNACION
               SET FCRESETAFINAL02 = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND IDCONCEPTO = arrDetalle (liBarre).rConcepto
                   AND FCCREDITOCARTERA = arrDetalle (liBarre).rCredito
                   AND FCUSUETAFINAL02 = pnUsuario;
         ELSIF (arrDetalle (liBarre).rAlerta = 46)
         THEN                                    /* CREDITO ?IQ EXCEPCIONAL */
            UPDATE FACTURAASIGNACION
               SET FCRESLIQ01 = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND IDCONCEPTO = arrDetalle (liBarre).rConcepto
                   AND FCCREDITOCARTERA = arrDetalle (liBarre).rCredito
                   AND FCUSUETAFINAL01 = pnUsuario;

            UPDATE FACTURAASIGNACION
               SET FCRESLIQ02 = arrDetalle (liBarre).rResultado
             WHERE     IDGASTOMAIN = arrDetalle (liBarre).rIdGasto
                   AND IDCONCEPTO = arrDetalle (liBarre).rConcepto
                   AND FCCREDITOCARTERA = arrDetalle (liBarre).rCredito
                   AND FCUSUETAFINAL02 = pnUsuario;
         END IF;
      END LOOP;

      psError := '0';
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);
         psError := '*ERROR* ' || psErrorD;
   END setAutorizaAlerta;

   PROCEDURE getCatConceptoAsig (psTipoSolic          VARCHAR2,
                                 psQueAsigna          INTEGER,
                                 quePuestoEs          VARCHAR2,
                                 salida        IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa            T_CURSOR;
      psCadenaCarteras   VARCHAR2 (4000) := '';
      existe             INTEGER := 0;
      puestoComp         VARCHAR2 (20) := quePuestoEs || '|';
   BEGIN
      psCadenaCarteras :=
            'SELECT IDCUENTACAT IDVALOR, NMDESCRIP NMVALOR
              FROM CTCUENTACATEGORIA A
             WHERE FCSTATUS = ''A''
               AND IDCUENTACAT IN (SELECT IDCATEGORIA
                                     FROM CTCATALOGOCUENTAS
                                    WHERE FCSTATUS = ''A'' AND APLICAPROCESO = ''S''
                                      AND FCPUESTOGASTO LIKE ''%'
         || puestoComp
         || '%''';

      IF UPPER (psTipoSolic) = 'ANTICIPO'
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCANTICIPO = ''S''';
      ELSIF UPPER (psTipoSolic) = 'REEMBOLSO'
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCREEMBOLSO = ''S''';
      ELSIF UPPER (psTipoSolic) = 'TRAMITE'
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCTRAMITE = ''S''';
      ELSE
         psCadenaCarteras := psCadenaCarteras || ' AND FCTRAMITE = ''X''';
      END IF;

      IF (psQueAsigna = 2)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLCREDITO = ''S'' ';
      END IF;

      IF (psQueAsigna = 3)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLMCREDITO = ''S'' ';
      END IF;

      IF (psQueAsigna = 4)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLCARTERA = ''S'' ';
      END IF;

      IF (psQueAsigna = 42)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLCREDITO IS NULL AND FCAPLMCREDITO IS NULL AND FCAPLCARTERA IS NULL ';
      END IF;

      psCadenaCarteras := psCadenaCarteras || ')  ORDER BY 2,1';

      DBMS_OUTPUT.put_line ('ahi te va ...' || psCadenaCarteras);

      OPEN procesa FOR psCadenaCarteras;

      --            SELECT IDCUENTACAT IDVALOR, NMDESCRIP NMVALOR
      --              FROM CTCUENTACATEGORIA A
      --             WHERE IDCUENTACAT IN (SELECT IDCATEGORIA
      --                                     FROM CTCATALOGOCUENTAS
      --                                    WHERE FCPUESTOGASTO LIKE '%'||puestoComp||'%'
      --                                  )
      --           ORDER By 2;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getCatConceptoAsig;

   PROCEDURE getSbCatConceptoAsig (queCategoria          INTEGER,
                                   psTipoSolic           VARCHAR2,
                                   psQueAsigna           INTEGER,
                                   quePuestoEs           VARCHAR2,
                                   salida         IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa            T_CURSOR;
      psCadenaCarteras   VARCHAR2 (4000) := '';
      existe             INTEGER := 0;
      puestoComp         VARCHAR2 (20) := quePuestoEs || '|';
   BEGIN
      psCadenaCarteras :=
            'SELECT IDCUENTACAT IDVALOR, NMDESCRIP NMVALOR
              FROM CTCUENTACATEGORIA A
             WHERE IDHIJO = '
         || queCategoria
         || '
               AND FCSTATUS = ''A''
               AND (IDHIJO,IDCUENTACAT) IN
                  (SELECT IDCATEGORIA,IDSUBCATEGORIA
                     FROM CTCATALOGOCUENTAS
                    WHERE FCSTATUS = ''A'' AND APLICAPROCESO = ''S''
                      AND FCPUESTOGASTO LIKE  ''%'
         || puestoComp
         || '%''';

      IF UPPER (psTipoSolic) = 'ANTICIPO'
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCANTICIPO = ''S''';
      ELSIF UPPER (psTipoSolic) = 'REEMBOLSO'
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCREEMBOLSO = ''S''';
      ELSIF UPPER (psTipoSolic) = 'TRAMITE'
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCTRAMITE = ''S''';
      ELSE
         psCadenaCarteras := psCadenaCarteras || ' AND FCTRAMITE = ''X''';
      END IF;

      IF (psQueAsigna = 2)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLCREDITO = ''S'' ';
      END IF;

      IF (psQueAsigna = 3)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLMCREDITO = ''S'' ';
      END IF;

      IF (psQueAsigna = 4)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLCARTERA = ''S'' ';
      END IF;

      IF (psQueAsigna = 42)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLCREDITO IS NULL AND FCAPLMCREDITO IS NULL AND FCAPLCARTERA IS NULL ';
      END IF;

      psCadenaCarteras := psCadenaCarteras || ')  ORDER BY 2,1';

      DBMS_OUTPUT.put_line ('ahi te va ...' || psCadenaCarteras);

      OPEN procesa FOR psCadenaCarteras;

      --            SELECT IDCUENTACAT IDVALOR, NMDESCRIP NMVALOR
      --              FROM CTCUENTACATEGORIA A
      --             WHERE IDHIJO = queCategoria
      --               AND (IDHIJO,IDCUENTACAT) IN
      --                  (SELECT IDCATEGORIA,IDSUBCATEGORIA
      --                     FROM CTCATALOGOCUENTAS
      --                    WHERE FCPUESTOGASTO LIKE '%'||puestoComp||'%'
      --                  )
      --           ORDER By 2;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getSbCatConceptoAsig;

   PROCEDURE getQueConceptoAsig (queCategoria             INTEGER,
                                 queSubCategoria          INTEGER,
                                 psTipoSolic              VARCHAR2,
                                 psQueAsigna              INTEGER,
                                 quePuestoEs              VARCHAR2,
                                 salida            IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa            T_CURSOR;
      psCadenaCarteras   VARCHAR2 (4000) := '';
      existe             INTEGER := 0;
      puestoComp         VARCHAR2 (20) := quePuestoEs || '|';
   BEGIN
      psCadenaCarteras :=
            'SELECT IDCONCEPTO, NMCONCEPTO
              FROM CTCATALOGOCUENTAS A
             WHERE IDCATEGORIA = '
         || queCategoria
         || ' AND IDSUBCATEGORIA = '
         || queSubCategoria
         || '
               AND FCSTATUS = ''A'' AND APLICAPROCESO = ''S''
               AND FCPUESTOGASTO LIKE  ''%'
         || puestoComp
         || '%''';

      IF UPPER (psTipoSolic) = 'ANTICIPO'
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCANTICIPO = ''S'' ';
      ELSIF UPPER (psTipoSolic) = 'REEMBOLSO'
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCREEMBOLSO = ''S'' ';
      ELSIF UPPER (psTipoSolic) = 'TRAMITE'
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCTRAMITE = ''S'' ';
      ELSE
         psCadenaCarteras := psCadenaCarteras || ' AND FCTRAMITE = ''X'' ';
      END IF;

      IF (psQueAsigna = 2)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLCREDITO = ''S'' ';
      END IF;

      IF (psQueAsigna = 3)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLMCREDITO = ''S'' ';
      END IF;

      IF (psQueAsigna = 4)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLCARTERA = ''S'' ';
      END IF;

      IF (psQueAsigna = 42)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLCREDITO IS NULL AND FCAPLMCREDITO IS NULL AND FCAPLCARTERA IS NULL ';
      END IF;

      psCadenaCarteras := psCadenaCarteras || ' ORDER BY 2,1';

      DBMS_OUTPUT.put_line ('ahi te va ...' || psCadenaCarteras);

      OPEN procesa FOR psCadenaCarteras;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getQueConceptoAsig;

   PROCEDURE getQueConceptoNmAsig (queCategoria             INTEGER,
                                   queSubCategoria          INTEGER,
                                   queBuscar                VARCHAR2,
                                   psTipoSolic              VARCHAR2,
                                   psQueAsigna              INTEGER,
                                   quePuestoEs              VARCHAR2,
                                   salida            IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa            T_CURSOR;
      psCadenaCarteras   VARCHAR2 (4000) := '';
      existe             INTEGER := 0;
      puestoComp         VARCHAR2 (20) := quePuestoEs || '|';
      BuscarComp         VARCHAR2 (20) := UPPER (queBuscar);
   BEGIN
      psCadenaCarteras :=
            'SELECT IDCONCEPTO, NMCONCEPTO
              FROM CTCATALOGOCUENTAS A
             WHERE IDCATEGORIA = '
         || queCategoria
         || ' AND IDSUBCATEGORIA = '
         || queSubCategoria
         || '
               AND UPPER(NMCONCEPTO) LIKE  ''%'
         || BuscarComp
         || '%''
               AND FCPUESTOGASTO LIKE ''%'
         || puestoComp
         || '%'' AND FCSTATUS = ''A'' ';

      IF UPPER (psTipoSolic) = 'ANTICIPO'
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCANTICIPO = ''S'' ';
      ELSIF UPPER (psTipoSolic) = 'REEMBOLSO'
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCREEMBOLSO = ''S'' ';
      ELSIF UPPER (psTipoSolic) = 'TRAMITE'
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCTRAMITE = ''S'' ';
      ELSE
         psCadenaCarteras := psCadenaCarteras || ' AND FCTRAMITE = ''X'' ';
      END IF;

      IF (psQueAsigna = 2)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLCREDITO = ''S'' ';
      END IF;

      IF (psQueAsigna = 3)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLMCREDITO = ''S'' ';
      END IF;

      IF (psQueAsigna = 4)
      THEN
         psCadenaCarteras := psCadenaCarteras || ' AND FCAPLCARTERA = ''S'' ';
      END IF;

      psCadenaCarteras := psCadenaCarteras || ' ORDER BY 2,1';

      DBMS_OUTPUT.put_line ('ahi te va ...' || psCadenaCarteras);

      OPEN procesa FOR psCadenaCarteras;

      --            SELECT IDCONCEPTO, NMCONCEPTO
      --              FROM CTCATALOGOCUENTAS A
      --             WHERE IDCATEGORIA = queCategoria AND IDSUBCATEGORIA = queSubCategoria
      --               AND UPPER(NMCONCEPTO) LIKE '%'||BuscarComp||'%'
      --               AND FCPUESTOGASTO LIKE '%'||puestoComp||'%'
      --           ORDER By 2;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getQueConceptoNmAsig;

   PROCEDURE setTramiteINTERNO (pnGasto INTEGER)
   IS
      CURSOR cuCualesMain
      IS
         SELECT *
           FROM FACTURACIONMAIN
          WHERE IDGASTOMAIN = pnGasto;

      CURSOR cuCualesAsig
      IS
         SELECT *
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnGasto;

      CURSOR cuConcepto (cualEs INTEGER)
      IS
         SELECT *
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = cualEs;

      queelemento       INTEGER := 0;
      otro              INTEGER := pnGasto;
      psCadenaEjecuta   VARCHAR2 (1000)
         := 'PCKFACTURACIONGASTO.setTramiteINTERNO(' || pnGasto || ')';
      psErrorD          VARCHAR2 (4000) := '0';
      vsError           VARCHAR2 (4000) := '0';
   BEGIN
      psErrorD := '0';

      DELETE FACTURACIONAUT
       WHERE     IDGASTOMAIN = pnGasto
             AND IDDELINDEX = (SELECT MAX (DEL_INDEX)
                                 FROM FACTURACIONBITACORA
                                WHERE IDGASTOMAIN = pnGasto);

      FOR regMain IN cuCualesMain
      LOOP
         FOR regConc IN cuConcepto (regMain.IDCONCEPTO)
         LOOP
            UPDATE FACTURACIONMAIN
               SET FNIMPORTECOMPROBADO = regConc.FNCOSTOINTERNO,
                   FNIMPORTEANTICIPO = 0,
                   FNIMPORTESOLICITADO = 0,
                   FCPAGOADICIONAL = NULL,
                   FCSEVERIDADGASTO = NULL,
                   IDEMPRESAFACTURACION = NULL,
                   IDOTEMPRESAFACTURACION = NULL,
                   IDFORMAPAGO = NULL,
                   FCTIPOCUENTA = NULL,
                   FDFECHAREQUERIDA = NULL
             WHERE IDGASTOMAIN = pnGasto AND IDCONCEPTO = regMain.IDCONCEPTO;
         END LOOP;
      END LOOP;

      FOR regAsig IN cuCualesAsig
      LOOP
         FOR regConc IN cuConcepto (regAsig.IDCONCEPTO)
         LOOP
            UPDATE FACTURAASIGNACION
               SET FCDETALLECAMPOS = regConc.FNCOSTOINTERNO,
                   FNIMPORTE = 0,
                   FCQUEUMBRAL = 0,
                   FNUMBRAL = NULL,
                   FNUMBRALREBASADO = 0,
                   FNIMPORTECOMPROBA = 0
             WHERE     IDGASTOMAIN = pnGasto
                   AND IDCONCEPTO = regAsig.IDCONCEPTO
                   AND FCCREDITOCARTERA = regAsig.FCCREDITOCARTERA;
         END LOOP;
      END LOOP;

      COMMIT;
      DBMS_OUTPUT.PUT_LINE ('** EXITOSOOO ** ');

      ---- INSERTA EL DETALLE DE LA TRANSACCION
      SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

      INSERT INTO BITACORATRANSACCION
           VALUES (pnGasto,
                   queelemento,
                   psCadenaEjecuta,
                   SYSDATE,
                   SYSDATE,
                   psErrorD);

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         vsError := SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('** ERROR ** ' || SQLERRM);
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

         INSERT INTO BITACORATRANSACCION
              VALUES (otro,
                      queelemento,
                      psCadenaEjecuta,
                      SYSDATE,
                      SYSDATE,
                      psErrorD);

         COMMIT;
   END setTramiteINTERNO;

   PROCEDURE setTramiteExterno (pnCaso              INTEGER,
                                psTipoSolucion      VARCHAR2,
                                quienSolic          INTEGER,
                                queSeveridad        VARCHAR2,
                                queEmpresaFact      VARCHAR2,
                                queOtEmpresaFact    VARCHAR2,
                                queFormaPago        VARCHAR2,
                                queTipoCuenta       VARCHAR2,
                                psCadenaEjecuta     VARCHAR2,
                                pdFecRequerida      VARCHAR2)
   IS
      vsExiste       INTEGER := 0;
      vsExiste1      INTEGER := 0;
      vnsucursal     INTEGER := 0;
      queelemento    INTEGER := 0;
      numConsec      INTEGER := 0;
      queHistorico   INTEGER := 0;
      FecRequerida   DATE := TO_DATE (pdFecRequerida, 'DD/MM/YYYY');
      psErrorD       VARCHAR2 (500) := '';
   BEGIN
      DBMS_OUTPUT.PUT_LINE ('INICIO...');

      UPDATE FACTURACIONMAIN
         SET FCSEVERIDADGASTO = queSeveridad,
             FCTIPOSOLUCION = psTipoSolucion,
             IDEMPRESAFACTURACION = queEmpresaFact,
             IDOTEMPRESAFACTURACION = queOtEmpresaFact,
             IDFORMAPAGO = queFormaPago,
             FCTIPOCUENTA = queTipoCuenta,
             FDFECHAREQUERIDA = FecRequerida
       WHERE IDGASTOMAIN = pnCaso;

      DBMS_OUTPUT.PUT_LINE ('UPDATE FACTURACIONMAIN....');

      SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

      INSERT INTO BITACORATRANSACCION
           VALUES (pnCaso,
                   queelemento,
                   psCadenaEjecuta,
                   SYSDATE,
                   SYSDATE,
                   '0');

      DBMS_OUTPUT.PUT_LINE ('EXITOSO....');
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         INSERT INTO BITACORATRANSACCION
              VALUES (pnCaso,
                      queelemento,
                      psCadenaEjecuta,
                      SYSDATE,
                      SYSDATE,
                      psErrorD);

         COMMIT;
         DBMS_OUTPUT.PUT_LINE ('-1 ' || SQLERRM);
   END setTramiteExterno;

   PROCEDURE getDetalleDiaTeso (pnEmpleado          INTEGER,
                                laFechaEs           VARCHAR2,
                                salida       IN OUT T_CURSOR,
                                queEmpresaFact      VARCHAR2,
                                queLote             INTEGER DEFAULT 0)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa           T_CURSOR;
      fdFechaOperaIni   DATE := TO_DATE (laFechaEs, 'DD/MM/YYYY')+1;
      fdFechaOperaFin   DATE := TO_DATE (laFechaEs || ' 23:59', 'DD/MM/YYYY HH24:MI');
      quienOpero        VARCHAR2(100) := '';

   BEGIN

      OPEN procesa FOR
           SELECT    ROW_NUMBER()
                         OVER (PARTITION BY PROVEEDOR ORDER BY PROVEEDOR) AS numero,
                    GASTO, REPLACE(CONCEPTO,'<BR/>','') CONCEPTO,
                            IMPORTE, DEPOSITO,  FECHAESPERADA,CUENTARETIRO,TIPODEPOSITO,
                            REFERENCIA,CVEPROVEEDOR, PROVEEDOR,CTADEPOSITO,  NUMOTE, REFDYN
                    FROM (
                               SELECT IDGASTOMAIN GASTO,
                                      PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN) CONCEPTO,
                                      FNIMPORTEDEPOSITO IMPORTE,
                                      '$' || PCKCONVENIOS.formatComas (FNIMPORTEDEPOSITO) DEPOSITO,
                                      (SELECT DISTINCT PCKENVIOCORREO.aplFecha (FDFECPARAPAGO,'N')
                                         FROM FACTURACIONPAGOS X
                                        WHERE X.IDGASTOMAIN = MAIN.IDGASTOMAIN
                                          AND X.FNCONSEC = MAIN.FNCONSEC)
                                         FECHAESPERADA,
                                      FCCUENTADEPOSITO CUENTARETIRO,
                                      CASE
                                         WHEN FNCONSEC = 2 THEN 'ANTICIPO'
                                         WHEN FNCONSEC = 6 THEN 'PAGO / REEMBOLSO'
                                      END  TIPODEPOSITO,
                                      FCREFERENCIA REFERENCIA,
                                      MAIN.IDPROVEEDORGTO  CVEPROVEEDOR,
                                      (SELECT NMPROVEEDOR   FROM CTPROVEEDORGASTO  CC  WHERE CC.IDPROVEEDORGTO = MAIN.IDPROVEEDORGTO) PROVEEDOR,
                                      FCNUMCTADEPOSITO  CTADEPOSITO ,
                                      FNNUMARCHCONTROL NUMOTE,
                                      (SELECT FCREFERDYN FROM FACTURACIONPAGOS XX WHERE XX.IDGASTOMAIN = MAIN.IDGASTOMAIN AND XX.FNCONSEC = MAIN.FNCONSEC) REFDYN
                                 FROM FACTURACIONDEPOSITO MAIN
                                WHERE
                                FDFECREGISTRO BETWEEN fdFechaOperaIni-15 AND fdFechaOperaFin
--                                WHERE FDFECDERIVACION BETWEEN fdFechaOperaIni-15 AND fdFechaOperaFin
--                                  AND  FCSTATUS = 'A'
                                  AND IDEMPRESA = queEmpresaFact
                                  AND FCTIPODEPOSITO =  36
                                  AND FNNUMARCHCONTROL = queLote
                    ) PASO ;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getDetalleDiaTeso;

   PROCEDURE getDetallePagosCie (pnEmpleado          INTEGER,
                                laFechaEs           VARCHAR2,
                                salida       IN OUT T_CURSOR,
                                queEmpresaFact      VARCHAR2,
                                queLote             INTEGER DEFAULT 0)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa           T_CURSOR;
      fdFechaOperaIni   DATE := TO_DATE (laFechaEs, 'DD/MM/YYYY')+1;
      fdFechaOperaFin   DATE := TO_DATE (laFechaEs || ' 23:59', 'DD/MM/YYYY HH24:MI');
      quienOpero        VARCHAR2(100) := '';

   BEGIN

      OPEN procesa FOR
           SELECT    ROW_NUMBER()
                         OVER (PARTITION BY PROVEEDOR ORDER BY PROVEEDOR) AS numero,
                    GASTO, REPLACE(CONCEPTO,'<BR/>','') CONCEPTO,
                            IMPORTE, DEPOSITO,  FECHAESPERADA,CUENTARETIRO,TIPODEPOSITO,
                            REFERENCIA,CVEPROVEEDOR, PROVEEDOR,CTADEPOSITO,  NUMOTE, REFDYN
                    FROM (
                               SELECT IDGASTOMAIN GASTO,
                                      PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN) CONCEPTO,
                                      FNIMPORTEDEPOSITO IMPORTE,
                                      '$' || PCKCONVENIOS.formatComas (FNIMPORTEDEPOSITO) DEPOSITO,
                                      (SELECT DISTINCT PCKENVIOCORREO.aplFecha (FDFECPARAPAGO,'N')
                                         FROM FACTURACIONPAGOS X
                                        WHERE X.IDGASTOMAIN = MAIN.IDGASTOMAIN
                                          AND X.FNCONSEC = MAIN.FNCONSEC)
                                         FECHAESPERADA,
                                      FCCUENTADEPOSITO CUENTARETIRO,
                                      CASE
                                         WHEN FNCONSEC = 2 THEN 'ANTICIPO'
                                         WHEN FNCONSEC = 6 THEN 'PAGO / REEMBOLSO'
                                      END  TIPODEPOSITO,
                                      FCREFERENCIA REFERENCIA,
                                      MAIN.IDPROVEEDORGTO  CVEPROVEEDOR,
                                      (SELECT NMPROVEEDOR   FROM CTPROVEEDORGASTO  CC  WHERE CC.IDPROVEEDORGTO = MAIN.IDPROVEEDORGTO) PROVEEDOR,
                                      FCNUMCTADEPOSITO  CTADEPOSITO ,
                                      FNNUMARCHCONTROL NUMOTE,
                                      (SELECT FCREFERDYN FROM FACTURACIONPAGOS XX WHERE XX.IDGASTOMAIN = MAIN.IDGASTOMAIN AND XX.FNCONSEC = MAIN.FNCONSEC) REFDYN
                                 FROM FACTURACIONDEPOSITO MAIN
                                WHERE
                                FDFECREGISTRO BETWEEN fdFechaOperaIni-15 AND fdFechaOperaFin
--                                WHERE FDFECDERIVACION BETWEEN fdFechaOperaIni-15 AND fdFechaOperaFin
--                                  AND  FCSTATUS = 'A'
                                  AND IDEMPRESA = queEmpresaFact
                                  AND FCTIPODEPOSITO =  40
                                  AND FNNUMARCHCONTROL = queLote
                    ) PASO ;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getDetallePagosCie;

   PROCEDURE getDetalleDiaCheqTeso (pnEmpleado          INTEGER,
                                laFechaEs           VARCHAR2,
                                salida       IN OUT T_CURSOR,
                                queEmpresaFact      VARCHAR2)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa           T_CURSOR;
      fdFechaOperaIni   DATE := TO_DATE (laFechaEs, 'DD/MM/YYYY');
      fdFechaOperaFin   DATE := TO_DATE (laFechaEs || ' 23:59', 'DD/MM/YYYY HH24:MI');
      quienOpero        VARCHAR2(100) := '';

   BEGIN

   SELECT '(' || "cvetra" || ') ' || "nombreCompleto"
     INTO quienOpero
     FROM PENDUPM.VISTAASOCIADOS A
    WHERE "cvetra" = pnEmpleado;

      OPEN procesa FOR
SELECT GASTO, CONCEPTO,
        (SELECT '(' || "cvetra" || ') ' || "nombreCompleto"
                             FROM PENDUPM.VISTAASOCIADOS A
                            WHERE "cvetra" = PASO.SOLICITANTE
        ) SOLICITANTE,
        IMPORTE, DEPOSITO, FECMOVTO FECHA ,TIPODEPOSITO||'<BR/>'||FORMAPAGO TIPODEPOSITO,FORMAPAGO,FECHA ORDEN,
        quienOpero QUIENAPLICO,   EMPFACURACION      ,DEPOSITOA, CTADEPOSITO, PROVEEDOR,REFERENCIA
FROM (
          SELECT IDGASTOMAIN GASTO,
                  PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN) CONCEPTO,
                  (SELECT DISTINCT FNNUMEMPLEADO
                     FROM FACTURACIONMAIN X
                    WHERE X.IDGASTOMAIN = MAIN.IDGASTOMAIN) SOLICITANTE,
                  FNIMPORTEDEPOSITO IMPORTE,
                  '$' || PCKCONVENIOS.formatComas (FNIMPORTEDEPOSITO) DEPOSITO,
                  (SELECT DISTINCT PCKENVIOCORREO.aplFecha (FDDYNAMICSGASTOCONF, FDDYNAMICSREEMBCONF)
                     FROM FACTURACIONMAIN X
                    WHERE X.IDGASTOMAIN = MAIN.IDGASTOMAIN)
                     FECMOVTO,
                  (SELECT DISTINCT FDDYNAMICSGASTO
                     FROM FACTURACIONMAIN X
                    WHERE X.IDGASTOMAIN = MAIN.IDGASTOMAIN)
                     FECHA,
                  '(' || FCCUENTADEPOSITO || ') ' || FCNOMBRE DEPOSITOA,
                  CASE
                     WHEN FNCONSEC = 2 THEN 'ANTICIPO'
                     WHEN FNCONSEC = 6 THEN 'PAGO / REEMBOLSO'
                  END
                     TIPODEPOSITO,
                     (SELECT NMDESCRIPCION
                        FROM CTCATALOGOGASTOS F
                       WHERE F.IDCATGASTO =
                                (SELECT DISTINCT IDFORMAPAGO
                                   FROM FACTURACIONMAIN X
                                  WHERE X.IDGASTOMAIN = MAIN.IDGASTOMAIN))
                  || '( ref.'
                  || FCREFERENCIA
                  || ' )'
                     FORMAPAGO,
                  FCUSUARIOAPLICA QUIENAPLICO,
                  (SELECT NMEMPRESA
                     FROM EMPRESAFACTURACION EMP
                    WHERE EMP.IDEMPRESA = MAIN.IDEMPRESA)
                     EMPFACURACION,
                    FCCUENTADEPOSITO  CTADEPOSITO ,
                   (SELECT NMPROVEEDOR   FROM CTPROVEEDORGASTO  CC  WHERE CC.IDPROVEEDORGTO = MAIN.IDPROVEEDORGTO)||
                   (SELECT  DISTINCT CASE WHEN IDFORMAPAGO = 38 THEN '<BR/>A nombre de : '||FCNMPAGOCHQCAJA END
                      FROM FACTURACIONMAIN FM  WHERE FM.IDGASTOMAIN = MAIN.IDGASTOMAIN) PROVEEDOR,
                   (SELECT FCREFERDYN  FROM FACTURACIONPAGOS DD WHERE  DD.IDGASTOMAIN = MAIN.IDGASTOMAIN AND DD.FNCONSEC = MAIN.FNCONSEC) REFERENCIA
             FROM FACTURACIONDEPOSITO MAIN
            WHERE FDFECDERIVACION BETWEEN fdFechaOperaIni AND fdFechaOperaFin
              AND IDEMPRESA = queEmpresaFact
              AND FCTIPODEPOSITO IN (37,38,39)
--              AND FCUSUARIOAPLICA = pnEmpleado
              AND  FCSTATUS = 'A'
) PASO
         ORDER BY ORDEN;
--           SELECT IDGASTOMAIN GASTO,
--                  PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN) CONCEPTO,
--                  (SELECT '(' || "cvetra" || ') ' || "nombreCompleto"
--                     from pendupm.vistaasociadoscompleta a
--                    WHERE "cvetra" = (SELECT DISTINCT FNNUMEMPLEADO
--                                        FROM FACTURACIONMAIN X
--                                       WHERE X.IDGASTOMAIN = MAIN.IDGASTOMAIN))
--                     SOLICITANTE,
--                  FNIMPORTEDEPOSITO IMPORTE,
--                  '$' || PCKCONVENIOS.formatComas (FNIMPORTEDEPOSITO) DEPOSITO,
--                  (SELECT DISTINCT PCKENVIOCORREO.aplFecha (FDDYNAMICSGASTO)
--                     FROM FACTURACIONMAIN X
--                    WHERE X.IDGASTOMAIN = MAIN.IDGASTOMAIN)
--                     FECMOVTO,
--                  (SELECT DISTINCT FDDYNAMICSGASTO
--                     FROM FACTURACIONMAIN X
--                    WHERE X.IDGASTOMAIN = MAIN.IDGASTOMAIN)
--                     FECHA,
--                  '(' || FCCUENTADEPOSITO || ') ' || FCNOMBRE DEPOSITOA,
--                  CASE
--                     WHEN FNCONSEC = 2 THEN 'ANTICIPO'
--                     WHEN FNCONSEC = 6 THEN 'PAGO / REEMBOLSO'
--                  END
--                     TIPODEPOSITO,
--                     (SELECT NMDESCRIPCION
--                        FROM CTCATALOGOGASTOS F
--                       WHERE F.IDCATGASTO =
--                                (SELECT DISTINCT IDFORMAPAGO
--                                   FROM FACTURACIONMAIN X
--                                  WHERE X.IDGASTOMAIN = MAIN.IDGASTOMAIN))
--                  || '( ref.'
--                  || FCREFERENCIA
--                  || ' )'
--                     FORMAPAGO,
--                  quienOpero QUIENAPLICO,
--                  (SELECT NMEMPRESA
--                     FROM EMPRESAFACTURACION EMP
--                    WHERE EMP.IDEMPRESA = MAIN.IDEMPRESA)
--                     EMPFACURACION
--            WHERE FDFECDERIVACION BETWEEN fdFechaOperaIni AND fdFechaOperaFin
--              AND FCUSUARIOAPLICA = pnEmpleado
--              AND  FCSTATUS = 'A'
--         ORDER BY 7, 1;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getDetalleDiaCheqTeso;

   PROCEDURE setTramiteAreaConc (pnGasto        INTEGER,
                                 pcEmailTit     VARCHAR2,
                                 pnQueGestor    VARCHAR2,
                                 queEjecuta     VARCHAR2)
   IS
      queEmailGestor    VARCHAR2 (50) := '';
      queEmailTitular   INTEGER := 0;
      queelemento       INTEGER := 0;
      psErrorD          VARCHAR2 (4000) := '0';
      vsError           VARCHAR2 (4000) := '0';
      existe            INTEGER := 0;
   BEGIN
      SELECT "cvetra"
        INTO queEmailTitular
        FROM PENDUPM.VISTAASOCIADOS A
       WHERE "email" = pcEmailTit;

      SELECT "email"
        INTO queEmailGestor
        FROM PENDUPM.VISTAASOCIADOS A
       WHERE "cvetra" = pnQueGestor;

      SELECT COUNT (1)
        INTO existe
        FROM FACTURATRAMITE
       WHERE IDGASTOMAIN = pnGasto;

      IF (existe = 0)
      THEN
         INSERT INTO FACTURATRAMITE (IDGASTOMAIN,
                                     FNEMAILTITULAR,
                                     FNEMPTITULAR,
                                     FCEMAILGESTOR,
                                     FNEMPGESTOR)
              VALUES (pnGasto,
                      pcEmailTit,
                      queEmailTitular,
                      queEmailGestor,
                      pnQueGestor);
      ELSE
         UPDATE FACTURATRAMITE
            SET FNEMAILTITULAR = pcEmailTit,
                FNEMPTITULAR = queEmailTitular,
                FCEMAILGESTOR = queEmailGestor,
                FNEMPGESTOR = pnQueGestor
          WHERE IDGASTOMAIN = pnGasto;
      END IF;

      ---- INSERTA EL DETALLE DE LA TRANSACCION
      SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

      INSERT INTO BITACORATRANSACCION
           VALUES (pnGasto,
                   queelemento,
                   queEjecuta,
                   SYSDATE,
                   SYSDATE,
                   psErrorD);

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         vsError := SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('** ERROR ** ' || SQLERRM);
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

         INSERT INTO BITACORATRANSACCION
              VALUES (pnGasto,
                      queelemento,
                      queEjecuta,
                      SYSDATE,
                      SYSDATE,
                      psErrorD);

         COMMIT;
   END setTramiteAreaConc;

   PROCEDURE setTramiteGestion (pnGasto            INTEGER,
                                pcQueSolucion      VARCHAR2,
                                pnMontoAnticipo    NUMBER,
                                pcSolucTram        VARCHAR2,
                                pcQueProveedor     VARCHAR2,
                                pcQuienDeposita    VARCHAR2,
                                pnImpBase          NUMBER,
                                pnIva              NUMBER,
                                pnEsperado         NUMBER,
                                queEjecuta         VARCHAR2)
   IS
      queEmailGestor    VARCHAR2 (50) := '';
      queEmailTitular   INTEGER := 0;
      queelemento       INTEGER := 0;
      psErrorD          VARCHAR2 (4000) := '0';
      vsError           VARCHAR2 (4000) := '0';
      ImpComprobado     NUMBER (12, 2) := 0;
   BEGIN
      SELECT SUM (FNTOTAL)
        INTO ImpComprobado
        FROM FACTURACIONCOMPROBA
       WHERE IDGASTOMAIN = pnGasto;

      UPDATE FACTURATRAMITE
         SET FCTIPOSOLUCION = pcQueSolucion,
             FCTIPOPAGO =
                CASE
                   WHEN pcQueSolucion = 'INTERNO' THEN NULL
                   ELSE pcSolucTram
                END,
             FNMONTOANTICIPO = pnMontoAnticipo,
             FCPROVEEDOR =
                CASE
                   WHEN pcQueSolucion = 'INTERNO' THEN NULL
                   ELSE pcQueProveedor
                END,
             FCQUIENDEPOSITA =
                CASE
                   WHEN pcQueSolucion = 'INTERNO' THEN NULL
                   ELSE pcQuienDeposita
                END,
             FNMONTOCOMPROBADO = ImpComprobado
       WHERE IDGASTOMAIN = pnGasto;

      UPDATE FACTURACIONMAIN
         SET IDPROVEEDORGTO = pcQueProveedor
       WHERE IDGASTOMAIN = pnGasto;

      ---- INSERTA EL DETALLE DE LA TRANSACCION
      SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

      INSERT INTO BITACORATRANSACCION
           VALUES (pnGasto,
                   queelemento,
                   queEjecuta,
                   SYSDATE,
                   SYSDATE,
                   psErrorD);

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         vsError := SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('** ERROR ** ' || SQLERRM);
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

         INSERT INTO BITACORATRANSACCION
              VALUES (pnGasto,
                      queelemento,
                      queEjecuta,
                      SYSDATE,
                      SYSDATE,
                      psErrorD);

         COMMIT;
   END setTramiteGestion;

   PROCEDURE setResultAutorizacion (pnGasto          INTEGER,
                                    quienEs          VARCHAR2,
                                    queResultado     VARCHAR2,
                                    queComentario    VARCHAR2,
                                    queEjecuta       VARCHAR2,
                                    queindiceAut     INTEGER)
   IS
      CURSOR cuAutoriza
      IS
           SELECT *
             FROM FACTURACIONAUT
            WHERE     IDGASTOMAIN = pnGasto
                  AND IDDELINDEX = (SELECT MAX (IDDELINDEX)
                                      FROM FACTURACIONAUT
                                     WHERE IDGASTOMAIN = pnGasto)
         ORDER BY IDCONSEC ASC;

      queelemento   INTEGER := 0;
      psErrorD      VARCHAR2 (4000) := '0';
      vsError       VARCHAR2 (4000) := '0';
   BEGIN
      FOR regAutoriza IN cuAutoriza
      LOOP
         UPDATE FACTURACIONAUT
            SET FCRESULTADO =
                   CASE
                      WHEN regAutoriza.FCAUTORIZADOR = quienEs
                      THEN
                         queResultado
                      WHEN regAutoriza.FCAUTORIZADOR != quienEs
                      THEN
                         CASE
                            WHEN queResultado = 'Rechazado'
                            THEN
                               CASE
                                  WHEN FCRESULTADO IS NULL THEN '----------'
                                  ELSE FCRESULTADO
                               END
                            ELSE
                               FCRESULTADO
                         END
                   END,
                FCCOMENTARIO02 =
                   CASE
                      WHEN regAutoriza.FCAUTORIZADOR = quienEs
                      THEN
                         queComentario
                      WHEN regAutoriza.FCAUTORIZADOR != quienEs
                      THEN
                         CASE
                            WHEN queResultado = 'Rechazado'
                            THEN
                               CASE
                                  WHEN FCCOMENTARIO02 IS NULL
                                  THEN
                                     '------------------------'
                                  ELSE
                                     FCCOMENTARIO02
                               END
                            ELSE
                               FCCOMENTARIO02
                         END
                   END,
                FDFECAUTORIZA =
                   CASE
                      WHEN regAutoriza.FCAUTORIZADOR = quienEs
                      THEN
                         SYSDATE
                      WHEN regAutoriza.FCAUTORIZADOR != quienEs
                      THEN
                         CASE
                            WHEN FDFECAUTORIZA IS NOT NULL THEN FDFECAUTORIZA
                            ELSE NULL
                         END
                      ELSE
                         FDFECAUTORIZA
                   END,
                DELINDEX_AUTORIZA = queindiceAut
          WHERE     IDCONSEC = regAutoriza.IDCONSEC
                AND IDDELINDEX = regAutoriza.IDDELINDEX
                AND IDGASTOMAIN = pnGasto;
      END LOOP;

      ---- INSERTA EL DETALLE DE LA TRANSACCION
      SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

      INSERT INTO BITACORATRANSACCION
           VALUES (pnGasto,
                   queelemento,
                   queEjecuta,
                   SYSDATE,
                   SYSDATE,
                   psErrorD);

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         vsError := SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('** ERROR ** ' || SQLERRM);
         ROLLBACK;
         psErrorD := SUBSTR (SQLERRM, 1, 490);

         SELECT SEQTRANSACCION.NEXTVAL INTO queelemento FROM DUAL;

         INSERT INTO BITACORATRANSACCION
              VALUES (pnGasto,
                      queelemento,
                      queEjecuta,
                      SYSDATE,
                      SYSDATE,
                      psErrorD);

         COMMIT;
   END setResultAutorizacion;

   PROCEDURE getMisConceptos (quienEs VARCHAR2, externo VARCHAR2, salida IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa      T_CURSOR;
      quePuesto    VARCHAR2 (100) := '';
      cadEjecuta   VARCHAR2 (4000) := '';
   BEGIN
      -- obtiene el puesto del solicitante
      IF externo = '1' THEN
      quePuesto:= '317';
      ELSE
      SELECT "cvepue"
        INTO quePuesto
        FROM PENDUPM.VISTAASOCIADOS
       WHERE "cvetra" = quienEs;
    END IF;

      cadEjecuta :=
            'SELECT IDCONCEPTO, NMCONCEPTO
                     FROM CTCATALOGOCUENTAS A
                    WHERE FCPUESTOGASTO LIKE ''%'
         || quePuesto
         || '%''
                      AND FCSTATUS = ''A'' AND APLICAPROCESO = ''S''
                   ORDER BY 2';
      DBMS_OUTPUT.PUT_LINE ('** es la cadena ** ' || cadEjecuta);

      OPEN procesa FOR cadEjecuta;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getMisConceptos;

   PROCEDURE getObtenPagodoble (pnSolicitud          INTEGER,
                                pnConcepto           NUMBER,
                                psCredito            VARCHAR2,
                                salida        IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa            T_CURSOR;
      psCadenaCarteras   VARCHAR2 (4000) := '';
      existe             INTEGER := 0;
      idDynamics         VARCHAR2 (30) := '';
      pnPagoDoble        NUMBER (5) := 0;
      psCuentaContable   VARCHAR2 (30) := '';
      psIdDynamics       VARCHAR2 (30) := '';
   BEGIN
      SELECT FCCUENTACONTABLE
        INTO psCuentaContable
        FROM CTCATALOGOCUENTAS
       WHERE IDCONCEPTO = pnConcepto;

      SELECT FCDYNAMICS
        INTO psIdDynamics
        FROM CTCREDITODYNAMICS
       WHERE FCCREDITO = psCredito;

      OPEN procesa FOR
         SELECT 1 IND, CREDITO_CYBER CREDITO,
                'DYNAMICS' ORIGEN,      CREDITO_CYBER ProjectID,    ID_GASTO IDHISTORICO,
                CUENTA_CONTABLE,        CONCEPTO,                   PCKCTRLDOCUMENTAL01.aplFecha (FECHA_DE_PAGO,'2') FECHA_DE_PAGO,
                PROVEEDOR,              POLIZA,                     FACTURA,
                PCKCONVENIOS.formatComas(MONTO_TOTAL ) MONTO_TOTAL
           FROM BI_DIMGASTOS@PENDUBI.COM
          WHERE CREDITO_CYBER = psCredito
            AND CUENTA_CONTABLE = psCuentaContable
            AND (PROVEEDOR IS NULL OR PROVEEDOR NOT LIKE '%PENDULUM%')
            AND TO_NUMBER(NVL(NUMERO_CASO,0)) NOT IN ( 
                         SELECT B.IDGASTOMAIN 
                           FROM PENDUPM.FACTURAASIGNACION A 
                     INNER JOIN PENDUPM.FACTURACIONMAIN B ON ( A.IDGASTOMAIN = B.IDGASTOMAIN AND A.IDCONCEPTO = B.IDCONCEPTO) 
                          WHERE     A.IDGASTOMAIN != pnSolicitud AND FCCREDITOCARTERA = psCredito AND FCSTATUS NOT IN ( 'Z','R') 
                                AND FCCUENTACONTABLE = psCuentaContable AND A.STATUS = 'A'
                  )
       UNION ALL
        SELECT 2 IND,
               'PM' ORIGEN,  FCCREDITOCARTERA  CREDITO,
               A.FCDYNAMICS ProjectID,
               A.IDGASTOMAIN IDHISTORICO,
               FCCUENTACONTABLE CUENTA_CONTABLE,
               (SELECT NMCONCEPTO
                  FROM CTCATALOGOCUENTAS C
                 WHERE A.IDCONCEPTO = C.IDCONCEPTO)
                  CONCEPTO,
               PCKCTRLDOCUMENTAL01.aplFecha (B.FDFECREGISTRO, '2') FECHA_DE_PAGO,
               NVL(B.NMPROVEEDOR,'--SIN PROVEEDOR...') PROVEEDOR,
               '0' POLIZA, '0' FACTURA,
               PCKCONVENIOS.formatComas(FNIMPORTE)  MONTO_TOTAL
          FROM FACTURAASIGNACION A
               INNER JOIN FACTURACIONMAIN B
                  ON (    A.IDGASTOMAIN = B.IDGASTOMAIN
                      AND A.IDCONCEPTO = B.IDCONCEPTO)
         WHERE FCCREDITOCARTERA = psCredito
               AND FCSTATUS NOT IN ('Z', 'R', 'F')
               AND FCCUENTACONTABLE = psCuentaContable
        ORDER BY 1 ASC;

--         SELECT 1 IND,
--                'DYNAMICS' ORIGEN,
--                "ProjectID",
--                "Id" CVECONTROL,
--                "Name" NOMBRE,
--                "RefNbr" FOLIO,
--                "TranDesc" CONCEPTO,
--                PCKCTRLDOCUMENTAL01.aplFecha ("TranDate", 2) FECHAMOVTO,
--                "DrAmt" IMPORTE,
--                "TranDate" FECHA
--           FROM GLTRAN@erpbase.com gl, Vendor@erpbase.com xv
--          WHERE     "VendId" = "Id"
--                AND "Acct" = '6010050325'
--                AND "ProjectID" = 'PQ03000008021652'
--         UNION ALL
--         SELECT 2 ind, FCCREDITOCARTERA CREDITO,
--                'PM' ORIGEN,
--                A.FCDYNAMICS ProjectID,
--                TO_CHAR (FNNUMEMPLEADO) CVECONTROL,
--                (SELECT "nombreCompleto"
--                   from pendupm.vistaasociadoscompleta
--                  WHERE "cvetra" = B.FNNUMEMPLEADO)
--                   NOMBRE,
--                TO_CHAR (B.IDGASTOMAIN) FOLIO,
--                (SELECT NMCONCEPTO
--                   FROM CTCATALOGOCUENTAS C
--                  WHERE A.IDCONCEPTO = C.IDCONCEPTO)
--                   CONCEPTO,
--                PCKCTRLDOCUMENTAL01.aplFecha (B.FDFECREGISTRO, 2) FECHAMOVTO,
--                FNIMPORTE IMPORTE,
--                B.FDFECREGISTRO FECHA
--           FROM FACTURAASIGNACION A
--                INNER JOIN FACTURACIONMAIN B
--                   ON (    A.IDGASTOMAIN = B.IDGASTOMAIN
--                       AND A.IDCONCEPTO = B.IDCONCEPTO)
--          WHERE     FCCREDITOCARTERA = '42002728'
--                AND FCSTATUS NOT IN ('Z', 'R', 'F')
--         ORDER BY 1;


      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         OPEN procesa FOR SELECT 'ERROR' QUEPASO FROM DUAL;

         salida := procesa;
   END getObtenPagodoble;

   PROCEDURE setCancfTransAnticipo (psGastos         VARCHAR2, /* CADENA DE IDGASTO SEPARADO POR PIPES */
                                    usuSolic         VARCHAR2,
                                    psFecReprog      VARCHAR2,  /* DD/MM/YYYY */
                                    psError      OUT VARCHAR2,
                                    psEmpresaFact    VARCHAR2)
   IS
      ubica        INTEGER := 0;
      ubicaCred    INTEGER := 0;
      valor        VARCHAR2 (20) := '';
      cadena       VARCHAR2 (4000) := psGastos;
      cadena1      VARCHAR2 (4000) := psGastos;
      DeRR         VARCHAR2 (4000) := psGastos;
      laFechaProg  DATE    := TO_DATE(psFecReprog,'DD/MM/YYYY');
      laFechaAnt   DATE    := SYSDATE;
      psApp        VARCHAR2 (40) := '';
      psTask       VARCHAR2 (40) := '';
      psIndex      INTEGER := 0;
      queUsuEs     VARCHAR2 (50) := '';
      queTipoEs    VARCHAR2 (50) := '';
      pstipoPago   INTEGER := 0;
   BEGIN
      psError := '0';
      ubica := INSTR (cadena1, '|');

      WHILE (ubica > 0)
      LOOP
         valor := SUBSTR (cadena1, 1, ubica - 1);


         SELECT CASE WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'AN'
                     WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '656925561529384c6847c88021053266' THEN 'RE'
                     WHEN TPOMOVIMIENTO = 'Reembolso' AND ETAPA = '656925561529384c6847c88021053266' THEN 'RE'
                     WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'AN'
                     WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '656925561529384c6847c88021053266' THEN 'RE'
                END TIPOMOVTO,IDFORMAPAGO
         INTO queTipoEs, pstipoPago
         FROM (
         SELECT DISTINCT IDGASTOMAIN,
                         (SELECT IDTASKGASTO
                            FROM FACTURACIONBITACORA XX
                           WHERE XX.IDGASTOMAIN = A.IDGASTOMAIN
                             AND xx.DEL_INDEX = (SELECT MAX(DEL_INDEX)
                                                   FROM FACTURACIONBITACORA DD
                                                  WHERE XX.IDGASTOMAIN = DD.IDGASTOMAIN
                                                )
                          ) ETAPA   ,
                          TPOMOVIMIENTO,
                          IDFORMAPAGO
           FROM FACTURACIONMAIN A
          WHERE A.IDGASTOMAIN = valor
          AND CASE
                 WHEN (   IDEMPRESAFACTURACION = 0
                       OR IDEMPRESAFACTURACION IS NULL)
                 THEN
                    A.IDOTEMPRESAFACTURACION
                 WHEN (   IDEMPRESAFACTURACION != 0
                       OR IDEMPRESAFACTURACION IS NOT NULL)
                 THEN
                    A.IDEMPRESAFACTURACION
              END = psEmpresaFact
              );

            DBMS_OUTPUT.PUT_LINE ('****inicio');

         SELECT APP_UID, IDTASKGASTO, DEL_INDEX
           INTO psApp, psTask, psIndex
           FROM FACTURACIONBITACORA X
          WHERE     X.IDGASTOMAIN = valor
                AND X.DEL_INDEX = (SELECT MAX (DEL_INDEX)
                                     FROM FACTURACIONBITACORA P
                                    WHERE P.IDGASTOMAIN = valor);
            DBMS_OUTPUT.PUT_LINE ('****dos');


            DBMS_OUTPUT.PUT_LINE ('****dos y pedacito***'||valor||'---'||queTipoEs);

         SELECT FDFECPARAPAGO INTO laFechaAnt FROM FACTURACIONPAGOS WHERE IDGASTOMAIN = valor
             AND FNCONSEC = CASE WHEN queTipoEs = 'RE' THEN 6 ELSE 2 END;

            DBMS_OUTPUT.PUT_LINE ('****dos y medio');

         UPDATE FACTURACIONPAGOS SET FDFECPAGADO = NULL, IDUSUARIO = NULL, FDFECPARAPAGO = laFechaProg
           WHERE IDGASTOMAIN = valor
             AND FNCONSEC = CASE WHEN queTipoEs = 'RE' THEN 6 ELSE 2 END;

            DBMS_OUTPUT.PUT_LINE ('****tres');

         UPDATE FACTURACIONMAIN
            SET FCSTATUS = CASE WHEN queTipoEs = 'RE' THEN 'D' ELSE 'D' END,
                FDFECTERMINO = CASE WHEN queTipoEs = 'RE' THEN NULL END,
                FDDYNAMICSREEMB = CASE WHEN queTipoEs = 'RE' THEN NULL END,
                FDDYNAMICSREEMBCONF =
                   CASE WHEN queTipoEs = 'RE' THEN NULL END,
                FDDYNAMICSGASTOCONF =
                   CASE
                      WHEN IDFORMAPAGO = 36 AND FNIMPORTEANTICIPO > 0  THEN
                         NULL
                      ELSE
                         NULL
                   END,
                FDDYNAMICSGASTO = CASE WHEN queTipoEs = 'AN' THEN NULL END,
                FCUSUCONF = NULL
          WHERE IDGASTOMAIN = valor;

         IF (queTipoEs = 'RE')
         THEN
            UPDATE FACTURACIONMAIN
               SET FCSTATUS = 'D'
             WHERE IDGASTOMAIN = valor;
         END IF;

         UPDATE FACTURACIONDEPOSITO
            SET FDFECDERIVACION = NULL,
                FCREFERENCIA = CASE WHEN queTipoEs != 'RE' THEN NULL END,
                FCSTATUS = 'C', FDFECCANCELADA= laFechaAnt , FDFECSTATUS = SYSDATE, IDUSUARIOCANCELA = usuSolic
          WHERE IDGASTOMAIN = valor
             AND FCSTATUS = 'A'
             AND FNCONSEC = CASE WHEN queTipoEs = 'RE' THEN 6 ELSE 2 END;

         UPDATE FACTURACIONBITACORA
            SET FCRESULTADO =
                   CASE WHEN (pstipoPago = 36) THEN 'ENVIADO' END,
                FCCOMENTARIOS =
                   CASE
                      WHEN (pstipoPago = 36)
                      THEN 'SE REPROGRAMO EL PAGO '
                   END,
                FDFECREGISTRO = NULL,
                FCUSUARIO = NULL
          WHERE     IDGASTOMAIN = valor
                AND APP_UID = psApp
                AND IDTASKGASTO = psTask
                AND DEL_INDEX = psIndex;

         SELECT FCUSUARIO
           INTO queUsuEs
           FROM FACTURACIONBITACORA
          WHERE IDGASTOMAIN = valor AND APP_UID = psApp AND DEL_INDEX = 1;

         cadena1 := SUBSTR (cadena1, ubica + 1);
         ubica := INSTR (cadena1, '|');
      END LOOP;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         DeRR := SQLERRM;
         psError := '-1 setCancfTransAnticipo **' || DeRR;
   END setCancfTransAnticipo;

   PROCEDURE getCuentasEmpresa (pnEmpresa INTEGER, salida IN OUT T_CURSOR)   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa      T_CURSOR;
      quePuesto    VARCHAR2 (100) := '';
      cadEjecuta   VARCHAR2 (4000) := '';
   BEGIN

      OPEN procesa FOR
          SELECT FCCUENTA,FCCUENTA FCCUENTA
            FROM EMPFACTURADETALLE
           WHERE IDEMPRESA = pnEmpresa AND FCSTATUS = 'A';

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getCuentasEmpresa;

   PROCEDURE getFolCtrlTesoDia(laFechaEs           VARCHAR2,
                               queEmpresaFact      VARCHAR2,
                               salida       IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa           T_CURSOR;
      fdFechaOperaIni   DATE := TO_DATE (laFechaEs, 'DD/MM/YYYY');
      fdFechaOperaFin   DATE := TO_DATE (laFechaEs || ' 23:59', 'DD/MM/YYYY HH24:MI');
      quienOpero        VARCHAR2(100) := '';

   BEGIN

      OPEN procesa FOR
          SELECT DISTINCT FNNUMARCHCONTROL
             FROM FACTURACIONDEPOSITO MAIN
            WHERE FDFECDERIVACION BETWEEN fdFechaOperaIni-15 AND fdFechaOperaFin
              AND  FCSTATUS = 'A'
              AND IDEMPRESA = queEmpresaFact
              AND FCTIPODEPOSITO =  36
         ORDER BY FNNUMARCHCONTROL;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getFolCtrlTesoDia;

   PROCEDURE getFolCtrlPagoCie(laFechaEs           VARCHAR2,
                               queEmpresaFact      VARCHAR2,
                               salida       IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;

      procesa           T_CURSOR;
      fdFechaOperaIni   DATE := TO_DATE (laFechaEs, 'DD/MM/YYYY');
      fdFechaOperaFin   DATE := TO_DATE (laFechaEs || ' 23:59', 'DD/MM/YYYY HH24:MI');
      quienOpero        VARCHAR2(100) := '';

   BEGIN

      OPEN procesa FOR
          SELECT DISTINCT FNNUMARCHCONTROL
             FROM FACTURACIONDEPOSITO MAIN
            WHERE FDFECDERIVACION BETWEEN fdFechaOperaIni-15 AND fdFechaOperaFin
              AND  FCSTATUS = 'A'
              AND IDEMPRESA = queEmpresaFact
              AND FCTIPODEPOSITO =  40
         ORDER BY FNNUMARCHCONTROL;

      salida := procesa;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getFolCtrlPagoCie;

   PROCEDURE getMisJuicios( quienEs VARCHAR2,
                          salida  IN OUT T_CURSOR )
    IS
      TYPE T_CURSOR IS REF CURSOR;
      procesa           T_CURSOR;

    BEGIN
      OPEN procesa FOR
        SELECT   CASE.CECASENO || ' - ' || CASEACCT.CCACCT credito_juicio,
           CASEACCT.CCACCT credito,
           CASE.CECASENO juicio,
           CASE.CESTATUS estatus_juicio,
           CASE.CEEXTLWYR cve_externo,
           CASE.CENAME ACREDITADO,
           CASE.CESUPVLWYR cve_supervisor,
           USR_SUPERVISOR.CLNAME nombre_supervisor,
           USR_SUPERVISOR.CLMAIL mail_supervisor,
           USR_SUPERVISOR.CLIDNUM num_emp_supervisor,
           USR_SUPERVISOR.CLSTATUS estatus_supervisor
        FROM   RCVRY.CASE,
           RCVRY.CASEACCT,
           RCVRY.COLLID USR_EXTERNO,
           RCVRY.COLLID USR_SUPERVISOR
        WHERE   (CASE.CECASENO = CASEACCT.CCCASENO)
           AND (USR_EXTERNO.CLCOLLID = CASE.CEEXTLWYR)
           AND (USR_SUPERVISOR.CLCOLLID = CASE.CESUPVLWYR)
           AND CESTATUS != 'C';


    salida := procesa;
     EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getMisJuicios;

   PROCEDURE getInfoJuicio( idJuicio VARCHAR2,
                          salida  IN OUT T_CURSOR )
    IS
      TYPE T_CURSOR IS REF CURSOR;
      procesa           T_CURSOR;

    BEGIN
      OPEN procesa FOR
        SELECT CASEACCT.CCACCT credito,
           CASE.CECASENO juicio,
           CASE.CESTATUS estatus_juicio,
           CASE.CEEXTLWYR cve_externo,
           CASE.CENAME ACREDITADO,
           CASE.CESUPVLWYR cve_supervisor,
           USR_SUPERVISOR.CLNAME nombre_supervisor,
           USR_SUPERVISOR.CLMAIL mail_supervisor,
           USR_SUPERVISOR.CLIDNUM num_emp_supervisor,
           USR_SUPERVISOR.CLSTATUS estatus_supervisor,
           TD.DESCRIPCION TIPO_JUICIO
        FROM RCVRY.CASE LEFT OUTER JOIN OPERACION.ELP_JUICIO JUICIO ON CASE.CECASENO = JUICIO.NUMERO
                        INNER JOIN RCVRY.CASEACCT ON CASE.CECASENO = CASEACCT.CCCASENO
                        INNER JOIN RCVRY.COLLID USR_EXTERNO ON USR_EXTERNO.CLCOLLID = CASE.CEEXTLWYR
                        INNER JOIN RCVRY.COLLID USR_SUPERVISOR ON USR_SUPERVISOR.CLCOLLID = CASE.CESUPVLWYR
                        LEFT OUTER JOIN OPERACION.CAT_TIPO_DEMANDA TD ON JUICIO.ID_TIPO_DEMANDA = TD.ID_TIPO_DEMANDA
        WHERE CASE.CECASENO = idJuicio;

    salida := procesa;
     EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
    END getInfoJuicio;

    PROCEDURE setSupervisorByExterno (solicitudId VARCHAR2,
                                      mailSuper   VARCHAR2,
                                      idSuper     VARCHAR2,
                                      empleadoId  VARCHAR2,
                                      credito     VARCHAR2,
                                      salida      IN OUT T_CURSOR)
    IS
      TYPE T_CURSOR IS REF CURSOR;
      procesa           T_CURSOR;
      contador          INTEGER :=0 ;
      contadorExt       INTEGER :=0 ;

    BEGIN

      OPEN procesa FOR
        SELECT IDGASTOMAIN FROM PENDUPM.FACTURACIONAUT WHERE IDGASTOMAIN = solicitudId;

        SELECT (COUNT(1)+1) CONTA INTO contador FROM PENDUPM.FACTURACIONAUT WHERE IDGASTOMAIN = solicitudId;

        SELECT (COUNT(1)) CONTA INTO contadorExt FROM PENDUPM.FACTURACIONAUT WHERE IDTIPOAUTORIZA=50 AND IDGASTOMAIN = solicitudId;

        IF contadorExt=0 THEN

        INSERT INTO FACTURACIONAUT
        VALUES ( solicitudId, mailSuper, 50,
            contador, credito, SYSDATE,
            NULL, empleadoId, SYSDATE,
            idSuper, NULL, NULL,
            '974392365525c7af897e890053564163', 1, NULL, NULL );

        END IF;

    COMMIT;
    salida := procesa;
     EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END setSupervisorByExterno;

   PROCEDURE reasignaAutorizador ( appuid   VARCHAR2,
                                   tasuid   VARCHAR2,
                                   newuser  VARCHAR2,
                                   salida       IN OUT T_CURSOR)
   IS
      TYPE T_CURSOR IS REF CURSOR;
      procesa         T_CURSOR;
      idgasto         INTEGER := '';
      olduser         VARCHAR2(50) := '';
      oldnumero       INTEGER :=0 ;
      newnumero       INTEGER :=0 ;
      newuserTe       VARCHAR2(50) := '';

      CURSOR cuCualesAsig(gastoId INTEGER)
      IS
         SELECT FCCREDITOCARTERA,FCUSUJFEINMED,   FCUSUUMBRAL03,    FCUSUUMBRAL04,   FCUSUUMBRAL05,
                FCUSUETAPA01,    FCUSUETAPA02,    FCUSUPGODBL01,    FCUSUPGODBL02,   FCUSUEMPRESA,
                FCUSUURGENTE,    FCUSUPM,         FCUSUNOFACT,      FCUSUEXCGASTO01, FCUSUEXCGASTO02,
                FCUSUETAFINAL01, FCUSUETAFINAL02, FCUSULIQUIDADO01, FCUSULIQUIDADO02
         FROM PENDUPM.FACTURAASIGNACION
         WHERE IDGASTOMAIN = gastoId;

    BEGIN
        SELECT IDGASTOMAIN,FCUSUARIO
        INTO idgasto,olduser
        FROM PENDUPM.FACTURACIONBITACORA
        WHERE APP_UID = appuid AND IDTASKGASTO = tasuid
                AND FCRESULTADO IS NULL;

        SELECT "cvetra"
        INTO oldnumero
        FROM PENDUPM.VISTAASOCIADOSCOMPLETA
        WHERE "email" = olduser;

        SELECT "cvetra","email"
        INTO newnumero,newuserTe
        FROM PENDUPM.VISTAASOCIADOS
        WHERE "email" = newuser;

        DBMS_OUTPUT.PUT_LINE ('gasto '||idgasto);
        DBMS_OUTPUT.PUT_LINE ('oldmail '||olduser);
        DBMS_OUTPUT.PUT_LINE ('oldcvetra '||oldnumero);
        DBMS_OUTPUT.PUT_LINE ('newuserTe '||newuserTe);

        UPDATE PENDUPM.FACTURACIONAUT
        SET FCAUTORIZADOR = newuser, FCUSUARIOAUTORIZA =  newnumero
        WHERE IDGASTOMAIN = idgasto AND FCRESULTADO IS NULL
                AND FCAUTORIZADOR = olduser;
                --AND FCAUTORIZADOR = olduser AND FCUSUARIOAUTORIZA = oldnumero;
        COMMIT;

        FOR regConc IN cuCualesAsig ( idgasto )
         LOOP
            IF ( regConc.FCUSUJFEINMED = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUJFEINMED = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUJFEINMED = oldnumero;
            END IF;

            IF ( regConc.FCUSUUMBRAL03 = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUUMBRAL03 = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUUMBRAL03 = oldnumero;
            END IF;

            IF ( regConc.FCUSUUMBRAL04 = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUUMBRAL04 = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUUMBRAL04 = oldnumero;
            END IF;

            IF ( regConc.FCUSUUMBRAL05 = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUUMBRAL05 = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUUMBRAL05 = oldnumero;
            END IF;

            IF ( regConc.FCUSUETAPA01 = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUETAPA01 = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUETAPA01 = oldnumero;
            END IF;

            IF ( regConc.FCUSUETAPA02 = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUETAPA02 = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUETAPA02 = oldnumero;
            END IF;

            IF ( regConc.FCUSUPGODBL01 = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUPGODBL01 = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUPGODBL01 = oldnumero;
            END IF;

            IF ( regConc.FCUSUPGODBL02 = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUPGODBL02 = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUPGODBL02 = oldnumero;
            END IF;

            IF ( regConc.FCUSUEMPRESA = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUEMPRESA = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUEMPRESA = oldnumero;
            END IF;

            IF ( regConc.FCUSUPGODBL01 = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUPGODBL01 = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUPGODBL01 = oldnumero;
            END IF;

            IF ( regConc.FCUSUURGENTE = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUURGENTE = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUURGENTE = oldnumero;
            END IF;

            IF ( regConc.FCUSUPM = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUPM = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUPM = oldnumero;
            END IF;

            IF ( regConc.FCUSUNOFACT = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUNOFACT = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUNOFACT = oldnumero;
            END IF;

            IF ( regConc.FCUSUEXCGASTO01 = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUEXCGASTO01 = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUEXCGASTO01 = oldnumero;
            END IF;

            IF ( regConc.FCUSUEXCGASTO02 = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUEXCGASTO02 = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUEXCGASTO02 = oldnumero;
            END IF;

            IF ( regConc.FCUSUETAFINAL01 = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUETAFINAL01 = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUETAFINAL01 = oldnumero;
            END IF;

            IF ( regConc.FCUSUETAFINAL02 = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSUETAFINAL02 = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSUETAFINAL02 = oldnumero;
            END IF;

            IF ( regConc.FCUSULIQUIDADO01 = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSULIQUIDADO01 = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSULIQUIDADO01 = oldnumero;
            END IF;

            IF ( regConc.FCUSULIQUIDADO02 = oldnumero ) THEN
               UPDATE PENDUPM.FACTURAASIGNACION
               SET FCUSULIQUIDADO02 = newnumero
               WHERE IDGASTOMAIN = idgasto AND FCCREDITOCARTERA = regConc.FCCREDITOCARTERA AND FCUSULIQUIDADO02 = oldnumero;
            END IF;

         END LOOP;

         UPDATE PENDUPM.FACTURACIONBITACORA SET FCUSUARIO = newuser
         WHERE IDGASTOMAIN = idgasto AND APP_UID = appuid AND IDTASKGASTO = tasuid AND FCRESULTADO IS NULL;
         COMMIT;

        OPEN procesa FOR
          SELECT IDGASTOMAIN FROM PENDUPM.FACTURACIONAUT WHERE IDGASTOMAIN = idgasto;

        COMMIT;
     salida := procesa;
     EXCEPTION
      WHEN OTHERS
      THEN
         NULL;

   END reasignaAutorizador;



   PROCEDURE addCreditoAsignacion (pnSolicitud        INTEGER,
                               psCredito          VARCHAR2,
                               pnConcepto         NUMBER,
                               psQueTramite       VARCHAR2,
                               pnImporte          NUMBER,
                               psTipomovto        INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL */
                               quienSolic         INTEGER,
                               queUsuPM           VARCHAR2,
                               psAPPUID           VARCHAR2,
                               psFechaPgoIni      VARCHAR2,
                               psFechaPgoFin      VARCHAR2,
                               psError        OUT VARCHAR2)
   IS
      quePaso       VARCHAR2 (4000) := '';
      quePasoConc   VARCHAR2 (4000) := '';
   BEGIN
      psError := '0';
      
      --DBMS_OUTPUT.PUT_LINE ('INICIA');
      
      PCKFACTURACIONGASTO.addNuevoConceptoGasto (pnSolicitud,
                                            pnConcepto,
                                            psQueTramite,
                                            quienSolic,
                                            queUsuPM,
                                            psTipomovto,
                                            psAPPUID,
                                            quePasoConc);


     DBMS_OUTPUT.PUT_LINE ('QUE REGRESO  ' || quePasoConc);

      IF (quePasoConc = '0')
      THEN
          quePaso := '0';
         PCKFACTURACIONGASTO.validaNuevoCreditoAsigna (pnSolicitud,
                                                  psCredito,
                                                  pnConcepto,
                                                  pnImporte,
                                                  psTipomovto,
                                                  NULL,
                                                  psFechaPgoIni,
                                                  psFechaPgoFin,
                                                  quienSolic,
                                                  quePaso);

         IF (quePaso != '0')
         THEN
            ROLLBACK;
            psError := quePaso;
         ELSE
            COMMIT;
            psError := '0';
         END IF;
      ELSE
         psError := quePasoConc;
         ROLLBACK;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         psError := '**ERROR** ' || SQLERRM;
         DBMS_OUTPUT.PUT_LINE ('-1 ' || SQLERRM);
   END addCreditoAsignacion;


   PROCEDURE addNuevoConceptoGasto (pnCaso             INTEGER,
                               pnconcepto         INTEGER,
                               psQueTramite       VARCHAR2,
                               quienSolic         INTEGER,
                               queUsuPM           VARCHAR2,
                               quetipoEs          VARCHAR2,
                               psAPPUID           VARCHAR2,
                               psSalida       OUT VARCHAR2)
   IS
      vsExiste           INTEGER := 0;
      vsExiste1          INTEGER := 0;
      vnsucursal         INTEGER := 0;
      queelemento        INTEGER := 0;
      numConsec          INTEGER := 0;
      queHistorico       INTEGER := 0;
      vnHayUno           INTEGER := 0;
      esConcepto         INTEGER := 0;
      esIgual            INTEGER := 0;
      queTpoTram         VARCHAR2 (50) := '';
      hayOtros           INTEGER := 0;
      esImpFacturado     VARCHAR2 (3) := '';
      esCuentaContable   VARCHAR2 (30) := '';
      otroTiposolic      INTEGER := 0;
      esTpoSolicAct      VARCHAR2 (30) := '';
      queSucursal        VARCHAR2 (30) := '';

      CURSOR cuPrimero (queConc INTEGER)
      IS
         SELECT *
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = queConc;

      CURSOR cuSegundo (queConc INTEGER)
      IS
         SELECT *
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = queConc;

   BEGIN
      psSalida := '0';

      SELECT FCCUENTACONTABLE
        INTO esCuentaContable
        FROM CTCATALOGOCUENTAS
       WHERE IDCONCEPTO = pnconcepto;

      SELECT COUNT (1)
        INTO vsExiste
        FROM FACTURACIONMAIN
       WHERE IDGASTOMAIN = pnCaso AND IDCONCEPTO = pnconcepto;

      SELECT COUNT (1), MAX (IDCONCEPTO), MAX (TPOMOVIMIENTO)
        INTO vnHayUno, esConcepto, queTpoTram
        FROM FACTURACIONMAIN
       WHERE     IDGASTOMAIN = pnCaso
             AND FDFECREGISTRO = (SELECT MIN (FDFECREGISTRO)
                                    FROM FACTURACIONMAIN
                                   WHERE IDGASTOMAIN = pnCaso);

      BEGIN
         SELECT NVL (FCIMPFACTTRAMITE, 'N')
           INTO esImpFacturado
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = esConcepto;
      EXCEPTION
         WHEN OTHERS
         THEN
            esImpFacturado := 'N';
      END;

      BEGIN
         SELECT "cveUbicacion"
           INTO queSucursal
           FROM PENDUPM.VISTAASOCIADOS
          WHERE "cvetra" = quienSolic;
      EXCEPTION
         WHEN OTHERS
         THEN
            queSucursal := '001';
      END;

      SELECT COUNT (1)
        INTO hayOtros
        FROM FACTURAGASTO
       WHERE IDGASTOMAIN = pnCaso;

      IF (hayOtros = 0)
      THEN
         INSERT INTO FACTURAGASTO
              VALUES (pnCaso,
                      SYSDATE,
                      NULL,
                      psAPPUID,
                      quienSolic);
      ELSE
         UPDATE FACTURAGASTO
            SET FCUSUARIO = quienSolic
          WHERE IDGASTOMAIN = pnCaso;
      END IF;

      BEGIN
         SELECT IDSUCURSAL
           INTO vnsucursal
           FROM CTSUCURSALPENDULUM
          WHERE CVEUBICACION = queSucursal;
      EXCEPTION
         WHEN OTHERS
         THEN
            vnsucursal := NULL;
      END;

      BEGIN
         SELECT MAX (IDHISTORICO) CUALES
           INTO queHistorico
           FROM HISTORICOCATALCUENTAS
          WHERE IDCONCEPTO = pnconcepto;
      EXCEPTION
         WHEN OTHERS
         THEN

            INSERT INTO HISTORICOCATALCUENTAS
               SELECT SEQHISTCATCTAS.NEXTVAL, A.*
                 FROM CTCATALOGOCUENTAS A
                WHERE IDCONCEPTO = pnconcepto;

            SELECT MAX (IDHISTORICO) CUALES
              INTO queHistorico
              FROM HISTORICOCATALCUENTAS
             WHERE IDCONCEPTO = pnconcepto;
      END;

      IF (queHistorico IS NULL)
      THEN

         INSERT INTO HISTORICOCATALCUENTAS
            SELECT SEQHISTCATCTAS.NEXTVAL, A.*
              FROM CTCATALOGOCUENTAS A
             WHERE IDCONCEPTO = pnconcepto;

         SELECT MAX (IDHISTORICO) CUALES
           INTO queHistorico
           FROM HISTORICOCATALCUENTAS
          WHERE IDCONCEPTO = pnconcepto;
      END IF;

      ---  Verifica que el Concepto no exista en la solicitud
      IF (vsExiste = 0)
      THEN

         SELECT COUNT (1)
           INTO otroTiposolic
           FROM FACTURACIONMAIN
          WHERE     IDGASTOMAIN = pnCaso
                AND UPPER (TPOMOVIMIENTO) != UPPER (psQueTramite);

         BEGIN
            SELECT DISTINCT TPOMOVIMIENTO
              INTO esTpoSolicAct
              FROM FACTURACIONMAIN
             WHERE IDGASTOMAIN = pnCaso;
         EXCEPTION
            WHEN OTHERS
            THEN
               esTpoSolicAct := 0;
         END;

         IF (otroTiposolic = 0)
         THEN
            ---- so ya Existe un Concepto valida que sean Iguales en Configuracion
            IF (vnHayUno > 0)
            THEN
               esIgual := 0;
               psSalida := '0';

               FOR regValida IN cuPrimero (esConcepto)
               LOOP
                  FOR regActual IN cuSegundo (pnconcepto)
                  LOOP
                     IF (regValida.FCJEFEINMEDIATO != regActual.FCJEFEINMEDIATO)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion JEFE INMEDIATO NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCTIPOJEFEIN != regActual.FCTIPOJEFEIN)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion JEFE INMEDIATO TIPO AUTORIZADOR NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTMONTO01 != regActual.AUTMONTO01)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR MONTO 01 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTMONTO02 != regActual.AUTMONTO02)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR MONTO 02 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTMONTO03 != regActual.AUTMONTO03)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR MONTO 03 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTMONTO03A != regActual.AUTMONTO03A)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR MONTO 03A NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTMONTO03B != regActual.AUTMONTO03B)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR MONTO 03B NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTETAPA01 != regActual.AUTETAPA01)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR ETAPA 01 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTETAPA02 != regActual.AUTETAPA02)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR ETAPA 02 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTPGODBL01 != regActual.AUTPGODBL01)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR PAGO DOBLE 01 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.AUTPGODBL02 != regActual.AUTPGODBL02)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR PAGO DOBLE 02 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCVERIFFINAL01 !=
                               regActual.FCVERIFFINAL01)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR FINAL 01 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCVERIFFINAL02 !=
                               regActual.FCVERIFFINAL02)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR FINAL 02 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCVERIFFINAL03 !=
                               regActual.FCVERIFFINAL03)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZADOR FINAL 03 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCANTICIPO != regActual.FCANTICIPO)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion MARCA ANTICIPO NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCREEMBOLSO != regActual.FCREEMBOLSO)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion MARCA REEMBOLSO NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCTRAMITE != regActual.FCTRAMITE)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion MARCA TRAMITE NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCIMPFACTTRAMITE !=
                               regActual.FCIMPFACTTRAMITE)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion MARCA TRAMITE - FACTURACION NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.IDTITULARAREACONC !=
                               regActual.IDTITULARAREACONC)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion TITULAR AREA CONCENT NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (regValida.FCTITAREACONC !=
                               regActual.FCTITAREACONC)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion TITULAR AREA CONCENT NO es igual para esta Solicitud ';
                        EXIT;
                     ELSE
                        psSalida := '0';
                     END IF;

                     IF (regValida.FCREQNOFACT != regActual.FCREQNOFACT)
                     THEN
                        psSalida :=
                           '*ALERTA* La Configuracion AUTORIZA NO FACTURABLE NO es igual para esta Solicitud ';
                        EXIT;
                     ELSE
                        IF (regValida.FCREQNOFACT = 'S' )
                        THEN
                            IF (   regValida.IDREQNOFACT1 != regActual.IDREQNOFACT1 OR regValida.FCTIPONOFACT1 != regActual.FCTIPONOFACT1
                                OR regValida.IDREQNOFACT2 != regActual.IDREQNOFACT2 OR regValida.FCTIPONOFACT2 != regActual.FCTIPONOFACT2 OR regValida.FCNOMBRENOFACT2 != regActual.FCNOMBRENOFACT2 )
                            THEN
                                psSalida :=
                                '*ALERTA* La Configuracion AUTORIZA NO FACTURABLE NO es igual para esta Solicitud, autorizadores ';
                            ELSE
                                psSalida := '0';
                            END IF;

                        ELSE
                            psSalida := '0';
                        END IF;

                     END IF;

                  END LOOP;
               END LOOP;
            END IF;

            ---- si no hay diferencias en Catalogo Agrega elConcepto
            IF (psSalida = '0')
            THEN
               psSalida := '0';

               INSERT INTO FACTURACIONMAIN (IDGASTOMAIN,
                                            IDCONCEPTO,
                                            IDPROCESO,
                                            FDFECREGISTRO,
                                            FNNUMEMPLEADO,
                                            IDSOLICITANTE,
                                            IDSUCURSAL,
                                            FCSTATUS,
                                            TPOMOVIMIENTO,
                                            APP_UID,
                                            IDHISTORICO,
                                            IDPROVEEDORGTO,
                                            FCCUENTACONTABLE,
                                            FCTRAMITEFACTURADO)
                    VALUES (pnCaso,
                            pnconcepto,
                            8,
                            SYSDATE,
                            quienSolic,
                            queUsuPM,
                            vnsucursal,
                            'R',
                            psQueTramite,
                            psAPPUID,
                            queHistorico,
                            NULL,
                            esCuentaContable,
                            esImpFacturado);

               IF (UPPER (queTpoTram) = 'TRAMITE')
               THEN
                  UPDATE FACTURACIONMAIN
                     SET FCTRAMITEFACTURADO = esImpFacturado
                   WHERE IDGASTOMAIN = pnCaso;
               END IF;
            --              ELSE
            --                  COMMIT;
            END IF;
         ELSE
            psSalida :=
                  '*ALERTA* NO se pueden Combinar Diferentes Tipos de Solicitud ['
               || esTpoSolicAct
               || '] Si desea Cambiarlo Elimine los Conceptos Existentes';
         END IF;
      ELSE
         SELECT COUNT (1)
           INTO otroTiposolic
           FROM FACTURACIONMAIN
          WHERE     IDGASTOMAIN = pnCaso
                AND UPPER (TPOMOVIMIENTO) != UPPER (psQueTramite);

         IF (otroTiposolic > 0)
         THEN
            BEGIN
               SELECT DISTINCT TPOMOVIMIENTO
                 INTO esTpoSolicAct
                 FROM FACTURACIONMAIN
                WHERE IDGASTOMAIN = pnCaso;
            EXCEPTION
               WHEN OTHERS
               THEN
                  esTpoSolicAct := 0;
            END;

            psSalida :=
                  '*ALERTA* NO se pueden Combinar Diferentes Tipos de Solicitud ['
               || esTpoSolicAct
               || '] Si desea Cambiarlo Elimine los Conceptos Existentes';
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         --     ROLLBACK;
         psSalida :=
            '*ERROR*' || pnCaso || '-' || pnconcepto || '-**' || SQLERRM;
         DBMS_OUTPUT.PUT_LINE (
               '*ERROR* '
            || pnCaso
            || '-'
            || pnconcepto
            || '-'
            || '8'
            || '-**'
            || SQLERRM);
   END addNuevoConceptoGasto;



   PROCEDURE validaNuevoCreditoAsigna (pnSolicitud         INTEGER,
                                  psCredito           VARCHAR2, /* SI  es psTipomovto = 4 [valor CARTERA]  psTipomovto = 42 [CONCEPTO ]*/
                                  pnConcepto          NUMBER,
                                  pnImporte           NUMBER,
                                  psTipomovto         INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL */
                                  psCentroCosto       VARCHAR2, /* Solo valido si es CArtera ? Importe General */
                                  psFechaPgoIni      VARCHAR2,
                                  psFechaPgoFin      VARCHAR2,
                                  quienSolic         INTEGER,
                                  psError         OUT VARCHAR2)
   IS
      queTipoJuicio      NUMBER (5) := '';
      queTipoDemanda     NUMBER (5) := '';
      queUmbralRebaso    NUMBER (10) := 0;
      queCodAccion       VARCHAR2 (1000) := 'N';
      queCodResultado    VARCHAR2 (1000) := 'N';
      quePagoDoble       NUMBER (10) := 0;
      queEtapaCRAVER     VARCHAR2 (2000) := '';
      queEtapaABTA       VARCHAR2 (2000) := '';
      queEtapaFinal      VARCHAR2 (20) := '';
      cuantosSon         INTEGER := 0;
      psQuery            VARCHAR2 (4000) := '';
      ubica              INTEGER := 0;
      vnBarre            INTEGER := 0;
      cadena1            VARCHAR2 (4000) := '';
      valor              VARCHAR2 (4000) := '';
      contador           INTEGER := 0;
      usuSolic           VARCHAR2 (15) := '';
      importeUmbral      NUMBER (10, 2) := 0;
      importeRebasado    NUMBER (10, 2) := 0;
      psCatEtaCraVer     VARCHAR2 (500) := '';
      psCatEtaAbi        VARCHAR2 (500) := '';
      psCatCodAcc        VARCHAR2 (6) := '';
      psCatCodRes        VARCHAR2 (6) := '';
      psCatEtaFinal      VARCHAR2 (500) := '';
      vsCentroCostos     VARCHAR2 (10) := '';
      psQueJuicios       VARCHAR2 (500) := '';
      cadenaArma         VARCHAR2 (4000) := '';
      verCreditoOk       VARCHAR2 (100) := '';
      verCreditoOkRee    VARCHAR2 (4000) := '';
      verCreditoOkFac    VARCHAR2 (4000) := '';
      queCarterasRee     VARCHAR2 (4000) := '';
      queCarterasFac     VARCHAR2 (4000) := '';
      queVALCarteras     VARCHAR2 (4000) := '';
      esCArtera          VARCHAR2 (4000) := '';
      suCArtera          VARCHAR2 (15) := '';
      esIndicador        VARCHAR2 (4000) := '';
      cualOtroTipo       VARCHAR2 (4000) := '';
      esFacturable       CHAR (1) := 'N';
      esReebolsable      CHAR (1) := 'N';
      esLIQUIDADO        VARCHAR2 (10) := '';
      queEstatusEs       VARCHAR2 (15) := '';
      queColaEs          VARCHAR2 (15) := '';
      queEstatusEs1      VARCHAR2 (15) := '';
      queColaEs1         VARCHAR2 (15) := '';
      existeColaStat     INTEGER := 0;
      idDynamics         VARCHAR2 (30) := '';
      esTramFact         VARCHAR2 (30) := '';
      pnPagoDoble        NUMBER (5) := 0;
      pnPagoDoblePM      NUMBER (5) := 0;
      pnPagoDobleDYN     NUMBER (5) := 0;
      psCuentaContable   VARCHAR2 (30) := '';
      queOperacion       VARCHAR2 (30) := '';
      yaExiste           INTEGER := 0;
      pnQueUmbral        INTEGER := 0;
      existeConc         INTEGER := 0;
      hayCabecero        INTEGER := 0;
      hayOtroTipo        INTEGER := 0;
      hayJuicioCred      INTEGER := 0;
      existeEtapaCrra    INTEGER := 0;
      existeEtapaAbie    INTEGER := 0;
      existeCA           INTEGER := 0;
      existeCR           INTEGER := 0;
      pnActimporte       NUMBER (10, 2) := pnImporte;
      permiteStatus      VARCHAR2 (500) := '';
      permiteCola        VARCHAR2 (500) := '';
      statusValido       INTEGER := 0;
      debeStatusValido   INTEGER := 0;
      unificaCredito     INTEGER := CASE WHEN psTipomovto = 3 THEN 2 ELSE psTipomovto END;
      exiteEnAsigna      INTEGER := 0;
      correoProjMang     VARCHAR2 (50) := '';
      tipoNoFactura1     VARCHAR2 (15) := '';
      tipoNoFactura2     VARCHAR2 (15) := '';
      CARTERA_NOVALIDA   EXCEPTION;
      fecha_pago_ini    DATE;
      fecha_pago_fin    DATE;
       esPagoDoble      INTEGER := 0;
      esPagoServicio    INTEGER := 0;
      sqmlEtapasLegales VARCHAR2 (2000) := '';
      strElementos       STRING_FNC.t_array;
      totalEtapasCerradas INTEGER     := 0;
      totalEtapasAbiertas INTEGER     := 0;
      fnmontoTotal      INTEGER     := 0;

      usujefeinmediato  VARCHAR (50) := '';
      usunofacturable  VARCHAR (50) := '';
      usuumbral1          VARCHAR (50) := '';
      usuumbral2          VARCHAR (50) := '';
      usuumbral3          VARCHAR (50) := '';
      usuexcedente1       VARCHAR (50) := '';
      usuexcedente2       VARCHAR (50) := '';
usuetapaabierta     VARCHAR (50) := '';
usuetapacerrada     VARCHAR (50) := '';
usuetapafin1        VARCHAR (50) := '';
usuetapafin2        VARCHAR (50) := '';
usupagodoble1       VARCHAR (50) := '';
usupagodoble2       VARCHAR (50) := '';
usudocsoporte1      VARCHAR (50) := '';
usudocsoporte2      VARCHAR (50) := '';
usudocsoporte3      VARCHAR (50) := '';
vnHayUno           INTEGER := 0;
      esConcepto         INTEGER := 0;
      esIgual            INTEGER := 0;
      queTpoTram         VARCHAR2 (50) := '';


      TYPE CUR_TYP IS REF CURSOR;
      cursor_Legales   CUR_TYP;

      CURSOR cuConcepto
      IS
         SELECT *
           FROM CTCATALOGOCUENTAS
          WHERE IDCONCEPTO = pnConcepto;

      CURSOR cuPrimero ( idgasto INTEGER)
      IS
         SELECT *
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = idgasto;

      CURSOR cuSegundo (idgasto INTEGER)
      IS
         SELECT *
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = idgasto;

      CURSOR cuJuicios (tpoDem NUMBER)
      IS
         SELECT CCCASENO, CCCASENO CCCASENODESC
           FROM RCVRY.CASEACCT
          WHERE     CCACCT = psCredito
                AND CCCASENO IN (SELECT CECASENO
                                   FROM RCVRY.CASE
                                  WHERE CESTATUS = 'A')
                AND CCCASENO IN (SELECT NUMERO
                                   FROM OPERACION.ELP_JUICIO
                                  WHERE ID_TIPO_DEMANDA = tpoDem);

      CURSOR cuEtapaCrraVerif(
         psjuicio    INTEGER,
         psEtapa     VARCHAR2)
         IS
           SELECT *
             FROM OPERACION.VW_ELP_ETAPAS_LEGALES
            WHERE     NUMERO_JUICIO = psjuicio
                  AND EN_PROCESO = 0
                  AND EN_PROCESO_PM = 0
                  AND ES_RETROCESO_ETAPAS= 0
                  AND FECHA_TERMINO IS NOT NULL
                  AND RESULTADO_VERIFICACION = 'CORRECTO'
                  AND NUMERO_ETAPA = psEtapa
         ORDER BY ORDEN DESC;

      CURSOR cuEtapaAbierta (
         psjuicio    INTEGER,
         psEtapa     VARCHAR2)
      IS
           SELECT *
             FROM OPERACION.VW_ELP_ETAPAS_LEGALES
            WHERE     NUMERO_JUICIO = psjuicio
                  AND EN_PROCESO = 0
                  AND FECHA_TERMINO IS NULL
                  AND NUMERO_ETAPA = psEtapa
                  AND ORDEN =
                         (SELECT MAX (ORDEN)
                            FROM OPERACION.VW_ELP_ETAPAS_LEGALES
                           WHERE     NUMERO_JUICIO = psjuicio
                                 AND EN_PROCESO = 0
                                 AND FECHA_TERMINO IS NULL
                                 AND NUMERO_ETAPA = psEtapa)
         ORDER BY ORDEN DESC;

      CURSOR cuDetCredito
      IS
         SELECT DM.DMACCT credito,
                DM.DMNAME deudor,
                DM.DMQUE cola,
                NVL (UPPER (U1CARTERA), UPPER (U2CARTERA)) CARTERA,
                DM.DMBRANCH CCOSTO,
                NVL (U1STATUS, U2STATUS) STATUS,
                FCDYNAMICS IDDYNAMICS
           FROM RCVRY.DELQMST DM
                LEFT JOIN RCVRY.UDA1 U1 ON (DM.DMACCT = U1.U1ACCT)
                LEFT JOIN RCVRY.UDA2 U2 ON (DM.DMACCT = U2.U2ACCT)
                LEFT JOIN CTCREDITODYNAMICS CD ON (CD.FCCREDITO = DM.DMACCT)
          WHERE DM.DMACCT = psCredito;

        CURSOR cuCreditosPagados IS
         SELECT * FROM (SELECT FA.IDGASTOMAIN, FA.IDCONCEPTO, FA.FCCREDITOCARTERA,
            FDFECREALPAGO, FCREMESA, FDFECSERVPAGADODEL, FDFECSERVPAGADOAL,
            ( CASE WHEN ( SELECT COUNT(1) FROM PENDUPM.FACTURACIONBITACORA
                           WHERE IDGASTOMAIN = FA.IDGASTOMAIN AND IDTASKGASTO = '4515947455273e63c4198f0073790158'
                                                  AND FCRESULTADO = 'Autorizado' ) > 0
                   THEN FNIMPORTECOMPROBA
                   ELSE FNIMPORTE END ) MONTO_TOTAL
            FROM PENDUPM.FACTURAASIGNACION FA INNER JOIN PENDUPM.FACTURACIONMAIN FM ON (FA.IDGASTOMAIN = FM.IDGASTOMAIN AND FA.IDCONCEPTO = FM.IDCONCEPTO)
            WHERE
            FA.FCCREDITOCARTERA = psCredito
            AND FA.IDCONCEPTO = pnConcepto
            AND (FA.FDFECSERVPAGADODEL IS NOT NULL OR FA.FDFECSERVPAGADOAL IS NOT NULL)
            AND FA.IDGASTOMAIN != pnSolicitud AND FCSTATUS NOT IN ('Z','R')
            AND FA.STATUS = 'A'
            ) WHERE MONTO_TOTAL > 0 ORDER BY FDFECSERVPAGADODEL;


        CURSOR cuCreditosPagadosSinFechas IS
         SELECT * FROM (SELECT FA.IDGASTOMAIN, FA.IDCONCEPTO, FA.FCCREDITOCARTERA,
            FDFECREALPAGO, FCREMESA, FDFECSERVPAGADODEL, FDFECSERVPAGADOAL,
            ( CASE WHEN ( SELECT COUNT(1) FROM PENDUPM.FACTURACIONBITACORA
                           WHERE IDGASTOMAIN = FA.IDGASTOMAIN AND IDTASKGASTO = '4515947455273e63c4198f0073790158'
                                                  AND FCRESULTADO = 'Autorizado' ) > 0
                   THEN FNIMPORTECOMPROBA
                   ELSE FNIMPORTE END ) MONTO_TOTAL
            FROM PENDUPM.FACTURAASIGNACION FA INNER JOIN PENDUPM.FACTURACIONMAIN FM ON (FA.IDGASTOMAIN = FM.IDGASTOMAIN AND FA.IDCONCEPTO = FM.IDCONCEPTO)
            WHERE
            FA.FCCREDITOCARTERA = psCredito
            AND FA.IDCONCEPTO = pnConcepto
            AND (FA.FDFECSERVPAGADODEL IS NULL AND FA.FDFECSERVPAGADOAL IS NULL)
            AND FA.IDGASTOMAIN != pnSolicitud AND FCSTATUS NOT IN ('Z','R')
            AND FA.STATUS = 'A'
            ) WHERE MONTO_TOTAL > 0 ORDER BY FDFECSERVPAGADODEL;


   BEGIN

      BEGIN
         SELECT DISTINCT TPOMOVIMIENTO
           INTO queOperacion
           FROM FACTURACIONMAIN
          WHERE IDGASTOMAIN = pnSolicitud;
      EXCEPTION
         WHEN OTHERS
         THEN
            queOperacion := NULL;
      END;

      SELECT COUNT (1)
        INTO hayOtroTipo
        FROM FACTURAASIGNACION
       WHERE IDGASTOMAIN = pnSolicitud AND IDTIPOMOVTO != unificaCredito;

      SELECT COUNT (1), MAX (IDCONCEPTO), MAX (TPOMOVIMIENTO)
        INTO vnHayUno, esConcepto, queTpoTram
        FROM FACTURACIONMAIN
       WHERE     IDGASTOMAIN = pnSolicitud
             AND FDFECREGISTRO = (SELECT MIN (FDFECREGISTRO)
                                    FROM FACTURACIONMAIN
                                   WHERE IDGASTOMAIN = pnSolicitud);

      IF (hayOtroTipo = 0)
      THEN
         SELECT COUNT (1)
           INTO yaExiste
           FROM FACTURAASIGNACION
          WHERE     IDGASTOMAIN = pnSolicitud
                AND IDCONCEPTO = pnConcepto
                AND IDTIPOMOVTO = unificaCredito
                AND FCCREDITOCARTERA = psCredito;

         IF (yaExiste = 0 OR psTipomovto = 42 OR psTipomovto = 4)
         THEN
            psError := '0';

            ---  Carga informacion del Concepto con que se va a Validar
            FOR regConcepto IN cuConcepto
            LOOP














            -- Jefe inmediato
             IF regConcepto.FCTIPOJEFEIN = 'S' THEN
                BEGIN
                    SELECT EMAILPUESTO
                      INTO usujefeinmediato
                      FROM GASTOESTRUCTURA
                     WHERE IDGASTOMAIN = pnSolicitud AND IDCONSECUTIVO = 2;
                EXCEPTION
                    WHEN OTHERS
                THEN
                  SELECT EMAILPUESTO
                    INTO usujefeinmediato
                    FROM GASTOESTRUCTURA
                   WHERE     IDGASTOMAIN = pnSolicitud
                         AND IDCONSECUTIVO = (SELECT MAX (IDCONSECUTIVO)
                                                FROM GASTOESTRUCTURA
                                               WHERE IDGASTOMAIN = pnSolicitud);
             END;
             ELSIF regConcepto.FCTIPOJEFEIN = 'O' THEN
                IF (regConcepto.FCTIPOJEFEINMED = 'E') THEN
                    usujefeinmediato := regConcepto.IDJEFEINMEDIATO;
                END IF;
                IF (regConcepto.FCTIPOJEFEINMED = 'T') THEN
                    usujefeinmediato :=PCKFACTURACIONGASTO.queEmpleadoMailPuesto (regConcepto.IDJEFEINMEDIATO);
                END IF;
                IF (regConcepto.FCTIPOJEFEINMED = 'P') THEN
                    usujefeinmediato := PENDUPM.PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, regConcepto.FCJEFEINMEDIATO);
                END IF;
             ELSE
                    usujefeinmediato := NULL;
            END IF;
            -- Termina Jefe Inmediato


            -- Autorizador No Facturable Autorizador 02
            IF (regConcepto.FCREQNOFACT = 'S') THEN
                IF ( regConcepto.FCTIPONOFACT2 = 'E' AND (regConcepto.IDREQNOFACT2 IS NOT NULL OR regConcepto.IDREQNOFACT2 != ''))
                THEN
                    usunofacturable := regConcepto.IDREQNOFACT2;
                END IF;
                IF ( regConcepto.FCTIPONOFACT2 = 'T' AND (regConcepto.IDREQNOFACT2 IS NOT NULL OR regConcepto.IDREQNOFACT2 != ''))
                THEN
                    usunofacturable := PCKFACTURACIONGASTO.queEmpleadoMailPuesto ( regConcepto.IDREQNOFACT2 );
                END IF;
                IF ( regConcepto.FCTIPONOFACT2 = 'P' )
                THEN
                    usunofacturable := PENDUPM.PCKFACTURACIONGASTO.QUECORREONIVELES ( quienSolic, regConcepto.FCNOMBRENOFACT2 );
                END IF;
            END IF;
            -- Termina Autorizador No Facturable Autorizador 02

            -- Umbral 01
            IF (    regConcepto.FCTIPOAUTMTO01 = 'E' AND regConcepto.AUTMONTO01 IS NOT NULL) THEN
                  usuumbral1 := regConcepto.AUTMONTO01;
            END IF;

            IF (    regConcepto.FCTIPOAUTMTO01 = 'T' AND regConcepto.AUTMONTO01 IS NOT NULL) THEN
                  usuumbral1 := PCKFACTURACIONGASTO.queEmpleadoMailPuesto ( regConcepto.AUTMONTO01);
            END IF;

            IF (    regConcepto.FCTIPOAUTMTO01 = 'P' AND regConcepto.AUTMONTO01 IS NOT NULL) THEN
                  usuumbral1 := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic,regConcepto.AUTMONTO01);
            END IF;

            -- Umbral 02
            IF (    regConcepto.FCTIPOAUTMTO02 = 'E' AND regConcepto.AUTMONTO02 IS NOT NULL) THEN
                  usuumbral2 := regConcepto.AUTMONTO02;
            END IF;

            IF (    regConcepto.FCTIPOAUTMTO02 = 'T' AND regConcepto.AUTMONTO02 IS NOT NULL) THEN
                  usuumbral2 := PCKFACTURACIONGASTO.queEmpleadoMailPuesto ( regConcepto.AUTMONTO02);
            END IF;

            IF (    regConcepto.FCTIPOAUTMTO02 = 'P' AND regConcepto.AUTMONTO02 IS NOT NULL) THEN
                  usuumbral2 := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic,regConcepto.AUTMONTO02);
            END IF;

            -- Umbral 03
            IF (    regConcepto.FCTIPOAUTMTO03 = 'E' AND regConcepto.AUTMONTO03 IS NOT NULL) THEN
                  usuumbral3 := regConcepto.AUTMONTO03;
            END IF;

            IF (    regConcepto.FCTIPOAUTMTO03 = 'T' AND regConcepto.AUTMONTO03 IS NOT NULL) THEN
                  usuumbral3 := PCKFACTURACIONGASTO.queEmpleadoMailPuesto ( regConcepto.AUTMONTO03);
            END IF;

            IF (    regConcepto.FCTIPOAUTMTO03 = 'P' AND regConcepto.AUTMONTO03 IS NOT NULL) THEN
                  usuumbral3 := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic,regConcepto.AUTMONTO03);
            END IF;


            -- Excedente de gasto 01
            IF ( regConcepto.TPOAUTEXCEDGSTO01 = 'E' AND regConcepto.AUTEXCEDGSTO01 IS NOT NULL) THEN
                  usuexcedente1 := regConcepto.AUTEXCEDGSTO01;
            END IF;

            IF ( regConcepto.TPOAUTEXCEDGSTO01 = 'T') THEN
                  usuexcedente1 := PCKFACTURACIONGASTO.queEmpleadoMailPuesto ( regConcepto.AUTEXCEDGSTO01 );
            END IF;

            IF ( regConcepto.TPOAUTEXCEDGSTO01 = 'P' AND regConcepto.AUTEXCEDGSTO01 IS NOT NULL) THEN
                  usuexcedente1 := PCKFACTURACIONGASTO.QUECORREONIVELES ( quienSolic, regConcepto.AUTEXCEDGSTO01 );
            END IF;

            -- Excedente de gasto 02
            IF ( regConcepto.TPOAUTEXCEDGSTO02 = 'E' AND regConcepto.AUTEXCEDGSTO02 IS NOT NULL) THEN
                  usuexcedente2 := regConcepto.AUTEXCEDGSTO02;
            END IF;

            IF ( regConcepto.TPOAUTEXCEDGSTO02 = 'T') THEN
                  usuexcedente2 := PCKFACTURACIONGASTO.queEmpleadoMailPuesto ( regConcepto.AUTEXCEDGSTO02 );
            END IF;

            IF ( regConcepto.TPOAUTEXCEDGSTO02 = 'P' AND regConcepto.AUTEXCEDGSTO02 IS NOT NULL) THEN
                  usuexcedente2 := PCKFACTURACIONGASTO.QUECORREONIVELES ( quienSolic, regConcepto.AUTEXCEDGSTO02 );
            END IF;

            -- ETAPA FINAL 01
            IF ( regConcepto.FCTIPOAUTETAPA01 = 'E' AND regConcepto.AUTETAPA01 IS NOT NULL) THEN
               usuetapafin1 := regConcepto.AUTETAPA01;
            END IF;

            IF ( regConcepto.FCTIPOAUTETAPA01 = 'T' AND regConcepto.AUTETAPA01 IS NOT NULL) THEN
               usuetapafin1 := PCKFACTURACIONGASTO.queEmpleadoMailPuesto (regConcepto.AUTETAPA01);
            END IF;

            IF ( regConcepto.FCTIPOAUTETAPA01 = 'P' AND (regConcepto.AUTETAPA01 IS NOT NULL))
            THEN
               usuetapafin1 := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, regConcepto.AUTETAPA01);
            END IF;

            -- ETAPA FINAL 02
            IF ( regConcepto.FCTIPOAUTETAPA02 = 'E' AND regConcepto.AUTETAPA02 IS NOT NULL) THEN
               usuetapafin2 := regConcepto.AUTETAPA02;
            END IF;

            IF ( regConcepto.FCTIPOAUTETAPA02 = 'T' AND regConcepto.AUTETAPA02 IS NOT NULL) THEN
               usuetapafin2 := PCKFACTURACIONGASTO.queEmpleadoMailPuesto (regConcepto.AUTETAPA02);
            END IF;

            IF ( regConcepto.FCTIPOAUTETAPA02 = 'P' AND (regConcepto.AUTETAPA02 IS NOT NULL)) THEN
               usuetapafin2 := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, regConcepto.AUTETAPA02);
            END IF;

            -- PAGO DOBLE 01
            IF ( regConcepto.FCPAGODOBLE = 'S' AND regConcepto.TIPOAUTPGODBL01 = 'E' AND regConcepto.AUTPGODBL01 IS NOT NULL) THEN
               usupagodoble1 := regConcepto.AUTPGODBL01;
            END IF;

            IF ( regConcepto.FCPAGODOBLE = 'S' AND regConcepto.TIPOAUTPGODBL01 = 'T' AND regConcepto.AUTPGODBL01 IS NOT NULL) THEN
               usupagodoble1 := PCKFACTURACIONGASTO.queEmpleadoMailPuesto ( regConcepto.AUTPGODBL01 );
            END IF;

            IF ( regConcepto.FCPAGODOBLE = 'S' AND regConcepto.TIPOAUTPGODBL01 = 'P' AND regConcepto.AUTPGODBL01 IS NOT NULL) THEN
               usupagodoble1 := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, regConcepto.AUTPGODBL01);
            END IF;

            -- PAGO DOBLE 02
            IF ( regConcepto.FCPAGODOBLE = 'S' AND regConcepto.TIPOAUTPGODBL02 = 'E' AND regConcepto.AUTPGODBL02 IS NOT NULL) THEN
               usupagodoble2 := regConcepto.AUTPGODBL01;
            END IF;

            IF ( regConcepto.FCPAGODOBLE = 'S' AND regConcepto.TIPOAUTPGODBL02 = 'T' AND regConcepto.AUTPGODBL02 IS NOT NULL) THEN
               usupagodoble2 := PCKFACTURACIONGASTO.queEmpleadoMailPuesto ( regConcepto.AUTPGODBL02 );
            END IF;

            IF ( regConcepto.FCPAGODOBLE = 'S' AND regConcepto.TIPOAUTPGODBL02 = 'P' AND regConcepto.AUTPGODBL02 IS NOT NULL) THEN
               usupagodoble2 := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, regConcepto.AUTPGODBL02);
            END IF;

            -- Verificacion de documentos de soporte 01
            IF( ( regConcepto.TIPOVERIFFINAL01 = 'E' OR INSTR (regConcepto.FCVERIFFINAL01, '@') > 0)
                                                        AND regConcepto.FCVERIFFINAL01 IS NOT NULL) THEN
                usudocsoporte1 := regConcepto.FCVERIFFINAL01;
            END IF;

            IF ( regConcepto.TIPOVERIFFINAL01 = 'T' AND ( regConcepto.FCVERIFFINAL01 IS NOT NULL
                                   OR regConcepto.FCVERIFFINAL01 != '')) THEN
                usudocsoporte1 := PCKFACTURACIONGASTO.queEmpleadoMailPuesto ( regConcepto.FCVERIFFINAL01 );
            END IF;

            IF ( (regConcepto.TIPOVERIFFINAL01 = 'P') AND ( regConcepto.FCVERIFFINAL01 IS NOT NULL
                                   OR regConcepto.FCVERIFFINAL01 != '')) THEN
                usudocsoporte1 := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, regConcepto.FCVERIFFINAL01);
            END IF;

             -- Verificacion de documentos de soporte 02
            IF( ( regConcepto.TIPOVERIFFINAL02 = 'E' OR INSTR (regConcepto.FCVERIFFINAL02, '@') > 0)
                                                        AND regConcepto.FCVERIFFINAL02 IS NOT NULL) THEN
                usudocsoporte2 := regConcepto.FCVERIFFINAL02;
            END IF;

            IF ( regConcepto.TIPOVERIFFINAL02 = 'T' AND ( regConcepto.FCVERIFFINAL02 IS NOT NULL
                                   OR regConcepto.FCVERIFFINAL02 != '')) THEN
                usudocsoporte2 := PCKFACTURACIONGASTO.queEmpleadoMailPuesto ( regConcepto.FCVERIFFINAL02 );
            END IF;

            IF ( (regConcepto.TIPOVERIFFINAL02 = 'P') AND ( regConcepto.FCVERIFFINAL02 IS NOT NULL
                                   OR regConcepto.FCVERIFFINAL02 != '')) THEN
                usudocsoporte2 := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, regConcepto.FCVERIFFINAL02);
            END IF;

             -- Verificacion de documentos de soporte 03
            IF( ( regConcepto.TIPOVERIFFINAL03 = 'E' OR INSTR (regConcepto.FCVERIFFINAL03, '@') > 0)
                                                        AND regConcepto.FCVERIFFINAL03 IS NOT NULL) THEN
                usudocsoporte3 := regConcepto.FCVERIFFINAL03;
            END IF;

            IF ( regConcepto.TIPOVERIFFINAL03 = 'T' AND ( regConcepto.FCVERIFFINAL03 IS NOT NULL
                                   OR regConcepto.FCVERIFFINAL03 != '')) THEN
                usudocsoporte3 := PCKFACTURACIONGASTO.queEmpleadoMailPuesto ( regConcepto.FCVERIFFINAL03 );
            END IF;

            IF ( (regConcepto.TIPOVERIFFINAL03 = 'P') AND ( regConcepto.FCVERIFFINAL03 IS NOT NULL
                                   OR regConcepto.FCVERIFFINAL03 != '')) THEN
                usudocsoporte3 := PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, regConcepto.FCVERIFFINAL03);
            END IF;



            IF (vnHayUno > 0)
            THEN
               esIgual := 0;

               FOR regValida IN cuPrimero (pnSolicitud)
               LOOP
                  FOR regActual IN cuSegundo (pnSolicitud)
                  LOOP
                     IF ( regValida.FCUSUJEFEINMEDIATO != regActual.FCUSUJEFEINMEDIATO ) THEN
                        psError :=
                           '*ALERTA* La Configuracion JEFE INMEDIATO NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF (   ( regValida.FCUSUNOFACTURABLE IS NOT NULL
                             AND regActual.FCUSUNOFACTURABLE IS NOT NULL  )
                             AND regValida.FCUSUNOFACTURABLE != regActual.FCUSUNOFACTURABLE) THEN
                        psError :=
                           '*ALERTA* La Configuracion AUTORIZA NO FACTURABLE NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF ( ( regValida.FCUSUUMBRAL1 IS NOT NULL
                             AND regActual.FCUSUUMBRAL1 IS NOT NULL  )
                             AND regValida.FCUSUUMBRAL1 != regActual.FCUSUUMBRAL1) THEN
                        psError :=
                           '*ALERTA* La Configuracion AUTORIZA UMBRAL 01 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF ( ( regValida.FCUSUUMBRAL2 IS NOT NULL
                             AND regActual.FCUSUUMBRAL2 IS NOT NULL  )
                             AND regValida.FCUSUUMBRAL2 != regActual.FCUSUUMBRAL2) THEN
                        psError :=
                           '*ALERTA* La Configuracion AUTORIZA UMBRAL 02 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF ( ( regValida.FCUSUUMBRAL3 IS NOT NULL
                             AND regActual.FCUSUUMBRAL3 IS NOT NULL  )
                             AND regValida.FCUSUUMBRAL3 != regActual.FCUSUUMBRAL3) THEN
                        psError :=
                           '*ALERTA* La Configuracion AUTORIZA UMBRAL 03 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF ( ( regValida.FCUSUEXCEDENTE1 IS NOT NULL
                             AND regActual.FCUSUEXCEDENTE1 IS NOT NULL  )
                             AND regValida.FCUSUEXCEDENTE1 != regActual.FCUSUEXCEDENTE1) THEN
                        psError :=
                           '*ALERTA* La Configuracion AUTORIZA EXCEDENTE 01 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF ( ( regValida.FCUSUEXCEDENTE2 IS NOT NULL
                             AND regActual.FCUSUEXCEDENTE2 IS NOT NULL  )
                             AND regValida.FCUSUEXCEDENTE2 != regActual.FCUSUEXCEDENTE2) THEN
                        psError :=
                           '*ALERTA* La Configuracion AUTORIZA EXCEDENTE 02 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF ( ( regValida.FCUSUETAPAFIN1 IS NOT NULL
                             AND regActual.FCUSUETAPAFIN1 IS NOT NULL  )
                             AND regValida.FCUSUETAPAFIN1 != regActual.FCUSUETAPAFIN1) THEN
                        psError :=
                           '*ALERTA* La Configuracion AUTORIZA ETAPA FINAL 01 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF ( ( regValida.FCUSUETAPAFIN2 IS NOT NULL
                             AND regActual.FCUSUETAPAFIN2 IS NOT NULL  )
                             AND regValida.FCUSUETAPAFIN2 != regActual.FCUSUETAPAFIN2) THEN
                        psError :=
                           '*ALERTA* La Configuracion AUTORIZA ETAPA FINAL 02 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF ( ( regValida.FCUSUPAGODOBLE1 IS NOT NULL
                             AND regActual.FCUSUPAGODOBLE1 IS NOT NULL  )
                             AND regValida.FCUSUPAGODOBLE1 != regActual.FCUSUPAGODOBLE1) THEN
                        psError :=
                           '*ALERTA* La Configuracion AUTORIZA PAGO DOBLE 01 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF ( ( regValida.FCUSUPAGODOBLE2 IS NOT NULL
                             AND regActual.FCUSUPAGODOBLE2 IS NOT NULL  )
                             AND regValida.FCUSUPAGODOBLE2 != regActual.FCUSUPAGODOBLE2) THEN
                        psError :=
                           '*ALERTA* La Configuracion AUTORIZA PAGO DOBLE 02 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF ( ( regValida.FCUSUDOCSOPORTE1 IS NOT NULL
                             AND regActual.FCUSUDOCSOPORTE1 IS NOT NULL  )
                             AND regValida.FCUSUDOCSOPORTE1 != regActual.FCUSUDOCSOPORTE1) THEN
                        psError :=
                           '*ALERTA* La Configuracion AUTORIZA DOCUMENTO DE SOPORTE 01 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF ( ( regValida.FCUSUDOCSOPORTE2 IS NOT NULL
                             AND regActual.FCUSUDOCSOPORTE2 IS NOT NULL  )
                             AND regValida.FCUSUDOCSOPORTE2 != regActual.FCUSUDOCSOPORTE2) THEN
                        psError :=
                           '*ALERTA* La Configuracion AUTORIZA DOCUMENTO DE SOPORTE 02 NO es igual para esta Solicitud';
                        EXIT;
                     ELSIF ( ( regValida.FCUSUDOCSOPORTE3 IS NOT NULL
                             AND regActual.FCUSUDOCSOPORTE3 IS NOT NULL  )
                             AND regValida.FCUSUDOCSOPORTE3 != regActual.FCUSUDOCSOPORTE3) THEN
                        psError :=
                           '*ALERTA* La Configuracion AUTORIZA DOCUMENTO DE SOPORTE 03 NO es igual para esta Solicitud';
                        EXIT;
                     END IF;

                  END LOOP;
               END LOOP;
            END IF;






               queCarterasRee := regConcepto.FCCARTERAASIGNADA;
               queCarterasFac := regConcepto.FCCARTERAASIGFAC;
               psCuentaContable := regConcepto.FCCUENTACONTABLE;

               IF (UPPER (queOperacion) != 'TRAMITE')
               THEN
                  --****** Verifica umbral de importe ********
                  IF (   (    regConcepto.VERMONTO01 IS NOT NULL )
                      OR (    regConcepto.VERMONTO02 IS NOT NULL )
                      OR (    regConcepto.VERMONTO03 IS NOT NULL )
                     )
                  THEN
                     -- Revisa contra primer monto
                     IF (pnImporte <= regConcepto.VERMONTO01)
                     THEN
                        queUmbralRebaso := 0;
                        importeUmbral := regConcepto.VERMONTO01;
                        pnQueUmbral := 0;
           END IF;
                     -- Revisa contra segundo monto
                     IF (pnImporte > regConcepto.VERMONTO01 AND regConcepto.AUTMONTO01 IS NOT NULL)
                     THEN
                        queUmbralRebaso := pnImporte;
                        importeUmbral := regConcepto.VERMONTO01;
                        pnQueUmbral := 1;
           END IF;
                     -- Revisa contra tercer monto
                     IF (pnImporte > regConcepto.VERMONTO02 AND regConcepto.AUTMONTO02 IS NOT NULL)
                     THEN
                        queUmbralRebaso := pnImporte;
                        importeUmbral := regConcepto.VERMONTO02;
                        pnQueUmbral := 2;
           END IF;
                     --- si rebasa el Tercer Monto
                     IF (pnImporte > regConcepto.VERMONTO03 AND regConcepto.AUTMONTO03 IS NOT NULL)
                     THEN
                        queUmbralRebaso := pnImporte;
                        importeUmbral := regConcepto.VERMONTO03;
                        pnQueUmbral := 3;
                     END IF;
                  END IF;

                  esTramFact := regConcepto.FCIMPFACTTRAMITE;
               ELSE
                  esTramFact := regConcepto.FCIMPFACTTRAMITE;
                  queUmbralRebaso := 0;
                  importeUmbral := 0;
                  pnQueUmbral := 0;
               END IF;                               --- SOLO SI NO ES TRAMITE

               IF (psTipomovto = 2 OR psTipomovto = 3)
               THEN
                  psCatEtaCraVer := regConcepto.VERETAPACDACHK;
                  psCatEtaAbi := regConcepto.VERETAPAABIERTA;
                  psCatCodAcc := regConcepto.FCCODACCEXT;
                  psCatCodRes := regConcepto.FCCODRESEXT;
                  psCatEtaFinal := regConcepto.VERETAPACDACHKFIN;

                  --****** Verifica Etapas Procesales / JUICIOS ACTIVOS ********
                  IF (   (regConcepto.VERETAPACDACHK IS NOT NULL)
                      OR (regConcepto.VERETAPAABIERTA IS NOT NULL)
                      OR (regConcepto.FCCODACCEXT IS NOT NULL)
                      OR (regConcepto.FCCODRESEXT IS NOT NULL))
                  THEN

                     queEtapaCRAVER := '';
                     queEtapaABTA := '';

                     SELECT COUNT (1)
                       INTO hayJuicioCred
                       FROM RCVRY.CASEACCT
                      WHERE     CCACCT = psCredito
                            AND CCCASENO IN (SELECT CECASENO
                                               FROM RCVRY.CASE
                                              WHERE CESTATUS = 'A')
                            AND CCCASENO IN (SELECT NUMERO
                                               FROM OPERACION.ELP_JUICIO
                                              WHERE ID_TIPO_DEMANDA = 2);

                     IF (hayJuicioCred = 0)
                     THEN
                        queEtapaCRAVER :=
                              queEtapaCRAVER
                           || 'EL CREDITO '
                           || psCredito
                           || ' NO TIENE JUICIOS ACTIVOS<BR/>';
                        queEtapaABTA :=
                              queEtapaABTA
                           || 'EL CREDITO '
                           || psCredito
                           || ' NO TIENE JUICIOS ACTIVOS<BR/>';
                     END IF;

                     FOR regjuicios IN cuJuicios (2)
                     LOOP
                        /*  IDTIPODEMANDA = 1  EN CONTRA   /  IDTIPODEMANDA = 2  DEMANDA NUESTRA */
                        /*  OPERACION.ELP_JUICIO campo  ID_TIPO_DEMANDA del catalogo OPERACION.CAT_TIPO_DEMANDA */
                        --- Obtiene el Tipo de Demanda del Juicio
                        --- Obtiene Valores para juicio
                        BEGIN
                           SELECT ID_TIPO_DEMANDA, ID_TIPO_JUICIO
                             INTO queTipoJuicio, queTipoDemanda
                             FROM OPERACION.ELP_JUICIO
                            WHERE NUMERO = regjuicios.CCCASENO;
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              queTipoJuicio := NULL;
                              queTipoDemanda := NULL;
                        END;

                        ---  Barre para Validar las ETAPAS CERADAS Y VERIFICADAS del JUICIO
                        queEtapaCRAVER := '';
                        queEtapaABTA := '';
                        existeEtapaCrra := 0;

                        IF ( (regConcepto.VERETAPACDACHK IS NOT NULL))
                        THEN
                           existeEtapaCrra := 0;

                           sqmlEtapasLegales := 'SELECT COUNT(1) TOTAL FROM OPERACION.VW_ELP_ETAPAS_LEGALES WHERE NUMERO_JUICIO = '|| regjuicios.CCCASENO ||'
                                AND EN_PROCESO = 0
                                AND EN_PROCESO_PM = 0
                                AND ES_RETROCESO_ETAPAS= 0
                                AND FECHA_TERMINO IS NOT NULL
                                AND RESULTADO_VERIFICACION = ''CORRECTO''
                                AND NUMERO_ETAPA IN ('|| replace(regConcepto.VERETAPACDACHK,'|',',') ||')
                              ORDER BY ORDEN DESC';

                           open cursor_Legales for sqmlEtapasLegales;
                            LOOP
                              FETCH cursor_Legales INTO fnmontoTotal;
                                EXIT WHEN cursor_Legales%NOTFOUND;
                                totalEtapasCerradas := fnmontoTotal;
                            END LOOP;
                           CLOSE cursor_Legales;

                            IF ( totalEtapasCerradas > 0 ) THEN
                              existeEtapaCrra := 0;

                            ELSE
                             existeEtapaCrra := existeEtapaCrra;
                             cadena1 := regConcepto.VERETAPACDACHK || '|';
                             ubica := INSTR (cadena1, '|');

                            WHILE (ubica > 0)
                            LOOP
                              valor := SUBSTR (cadena1, 1, ubica - 1);
                              contador := 0;

                              FOR regEtapa
                                 IN cuEtapaCrraVerif (regjuicios.CCCASENO,
                                                      valor)
                              LOOP
                                 contador := contador + 1;
                                 queEtapaCRAVER := '';

                                 IF (regEtapa.RESULTADO_VERIFICACION !=
                                        'CORRECTO')
                                 THEN
                                    queEtapaCRAVER :=
                                          queEtapaCRAVER
                                       || 'LA ETAPA ['
                                       || valor
                                       || '] FUE CALIFICADA COMO '
                                       || regEtapa.RESULTADO_VERIFICACION
                                       || ' EL DIA '
                                       || PCKCTRLDOCUMENTAL01.aplFecha (
                                             regEtapa.FECHA_VERIFICACION)
                                       || '<BR/>';
                                 ELSIF (regEtapa.RESULTADO_VERIFICACION =
                                           'CORRECTO')
                                 THEN
                                    --- Si se cumple al menos una de las etapas se sale
                                    existeEtapaCrra := 1;
                                    queEtapaCRAVER := '';
                                    EXIT;
                                 END IF;
                              END LOOP;

                              IF (existeEtapaCrra = 0)
                              THEN
                                 queEtapaCRAVER :=
                                       queEtapaCRAVER
                                    || 'LA ETAPA ['
                                    || valor
                                    || '] NO SE ENCUENTRA CERRADA Y VERIFICADA'
                                    || '<BR/>';
                              END IF;

                              cadena1 := SUBSTR (cadena1, ubica + 1);
                              ubica := INSTR (cadena1, '|');

                            END LOOP;

                           END IF;

                        END IF;

                        IF ( (regConcepto.VERETAPAABIERTA IS NOT NULL))
                        THEN
                           cadena1 := regConcepto.VERETAPAABIERTA || '|';
                           existeEtapaAbie := 0;
                           queEtapaABTA := 'LAS SIGUIENTES ETAPAS NO ESTAN ABIERTAS: ';
                           ubica := INSTR (cadena1, '|');

                           WHILE (ubica > 0)
                           LOOP
                              valor := SUBSTR (cadena1, 1, ubica - 1);
                              contador := 0;

                              FOR regEtapa
                                 IN cuEtapaAbierta (regjuicios.CCCASENO,
                                                    valor)
                              LOOP
                                 contador := contador + 1;
                              END LOOP;

                              IF (contador = 0)
                              THEN
                                 queEtapaABTA :=
                                       queEtapaABTA
                                    || '['
                                    || valor
                                    || ']'
                                    || ' | ';
                              END IF;

                              IF (contador > 0)
                                 THEN
                                    --- Si se cumple al menos una de las etapas se sale
                                    queEtapaABTA := '';
                                    EXIT;
                              END IF;

                              cadena1 := SUBSTR (cadena1, ubica + 1);
                              ubica := INSTR (cadena1, '|');
                           END LOOP;
                        END IF;
                     END LOOP;
                  END IF;

                  --****** Verifica Codigos de Accion y Resultados del Cr?dito ********
                  queCodAccion := '';
                  queCodResultado := '';

                  IF (   (regConcepto.FCCODACCEXT IS NOT NULL)
                      OR (regConcepto.FCCODRESEXT IS NOT NULL))
                  THEN
                     IF (    (regConcepto.FCCODACCEXT IS NOT NULL)
                         AND (regConcepto.FCCODRESEXT IS NOT NULL))
                     THEN
                        FOR regjuicios IN cuJuicios (2)
                        LOOP
                            SELECT COUNT(*) INTO contador FROM OPERACION.VW_ELP_BITACORA_GESTION
                            WHERE NUMERO_JUICIO = regjuicios.CCCASENO AND CA = regConcepto.FCCODACCEXT AND CR = regConcepto.FCCODRESEXT
                            AND FECHA BETWEEN (  SYSDATE
                                                     - CASE
                                                          WHEN regConcepto.FNVIGENCIA
                                                                  IS NULL
                                                          THEN
                                                             30
                                                          ELSE
                                                             regConcepto.FNVIGENCIA
                                                       END)
                                                AND SYSDATE;

                            IF (contador = 0)
                            THEN
                               queCodAccion :=
                                     'NO Existe gestion del CA['
                                  || regConcepto.FCCODACCEXT
                                  || ']';
                               queCodResultado :=
                                     'NO Existe gestion del CR['
                                  || regConcepto.FCCODRESEXT
                                  || ']';
                            ELSE
                                queCodAccion := '';
                                queCodResultado := '';
                                EXIT;
                            END IF;
                        END LOOP;
                     ELSIF (    (regConcepto.FCCODACCEXT IS NOT NULL)
                            AND (regConcepto.FCCODRESEXT IS NULL))
                     THEN
                        FOR regjuicios IN cuJuicios (2)
                        LOOP
                            SELECT COUNT(*) INTO contador FROM OPERACION.VW_ELP_BITACORA_GESTION
                            WHERE NUMERO_JUICIO = regjuicios.CCCASENO AND CA = regConcepto.FCCODACCEXT
                            AND FECHA BETWEEN (  SYSDATE
                                                     - CASE
                                                          WHEN regConcepto.FNVIGENCIA
                                                                  IS NULL
                                                          THEN
                                                             30
                                                          ELSE
                                                             regConcepto.FNVIGENCIA
                                                       END)
                                                AND SYSDATE;
                            IF (contador = 0)
                            THEN
                               queCodAccion :=
                                     'NO Existe gestion del CA['
                                  || regConcepto.FCCODACCEXT
                                  || ']';
                               queCodResultado := '';
                            ELSE
                               queCodAccion := '';
                               queCodResultado := '';
                               EXIT;
                            END IF;
                        END LOOP;
                     ELSIF (    (regConcepto.FCCODACCEXT IS NULL)
                            AND (regConcepto.FCCODRESEXT IS NOT NULL))
                     THEN
                        FOR regjuicios IN cuJuicios (2)
                        LOOP
                            SELECT COUNT(*) INTO contador FROM OPERACION.VW_ELP_BITACORA_GESTION
                            WHERE NUMERO_JUICIO = regjuicios.CCCASENO AND CR = regConcepto.FCCODRESEXT
                            AND FECHA BETWEEN (  SYSDATE
                                                     - CASE
                                                          WHEN regConcepto.FNVIGENCIA
                                                                  IS NULL
                                                          THEN
                                                             30
                                                          ELSE
                                                             regConcepto.FNVIGENCIA
                                                       END)
                                                AND SYSDATE;
                            IF (contador = 0)
                            THEN
                               queCodAccion := '';
                               queCodResultado :=
                                     'NO Existe gestion del CR['
                                  || regConcepto.FCCODRESEXT
                                  || ']';
                            ELSE
                               queCodAccion := '';
                               queCodResultado := '';
                               EXIT;
                            END IF;
                        END LOOP;
                     ELSE
                        queCodAccion :=
                              'NO Existe gestion del CA['
                           || regConcepto.FCCODACCEXT
                           || ']';
                        queCodResultado :=
                              'NO Existe gestion del CR['
                           || regConcepto.FCCODRESEXT
                           || ']';
                     END IF;
                  END IF;

               ELSE
                  psCatEtaCraVer := NULL;
                  psCatEtaAbi := NULL;
                  psCatCodAcc := NULL;
                  psCatCodRes := NULL;
                  psCatEtaFinal := NULL;
                  queCodAccion := NULL;
                  queCodResultado := NULL;
                  queEtapaABTA := NULL;
                  queEtapaCRAVER := NULL;
                  cadenaArma := NULL;
               END IF;
            END LOOP;

            IF (psTipomovto = 2 OR psTipomovto = 3)
            THEN
               FOR regjuicios IN cuJuicios (2)
               LOOP
                  psQueJuicios :=
                     psQueJuicios || '[' || regjuicios.CCCASENO || '] ';
               END LOOP;

               FOR regCredito IN cuDetCredito
               LOOP
                  cadenaArma :=
                        cadenaArma
                     || regCredito.credito
                     || '|'
                     || regCredito.deudor
                     || '|'
                     || regCredito.cola
                     || '|'
                     || regCredito.CARTERA
                     || '|'
                     || regCredito.CCOSTO
                     || '|'
                     || '|'
                     || regCredito.STATUS
                     || '|'
                     || regCredito.IDDYNAMICS
                     || '|'
                     || psQueJuicios;
                  suCArtera := regCredito.CARTERA;
                  vsCentroCostos := regCredito.CCOSTO;
               END LOOP;

               --- Verifica que el Cr?dito se permita agregar por Configuracion
               strElementos := STRING_FNC.split (queCarterasRee, '|');
               verCreditoOkRee := '*';

               FOR vnBarre IN 1 .. strElementos.COUNT
               LOOP
                  queVALCarteras :=
                     SUBSTR (strElementos (vnBarre),
                             1,
                             LENGTH (strElementos (vnBarre)) - 1);
                  ubica := INSTR (queVALCarteras, '-');
                  esCArtera := SUBSTR (queVALCarteras, 1, (ubica - 1)); /* Regresa la CArtera Valida */
                  esIndicador := SUBSTR (queVALCarteras, (ubica + 1)); /* SI - NO - NOAPLICA - FORMULA */

                  IF (suCArtera = esCArtera)
                  THEN
                  
                     IF (esIndicador = 'SI' OR esIndicador = 'NO')
                     THEN
                        verCreditoOkRee := '0';
                        esReebolsable :=
                           CASE WHEN esIndicador = 'SI' THEN 'S' ELSE 'N' END;
                     ELSIF (esIndicador = 'NOAPLICA')
                     THEN
                        esReebolsable := 'N';
                     ELSE
                        verCreditoOkRee :=
                              '*ERROR* El Credito de la CARTERA '
                           || esCArtera
                           || ' NO esta permitido para esta Operacion';
                        esReebolsable := 'N';
                     END IF;

                     EXIT;
                  ELSE
                     verCreditoOkRee := '*';
                     esReebolsable := 'N';
                  END IF;
               ---DBMS_OUTPUT.PUT_LINE('===:: '||suCArtera||'---'||esCArtera||'---'||esIndicador||'---'||verCreditoOk||'---'||esFacturable);
               END LOOP;

                    --- Verifica que el Cr?dito se permita agregar por Configuracion
               strElementos := STRING_FNC.split (queCarterasFac, '|');
               verCreditoOkFac := '*';

               FOR vnBarre IN 1 .. strElementos.COUNT
               LOOP
                  queVALCarteras :=
                     SUBSTR (strElementos (vnBarre),
                             1,
                             LENGTH (strElementos (vnBarre)) - 1);
                  ubica := INSTR (queVALCarteras, '-');
                  esCArtera := SUBSTR (queVALCarteras, 1, (ubica - 1)); /* Regresa la CArtera Valida */
                  esIndicador := SUBSTR (queVALCarteras, (ubica + 1)); /* SI - NO - NOAPLICA - FORMULA */


                  IF (suCArtera = esCArtera)
                  THEN
                     IF (esIndicador = 'SI' OR esIndicador = 'NO')
                     THEN
                        verCreditoOkFac := '0';
                        esFacturable :=
                           CASE WHEN esIndicador = 'SI' THEN 'S' ELSE 'N' END;
                     ELSIF (esIndicador = 'NOAPLICA')
                     THEN
                        verCreditoOkFac :=
                              '*ERROR* El Credito de la CARTERA '
                           || esCArtera
                           || ' NO esta permitido para esta Operacion';
                        esFacturable := 'N';
                     ELSE
                        verCreditoOkFac :=
                              '*ERROR* El Credito de la CARTERA '
                           || esCArtera
                           || ' NO esta permitido para esta Operacion';
                        esFacturable := 'N';
                     END IF;

                     EXIT;
                  
                  ELSE
                     verCreditoOkFac := '*';
                     esFacturable := 'N';
                  END IF;
               ---DBMS_OUTPUT.PUT_LINE('===:: '||suCArtera||'---'||esCArtera||'---'||esIndicador||'---'||verCreditoOk||'---'||esFacturable);
               END LOOP;

DBMS_OUTPUT.PUT_LINE ( 'DEVMK01: '||psError );
DBMS_OUTPUT.PUT_LINE ( 'verCreditoOkRee: '||verCreditoOkRee );
DBMS_OUTPUT.PUT_LINE ( 'verCreditoOkFac: '||verCreditoOkFac );

               IF (verCreditoOkRee = '*' AND verCreditoOkFac = '*' )
               THEN
                  verCreditoOk :=
                        '*ERROR* El Credito '
                     || psCredito
                     || ' NO esta permitido para esta Operacion,CARTERA no valida';
                  esFacturable := 'N';
                  esReebolsable := 'N';
               END IF;

               psError := verCreditoOk;
            ELSE
               vsCentroCostos := psCentroCosto;
            END IF;

DBMS_OUTPUT.PUT_LINE ( 'DEVMK02: '||psError );
DBMS_OUTPUT.PUT_LINE ( 'verCreditoOkRee: '||verCreditoOkRee );
DBMS_OUTPUT.PUT_LINE ( 'verCreditoOkFac: '||verCreditoOkFac );

      -- VALIDAMOS SI LA CARTERA ES FACTURABLE
            IF (psTipomovto = 4)
            THEN
                suCArtera := psCredito;
                
               strElementos := STRING_FNC.split (queCarterasRee, '|');
               verCreditoOkRee := '*';
               FOR vnBarre IN 1 .. strElementos.COUNT
               LOOP
                  queVALCarteras :=
                     SUBSTR (strElementos (vnBarre),
                             1,
                             LENGTH (strElementos (vnBarre)) - 1);
                  ubica := INSTR (queVALCarteras, '-');
                  esCArtera := SUBSTR (queVALCarteras, 1, (ubica - 1)); /* Regresa la CArtera Valida */
                  esIndicador := SUBSTR (queVALCarteras, (ubica + 1)); /* SI - NO - NOAPLICA - FORMULA */

                  IF (suCArtera = esCArtera)
                  THEN
                     IF (esIndicador = 'SI' OR esIndicador = 'NO')
                     THEN
                        verCreditoOkRee := '0';
                        esReebolsable :=
                           CASE WHEN esIndicador = 'SI' THEN 'S' ELSE 'N' END;
                     ELSIF (esIndicador = 'NOAPLICA')
                     THEN
                        verCreditoOkRee :=
                              '*ERROR* El Credito de la CARTERA '
                           || esCArtera
                           || ' NO esta permitido para esta Operacion';
                        esReebolsable := 'N';
                     ELSE
                        verCreditoOkRee :=
                              '*ERROR* El Credito de la CARTERA '
                           || esCArtera
                           || ' NO esta permitido para esta Operacion';
                        esReebolsable := 'N';
                     END IF;

                     EXIT;
                  ELSE
                     verCreditoOkRee := '*';
                     esReebolsable := 'N';
                  END IF;

               END LOOP;
               
               verCreditoOkFac := '*';
               strElementos := STRING_FNC.split (queCarterasFac, '|');
               FOR vnBarre IN 1 .. strElementos.COUNT
               LOOP
                  queVALCarteras :=
                     SUBSTR (strElementos (vnBarre),
                             1,
                             LENGTH (strElementos (vnBarre)) - 1);
                  ubica := INSTR (queVALCarteras, '-');
                  esCArtera := SUBSTR (queVALCarteras, 1, (ubica - 1)); /* Regresa la CArtera Valida */
                  esIndicador := SUBSTR (queVALCarteras, (ubica + 1)); /* SI - NO - NOAPLICA - FORMULA */

                  IF (suCArtera = esCArtera)
                  THEN
                     IF (esIndicador = 'SI' OR esIndicador = 'NO')
                     THEN
                       verCreditoOkFac := '0';
                       esFacturable :=
                           CASE WHEN esIndicador = 'SI' THEN 'S' ELSE 'N' END;
                     ELSIF (esIndicador = 'NOAPLICA')
                     THEN
                        verCreditoOkFac :=
                              '*ERROR* El Credito de la CARTERA '
                           || esCArtera
                           || ' NO esta permitido para esta Operacion';
                        esFacturable := 'N';
                     ELSE
                        verCreditoOkFac :=
                              '*ERROR* El Credito de la CARTERA '
                           || esCArtera
                           || ' NO esta permitido para esta Operacion';
                        esFacturable := 'N';
                     END IF;

                     EXIT;
                  ELSE
                     verCreditoOkFac := '*';
                     esFacturable := 'N';
                  END IF;

               END LOOP;
               
            END IF;

            --- obtiene el usuario que Agrega
            SELECT DISTINCT FCUSUARIO
              INTO usuSolic
              FROM FACTURAGASTO
             WHERE IDGASTOMAIN = pnSolicitud;

            -- Valido que el concepto este configurado como PagoDoble
                SELECT COUNT(*) INTO esPagoDoble FROM CTCATALOGOCUENTAS WHERE FCPAGODOBLE = 'S'
                AND IDCONCEPTO = pnConcepto;

            -- Valido que el concepto sea de pago de servicios
                SELECT COUNT(*) INTO esPagoServicio FROM CTCATALOGOCUENTAS WHERE FCREQPAGSERV = 'S'
                AND IDCONCEPTO = pnConcepto;

            IF ( (psTipomovto = 2 OR psTipomovto = 3) AND esPagoServicio = 0 AND esPagoDoble > 0 )
            THEN

               --- obtiene el Id de dynamics del Credito
               BEGIN
                  SELECT FCDYNAMICS
                    INTO idDynamics
                    FROM CTCREDITODYNAMICS
                   WHERE FCCREDITO = psCredito;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     idDynamics := 'NOEXISTE';
               END;

               --- Obtiene el numero de Pagos Dobles Encontrados
               ---  TONA LA INFO DE BI  DEL ACCESSS
               SELECT COUNT (1)
                 INTO pnPagoDobleDYN
                 FROM BI_DIMGASTOS@PENDUBI.COM
                WHERE CREDITO_CYBER = psCredito
                  AND CUENTA_CONTABLE = psCuentaContable
                  AND (PROVEEDOR IS NULL OR PROVEEDOR NOT LIKE '%PENDULUM%')
                  AND TO_NUMBER(NVL(NUMERO_CASO,0)) NOT IN ( 
                         SELECT B.IDGASTOMAIN 
                           FROM PENDUPM.FACTURAASIGNACION A 
                     INNER JOIN PENDUPM.FACTURACIONMAIN B ON ( A.IDGASTOMAIN = B.IDGASTOMAIN AND A.IDCONCEPTO = B.IDCONCEPTO) 
                          WHERE     A.IDGASTOMAIN != pnSolicitud AND FCCREDITOCARTERA = psCredito AND FCSTATUS NOT IN ( 'Z','R') 
                                AND FCCUENTACONTABLE = psCuentaContable AND A.STATUS = 'A'
                  );

            ELSE
               idDynamics := NULL;
               pnPagoDoblePM := 0;
            END IF;


            --   COLUMNAS PAGO DOBLE ***   SELECT "Acct", "ProjectID" ,"Id", "Name", "OrigAcct", "RefNbr", "TranDesc", "TranDate", "DrAmt"
            IF (esPagoServicio = 0 AND esPagoDoble > 0)    THEN
                SELECT COUNT (1)
                 INTO pnPagoDoblePM
                 FROM FACTURAASIGNACION FA INNER JOIN PENDUPM.CTCATALOGOCUENTAS CT ON ( FA.IDCONCEPTO = CT.IDCONCEPTO )
                WHERE IDGASTOMAIN != pnSolicitud
                  AND FCCREDITOCARTERA = psCredito
                  AND STATUS = 'A' AND CT.FCPAGODOBLE = 'S'
                  AND (IDGASTOMAIN) IN (SELECT IDGASTOMAIN
                                          FROM FACTURACIONBITACORA
                                         WHERE IDGASTOMAIN != pnSolicitud
                                           AND (IDGASTOMAIN,DEL_INDEX) IN (SELECT IDGASTOMAIN,MAX(DEL_INDEX)
                                                               FROM FACTURACIONBITACORA
                                                              WHERE IDGASTOMAIN != pnSolicitud
                                                                AND IDTASKGASTO NOT IN ('974392365525c7af897e890053564163','8433500185372a3c766b298052315707')
                                                           GROUP BY IDGASTOMAIN)
                                        )
                   AND (IDGASTOMAIN,psCuentaContable,FA.IDCONCEPTO) IN (SELECT IDGASTOMAIN,FCCUENTACONTABLE,IDCONCEPTO FROM FACTURACIONMAIN WHERE FCSTATUS != 'Z')
                   AND (IDGASTOMAIN, FNIMPORTE) NOT IN (SELECT IDGASTOMAIN, FNIMPORTE FROM FACTURACIONCOMPROBA WHERE FCTIPOCOMPROBANTE IN ('Ficha de Deposito','Descuento de nomina'));
            END IF;
            --////// Validamos los pagos dobles de Pago de servicios
            IF (esPagoServicio > 0 AND esPagoDoble > 0) THEN
                 fecha_pago_ini := TO_DATE(psFechaPgoIni,'DD-MM-YYYY');
                 fecha_pago_fin := TO_DATE(psFechaPgoFin,'DD-MM-YYYY');

                 FOR regSalida IN cuCreditosPagados LOOP
                     IF (fecha_pago_ini <= regSalida.FDFECSERVPAGADODEL AND regSalida.FDFECSERVPAGADODEL <= fecha_pago_fin )
                        OR (fecha_pago_ini <= regSalida.FDFECSERVPAGADOAL AND regSalida.FDFECSERVPAGADOAL <= fecha_pago_fin)
                        THEN
                        pnPagoDoblePM := pnPagoDoblePM + 1;
                     EXIT;
                     END IF;
                 END LOOP;

                 FOR regSalida IN cuCreditosPagadosSinFechas LOOP
                        pnPagoDoblePM := pnPagoDoblePM + 1;
                 END LOOP;

             END IF;
            pnPagoDoble := pnPagoDobleDYN + pnPagoDoblePM;

            SELECT COUNT (1)
              INTO existeConc
              FROM FACTURACIONMAIN
             WHERE IDGASTOMAIN = pnSolicitud AND IDCONCEPTO = pnConcepto;

            IF (UPPER (queOperacion) = 'TRAMITE')
            THEN
               pnActimporte :=
                  CASE WHEN esTramFact = 'S' THEN pnImporte ELSE 0 END;
            ELSE
               pnActimporte := pnImporte;
            END IF;

            queColaEs1 := NULL;
            queEstatusEs1 := NULL;

            --***************************************************************
            --*******************
            ---******   REVISA  SI ESTA LIQUIDADO VALIDA SOBRE ESTATUS VALIDOS EL CREDITO *****
            --**********************************************************************************
            IF (psTipomovto = 2 OR psTipomovto = 3)
            THEN                                        /* SI ES UN CREDITO */
               SELECT FCCREDITOSTATUS, FCCREDITOCOLA
                 INTO permiteStatus, permiteCola
                 FROM CTCATALOGOCUENTAS
                WHERE IDCONCEPTO = pnConcepto;

               --- Obtiene el status del Credito
               BEGIN
                   SELECT NVL (U1STATUS, U2STATUS)
                     INTO queEstatusEs
                     FROM RCVRY.DELQMST DM
                          LEFT JOIN RCVRY.UDA1 UD1 ON (DM.DMACCT = UD1.U1ACCT)
                          LEFT JOIN RCVRY.UDA2 UD2 ON (DM.DMACCT = UD2.U2ACCT)
                    WHERE DM.DMACCT = psCredito;
               EXCEPTION WHEN OTHERS THEN
                 queEstatusEs := NULL;
               END;
               --- Obtiene la COLA del credito
               BEGIN
                   SELECT NVL (DMQUE, '')
                     INTO queColaEs
                     FROM RCVRY.DELQMST DM
                    WHERE DM.DMACCT = psCredito;
               EXCEPTION WHEN OTHERS THEN
                 queColaEs := NULL;
               END;
               --- Verifica si el Estatus debe obligarse a que se Autorice
               IF (INSTR (permiteStatus || '|', queEstatusEs || '|') > 0)
               THEN
                  queEstatusEs1 := queEstatusEs;
               ELSE
                  queEstatusEs1 := NULL;
               END IF;

               IF (INSTR (permiteCola || '|', queColaEs || '|') > 0)
               THEN
                  queColaEs1 := queColaEs;
               ELSE
                  queColaEs1 := NULL;
               END IF;
            END IF;

            --- OBTENEMOS PROJECT MANAGER DEL CREDITO/CARTERA

            IF (suCArtera IS NOT NULL)
            THEN
                SELECT IMPM INTO correoProjMang FROM PENDUPM.CTCARTERA WHERE NMCARTERA LIKE suCArtera;
            END IF;

DBMS_OUTPUT.PUT_LINE ( 'DEVMK00: '||psError );

            IF (psError = '0' OR psError = '' OR psError is null ) THEN

               --  VERIFICA SI EXISTE EN ASIGNACION, SE AJUSTA PARA QUE ACTUALICE
               SELECT COUNT(1) INTO exiteEnAsigna
                 FROM FACTURAASIGNACION
                WHERE IDGASTOMAIN = pnSolicitud AND FCCREDITOCARTERA = psCredito AND IDCONCEPTO = pnConcepto;

               IF (  exiteEnAsigna = 0 OR psTipomovto = 42 OR psTipomovto = 4) THEN

DBMS_OUTPUT.PUT_LINE ( 'DEVMK05' );

                   /*  2 X CREDITO  2 X CRED MULT  4 X CARTERA  42 IMP GENERAL  */
                   INSERT INTO FACTURAASIGNACION(IDGASTOMAIN,IDCONCEPTO,IDTIPOMOVTO,FCCREDITOCARTERA,FCUSUARIO,FDFECREGISTRO,FCDETALLECAMPOS,
FNIMPORTE,FCCOMENTARIOS,FCQUEUMBRAL,FNUMBRAL,FNUMBRALREBASADO,FNPAGODOBLE,VERETAPACDACHK,VERETAPACDACHKNO,
VERETAPAABIERTA,VERETAPAABIERTANO,FCCODACCEXT,FCCODACCEXTNO,FCCODRESEXT,FCCODRESEXTNO,VERETAPAFIN,
VERETAPAFINVAL,FNIMPORTECOMPROBA,FDFECCOMPROBA,FCCENTROCOSTOS,FCDETALLECREDITO,FCESFACTURABLE,FCDYNAMICS,
FCRESETAFINAL,FCUSUJFEINMED,FCRESULTJFEINMED,FCUSUUMBRAL03,FCUSUUMBRAL04,FCUSUUMBRAL05,FCJUSTIFICACIONUMBRAL,
FCRESUMBRAL03,FCRESUMBRAL04,FCRESUMBRAL05,FCUSUETAPA01,FCUSUETAPA02,FCJUSTIFICAETAPA,FCJUSTIFICACODIGOS,
FCRESETAPA01,FCRESETAPA02,FCUSUPGODBL01,FCUSUPGODBL02,FCJUSTIFICAPAGODBL,FCRESPGODBL01,FCRESPGODBL02,
FDULTFECACTUALIZA,FCUSUEMPRESA,FCJUSTIFICAEMPRESA,FCRESEMPRESA,FCUSUURGENTE,FCJUSTIFICAURGENTE,FCRESURGENTE,
FCUSUEXCGASTO01,FCUSUEXCGASTO02,FCJUSTIFICAEXCGASTO,FCRESEXCGASTO01,FCRESEXCGASTO02,FCUSUETAFINAL01,
FCUSUETAFINAL02,FCJUSTIFICETAFINAL,FCRESETAFINAL01,FCRESETAFINAL02,FCUSULIQUIDADO01,FCUSULIQUIDADO02,
FCJUSTIFICALIQ,FCRESLIQ01,FCRESLIQ02,FCCREDSTATUS,FCCREDCOLA,IDCOMPROBACION,FCUSUPM,FDFECSERVPAGADODEL,FDFECSERVPAGADOAL,
FCUSUJEFEINMEDIATO,FCUSUNOFACTURABLE,FCUSUUMBRAL1,FCUSUUMBRAL2,FCUSUUMBRAL3,FCUSUEXCEDENTE1,FCUSUEXCEDENTE2,
FCUSUETAPAABIERTA, FCUSUETAPACERRADA, FCUSUETAPAFIN1, FCUSUETAPAFIN2, FCUSUPAGODOBLE1, FCUSUPAGODOBLE2,
FCUSUDOCSOPORTE1, FCUSUDOCSOPORTE2, FCUSUDOCSOPORTE3, FCJUSTIFICACIONALERTA, IDPLANVIAJE, FCESREEMBOLSABLE )
                        VALUES (pnSolicitud,
                                pnConcepto,
                                unificaCredito,
                                psCredito,
                                usuSolic,
                                SYSDATE,
                                NULL,
                                pnActimporte,
                                cadenaArma,
                                pnQueUmbral,
                                importeUmbral,
                                queUmbralRebaso,
                                pnPagoDoble,
                                psCatEtaCraVer,
                                queEtapaCRAVER,
                                psCatEtaAbi,
                                queEtapaABTA,
                                psCatCodAcc,
                                queCodAccion,
                                psCatCodRes,
                                queCodResultado,
                                psCatEtaFinal,
                                NULL,
                                0,
                                NULL,
                                vsCentroCostos,
                                cadenaArma,
                                esFacturable,
                                idDynamics,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                queEstatusEs1,
                                queColaEs1,NULL,
                                correoProjMang,
                                TO_DATE(psFechaPgoIni, 'DD/MM/YYYY'),
                                TO_DATE(psFechaPgoFin, 'DD/MM/YYYY'),
                                usujefeinmediato,
                                usunofacturable,
                                usuumbral1,
                                usuumbral2,
                                usuumbral3,
                                usuexcedente1,
                                usuexcedente2,
                                usuetapaabierta,
                                usuetapacerrada,
                                usuetapafin1,
                                usuetapafin2,
                                usupagodoble1,
                                usupagodoble2,
                                usudocsoporte1,
                                usudocsoporte2,
                                usudocsoporte3, NULL, NULL, esReebolsable
                                );

               ELSE

                   UPDATE FACTURAASIGNACION SET FDFECREGISTRO = SYSDATE,            FNIMPORTE = pnActimporte,
                                                FCCOMENTARIOS =  cadenaArma,        FCQUEUMBRAL =pnQueUmbral,
                                                FNUMBRAL =   importeUmbral ,        FNUMBRALREBASADO = queUmbralRebaso,
                                                FNPAGODOBLE =  pnPagoDoble        , VERETAPACDACHK =psCatEtaCraVer,
                                                VERETAPACDACHKNO = queEtapaCRAVER , VERETAPAABIERTA =psCatEtaAbi,
                                                VERETAPAABIERTANO =   queEtapaABTA, FCCODACCEXT =psCatCodAcc,
                                                FCCODACCEXTNO =  queCodAccion     , FCCODRESEXT =psCatCodRes,
                                                FCCODRESEXTNO =  queCodResultado  , VERETAPAFIN =psCatEtaFinal,
                                                FCCENTROCOSTOS =  vsCentroCostos  , FCDETALLECREDITO =cadenaArma,
                                                FCESFACTURABLE =  esFacturable    , FCDYNAMICS = idDynamics,
                                                FCCREDSTATUS = queEstatusEs1      , FCCREDCOLA = queColaEs1,
                                                FCESREEMBOLSABLE = esReebolsable
                    WHERE IDGASTOMAIN = pnSolicitud AND FCCREDITOCARTERA = psCredito AND IDCONCEPTO = pnConcepto;


               END IF;

            END IF;
         ELSE
            IF (psTipomovto = 2 OR psTipomovto = 3)
            THEN
               psError :=
                     'El Credito '
                  || psCredito
                  || ' ya fue Registrado Previamente';
            ELSIF (psTipomovto = 4)
            THEN
               psError :=
                     'La Cartera'
                  || psCredito
                  || ' ya fue Registrado Previamente';
            ELSIF (psTipomovto = 42)
            THEN
               psError := 'El Importe General ya fue Registrado Previamente';
            ELSIF (psTipomovto = 43)
            THEN
               psError := 'El Monto Facturacion ya fue Registrado Previamente';
            END IF;
         END IF;
      ELSE
         SELECT DISTINCT (SELECT NMDESCRIPCION
                            FROM CTCATALOGOGASTOS
                           WHERE IDCATGASTO = IDTIPOMOVTO)
           INTO cualOtroTipo
           FROM FACTURAASIGNACION
          WHERE IDGASTOMAIN = pnSolicitud AND IDTIPOMOVTO != unificaCredito;

         psError :=
               'Existe el tipo de Asignacion '
            || cualOtroTipo
            || ' Debe Eliminar antes de Agregar de este nuevo tipo';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ------ROLLBACK;  FACTURACIONMAIN  CTCATALOGOCUENTAS
         psError :=
               '**ERROR CHECA ASIGNACION** --'
            || unificaCredito
            || '-'
            || psCredito
            || '-'
            || pnSolicitud
            || '-'
            || pnConcepto
            || '-'
            || pnImporte
            || '-'
            || psTipomovto
            || '-'
            || psCentroCosto
            || '****'
            || SQLERRM;

         DBMS_OUTPUT.PUT_LINE ('-1 ' || SQLERRM);
   END validaNuevoCreditoAsigna;

   FUNCTION whichDirectBoss (FCTIPOJEFEINMED VARCHAR2, IDJEFEINMEDIATO VARCHAR2, quienSolic VARCHAR2, FCJEFEINMEDIATO VARCHAR2)
   RETURN VARCHAR2
   IS
   vdEmailPgo VARCHAR2(5000);
   BEGIN
    IF (FCTIPOJEFEINMED = 'E')
    THEN
       vdEmailPgo := IDJEFEINMEDIATO;
    END IF;
    IF (FCTIPOJEFEINMED = 'T')
    THEN
       vdEmailPgo :=  PENDUPM.PCKFACTURACIONGASTO.queEmpleadoMailPuesto (IDJEFEINMEDIATO);
    END IF;
    IF (FCTIPOJEFEINMED = 'P')
    THEN
       vdEmailPgo := PENDUPM.PCKFACTURACIONGASTO.QUECORREONIVELES (quienSolic, FCJEFEINMEDIATO);
    END IF;
    RETURN(vdEmailPgo);
    EXCEPTION
      WHEN OTHERS
      THEN
         RETURN '**ERROR**';
   END whichDirectBoss;

   
   
   PROCEDURE insertCargaMasivaFactura(psUUID       VARCHAR2,
                                    psID_DOCUMENTO VARCHAR2, 
                                    psID_USUARIO   NUMBER,
                                    psNOM_USUARIO  VARCHAR2,
                                    psURL_XML      VARCHAR2, 
                                    psError        OUT VARCHAR2) IS
                                         
 
    BEGIN       
        
        INSERT INTO PENDUPM.FACARGAMASIVA ( ID_FACARGAMASIVA, UUID, ID_DOCUMENTO, FECHA_REGISTRO, ID_USUARIO, NOM_USUARIO, URL_XML)VALUES (PENDUPM.SEQ_FACARGAMASIVA.NEXTVAL, psUUID, psID_DOCUMENTO, SYSDATE, psID_USUARIO, psNOM_USUARIO, psURL_XML);
                
        psError := '1';
               
        COMMIT;
               
        -- dbms_output.put_line('psQuery ' || psQuery);
             
   EXCEPTION WHEN OTHERS THEN
       
       psError := 'error' ||SQLERRM;
       dbms_output.put_line('caso ' || pIdCaso || 'psError ' || psError);
       -- dbms_output.put_line('psQuery ' || psQuery);
       
   END insertCargaMasivaFactura;
   
   

END PCKFACTURACIONGASTO;
/
