<?
$bd = '246049121525d6e46863867035057511';
$oracle= '246049121525d6e46863867035057511';
$idgasto = @@casoNumero;
$indice = @#INDEX;
$delIndex = @%INDEX;
$caseId = @@APPLICATION;
$taskId = @@TASK;
$numEmpleadoActual = @@numEmpleadoActual;
$queSolucionEs = @@tipoSolucionConcentradora;
$queTipoTram = @@tipoSolucionTramite;
$queESSolic = @@tipoSolicitud;
@#existeAutExcedentes = 0;
@@autEnTurno = '';
@@verificaSoporte = '';
@@autExcedentes = '';
@@umbralRebasadoTramite = '';
@@usuAutorizador01 = '';
$hayAutExed = 0 ;
$hayUmbralesTram = 0 ;

try {
  


  //---- inicializa las justificaciones
   $iniJustif = "UPDATE FACTURAASIGNACION SET FCJUSTIFICETAFINAL = NULL, 
                                           FCJUSTIFICAEXCGASTO = NULL , 
                                           FCJUSTIFICACIONUMBRAL = NULL
                  WHERE IDGASTOMAIN = $idgasto";
   $resIniJust = executeQuery($iniJustif,$oracle);


	//*****  SI la Soucion es INTERNA
	if ( $queSolucionEs  == 'INTERNO'){
                 //--- ****  ACTUALIZACIONES X SER SOLUCION INTERNA
		$queEjecuta = "PCKFACTURACIONGASTO.setTramiteINTERNO($idgasto)";
		$addGasto = "BEGIN PCKFACTURACIONGASTO.setTramiteINTERNO($idgasto); END;";
		executeQuery($addGasto, $oracle);
		
		//--- audita Ejecucionn del Store Procedure
		$queRevisa = "SELECT FCERROR FROM BITACORATRANSACCION
		             WHERE IDGASTOMAIN = $idgasto  AND IDCONSEC = (SELECT MAX(IDCONSEC) FROM BITACORATRANSACCION WHERE IDGASTOMAIN = $idgasto )
		               AND FCEJECUTA = '$queEjecuta'";
                //---die($queRevisa );
		$resRevisa = executeQuery($queRevisa, $oracle);
		if(is_array($resRevisa) && count($resRevisa) > 0){
		     $valorRegresa = $resRevisa[1]['FCERROR'];
		     if ($valorRegresa != '0' ) {
			   die('*ERROR* de Transaccion.  PCKFACTURACIONGASTO.setTramiteINTERNO(..'.$valorRegresa);
			}
		}else{	
		      die('*ERROR* NO existe PCKFACTURACIONGASTO.setTramiteINTERNO ...'.$queEjecuta);
		} //---  if(is_array($resRevisa)

		    //------  ****  EJECUTA PARA AUTORIZADORES DE SOPORTE
			$queEjecuta = "PCKFACTURACIONGASTO.setDoctoSoporte($idgasto ,$numEmpleadoActual,--------------,$taskId, $indice);";
			$addGasto = "BEGIN 
			       PCKFACTURACIONGASTO.setDoctoSoporte($idgasto ,$numEmpleadoActual,'$queEjecuta','$taskId', $indice); 
		            END;";
	                 //--die($addGasto);
	
			executeQuery($addGasto, $bd);
		
			//--- audita Ejecucionn del Store Procedure
			$queRevisa = "SELECT FCERROR FROM BITACORATRANSACCION
		             WHERE IDGASTOMAIN = $idgasto  AND IDCONSEC = (SELECT MAX(IDCONSEC) FROM BITACORATRANSACCION WHERE IDGASTOMAIN = $idgasto )
		               AND FCEJECUTA = '$queEjecuta'";
			$resRevisa = executeQuery($queRevisa, $bd);
			if(is_array($resRevisa) && count($resRevisa) > 0){
		    	 $valorRegresa = $resRevisa[1]['FCERROR'];
		     	if ($valorRegresa != '0' ) {
			   	die('*ERROR* de Transaccion PCKFACTURACIONGASTO.setDoctoSoporte...'.$valorRegresa);
			} //--if ($valorRegresa !
			}  //--if(is_array($resRevisa)       	
			//--************OBTIENE EL ID DEL 1ER AUTORIZADOR
			$query = "SELECT FCAUTORIZADOR
			 			FROM FACTURACIONAUT
					   WHERE IDDELINDEX = (SELECT MAX(IDDELINDEX) 
			                                 FROM FACTURACIONAUT 
			                                WHERE IDGASTOMAIN = $idgasto)
			                                  AND IDCONSEC = (SELECT MIN(IDCONSEC) 
			                                                    FROM FACTURACIONAUT 
			                                                   WHERE IDGASTOMAIN = $idgasto 
			                                                     AND FCRESULTADO IS NULL
			                                                     AND IDDELINDEX = (SELECT MAX(IDDELINDEX) 
			                                                                         FROM FACTURACIONAUT 
			                                                                        WHERE IDGASTOMAIN = $idgasto
			                                                                       )
			                                                  )
			                                  AND IDGASTOMAIN = $idgasto
		                                     AND FCRESULTADO IS NULL";	
		    $result = executeQuery($query, $bd);
		    if(is_array($result) && count($result) > 0){
			      $emailAut = $result[1]['FCAUTORIZADOR'];
			      $queryId = "SELECT USR_UID FROM USERS WHERE USR_EMAIL = '$emailAut' AND USR_STATUS = 'ACTIVE'";
			      $resultId = executeQuery($queryId);
			      if(is_array($resultId) && count($resultId) > 0){
		              @@verificaSoporte = $resultId[1]['USR_UID'];
                      
                        if($idgasto == 4312820){
                        	 @@verificaSoporte = '';
                      	}
                        
			      } //--if(is_array($resultId)
		    }//--if(is_array($result)			
		
		
	}  //---  if ( $queSolucionEs  = 'INTERNO')


	//*****  SI la Soucion es EXTERNA
	if ( $queSolucionEs  == 'EXTERNO'){
	//****************************************************************
	//----- SE EJECUTA PCKFACTURACIONGASTO.setTramiteExterno------//
	//****************************************************************
	       $fechaPago = NULL;
    	       if(@@fechaPago != NULL)
			$fechaPago = @@fechaPago;
		$queSolucionEs = @@tipoSolucionConcentradora;
		$queTipoTram = @@tipoSolucionTramite;
		$queESSolic = @@tipoSolicitud;
		$severidadTram  = @@severidadGasto;
		$fechaPgoTram  = @@fechaPago;
		$empFactTram = @@empresaFactura1;
		$otraempFactTram = @@otEmpresaFactura;
		$formaPagoTram = @@formaPago;
		$tipocuentaTram = @@tipoCuenta;
		$montoantTram = @@montoAnticipo;
		$provPagoTram  = @@cboProveedorPago;
		$quienDepoTram = @@asignacionDeposito;
	
             
		$queEjecuta = "PCKFACTURACIONGASTO.setTramiteExterno($idgasto,$queSolucionEs, $numEmpleadoActual,$severidadTram,$empFactTram,$otraempFactTram,$formaPagoTram,$tipocuentaTram,---,$fechaPago)";
		$addTramExt = "BEGIN 
				   PCKFACTURACIONGASTO.setTramiteExterno('$idgasto','$queSolucionEs', $numEmpleadoActual,'$severidadTram','$empFactTram','$otraempFactTram','$formaPagoTram','$tipocuentaTram','$queEjecuta','$fechaPago'); 
					END;";
                //die($addTramExt);
		$resTramExt= executeQuery($addTramExt, $oracle);
		//--- audita Ejecucionn del Store Procedure
		$queTramExt = "SELECT FCERROR FROM BITACORATRANSACCION
					 WHERE IDGASTOMAIN = $idgasto AND IDCONSEC = (SELECT MAX(IDCONSEC) FROM BITACORATRANSACCION 
					                  WHERE IDGASTOMAIN = $idgasto) AND FCEJECUTA = '$queEjecuta'";
		$resRevTramExt = executeQuery($queTramExt, $oracle);
		if(is_array($resRevTramExt) && count($resRevTramExt) > 0){
			 $valorRegresa = $resRevTramExt[1]['FCERROR'];
			 if ($valorRegresa != '0' ) {
			   die('*ERRORT1* de Transaccion. PCKFACTURACIONGASTO.setTramiteExterno ..'.$addTramExt);
			}
		}else{	
			die('*ERRORT2* NO existe PCKFACTURACIONGASTO.setTramiteExterno ...'.$addTramExt);
		}


//****************************************************************************************************
//------------------------- OBTIENE LA EMPRESA DE DYNAMICS -------------------------------//
//****************************************************************************************************
//var_dump("empresa::: " . $empFactTram . "...y.. otEmpresa" .$otEmpresa );exit;
$empresaSel = '';
$empresaFacturaDyn = '';
if($empFactTram != ''){
	$empresaSel = $empFactTram;
} else {
	$empresaSel = $otraempFactTram;
}

if(empresaSel != ''){
	$query = "SELECT IDEMPRESA,RFCCUENTA,FCEMPDYN FROM PENDUPM.EMPRESAFACTURACION where FCEMPDYN IS NOT NULL AND IDEMPRESA = $empresaSel";
	$result = executeQuery($query, $oracle);
	$empresaFacturaDyn = $result[1]['FCEMPDYN'];
}
@@empresaFacturaDyn = $empresaFacturaDyn;

  
  if ( @@TASK != '51395076558cb0db4288524083377624' ) {
  if($caso==4181897){
			echo 'R10 2 => '.$delIndex;exit;
		}
          	//------  *************  EJECUTA PARA DETERMINAR ALERTAS DE UMBRALES DE CREDITOS
		$queEjecuta = "PCKFACTURACIONGASTO.setUmbralTramite ($idgasto,$numEmpleadoActual ,--------------,$taskId, $delIndex);";
		$addGasto = "BEGIN PCKFACTURACIONGASTO.setUmbralTramite ($idgasto,$numEmpleadoActual ,'$queEjecuta','$taskId', $delIndex); END;";
		$resGasto = executeQuery($addGasto, $oracle);
	        $queRevisa = "SELECT FCERROR FROM BITACORATRANSACCION
	             WHERE IDGASTOMAIN = $idgasto AND IDCONSEC = (SELECT MAX(IDCONSEC) FROM BITACORATRANSACCION WHERE IDGASTOMAIN = $idgasto)
	               AND FCEJECUTA = '$queEjecuta'";
	    $resRevisa = executeQuery($queRevisa, $bd);
	    if(is_array($resRevisa) && count($resRevisa) > 0){
	        $valorRegresa = $resRevisa[1]['FCERROR'];
	        if ($valorRegresa != '0' ) {
		       die('*ERROR* de Transaccion. PCKFACTURACIONGASTO.setUmbralTramite  ..'.$valorRegresa);
		    }else{
				//--************OBTIENE EL ID DEL 1ER AUTORIZADOR
				$query = "SELECT FCAUTORIZADOR
				 			FROM FACTURACIONAUT
						   WHERE IDDELINDEX = (SELECT MAX(IDDELINDEX) 
				                                 FROM FACTURACIONAUT 
				                                WHERE IDGASTOMAIN = $idgasto)
				                                  AND IDCONSEC = (SELECT MIN(IDCONSEC) 
				                                                    FROM FACTURACIONAUT 
				                                                   WHERE IDGASTOMAIN = $idgasto 
				                                                     AND FCRESULTADO IS NULL
				                                                     AND IDDELINDEX = (SELECT MAX(IDDELINDEX) 
				                                                                         FROM FACTURACIONAUT 
				                                                                        WHERE IDGASTOMAIN = $idgasto
				                                                                       )
				                                                  )
				                                  AND IDGASTOMAIN = $idgasto
			                                     AND FCRESULTADO IS NULL";
				$result = executeQuery($query, $bd);
			    if(is_array($result) && count($result) > 0){
				      $emailAut = $result[1]['FCAUTORIZADOR'];
				      $queryId = "SELECT USR_UID FROM USERS WHERE USR_EMAIL = '$emailAut' AND USR_STATUS = 'ACTIVE'";
				      $resultId = executeQuery($queryId);
				      if(is_array($resultId) && count($resultId) > 0){
			              @@usuAutorizador01 = $resultId[1]['USR_UID'];
				      } //--if(is_array($resultId)
			    }//--if(is_array($result)			    	
		    }
	    }else{	
		       die('*ERROR* NO existe PCKFACTURACIONGASTO.setDoctoExcGtoEtaFinal ...'.$queEjecuta);
	    } //---  if(is_array($resRevisa)
    	
      
}
      
      
		//---- VARIABLE para saber que se rebaso umbral
		$query = "SELECT COUNT(1) REBASADO FROM FACTURACIONAUT WHERE IDTIPOAUTORIZA = 6 AND IDGASTOMAIN = $idgasto AND FCRESULTADO IS NULL";
		$result = executeQuery($query, $oracle);
		@@umbralRebasadoTramite = $result[1]['REBASADO'];
		$hayUmbralesTram = $result[1]['REBASADO'];
               //***  vrifica si hay umbrales no ejecuta  etapas o documentos de soporte		
		if ( $hayUmbralesTram  == 0 ){
	             $hayAutExed = 0;
		    //------  *************  EJECUTA PARA DETERMINAR ALERTAS DE EXCEDENTES EN COMPROBACION
		    $operacion = "PCKFACTURACIONGASTO.setDoctoExcGtoEtaFinal ( $idgasto, $numEmpleadoActual, '--------', '$taskId', $indice,'TRAMITE',$queTipoTram)";
		    $cadena = str_replace("'", "", $operacion);
		    $operacion = "BEGIN PCKFACTURACIONGASTO.setDoctoExcGtoEtaFinal ( $idgasto, $numEmpleadoActual, '$cadena', '$taskId', $indice,'TRAMITE','$queTipoTram'); END;";
		    //---die($operacion);
		    executeQuery($operacion, $bd);
		    $queRevisa = "SELECT FCERROR FROM BITACORATRANSACCION
		             WHERE IDGASTOMAIN = $idgasto AND IDCONSEC = (SELECT MAX(IDCONSEC) FROM BITACORATRANSACCION WHERE IDGASTOMAIN = $idgasto)
		               AND FCEJECUTA = '$cadena'";
		    $resRevisa = executeQuery($queRevisa, $bd);
		    if(is_array($resRevisa) && count($resRevisa) > 0){
		        $valorRegresa = $resRevisa[1]['FCERROR'];
		        if ($valorRegresa != '0' ) {
			       die('*ERROR* de Transaccion...'.$valorRegresa);
			    }else{
		            $queryAut = "SELECT COUNT(1) EXISTE FROM FACTURACIONAUT WHERE IDGASTOMAIN = $idgasto AND IDDELINDEX = $indice AND IDTIPOAUTORIZA IN (44, 45)";
		            $resAut = executeQuery($queryAut, $bd);
		            @@existeAutExcedentes = $resAut[1]['EXISTE'];
		            $hayAutExed = $resAut[1]['EXISTE'];
		        } //--- if ($valorRegresa
		    }else{	
			       die('*ERROR* NO existe PCKFACTURACIONGASTO.setDoctoExcGtoEtaFinal ...'.$queEjecuta);
		    } //---  if(is_array($resRevisa)

		    //----  SI NO hay autorizaciones de excedentes
		    if ( $hayAutExed == 0 ) { 
                       $comoSePaga = @@tipoSolucionTramite;
                       if ( $comoSePaga != 'Anticipo'){ 
			    //------  ****  EJECUTA PARA AUTORIZADORES DE SOPORTE
				$queEjecuta = "PCKFACTURACIONGASTO.setDoctoSoporte($idgasto ,$numEmpleadoActual,--------------,$taskId, $indice);";
				$addGasto = "BEGIN PCKFACTURACIONGASTO.setDoctoSoporte($idgasto ,$numEmpleadoActual,'$queEjecuta','$taskId', $indice); END;";
		                 //die($addGasto);
		
				executeQuery($addGasto, $bd);
			
				//--- audita Ejecucionn del Store Procedure
				$queRevisa = "SELECT FCERROR FROM BITACORATRANSACCION
			             WHERE IDGASTOMAIN = $idgasto  AND IDCONSEC = (SELECT MAX(IDCONSEC) FROM BITACORATRANSACCION WHERE IDGASTOMAIN = $idgasto )
			               AND FCEJECUTA = '$queEjecuta'";
				$resRevisa = executeQuery($queRevisa, $bd);
				if(is_array($resRevisa) && count($resRevisa) > 0){
			    	 $valorRegresa = $resRevisa[1]['FCERROR'];
			     	if ($valorRegresa != '0' ) {
				   	die('*ERROR* de Transaccion PCKFACTURACIONGASTO.setDoctoSoporte...'.$valorRegresa);
				} //--if ($valorRegresa !
				}  //--if(is_array($resRevisa)    
                        }  //---if ( $comoSePaga != 'Anticipo') 	
		    } //--if ( $hayAutExed > 0)	
		
		     @@hayAlertasPend = 0;
		
			$query = "SELECT FCAUTORIZADOR
			 			FROM FACTURACIONAUT
					   WHERE IDDELINDEX = (SELECT MAX(IDDELINDEX) 
			                                 FROM FACTURACIONAUT 
			                                WHERE IDGASTOMAIN = $idgasto)
			                                  AND IDCONSEC = (SELECT MIN(IDCONSEC) 
			                                                    FROM FACTURACIONAUT 
			                                                   WHERE IDGASTOMAIN = $idgasto 
			                                                     AND FCRESULTADO IS NULL
			                                                     AND IDDELINDEX = (SELECT MAX(IDDELINDEX) 
			                                                                         FROM FACTURACIONAUT 
			                                                                        WHERE IDGASTOMAIN = $idgasto
			                                                                       )
			                                                  )
			                                  AND IDGASTOMAIN = $idgasto
			                                   AND FCRESULTADO IS NULL";	
		    $result = executeQuery($query, $bd);
		    if(is_array($result) && count($result) > 0){
			      $emailAut = $result[1]['FCAUTORIZADOR'];
			      $queryId = "SELECT USR_UID FROM USERS WHERE USR_EMAIL = '$emailAut' AND USR_STATUS = 'ACTIVE'";
			      $resultId = executeQuery($queryId);
			
			      if(is_array($resultId) && count($resultId) > 0){
		                  if ( $hayAutExed > 0 )
			               @@hayAlertasPend = 1;
			      } //--if(is_array($resultId)
		    }//--if(is_array($result)
		    
		    //--***** ASIGNA DEPENDIENDO A QUIEN SE VA LA AUTORIZACION SOPORTE O EXCEDENTES
		    if ( $hayAutExed == 0 ) { 
		    	@@verificaSoporte = $resultId[1]['USR_UID'];
		        //die(' soportr ...  ' . @@verificaSoporte);
		    }else{
		    	@@autExcedentes = $resultId[1]['USR_UID'];
		        //die(' excedente ...  ' . @@autExcedentes );
		    } //---if ( $hayAutExed == 0 )
		}//-- hay ubmrales  
		} //--if ( $queSolucionEs  = 'EXTERNO')
		
    $hayAlertas = "SELECT COUNT(1) TOT FROM FACTURACIONAUT 
                   WHERE IDGASTOMAIN = $idgasto AND IDTIPOAUTORIZA != 41 AND FDFECAUTORIZA IS NULL
                     AND IDDELINDEX = (SELECT MAX(IDDELINDEX) FROM FACTURACIONAUT WHERE IDGASTOMAIN= $idgasto)";
    //--die($hayAlertas);
    $resAlert = executeQuery( $hayAlertas , $bd);    
    @@justificatramite = $resAlert[1]['TOT'];
      
      
		    
}catch (Exception $e){
    $e->getMessage();
   die($e);
}  //---}catch   -  TRY


