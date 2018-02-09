SELECT D.*, PENDUPM.PCKCONVENIOS.formatComas(MONTO_TOTAL) FMONTO_TOTAL 


FROM ( 

SELECT 1 IND, CREDITO_CYBER CREDITO
, 'DYNAMICS' ORIGEN
, '' ProjectID
, ID_GASTO IDHISTORICO
, CUENTA_CONTABLE
, CONCEPTO
, PENDUPM.PCKCTRLDOCUMENTAL01.aplFecha (FECHA_DE_PAGO,'2') FECHA_DE_PAGO
, PROVEEDOR
, POLIZA
, FACTURA
, MONTO_TOTAL
, '-- NO IDENTIFICADO --' SOLICITANTE
, TO_NUMBER(NUMERO_CASO) IDGASTO
, 'NA' FCSTATUS
, 'NA' TPOMOVIMIENTO 

FROM BI_DIMGASTOS@PENDUBI.COM 
WHERE CREDITO_CYBER = 'B110094' 
    AND CUENTA_CONTABLE = '6010010401' 
    AND TO_NUMBER(NVL(NUMERO_CASO,0)) != 4305836 
    AND TO_NUMBER(NVL(NUMERO_CASO,0)) 
    NOT IN ( 
        SELECT B.IDGASTOMAIN 
            FROM PENDUPM.FACTURAASIGNACION A 
            INNER JOIN PENDUPM.FACTURACIONMAIN B ON ( A.IDGASTOMAIN = B.IDGASTOMAIN AND A.IDCONCEPTO = B.IDCONCEPTO) 
            WHERE A.IDGASTOMAIN != 4305836 
            AND FCCREDITOCARTERA = 'B110094' 
            AND FCSTATUS NOT IN ( 'R') 
            AND FCCUENTACONTABLE = '6010010401' 
            AND A.STATUS = 'A' 
    ) 
            
            UNION ALL 
            
            SELECT 2 IND
            , FCCREDITOCARTERA CREDITO
            , 'SIST_GASTOS' ORIGEN
            , A.FCDYNAMICS ProjectID
            , A.IDGASTOMAIN IDHISTORICO
            , FCCUENTACONTABLE CUENTA_CONTABLE
            , ( SELECT NMCONCEPTO 
                        FROM PENDUPM.CTCATALOGOCUENTAS C 
                            WHERE A.IDCONCEPTO = C.IDCONCEPTO) CONCEPTO
                            , PENDUPM.PCKCTRLDOCUMENTAL01.aplFecha (B.FDFECREGISTRO, '2') FECHA_DE_PAGO
                            , NVL(B.NMPROVEEDOR,'--SIN PROVEEDOR...') PROVEEDOR, '0' POLIZA, '0' FACTURA
                            , ( CASE WHEN ( SELECT COUNT(1) 
                                    FROM PENDUPM.FACTURACIONBITACORA 
                                        WHERE IDGASTOMAIN = B.IDGASTOMAIN 
                                        AND IDTASKGASTO = '4515947455273e63c4198f0073790158' 
                                        AND FCRESULTADO = 'Autorizado' ) > 0 
                                        THEN FNIMPORTECOMPROBA ELSE FNIMPORTE 
                                        END ) MONTO_TOTAL
                                        , (SELECT "nombreCompleto" FROM PENDUPM.VISTAASOCIADOS 
                                            WHERE "cvetra" = FCUSUARIO) SOLICITANTE
                                            , (A.IDGASTOMAIN) IDGASTO
                                            , B.FCSTATUS
                                            , B.TPOMOVIMIENTO 
                                            
                                            FROM PENDUPM.FACTURAASIGNACION A 
                                            INNER JOIN PENDUPM.FACTURACIONMAIN B ON ( A.IDGASTOMAIN = B.IDGASTOMAIN 
                                            AND A.IDCONCEPTO = B.IDCONCEPTO) 
                                            WHERE A.IDGASTOMAIN != 4305836 
                                            AND FCCREDITOCARTERA = 'B110094' 
                                            AND FCSTATUS NOT IN ( 'R') 
                                            AND FCCUENTACONTABLE = '6010010401' 
                                            AND A.STATUS = 'A' ) D 
                                            ORDER BY 1 ASC 