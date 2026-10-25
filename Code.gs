const SHEET_ID = '1evv8hbTsu9Z988YmgqXmLG5LDMxP7pUhIJFiZoLQ_6U';
const SYNC_KEY = 'CAMBIA-QUESTA-CHIAVE';
const MONITOR_SHEET = 'PC Monitor';
const REBOOT_SHEET = 'Reboot Sessions';
const MONITOR_KEY_PROPERTY = 'MONITOR_AGENT_KEY';

function doGet() {
  return ContentService.createTextOutput(JSON.stringify({ok:true})).setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents || '{}');

    if (body.type === 'heartbeat') {
      if (!isMonitorAuthorized_(body)) return json_({ok:false,error:'unauthorized_agent'});
      const ss = SpreadsheetApp.openById(SHEET_ID);
      return handleHeartbeat_(ss, body);
    }

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
  if (!expected) return false;
  const supplied = String(body.agentKey || '');
  return supplied.length > 0 && supplied === expected;
}

function handleHeartbeat_(ss, body) {
  const agentId = String(body.agentId || '').trim();
  if (!agentId) return json_({ok:false,error:'missing_agent_id'});

  const sheet = getOrCreateMonitorSheet_(ss);
  const rebootSheet = getOrCreateRebootSheet_(ss);
  const now = new Date();
  const row = findAgentRow_(sheet, agentId);

  let previousContact = null;
  let previousStatus = '';
  if (row) {
    previousStatus = String(sheet.getRange(row,4).getDisplayValue() || '');
    const raw = sheet.getRange(row,5).getValue();
    if (raw instanceof Date && !isNaN(raw.getTime())) previousContact = raw;
  }

  const status = String(body.status || 'ONLINE');
  const updateStatus = String(body.updateStatus || '');
  const updateTitle = String(body.updateTitle || '');
  const updateResultCode = String(body.updateResultCode || '');
  const updateDateUtc = String(body.updateDateUtc || '');

  if (status === 'REBOOT_PENDING') {
    ensureOpenRebootSession_(rebootSheet, agentId, String(body.hostName || ''), now);
  }

  if (status === 'ONLINE_AFTER_REBOOT') {
    closeRebootSession_(
      rebootSheet, agentId, String(body.hostName || ''), now, previousContact,
      String(body.bootTimeUtc || ''), updateStatus, updateTitle, updateResultCode, updateDateUtc
    );
  }

  const values = [[
    agentId,
    String(body.hostName || ''),
    String(body.agentVersion || ''),
    status,
    now,
    String(body.timestampUtc || ''),
    String(body.bootTimeUtc || ''),
    String(body.windows || ''),
    String(body.build || ''),
    updateStatus,
    updateTitle,
    updateResultCode,
    updateDateUtc
  ]];

  if (row) sheet.getRange(row, 1, 1, values[0].length).setValues(values);
  else sheet.getRange(sheet.getLastRow() + 1, 1, 1, values[0].length).setValues(values);

  return json_({ok:true,agentId:agentId,serverTimeUtc:now.toISOString(),previousStatus:previousStatus});
}

function getOrCreateMonitorSheet_(ss) {
  const headers = [
    'Agent ID','PC','Agent Version','Stato','Ultimo contatto server',
    'Timestamp Agent UTC','Boot UTC','Windows','Build','Update Status',
    'Update Title','Update Result Code','Update Date UTC'
  ];
  let sheet = ss.getSheetByName(MONITOR_SHEET);
  if (!sheet) {
    sheet = ss.insertSheet(MONITOR_SHEET);
    sheet.appendRow(headers);
    sheet.setFrozenRows(1);
  } else {
    ensureHeaders_(sheet, headers);
  }
  return sheet;
}

function getOrCreateRebootSheet_(ss) {
  const headers = [
    'Session ID','Agent ID','PC','Riavvio richiesto','Ultimo contatto prima del rientro',
    'Rientro online','Indisponibilità osservata sec','Indisponibilità min','Boot UTC dopo riavvio','Esito',
    'Update Status','Update Title','Update Result Code','Update Date UTC'
  ];
  let sheet = ss.getSheetByName(REBOOT_SHEET);
  if (!sheet) {
    sheet = ss.insertSheet(REBOOT_SHEET);
    sheet.appendRow(headers);
    sheet.setFrozenRows(1);
  } else {
    ensureHeaders_(sheet, headers);
  }
  return sheet;
}

function ensureHeaders_(sheet, headers) {
  if (sheet.getMaxColumns() < headers.length) {
    sheet.insertColumnsAfter(sheet.getMaxColumns(), headers.length - sheet.getMaxColumns());
  }
  sheet.getRange(1,1,1,headers.length).setValues([headers]);
  sheet.setFrozenRows(1);
}

function ensureOpenRebootSession_(sheet, agentId, hostName, now) {
  if (findOpenRebootRow_(sheet, agentId)) return;
  const sessionId = 'RB-' + Utilities.getUuid().substring(0,8).toUpperCase();
  sheet.appendRow([sessionId,agentId,hostName,now,'','','','','','IN_ATTESA_RIENTRO','','','','']);
}

function closeRebootSession_(sheet, agentId, hostName, returnedAt, previousContact, bootTimeUtc, updateStatus, updateTitle, updateResultCode, updateDateUtc) {
  let row = findOpenRebootRow_(sheet, agentId);

  if (!row) {
    const sessionId = 'RB-' + Utilities.getUuid().substring(0,8).toUpperCase();
    sheet.appendRow([sessionId,agentId,hostName,'',previousContact||'',returnedAt,'','',bootTimeUtc,'RIAVVIO_RILEVATO',updateStatus,updateTitle,updateResultCode,updateDateUtc]);
    row = sheet.getLastRow();
  }

  let seconds = '';
  let minutes = '';
  if (previousContact instanceof Date && !isNaN(previousContact.getTime())) {
    seconds = Math.max(0, Math.round((returnedAt.getTime() - previousContact.getTime()) / 1000));
    minutes = Math.round((seconds / 60) * 10) / 10;
  }

  let outcome = seconds === '' ? 'RIENTRATO_DURATA_NON_CALCOLABILE' : 'RIENTRATO';
  if (updateStatus) outcome += '_' + updateStatus;

  sheet.getRange(row,5,1,10).setValues([[
    previousContact || '', returnedAt, seconds, minutes, bootTimeUtc, outcome,
    updateStatus, updateTitle, updateResultCode, updateDateUtc
  ]]);
}

function findOpenRebootRow_(sheet, agentId) {
  const last = sheet.getLastRow();
  if (last < 2) return 0;
  const values = sheet.getRange(2,1,last-1,10).getValues();
  for (let i=values.length-1; i>=0; i--) {
    if (String(values[i][1]) === agentId && String(values[i][9]) === 'IN_ATTESA_RIENTRO') return i + 2;
  }
  return 0;
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
