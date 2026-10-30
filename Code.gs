const SHEET_ID = '1evv8hbTsu9Z988YmgqXmLG5LDMxP7pUhIJFiZoLQ_6U';
const SYNC_KEY = 'CAMBIA-QUESTA-CHIAVE';
const MONITOR_SHEET = 'PC Monitor';
const REBOOT_SHEET = 'Reboot Sessions';
const MONITOR_KEY_PROPERTY = 'MONITOR_AGENT_KEY';
const DASHBOARD_KEY_PROPERTY = 'MONITOR_DASHBOARD_KEY';
const ONLINE_AFTER_SEC = 90;

function doGet(e) {
  const p = (e && e.parameter) || {};
  if (String(p.api || '') === 'dashboard') {
    if (!isDashboardAuthorized_(p)) return json_({ok:false,error:'unauthorized_dashboard'});
    return getDashboardData_(SpreadsheetApp.openById(SHEET_ID));
  }
  return json_({ok:true});
}

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents || '{}');
    if (body.type === 'heartbeat') {
      if (!isMonitorAuthorized_(body)) return json_({ok:false,error:'unauthorized_agent'});
      return handleHeartbeat_(SpreadsheetApp.openById(SHEET_ID), body);
    }
    if (body.key !== SYNC_KEY) return json_({ok:false,error:'unauthorized'});
    if (body.type === 'ping') return json_({ok:true,pong:true});
    const ss = SpreadsheetApp.openById(SHEET_ID);
    const sessions = ss.getSheetByName('PC Sessions');
    const taskLog = ss.getSheetByName('Task Log');
    const s = body.session || {};
    const sessionId = String(s.sessionId || '').trim();
    if (!sessionId) return json_({ok:false,error:'missing_session_id'});
    if (!sessionExists_(sessions, sessionId)) sessions.appendRow([s.sessionId||'',s.pc||'',s.date||'',s.start||'',s.end||'',Number(s.durationMin||0),Number(s.completed||0),Number(s.total||0),Number(s.completion||0),s.outcome||'',s.reason||'',s.operator||'',s.notes||'',s.anydeskId||'',s.autoAccess||'']);
    const existing = existingTaskKeys_(taskLog, sessionId);
    (body.tasks || []).forEach(t => { const key=[t.sessionId||'',t.phase||'',String(t.order||''),t.task||''].join('|'); if(!existing.has(key)){taskLog.appendRow([t.sessionId||'',t.pc||'',t.phase||'',Number(t.order||0),t.task||'',t.status||'',t.completedAt||'',t.elapsed||'',t.command||'',t.note||'']);existing.add(key);}});
    return json_({ok:true,sessionId});
  } catch (err) { return json_({ok:false,error:String(err)}); }
}

function isMonitorAuthorized_(body) { const expected=PropertiesService.getScriptProperties().getProperty(MONITOR_KEY_PROPERTY); return !!expected && String(body.agentKey||'')===expected; }
function isDashboardAuthorized_(p) { const expected=PropertiesService.getScriptProperties().getProperty(DASHBOARD_KEY_PROPERTY); return !!expected && String(p.key||'')===expected; }

