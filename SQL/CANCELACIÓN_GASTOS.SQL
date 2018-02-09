 SELECT *
           FROM (  SELECT DISTINCT
                            A.IDGASTOMAIN GASTO
                          , PENDUPM.PCKFACTURACIONGASTO.queConceptoGasto (A.IDGASTOMAIN) CONCEPTO
                          , IDPROVEEDORDEPOSITO QUIESES
                          , FCASIGNADEPOSITO AQUIEN
                          , PENDUPM.PCKENVIOCORREO.aplFecha (FDFECREGISTRO) FDFECREGISTRO
                          
                          , CASE WHEN (SELECT COUNT(1) FROM PENDUPM.FACTURACIONBITACORA H WHERE B.IDGASTOMAIN = H.IDGASTOMAIN AND DEL_INDEX = B.DELINDEX
                                        AND IDTASKGASTO  IN ('2082181485273e6002e4959086601056', '656925561529384c6847c88021053266')) > 0 THEN 'En Tesoreria'
                          ELSE
                              (SELECT "nombreCompleto" FROM PENDUPM.VISTAASOCIADOS  WHERE     "email" =
                                             (SELECT FCUSUARIO FROM PENDUPM.FACTURACIONBITACORA C
                                               WHERE C.IDGASTOMAIN = A.IDGASTOMAIN  AND C.DEL_INDEX = B.DELINDEX)
                                                 AND "status" = 'A')
                          END SOLICITANTE,
                          
                          
                          (SELECT "status" FROM PENDUPM.VISTAASOCIADOS WHERE "cvetra" = FNNUMEMPLEADO AND "status" = 'A') STATUSEMP,
                           FNIMPORTESOLICITADO TOTAL
                          , FNIMPORTEANTICIPO ANTICIPO
                          , CASE
                             WHEN FCSEVERIDADGASTO NOT IN ('Normal', 'Urgente')
                             THEN
                                PENDUPM.PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA)
                             ELSE
                                FCSEVERIDADGASTO
                          END
                             URGENCIA
                             
                         ,                            
                             '<B>'
                          || TPOMOVIMIENTO
                          || ' </B>'
                          || NVL (
                                CASE
                                   WHEN IDEMPRESAFACTURACION = 0
                                   THEN
                                      (SELECT NMEMPRESA
                                         FROM PENDUPM.EMPRESAFACTURACION D
                                        WHERE D.IDEMPRESA =
                                                 A.IDOTEMPRESAFACTURACION)
                                   WHEN (   IDEMPRESAFACTURACION != 0
                                         OR IDEMPRESAFACTURACION IS NOT NULL)
                                   THEN
                                      (SELECT NMEMPRESA
                                         FROM PENDUPM.EMPRESAFACTURACION D
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
                                      FROM PENDUPM.EMPRESAFACTURACION D
                                     WHERE D.IDEMPRESA =
                                              A.IDOTEMPRESAFACTURACION)
                                WHEN (   IDEMPRESAFACTURACION != 0
                                      OR IDEMPRESAFACTURACION IS NOT NULL)
                                THEN
                                   (SELECT FNIMPCOMISION
                                      FROM PENDUPM.EMPRESAFACTURACION D
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
                             FROM PENDUPM.ETAPAFACTURACION C
                            WHERE C.IDTASKGASTO =
                                     (SELECT IDTASKGASTO
                                        FROM PENDUPM.FACTURACIONBITACORA BIT
                                       WHERE     BIT.IDGASTOMAIN =
                                                    B.IDGASTOMAIN
                                         AND BIT.DEL_INDEX = B.DELINDEX))||CASE WHEN (FDDYNAMICSGASTO IS NOT NULL OR FDDYNAMICSREEMB IS NOT NULL) THEN
                                         ' <BR/><B>**Hay DEPOSITO de DINERO**</B>'  END||'<BR/> STATUS : '||CASE WHEN FCSTATUS = 'F' THEN  '<font color="red">FINALIZADO</font>'
                                                                                              WHEN FCSTATUS = 'Z' THEN  '<font color="red">CANCELADO</font>'
                                                                                         ELSE '<font color="red">EN SOLUCION</font>'  END
                             DONDEESTA,
                          B.DELINDEX IDUBICA,
                          (SELECT IDTASKGASTO
                             FROM PENDUPM.FACTURACIONBITACORA C
                            WHERE     C.IDGASTOMAIN = A.IDGASTOMAIN
                                  AND C.DEL_INDEX = B.DELINDEX)
                             TSK,
                          A.APP_UID
                     FROM PENDUPM.FACTURACIONMAIN A
                          INNER JOIN
                          ( SELECT IDGASTOMAIN,
                                    APP_UID,
                                    MAX (DEL_INDEX) DELINDEX
                               FROM PENDUPM.FACTURACIONBITACORA
                           GROUP BY IDGASTOMAIN, APP_UID) B
                             ON (    A.IDGASTOMAIN = B.IDGASTOMAIN
                                 AND A.APP_UID = B.APP_UID)
                  
           
             WHERE A.IDGASTOMAIN = 4302962 /* AND A.FCSTATUS NOT IN ('Z') AND A.DELINDEX_ETAPA > 1*/
                 ORDER BY FDFECREGISTRO ASC) PASO;