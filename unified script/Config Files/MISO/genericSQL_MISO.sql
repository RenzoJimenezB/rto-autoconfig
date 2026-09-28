DECLARE
script clob;
tmp1 varchar2(100);
tmp2 varchar2(100);
BEGIN
	script := 'import java.rmi.RemoteException;
	import java.util.Hashtable;

	import javax.ejb.CreateException;
	import javax.naming.NamingException;

	import com.pci.gtdw.ObjectHierarchy;
	import com.pci.gtdw.ObjectHierarchyHome;
	import com.pci.gtdw.editor.ScriptLibraryEditor;
	import com.pci.gtdw.editor.ScriptLibraryEditorHome;
	import com.pci.gtdw.exceptions.GetViewsException;
	import com.pci.gtdw.exceptions.ObjectNotFoundException;
	import com.pci.gtdw.util.JNDINames;
	import com.pci.gtdw.view.ScriptLibraryView;
	import com.pci.iso.data.DriverParameters;
	import com.pci.iso.util.DriverParameterManager;

	DriverParameters[] parameters=null;
	DriverParameterManager parameterManager=null;
	Hashtable paramTable = null;
	void loadParameters() {
	global.parameters = new DriverParameters[34];
	int i = 0;
	global.parameters[i++] = new DriverParameters("UPLOAD_DIRECTORY", "C:\\MISO\\upload", "Directory to place files to be uploaded to ISO", true);
	global.parameters[i++] = new DriverParameters("DOWNLOAD_DIRECTORY", "C:\\MISO\\download", "Directory to place files that are downloaded from the ISO", true);
	global.parameters[i++] = new DriverParameters("ARCHIVE_DIRECTORY", "C:\\MISO\\archive", "Directory to archive processed files", true);
	global.parameters[i++] = new DriverParameters("PARTICIPANT_CODE", "PCI", "MISO ID", true);
	global.parameters[i++] = new DriverParameters("DART_USE_SSL", "true", "Flag to indicate if SSL should be used to communicate (true/false)", true);
	global.parameters[i++] = new DriverParameters("DART_HOST", "markets.midwestiso.org", "MISO host name", true);
	global.parameters[i++] = new DriverParameters("TRUST_STORE", "C:\\MISO\\certs\\miso.jks", "Service trust manager store", true);
	global.parameters[i++] = new DriverParameters("TRUST_STORE_PASSWORD", "changeit", "Password to access the TRUST_STORE", true);
	global.parameters[i++] = new DriverParameters("HANDSHAKE_RETRIES", "1", "Number of handshake retries for SSL", true);
	global.parameters[i++] = new DriverParameters("DART_ENVELOPE_START", "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<env:Envelope xmlns:env=\"http://schemas.xmlsoap.org/soap/envelope/\">\n    <env:Body>\n", "Start of the SOAP envelope", true);
	global.parameters[i++] = new DriverParameters("DART_ENVELOPE_END", "    </env:Body>\n</env:Envelope>", "End of the SOAP envelope", true);
	global.parameters[i++] = new DriverParameters("DART_URL_QUERY", "/darteor/xml/query", "MISO Query URL", true);
	global.parameters[i++] = new DriverParameters("DART_URL_SUBMIT", "/darteor/xml/submit/changeme", "MISO Submit URL", true);
	global.parameters[i++] = new DriverParameters("TEST_MODE", "false", "Flag to indicate the driver is in test mode (true/false)", true);
	global.parameters[i++] = new DriverParameters("ISSUE_ALARMS", "true", "Flag to indicate if the driver should issue alarms or not (true/false)", true);
	global.parameters[i++] = new DriverParameters("SOAP_NS", "http://schemas.xmlsoap.org/soap/envelope/", "Namespace used on the SOAP message", true);
	global.parameters[i++] = new DriverParameters("DART_NS", "http://markets.midwestiso.org/dart/xml", "Namespace used on the MISO message", true);
	global.parameters[i++] = new DriverParameters("AUTO_UPLOAD_DIRECTORY", "C:\\MISO\\upload", "Directory to place files to be uploaded automatically to ISO", true);
	global.parameters[i++] = new DriverParameters("DART_VALIDATE_XML", "false", "Flag to indicate if XML validation should be performed on all XML sent and received (true/false)", true);
	global.parameters[i++] = new DriverParameters("DART_VALIDATE_XML_SCHEMA", "c:\\web_services\\miso.txt", "Defines the schema file for validating XML documents", true);
	global.parameters[i++] = new DriverParameters("COS_HOST", "markets.midwestiso.org", "MISO COS Settlement Server", true);
	global.parameters[i++] = new DriverParameters("COS_URL", "/axis/servlet/AxisServlet", "URL used to communicate with COS_HOST", true);
	global.parameters[i++] = new DriverParameters("COS_USE_SSL", "true", "Indicate if SSL is used to communicate with COS", true);
	global.parameters[i++] = new DriverParameters("COS_ENVELOPE_START", "<?xml version=\"1.0\" encoding=\"UTF-8\" ?><SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\n<SOAP-ENV:Body>\n", "Start of the COS SOAP envelope", true);
	global.parameters[i++] = new DriverParameters("COS_ENVELOPE_END", "</SOAP-ENV:Body>\n</SOAP-ENV:Envelope>", "End of the COS SOAP envelope", true);
	global.parameters[i++] = new DriverParameters("COM_TIMEOUT", "60000", "Time out for ISO Communications tasks (in milliseconds)", true);
	global.parameters[i++] = new DriverParameters("METER_UPLOAD_URL", "/PI/MeterDataUpload/", "URL used to upload actual meter values to COS_HOST", true);
	global.parameters[i++] = new DriverParameters("MISO_CA_MESSAGES", "NSINotification", "The tag names of control area notification messages to process.", true);
	global.parameters[i++] = new DriverParameters("MISO_NOTIFICATION_PROCESS", "", "Execute Task to run when a notification message is received (Example-> MarketResult:ExecutePostNotification)", true);
	global.parameters[i++] = new DriverParameters("PSS_HOST", "www.miso.oati.com", "PSS host name", true);
	global.parameters[i++] = new DriverParameters("PSS_URL", "/sched_miso/mes/xml/sched-mes-soap-entrypoint.wml", "PSS URL", true);
	global.parameters[i++] = new DriverParameters("DRTool_URL", "https://cce.midwestiso.org/sbm/webservice/HTTPEndPoint", "Demand Response Tool URL to submit meter data", true);
	global.parameters[i++] = new DriverParameters("SETTLEMENT_INVOICE_DOWNLOAD_URL", "/portalDownload/invoices/file?entity=", "MISO Settlement Invoice Download URL", true);
	global.parameters[i++] = new DriverParameters("SETTLEMENT_STATEMENT_DOWNLOAD_URL", "/portalDownload/ssi/file?date=", "MISO Settlement Statement Download URL", true);

	ScriptLibraryEditor scriptEditor = ((ScriptLibraryEditorHome) GenPortalSys.context.lookup(JNDINames.SCRIPTLIBRARYEDITOR_EJBHOME)).create();
	ObjectHierarchy oh = ((ObjectHierarchyHome) GenPortalSys.context.lookup(JNDINames.OBJECTHIERARCHY_EJBHOME)).create();
	ScriptLibraryView script = scriptEditor.Load(oh.getView("Tasks").getViewKey(), "MisoDriverParameters");
	for (int counter = 0; counter < i; ++counter)
	{
	global.parameters[counter].setModifiedBy(script.getModifiedBy());
	global.parameters[counter].setModifiedOn(script.getModifiedOn());
	}
	global.parameterManager = new DriverParameterManager(global.parameters, GenPortalSys.user.getUserName());
	global.paramTable = new Hashtable();
	for(int j = 0; j < global.parameters.length; j++)
	global.paramTable.put(global.parameters[j].getName(), global.parameters[j].getValue());
	}
	DriverParameterManager getDriverParameterManager() {
	if (global.parameterManager == null) {
	loadParameters();
	}
	return global.parameterManager;
	}
	DriverParameters[] getDriverParameters() {
	if (global.parameters == null) {
	loadParameters();
	}
	return global.parameters;
	}
	Hashtable getDriverParameterTable() {
	if (global.paramTable == null) {
	loadParameters();
	}
	return global.paramTable;
	}
	DriverParameters[] swapToOld() {
	DriverParameters DartQuery = new DriverParameters("DART_URL_QUERY", "/dart/xml/query", "MISO query url", true);
	DriverParameters DartSubmit = new DriverParameters("DART_URL_SUBMIT", "/dart/xml/submit", "MISO submit url", true);
	swap(DartQuery,DartSubmit);
	return global.parameters;
	}
	DriverParameters[] swapToNew() {
	DriverParameters DartQuery = new DriverParameters("DART_URL_QUERY", "/darteor/xml/query", "MISO ASM query url", true);
	DriverParameters DartSubmit = new DriverParameters("DART_URL_SUBMIT", "/darteor/xml/submit", "MISO ASM submit url", true);
	swap(DartQuery,DartSubmit);
	return global.parameters;
	}
	void swap(DriverParameters query, DriverParameters submit) {
	boolean gotQuery = false;
	boolean gotSubmit = false;
	if (global.paramTable == null) {
	loadParameters();
	}
	for (int i=0;i<global.parameters.length;i++) {
	if (global.parameters[i].getName().equals(query.getName())) {
	global.parameters[i].setValue(query.getValue());
	global.paramTable.put(query.getName(),query.getValue());
	gotQuery = true;
	}
	if (global.parameters[i].getName().equals(submit.getName())) {
	global.parameters[i].setValue(submit.getValue());
	global.paramTable.put(submit.getName(), submit.getValue());
	gotSubmit = true;
	}
	}
	if (!gotQuery) {
	DriverParameters [] newParameters = new DriverParameters [global.parameters.length+1];
	for (int i=0;i<global.parameters.length;i++) {
	newParameters[i] = global.parameters[i];
	}
	newParameters[newParameters.length-1]= new DriverParameters("DART_URL_QUERY", query.getValue(), "MISO query url", true);
	global.parameters = newParameters;
	global.paramTable.put(query.getName(),query.getValue());
	}
	if (!gotSubmit) {
	DriverParameters [] newParameters = new DriverParameters [global.parameters.length+1];
	for (int i=0;i<global.parameters.length;i++) {
	newParameters[i] = global.parameters[i];
	}
	newParameters[newParameters.length-1]= new DriverParameters("DART_URL_SUBMIT", submit.getValue(), "MISO submit url", true);
	global.parameters = newParameters;
	global.paramTable.put(submit.getName(), submit.getValue());	
	}
	}
	void swapOrAdd(String newName, String newValue) {
	swapOrAdd(newName,newValue,"NEW PARAMETER",true);
	}
	void swapOrAdd(String newName, String newValue, String newDescription) {
	swapOrAdd(newName,newValue,newDescription,true);
	}
	void swapOrAdd(String newName, String newValue, String newDescription, boolean newUpdateable){
	DriverParameters np = new DriverParameters(newName,newValue,newDescription,newUpdateable);
	swapOrAdd(np);
	}
	void swapOrAdd(DriverParameters newParam) {
	boolean gotParam = false;
	if (global.paramTable == null) {
	loadParameters();
	}
	for (int i=0;i<global.parameters.length && !gotParam;i++) {
	if (global.parameters[i].getName().equals(newParam.getName())) {
	global.parameters[i].setDescription(newParam.getDescription());
	global.parameters[i].setValue(newParam.getValue());
	global.parameters[i].setUpdateable(newParam.getUpdateable());
	global.paramTable.put(newParam.getName(),newParam.getValue());
	gotParam = true;
	}
	}
	if (!gotParam) {
	DriverParameters [] newParameters = new DriverParameters [global.parameters.length+1];
	for (int i=0;i<global.parameters.length;i++) {
	newParameters[i] = global.parameters[i];
	}
	newParameters[newParameters.length-1]= newParam;
	global.parameters = newParameters;
	global.paramTable.put(newParam.getName(),newParam.getValue());
	}
	}';
	UPDATE SSCRIPT_LIBRARY SET CODE = script WHERE DESCRIPTION = 'MisoDriverParameters' and NAME = 'MisoDriverParameters';

	UPDATE SUSER SET U_PASSWORD = 'gtwp$pci1' WHERE U_NAME IN ('Admin','background');
	UPDATE SPARAMETER SET "VALUE" = 'gtwp$pci1' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'BACKGROUND_PASSWORD';

	UPDATE SASSET_OWNER_CONFIG SET ACTIVE = 'N';

	UPDATE SPARAMETER SET VALUE = 'C:\PCI\archive\settlement' WHERE SYSTEM = 'GenManager' and TYPE = '_SYSTEM_' and NAME = 'SETTLEMENT_STATEMENT_ARCHIVE_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\MISO\archiveXMLInvoice' WHERE SYSTEM = 'GenManager' and TYPE = '_SYSTEM_' and NAME = 'SETTLEMENT_INVOICE_ARCHIVE_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\MISO\invoicePDFDisplay' WHERE SYSTEM = 'GenManager' and TYPE = '_SYSTEM_' and NAME = 'SETTLEMENT_INVOICE_DISPLAY_DIR';
	UPDATE SPARAMETER SET VALUE = 'C:\MISO\archivePDFInvoice' WHERE SYSTEM = 'GenManager' and TYPE = '_SYSTEM_' and NAME = 'SETTLEMENT_INVOICE_PDF_DOWNLOAD_DIR';
	UPDATE SPARAMETER SET VALUE = 'C:\MISO\disputes' WHERE SYSTEM = 'GenManager' and TYPE = '_SYSTEM_' and NAME = 'DISPUTE_UPLOAD_DIRECTORY';

	UPDATE SPARAMETER SET VALUE = 'C:\MISO\crow\archive' WHERE SYSTEM = 'GenManager' and TYPE = 'MISO' and NAME = 'CROW_ARCHIVE_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'C:\MISO\crow\download' WHERE SYSTEM = 'GenManager' and TYPE = 'MISO' and NAME = 'CROW_DOWNLOAD_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'S' WHERE SYSTEM = 'GenManager' and TYPE = 'MISO' and NAME = 'CROW_MODE';
	UPDATE SPARAMETER SET VALUE = 'C:\PCI\settlement' WHERE SYSTEM = 'GenManager' and TYPE = 'MISO' and NAME = 'STATEMENT_LOAD_DIRECTORY';
	UPDATE SPARAMETER SET VALUE = 'ALL' WHERE SYSTEM = 'GenManager' and TYPE = 'MISO' and NAME = 'MANUAL_LOAD_SETTLEMENT_TYPE';

	UPDATE SPARAMETER SET VALUE = 'T' WHERE SYSTEM = 'ISOCOMM' and TYPE = '_MISO_' and NAME = 'MISO_DART2_HOST_TARGET';
	UPDATE SPARAMETER SET VALUE = 'P' WHERE SYSTEM = 'ISOCOMM' and TYPE = '_MISO_' and NAME = 'MISO_DART2_HOST_TARGET_DOWNLOADS';
	UPDATE SPARAMETER SET VALUE = 'false' WHERE SYSTEM = 'ISOCOMM' and TYPE = '_MISO_' and NAME = 'MISO_USE_PROXY';
	UPDATE SPARAMETER SET VALUE = 'false' WHERE SYSTEM = 'ISOCOMM' and TYPE = '_MISO_' and NAME = 'MISO_USE_PROXY_UPLOAD';
	UPDATE SPARAMETER SET VALUE = 'apim.misoenergy.org' WHERE SYSTEM = 'ISOCOMM' and TYPE = '_MISO_' and NAME = 'DATA_EXCHANGE_HOST';
	UPDATE SPARAMETER SET VALUE = '903dc31d4a60476282f87fa979c3dc7e' WHERE SYSTEM = 'ISOCOMM' and TYPE = '_MISO_' and NAME = 'DATA_EXCHANGE_PRICING_API_KEY';

	UPDATE SPARAMETER SET VALUE = 'PCI Cloud Environment' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'ENVIRONMENT';
	UPDATE SPARAMETER SET VALUE = '<a href="../../common/portal.jsp"><img id="logo-img" src="/images/logo-white-on-clear-bg.svg"/></a>' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'PORTAL_LOGO';
	UPDATE SPARAMETER SET VALUE = '<a href="../../common/portal.jsp"><img id="logo-img" src="/images/logo-white-on-clear-bg.svg"/></a>' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'PORTAL_LOGO_DARK';
	
	UPDATE SPARAMETER SET VALUE = 'gsms' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'GP_CONNECT';
	UPDATE SPARAMETER SET VALUE = 'pci' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'GP_PASSWORD';
	UPDATE SPARAMETER SET VALUE = 'pci' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'GP_USER';
	UPDATE SPARAMETER SET VALUE = 'false' WHERE SYSTEM = 'GenPortal' and TYPE = '_SYSTEM_' and NAME = 'FILE_ARCHIVER_ENABLED';
	
	UPDATE SPARAMETER SET VALUE = 'true' WHERE SYSTEM = 'GenManager' and TYPE = 'ISO' and NAME = 'STORE_BID_RESULT_DATA';
	UPDATE SPARAMETER SET VALUE = 'C:\ISO\STORE_BID_RESULT_DATA' WHERE SYSTEM = 'GenManager' and TYPE = 'ISO' and NAME = 'STORE_BID_RESULT_DATA_DIR';
	UPDATE SPARAMETER SET VALUE = 'true' WHERE SYSTEM = 'GenManager' and TYPE = 'ISO' and NAME = 'STORE_BID_SUBMIT_DATA';
	UPDATE SPARAMETER SET VALUE = 'C:\ISO\STORE_BID_SUBMIT_DATA' WHERE SYSTEM = 'GenManager' and TYPE = 'ISO' and NAME = 'STORE_BID_SUBMIT_DATA_DIR';
	UPDATE SPARAMETER SET VALUE = 'true' WHERE SYSTEM = 'GenManager' and TYPE = 'ISO' and NAME = 'STORE_CB_BID_DATA';

	DELETE FROM SPARAMETER WHERE NAME = 'AUTO_QUERY_BID_RESULTS_RT';
	BEGIN
		SELECT VALUE INTO tmp1 FROM sparameter WHERE NAME='STORE_BID_RESULT_DATA';
	EXCEPTION
		WHEN no_data_found THEN
		INSERT INTO SPARAMETER (PARAMETER_KEY, NAME, VALUE, DESCRIPTION, SYSTEM, TYPE, MODIFIEDON, MODIFIEDBY, CREATEDON, CREATEDBY) VALUES ((SELECT MAX(PARAMETER_KEY)+1 FROM SPARAMETER), 'STORE_BID_RESULT_DATA', 'true', '','GenManager', 'ISO', SYSDATE, 'background', SYSDATE, 'background');
	END;
	BEGIN
		SELECT VALUE INTO tmp2 FROM sparameter WHERE NAME='STORE_BID_RESULT_DATA_DIR';
	EXCEPTION
		WHEN no_data_found THEN
		INSERT INTO SPARAMETER (PARAMETER_KEY, NAME, VALUE, DESCRIPTION, SYSTEM, TYPE, MODIFIEDON, MODIFIEDBY, CREATEDON, CREATEDBY) VALUES ((SELECT MAX(PARAMETER_KEY)+1 FROM SPARAMETER), 'STORE_BID_RESULT_DATA_DIR', 'C:\ISO\STORE_BID_RESULT_DATA', '','GenManager', 'ISO', SYSDATE, 'background', SYSDATE, 'background');
	END;
	UPDATE SSYS_ID SET NEXT_KEY = (SELECT MAX(PARAMETER_KEY) FROM SPARAMETER) WHERE ID_TYPE = 'PARAMETER';
	COMMIT;
END;