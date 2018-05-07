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
	define(['array-map-set', 'k-bucket-sync'], Wrapper)
else if typeof exports == 'object'
	# CommonJS
	module.exports = Wrapper(require('array-map-set'), require('k-bucket-sync'))
else
	# Browser globals
	@'detox_transport' = Wrapper(@'array_map_set', @'k_bucket_sync')
