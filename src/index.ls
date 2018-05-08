/**
 * @package Entangled state DHT
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
/*
 * Implements version ? of the specification
 */
function Wrapper (array-map-set, k-bucket-sync)
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
	 * @param {number}		bucket_size			Size of a bucket from Kademlia design
	 * @param {number}		state_history_size	How many versions of local history will be kept
	 *
	 * @return {!DHT}
	 */
	!function DHT (id, bucket_size, state_history_size)
		if !(@ instanceof DHT)
			return new DHT(id, bucket_size, state_history_size)

		@_id	= id
		@_state	= LRU(state_history_size)
		@_insert_state(new Map)
		# TODO: More stuff here

	DHT:: =
		/**
		 * @param {!Uint8Array} id				Id of a peer
		 * @param {!Uint8Array} state_version	State version of a peer
		 */
		'set_peer' : (id, state_version) !->
			state	= @'get_state'()[1]
			state.set(id, state_version)
			@_insert_state(state)
		/**
		 * @param {!Uint8Array} id Id of a peer
		 */
		'del_peer' : (id) !->
			state	= @'get_state'()[1]
			if !state.has(id)
				return
			state.delete(id)
			@_insert_state(state)
		/**
		 * @param {Uint8Array=} state_version	Specific state version or latest if `null`
		 *
		 * @return {!Array} `[state_version, state]`, where `state_version` is a Merkle Tree root of the state and `state` is a `Map` with peers as keys and their state versions as values
		 */
		'get_state' : (state_version = null) ->
			state_version	= state_version || @_state.last_key()
			[state_version, ArrayMap(Array.from(@_state.get(version)))]
		/**
		 * @param {!Map}	new_state
		 */
		_insert_state : (new_state) !->
			items			= [].concat(...Array.from(new_state))
			items_count		= items.length
			# We'll insert own ID at the end of the list so that total number of items will be a power of 2, but not less than once
			# TODO: This should be in Merkle Tree implementation, only one item needs to be inserted explicitly
			items.length	= Math.ceil(Math.log2(items_count + 1)) - items_count
			items.fill(@_id, items_count)
			# TODO: This function doesn't yet exists
			state_version	= merkle-tree(items)
			@_state.add(state_version, new_state)
		# TODO: Many more methods

	Object.defineProperty(DHT::, 'constructor', {value: DHT})

	DHT

if typeof define == 'function' && define['amd']
	# AMD
	define(['array-map-set', 'k-bucket-sync'], Wrapper)
else if typeof exports == 'object'
	# CommonJS
	module.exports = Wrapper(require('array-map-set'), require('k-bucket-sync'))
else
	# Browser globals
	@'detox_transport' = Wrapper(@'array_map_set', @'k_bucket_sync')
