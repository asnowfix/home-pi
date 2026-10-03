'use strict';
// Discover the Roomba on the LAN (dorita980 UDP broadcast to :5678).
// No credentials or button press needed. Prints the robot's public info.
const dorita980 = require('dorita980');
const robot = require('./robot.json');
const to = setTimeout(() => { console.error('TIMEOUT: no robot reply on UDP 5678'); process.exit(2); }, 8000);
dorita980.getRobotPublicInfo(robot.host, (err, info) => {
  clearTimeout(to);
  if (err) { console.error('ERR', err.message); process.exit(1); }
  console.log(JSON.stringify(info, null, 2));
  process.exit(0);
});
