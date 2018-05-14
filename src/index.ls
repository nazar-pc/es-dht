/**
 * @package Entangled state DHT
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
/*
 * Implements version 0.1.1 of the specification
 */
/**
 * @param {!Uint8Array}	array1
 * @param {!Uint8Array}	array2
 *
 * @return {boolean}
 */
function are_arrays_equal (array1, array2)
	if array1 == array2
		return true
	if array1.length != array2.length
		return false
	for item, key in array1
		if item != array2[key]
			return false
	true
/**
 * @param {!Uint8Array} array1
 * @param {!Uint8Array} array2
 *
 * @return {!Uint8Array}
 */
function concat (array1, array2)
	length	= array1.length
	new Uint8Array(length * 2)
		..set(array1)
		..set(array2, length)

function Wrapper (array-map-set, k-bucket-sync, merkle-tree-binary)
	ArrayMap	= array-map-set['ArrayMap']
	ArraySet	= array-map-set['ArraySet']
	/**
	 * @constructor
	 *
	 * @param {number}	size
	 *
	 * @return {!State_cache}
	 */
	!function State_cache (size)
		if !(@ instanceof State_cache)
			return new State_cache(size)
		@_size		= size
		@_map		= ArrayMap()
		@_last_key	= null
	State_cache:: =
		/**
		 * @param {!Uint8Array}	key
		 * @param {!Map}		value
		 */
		add : (key, value) !->
			if @_map.has(key)
				return
			@_map.set(key, value)
			@_last_key	= key
			if @_map.size > @_size
				@_map.delete(@_map.keys().next().value)
		/**
		 * @param {!Uint8Array}	key
		 *
		 * @return {!Map}
		 */
		get : (key) ->
			@_map.get(key)
		/**
		 * @param {!Uint8Array}	key
		 */
		del : (key) !->
			@_map.delete(key)
			if !@_map.has(@_last_key)
				@_last_key = Array.from(@_map.keys())[* - 1] || null
		/**
		 * @return {Uint8Array} `null` if there are no items
		 */
		last_key : ->
			@_last_key
	Object.defineProperty(State_cache::, 'constructor', {value: State_cache})
	/**
	 * @constructor
	 *
	 * @param {!Uint8Array}	id									Own ID
	 * @param {!Function}	hash_function						Hash function to be used for Merkle Tree
	 * @param {number}		bucket_size							Size of a bucket from Kademlia design
	 * @param {number}		state_history_size					How many versions of local history will be kept
	 * @param {number}		fraction_of_nodes_from_same_peer	Max fraction of nodes originated from single peer allowed on lookup start
	 *
	 * @return {!DHT}
	 */
	!function DHT (id, hash_function, bucket_size, state_history_size, fraction_of_nodes_from_same_peer = 0.2)
		if !(@ instanceof DHT)
			return new DHT(id, hash_function, bucket_size, state_history_size, fraction_of_nodes_from_same_peer)

		@_id								= id
		# All IDs and hashes will have the same length, so store it for future references
		@_id_length							= id.length
		@_hash								= hash_function
		@_bucket_size						= bucket_size
		@_fraction_of_nodes_from_same_peer	= fraction_of_nodes_from_same_peer
		@_state								= State_cache(state_history_size)
		@_peers								= k-bucket-sync(@_id, bucket_size)
		# Lookups that are in progress
		@_lookups							= ArrayMap()
		@_insert_state(new Map)

	DHT:: =
		/**
		 * @param {!Uint8Array}	id		ID if the node being searched for
		 * @param {number=}		number	Number of nodes to be returned if exact match was not found, defaults to bucket size
		 *
		 * @return {!Array<!Array<!Uint8Array>>} Array of items, each item is an array of `Uint8Array`s `[node_id, parent_peer_id, parent_peer_state_version]`
		 */
		'start_lookup' : (id, number = @_bucket_size) ->
			if @_peers['has'](id)
				return []
			bucket		= k-bucket-sync(id, number)
			parents		= ArrayMap()
			state		= @_get_state()
			state.forEach ([state_version, peer_peers], peer_id) !->
				bucket.set(peer_id)
				for peer_peer_id in peer_peers
					if !parents.has(peer_peer_id) && bucket.set(peer_peer_id)
						parents.set(peer_peer_id, peer_id)
			max_fraction	= Math.max(@_fraction_of_nodes_from_same_peer, 1 / @_peers['count']())
			current_number	= number
			# On the first round of lookup we only allow some fraction of closest nodes to originate from the same peer
			loop
				closest_so_far			= bucket['closest'](id, number)
				closest_nodes_found		= closest_so_far.length
				max_count_allowed		= Math.ceil(closest_nodes_found * max_fraction)
				nodes_to_connect_to		= []
				connections_awaiting	= ArraySet()
				originated_from			= ArrayMap()
				retry					= false
				for closest_node_id in closest_so_far
					parent_peer_id	= parents.get(closest_node_id)
					if parent_peer_id
						count	= originated_from.get(parent_peer_id) || 0
						originated_from.set(parent_peer_id, count + 1)
						if count > max_count_allowed
							# This node should be discarded, since it exceeds quota for number of nodes originated from the same peer
							bucket.del(closest_node_id)
							retry	= true
						else
							parent_peer_state_version	= state.get(parent_peer_id)
							nodes_to_connect_to.push([closest_node_id, parent_peer_id, parent_peer_state_version])
							connections_awaiting.add(closest_node_id)
					else
						count	= originated_from.get(closest_node_id) || 0
						originated_from.set(closest_node_id, count + 1)
						if count > max_count_allowed
							# This node should be discarded, since it exceeds quota for number of nodes originated from the same peer
							bucket.del(closest_node_id)
							retry	= true
				if !retry
					break
			@_lookups.set(id, [connections_awaiting, bucket, number])
			nodes_to_connect_to
		/**
		 * @param {!Uint8Array}			id					The same as in `start_lookup()`
		 * @param {!Uint8Array}			node_id				As returned by `start_lookup()`
		 * @param {!Uint8Array}			node_state_version	Corresponding state version for `node_id`
		 * @param {Array<!Uint8Array>}	node_peers			Peers of `node_id` at state `node_state_version` or `null` if connection to `node_id` have failed
		 *
		 * @return {!Array<!Array<!Uint8Array>>} The same as in `start_lookup()`
		 */
		'update_lookup' : (id, node_id, node_state_version, node_peers) ->
			lookup	= @_lookups.get(id)
			if !lookup
				return []
			[connections_awaiting, bucket, number]	= lookup
			connections_awaiting.delete(node_id)
			if !node_peers
				bucket.del(node_id)
				return []
			added_nodes	= ArraySet()
			for node_peer_id in node_peers
				if !bucket.has(node_peer_id) && bucket.set(node_peer_id)
					added_nodes.add(node_peer_id)
			closest_so_far		= bucket['closest'](id, number)
			nodes_to_connect_to	= []
			for closest_node_id in closest_so_far
				if added_nodes.has(closest_node_id)
					nodes_to_connect_to.push([closest_node_id, node_id, node_state_version])
					connections_awaiting.add(closest_node_id)
			nodes_to_connect_to
		/**
		 * @param {!Uint8Array} id The same as in `start_lookup()`
		 *
		 * @return {Array<!Uint8Array>} `[id]` if node with specified ID was connected directly, an array of closest IDs if exact node wasn't found and `null` otherwise
		 */
		'finish_lookup' : (id) ->
			lookup	= @_lookups.get(id)
			@_lookups.delete(id)
			if @_peers['has'](id)
				return [id]
			if !lookup
				return null
			[, bucket, number]	= lookup
			bucket['closest'](id, number)
		/**
		 * @param {!Uint8Array}			peer_id				Id of a peer
		 * @param {!Uint8Array}			peer_state_version	State version of a peer
		 * @param {!Uint8Array}			proof				Proof for specified state
		 * @param {!Array<!Uint8Array>}	peer_peers			Peer's peers that correspond to `state_version`
		 *
		 * @return {boolean} `false` if proof is not valid, returning `true` only means there was not errors, but peer was not necessarily added to k-bucket
		 *                   (use `has_peer()` method if confirmation of addition to k-bucket is needed)
		 */
		'set_peer' : (peer_id, peer_state_version, proof, peer_peers) ->
			expected_number_of_items	= peer_peers.length * 2 + 2
			proof_block_size			= @_id_length + 1
			expected_proof_height		= Math.log2(expected_number_of_items)
			proof_height				= proof.length / (proof_block_size)
			# First check if proof height roughly corresponds to number of peer's peers advertised
			if proof_height != expected_proof_height
				if proof_height != Math.ceil(expected_proof_height)
					return false
				# Then check if there are non-advertised peers in state version
				last_block	= peer_id
				for block from 0 to Math.ceil(Math.log2(expected_number_of_items) ** 2 - (expected_number_of_items)) / 2
					if (
						proof[block * proof_block_size] != 0 ||
						!are_arrays_equal(proof.subarray(block * proof_block_size + 1, (block + 1) * proof_block_size), last_block)
					)
						return false
					last_block	= @_hash(concat(last_block, last_block))
			# Since peer_id is added to the end of leaves of Merkle Tree and the rest items are added in pairs, it will appear there as pair of the same elements too
			detected_peer_id	= @_check_state_proof(peer_state_version, proof, peer_id)
			if !detected_peer_id || !are_arrays_equal(detected_peer_id, peer_id)
				return false
			if !@_peers['set'](peer_id)
				return true
			state	= @_get_state_copy()
			state.set(peer_id, [peer_state_version, peer_peers])
			@_insert_state(state)
			true
		/**
		 * @param {!Uint8Array} node_id
		 *
		 * @return {boolean} `true` if node is our peer (stored in k-bucket)
		 */
		'has_peer' : (node_id) ->
			@_peers['has'](node_id)
		/**
		 * @param {!Uint8Array} peer_id Id of a peer
		 */
		'del_peer' : (peer_id) !->
			state	= @_get_state_copy()
			if !state.has(peer_id)
				return
			@_peers['delete'](peer_id)
			state.delete(peer_id)
			@_insert_state(state)
		/**
		 * @param {Uint8Array=} state_version	Specific state version or latest if `null`
		 *
		 * @return {Array} `[state_version, proof, peers]` or `null` if state version not found, where `state_version` is a Merkle Tree root, `proof` is a proof
		 *                 that own ID corresponds to `state_version` and `peers` is an array of peers IDs
		 */
		'get_state' : (state_version = null) ->
			state_version	= state_version || @_state.last_key()
			state			= @_get_state(state_version)
			if !state
				return null
			# Get proof that own ID is in this state version
			proof	= @'get_state_proof'(state_version, @_id)
			[state_version, proof, Array.from(state.keys())]
		/**
		 * @param {Uint8Array=}	state_version	Specific state version or latest if `null`
		 *
		 * @return {Map} `null` if state is not found
		 */
		_get_state : (state_version = null) ->
			state_version	= state_version || @_state.last_key()
			if !state_version
				return null
			@_state.get(state_version)
		/**
		 * @param {Uint8Array=}	state_version	Specific state version or latest if `null`
		 *
		 * @return {Map}
		 */
		_get_state_copy : (state_version = null) ->
			state	= @_get_state(state_version)
			if !state
				return null
			ArrayMap(Array.from(state))
		/**
		 * Generate proof about peer in current state version
		 *
		 * @param {!Uint8Array} state_version	Specific state version
		 * @param {!Uint8Array} peer_id			ID of peer for which to create a proof
		 *
		 * @return {!Uint8Array}
		 */
		'get_state_proof' : (state_version, peer_id) ->
			state	= @_get_state(state_version)
			if !state || (!state.has(peer_id) && !are_arrays_equal(peer_id, @_id))
				new Uint8Array(0)
			else
				items	= @_reduce_state_to_proof_items(state)
				merkle-tree-binary['get_proof'](items, peer_id, @_hash)
		/**
		 * @param {!Map} state
		 *
		 * @return {!Array<!Uint8Array>}
		 */
		_reduce_state_to_proof_items : (state) ->
			items	= []
			state.forEach ([peer_state_version], peer_id) !->
				items.push(peer_id, peer_state_version)
			# Add own ID twice; this will not affect Merkle Tree root (if there are some peers already), but will allow us to check proof in `set_peer` method
			items.push(@_id, @_id)
			items
		/**
		 * Generate proof about peer in current state version
		 *
		 * @param {!Uint8Array} state_version	Local state version
		 * @param {!Uint8Array} peer_id			ID of peer that created proof
		 * @param {!Uint8Array} proof			Proof itself
		 * @param {!Uint8Array} target_peer_id	ID of peer's peer for which proof was generated
		 *
		 * @return {Uint8Array} `state_version` of `target_peer_id` on success or `null` otherwise
		 */
		'check_state_proof' : (state_version, peer_id, proof, target_peer_id) ->
			state	= @_get_state(state_version)
			if !state
				return null
			[peer_state_version]	= state.get(peer_id)
			@_check_state_proof(peer_state_version, proof, target_peer_id)
		/**
		 * @param {!Uint8Array} state_version
		 * @param {!Uint8Array} proof
		 * @param {!Uint8Array} target_peer_id
		 *
		 * @return {Uint8Array} `state_version` of `target_peer_id` on success or `null` otherwise
		 */
		_check_state_proof : (state_version, proof, target_peer_id) ->
			# Correct proof will always start from `0` followed by state version, since peer ID and its state version are placed one after another in Merkle Tree
			if proof[0] == 0 && merkle-tree-binary['check_proof'](state_version, proof, target_peer_id, @_hash)
				proof.subarray(1, @_id_length + 1)
			else
				null
		/**
		 * @param {!Map} new_state
		 */
		_insert_state : (new_state) !->
			items			= @_reduce_state_to_proof_items(new_state)
			state_version	= merkle-tree-binary['get_root'](items, @_hash)
			@_state.add(state_version, new_state)
	Object.defineProperty(DHT::, 'constructor', {value: DHT})

	DHT

if typeof define == 'function' && define['amd']
	# AMD
	define(['array-map-set', 'k-bucket-sync', 'merkle-tree-binary'], Wrapper)
else if typeof exports == 'object'
	# CommonJS
	module.exports = Wrapper(require('array-map-set'), require('k-bucket-sync'), require('merkle-tree-binary'))
else
	# Browser globals
	@'es_dht' = Wrapper(@'array_map_set', @'k_bucket_sync', @'merkle_tree_binary')
