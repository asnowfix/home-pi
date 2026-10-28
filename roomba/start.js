'use strict';
// Start a full-home clean using already-saved roomba-creds.json (no button press).
// Resolves the robot's current IP by discovery (DHCP is dynamic), so it keeps
// working after the robot's lease changes. Use this for every clean AFTER the
// first-time getpass. Cron-friendly.
const fs = require('fs');
const dorita980 = require('dorita980');
const { robot, resolveHost } = require('./lib');
const CREDS = __dirname + '/roomba-creds.json';

if (!fs.existsSync(CREDS)) { console.error('No roomba-creds.json — run `node go.js` once (needs HOME-button press).'); process.exit(2); }
const { password } = JSON.parse(fs.readFileSync(CREDS));

(async () => {
  let host;
  try { host = await resolveHost(); } catch (e) { console.error('NO_ROBOT', e.message); process.exit(2); }
  const r = new dorita980.Local(robot.blid, password, host);
  const giveUp = setTimeout(() => { try { r.end(); } catch (e) {} console.error('no local connect within 25s'); process.exit(3); }, 25000);
  let badAuth = 0;
  r.on('error', (e) => {
    console.error('[robot] error:', e.message);
    if (/username or password/i.test(e.message) && ++badAuth >= 2) { clearTimeout(giveUp); try { r.end(); } catch (x) {} console.error('BAD_CREDS (delete roomba-creds.json and re-run `node go.js` with a HOME-button press)'); process.exit(1); }
  });
  r.on('connect', () => {
    r.start()
      .then(() => { console.log('RESULT:STARTED'); clearTimeout(giveUp); setTimeout(() => { r.end(); process.exit(0); }, 3000); })
      .catch((e) => { clearTimeout(giveUp); console.error('START_ERROR', e.message); try { r.end(); } catch (x) {} process.exit(1); });
  });
})();
