validar los estatus correctos de plan de viaje reporte de israel sitema


/*CONSULTA DE TODOS LOS PLANES DE VIAJE APARTIR DELPRORRATEO*/
select * 
--  SELECT COUNT(1) NUMERO_REGISTROS, FCSTATUS ESTATUS, SUM (FV_FNIMPORTE) , SUM (IMPORTE_PRORRATEO) 
from pendupm.iaal
where FDFECREGISTRO > TO_DATE('02/03/2017 22:07:20', 'MM/DD/YYYY HH24:MI:SS')

GROUP BY FCSTATUS


/*CONSULTA DE LO QUE FALTA EN LOTES PARA ELDA*/  -- 708551.35
select * 
--  SELECT COUNT(1) NUMERO_REGISTROS, FCSTATUS ESTATUS, SUM (FV_FNIMPORTE) , SUM (IMPORTE_PRORRATEO) 
from pendupm.iaal
where FDFECREGISTRO > TO_DATE('02/03/2017 22:07:20', 'MM/DD/YYYY HH24:MI:SS')
AND IMPORTE_PRORRATEO IS NULL
and idgasto = :PV

AND FCSTATUS IN ('V','F')
GROUP BY FCSTATUS


/*CONSULTA DE LO QUE FALTA EN LOTES PARA FABIOLA*/
select * 
--  SELECT COUNT(1) NUMERO_REGISTROS, FCSTATUS ESTATUS, SUM (FV_FNIMPORTE) , SUM (IMPORTE_PRORRATEO) 
from pendupm.iaal
where FDFECREGISTRO > TO_DATE('02/03/2017 22:07:20', 'MM/DD/YYYY HH24:MI:SS')
AND IMPORTE_PRORRATEO IS NULL

AND FCSTATUS IN ('V','F')
GROUP BY FCSTATUS


--29 renta de auto cerrados sin renta de auto finalizados
-- 4 que 2017 cerrados en el 2018
--comprovación validada que no se deberian de esrar asi 99   V 
-- deposito de anticipo 33


/*PLANES DE VIAJE QUE NO ESTAN EN TESORESIA */


/*ATENDIDO EN 2017 Y SE CERRO EN EL 2018*/
SELECT ISRA.* ,  GM.FDDYNAMICSCOMP FECHA_DISPERSION_FINAL
FROM PENDUPM.IAAL ISRA LEFT JOIN PENDUPM.GASTOMAIN GM 
ON ISRA.IDGASTO = GM.IDGASTO
WHERE isra.idgasto = :PV

pestaña 1
AUTORIZADO --  no deben de estar atorizados sino finalizados
los estatus dentro dicen otra cosa 
 
COMPROBACION VALIDADA --  no deben de estar atorizados sino finalizados
los estatus dentro dicen otra cosa 
validar si deben de ser finalizados


DEPOSITO DE ANTICIPO falta correr el proceso de las noches

GESTION DE APROVISIONAMIENTO --> falta ver que paso con la factura
PENDIENTE AUTORIZACION



4298533



select 
gas.IDGASTO numero_caso
,gas.FNEMPNOMINA || ' - ' ||(select clname from rcvry.collid where clcollid =gas.IDSOLICITANTE) Solicitante
, gas.IDCONTADOR AUTORIZADOR
, MT.NMMOTIVOGASTO motivo
,gas.FDFECREGISTRO fecha_solicitud
, gas.FDAPROBADO fecha_aprovacion
, gas.FDFECINI Fecha_ini
,gas.FDFECFIN Fecha_fin
,decode (gas.FCURGENTE , 'N','NORMAL' , 'S', 'URGENTE', '') Tipo_plan_viaje
,gas.FCSTATUS
, CASE gas.FCSTATUS 
    WHEN 'R'  THEN 'REGISTRADO'
    WHEN 'P'  THEN 'PENDIENTE AUTORIZACION'
    WHEN 'A'  THEN 'AUTORIZADO'
    WHEN 'D'  THEN 'DEPOSITO DE ANTICIPO'
    WHEN 'G'  THEN 'GESTION DE APROVISIONAMIENTO'
    WHEN 'C'  THEN 'EN COMPROBACION'
    WHEN 'F'  THEN 'FINALIZADOS'
    WHEN 'V'  THEN 'COMPROBACION VALIDADA'
    WHEN 'Z' THEN 'CANCELADOS'
ELSE gas.FCSTATUS END AS estatus
,gas.FNMONTOGASTO monto_solicitado
,'--'
,gas.FCVIATICO0
FROM 
  PENDUPM.GASTOMAIN Gas
           INNER JOIN PENDUPM.CTMOTIVOGASTO MT ON MT.IDMOTIVOGASTO =  Gas.IDMOTIVOGASTO
            and gas.idGasto = 4298533


* validar cuales son los que si pasaron por liliana 

    


porque no se ha cerrado -- 4273588
4275232


no se envio por 
4275402

identificar lo que tienen descuento de nomina --comprobacion de liliana 
4370104
4279857


se debio de cerrar porque esta en el status "Autorizado" 
4279857

porque no se cerro en tiempo 
4291200
4294794



