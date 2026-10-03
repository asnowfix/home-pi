'use strict';
// Start a full-home clean using already-saved roomba-creds.json (no button press).
// Use this for every clean AFTER the first-time getpass. Could be cron'd.
const fs = require('fs');
const dorita980 = require('dorita980');
const robot = require('./robot.json');
const CREDS = __dirname + '/roomba-creds.json';
if (!fs.existsSync(CREDS)) { console.error('No roomba-creds.json — run `node go.js` once (needs HOME-button press).'); process.exit(2); }
const { password } = JSON.parse(fs.readFileSync(CREDS));
const r = new dorita980.Local(robot.blid, password, robot.host);
const giveUp = setTimeout(() => { try { r.end(); } catch (e) {} console.error('no local connect within 25s'); process.exit(3); }, 25000);
r.on('error', (e) => console.error('[robot] error:', e.message));
r.on('connect', () => {
  r.start()
    .then(() => { console.log('RESULT:STARTED'); clearTimeout(giveUp); setTimeout(() => { r.end(); process.exit(0); }, 3000); })
    .catch((e) => { clearTimeout(giveUp); console.error('START_ERROR', e.message); try { r.end(); } catch (x) {} process.exit(1); });
});
