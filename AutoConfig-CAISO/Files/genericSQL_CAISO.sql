DECLARE 
script clob;
tmp1 varchar2(100);
tmp2 varchar2(100);
BEGIN
	script := 'import com.pci.iso.util.*;
	import com.pci.iso.data.*;
	import java.util.Hashtable;
	DriverParameters[] parameters=null;
	DriverParameterManager parameterManager=null;
	{
	global.parameters = new DriverParameters[23];
	global.parameters[0] = new DriverParameters("ALIAS",
								"",
								"Alias in CRN report",
								true);
	global.parameters[1] = new DriverParameters("ARCHIVE_DIRECTORY",
								"C:\\CAISO\\Archive",
								"Directory to archive processed files",
								true);
	global.parameters[2] = new DriverParameters("AUTO_UPLOAD_DIRECTORY",
								"C:\\CAISO\\Auto_Upload",
								"Directory to place files to be uploaded automatically to ISO",
								true);
	global.parameters[3] = new DriverParameters("CAISO_NOTIFICATION_PROCESS",
								"",
								"Execute Task when a notification message is received. Example-> MarketResult:ExecutePostNotification",
								true);
	global.parameters[4] = new DriverParameters("CRN_FTP_HOST",
								"",
								"URL of the server to use when retrieving CMRI reports",
								true);
	global.parameters[5] = new DriverParameters("CRN_FTP_PASSWORD",
								"[*MQ==",
								"Password of the certificate to use when retrieving CMRI reports",
								true);
	global.parameters[6] = new DriverParameters("CRN_FTP_PRIVATEKEY",
								"",
								"Private Key for CRN.",
								true);
	global.parameters[7] = new DriverParameters("CRN_FTP_USER",
								"",
								"Name of the certificate owner to use when retrieving CMRI reports",
								true);
	global.parameters[8] = new DriverParameters("DOWNLOAD_DIRECTORY",
								"C:\\CAISO\\Download",
								"Directory for all the files from ISO",
								true);
	global.parameters[9] = new DriverParameters("KEY_PASSWORD",
								"[*MQ==",
								"Password of the alias in CRN report",
								true);
	global.parameters[10] = new DriverParameters("OMAR_KEYSTORE",
								"",
								"Keystore for OMAR private key",
								true);
	global.parameters[11] = new DriverParameters("OMAR_KEYSTORE_PASSWORD",
								"[*MQ==",
								"Passowrd to access OMAR private key",
								true);
	global.parameters[12] = new DriverParameters("RAAM_URL",
								"https://portalmktsim.caiso.com/scp/services",
								"URL for RAAM",
								true);
	global.parameters[13] = new DriverParameters("SETTLEMENT_ARCHIVE_DIRECTORY",
								"C:\\CAISO\\Settlements\\Archive",
								"Directory to archive processed settlement files",
								true);
	global.parameters[14] = new DriverParameters("SETTLEMENT_DOWNLOAD_DIRECTORY",
								"C:\\CAISO\\Settlements\\Download",
								"Directory to place settlement files that are downloaded from the ISO",
								true);
	global.parameters[15] = new DriverParameters("SETTLEMENT_HISTORIC_DIRECTORY",
								"C:\\CAISO\\Settlements\\Historic",
								"Directory to place settlement files that are downloaded from the ISO",
								true);
	global.parameters[16] = new DriverParameters("TEST_MODE",
								"false",
								"Flag to indicate the driver is in test mode (true/false)",
								true);
	global.parameters[17] = new DriverParameters("TRUST_STORE",
								"C:\\CAISO\\CAISOEIM.keystore",
								"Service trust manager store",
								true);
	global.parameters[18] = new DriverParameters("TRUST_STORE_PASSWORD",
								"caisoteam",
								"Passowrd to access the trust store TRUST_STORE",
								true);
	global.parameters[19] = new DriverParameters("UPLOAD_DIRECTORY",
								"C:\\CAISO\\Upload",
								"Directory to place files to be uploaded to ISO",
								true);
	global.parameters[20] = new DriverParameters("USE_MODE",
								"N",
								"Use Production (P), MAP Stage (N), Stage (L) or Test (T) environment",
								true);
	global.parameters[21] = new DriverParameters("VALIDATE_XML",
								"true",
								"Flag to indicate if XML validation should be performed on all XML sent and received",
								true);
	global.parameters[22] = new DriverParameters("VALIDATE_XML_SCHEMA",
								"c:\\web_services\\caiso.txt",
								"Defines the schema files for validating XML documents",
								true);

	global.parameterManager = new DriverParameterManager(global.parameters, GenPortalSys.user.getUserName());
	paramTable = new Hashtable();
	for(int i = 0; i < global.parameters.length; i++)
		paramTable.put(global.parameters[i].getName(), global.parameters[i].getValue());
	}
	DriverParameterManager getDriverParameterManager() {
	return global.parameterManager;
	}
	setDriverParameterManager(DriverParameterManager parameterManager) {
	global.parameterManager = parameterManager;
	}
	DriverParameters[] getDriverParameters() {
	return global.parameters;
	}
	setDriverParameters(DriverParameters[] parameters) {
	global.parameters = parameters;
	}';
	UPDATE SSCRIPT_LIBRARY SET CODE = script WHERE DESCRIPTION = 'CaisoDriverParametersInstall' and NAME = 'CaisoDriverParametersInstall';
	UPDATE SLOV_VALUE SET PROPERTY1 = 'C:\CAISO\CAISOEIM.keystore', PROPERTY2 = 'caisoteam', PROPERTY4 = 'caisoteam' WHERE LOV_KEY = (SELECT LOV_KEY from SLOV WHERE Name like 'CAISO OMS Market Participant Info');
	
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Archive' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'ARCHIVE_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Auto_Upload' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'AUTO_UPLOAD_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Download' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'DOWNLOAD_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Settlements\Download' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'INVOICE_LOAD_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Bid_Status' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'MERCHANT_TO_ENTITY_SHARE';

	UPDATE SPARAMETER SET VALUE = 'T' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'OMS_MODE';
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\CAISOEIM.keystore' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'OMS_TRUSTSTORE';
	UPDATE SPARAMETER SET VALUE = 'caisoteam' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'OMS_TRUSTSTOREPASSWORD';

	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Settlements\Archive' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'SETTLEMENT_ARCHIVE_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Settlements\Download' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'SETTLEMENT_DOWNLOAD_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Settlements\Historic' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'SETTLEMENT_HISTORIC_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Settlements\Upload' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'STATEMENT_LOAD_DIRECTORY';

	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\CAISOEIM.keystore' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'TRUST_STORE';
	UPDATE SPARAMETER SET VALUE = 'caisoteam' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'TRUST_STORE_PASSWORD';
	
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Upload' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'UPLOAD_DIRECTORY';
	
	UPDATE SPARAMETER SET VALUE = 'N' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'USE_MODE';

	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Import_Datafeed\Import_Files\Load_Forecast\Archive' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'ARCHIVE_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Import_Datafeed\Import_Files' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'IMPORT_FILES';
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Import_Datafeed\IT_Datafeed_Files' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'IT_DATAFEED_FILES';
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Import_Datafeed\IT_Datafeed_Files\WACOG' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'IT_DATAFEED_FILES_WACOG';
	
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Bid_Status' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'M_TO_E';
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Exports' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'OBJ_STORE_PATH';
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Exports' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'RTP.OBJ_STORE_PATH';

	UPDATE SPARAMETER SET VALUE = 'PCI Cloud Environment' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'ENVIRONMENT';

	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Import_Datafeed\ETL_Export_Latest' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'ETL_EXPORT_LATEST';
	UPDATE SPARAMETER SET VALUE = 'C:\CAISO\Exports' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'EXPORT_FILES';

	UPDATE SPARAMETER SET VALUE = 'gsms' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'GP_CONNECT';
	UPDATE SPARAMETER SET VALUE = 'pci' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'GP_PASSWORD';
	UPDATE SPARAMETER SET VALUE = 'pci' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'GP_USER';
	UPDATE SPARAMETER SET VALUE = 'false' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'FILE_ARCHIVER_ENABLED';

	UPDATE SPARAMETER SET VALUE = 'true' WHERE SYSTEM = 'GenManager' and TYPE = 'ISO' and NAME = 'STORE_BID_RESULT_DATA';
	UPDATE SPARAMETER SET VALUE = 'C:\ISO\STORE_BID_RESULT_DATA' WHERE SYSTEM = 'GenManager' and TYPE = 'ISO' and NAME = 'STORE_BID_RESULT_DATA_DIR';
	UPDATE SPARAMETER SET VALUE = 'true' WHERE SYSTEM = 'GenManager' and TYPE = 'ISO' and NAME = 'STORE_BID_SUBMIT_DATA';
	UPDATE SPARAMETER SET VALUE = 'C:\ISO\STORE_BID_SUBMIT_DATA' WHERE SYSTEM = 'GenManager' and TYPE = 'ISO' and NAME = 'STORE_BID_SUBMIT_DATA_DIR';
	UPDATE SPARAMETER SET VALUE = 'true' WHERE SYSTEM = 'GenManager' and TYPE = 'ISO' and NAME = 'STORE_CB_BID_DATA';
	
	UPDATE SPARAMETER SET VALUE = 'DEV REFRESH' WHERE NAME = 'ENVIRONMENT';
	DELETE FROM SPARAMETER WHERE NAME = 'AUTO_QUERY_BID_RESULTS_RT';
	BEGIN 
		SELECT VALUE INTO tmp1 FROM sparameter WHERE NAME='STORE_BID_RESULT_DATA'; 
	EXCEPTION
		WHEN no_data_found THEN
		INSERT INTO SPARAMETER (PARAMETER_KEY, NAME, VALUE, DESCRIPTION, SYSTEM, TYPE, MODIFIEDON, MODIFIEDBY, CREATEDON, CREATEDBY) VALUES ((SELECT MAX(PARAMETER_KEY)+1 FROM SPARAMETER), 'STORE_BID_RESULT_DATA', 'true', '','GenManager', 'ISO', '10-JAN-18 11.05.04.000000000 PM', 'background', '10-JAN-18 11.05.04.000000000 PM', 'background');
	END; 
	BEGIN 
		SELECT VALUE INTO tmp2 FROM sparameter WHERE NAME='STORE_BID_RESULT_DATA_DIR'; 
	EXCEPTION
		WHEN no_data_found THEN
		INSERT INTO SPARAMETER (PARAMETER_KEY, NAME, VALUE, DESCRIPTION, SYSTEM, TYPE, MODIFIEDON, MODIFIEDBY, CREATEDON, CREATEDBY) VALUES ((SELECT MAX(PARAMETER_KEY)+1 FROM SPARAMETER), 'STORE_BID_RESULT_DATA_DIR', 'C:\ISO\STORE_BID_RESULT_DATA', '','GenManager', 'ISO', '10-JAN-18 11.05.04.000000000 PM', 'background', '10-JAN-18 11.05.04.000000000 PM', 'background');
	END; 
	UPDATE SSYS_ID SET NEXT_KEY = (SELECT MAX(PARAMETER_KEY) FROM SPARAMETER) WHERE ID_TYPE = 'PARAMETER';
	COMMIT;
END;
