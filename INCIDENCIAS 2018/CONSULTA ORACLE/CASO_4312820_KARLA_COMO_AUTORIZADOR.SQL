-- Caso de Karla --   tRIGGER   validaTramiteDerivacionAplciar - tAREA - pERSONAL ASIGNADO PARA FINALIZACION DE TRAMITE 
SELECT FCAUTORIZADOR
                         FROM PENDUPM.FACTURACIONAUT
                       WHERE IDDELINDEX = (SELECT MAX(IDDELINDEX) 
                                             FROM PENDUPM.FACTURACIONAUT 
                                            WHERE IDGASTOMAIN = 4312820)
                                              AND IDCONSEC = (SELECT MIN(IDCONSEC) 
                                                                FROM PENDUPM.FACTURACIONAUT 
                                                               WHERE IDGASTOMAIN = 4312820 
                                                                 AND FCRESULTADO IS NULL
                                                                 AND IDDELINDEX = (SELECT MAX(IDDELINDEX) 
                                                                                     FROM PENDUPM.FACTURACIONAUT 
                                                                                    WHERE IDGASTOMAIN = 4312820
                                                                                   )
                                                              )
                                              AND IDGASTOMAIN = 4312820
                                             AND FCRESULTADO IS NULL
                                             
                                             
                                             
SELECT * FROM PENDUPM.FACTURACIONAUT  WHERE IDGASTOMAIN = 4312820;

SELECT MAX(IDDELINDEX)  FROM PENDUPM.FACTURACIONAUT  WHERE IDGASTOMAIN = 4312820; 

SELECT MIN(IDCONSEC)  FROM PENDUPM.FACTURACIONAUT  WHERE IDGASTOMAIN = 4312820 AND FCRESULTADO IS NULL AND IDDELINDEX = 1

SELECT MAX(IDDELINDEX) 
                                             FROM PENDUPM.FACTURACIONAUT 
                                            WHERE IDGASTOMAIN = 4312820
                                              AND IDCONSEC = (2)
                                              AND IDGASTOMAIN = 4312820
                                             AND FCRESULTADO IS NULL                                               