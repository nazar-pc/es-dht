/**
 * @package Entangled state DHT
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
array-map-set	= require('array-map-set')
crypto			= require('crypto')
lib				= require('..')
test			= require('tape')

ArrayMap		= array-map-set.ArrayMap
sha1			= (data) ->
	crypto.createHash('sha1').update(data).digest()
random_bytes	= crypto.randomBytes


# WARNING: This is a trivial implementation for testing purposes, don't use it in real application as is!
instances	= ArrayMap()
!function Simple_DHT (id, bootstrap_node_id = null)
	if !(@ instanceof Simple_DHT)
		return new Simple_DHT(id, bootstrap_node_id)
	@_id	= id
	instances.set(id, @)
	@_dht	= lib(id, sha1, 20, 1000)
	@_data	= ArrayMap()
	if bootstrap_node_id
		state	= @_request(bootstrap_node_id, 'bootstrap', @_dht.get_state())
		if state
			[state_version, proof, peers]	= state
			@_dht.set_peer(bootstrap_node_id, state_version, proof, peers)
#	@_interval = setInterval (!~>
#		@lookup(random_bytes(20))
#		state							= @_dht.get_state()
#		[state_version, proof, peers]	= state
#		for peer in peers
#			@_request(peer, 'put_state', state)
#	), 20
Simple_DHT:: =
	lookup : (id) ->
		@_handle_lookup(@_dht.start_lookup(id))
		@_dht.finish_lookup(id)
	_handle_lookup : (nodes_to_connect_to) !->
		if !nodes_to_connect_to.length
			return
		for [target_node_id, parent_node_id, parent_state_version] in nodes_to_connect_to
			proof						= @_request(parent_node_id, 'get_state_proof', [target_node_id, parent_state_version])
			target_node_state_version	= @_dht.check_state_proof(parent_state_version, parent_node_id, proof, target_node_id)
			if target_node_state_version
				# Here we implicitly assume that `parent_node_id` helped us to connect to `target_node_id`
				[proof, target_node_peers]	= @_request(target_node_id, 'get_state', target_node_state_version)
				if @_dht.check_state_proof(target_node_state_version, target_node_id, proof, target_node_id)
					@_handle_lookup(@_dht.update_lookup(id, target_node_id, target_node_state_version, target_node_peers))
	put : (data) ->
		infohash	= sha1(data)
		@_data.set(infohash, data)
		for node in @lookup(infohash)
			@_request(node, 'put', data)
		infohash
	get : (infohash) ->
		if @_data.has(infohash)
			@_data.get(infohash)
		else
			for node in @lookup(infohash)
				data	= @_request(node, 'get', infohash)
				if data
					return data
			null
	destroy : !->
		clearInterval(@_interval)
	_request : (target_id, command, data) ->
		instances.get(target_id)._response(@_id, command, data)
	_response : (source_id, command, data) !->
		switch command
			case 'bootstrap'
				[state_version, proof, peers] = data
				return
					if @_dht.set_peer(source_id, state_version, proof, peers)
						@_dht.get_state()
					else
						null
			case 'get'
				return @_data.get(data) || null
			case 'put'
				infohash	= sha1(data)
				@_data.set(infohash, data)
			case 'get_state_proof'
				[peer_id, state_version]	= data
				return @_dht.get_state_proof(peer_id, state_version)
			case 'get_state'
				return @_dht.get_state(data).slice(1)
			case 'put_state'
				[state_version, proof, peers]	= data
				@_dht.set_peer(source_id, state_version, proof, peers)

test('es-dht', (t) !->
	t.plan(4)

	console.log 'Creating instances...'
	nodes				= []
	bootstrap_node_id	= random_bytes(20)
	Simple_DHT(bootstrap_node_id)
	for _ from 0 til 100
		id	= random_bytes(20)
		nodes.push(id)
		Simple_DHT(id, bootstrap_node_id)

	console.log 'Warm-up...'

	node_0	= instances.get(nodes[0])
	node_5	= instances.get(nodes[5])
	node_20	= instances.get(nodes[20])

	data		= random_bytes(10)
	infohash	= node_0.put(data)

	t.ok(infohash, 'put succeeded')
	t.equal(node_0.get(infohash), data, 'get on node 0 succeeded')
	t.equal(node_5.get(infohash), data, 'get on node 5 succeeded')
	t.equal(node_20.get(infohash), data, 'get on node 20 succeeded')

	instances.forEach (instance) !->
		instance.destroy()
)
