xquery version '1.0-ml';
import module namespace trgr='http://marklogic.com/xdmp/triggers' at '/MarkLogic/triggers.xqy';

declare variable $trgr:uri as xs:string external;
declare variable $trgr:trigger as node() external;

declare variable $TRACE-ID := "hackaton-trigger";

xdmp:trace($TRACE-ID, fn:concat('ADD-TDE-EXTRACTION-COLLECTION ', $trgr:uri)),
xdmp:trace($TRACE-ID, fn:concat('ADD-TDE-EXTRACTION-COLLECTION ', xdmp:quote($trgr:trigger)))(:),
xdmp:document-add-collections($trgr:uri, "/opera/options/ow-tde-extraction"):)

