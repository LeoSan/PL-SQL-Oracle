
  UPDATE  `APPLICATION` SET APP_STATUS = 'COMPLETED', APP_FINISH_DATE = NOW()  WHERE APP_NUMBER IN (4315231); 

  UPDATE `APP_DELEGATION` SET `DEL_THREAD_STATUS` = 'CLOSED', `DEL_FINISH_DATE` = NOW() WHERE APP_UID IN ('7900519285a37f38fecba48051969450')  AND DEL_INDEX = 2

  SELECT ',' AS COMA, `APP_UID` FROM  `APPLICATION` WHERE APP_NUMBER IN (4315231); 
   
  SELECT * FROM  `APP_DELEGATION` WHERE APP_UID IN ('3485246105a384ac79157b9069810197', '5411336115a39a7267b6277069456396', '1901019485a3a774e85b123024209168', '2295008185a3af253a1e875020832991') AND DEL_INDEX = 2 
 