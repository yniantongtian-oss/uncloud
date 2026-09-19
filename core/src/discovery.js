/**
 * discovery.js — LAN peer discovery over UDP multicast.
 *
 * Group: 239.255.77.77, port 47777. Every 2 seconds each device announces:
 *   { type: 'announce', deviceId, name, port, version: 1 }
 * The listener deduplicates peers by deviceId and expires them after 8 s
 * of silence.
 */
import dgram from 'node:dgram';
import { EventEmitter } from 'node:events';

export const MULTICAST_GROUP = '239.255.77.77';
export const DISCOVERY_PORT = 47777;
export const ANNOUNCE_INTERVAL_MS = 2000;
export const PEER_EXPIRY_MS = 8000;

/**
 * Start announcing this device and listening for peers.
 *
 * @param {object} options
 * @param {number} options.port       TCP port of this device's transfer server.
 * @param {string} options.name       Human-readable device name.
 * @param {string} options.deviceId   This device's id (ignored from peer list).
 * @param {number} [options.version]  Protocol version (default 1).
 * @param {string} [options.multicastGroup] Override multicast group (testing).
 * @param {number} [options.discoveryPort]  Override UDP port (testing).
 *
 * @returns {EventEmitter & {
 *   peers: Array<{deviceId:string,name:string,host:string,port:number,version:number,lastSeen:number}>,
 *   stop: () => void
 * }}
 * Emits: 'listening', 'peer' (new peer), 'peer-expired' (peer timed out),
 * 'error'.
 */
export function startDiscovery({
  port,
  name,
  deviceId,
  version = 1,
  multicastGroup = MULTICAST_GROUP,
  discoveryPort = DISCOVERY_PORT,
} = {}) {
  if (!deviceId) throw new Error('startDiscovery: deviceId is required');
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new Error('startDiscovery: port must be an integer between 0 and 65535');
  }

  const emitter = new EventEmitter();
  const peerMap = new Map();
  const socket = dgram.createSocket({ type: 'udp4', reuseAddr: true });
  let announceTimer = null;
  let expiryTimer = null;
  let stopped = false;

  function announce() {
    if (stopped) return;
    const message = Buffer.from(
      JSON.stringify({ type: 'announce', deviceId, name: name ?? 'unknown', port, version }),
      'utf8',
    );
    socket.send(message, 0, message.length, discoveryPort, multicastGroup, (err) => {
      if (err && emitter.listenerCount('error') > 0) emitter.emit('error', err);
    });
  }

  function sweepExpired() {
    const now = Date.now();
    for (const [id, peer] of peerMap) {
      if (now - peer.lastSeen > PEER_EXPIRY_MS) {
        peerMap.delete(id);
        emitter.emit('peer-expired', peer);
      }
    }
  }

  socket.on('message', (buf, rinfo) => {
    let msg;
    try {
      msg = JSON.parse(buf.toString('utf8'));
    } catch {
      return; // Ignore malformed datagrams silently.
    }
    if (!msg || msg.type !== 'announce' || typeof msg.deviceId !== 'string') return;
    if (msg.deviceId === deviceId) return; // Never list ourselves.

    const isNew = !peerMap.has(msg.deviceId);
    const peer = {
      deviceId: msg.deviceId,
      name: typeof msg.name === 'string' ? msg.name : 'unknown',
      port: Number.isInteger(msg.port) ? msg.port : 0,
      version: msg.version ?? 1,
      host: rinfo.address,
      lastSeen: Date.now(),
    };
    peerMap.set(msg.deviceId, peer);
    if (isNew) emitter.emit('peer', peer);
  });

  socket.on('error', (err) => {
    if (emitter.listenerCount('error') > 0) emitter.emit('error', err);
  });

  socket.bind(discoveryPort, () => {
    try {
      socket.addMembership(multicastGroup);
    } catch (err) {
      if (emitter.listenerCount('error') > 0) emitter.emit('error', err);
    }
    try {
      socket.setMulticastTTL(1); // Stay on the local link.
    } catch {
      /* best effort */
    }
    announce();
    announceTimer = setInterval(announce, ANNOUNCE_INTERVAL_MS);
    expiryTimer = setInterval(sweepExpired, 1000);
    emitter.emit('listening');
  });

  function stop() {
    if (stopped) return;
    stopped = true;
    if (announceTimer) clearInterval(announceTimer);
    if (expiryTimer) clearInterval(expiryTimer);
    try {
      socket.close();
    } catch {
      /* already closed */
    }
    peerMap.clear();
  }

  Object.defineProperty(emitter, 'peers', {
    enumerable: true,
    get: () => [...peerMap.values()],
  });
  Object.defineProperty(emitter, 'stop', { enumerable: true, value: stop });

  return emitter;
}
