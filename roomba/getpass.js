'use strict';
// Fetch the Roomba's LOCAL password using dorita980's v2 magic-packet method.
// REQUIRES a physical step first: with the robot docked + powered on, press and
// hold HOME (house icon) ~2s until it plays tones; release; Wi-Fi light flashes.
// Then run this within ~2 minutes. On success the password is saved to
// roomba-creds.json (gitignored). Harmless to run anytime; without the button
// press the robot returns a 7-byte "not now" reply and this reports NEEDS_BUTTON.
const fs = require('fs');
const tls = require('tls');
const { constants } = require('crypto');
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

getPassword(robot.host)
  .then((password) => {
    fs.writeFileSync(CREDS, JSON.stringify({ blid: robot.blid, password, host: robot.host }, null, 2));
    console.log('OK: password retrieved and saved to roomba-creds.json');
    process.exit(0);
  })
  .catch((e) => {
    if (e.message === 'NEEDS_BUTTON') {
      console.error('NEEDS_BUTTON: press & hold HOME ~2s until tones, then rerun within 2 min.');
      process.exit(10);
    }
    console.error('ERROR', e.message); process.exit(1);
  });
