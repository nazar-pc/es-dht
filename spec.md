# Entangled state DHT (ES-DHT) framework specification

Specification version: 0.1.0

Author: Nazar Mokrynskyi

License: Entangled state DHT framework specification (this document) is hereby placed in the public domain

### Introduction
This document is a textual specification of the Entangled state DHT framework.
The goal of this document is to give enough guidance to permit a complete and correct implementation.

Refer to the design document if you need a high level overview of this framework.

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED",  "MAY", and "OPTIONAL" in this document are to be interpreted as described in IETF [RFC 2119](http://www.ietf.org/rfc/rfc2119.txt).

### Glossary
* Peer: node in ES-DHT network that is directly connected to node under considerations

### K-bucket
K-bucket is a core data structure that is used for storing information about peers as well as used during lookup process.

K-bucket is initialized with some bucket size `k` and an empty collection of nodes. As other nodes are discovered, they are added to this collection until number of nodes in collection reaches `k`.
If new peer is going to be inserted into collection of size `k`, collection is split into 2, so that one of new collections, that is further from node's own ID by XOR metric (XOR between 2 IDs is treated as number) becomes unsplittable (doesn't split into 2 once collection reaches `k`).
This creates a tree of collections, in which there are more peers whose ID is closer to node's own ID and less as XOR distance is bigger.

You can refer to Kademlia paper for more details about k-bucket and XOR metric.

### Node state and and its versions
Each node keeps data structure called state.

State is a collection of peers IDs, each of which is associated with its latest known state version and collection of its peers IDs.

State version is a root hash of Merkle Tree. Merkle Tree is created by placing peers IDs, each followed by corresponding state version and own ID (twice) at the end (see "Merkle Tree and proofs" section below).
On start there are no peers connected, so Merkle Tree will only contain own ID twice and will grow/shrink over time as new peers are connected and existing disconnect.

Upon connection to new node, they must exchange state version, proof that its own ID is in this state version and IDs of their peers.
While connected they should also periodically update each other with newer versions of their states.
Since state of each node is based on state of their peers and vice versa, this data structure is recursive in its nature.
Because of this recursive nature, state changes must be sent to peers periodically, since immediate state change notification will cause snowball effect in the network (actually only part of the network that doesn't not follow the protocol).

### Lookup
Lookup is proceeded in rounds, each round may contain multiple parallel queries. Each lookup round is done locally similarly to NISAN and then connections to useful nodes are established.

First, empty k-bucket is created and filled with all of the nodes known (both peers and their peers).

In each round specified number of nodes is selected from k-bucket that are closest to target ID.
If node that is not yet connected (not a peer in the first round) appear in the list:
* Merkle Tree proofs (see "Merkle Tree and proofs" section below) is requested (with state version and peer ID) from previously connected node
  * if proof is not received or is incorrect, corresponding node is disconnected, blacklisted, its ID and its peers IDs are removed from previously created k-bucket
  * if proof is correct, state version is extracted
* connection to node is established and list of its peers is requested for state version that we get in previous step
* received peers are added to k-bucket

Proofs requests and connections in each round happen in parallel all at the same time. When everything is done, next round starts.

Lookup finishes when all closest nodes in a round are already connected.
Now either node with target ID will be directly connected or nodes that are closest to target ID will be known (for instance, in case of storing some data in DHT).

One of the hardening methods might include limiting fraction of nodes that originate from the same peer (peer itself or its peers) in the first round, so that it will not control our lookup exclusively.

Selecting nodes locally doesn't disclose target ID to peers, but if there are many lookup rounds and a lot of colluding nodes are along the way, adversary can figure out approximate range for target ID.

The fact that each next round uses state versions that are part of state versions in previous round, we effectively execute lookup on immutable snapshot of the network.
Immutability means that active adversary can't substitute colluding nodes dynamically and any diverging from normal operation will be visible to other nodes (though, some natural inability to connect to some nodes might happens because of nodes churn, so some heuristic is needed, which is not defined by this spec).

### Merkle Tree and proofs
Merkle Tree in ES-DHT must use hash function, that produces values from the same ID space as node ID. ES-DHT doesn't specify particular hash function though.

Merkle Tree proof is a binary string that consists of blocks. Each block starts with `0` or `1` for left and right accordingly, where hash of ID for which proof is generated should be inserted and followed by the other hash on the same level.
In our case we will only request hashes for IDs of peers, so the first block always starts with `0` and is followed by state version of the peer, which we can extract if proof is correct.

One minor exception from this rule is state of node itself, in this case proof is generated for node's ID and `0` will be followed by again with node's ID.

Merkle Tree construction, where each peer's ID is followed by state version is very useful, since we don't need additional operations to know which state version of peer's peer corresponds to peer's state version.

### Important considerations
ES-DHT doesn't specify anything related to transport layer, so it is important to keep it secure (for instance, using signatures that correspond to node's ID/public key).

Also it is responsibility of higher-level implementation to keep track of incorrect proofs, unsuccessful connections and other anomalies that are indications of various degrees of confidence about an active attacker presence.

### Acknowledgements
This design is heavily inspired by [Kademlia](http://www.scs.stanford.edu/~dm/home/papers/kpos.pdf) (XOR metric, k-buckets).

[ShadowWalker](https://www.freehaven.net/anonbib/cache/ccs09-shadowwalker.pdf) was a starting point for designing hierarchy of entangled states.

[NISAN](https://www.freehaven.net/anonbib/cache/ccs09-nisan.pdf)'s idea of hiding target ID was also used as an integral part of lookup process.
