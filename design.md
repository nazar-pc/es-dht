# Entangled state DHT (ES-DHT) framework design

Complements specification version: ?

Author: Nazar Mokrynskyi

License: Entangled state DHT framework design (this document) is hereby placed in the public domain

### Introduction
This document is a high level design overview of the Entangled state DHT framework.
The goal of this document is to give general understanding what Entangled state DHT is, how it works and why it is designed the way it is.

Refer to the specification if you intend to implement this framework.

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED",  "MAY", and "OPTIONAL" in this document are to be interpreted as described in IETF [RFC 2119](http://www.ietf.org/rfc/rfc2119.txt).

### Glossary
* Peer: node in ES-DHT network that is directly connected to node under considerations

### What Entangled state DHT is and what isn't
This is not a design of the whole DHT. Instead, this is only the core part of DHT that needs to be implemented on top of ES-DHT.

The idea is to give a robust building block that can be extended with desired set of commands (like `PING`, `STORE`, `FIND_NODE` and `FIND_VALUE` in Kademlia terminology) on top of transport layer of choice (like TCP, UDP or even something exotic like WebRTC).

As such, ES-DHT will give you a few abstract methods for nodes lookup (while operating with IDs instead of real addresses) and managing peers (in k-buckets like in Kademlia).

### Nodes organization
Each node in ES-DHT has a unique ID of fixed size (ID space), likely pubic key or something derived from it. Each node stores information about part of the network in k-buckets (from Kademlia paper, refer to it for more details).
K-bucket is a tree-like structure where peers are organized by their IDs in such a way, that there are more peers that whose IDs are closer to ID of the node (using XOR metric), but as distance is bigger, there are less nodes.

In ES-DHT each node in addition to information about each peer's ID also stores information about their current state version (see "Node state and and its versions" section below) and peer's peers IDs.
This way even though node is only directly connected to its peers, it have a bit wider view of the network topology and can be one step ahead of potential adversary when doing lookup (see "Lookup" section below).

### Node state and and its versions
The primary feature of ES-DHT is node state. It is inspired by ShadowWalker's shadows, but it is kind of inverted and expanded in a way that covers not just a a few adjacent peers, but DHT as a whole.

So local state of the node in ES-DHT consist of peers IDs, their state versions and own ID. State version is a root hash of Merkle Tree composed from state items.

Merkle Tree is organized by placing peers IDs, each followed by corresponding state version and own ID (twice) at the end (see "Merkle Tree and proofs" section below).
This way every state version can implicitly prove not only its own contents, but also contents of each peer.
And since each peer's state version also contains information about their peers (hence entangled state in the name) and so on recursively, state version effectively represents a snapshot of the view from current node onto the whole network.

This property is essential for ES-DHT. Having snapshot of the network, we can do lookups always one step ahead of adversary and at the same time being able to identify with non-zero probability when active adversary tries to influence lookup process.

Node should keep a history of its states and regularly notify peers about changes (not immediately though, since it will have recursive snowball effect in the network).

### Lookup
Lookup is proceeded in rounds, each round may contain multiple parallel queries. Each lookup round is done locally similarly to NISAN and then connections to useful nodes are established.

When lookup is started, new k-bucket is created and IDs of all peers (that correspond to latest local state version at that moment of time) as we as their peers IDs are added.
Then IDs closest to target ID are selected and Merkle Tree proofs (see "Merkle Tree and proofs" section below) are requested for those IDs that are not peers yet from corresponding peers.
If proof for ID is not received or is incorrect, corresponding peer is disconnected, blacklisted, its ID and its peers IDs are removed from previously created k-bucket.
For nodes with correct proofs new connections are created in parallel, state at version from above proof is requested and peers are added to k-bucket.

Then process repeats starting from selecting closest nodes from k-bucket until all of the closest nodes are peers, at which point lookup is finished.
Now either node with target ID will be a peer or nodes that are closest to target ID will be known (for instance, in case of storing some data in DHT).

Such lookup procedure doesn't disclose target ID to peers, but if there are many lookup rounds and a lot of colluding nodes are along the way, adversary can figure out approximate range for target ID.

### Merkle Tree and proofs
Merkle Tree in ES-DHT must use hash function, that produces values from the same ID space as node ID. ES-DHT doesn't specify particular hash function though.

Merkle Tree proof is a binary string that consists of blocks. Each block starts with `0` or `1` for left and right accordingly, where hash of ID for which proof is generated should be inserted and followed by the other hash on the same level.
In our case we will only request hashes for IDs of peers, so the first block will always start with `0` and will be followed by state version of the peer, which we can extract if proof is correct.

One minor exception from this rule is state of node itself, in this case proof is generated for node's ID and `0` will be followed by again with node's ID.

Merkle Tree construction, where each peer's ID is followed by state version is very useful, since we don't need additional operations to know which state version of peer's peer corresponds to peer's state version.

### Important considerations
ES-DHT doesn't specify anything related to transport layer, so it is important to keep it secure (for instance, using signatures that correspond to node's ID/public key).

Also it is responsibility of higher-level implementation to keep track of incorrect proofs, unsuccessful connections and other anomalies that are indications of various degrees of confidence about an active attacker presence.

### Acknowledgements
This design is heavily inspired by [Kademlia](http://www.scs.stanford.edu/~dm/home/papers/kpos.pdf) (XOR metric, k-buckets).

[ShadowWalker](https://www.freehaven.net/anonbib/cache/ccs09-shadowwalker.pdf) was a starting point for designing hierarchy of entangled states.

[NISAN](https://www.freehaven.net/anonbib/cache/ccs09-nisan.pdf)'s idea of hiding target ID was used 
