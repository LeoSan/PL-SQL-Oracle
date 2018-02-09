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
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN  'Subtotal..'||PENDUPM.PCKCONVENIOS.formatComas(FNIMPORTEREEMBOLSO)||'<BR/>'||
                                                                                                  'Comision..'||PENDUPM.PCKCONVENIOS.formatComas(COMISION)
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN 'Subtotal..'||PENDUPM.PCKCONVENIOS.formatComas(FNIMPORTEANTICIPO)||'<BR/>'||
                                                                                                'Comision..'||PENDUPM.PCKCONVENIOS.formatComas(COMISION)
                                                             END
                         WHEN TPOMOVIMIENTO = 'Reembolso' THEN  'Subtotal..'||PENDUPM.PCKCONVENIOS.formatComas(FNIMPORTEREEMBOLSO)||'<BR/>'||
                                                               'Comision..'||PENDUPM.PCKCONVENIOS.formatComas(COMISION)
                         WHEN TPOMOVIMIENTO = 'Tramite' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN  'Subtotal..'||PENDUPM.PCKCONVENIOS.formatComas(FNIMPORTEREEMBOLSO)||'<BR/>'||
                                                                                                  'Comision..'||PENDUPM.PCKCONVENIOS.formatComas(COMISION)
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN 'Subtotal..'||PENDUPM.PCKCONVENIOS.formatComas(FNIMPORTEANTICIPO)||'<BR/>'||
                                                                                                'Comision..'||PENDUPM.PCKCONVENIOS.formatComas(COMISION)
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
                    (SELECT NMDESCRIPCION FROM PENDUPM.CTCATALOGOGASTOS WHERE IDCATGASTO = IDFORMAPAGO ) URGENCIA,
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
                       FROM PENDUPM.EMPRESAFACTURACION D
                      WHERE D.IDEMPRESA = EMPRESA
                    ) EMPFACT,
                    COMISION COMISIONCHEQUE,
                    TPOCUENTA,
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN (SELECT PENDUPM.PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN (SELECT PENDUPM.PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                                                             END
                         WHEN TPOMOVIMIENTO = 'Reembolso' THEN (SELECT PENDUPM.PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                         WHEN TPOMOVIMIENTO = 'Tramite' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN (SELECT PENDUPM.PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN (SELECT PENDUPM.PCKENVIOCORREO.aplFecha(FDFECPARAPAGO,'1') FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                                                             END
                    END  FECHAANTICIPO   ,
                    CASE WHEN TPOMOVIMIENTO = 'Anticipo' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN (SELECT FDFECPARAPAGO FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN (SELECT FDFECPARAPAGO FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                                                             END
                         WHEN TPOMOVIMIENTO = 'Reembolso' THEN (SELECT FDFECPARAPAGO FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                         WHEN TPOMOVIMIENTO = 'Tramite' THEN CASE WHEN ETAPA2 = 'REEMBOLSO' THEN (SELECT FDFECPARAPAGO FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 6)
                                                                  WHEN ETAPA1 = 'ANTICIPO' THEN (SELECT FDFECPARAPAGO FROM PENDUPM.FACTURACIONPAGOS FF WHERE FF.IDGASTOMAIN = PASO.GASTO AND FNCONSEC = 2)
                                                             END
                    END FECHAORDEN
              FROM (
                   SELECT DISTINCT
                          IDGASTOMAIN GASTO,
                          PENDUPM.PCKFACTURACIONGASTO.queConceptoGasto (IDGASTOMAIN) CONCEPTO,
                          IDPROVEEDORDEPOSITO QUIESES,
                          FCASIGNADEPOSITO AQUIEN,
                          TPOMOVIMIENTO,
                          (SELECT NMPROVEEDOR FROM PENDUPM.CTPROVEEDORGASTO F WHERE F.IDPROVEEDORGTO = A.IDPROVEEDORDEPOSITO ) NMPROVEEDOR,
                          FNNUMEMPLEADO,
                          FNIMPORTESOLICITADO TOTAL,
                          CASE WHEN ( SELECT COUNT(1)
                                        FROM PENDUPM.FACTURACIONBITACORA XX
                                       WHERE XX.IDGASTOMAIN = A.IDGASTOMAIN
                                         AND IDTASKGASTO = '2082181485273e6002e4959086601056'
                                    ) > 0 THEN 'ANTICIPO' ELSE NULL
                          END ETAPA1,
                          CASE WHEN ( SELECT COUNT(1)
                                        FROM PENDUPM.FACTURACIONBITACORA XX
                                       WHERE XX.IDGASTOMAIN = A.IDGASTOMAIN
                                         AND IDTASKGASTO = '656925561529384c6847c88021053266'
                                    ) > 0 THEN 'REEMBOLSO' ELSE NULL
                          END  ETAPA2,
                          FNIMPORTEREEMBOLSO,
                          FNIMPORTEANTICIPO,
                          FCSEVERIDADGASTO,
                          CASE WHEN IDEMPRESAFACTURACION = 0 THEN IDOTEMPRESAFACTURACION ELSE IDEMPRESAFACTURACION END EMPRESA,
                          (SELECT (FCVALOR+FCVALOR1) FROM PENDUPM.CTCATALOGOGASTOS F WHERE F.IDCATGASTO= A.IDFORMAPAGO) COMISION,
                          CASE WHEN FCTIPOCUENTA = '1' THEN 'Fiscal' ELSE 'No Fiscal' END  TPOCUENTA,
                          CASE
                             WHEN FCSEVERIDADGASTO NOT IN ('Normal', 'Urgente')
                             THEN
                                PENDUPM.PCKENVIOCORREO.aplFecha (FDFECHAREQUERIDA)
                             ELSE
                                FCSEVERIDADGASTO
                          END URGENCIA1,
                          IDFORMAPAGO
                     FROM PENDUPM.FACTURACIONMAIN A
                    WHERE ( FNIMPORTEANTICIPO > 0 OR FNIMPORTEREEMBOLSO > 0)
                      AND ((FNIMPORTEANTICIPO IS NOT NULL OR FNIMPORTEANTICIPO != '') or (FNIMPORTEREEMBOLSO IS NOT NULL OR FNIMPORTEREEMBOLSO != ''))
                      AND CASE
                              WHEN IDEMPRESAFACTURACION = 0 THEN A.IDOTEMPRESAFACTURACION
                              WHEN (IDEMPRESAFACTURACION != 0 OR IDEMPRESAFACTURACION IS NOT NULL) THEN A.IDEMPRESAFACTURACION
                              END = 13
                      AND A.IDGASTOMAIN NOT IN (SELECT IDGASTOMAIN FROM PENDUPM.CIRCUITOCONTABLE WHERE FCQUEARCHIVO = 'PRVANTCGO')
                      AND  A.IDGASTOMAIN IN (SELECT IDGASTOMAIN FROM PENDUPM.FACTURACIONPAGOS WHERE FNCONSEC IN ( 2,6) AND FNIMPORTE > 0 ) /* AND FDFECPAGADO IS NULL)*/
                 ) PASO
            WHERE ETAPA2 IS NOT NULL OR ETAPA1 IS NOT NULL  
           ) TODOJUNTO WHERE GASTO = 4293919
         ORDER BY FECHAANTICIPO ASC;