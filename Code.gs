const SHEET_ID = '1evv8hbTsu9Z988YmgqXmLG5LDMxP7pUhIJFiZoLQ_6U';
const SYNC_KEY = 'CAMBIA-QUESTA-CHIAVE';
const MONITOR_SHEET = 'PC Monitor';
const MONITOR_KEY_PROPERTY = 'MONITOR_AGENT_KEY';

function doGet() {
  return ContentService.createTextOutput(JSON.stringify({ok:true})).setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents || '{}');

    // Heartbeats use a dedicated Agent credential stored in Apps Script
    // Properties, not the PWA synchronization key and not the source code.
    if (body.type === 'heartbeat') {
      if (!isMonitorAuthorized_(body)) return json_({ok:false,error:'unauthorized_agent'});
      const ss = SpreadsheetApp.openById(SHEET_ID);
      return handleHeartbeat_(ss, body);
    }

    // Existing PWA/checklist traffic keeps its current authentication.
    if (body.key !== SYNC_KEY) return json_({ok:false,error:'unauthorized'});
    if (body.type === 'ping') return json_({ok:true,pong:true});

    const ss = SpreadsheetApp.openById(SHEET_ID);
    const sessions = ss.getSheetByName('PC Sessions');
    const taskLog = ss.getSheetByName('Task Log');
    const s = body.session || {};
    const sessionId = String(s.sessionId || '').trim();
    if (!sessionId) return json_({ok:false,error:'missing_session_id'});

    if (!sessionExists_(sessions, sessionId)) {
      sessions.appendRow([
        s.sessionId||'',s.pc||'',s.date||'',s.start||'',s.end||'',
        Number(s.durationMin||0),Number(s.completed||0),Number(s.total||0),
        Number(s.completion||0),s.outcome||'',s.reason||'',s.operator||'',
        s.notes||'',s.anydeskId||'',s.autoAccess||''
      ]);
    }

    const existing = existingTaskKeys_(taskLog, sessionId);
    (body.tasks || []).forEach(t => {
      const key = [t.sessionId||'',t.phase||'',String(t.order||''),t.task||''].join('|');
      if (!existing.has(key)) {
        taskLog.appendRow([
          t.sessionId||'',t.pc||'',t.phase||'',Number(t.order||0),t.task||'',
          t.status||'',t.completedAt||'',t.elapsed||'',t.command||'',t.note||''
        ]);
        existing.add(key);
      }
    });

    return json_({ok:true,sessionId});
  } catch (err) {
    return json_({ok:false,error:String(err)});
  }
}

function isMonitorAuthorized_(body) {
  const expected = PropertiesService.getScriptProperties().getProperty(MONITOR_KEY_PROPERTY);
  if (!expected) return false; // fail closed until configured
  const supplied = String(body.agentKey || '');
  return supplied.length > 0 && supplied === expected;
}

function handleHeartbeat_(ss, body) {
  const agentId = String(body.agentId || '').trim();
  if (!agentId) return json_({ok:false,error:'missing_agent_id'});

  const sheet = getOrCreateMonitorSheet_(ss);
  const now = new Date();
  const row = findAgentRow_(sheet, agentId);
  const values = [[
    agentId,
    String(body.hostName || ''),
    String(body.agentVersion || ''),
    String(body.status || 'ONLINE'),
    now,
    String(body.timestampUtc || ''),
    String(body.bootTimeUtc || ''),
    String(body.windows || ''),
    String(body.build || '')
  ]];

  if (row) sheet.getRange(row, 1, 1, values[0].length).setValues(values);
  else sheet.getRange(sheet.getLastRow() + 1, 1, 1, values[0].length).setValues(values);

  return json_({ok:true,agentId:agentId,serverTimeUtc:now.toISOString()});
}

function getOrCreateMonitorSheet_(ss) {
  let sheet = ss.getSheetByName(MONITOR_SHEET);
  if (!sheet) {
    sheet = ss.insertSheet(MONITOR_SHEET);
    sheet.appendRow([
      'Agent ID','PC','Agent Version','Stato','Ultimo contatto server',
      'Timestamp Agent UTC','Boot UTC','Windows','Build'
    ]);
    sheet.setFrozenRows(1);
  }
  return sheet;
}

function findAgentRow_(sheet, agentId) {
  const last = sheet.getLastRow();
  if (last < 2) return 0;
  const ids = sheet.getRange(2,1,last-1,1).getDisplayValues().flat();
  const index = ids.indexOf(agentId);
  return index < 0 ? 0 : index + 2;
}

function sessionExists_(sheet, sessionId) {
  const last = sheet.getLastRow();
  if (last < 2) return false;
  const vals = sheet.getRange(2,1,last-1,1).getDisplayValues().flat();
  return vals.includes(sessionId);
}

function existingTaskKeys_(sheet, sessionId) {
  const set = new Set();
  const last = sheet.getLastRow();
  if (last < 2) return set;
  sheet.getRange(2,1,last-1,5).getDisplayValues().forEach(r=>{
    if (r[0] === sessionId) set.add([r[0],r[2],r[3],r[4]].join('|'));
  });
  return set;
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
