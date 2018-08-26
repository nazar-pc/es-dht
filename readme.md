# Entangled state DHT framework (ES-DHT) [![Travis CI](https://img.shields.io/travis/nazar-pc/es-dht/master.svg?label=Travis%20CI)](https://travis-ci.org/nazar-pc/es-dht)
Generic DHT framework agnostic to command set and transport layer.

This repository contains high level design overview (design.md), specification for implementors (spec.md) and reference implementation.

WARNING: INSECURE UNTIL PROVEN THE OPPOSITE!!!

## What is this
Entangled state DHT framework is intended to be practical and robust DHT framework that is resistant to active adversaries that try to distort information about network on the fly.
ES-DHT facilitates lookups over immutable snapshot of the whole or at least large part of DHT while only knowing a small part of all nodes.
This is achieved using Merkle Trees on each node that are recursively dependant on all of its peers, so that the whole network is interdependent and active adversary can't insert nodes into lookup process once lookup is started (which happens locally).

ES-DHT is not a full DHT implementation, but rather an important piece. ES-DHT also doesn't aim to protect against global passive adversary or other active attacks, defences against which can be implemented without changes to ES-DHT.

## Current status
Specification and design are not finalized yet, but seem good already.

Implementation API should be near stable and unlikely to change unless major spec changes are needed.

Still considered unstable, so be careful and make sure to report any issues you encounter. Project is covered with tests though to ensure it works as intended (see `tests` directory).

## How to install
```
npm install ronion
```

## How to use
Node.js:
```javascript
var es_dht = require('es-dht')

// Do stuff
```
Browser:
```javascript
requirejs(['es-dht'], function (es_dht) {
    // Do stuff
})
```

## Implementation API
Implementation is fully synchronous, which makes it easier to reason about and test.

### es_dht(id : Uint8Array, hash_function : Function, bucket_size : number, state_history_size : number, fraction_of_nodes_from_same_peer = 0.2 : number) : es_dht
Constructor, creates ES-DHT instance.

* `id` - Local ID (likely public key or something derived from it)
* `hash_function` - Hash function to be used for Merkle Tree
* `bucket_size` - Size of a bucket in internal k-bucket implementation
* `state_history_size` - How many history items will be kept in memory before removing older ones
* `fraction_of_nodes_from_same_peer` - what fraction of nodes can be originated from the same peer on lookup start

### es_dht.start_lookup(id : Uint8Array, number = bucket_size : number) : Array
Starts lookup for specified ID, returned result should be handled on higher level, then `es_dht.update_lookup()` is used to proceed with further rounds and `es_dht.finish_lookup()` to finish lookup.

* `id` - Target ID
* `number` - how many nodes to return in case lookup doesn't reach target ID (also impacts lookup performance in each round, defaults to bucket size)

Returns an array of items, each item is an array of `Uint8Array`s `[node_id, parent_peer_id, parent_peer_state_version]`.

### es_dht.update_lookup(id : Uint8Array, node_id : Uint8Array, node_state_version : Uint8Array, node_peers : Uint8Array[]) : Array
Continues lookup started with `es_dht.start_lookup()` for each element returned by `es_dht.start_lookup()` or consequent `es_dht.update_lookup()` call.

* `id` - Target ID, the same as in `es_dht.start_lookup()`
* `node_id` - As returned by `es_dht.start_lookup()` or previous `es_dht.update_lookup()`
* `node_state_version` - Corresponding state version for `node_id`
* `node_peers` - Peers of `node_id` at corresponding state version

Returns the same as in `start_lookup()` for next round, but next round should only start when previous is completely processed.

### es_dht.finish_lookup(id : Uint8Array) : Uint8Array[]
Finishes lookup started by `es_dht.start_lookup()` and cleans internal state related to lookup.

Returns `[id]` if node with specified ID was connected directly, an array of closest IDs if exact node wasn't found and `null` otherwise.

### es_dht.get_state(state_version = null : Uint8Array) : Array
Get specified (or latest if not specified explicitly) state of the node.

Returns `[state_version, proof, peers]` or `null` if state version not found, where `state_version` is a Merkle Tree root, `proof` is a proof that own ID corresponds to `state_version` and `peers` is an array of peers IDs.

### es_dht.commit_state()
Commit current state into state history, needs to be called if current state was sent to any peer.

This allows to only store useful state versions in cache known to other peers and discard the rest.

### es_dht.set_peer(peer_id : Uint8Array, peer_state_version : Uint8Array, proof : Uint8Array, peer_peers : Uint8Array[]) : boolean
Add or update peer with latest state version, proof for state version and peers.

* `peer_id` - ID of a peer
* `peer_state_version` - Latest state version of a peer
* `proof` - Proof that peer ID is inside latest state version
* `peer_peers` - Peer's peers IDs

Returns `false` if proof is not valid, returning `true` only means there was not errors, but peer was not necessarily added to k-bucket.

### es_dht.has_peer(node_id : Uint8Array) : boolean
Returns `true` if node is our peer (stored in k-bucket).

### es_dht.del_peer(peer_id : Uint8Array)
Delete peer from DHT (for instance if it goes offline).

### es_dht.get_state_proof(state_version : Uint8Array, peer_id : Uint8Array) : Uint8Array
Generates proof that peer ID or own ID is in specified state version.

### es_dht.check_state_proof(state_version : Uint8Array, proof : Uint8Array, node_id : Uint8Array) : Uint8Array
Checks whether proof generated by `es_dht.get_state_proof()` is valid.

* `state_version` - State version for which proof was generated
* `proof` - Proof itself
* `node_id` - Node ID for which proof was generated

Returns state version of `node_id` if checking peer's peer or `peer_id` if checking latest state or `null` if proof is not valid.


Look at code in `tests` directory for usage examples (not secure and not representative or real-world application, but should improve understanding).

## Contribution
Feel free to create issues and send pull requests (for big changes create an issue first and link it from the PR), they are highly appreciated!

When reading LiveScript code make sure to configure 1 tab to be 4 spaces (GitHub uses 8 by default), otherwise code might be hard to read.

## License
Implementation: Free Public License 1.0.0 / Zero Clause BSD License

https://opensource.org/licenses/FPL-1.0.0

https://tldrlegal.com/license/bsd-0-clause-license

Specification and design: public domain
