 SELECT 1 IND,
       'DYNAMICS' ORIGEN,      '0' ProjectID,     ID_GASTO IDHISTORICO,
                        CUENTA_CONTABLE,        CONCEPTO,                   PENDUPM.PCKCTRLDOCUMENTAL01.aplFecha (FECHA_DE_PAGO,'2') FECHA_DE_PAGO,
                        PROVEEDOR,              POLIZA,                     FACTURA,
                        PENDUPM.PCKCONVENIOS.formatComas(MONTO_TOTAL ) MONTO_TOTAL
        
 
 
            FROM BI_DIMGASTOS@PENDUBI.COM
                  WHERE CREDITO_CYBER = 'B110094'
                    AND CUENTA_CONTABLE = '6010010401' 
                    AND (PROVEEDOR IS NULL OR PROVEEDOR NOT LIKE '%PENDULUM%')
                    AND TO_NUMBER(NVL(NUMERO_CASO,0)) != 4305836
                    AND TO_NUMBER(NVL(NUMERO_CASO,0)) NOT IN ( 
                         SELECT B.IDGASTOMAIN 
                           FROM PENDUPM.FACTURAASIGNACION A 
                     INNER JOIN PENDUPM.FACTURACIONMAIN B ON ( A.IDGASTOMAIN = B.IDGASTOMAIN AND A.IDCONCEPTO = B.IDCONCEPTO) 
                          WHERE     A.IDGASTOMAIN != 4305836 AND FCCREDITOCARTERA = 'B110094' AND FCSTATUS NOT IN ( 'Z','R') 
                                AND FCCUENTACONTABLE = '6010010401' AND A.STATUS = 'A'
                  )
               UNION ALL
                SELECT 2 IND,
                       'PM' ORIGEN,
                       A.FCDYNAMICS ProjectID,
                       A.IDGASTOMAIN IDHISTORICO,
                       FCCUENTACONTABLE CUENTA_CONTABLE,
                       (SELECT NMCONCEPTO
                          FROM PENDUPM.CTCATALOGOCUENTAS C
                         WHERE A.IDCONCEPTO = C.IDCONCEPTO)
                          CONCEPTO,
                       PENDUPM.PCKCTRLDOCUMENTAL01.aplFecha (B.FDFECREGISTRO, '2') FECHA_DE_PAGO,
                       NVL(B.NMPROVEEDOR,'--SIN PROVEEDOR...') PROVEEDOR,
                       '0' POLIZA, '0' FACTURA,
                       PENDUPM.PCKCONVENIOS.formatComas(FNIMPORTE)  MONTO_TOTAL
                  FROM PENDUPM.FACTURAASIGNACION A
                       INNER JOIN PENDUPM.FACTURACIONMAIN B
                          ON (    A.IDGASTOMAIN = B.IDGASTOMAIN
                              AND A.IDCONCEPTO = B.IDCONCEPTO)
                 WHERE A.IDGASTOMAIN != 4305836
                  AND FCCREDITOCARTERA = 'B110094'
                       AND B.FCSTATUS != 'Z'
                       AND FCCUENTACONTABLE = 6010010401
                  AND (a.IDGASTOMAIN) IN (SELECT IDGASTOMAIN
                                          FROM PENDUPM.FACTURACIONBITACORA
                                         WHERE IDGASTOMAIN != 4305836
                                           AND (IDGASTOMAIN,DEL_INDEX) IN (SELECT IDGASTOMAIN,MAX(DEL_INDEX)
                                                                           FROM PENDUPM.FACTURACIONBITACORA
                                                                          WHERE IDGASTOMAIN != 4305836
                                                                            AND IDTASKGASTO NOT IN ('974392365525c7af897e890053564163','8433500185372a3c766b298052315707')
                                                                           GROUP BY IDGASTOMAIN
                                                                          )
                                            AND IDTASKGASTO NOT IN ('974392365525c7af897e890053564163','8433500185372a3c766b298052315707')
                                        )
                ORDER BY 1 ASC;
