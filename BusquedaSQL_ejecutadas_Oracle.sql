-- Si muestra este mensaje ORA-00942: la tabla o vista no existe es que no tienes permisos

select  
vs.SQL_ID,
vs.OPTIMIZER_MODE,
vs.OPTIMIZER_COST,
vs.EXECUTIONS,
vs.parsing_user_id,
vs.PARSING_SCHEMA_NAME,
vs.module,
ss.PROGRAM,
ss.username,
ss.MACHINE,
vs.sharable_mem,
vs.sql_text ,
sql_fulltext,
vs.command_type,
vs.rows_processed,
vs.persistent_mem,
vs.runtime_mem,
vs.sorts,
vs.parse_calls,
vs.buffer_gets,
vs.disk_reads,
vs.version_count,
vs.users_opening,
vs.loads,
to_char(to_date(vs.first_load_time,'YYYY-MM-DD/HH24:MI:SS'),'MM/DD HH24:MI:SS') first_load_time,
rawtohex(vs.address) address,
vs.hash_value hash_value
from v$sqlarea vs ,
    v$session ss
where (vs.parsing_user_id != 0)
   AND OPTIMIZER_COST is not null
   AND OPTIMIZER_COST > 0
   and (vs.executions >= 1)
   and vs.sql_id = ss.sql_id (+)
   SQL_TEXT 
order by OPTIMIZER_COST desc
;