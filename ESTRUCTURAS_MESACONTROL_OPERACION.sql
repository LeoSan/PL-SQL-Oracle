CREATE SEQUENCE OPERACION.SEQ_NUMERO_CASO
 START WITH     4499998
 INCREMENT BY   1
 NOCACHE
 NOCYCLE;

--DROP TABLE OPERACION.VMC_ETAPAS_TAREAS;

CREATE TABLE OPERACION.VMC_ETAPAS_TAREAS
(
  ID_CASO                   NUMBER         NOT NULL,
  ID_TAREA                  NUMBER         NOT NULL,
  FECHA_REGISTRO            DATE           NOT NULL,
  FECHA_FIN                 DATE,
  ORIGEN                    VARCHAR2(10)   NOT NULL,
  ID_PROC_VERIFICACION      INTEGER        NOT NULL,
  JUICIO                    VARCHAR2(10),
  ID_JUICIO                 INTEGER        NOT NULL,
  ID_ETAPA                  INTEGER        NOT NULL,
  ETAPA                     VARCHAR2(15)   NOT NULL,
  NOMBRE_ETAPA              VARCHAR2(200),
  CREDITO                   VARCHAR2(100)  NOT NULL,
  ID_ASIGNA                 VARCHAR2(5),
  BANDEJA                   VARCHAR2(15),
  FECHA_VERIFICADOR01       DATE,
  FECHA_FIN_VERIFICADOR01   DATE,
  FECHA_VERIFICADOR02       DATE,
  FECHA_FIN_VERIFICADOR02   DATE,
  FECHA_DICTAMEN            DATE,
  FECHA_FIN_DICTAMEN        DATE,
  ID_VERIFICADOR01          VARCHAR2(10),
  ID_VERIFICADOR02          VARCHAR2(10),
  ID_VERIFICADOR_DICTAMEN   VARCHAR2(10),
  RESULTADO_ETAPA_VER01     INTEGER,
  RAZON_ETAPA_VER01         INTEGER,
  RESULTADO_ETAPA_VER02     INTEGER,
  RAZON_ETAPA_VER02         INTEGER,
  RESULTADO_ETAPA_DICTAMEN  INTEGER,
  RAZON_ETAPA_DICTAMEN      INTEGER,
  COMENTARIO_VER01          VARCHAR2(1000),
  COMENTARIO_VER02          VARCHAR2(1000),
  COMENTARIO_DICTAMEN       VARCHAR2(1000)
)
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
NOMONITORING;


ALTER TABLE OPERACION.VMC_ETAPAS_TAREAS ADD (
  CONSTRAINT VMC_ETAPAS_TAREAS_PK
 PRIMARY KEY
 (ID_CASO));
 
--DROP TABLE OPERACION.VMC_CONFIG_ETAPAS;
 
CREATE TABLE OPERACION.VMC_CONFIG_ETAPAS
(
  NUMERO_ETAPA    VARCHAR2(10 BYTE)  NOT NULL,
  FECHA_REGISTRO  DATE,
  ID_USUARIO      VARCHAR2(15 BYTE),
  ESTATUS         VARCHAR2(1  BYTE)
)
TABLESPACE OPERACION
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
MONITORING;


CREATE UNIQUE INDEX OPERACION.PK1 ON OPERACION.VMC_CONFIG_ETAPAS
(NUMERO_ETAPA)
NOLOGGING
TABLESPACE OPERACION
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
NOPARALLEL;


ALTER TABLE OPERACION.VMC_CONFIG_ETAPAS ADD (
  CONSTRAINT PK1
 PRIMARY KEY
 (NUMERO_ETAPA)
    USING INDEX 
    TABLESPACE OPERACION
    PCTFREE    10
    INITRANS   2
    MAXTRANS   255
    STORAGE    (
                INITIAL          64K
                NEXT             1M
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
               ));




CREATE TABLE OPERACION.VMC_BITACORA_TAREAS
(
  ID_CASO       NUMBER,
  ID_TAREA      NUMBER,
  FECHA_INICIO  DATE,
  FECHA_FIN     DATE
)
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
NOMONITORING;


ALTER TABLE OPERACION.VMC_BITACORA_TAREAS ADD (
  CONSTRAINT VMC_BITACORA_TAREAS_R01 
 FOREIGN KEY (ID_CASO) 
 REFERENCES OPERACION.VMC_ETAPAS_TAREAS (ID_CASO));


 
  INSERT INTO  OPERACION.VMC_CONFIG_ETAPAS
       SELECT  IDNUMETAPA, FDFECREGISTRO, IDUSUARIO, 'A' 
         FROM  PENDUPM.CTMESACTRLETAPACAT;
 
  INSERT INTO  PENDUCRM.CAT_CLASIFICA_TAREA 
       VALUES  (1001, 'Verificación Mesa de control','QL',0,1);

COMMIT;
  

 GRANT DELETE, INSERT, SELECT, UPDATE ON OPERACION.VMC_CONFIG_ETAPAS TO PM_OPER;

 GRANT DELETE, INSERT, SELECT, UPDATE ON OPERACION.VMC_CONFIG_ETAPAS TO TL_PM;

 GRANT DELETE, INSERT, SELECT, UPDATE ON OPERACION.VMC_CONFIG_ETAPAS TO GESTION_TL;
 
 GRANT DELETE, INSERT, SELECT, UPDATE ON OPERACION.VMC_CONFIG_ETAPAS TO GESTION_OPER;
 
 
 GRANT DELETE, INSERT, SELECT, UPDATE ON OPERACION.VMC_ETAPAS_TAREAS TO PM_OPER;
 
 GRANT DELETE, INSERT, SELECT, UPDATE ON OPERACION.VMC_ETAPAS_TAREAS TO TL_PM;
  
 GRANT DELETE, INSERT, SELECT, UPDATE ON OPERACION.VMC_ETAPAS_TAREAS TO GESTION_TL;
 
 GRANT DELETE, INSERT, SELECT, UPDATE ON OPERACION.VMC_ETAPAS_TAREAS TO GESTION_OPER;
 
 
 GRANT DELETE, INSERT, SELECT, UPDATE ON OPERACION.VMC_BITACORA_TAREAS TO PM_OPER;
 
 GRANT DELETE, INSERT, SELECT, UPDATE ON OPERACION.VMC_BITACORA_TAREAS TO TL_PM;
 
 GRANT DELETE, INSERT, SELECT, UPDATE ON OPERACION.VMC_BITACORA_TAREAS TO GESTION_TL;
 
 GRANT DELETE, INSERT, SELECT, UPDATE ON OPERACION.VMC_BITACORA_TAREAS TO GESTION_OPER;
 
 
 GRANT SELECT ON OPERACION.SEQ_NUMERO_CASO TO PM_OPER;

 GRANT SELECT ON OPERACION.SEQ_NUMERO_CASO TO TL_PM;

 GRANT SELECT ON OPERACION.SEQ_NUMERO_CASO TO GESTION_TL;

 GRANT SELECT ON OPERACION.SEQ_NUMERO_CASO TO GESTION_OPER;
 

 