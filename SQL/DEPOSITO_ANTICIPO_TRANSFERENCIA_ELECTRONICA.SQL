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
                       FROM PENDUPM.EMPRESAFACTURACION D
                      WHERE D.IDEMPRESA = EMPRESA
                    ) EMPFACT,
                    COMISION COMISIONCHEQUE,
                    TPOCUENTA,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT PENDUPM.PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT PENDUPM.PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END   FECPAGO   ,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT FDFECPARAPAGO FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT FDFECPARAPAGO FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END PARAORDEN   ,
                    '<B>'||CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT FCREFERDYN  FROM PENDUPM.FACTURACIONPAGOS DD WHERE  DD.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT FCREFERDYN  FROM PENDUPM.FACTURACIONPAGOS DD WHERE  DD.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END||'</B><BR/>'||
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT PENDUPM.PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT PENDUPM.PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END  REFERENCIA,
                    CARTERA
              FROM (
                   SELECT IDGASTOMAIN GASTO,
                          PENDUPM.PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN) CONCEPTO,
                          IDPROVEEDORDEPOSITO||(select decode ("Status" ,'H','-BAJA')from vendor@erpbase.com where  "VendId" = IDPROVEEDORDEPOSITO ) QUIESES,
                          FCASIGNADEPOSITO AQUIEN,
                          TPOMOVIMIENTO,
                          (SELECT NMPROVEEDOR FROM PENDUPM.CTPROVEEDORGASTO F WHERE F.IDPROVEEDORGTO = A.IDPROVEEDORDEPOSITO ) NMPROVEEDOR,
                          FNNUMEMPLEADO,
                          "nombreCompleto" SOLICITANTE,
                          "status" STATUSEMP,
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
                          CASE WHEN IDEMPRESAFACTURACION = 0 THEN IDOTEMPRESAFACTURACION ELSE IDEMPRESAFACTURACION END EMPRESA,
                          (SELECT (FCVALOR+FCVALOR1) FROM PENDUPM.CTCATALOGOGASTOS F WHERE F.IDCATGASTO= A.IDFORMAPAGO) COMISION,
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
                     FROM PENDUPM.FACTURACIONMAIN A  INNER JOIN  (select * from  PENDUPM.VISTAASOCIADOSCOMPLETA )
                                    ON ( "cvetra" = FNNUMEMPLEADO)
                    WHERE IDGASTOMAIN IN (SELECT ZZ.IDGASTOMAIN
                                            FROM PENDUPM.FACTURACIONBITACORA ZZ
                                      INNER JOIN (SELECT IDGASTOMAIN,
                                                         MAX (DEL_INDEX) DONDEESTA
                                                    FROM PENDUPM.FACTURACIONBITACORA
                                                GROUP BY IDGASTOMAIN
                                                 ) CC ON ( ZZ.IDGASTOMAIN = CC.IDGASTOMAIN AND DEL_INDEX = DONDEESTA)
                                           WHERE IDTASKGASTO IN ('2082181485273e6002e4959086601056','656925561529384c6847c88021053266')
                                        )
                      AND IDFORMAPAGO = 36 AND FCSTATUS = 'D'
                      AND CASE WHEN IDEMPRESAFACTURACION = 0 THEN A.IDOTEMPRESAFACTURACION
                               WHEN (IDEMPRESAFACTURACION != 0 OR IDEMPRESAFACTURACION IS NOT NULL) THEN A.IDEMPRESAFACTURACION
                      END = 13
                 ) PASO GROUP BY GASTO, CONCEPTO, QUIESES, AQUIEN, TPOMOVIMIENTO, NMPROVEEDOR, FNNUMEMPLEADO, SOLICITANTE, STATUSEMP, TOTAL, ETAPA,FNIMPORTEREEMBOLSO, FNIMPORTEANTICIPO, FCSEVERIDADGASTO, EMPRESA, COMISION, TPOCUENTA, URGENCIA, CARTERA
           ) TODOJUNTO
        WHERE TRUNC(PARAORDEN) <= TRUNC(SYSDATE)
         ORDER BY PARAORDEN ASC;