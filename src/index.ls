/**
 * @package Entangled state DHT
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
/*
 * Implements version ? of the specification
 */
/**
 * @constructor
 *
 * @param {number}	size
 * @param {!Map=}	ArrayMap
 *
 * @return {!LRU}
 */
!function LRU (size, ArrayMap = new Map)
	if !(@ instanceof LRU)
		return new LRU(size)
	@_size		= size
	@_map		= new ArrayMap
	@_last_key	= null
LRU:: =
	/**
	 * @param {!Uint8Array}			key
	 * @param {!Array<!Uint8Array>}	value
	 */
	add : (key, value) !->
		@_map.set(key, value)
		@_last_key	= key
		if @_map.size > @_size
			@_map.delete(@_map.keys().next().value)
	/**
	 * @param {Uint8Array=}	key `null` for last key
	 *
	 * @return {!Array<!Uint8Array>}
	 */
	get : (key = null) ->
		@_map.get(key || @_last_key)
	/**
	 * @return {Uint8Array}
	 */
	last_key : ->
		@_last_key

function Wrapper (array-map-set)
	ArrayMap	= array-map-set['ArrayMap']
	/**
	 * @constructor
	 *
	 * @param {number}	bucket_size			Size of a bucket from Kademlia design
	 * @param {number}	state_history_size	How many versions of local history will be kept
	 *
	 * @return {!DHT}
	 */
	!function DHT (bucket_size, state_history_size)
		if !(@ instanceof DHT)
			return new DHT(bucket_size, state_history_size)

		@_state	= LRU(state_history_size, ArrayMap)
		# TODO: More stuff here

	DHT:: =
		/**
		 * @param {Uint8Array=} version	Specific state version or latest if `null`
		 */
		'get_state' : (version = null) ->
			@_state.get(version)
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
