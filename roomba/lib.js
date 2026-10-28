'use strict';
// Shared helpers for local Roomba control via dorita980.
// - resolveHost(): find the robot's CURRENT IP (DHCP is dynamic). Tries, in order:
//   env ROOMBA_HOST; the LAN router's host table by MAC (fast, no broadcast);
//   UDP broadcast discovery matching our BLID; robot.json host (stale fallback).
// - resolveHostViaRouter(): ask the SFR/Efixo box API (lan.getHostsList, which is
//   unauthenticated) for the IP currently leased to the robot's MAC.
// - getPassword(): send the magic packet and extract the password as the longest
//   printable-ASCII run from the raw response (the dorita980 fixed-offset slice is
//   WRONG for the i7 and yields a bad password).
// - grabPassword(): getPassword wrapped in retries to ride out :8883 flapping while
//   the robot wakes.
const dgram = require('dgram');
const tls = require('tls');
const http = require('http');
const { constants } = require('crypto');
const robot = require('./robot.json');

// LAN router that answers the SFR/Efixo local API (overridable; empty string disables).
const ROUTER = process.env.ROOMBA_ROUTER !== undefined ? process.env.ROOMBA_ROUTER : '192.168.1.1';

const TLS_OPTS = {
  timeout: 10000,
  rejectUnauthorized: false,                 // robot presents a self-signed cert
  ciphers: 'AES128-SHA256,TLS_AES_256_GCM_SHA384',
  minVersion: 'TLSv1',
  secureOptions: (constants && constants.SSL_OP_LEGACY_SERVER_CONNECT) || 0, // legacy renegotiation
};

// Broadcast-discover the robot; resolve its full public-info object (matched on blid).
function discoverRobot(blid, timeoutMs = 6000) {
  return new Promise((resolve, reject) => {
    const s = dgram.createSocket('udp4');
    let done = false;
    const finish = (err, val) => { if (done) return; done = true; try { s.close(); } catch (e) {} err ? reject(err) : resolve(val); };
    const to = setTimeout(() => finish(new Error('discovery timeout: no robot matching blid replied on UDP 5678')), timeoutMs);
    s.on('error', (e) => { clearTimeout(to); finish(e); });
    s.on('message', (msg) => {
      try {
        const p = JSON.parse(msg);
        if (p.hostname && p.ip && (p.hostname.startsWith('Roomba-') || p.hostname.startsWith('iRobot-'))) {
          if (!blid || p.hostname.split('-')[1] === blid) { clearTimeout(to); finish(null, p); }
        }
      } catch (e) { /* ignore non-JSON chatter */ }
    });
    s.bind(() => { s.setBroadcast(true); const m = Buffer.from('irobotmcs'); s.send(m, 0, m.length, 5678, '255.255.255.255'); });
  });
}

// Ask the LAN router's host table (SFR/Efixo API: lan.getHostsList, unauthenticated)
// for the IP currently leased to `mac`. The box always knows the live lease, so this
// is faster and more reliable than UDP broadcast. Rejects if no router, no match, or
// the box doesn't speak this API.
function resolveHostViaRouter(mac, timeoutMs = 3000) {
  return new Promise((resolve, reject) => {
    if (!ROUTER || !mac) return reject(new Error('router resolve disabled (no ROUTER or MAC)'));
    const want = mac.toLowerCase();
    const req = http.get({ host: ROUTER, path: '/api/1.0/?method=lan.getHostsList', timeout: timeoutMs }, (res) => {
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (d) => { body += d; });
      res.on('end', () => {
        // <host ... ip="x.x.x.x" ... mac="aa:bb:.." ... status="online"/> (attribute order varies)
        let best = null;
        for (const m of body.matchAll(/<host\b[^>]*>/g)) {
          const tag = m[0];
          const macM = tag.match(/\bmac="([^"]+)"/i);
          const ipM = tag.match(/\bip="([^"]+)"/i);
          if (!macM || !ipM || macM[1].toLowerCase() !== want) continue;
          const online = /\bstatus="online"/i.test(tag);
          if (online) return resolve(ipM[1]);        // prefer a live lease
          if (!best) best = ipM[1];                   // else remember last-known
        }
        best ? resolve(best) : reject(new Error('MAC ' + mac + ' not in router host list'));
      });
    });
    req.on('timeout', () => { req.destroy(new Error('router API timeout')); });
    req.on('error', reject);
  });
}

// Current IP: ROOMBA_HOST env > router host table by MAC > broadcast by blid > robot.json host.
async function resolveHost() {
  if (process.env.ROOMBA_HOST) return process.env.ROOMBA_HOST;
  try {
    return await resolveHostViaRouter(robot.mac);
  } catch (e) { /* router may be absent/other LAN — fall through to broadcast */ }
  try {
    const info = await discoverRobot(robot.blid);
    return info.ip;
  } catch (e) {
    if (robot.host) { console.error('[warn] ' + e.message + ' — falling back to robot.json host ' + robot.host); return robot.host; }
    throw e;
  }
}

// Fetch the local password via the magic packet. Resolves the password string,
// or rejects with Error('NEEDS_BUTTON') when the robot is not armed.
function getPassword(host, timeoutMs = 9000) {
  return new Promise((resolve, reject) => {
    const packet = Buffer.from('f005efcc3b2900', 'hex');
    const chunks = [];
    let settled = false;
    const done = (err, val) => { if (settled) return; settled = true; err ? reject(err) : resolve(val); };
    const finish = () => {
      const all = Buffer.concat(chunks);
      if (all.length <= 7) return done(new Error('NEEDS_BUTTON'));
      const runs = (all.toString('latin1').match(/[\x20-\x7e]{20,}/g) || []).sort((a, b) => b.length - a.length);
      if (!runs.length) return done(new Error('NO_PRINTABLE_RUN hex=' + all.toString('hex')));
      done(null, runs[0]);
    };
    const c = tls.connect(8883, host, TLS_OPTS, () => c.write(packet));
    const to = setTimeout(() => { try { c.destroy(); } catch (e) {} finish(); }, timeoutMs);
    c.on('data', (d) => chunks.push(Buffer.from(d)));
    c.on('close', () => { clearTimeout(to); finish(); });
    c.on('error', (e) => { clearTimeout(to); done(e); });
  });
}

// getPassword with retries for transient connection errors (:8883 flaps while waking).
// NEEDS_BUTTON is returned immediately (retrying won't help until the user presses HOME).
async function grabPassword(host, attempts = 15, delayMs = 2000) {
  let last;
  for (let i = 1; i <= attempts; i++) {
    try { return await getPassword(host); }
    catch (e) {
      if (e.message === 'NEEDS_BUTTON') throw e;
      last = e;
      await new Promise((r) => setTimeout(r, delayMs));
    }
  }
  throw last || new Error('grabPassword failed');
}

module.exports = { robot, TLS_OPTS, discoverRobot, resolveHostViaRouter, resolveHost, getPassword, grabPassword };
