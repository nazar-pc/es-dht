/**
 * @package Entangled state DHT
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
/*
 * Implements version ? of the specification
 */
function Wrapper (array-map-set)
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
		 * @return {Uint8Array}
		 */
		last_key : ->
			@_last_key
	/**
	 * @constructor
	 *
	 * @param {!Uint8Array}	id			Own ID
	 * @param {number}		bucket_size	Size of a bucket from Kademlia design
	 *
	 * @return {!K_bucket}
	 */
	!function K_bucket (id, bucket_size)
		if !(@ instanceof K_bucket)
			return new K_bucket(bucket_size)

		@_id			= id
		@_bucket_size	= bucket_size
		@_nodes_details	= ArrayMap()

	K_bucket:: =
		/**
		 * @param {!Uint8Array}			id				Node ID
		 * @param {!Uint8Array}			state_version	Root of Merkle tree
		 * @param {!Array<!Uint8Array>}	peers			Peers of the node
		 *
		 * @return {boolean} `true` if node was added/updated or `false` otherwise
		 */
		set : (id, state_version, peers) ->
		/**
		 * @param {!Uint8Array} id Node ID
		 *
		 * @return {boolean}
		 */
		has : (id) ->
		/**
		 * @param {!Uint8Array} id Node ID
		 */
		del : (id) !->
		/**
		 * @param {!Uint8Array}	id		Node ID
		 * @param {number=}		number	How many results to return
		 *
		 * @return {!Array<!Uint8Array>} Array of node IDs closest to specified ID (`number` of nodes max)
		 */
		closest : (id, number = Number.Number.MAX_SAFE_INTEGER) ->
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
		# TODO: More stuff here

	DHT:: =
		/**
		 * @param {Uint8Array=} version	Specific state version or latest if `null`
		 *
		 * @return {!Array} `[version, state]`, where `version` is a Merkle Tree root of the state
		 */
		'get_state' : (version = null) ->
			version	= version || @_state.last_key()
			[version, @_state.get(version)]
		# TODO: Many more methods

	Object.defineProperty(DHT::, 'constructor', {value: DHT})

	DHT

if typeof define == 'function' && define['amd']
	# AMD
	define(['array-map-set'], Wrapper)
else if typeof exports == 'object'
	# CommonJS
	module.exports = Wrapper(require('array-map-set'))
else
	# Browser globals
	@'detox_transport' = Wrapper(@'array_map_set')
