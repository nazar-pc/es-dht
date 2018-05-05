# Entangled state DHT (ES-DHT)
Generic DHT framework agnostic to command set and transport layer.

This repository contains high level design overview (design.md, not written yet), specification for implementors (spec.md, not written yet) and reference implementation (not written yet).

WARNING: INSECURE UNTIL PROVEN THE OPPOSITE!!!

Intention is to create practical and robust DHT framework that is resistant to various kinds of adversaries, to which Mainline DHT (BitTorrent) or other widely deployed DHTs are inherently vulnerable.
Design is inspired by ideas from recent researches on relevant distributed systems. Implementation that is based on ES-DHT should facilitate creation of anonymization networks.

## Current status
Early prototyping stage, instability over 9000, expect everything to change at any time.

Ideas so far:
* Initial local state is a set of random bytes
* Merkle tree with IDs of connected nodes and their states results in an updated local state
* send updated local state to connected peers if:
  * (sorted?) list of connected peers has changed
  * each ~10s (poisson process) since last sent
* keep history of X (try 1000) states
* search
  * each query includes up to date local state, which requested node should apply immediately to its state
  * query contains id of interested node and details needed for connection establishment with it (because WebRTC)
  * if node is unable to forward connection details, drop its nodes from consideration for current round altogether
  * if node is unable to forward connection details to interested too often (threshold), treat it as malicious and drop connection (probably add to black list)

Inspiration:
* Kademlia - XOR metric and buckets system, but nodes IDs are public keys
* ShadowWalker - instead of shadow nodes make states of nodes recursively dependant on states of their peers
* NISAN - hiding searched ID by knowing all of the peers of each peer and selecting most suitable node locally

The idea is to execute search query on immutable a snapshot of the DHT and detect potential protocol violations.
This way malicious nodes can't substitute other malicious nodes on the fly as recursive query propagates towards target ID or they'll be quickly discovered.

## Contribution
Feel free to create issues and send pull requests (for big changes create an issue first and link it from the PR), they are highly appreciated!

## License
Implementation: Free Public License 1.0.0 / Zero Clause BSD License

https://opensource.org/licenses/FPL-1.0.0

https://tldrlegal.com/license/bsd-0-clause-license

Specification and design: public domain