function getDashboardData_(ss) {
  const monitor=getOrCreateMonitorSheet_(ss), reboot=getOrCreateRebootSheet_(ss), now=new Date();
  const lastReboots={};
  if(reboot.getLastRow()>=2){
    reboot.getRange(2,1,reboot.getLastRow()-1,14).getValues().forEach(r=>{
      const id=String(r[1]||''); if(!id) return;
      const when=r[5] instanceof Date?r[5]:(r[3] instanceof Date?r[3]:null);
      if(!lastReboots[id] || (when && (!lastReboots[id]._when || when>lastReboots[id]._when))) lastReboots[id]={_when:when,sessionId:String(r[0]||''),durationMin:r[7]===''?null:Number(r[7]),outcome:String(r[9]||''),updateStatus:String(r[10]||''),updateTitle:String(r[11]||'')};
    });
  }
  const pcs=[];
  if(monitor.getLastRow()>=2) monitor.getRange(2,1,monitor.getLastRow()-1,26).getValues().forEach(r=>{
    const contact=r[4] instanceof Date?r[4]:null, age=contact?Math.max(0,Math.round((now-contact)/1000)):null;
    const rawStatus=String(r[3]||''), connectivity=age!==null&&age<=ONLINE_AFTER_SEC?'ONLINE':'OFFLINE';
    const lr=lastReboots[String(r[0]||'')]||{};
    const preCheckStatus=String(r[14]||'');
    pcs.push({agentId:String(r[0]||''),pc:String(r[1]||''),connectivity,agentStatus:rawStatus,lastContactUtc:contact?contact.toISOString():null,lastContactAgeSec:age,rebootPending:rawStatus==='REBOOT_PENDING',windows:String(r[7]||''),build:String(r[8]||''),updateStatus:String(r[9]||''),updateTitle:String(r[10]||''),preCheck:{scannedAtUtc:String(r[13]||'')||null,status:preCheckStatus||null,blockers:parseJsonArray_(r[15]),warnings:parseJsonArray_(r[16]),manufacturer:String(r[17]||''),model:String(r[18]||''),cpu:String(r[19]||''),ramGB:numberOrNull_(r[20]),firmware:String(r[21]||''),partitionStyle:String(r[22]||''),tpmVersion:String(r[23]||''),secureBoot:String(r[24]||''),systemDriveFreeGB:numberOrNull_(r[25])},lastReboot:{sessionId:lr.sessionId||null,durationMin:lr.durationMin===undefined?null:lr.durationMin,outcome:lr.outcome||null,updateStatus:lr.updateStatus||null,updateTitle:lr.updateTitle||null}});
  });
  pcs.sort((a,b)=>a.pc.localeCompare(b.pc));
  return json_({ok:true,generatedAtUtc:now.toISOString(),onlineThresholdSec:ONLINE_AFTER_SEC,summary:{total:pcs.length,online:pcs.filter(x=>x.connectivity==='ONLINE').length,offline:pcs.filter(x=>x.connectivity==='OFFLINE').length,rebootPending:pcs.filter(x=>x.rebootPending).length,updateFailed:pcs.filter(x=>x.updateStatus==='UPDATE_FAILED').length,preCheckBlocked:pcs.filter(x=>x.preCheck.status==='BLOCCATO').length,preCheckWarning:pcs.filter(x=>x.preCheck.status==='ATTENZIONE').length},pcs});
}

function handleHeartbeat_(ss, body) {
  const agentId=String(body.agentId||'').trim(); if(!agentId)return json_({ok:false,error:'missing_agent_id'});
  const sheet=getOrCreateMonitorSheet_(ss), rebootSheet=getOrCreateRebootSheet_(ss), now=new Date(), row=findAgentRow_(sheet,agentId);
  let previousContact=null,previousStatus=''; if(row){previousStatus=String(sheet.getRange(row,4).getDisplayValue()||'');const raw=sheet.getRange(row,5).getValue();if(raw instanceof Date&&!isNaN(raw.getTime()))previousContact=raw;}
  const status=String(body.status||'ONLINE'),updateStatus=String(body.updateStatus||''),updateTitle=String(body.updateTitle||''),updateResultCode=String(body.updateResultCode||''),updateDateUtc=String(body.updateDateUtc||'');
  if(status==='REBOOT_PENDING')ensureOpenRebootSession_(rebootSheet,agentId,String(body.hostName||''),now);
  if(status==='ONLINE_AFTER_REBOOT')closeRebootSession_(rebootSheet,agentId,String(body.hostName||''),now,previousContact,String(body.bootTimeUtc||''),updateStatus,updateTitle,updateResultCode,updateDateUtc);
  const oldPre=row?sheet.getRange(row,14,1,13).getValues()[0]:new Array(13).fill('');
  const pre=body.preCheck&&typeof body.preCheck==='object'?preCheckValues_(body.preCheck):oldPre;
  const values=[[agentId,String(body.hostName||''),String(body.agentVersion||''),status,now,String(body.timestampUtc||''),String(body.bootTimeUtc||''),String(body.windows||''),String(body.build||''),updateStatus,updateTitle,updateResultCode,updateDateUtc].concat(pre)];
  if(row)sheet.getRange(row,1,1,values[0].length).setValues(values);else sheet.getRange(sheet.getLastRow()+1,1,1,values[0].length).setValues(values);
  return json_({ok:true,agentId,serverTimeUtc:now.toISOString(),previousStatus,preCheckStored:!!body.preCheck});
}

