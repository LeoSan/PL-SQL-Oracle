CREATE OR REPLACE PACKAGE PENDUPM.PCKFACTURACIONGASTO
IS
  /*
    * HISTORIAL DE CAMBIOS
    * 20160329-->MAMB--> SE VALIDAN LOS EXCEDENTES DE GASTOS, LOS COMPROBANTES DEBEN SER MAYORES QUE LO SOLICITADO
    * 20160401-->MAMB--> SI NO HAY DOCUMENTOS DE SOPORTE A VALIDAR TERMINO EL PROCESO
    * 20160405-->MAMB--> AL INICIO DE LA COMPROBACION, EL IMPORTE COMPROBADO DEBE SER CERO CAMPO FNIMPORTECOMPROBA
    * 20160518-->MAMV--> SE ACTUALIZAN LOS PROCEDIMIENTOS  validaMasivaCreditoAsigna Y validaArchivoAsigna PARA CARGAS MASIVAS DE CREDITOS
    * 20160811-->MAMB--> AJUSTE AL VALIDAR EXCEDENTE DEL GASTO, SOLO IMPORTES SIN IVA
    * 20160825-->MAMB--> VALIDACION DE PAGOS DOBLES SERVICIOS ABA
    * 20160831-->MAMV--> Se agrega ORDER BY a la funcion queConceptoGasto para evitar mostrar registros duplicados en pantallas de tesoreria.
    * 20160914-->MAMV--> Se agrega metodo para reasignacion de autorizadores.
    * 20160922-->MAMV--> Se modifica logica para la regla de autorizaciones de Etapas de Juicio.
    * 20161229-->MAMV--> Se amplia el comentario de las justificaciones a 2000 caracteres.
    * 20170113-->MAMV--> Se agrega metodo para busqueda por niveles
    */

   CURSOR cuDetalle (
      pnSolicitud    INTEGER)
   IS
      SELECT FNNUMEMPLEADO,
             A.FNNUMEMPLEADO solicitante,
             A.IDSOLICITANTE,
             '' Centrocostos,
             '' Puesto,
             (SELECT NMDESCRIP
                FROM CTCUENTACATEGORIA B
               WHERE IDCUENTACAT = (SELECT IDCATEGORIA
                                      FROM CTCATALOGOCUENTAS C
                                     WHERE C.IDCONCEPTO = A.IDCONCEPTO))
                CATEGORIA,
             (SELECT NMDESCRIP
                FROM CTCUENTACATEGORIA B
               WHERE IDCUENTACAT = (SELECT IDSUBCATEGORIA
                                      FROM CTCATALOGOCUENTAS C
                                     WHERE C.IDCONCEPTO = A.IDCONCEPTO))
                SUBCATEGORIA,
             (SELECT NMCONCEPTO
                FROM CTCATALOGOCUENTAS C
               WHERE C.IDCONCEPTO = A.IDCONCEPTO)
                NMCONCEPTO,
             CASE WHEN TPOMOVIMIENTO = 'Tramite' THEN  TPOMOVIMIENTO||' - Solucion '||NVL((SELECT FCTIPOSOLUCION  FROM FACTURATRAMITE F WHERE F.IDGASTOMAIN = A.IDGASTOMAIN),' en Proceso')
                  ELSE TPOMOVIMIENTO END  TPOMOVIMIENTO,
             FCSEVERIDADGASTO,
             CASE
                WHEN FCSEVERIDADGASTO = 'Normal' THEN ''
                WHEN FCSEVERIDADGASTO = 'Urgente' THEN ''
                ELSE PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA)
             END
                FECREQUERIDA,
            (SELECT NMEMPRESA
              FROM EMPRESAFACTURACION
             WHERE IDEMPRESA = CASE
                      WHEN A.IDEMPRESAFACTURACION = 0 THEN A.IDOTEMPRESAFACTURACION
                      WHEN (A.IDEMPRESAFACTURACION != 0 OR A.IDEMPRESAFACTURACION IS NOT NULL) THEN A.IDEMPRESAFACTURACION
                      END
             )  EMPFACTURA,
             (SELECT NMDESCRIPCION
                FROM CTCATALOGOGASTOS G
               WHERE G.IDCATGASTO = A.IDFORMAPAGO)||' - '||
               (SELECT NMPROVEEDOR FROM CTPROVEEDORGASTO F WHERE F.IDPROVEEDORGTO = A.IDPROVEEDORDEPOSITO )||
                          CASE WHEN A.IDFORMAPAGO = 38 THEN '<BR/>A nombre de : '||A.FCNMPAGOCHQCAJA END
                FORMAPAGO,
             CASE WHEN FCTIPOCUENTA = '1' THEN 'Fiscal' ELSE 'No Fiscal' END TPOCUENTA,    
             FCCOMENTARIOSOLICITUD COMENTARIOS,
             PCKENVIOCORREO.detalleAsigCred (a.IDGASTOMAIN, 1) ASIGNACIONCRED,
             PCKENVIOCORREO.detalleAsigCred (a.IDGASTOMAIN, 2)
                ASIGNACIONCARTERA,
             PCKCONVENIOS.formatComas (NVL (FNIMPORTESOLICITADO, 0))
                IMPSOLICITADO,
             CASE WHEN (NVL (FNIMPORTEANTICIPO, 0) = 0 ) THEN 'NO REALIZADO' ELSE PCKCONVENIOS.formatComas (NVL(FNIMPORTEANTICIPO,0)) END ANTICIPO,
             --PCKCONVENIOS.formatComas ( NVL (FNIMPORTEANTICIPO, 0) ) ANTICIPO,
             PCKCONVENIOS.formatComas (NVL (FNIMPORTEREEMBOLSO, 0)) REEMBOLSO,
             (SELECT PCKENVIOCORREO.aplFecha (  FDFECDERIVACION
                                              + (SELECT MAX(TIEMPOMAXCOMPROBA) DIAS FROM PENDUPM.CTCATALOGOCUENTAS CT
                                                INNER JOIN PENDUPM.FACTURACIONMAIN FM ON CT.IDCONCEPTO = FM.IDCONCEPTO 
                                                WHERE IDGASTOMAIN = pnSolicitud))
                FROM FACTURACIONDEPOSITO X
               WHERE IDGASTOMAIN = pnSolicitud AND FNCONSEC = 2 AND FCSTATUS = 'A')
                FECCOMPDEP,
             FCASIGNADEPOSITO DEPOSITAA,
             IDPROVEEDORDEPOSITO CVEDYN,
            (SELECT NMEMPRESA
              FROM EMPRESAFACTURACION
             WHERE IDEMPRESA = CASE
                      WHEN A.IDEMPRESAFACTURACION = 0 THEN A.IDOTEMPRESAFACTURACION
                      WHEN (A.IDEMPRESAFACTURACION != 0 OR A.IDEMPRESAFACTURACION IS NOT NULL) THEN A.IDEMPRESAFACTURACION
                      END
             )  EMPRESAFACT,
             PCKENVIOCORREO.aplFecha (FDDYNAMICSGASTO) FECHADEPOSITOANT,
             CASE
                WHEN IDFORMAPAGO = 39
                THEN
                   PCKENVIOCORREO.aplFecha (FDDYNAMICSGASTOCONF)
                ELSE
                   ''
             END
                FECHACONFIRMACIONANT,
             PCKENVIOCORREO.aplFecha (FDDYNAMICSREEMB) FECHADEPOSITOREM,
             CASE
                WHEN IDFORMAPAGO = 39
                THEN
                   PCKENVIOCORREO.aplFecha (FDDYNAMICSREEMBCONF)
                ELSE
                   ''
             END
                FECHACONFIRMACIONREM,
             (SELECT FCNOMBRE || ' - ' || NVL (IDPROVEEDORGTO, '----')
                FROM FACTURACIONDEPOSITO X
               WHERE IDGASTOMAIN = pnSolicitud AND FNCONSEC = 2 AND FCSTATUS = 'A')
                QUIENDEPOSITODEP,
             (SELECT IDEMPRESA
                FROM FACTURACIONDEPOSITO X
               WHERE IDGASTOMAIN = pnSolicitud AND FNCONSEC = 2 AND FCSTATUS = 'A')
                EMPRESADEP,
             NVL ( (SELECT FCREFERENCIA
                      FROM FACTURACIONDEPOSITO X
                     WHERE IDGASTOMAIN = pnSolicitud AND FNCONSEC = 2 AND FCSTATUS = 'A'),
                  '')
                REFERENCIADEP,
             (SELECT PCKENVIOCORREO.aplFecha (FDFECREGISTRO)
                FROM FACTURACIONDEPOSITO X
               WHERE IDGASTOMAIN = pnSolicitud AND FNCONSEC = 2 AND FCSTATUS = 'A')
                FECAPLDEP,
             (SELECT FCUSUARIOAPLICA
                FROM FACTURACIONDEPOSITO X
               WHERE IDGASTOMAIN = pnSolicitud AND FNCONSEC = 2 AND FCSTATUS = 'A')
                QUIENLOHIZODEP,
             PCKENVIOCORREO.aplFecha (FDDYNAMICSGASTOCONF) FECCONFDEP,
             (SELECT IDEMPRESA
                FROM FACTURACIONDEPOSITO X
               WHERE IDGASTOMAIN = pnSolicitud AND FNCONSEC = 6 AND FCSTATUS = 'A')
                EMPRESAREE,
             NVL ( (SELECT FCREFERENCIA
                      FROM FACTURACIONDEPOSITO X
                     WHERE IDGASTOMAIN = pnSolicitud AND FNCONSEC = 6 AND FCSTATUS = 'A'),
                  '')
                REFERENCIAREE,
             (SELECT PCKENVIOCORREO.aplFecha (FDFECREGISTRO)
                FROM FACTURACIONDEPOSITO X
               WHERE IDGASTOMAIN = pnSolicitud AND FNCONSEC = 6 AND FCSTATUS = 'A')
                FECAPLREE,
             (SELECT FCUSUARIOAPLICA
                FROM FACTURACIONDEPOSITO X
               WHERE IDGASTOMAIN = pnSolicitud AND FNCONSEC = 6 AND FCSTATUS = 'A')
                QUIENLOHIZOREE,
             (SELECT PCKENVIOCORREO.aplFecha (FDFECDERIVACION)
                FROM FACTURACIONDEPOSITO X
               WHERE IDGASTOMAIN = pnSolicitud AND FNCONSEC = 6 AND FCSTATUS = 'A')
                FECCONFREE,
             (SELECT FCNOMBRE || ' - ' || NVL (IDPROVEEDORGTO, '----')
                FROM FACTURACIONDEPOSITO X
               WHERE IDGASTOMAIN = pnSolicitud AND FNCONSEC = 6 AND FCSTATUS = 'A')
                QUIENDEPOSITOREE,
             PCKENVIOCORREO.aplFecha (FDFECREGISTRO) FECREG,
             (SELECT MAX(NMETAPA)
                FROM FACTURACIONBITACORA H
               WHERE     H.IDGASTOMAIN = pnSolicitud
                     AND (H.IDGASTOMAIN,DEL_INDEX) = (SELECT IDGASTOMAIN,MAX (DEL_INDEX)
                                        FROM FACTURACIONBITACORA H
                                       WHERE H.IDGASTOMAIN = pnSolicitud
                                     GROUP BY IDGASTOMAIN))
                ESTAEN,
             CASE
                WHEN DELINDEX_ETAPA = 1
                THEN
                   '<font color="red">BORRADOR</font>'
                WHEN DELINDEX_ETAPA > 1 AND FCSTATUS = 'Z'
                THEN
                   '<font color="red">CANCELADO</font>'
                WHEN DELINDEX_ETAPA > 1 AND FCSTATUS = 'F'
                THEN
                   '<font color="red">FINALIZADO</font>'
                WHEN DELINDEX_ETAPA > 1 AND FCSTATUS NOT IN ('Z', 'F')
                THEN
                   '<font color="red">EN SOLUCION</font>'
                WHEN DELINDEX_ETAPA IS NULL
                THEN
                   CASE
                      WHEN FCSTATUS = 'F'
                      THEN
                         '<font color="red">FINALIZADO</font>'
                      WHEN FCSTATUS = 'Z'
                      THEN
                         '<font color="red">CANCELADO</font>'
                      ELSE
                         '<font color="red">EN SOLUCION</font>'
                   END
             END
                STATGASTO
        FROM FACTURACIONMAIN A
       WHERE     IDGASTOMAIN = pnSolicitud
             AND FDFECREGISTRO = (SELECT MIN (FDFECREGISTRO)
                                    FROM FACTURACIONMAIN A
                                   WHERE IDGASTOMAIN = pnSolicitud);

   TYPE TESORERIA IS RECORD
   (
      rIdGasto      GASTOMAIN.IDGASTO%TYPE,
      rDepositaA    VARCHAR2 (10),       /* Id Clave Dyn a quien se deposita*/
      rQueCuenta    VARCHAR2 (20),        /* Cuenta Bancaria */
      rQueBanco     VARCHAR2 (10),        /* Que banco */
      rQueRefer     VARCHAR2 (30),        /* Numero de Cheque  */
      rNombre       VARCHAR2 (150),       /* nombre del a quien se deposita */
      rRfc          VARCHAR2 (20),        /* rfc del a quien se deposita */
      rImporte      NUMBER (15, 2),       /* importe del gasto */
      rEmpFactura   VARCHAR2 (10),        /* Empresa que Factura */
      rIdApp        VARCHAR2 (50),        /* id del gasto APP_UID*/
      rIdTask       VARCHAR2 (50),        /* id del gasto TASK_UID*/
      rIdDelindex   INTEGER,              /* id del gasto DEL_INDEX*/
      rIdQuemovto   VARCHAR2 (10),        /* id del gasto DEL_INDEX*/
      rCuentaDepo   VARCHAR2 (20)         /*  Cuenta del Combo tranf elect */
   );

   TYPE TABGTOTESORERIA IS TABLE OF TESORERIA
      INDEX BY BINARY_INTEGER;

   TYPE T_CURSOR IS REF CURSOR;

   TYPE VALORCONCATENA IS RECORD
   (
      rIdValor   VARCHAR2 (90),
      rNMValor   VARCHAR2 (300)
   );

   TYPE TABVALORCONCATENA IS TABLE OF VALORCONCATENA;

   TBLVALORCONCATENA      TABVALORCONCATENA;

   TYPE ASIGNACOMP IS RECORD
   (
      rIdGasto      NUMBER (15),
      rConcepto     NUMBER (15),
      rCredito      VARCHAR2 (30),
      rImporteCom   NUMBER (15, 2),
      rComprobanteId NUMBER (15),
      rFechaComproba VARCHAR2 (30)
   );

   TYPE TABASIGNACOMP IS TABLE OF ASIGNACOMP
      INDEX BY BINARY_INTEGER;

   TBLASIGNACOMP          TABASIGNACOMP;

   TYPE DOCTOINI IS RECORD
   (
      rIdGasto       NUMBER (15),
      rconsecutivo   NUMBER (15),
      rArchivo       VARCHAR2 (255), /* LW  IDDOCTO    AGREGAR  NOMBRE ARCHIVO */
      rRuta          VARCHAR2 (255),
      rQueEs         CHAR (1)                /* 1 LW   2  AGREGAR NUEVOFILE */
   );

   TYPE TABDOCTOINI IS TABLE OF DOCTOINI
      INDEX BY BINARY_INTEGER;

   TBLDOCTOINI            TABDOCTOINI;

   TYPE DOCTOSOPORTE IS RECORD
   (
      rIdGasto       NUMBER (15),
      rconsecutivo   NUMBER (15),
      rArchivo       VARCHAR2 (255), /* LW  IDDOCTO    AGREGAR  NOMBRE ARCHIVO */
      rRuta          VARCHAR2 (255),
      rQueEs         CHAR (1)                /* 1 LW   2  AGREGAR NUEVOFILE */
   );

   TYPE TABDOCTOSOPORTE IS TABLE OF DOCTOSOPORTE
      INDEX BY BINARY_INTEGER;

   TBLDOCTOSOPORTE        TABDOCTOSOPORTE;

   TYPE VERIFDOCTOSOPORTE IS RECORD
   (
      rIdGasto       NUMBER (15),
      rconsecutivo   NUMBER (15),
      rResultado     VARCHAR2 (25),
      rComentario    VARCHAR2 (500)
   );

   TYPE TABVERIFDOCTOSOPORTE IS TABLE OF VERIFDOCTOSOPORTE
      INDEX BY BINARY_INTEGER;

   TBLVERIFDOCTOSOPORTE   TABVERIFDOCTOSOPORTE;

   TYPE JUSTIFICAALERTA IS RECORD
   (
      rIdGasto      NUMBER (15),
      rConcepto     NUMBER (15),
      rAlerta       NUMBER (15),
      rCredito      VARCHAR2 (40),
      rComentario   VARCHAR2 (1999),
      rFechaRegistro VARCHAR2 (30)
   );

   TYPE TABJUSTIFICAALERTA IS TABLE OF JUSTIFICAALERTA
      INDEX BY BINARY_INTEGER;

   TBLJUSTIFICAALERTA     TABJUSTIFICAALERTA;

   TYPE AUTORIZAALERTA IS RECORD
   (
      rIdGasto     NUMBER (15),
      rAlerta      NUMBER (15),
      rConcepto    NUMBER (15),
      rCredito     VARCHAR2 (40),
      rResultado   VARCHAR2 (15)
   );

   TYPE TABAUTORIZAALERTA IS TABLE OF AUTORIZAALERTA
      INDEX BY BINARY_INTEGER;

   TBLAUTORIZAALERTA      TABAUTORIZAALERTA;

   FUNCTION queUsuarioMail (psEmail VARCHAR2)
      RETURN INTEGER;

   FUNCTION queEmpleadoMail (pnUsuario INTEGER)
      RETURN VARCHAR2;

   FUNCTION queEmpleadoMailPuesto (quePuesto INTEGER)
      RETURN VARCHAR2;

   FUNCTION queCorreoAutoriza (gasto INTEGER, puesto INTEGER)
      RETURN VARCHAR2;

   FUNCTION queCorreoNiveles (pnUsuario INTEGER, puntos INTEGER)
      RETURN VARCHAR2;

   PROCEDURE addConceptoGasto (pnCaso             INTEGER,
                               pnconcepto         INTEGER,
                               psQueTramite       VARCHAR2,
                               quienSolic         INTEGER,
                               queUsuPM           VARCHAR2,
                               quetipoEs          VARCHAR2,
                               psAPPUID           VARCHAR2,
                               psSalida       OUT VARCHAR2);

   PROCEDURE delConceptoGasto (pnCaso           INTEGER,
                               pnconcepto       INTEGER,
                               psSalida     OUT VARCHAR2);

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
                                estructurajer       VARCHAR2);

   PROCEDURE setAutAdicionales (pnCaso              INTEGER,
                                quienSolic          INTEGER,
                                psCadenaEjecuta     VARCHAR2,
                                psIdTask            VARCHAR2 DEFAULT '1',
                                psDelindex          INTEGER DEFAULT 1,
                                psTipomovimiento    VARCHAR2);

   PROCEDURE getChequeCatalogo (salida IN OUT T_CURSOR);

   PROCEDURE getChequesAnticipo (queCheque          INTEGER DEFAULT 0,
                                 salida      IN OUT T_CURSOR,
                                 pnEmpFact          INTEGER);

   PROCEDURE setAplicaTesoreria (
      arrDetalle       PCKFACTURACIONGASTO.TABGTOTESORERIA,
      psQueEtapa       VARCHAR2,    /* [AN] ANTICIPO   [RE]  REEMBOLOS/PAGO */
      pstipoPago       INTEGER, /* [37-38-39] CHEQUE    [36]  TRANSFERENCIA  [40]  SERVICIOS */
      usuSolic         VARCHAR2,
      psError      OUT VARCHAR2); /* si es -1 ES ERRONEO, cual quier otra cosa es EL FOLIO DE CONTROL */

   PROCEDURE getDerivaCasos (pnControl INTEGER, salida IN OUT T_CURSOR);

   PROCEDURE getTransAnticipo (salida IN OUT T_CURSOR, pnEmpFact INTEGER);

   PROCEDURE getConfTransAnticipo (salida IN OUT T_CURSOR, pnEmpFact INTEGER);

   PROCEDURE setConfTransAnticipo (psGastos         VARCHAR2,
                                   usuSolic         VARCHAR2,
                                   queFolioEs       VARCHAR2,
                                   psError      OUT VARCHAR2,
                                   pnempresaFact    INTEGER);

   PROCEDURE getArchivoPoliza (salida IN OUT T_CURSOR, pnEmpFact INTEGER);

   PROCEDURE setArchivoPoliza (psGastos       VARCHAR2,
                               usuSolic       VARCHAR2,
                               psError    OUT VARCHAR2);


   PROCEDURE getChequesReembolso (queCheque          INTEGER DEFAULT 0,
                                  pnEmpFact          INTEGER,
                                  salida      IN OUT T_CURSOR);


   PROCEDURE getTransReembolso (salida IN OUT T_CURSOR, pnEmpFact INTEGER);


   PROCEDURE getCIEReembolso (salida IN OUT T_CURSOR, pnEmpFact INTEGER);


   PROCEDURE setDoctoSoporte (pnCaso             INTEGER,
                              quienSolic         INTEGER,
                              psCadenaEjecuta    VARCHAR2,
                              psIdTask           VARCHAR2 DEFAULT '1',
                              psDelindex         INTEGER DEFAULT 1);

   PROCEDURE setUmbralTramite (pnCaso             INTEGER,
                               quienSolic         INTEGER,
                               psCadenaEjecuta    VARCHAR2,
                               psIdTask           VARCHAR2 DEFAULT '1',
                               psDelindex         INTEGER DEFAULT 1);

   PROCEDURE setDoctoExcGtoEtaFinal (pnCaso             INTEGER,
                                     quienSolic         INTEGER,
                                     psCadenaEjecuta    VARCHAR2,
                                     psIdTask           VARCHAR2 DEFAULT '1',
                                     psDelindex         INTEGER DEFAULT 1,
                                     donde              VARCHAR2, /* COMPROBACION  / TRAMITE */
                                     queProcesa         VARCHAR2); /* Anticipo  /  Reembolso  */

   PROCEDURE getEmpresaFact (salida IN OUT T_CURSOR);

   PROCEDURE getEmpresaFactChq (pnEmpresa  INTEGER, salida IN OUT T_CURSOR);

   PROCEDURE getEmpresaCIE (salida IN OUT T_CURSOR);

   PROCEDURE getArchSPEI (psUsuario VARCHAR2, salida IN OUT T_CURSOR);

   PROCEDURE getArchPOLIZADyn (psUsuario VARCHAR2, salida IN OUT T_CURSOR);

   FUNCTION queConceptoGasto (pnGasto INTEGER)
      RETURN VARCHAR2;

   PROCEDURE getHistGastos (pncualDetalle          INTEGER,
                            salida          IN OUT T_CURSOR,
                            queusuario             INTEGER DEFAULT NULL);

   PROCEDURE getMisGestiones (salida          IN OUT T_CURSOR,
                              queusuario             INTEGER DEFAULT NULL);

   PROCEDURE getReasignacion (salida IN OUT T_CURSOR, pnGasto  INTEGER);

   PROCEDURE getCancelacion (salida IN OUT T_CURSOR, pnGasto  INTEGER);

   PROCEDURE setReasignacion (pnGasto            INTEGER,
                              psaQuien           VARCHAR2, /* nombre del usuario */
                              psEmailQuien       VARCHAR2, /* email del usuario */
                              noTicket           VARCHAR2,
                              indexEtapa         INTEGER,
                              quienEsta          VARCHAR2,
                              usuSolic           VARCHAR2,
                              comentario         VARCHAR2,
                              psError        OUT VARCHAR2);

   PROCEDURE setCancelacion (pnGasto            INTEGER,
                             psQuienSol         VARCHAR2, /* nombre del usuario */
                             psEmailQuien       VARCHAR2, /* email del usuario */
                             noTicket           VARCHAR2,
                             indexEtapa         INTEGER,
                             quienEsta          VARCHAR2,
                             usuSolic           VARCHAR2,
                             comentario         VARCHAR2,
                             psError        OUT VARCHAR2);

   PROCEDURE setSolicitudDocInicio (pnCaso INTEGER, psCadenaEjecuta VARCHAR2);

   PROCEDURE setSolicitudDocSoporte (pnCaso             INTEGER,
                                     psCadenaEjecuta    VARCHAR2);

   PROCEDURE getLimiteCredito (pnSolicitud        INTEGER,
                               psUbicacion        VARCHAR2, /* Registro Solicitud, Rechazo Autorizacion, Pago x Tramite, Rechazo de Tramite, finalizado */
                               psUsuario          VARCHAR2,
                               psCadenaEjecuta    VARCHAR2);

   ---- Valida que SOLO se puedan agregar conceptos de un solo tipo
   PROCEDURE validaTipoMovimiento (pnSolicitud       INTEGER,
                                   psTipomovto       INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL */
                                   psError       OUT VARCHAR2);

   ---- Elimina los movimientos de la Asignacion Previa
   PROCEDURE borraAsignacionsolic (pnSolicitud       INTEGER,
                                   pnConcepto        INTEGER,
                                   psCredito         VARCHAR2,
                                   psError       OUT VARCHAR2);

   ---- Obtiene los Conceptos de la Solicitus+d
   PROCEDURE getConceptosolicitud (pnSolicitud          INTEGER,
                                   psTipomovto          INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL */
                                   salida        IN OUT T_CURSOR);

   ----  Obtiene las Categorias para Asignacion de CC en no credito
   PROCEDURE getCategoriaCC (salida IN OUT T_CURSOR);

   ---- Obtiene los CC  de las categorias de Centro de costos
   PROCEDURE getCCsolic (pnCategoria VARCHAR2, salida IN OUT T_CURSOR);

   FUNCTION getValorConcatenado (psCadena VARCHAR2)
      RETURN TABVALORCONCATENA
      PIPELINED;

   ---- recupera cadena para ejecucion en pantalla inicio y soporte
   FUNCTION getValorArchIniSop (pnConsecutivo INTEGER, cualEs VARCHAR2)
      RETURN VARCHAR2;

   ---- regresacadena separada para mostrar los archivos concatenados
   FUNCTION getValorArchIniSopUnif (pnConsecutivo INTEGER, cualEs VARCHAR2)
      RETURN VARCHAR2;

   ---- Obtiene las Carteras Validas para el Concepto
   PROCEDURE getCarteraConcepto (pnConcepto INTEGER, salida IN OUT T_CURSOR);

   --- Recupera los Tipos de movimientos para los Conceptos
   PROCEDURE getTipomovimiento (pnSolicitud INTEGER, salida IN OUT T_CURSOR);

   --- Regresa el Detalle del Gris de la Pantalla de Asignacion
   PROCEDURE getDetalleAsignacion (pnSolicitud          INTEGER,
                                   salida        IN OUT T_CURSOR);

   ---- Procedimiento General para Valida el Alta de Asignacion de cualquier tipo
   PROCEDURE validaCreditoAsigna (pnSolicitud         INTEGER,
                                  psCredito           VARCHAR2, /* SI  es psTipomovto = 4 [valor CARTERA]  psTipomovto = 42 [CONCEPTO ]*/
                                  pnConcepto          NUMBER,
                                  pnImporte           NUMBER,
                                  psTipomovto         INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL */
                                  psCentroCosto       VARCHAR2, /* Solo valido si es CArtera ? Importe General */
                                  psFechaPgoIni       VARCHAR2,
                                  psFechaPgoFin       VARCHAR2,
                                  idplanviaje        NUMBER,
                                  psError         OUT VARCHAR2);

   ---- inserta una Asignacion por credito individual y multiple
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
                               psError        OUT VARCHAR2);

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
                               psError         OUT VARCHAR2);

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
                               psError         OUT VARCHAR2);

   PROCEDURE addimporteFactura (pnSolicitud         INTEGER,
                                pnConcepto          NUMBER,
                                pnImporte           NUMBER,
                                psQueTramite        VARCHAR2,
                                psTipomovto         INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL [43] X IMP FACTURACION*/
                                quienSolic          INTEGER,
                                queUsuPM            VARCHAR2,
                                psAPPUID            VARCHAR2,
                                psCentroCosto       VARCHAR2,
                                psError         OUT VARCHAR2);

   PROCEDURE validaArchivoAsigna (pnSolicitud          INTEGER,
                                  pnConcepto           NUMBER,
                                  psQueTramite         VARCHAR2,
                                  psTipomovto          INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL [43] X IMP FACTURACION*/
                                  psNmFile             VARCHAR2,
                                  quienSolic           INTEGER,
                                  queUsuPM             VARCHAR2,
                                  psAPPUID             VARCHAR2,
                                  psError          OUT VARCHAR2,
                                  psTotRegistros   OUT INTEGER);
                                  
  

   PROCEDURE validaMasivaCreditoAsigna (pnSolicitud       INTEGER,
                                        psTipomovto       INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL */
                                        psNmFile          VARCHAR2,
                                        psError       OUT VARCHAR2);

   PROCEDURE getDetPagodoble (pnSolicitud           INTEGER,
                              pnConcepto            NUMBER,
                              psCredito             VARCHAR2,
                              salida         IN OUT T_CURSOR);

   PROCEDURE getObtenPagodoble (pnSolicitud           INTEGER,
                                pnConcepto            NUMBER,
                                psCredito             VARCHAR2,
                                salida         IN OUT T_CURSOR);

   --- Regresa el Detalle del Gris de la Pantalla de Asignacion
   PROCEDURE getDetalleParaComproba (pnSolicitud          INTEGER,
                                     salida        IN OUT T_CURSOR);

   --- Guarda el Detalle del Importe comprobado en el sistema
   PROCEDURE setAsignacomprobacion (
      arrDetalle       PCKFACTURACIONGASTO.TABASIGNACOMP,
      psError      OUT VARCHAR2);

   FUNCTION siExisteArchivo (psFileName VARCHAR2)
      RETURN VARCHAR2;

   -- Regresa si la etapa esta Verificada y Cerrada  [CORRECTO] [*ERROR* Descripcion]
   FUNCTION etaCerradaFin (psCredito VARCHAR2, pnConcepto NUMBER)
      RETURN VARCHAR2;

   --- Actualiza Valor de la etapa final si  se Aplico
   PROCEDURE setVerifEtaCerradaFin (pnSolicitud        INTEGER,
                                    psCadenaEjecuta    VARCHAR2);

   --- Elimna el Registro del Valor dela Asignacion
   PROCEDURE delAsignacionsolicitud (pnSolicitud       INTEGER,
                                     pnConcepto        INTEGER,
                                     psCredito         VARCHAR2,
                                     psError       OUT VARCHAR2);

   FUNCTION getDetArchivosini (queConcepto INTEGER)
      RETURN VARCHAR2;

   PROCEDURE getDetalleDocIni (pnSolicitud INTEGER, salida IN OUT T_CURSOR);

   PROCEDURE getDetDocIniArchS (pnSolicitud          INTEGER,
                                pnConcepto           INTEGER,
                                psNmArchivo          VARCHAR2,
                                salida        IN OUT T_CURSOR);

   FUNCTION getDetArchivosSoporte (queConcepto INTEGER)
      RETURN VARCHAR2;

   PROCEDURE getDetalleDocSoporte (pnSolicitud          INTEGER,
                                   salida        IN OUT T_CURSOR);

   PROCEDURE getDetDocSopArchS (pnSolicitud          INTEGER,
                                pnConcepto           INTEGER,
                                psNmArchivo          VARCHAR2,
                                salida        IN OUT T_CURSOR);

   PROCEDURE setAddDoctoInicio (
      arrDetalle       PCKFACTURACIONGASTO.TABDOCTOINI,
      pnUsuario        INTEGER,
      psError      OUT VARCHAR2);

   PROCEDURE setAddDoctoSoporte (
      arrDetalle       PCKFACTURACIONGASTO.TABDOCTOINI,
      pnUsuario        INTEGER,
      psError      OUT VARCHAR2);

   PROCEDURE setVerifDoctoSoporte (
      arrDetalle       PCKFACTURACIONGASTO.TABVERIFDOCTOSOPORTE,
      pnUsuario        INTEGER,
      psError      OUT VARCHAR2);

   PROCEDURE setJustificaAlerta (
      arrDetalle       PCKFACTURACIONGASTO.TABJUSTIFICAALERTA,
      pnUsuario        INTEGER,
      psError      OUT VARCHAR2);

   PROCEDURE setAutorizaAlerta (
      arrDetalle       PCKFACTURACIONGASTO.TABAUTORIZAALERTA,
      pnUsuario        INTEGER,
      psError      OUT VARCHAR2);

   PROCEDURE getCatConceptoAsig (psTipoSolic          VARCHAR2,
                                 psQueAsigna          INTEGER,
                                 quePuestoEs          VARCHAR2,
                                 salida        IN OUT T_CURSOR);

   PROCEDURE getSbCatConceptoAsig (queCategoria          INTEGER,
                                   psTipoSolic           VARCHAR2,
                                   psQueAsigna           INTEGER,
                                   quePuestoEs           VARCHAR2,
                                   salida         IN OUT T_CURSOR);

   PROCEDURE getQueConceptoAsig (queCategoria             INTEGER,
                                 queSubCategoria          INTEGER,
                                 psTipoSolic              VARCHAR2,
                                 psQueAsigna              INTEGER,
                                 quePuestoEs              VARCHAR2,
                                 salida            IN OUT T_CURSOR);

   PROCEDURE getQueConceptoNmAsig (queCategoria             INTEGER,
                                   queSubCategoria          INTEGER,
                                   queBuscar                VARCHAR2,
                                   psTipoSolic              VARCHAR2,
                                   psQueAsigna              INTEGER,
                                   quePuestoEs              VARCHAR2,
                                   salida            IN OUT T_CURSOR);

 PROCEDURE setTramiteINTERNO (pnGasto INTEGER);

 PROCEDURE setTramiteExterno (pnCaso              INTEGER,
                                psTipoSolucion      VARCHAR2,
                                quienSolic          INTEGER,
                                queSeveridad        VARCHAR2,
                                queEmpresaFact      VARCHAR2,
                                queOtEmpresaFact    VARCHAR2,
                                queFormaPago        VARCHAR2,
                                queTipoCuenta       VARCHAR2,
                                psCadenaEjecuta     VARCHAR2,
                                pdFecRequerida      VARCHAR2);

 PROCEDURE getDetalleDiaTeso (pnEmpleado          INTEGER,
                              laFechaEs           VARCHAR2,
                              salida       IN OUT T_CURSOR,
                              queEmpresaFact      VARCHAR2,
                              queLote             INTEGER DEFAULT 0);

 PROCEDURE getDetallePagosCie (pnEmpleado          INTEGER,
                              laFechaEs           VARCHAR2,
                              salida       IN OUT T_CURSOR,
                              queEmpresaFact      VARCHAR2,
                              queLote             INTEGER DEFAULT 0);

 PROCEDURE getDetalleDiaCheqTeso (pnEmpleado          INTEGER,
                                laFechaEs           VARCHAR2,
                                salida       IN OUT T_CURSOR,
                                queEmpresaFact           VARCHAR2);

 PROCEDURE setTramiteAreaConc (pnGasto        INTEGER,
                                 pcEmailTit     VARCHAR2,
                                 pnQueGestor    VARCHAR2,
                                 queEjecuta     VARCHAR2);

 PROCEDURE setTramiteGestion (pnGasto            INTEGER,
                                pcQueSolucion      VARCHAR2,
                                pnMontoAnticipo    NUMBER,
                                pcSolucTram        VARCHAR2,
                                pcQueProveedor     VARCHAR2,
                                pcQuienDeposita    VARCHAR2,
                                pnImpBase          NUMBER,
                                pnIva              NUMBER,
                                pnEsperado         NUMBER,
                                queEjecuta         VARCHAR2);

 PROCEDURE setResultAutorizacion (pnGasto          INTEGER,
                                    quienEs          VARCHAR2,
                                    queResultado     VARCHAR2,
                                    queComentario    VARCHAR2,
                                    queEjecuta       VARCHAR2,
                                    queindiceAut     INTEGER);

 PROCEDURE getMisConceptos (  quienEs          VARCHAR2,
                                externo VARCHAR2,
                                salida       IN OUT T_CURSOR);

 PROCEDURE setCancfTransAnticipo (psGastos         VARCHAR2, /* CADENA DE IDGASTO SEPARADO POR PIPES */
                                    usuSolic         VARCHAR2,
                                    psFecReprog      VARCHAR2,  /* DD/MM/YYYY */
                                    psError      OUT VARCHAR2,
                                    psEmpresaFact    VARCHAR2);

 PROCEDURE getCuentasEmpresa (pnEmpresa INTEGER, salida IN OUT T_CURSOR);

 PROCEDURE getFolCtrlTesoDia(laFechaEs           VARCHAR2,
                             queEmpresaFact      VARCHAR2,
                             salida       IN OUT T_CURSOR);

 PROCEDURE getFolCtrlPagoCie(laFechaEs           VARCHAR2,
                             queEmpresaFact      VARCHAR2,
                             salida       IN OUT T_CURSOR);

 PROCEDURE getMisJuicios( quienEs VARCHAR2,
                          salida  IN OUT T_CURSOR );

 PROCEDURE getInfoJuicio( idJuicio VARCHAR2,
                          salida  IN OUT T_CURSOR );

 PROCEDURE setSupervisorByExterno ( solicitudId VARCHAR2,
                                    mailSuper   VARCHAR2,
                                    idSuper     VARCHAR2,
                                    empleadoId  VARCHAR2,
                                    credito     VARCHAR2,
                                    salida       IN OUT T_CURSOR);

 PROCEDURE ReasignaAutorizador ( appuid   VARCHAR2,
                                 tasuid   VARCHAR2,
                                 newuser  VARCHAR2,
                                 salida   IN OUT T_CURSOR);
                                 
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
                               psError        OUT VARCHAR2);

 PROCEDURE addNuevoConceptoGasto (pnCaso             INTEGER,
                               pnconcepto         INTEGER,
                               psQueTramite       VARCHAR2,
                               quienSolic         INTEGER,
                               queUsuPM           VARCHAR2,
                               quetipoEs          VARCHAR2,
                               psAPPUID           VARCHAR2,
                               psSalida       OUT VARCHAR2);

 PROCEDURE validaNuevoCreditoAsigna (pnSolicitud         INTEGER,
                                  psCredito           VARCHAR2, /* SI  es psTipomovto = 4 [valor CARTERA]  psTipomovto = 42 [CONCEPTO ]*/
                                  pnConcepto          NUMBER,
                                  pnImporte           NUMBER,
                                  psTipomovto         INTEGER, /* [2] X CREDITO , [3] MUT-CRED, [4] X CARTERA, [42] X IMP GRAL */
                                  psCentroCosto       VARCHAR2, /* Solo valido si es CArtera ? Importe General */
                                  psFechaPgoIni       VARCHAR2,
                                  psFechaPgoFin       VARCHAR2,
                                  quienSolic          INTEGER,
                                  psError         OUT VARCHAR2);
                                  

FUNCTION whichDirectBoss (FCTIPOJEFEINMED VARCHAR2, IDJEFEINMEDIATO VARCHAR2, quienSolic VARCHAR2, FCJEFEINMEDIATO VARCHAR2)
RETURN VARCHAR2;                                  

PROCEDURE insertCargaMasivaFactura (psUUID         VARCHAR2,
                                    psID_DOCUMENTO VARCHAR2, 
                                    psID_USUARIO   NUMBER,
                                    psNOM_USUARIO  VARCHAR2,
                                    psURL_XML      VARCHAR2, 
                                    psError        OUT VARCHAR2);
 



END PCKFACTURACIONGASTO;
/
