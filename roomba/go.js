'use strict';
// One command to start a full-home clean, cloud-independent, via dorita980 Local.
// Resolves the robot's current IP by discovery, reuses saved roomba-creds.json if
// present, otherwise fetches+saves the password (needs the HOME-button press
// described in getpass.js), then connects locally and sends a full-home start.
const fs = require('fs');
const dorita980 = require('dorita980');
const { robot, resolveHost, grabPassword } = require('./lib');
const CREDS = __dirname + '/roomba-creds.json';

function startClean(blid, password, host) {
  return new Promise((resolve, reject) => {
    const r = new dorita980.Local(blid, password, host);
    const giveUp = setTimeout(() => { try { r.end(); } catch (e) {} reject(new Error('no local connect within 25s')); }, 25000);
    let badAuth = 0;
    r.on('error', (e) => {
      console.error('[robot] error:', e.message);
      if (/username or password/i.test(e.message) && ++badAuth >= 2) { clearTimeout(giveUp); try { r.end(); } catch (x) {} reject(new Error('BAD_CREDS (delete roomba-creds.json and re-run with a HOME-button press)')); }
    });
    r.on('connect', () => {
      console.log('[robot] connected locally; sending start (full clean)...');
      r.start()
        .then(() => { console.log('RESULT:STARTED'); clearTimeout(giveUp); setTimeout(() => { r.end(); resolve(); }, 3000); })
        .catch((e) => { clearTimeout(giveUp); try { r.end(); } catch (x) {} reject(e); });
    });
  });
}

(async () => {
  let host;
  try { host = await resolveHost(); } catch (e) { console.error('RESULT:NO_ROBOT', e.message); process.exit(2); }

  let password = null;
  if (fs.existsSync(CREDS)) {
    try { password = JSON.parse(fs.readFileSync(CREDS)).password; console.log('[creds] using saved password'); } catch (e) {}
  }
  if (!password) {
    try {
      password = await grabPassword(host);
      fs.writeFileSync(CREDS, JSON.stringify({ blid: robot.blid, password, host }, null, 2));
      console.log('[creds] password retrieved and saved to roomba-creds.json');
    } catch (e) {
      if (e.message === 'NEEDS_BUTTON') { console.error('RESULT:NEEDS_BUTTON — press & hold HOME ~2s until tones, then rerun within 2 min.'); process.exit(10); }
      console.error('RESULT:GETPASS_ERROR', e.message); process.exit(11);
    }
  }
  try { await startClean(robot.blid, password, host); process.exit(0); }
  catch (e) { console.error('RESULT:START_ERROR', e.message); process.exit(12); }
})();
