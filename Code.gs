const SHEET_ID = '1evv8hbTsu9Z988YmgqXmLG5LDMxP7pUhIJFiZoLQ_6U';
const SYNC_KEY = 'CAMBIA-QUESTA-CHIAVE';

function doGet() {
  return ContentService.createTextOutput(JSON.stringify({ok:true})).setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents || '{}');
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
