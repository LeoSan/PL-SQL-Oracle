-- Crear Tabla  pendupm.xAddDev con su indice
drop table pendupm.xAddDev;
create table pendupm.xAddDev as (
select *   
FROM xAddDev@ERPBASE.COM A
);

CREATE INDEX PENDUPM.INDEX_BATBNR_DEV ON PENDUPM.xAddDev
("BatNbr")
LOGGING
NOPARALLEL
COMPUTE STATISTICS;

GRANT DELETE, INSERT, SELECT, UPDATE ON PENDUPM.xAddDev TO PM_OPER;

GRANT DELETE, INSERT, SELECT, UPDATE ON PENDUPM.xAddDev TO TL_PM;


