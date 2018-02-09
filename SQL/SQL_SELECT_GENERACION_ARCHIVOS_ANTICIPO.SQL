 
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
                                     from pendupm.vistaasociados
                                    WHERE "cvetra" = FNNUMEMPLEADO
                    ) SOLICITANTE,
                   (SELECT "status"
                     from pendupm.vistaasociados
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
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'Anticipo<BR/> '||FCSEVERIDADGASTO||'<BR/>'||TPOCUENTA
                         WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA = '656925561529384c6847c88021053266' THEN 'Reembolso<BR/> '||FCSEVERIDADGASTO||'<BR/>'||TPOCUENTA
                         WHEN TPOMOVIMIENTO = 'Reembolso' AND ETAPA = '656925561529384c6847c88021053266' THEN 'Reembolso<BR/> '||FCSEVERIDADGASTO||'<BR/>'||TPOCUENTA
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '2082181485273e6002e4959086601056' THEN 'Tramite-Anticipo<BR/> '||FCSEVERIDADGASTO||'<BR/>'||TPOCUENTA
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA = '656925561529384c6847c88021053266' THEN 'Tramite-Reembolso<BR/> '||FCSEVERIDADGASTO||'<BR/>'||TPOCUENTA
                    END||' </B>' EMPFACT,
                    COMISION COMISIONCHEQUE,
                    TPOCUENTA,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN CASE WHEN PASO.FCSEVERIDADGASTO = 'FechaPago' THEN PENDUPM.PCKENVIOCORREO.aplFecha(PASO.FDFECHAREQUERIDA,'1') ELSE (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2) END
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN CASE WHEN PASO.FCSEVERIDADGASTO = 'FechaPago' THEN PENDUPM.PCKENVIOCORREO.aplFecha(PASO.FDFECHAREQUERIDA,'1') ELSE  (SELECT PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6) END
                    END   FECPAGO   ,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN CASE WHEN PASO.FCSEVERIDADGASTO = 'FechaPago' THEN PASO.FDFECHAREQUERIDA ELSE  (SELECT FDFECPARAPAGO FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2) END
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN CASE WHEN PASO.FCSEVERIDADGASTO = 'FechaPago' THEN PASO.FDFECHAREQUERIDA ELSE  (SELECT FDFECPARAPAGO FROM FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6) END
                    END PARAORDEN  ,
                    QUEES TIPODEGASTO,
                    CARTERA
              FROM (
                   SELECT DISTINCT
                          IDGASTOMAIN GASTO,
                          PENDUPM.PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN) CONCEPTO,
                          IDPROVEEDORDEPOSITO QUIESES,
                          FCASIGNADEPOSITO AQUIEN,
                          TPOMOVIMIENTO,
                          (SELECT NMPROVEEDOR FROM PENDUPM.CTPROVEEDORGASTO F WHERE F.IDPROVEEDORGTO = A.IDPROVEEDORDEPOSITO )||
                          CASE WHEN IDFORMAPAGO = 38 THEN '<BR/>A nombre de : '||FCNMPAGOCHQCAJA END NMPROVEEDOR,
                          FNNUMEMPLEADO,
                          FNIMPORTESOLICITADO TOTAL,
                         (SELECT IDTASKGASTO
                            FROM PENDUPM.FACTURACIONBITACORA XX
                           WHERE XX.IDGASTOMAIN = A.IDGASTOMAIN
                             AND xx.DEL_INDEX = (SELECT MAX(DEL_INDEX)
                                                   FROM PENDUPM.FACTURACIONBITACORA DD
                                                  WHERE XX.IDGASTOMAIN = DD.IDGASTOMAIN
                                                )
                          ) ETAPA,
                          FNIMPORTEREEMBOLSO,
                          FNIMPORTEANTICIPO,
                          FCSEVERIDADGASTO,
                          FDFECHAREQUERIDA,
                          CASE WHEN IDEMPRESAFACTURACION = 0 THEN IDOTEMPRESAFACTURACION ELSE IDEMPRESAFACTURACION END EMPRESA,
                          (SELECT (FCVALOR+FCVALOR1) FROM PENDUPM.CTCATALOGOGASTOS F WHERE F.IDCATGASTO= A.IDFORMAPAGO) COMISION,
                          CASE WHEN FCTIPOCUENTA = '1' THEN 'Fiscal' ELSE 'No Fiscal' END  TPOCUENTA,
                          CASE
                             WHEN FCSEVERIDADGASTO NOT IN ('Normal', 'Urgente')
                             THEN
                                PENDUPM.PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA)
                             ELSE
                                FCSEVERIDADGASTO
                          END URGENCIA,
                          (SELECT NMDESCRIPCION FROM PENDUPM.CTCATALOGOGASTOS F WHERE F.IDCATGASTO= A.IDFORMAPAGO) QUEES,
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
                     FROM PENDUPM.FACTURACIONMAIN A
                    WHERE IDGASTOMAIN IN (SELECT ZZ.IDGASTOMAIN
                                            FROM PENDUPM.FACTURACIONBITACORA ZZ
                                      INNER JOIN (SELECT IDGASTOMAIN,
                                                         MAX (DEL_INDEX) DONDEESTA
                                                    FROM PENDUPM.FACTURACIONBITACORA
                                                GROUP BY IDGASTOMAIN
                                                 ) CC ON ( ZZ.IDGASTOMAIN = CC.IDGASTOMAIN AND DEL_INDEX = DONDEESTA)
                                           WHERE IDTASKGASTO IN ('2082181485273e6002e4959086601056')
                                          )
                      AND IDGASTOMAIN IN (SELECT IDGASTOMAIN
                                            FROM PENDUPM.FACTURACIONPAGOS
                                           WHERE FNCONSEC IN (2)
                                          )
                       AND FCSTATUS != 'Z'
                                           /*    etapafacturacion  AND FDFECPAGADO IS NULL)*/
                       AND CASE
                              WHEN IDEMPRESAFACTURACION = 0 THEN A.IDOTEMPRESAFACTURACION
                              WHEN (IDEMPRESAFACTURACION != 0 OR IDEMPRESAFACTURACION IS NOT NULL) THEN A.IDEMPRESAFACTURACION
                              END = 14
                       AND NOT EXISTS (SELECT IDGASTOMAIN FROM PENDUPM.FCTARCHANTICGTO B WHERE A.IDGASTOMAIN = B.IDGASTOMAIN)
                 ) PASO
           ) TODOJUNTO
         ORDER BY PARAORDEN ASC;