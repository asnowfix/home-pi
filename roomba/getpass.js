'use strict';
// Fetch the Roomba's LOCAL password (dorita980 v2 magic-packet method), parsing
// the password as the longest printable-ASCII run from the raw response.
// REQUIRES a physical step first: with the robot docked + powered on, press and
// hold HOME (house icon) ~2s until it plays tones; release; Wi-Fi light flashes.
// Then run this within ~2 minutes. On success the password is saved to
// roomba-creds.json (gitignored). Without the button press the robot returns a
// 7-byte "not now" reply and this reports NEEDS_BUTTON.
const fs = require('fs');
const { robot, resolveHost, grabPassword } = require('./lib');
const CREDS = __dirname + '/roomba-creds.json';

(async () => {
  let host;
  try { host = await resolveHost(); }
  catch (e) { console.error('ERROR could not locate robot:', e.message); process.exit(2); }
  try {
    const password = await grabPassword(host);
    fs.writeFileSync(CREDS, JSON.stringify({ blid: robot.blid, password, host }, null, 2));
    console.log('OK: password retrieved and saved to roomba-creds.json (host ' + host + ')');
    process.exit(0);
  } catch (e) {
    if (e.message === 'NEEDS_BUTTON') {
      console.error('NEEDS_BUTTON: press & hold HOME ~2s until tones, then rerun within 2 min.');
      process.exit(10);
    }
    console.error('ERROR', e.message); process.exit(1);
  }
})();
