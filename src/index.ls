/**
 * @package Entangled state DHT
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
/*
 * Implements version ? of the specification
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
function Wrapper (array-map-set, k-bucket-sync, merkle-tree-binary)
	ArrayMap	= array-map-set['ArrayMap']
	/**
	 * @constructor
	 *
	 * @param {number}	size
	 *
	 * @return {!LRU}
	 */
	!function LRU (size)
		if !(@ instanceof LRU)
			return new LRU(size)
		@_size		= size
		@_map		= ArrayMap()
		@_last_key	= null
	LRU:: =
		/**
		 * @param {!Uint8Array}			key
		 * @param {!Array<!Uint8Array>}	value
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
		 * @return {!Array<!Uint8Array>}
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
	/**
	 * @constructor
	 *
	 * @param {!Uint8Array}	id					Own ID
	 * @param {!Function}	hash_function		Hash function to be used for Merkle Tree
	 * @param {number}		bucket_size			Size of a bucket from Kademlia design
	 * @param {number}		state_history_size	How many versions of local history will be kept
	 *
	 * @return {!DHT}
	 */
	!function DHT (id, hash_function, bucket_size, state_history_size)
		if !(@ instanceof DHT)
			return new DHT(id, hash_function, bucket_size, state_history_size)

		@_id		= id
		# All IDs and hashes will have the same length, so store it for future references
		@_id_length	= id.length
		@_hash		= hash_function
		@_state		= LRU(state_history_size)
		@_insert_state(new Map)
		@_peers		= k-bucket-sync(@_id, bucket_size)
		# TODO: More stuff here

	DHT:: =
		/**
		 * @param {!Uint8Array}			peer_id			Id of a peer
		 * @param {!Uint8Array}			state_version	State version of a peer
		 * @param {!Uint8Array}			proof			Proof for specified state
		 * @param {!Array<!Uint8Array>}	peers			Peer's peers that correspond to `state_version`
		 *
		 * @return {boolean} `false` if proof is not valid or if a bucket that corresponds to this peer is already full
		 */
		'set_peer' : (peer_id, state_version, proof, peers) !->
			# Since peer_id is added to the end of leaves of Merkle Tree and the rest items are added in pairs, it will appear there as pair of the same elements too
			detected_peer_id	= @_check_state_proof(state_version, proof, peer_id)
			if !detected_peer_id || !are_arrays_equal(detected_peer_id, peer_id)
				return false
			if !@_peers.set(peer_id, ArraySet(peers))
				return false
			# TODO: handle peers diff
			state	= @_get_state_copy()
			state.set(peer_id, state_version)
			@_insert_state(state)
			true
		/**
		 * @param {!Uint8Array} peer_id Id of a peer
		 */
		'del_peer' : (peer_id) !->
			state	= @_get_state_copy()
			if !state.has(peer_id)
				return
			@_peers.delete(peer_id)
			state.delete(peer_id)
			@_insert_state(state)
		/**
		 * @param {Uint8Array=} state_version	Specific state version or latest if `null`
		 *
		 * @return {Array} `[state_version, proof, peers]` or `null` if state version not found, where `state_version` is a Merkle Tree root, `proof` is a proof
		 *                 that own ID corresponds to `state_version` and `peers` is an array of peers IDs
		 */
		'get_state' : (state_version = null) ->
			state	= @_get_state(state_version)
			if !state
				null
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
			@_state.get(state_version) || null
		/**
		 * @param {Uint8Array=}	state_version	Specific state version or latest if `null`
		 *
		 * @return {Map}
		 */
		_get_state_copy : (state_version = null) ->
			state	= @_get_state(state_version)
			if !state
				null
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
			if !state || !state.has(peer_id)
				new Uint8Array(0)
			else
				# Add own ID twice; this will not affect Merkle Tree root (if there are some peers already), but will allow us to check proof in `set_peer` method
				items	= [].concat(...Array.from(new_state), @_id, @_id)
				proof	= merkle-tree-binary['get_proof'](items, peer_id, @_hash)
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
			peer_state_version	= state.get(peer_id)
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
		 * @param {!Map}	new_state
		 */
		_insert_state : (new_state) !->
			items			= [].concat(...Array.from(new_state), @_id, @_id)
			state_version	= merkle-tree-binary['get_root'](items, @_hash)
			@_state.add(state_version, new_state)
		# TODO: Many more methods

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
	@'detox_transport' = Wrapper(@'array_map_set', @'k_bucket_sync', @'merkle_tree_binary')
