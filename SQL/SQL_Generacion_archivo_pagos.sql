 SELECT *
        FROM (
            SELECT  GASTO,CONCEPTO,
                    QUIESES,        
                    AQUIEN,
                    NMPROVEEDOR,
                    TOTAL,
                    URGENCIA,
                    ' <B>'||
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA =  '2082181485273e6002e4959086601056' THEN 'Anticipo'
                         WHEN TPOMOVIMIENTO = 'Anticipo' AND ETAPA =  '656925561529384c6847c88021053266' THEN 'Reembolso'
                         WHEN TPOMOVIMIENTO = 'Reembolso' AND ETAPA = '656925561529384c6847c88021053266' THEN 'Reembolso'
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA =   '2082181485273e6002e4959086601056' THEN 'Tramite-Anticipo'
                         WHEN TPOMOVIMIENTO = 'Tramite' AND ETAPA =   '656925561529384c6847c88021053266' THEN 'Tramite-Reembolso'
                    END||' </B>' EMPFACT,
                    COMISION COMISIONCHEQUE,
                    TPOCUENTA,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT pendupm.PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM pendupm.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT pendupm.PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM pendupm.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END   FECPAGO   ,
                    CASE WHEN ETAPA = '2082181485273e6002e4959086601056' THEN (SELECT FDFECPARAPAGO FROM pendupm.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                         WHEN ETAPA = '656925561529384c6847c88021053266' THEN (SELECT FDFECPARAPAGO FROM pendupm.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                    END PARAORDEN  ,
                    QUEES TIPODEGASTO
              FROM (
                   SELECT DISTINCT
                          IDGASTOMAIN GASTO,
                          pendupm.PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN) CONCEPTO,
                          IDPROVEEDORDEPOSITO QUIESES,
                          FCASIGNADEPOSITO AQUIEN,
                          TPOMOVIMIENTO,
                          (SELECT NMPROVEEDOR FROM pendupm.CTPROVEEDORGASTO F WHERE F.IDPROVEEDORGTO = A.IDPROVEEDORDEPOSITO )||
                          CASE WHEN IDFORMAPAGO = 38 THEN '<BR/>A nombre de : '||FCNMPAGOCHQCAJA END NMPROVEEDOR,
                          FNNUMEMPLEADO,
                          FNIMPORTESOLICITADO TOTAL,
                         (SELECT IDTASKGASTO
                            FROM pendupm.FACTURACIONBITACORA XX
                           WHERE XX.IDGASTOMAIN = A.IDGASTOMAIN
                             AND xx.DEL_INDEX = (SELECT MAX(DEL_INDEX)
                                                   FROM pendupm.FACTURACIONBITACORA DD
                                                  WHERE XX.IDGASTOMAIN = DD.IDGASTOMAIN
                                                )
                          ) ETAPA,
                          FNIMPORTEREEMBOLSO,
                          FNIMPORTEANTICIPO,
                          FCSEVERIDADGASTO,
                          CASE WHEN IDEMPRESAFACTURACION = 0 THEN IDOTEMPRESAFACTURACION ELSE IDEMPRESAFACTURACION END EMPRESA,
                          (SELECT (FCVALOR+FCVALOR1) FROM pendupm.CTCATALOGOGASTOS F WHERE F.IDCATGASTO= A.IDFORMAPAGO) COMISION,
                          CASE WHEN FCTIPOCUENTA = '1' THEN 'Fiscal' ELSE 'No Fiscal' END  TPOCUENTA,
                          CASE
                             WHEN FCSEVERIDADGASTO NOT IN ('Normal', 'Urgente')
                             THEN
                                pendupm.PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA)
                             ELSE
                                FCSEVERIDADGASTO
                          END URGENCIA,
                          (SELECT NMDESCRIPCION FROM pendupm.CTCATALOGOGASTOS F WHERE F.IDCATGASTO= A.IDFORMAPAGO) QUEES
                     FROM pendupm.FACTURACIONMAIN A
                    WHERE IDGASTOMAIN IN (SELECT ZZ.IDGASTOMAIN
                                            FROM pendupm.FACTURACIONBITACORA ZZ
                                      INNER JOIN (SELECT IDGASTOMAIN,
                                                         MAX (DEL_INDEX) DONDEESTA
                                                    FROM pendupm.FACTURACIONBITACORA
                                                GROUP BY IDGASTOMAIN
                                                 ) CC ON ( ZZ.IDGASTOMAIN = CC.IDGASTOMAIN AND DEL_INDEX = DONDEESTA)
                                           WHERE IDTASKGASTO IN ('656925561529384c6847c88021053266') -- 4294348
                                          )
                      AND IDGASTOMAIN IN (SELECT IDGASTOMAIN
                                            FROM pendupm.FACTURACIONPAGOS
                                           WHERE FNCONSEC IN (6)  -- 4294348
                                          )
                       AND FCSTATUS != 'Z'
                                           /*      AND FDFECPAGADO IS NULL)*/
                       AND CASE
                              WHEN IDEMPRESAFACTURACION = 0 THEN A.IDOTEMPRESAFACTURACION
                              WHEN (IDEMPRESAFACTURACION != 0 OR IDEMPRESAFACTURACION IS NOT NULL) THEN A.IDEMPRESAFACTURACION
                              END = 16
                        AND NOT EXISTS (SELECT IDGASTOMAIN FROM pendupm.FCTARCHPAGOSGASTO B WHERE A.IDGASTOMAIN = B.IDGASTO)
                 ) PASO
           ) TODOJUNTO
         ORDER BY PARAORDEN ASC;