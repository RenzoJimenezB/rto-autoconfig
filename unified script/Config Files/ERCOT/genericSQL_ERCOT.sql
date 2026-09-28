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
	global.parameters = new DriverParameters[25];
	global.parameters[0] = new DriverParameters("SANDBOX_URL", 
							"https://testmisapi.ercot.com/NodalAPI/EWS/", 
							"Testing MOTE URL",
							true);
	global.parameters[1] = new DriverParameters("PRODUCTION_URL", 
							"https://misapi.ercot.com/NodalAPI/EWS/", 
							"Production MIS URL",
							true);
	global.parameters[2] = new DriverParameters("USE_MODE", 
							"S", 
							"Use S for MOTE or M for Production/MIS",
							true);
	global.parameters[3] = new DriverParameters("UPLOAD_DIRECTORY", 
							"C:\\ERCOT\\FO\\Upload", 
							"Directory to place files to be uploaded to ISO",
							true);
	global.parameters[4] = new DriverParameters("DOWNLOAD_DIRECTORY", 
							"C:\\ERCOT\\FO\\Download", 
							"Directory to place files that are downloaded from the ISO",
							true);
	global.parameters[5] = new DriverParameters("ARCHIVE_DIRECTORY", 
							"C:\\ERCOT\\FO\\Archive", 
							"Directory to archive processed files",
							true);
	global.parameters[6] = new DriverParameters("AUTO_UPLOAD_DIRECTORY", 
							"C:\\ERCOT\\FO\\Upload\\Auto", 
							"Directory to place files to be uploaded automatically to ISO",
							true);
	global.parameters[7] = new DriverParameters("TRUST_STORE", 
							"C:\\ERCOT\\clientTruststore.jks", 
							"Service trust manager store",
							true);
	global.parameters[8] = new DriverParameters("TRUST_STORE_PASSWORD", 
							"changeit", 
							"Password to access the trust store TRUST_STORE",
							true);
	global.parameters[9] = new DriverParameters("TEST_MODE", 
							"false", 
							"Flag to indicate the driver is in test mode (true/false)",
							true);
	global.parameters[10] = new DriverParameters("ERCOT_NOTIFICATION_PROCESS", 
							"", 
							"Execute Task when a notification message is received. Example-> MarketResult:ExecutePostNotification",
							true);
	global.parameters[11] = new DriverParameters("WSDD_FILE", 
							"-", 
							"Location of the Web service deployment definition file",
							true);
	global.parameters[12] = new DriverParameters("WAN_URL_MODE", 
							"false", 
							"Switch to turn on the submission over WAN",
							true);
	global.parameters[13] = new DriverParameters("MIS_WAN_URL", 
							"https://api.wan.ercot.com", 
							"WAN MIS URL",
							true);
	global.parameters[14] = new DriverParameters("MOTE_WAN_URL", 
							"https://testing.wan.ercot.com", 
							"WAN MOTE URL",
							true);
	global.parameters[15] = new DriverParameters("RELAY_WSDD_FILE", 
							"-", 
							"Location of the Web service deployment definition file on the relay service.",
							true);
	global.parameters[16] = new DriverParameters("RELAY_TRUSTSTORE", 
							"c:\\ERCOT\\GSMS_keystore.jks", 
							"Relay service truststore for GSMS.",
							true);
	global.parameters[17] = new DriverParameters("RELAY_TRUSTSTORE_PASSWORD", 
							"{GSMS.1}Zz/NdfUI/78+msw6mh2vLw==", 
							"Relay service truststore password.",
							true);
	global.parameters[18] = new DriverParameters("RELAY_ARCHIVE_DIRECTORY", 
							"c:\\ERCOT\\archive", 
							"Directory to archive processed files on relay service.",
							true);
	global.parameters[19] = new DriverParameters("RELAY_ACTIVE", 
							"false", 
							"Switch to turn on the submission via relay service.",
							true);
	global.parameters[20] = new DriverParameters("RELAY_KEYSTORE", 
							"c:\\ERCOT\\GSMS_keystore.jks", 
							"Relay service keystore for GSMS.",
							true);
	global.parameters[21] = new DriverParameters("RELAY_KEYSTORE_PASSWORD", 
							"{GSMS.1}Zz/NdfUI/78+msw6mh2vLw==", 
							"Relay service keystore password.",
							true);
	global.parameters[22] = new DriverParameters("AUTO_IMPORT_DIRECTORY", 
							"C:\\ERCOT\\FO\\Import", 
							"Import directory for the file watcher standard imports.",
							true);
	global.parameters[23] = new DriverParameters("RELAY_URL_MOTE", 
							"", 
							"Used when USE_MODE is S (Mote/Sandbox)",
							true);
	global.parameters[24] = new DriverParameters("RELAY_URL_PROD", 
							"", 
							"Used when USE_MODE is M (Prod/MIS)",
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
	UPDATE SSCRIPT_LIBRARY SET CODE = script WHERE DESCRIPTION = 'ErcotDriverParametersInstall' and NAME = 'ErcotDriverParametersInstall';

	UPDATE SUSER SET U_PASSWORD = 'gtwp$pci1' WHERE U_NAME IN ('Admin','background');
	UPDATE SPARAMETER SET "VALUE" = 'gtwp$pci1' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'BACKGROUND_PASSWORD';

	UPDATE SASSET_OWNER_CONFIG SET ACTIVE = 'N';

	UPDATE SPARAMETER SET VALUE = 'C:\ERCOT\BO\Archive' WHERE SYSTEM = 'GenManager' and TYPE = 'ERCOT' and NAME = 'ARCHIVE_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\ERCOT\BO\Download' WHERE SYSTEM = 'GenManager' and TYPE = 'ERCOT' and NAME = 'DOWNLOAD_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\ERCOT\BO\Invoices' WHERE SYSTEM = 'GenManager' and TYPE = 'ERCOT' and NAME = 'INVOICE_LOAD_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\ERCOT\BO\invoice_reports' WHERE SYSTEM = 'GenManager' and TYPE = 'ERCOT' and NAME = 'INVOICE_REPORT_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\ERCOT\BO\Calendar' WHERE SYSTEM = 'GenManager' and TYPE = 'ERCOT' and NAME = 'ISO_CALENDAR_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\ERCOT\BO\Statements' WHERE SYSTEM = 'GenManager' and TYPE = 'ERCOT' and NAME = 'STATEMENT_LOAD_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\ERCOT\BO\Manual' WHERE SYSTEM = 'GenManager' and TYPE = 'ERCOT' and NAME = 'STATEMENT_MANUAL_LOAD';

	UPDATE SPARAMETER SET VALUE = 'PCI Cloud Environment' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'ENVIRONMENT';
	UPDATE SPARAMETER SET VALUE = '<a href="../../common/portal.jsp"><img id="logo-img" src="/images/logo-white-on-clear-bg.svg"/></a>' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'PORTAL_LOGO';
	UPDATE SPARAMETER SET VALUE = '<a href="../../common/portal.jsp"><img id="logo-img" src="/images/logo-white-on-clear-bg.svg"/></a>' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'PORTAL_LOGO_DARK';
	
	UPDATE SPARAMETER SET VALUE = 'gsms' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'GP_CONNECT';
	UPDATE SPARAMETER SET VALUE = 'pci' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'GP_PASSWORD';
	UPDATE SPARAMETER SET VALUE = 'pci' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'GP_USER';
	UPDATE SPARAMETER SET VALUE = 'false' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'FILE_ARCHIVER_ENABLED';
	COMMIT;
END;