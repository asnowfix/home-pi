'use strict';
// One command to start a full-home clean, cloud-independent, via dorita980 Local.
// Uses saved roomba-creds.json if present; otherwise fetches the password via the
// magic packet (needs the HOME-button press described in getpass.js) and saves it.
const fs = require('fs');
const tls = require('tls');
const { constants } = require('crypto');
const dorita980 = require('dorita980');
const robot = require('./robot.json');
const CREDS = __dirname + '/roomba-creds.json';

function getPassword(host) {
  return new Promise((resolve, reject) => {
    const packet = Buffer.from('f005efcc3b2900', 'hex');
    let sliceFrom = 13;
    const opts = {
      timeout: 10000, rejectUnauthorized: false,
      ciphers: 'AES128-SHA256,TLS_AES_256_GCM_SHA384', minVersion: 'TLSv1',
      secureOptions: (constants && constants.SSL_OP_LEGACY_SERVER_CONNECT) || 0
    };
    const to = setTimeout(() => reject(new Error('timeout')), 12000);
    const c = tls.connect(8883, host, opts, () => c.write(packet));
    c.setEncoding('utf-8');
    c.on('data', (d) => {
      if (d.length === 2) { sliceFrom = 9; return; }
      clearTimeout(to);
      if (d.length <= 7) { c.end(); return reject(new Error('NEEDS_BUTTON')); }
      c.end(); resolve(Buffer.from(d).slice(sliceFrom).toString());
    });
    c.on('error', (e) => { clearTimeout(to); reject(e); });
  });
}

function startClean(blid, password, host) {
  return new Promise((resolve, reject) => {
    const r = new dorita980.Local(blid, password, host);
    const giveUp = setTimeout(() => { try { r.end(); } catch (e) {} reject(new Error('no local connect within 25s')); }, 25000);
    r.on('error', (e) => console.error('[robot] error:', e.message));
    r.on('connect', () => {
      console.log('[robot] connected locally; sending start (full clean)...');
      r.start()
        .then(() => { console.log('RESULT:STARTED'); clearTimeout(giveUp); setTimeout(() => { r.end(); resolve(); }, 3000); })
        .catch((e) => { clearTimeout(giveUp); try { r.end(); } catch (x) {} reject(e); });
    });
  });
}

(async () => {
  let password = null;
  if (fs.existsSync(CREDS)) {
    try { password = JSON.parse(fs.readFileSync(CREDS)).password; console.log('[creds] using saved password'); } catch (e) {}
  }
  if (!password) {
    try {
      password = await getPassword(robot.host);
      fs.writeFileSync(CREDS, JSON.stringify({ blid: robot.blid, password, host: robot.host }, null, 2));
      console.log('[creds] password retrieved and saved to roomba-creds.json');
    } catch (e) {
      if (e.message === 'NEEDS_BUTTON') { console.error('RESULT:NEEDS_BUTTON — press & hold HOME ~2s until tones, then rerun within 2 min.'); process.exit(10); }
      console.error('RESULT:GETPASS_ERROR', e.message); process.exit(11);
    }
  }
  try { await startClean(robot.blid, password, robot.host); process.exit(0); }
  catch (e) { console.error('RESULT:START_ERROR', e.message); process.exit(12); }
})();
