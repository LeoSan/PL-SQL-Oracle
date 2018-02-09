-- Crear Tabla  pendupm.xtravelfieldhdr con su Indice
drop  table pendupm.xtravelfieldhdr; 

create table pendupm.xtravelfieldhdr as (
select *      
FROM xtravelfieldhdr@erpbase.com  A
);


CREATE INDEX PENDUPM.INDEX_BATBNR_XT ON PENDUPM.xtravelfieldhdr
("BatNbr")
LOGGING
NOPARALLEL
COMPUTE STATISTICS;


GRANT DELETE, INSERT, SELECT, UPDATE ON PENDUPM.xtravelfieldhdr TO PM_OPER;

GRANT DELETE, INSERT, SELECT, UPDATE ON PENDUPM.xtravelfieldhdr TO TL_PM;


