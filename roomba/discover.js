'use strict';
// Discover the Roomba on the LAN (dorita980 UDP broadcast to :5678, matched on
// our BLID). No credentials or button press needed. Prints the robot's public
// info, including its CURRENT (DHCP-assigned) IP.
const { robot, discoverRobot } = require('./lib');
discoverRobot(robot.blid)
  .then((info) => { console.log(JSON.stringify(info, null, 2)); process.exit(0); })
  .catch((e) => { console.error('ERR', e.message); process.exit(1); });
