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
                    FECHAANTICIPO       , QUEEMPRESAES
              FROM (
                   SELECT DISTINCT
                          IDGASTOMAIN GASTO,
                          PENDUPM.PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN) CONCEPTO,
                          IDPROVEEDORDEPOSITO QUIESES,
                          FCASIGNADEPOSITO AQUIEN,
                          TPOMOVIMIENTO,
                          (SELECT NMPROVEEDOR FROM PENDUPM.CTPROVEEDORGASTO F WHERE F.IDPROVEEDORGTO = A.IDPROVEEDORDEPOSITO ) NMPROVEEDOR,
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
                          PENDUPM.PCKENVIOCORREO.aplFecha (FDDYNAMICSGASTO) FECHAANTICIPO,
                          CASE  WHEN A.IDEMPRESAFACTURACION > 0 THEN A.IDEMPRESAFACTURACION
                         ELSE A.IDOTEMPRESAFACTURACION
                         END QUEEMPRESAES
                     FROM PENDUPM.FACTURACIONMAIN A
                    WHERE IDGASTOMAIN IN (SELECT ZZ.IDGASTOMAIN
                                            FROM PENDUPM.FACTURACIONBITACORA ZZ
                                      INNER JOIN (SELECT IDGASTOMAIN,
                                                         MAX (DEL_INDEX) DONDEESTA
                                                    FROM PENDUPM.FACTURACIONBITACORA
                                                GROUP BY IDGASTOMAIN
                                                 ) CC ON ( ZZ.IDGASTOMAIN = CC.IDGASTOMAIN AND DEL_INDEX = DONDEESTA)
                                           WHERE IDTASKGASTO IN ('2082181485273e6002e4959086601056','656925561529384c6847c88021053266')
                                        )
                     AND A.IDFORMAPAGO = 36
                    AND (FNIMPORTEANTICIPO > 0 OR FNIMPORTEREEMBOLSO > 0)
                    AND FCSTATUS = 'DP'
                        OR (    FCSTATUS = 'F'
                            AND (SELECT COUNT (1)
                                   FROM PENDUPM.FACTURACIONBITACORA X
                                  WHERE     X.IDGASTOMAIN = A.IDGASTOMAIN
                                        AND FCCOMENTARIOS IN ('LA TRANSFERENCIA SPEI FUE REALIZADA','TRANSFERENCIA SPEI REALIZADA FALTA CONFIRMACION')) >
                                   0)
                 ) PASO
           ) TODOJUNTO
          WHERE QUEEMPRESAES = 13
         ORDER BY PARAORDEN ASC;