function preCheckValues_(p){return [String(p.scannedAtUtc||''),String(p.status||''),JSON.stringify(Array.isArray(p.blockers)?p.blockers:[]),JSON.stringify(Array.isArray(p.warnings)?p.warnings:[]),String(p.manufacturer||''),String(p.model||''),String(p.cpu||''),p.ramGB===null||p.ramGB===undefined?'':Number(p.ramGB),String(p.firmware||''),String(p.partitionStyle||''),String(p.tpmVersion||''),String(p.secureBoot||''),p.systemDriveFreeGB===null||p.systemDriveFreeGB===undefined?'':Number(p.systemDriveFreeGB)];}
function parseJsonArray_(v){try{const a=JSON.parse(String(v||'[]'));return Array.isArray(a)?a:[];}catch(e){return [];}}
function numberOrNull_(v){return v===''||v===null||v===undefined?null:Number(v);}
function getOrCreateMonitorSheet_(ss){const h=['Agent ID','PC','Agent Version','Stato','Ultimo contatto server','Timestamp Agent UTC','Boot UTC','Windows','Build','Update Status','Update Title','Update Result Code','Update Date UTC','PreCheck UTC','PreCheck Status','PreCheck Blockers','PreCheck Warnings','Manufacturer','Model','CPU','RAM GB','Firmware','Partition Style','TPM Version','Secure Boot','Free C GB'];let s=ss.getSheetByName(MONITOR_SHEET);if(!s){s=ss.insertSheet(MONITOR_SHEET);s.appendRow(h);s.setFrozenRows(1);}else ensureHeaders_(s,h);return s;}
function getOrCreateRebootSheet_(ss){const h=['Session ID','Agent ID','PC','Riavvio richiesto','Ultimo contatto prima del rientro','Rientro online','Indisponibilità osservata sec','Indisponibilità min','Boot UTC dopo riavvio','Esito','Update Status','Update Title','Update Result Code','Update Date UTC'];let s=ss.getSheetByName(REBOOT_SHEET);if(!s){s=ss.insertSheet(REBOOT_SHEET);s.appendRow(h);s.setFrozenRows(1);}else ensureHeaders_(s,h);return s;}
function ensureHeaders_(s,h){if(s.getMaxColumns()<h.length)s.insertColumnsAfter(s.getMaxColumns(),h.length-s.getMaxColumns());s.getRange(1,1,1,h.length).setValues([h]);s.setFrozenRows(1);}
function ensureOpenRebootSession_(s,id,pc,now){if(findOpenRebootRow_(s,id))return; s.appendRow(['RB-'+Utilities.getUuid().substring(0,8).toUpperCase(),id,pc,now,'','','','','','IN_ATTESA_RIENTRO','','','','']);}
function closeRebootSession_(s,id,pc,returnedAt,previousContact,boot,us,ut,ur,ud){let row=findOpenRebootRow_(s,id);if(!row){s.appendRow(['RB-'+Utilities.getUuid().substring(0,8).toUpperCase(),id,pc,'',previousContact||'',returnedAt,'','',boot,'RIAVVIO_RILEVATO',us,ut,ur,ud]);row=s.getLastRow();}let sec='',min='';if(previousContact instanceof Date&&!isNaN(previousContact.getTime())){sec=Math.max(0,Math.round((returnedAt-previousContact)/1000));min=Math.round(sec/6)/10;}let outcome=sec===''?'RIENTRATO_DURATA_NON_CALCOLABILE':'RIENTRATO';if(us)outcome+='_'+us;s.getRange(row,5,1,10).setValues([[previousContact||'',returnedAt,sec,min,boot,outcome,us,ut,ur,ud]]);}
function findOpenRebootRow_(s,id){const last=s.getLastRow();if(last<2)return 0;const v=s.getRange(2,1,last-1,10).getValues();for(let i=v.length-1;i>=0;i--)if(String(v[i][1])===id&&String(v[i][9])==='IN_ATTESA_RIENTRO')return i+2;return 0;}
function findAgentRow_(s,id){const last=s.getLastRow();if(last<2)return 0;const ids=s.getRange(2,1,last-1,1).getDisplayValues().flat(),i=ids.indexOf(id);return i<0?0:i+2;}
function sessionExists_(s,id){const last=s.getLastRow();if(last<2)return false;return s.getRange(2,1,last-1,1).getDisplayValues().flat().includes(id);}
function existingTaskKeys_(s,id){const set=new Set(),last=s.getLastRow();if(last<2)return set;s.getRange(2,1,last-1,5).getDisplayValues().forEach(r=>{if(r[0]===id)set.add([r[0],r[2],r[3],r[4]].join('|'));});return set;}
function json_(obj){return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);}
