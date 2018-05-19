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
		@_dht.commit_state()
		if state
			[state_version, proof, peers]	= state
			@_dht.set_peer(bootstrap_node_id, state_version, proof, peers)
Simple_DHT:: =
	lookup : (id) ->
		@_handle_lookup(id, @_dht.start_lookup(id))
		@_dht.finish_lookup(id)
	_handle_lookup : (id, nodes_to_connect_to) !->
		if !nodes_to_connect_to.length
			return
		nodes_for_next_round	= []
		for [target_node_id, parent_node_id, parent_state_version] in nodes_to_connect_to
			proof						= @_request(parent_node_id, 'get_state_proof', [target_node_id, parent_state_version])
			target_node_state_version	= @_dht.check_state_proof(parent_state_version, proof, target_node_id)
			if target_node_state_version
				# Here we implicitly assume that `parent_node_id` helped us to connect to `target_node_id`
				[proof, target_node_peers]	= @_request(target_node_id, 'get_state', target_node_state_version)
				if @_dht.check_state_proof(target_node_state_version, proof, target_node_id).join?(',') == target_node_id.join(',')
					nodes_for_next_round	= nodes_for_next_round.concat(@_dht.update_lookup(id, target_node_id, target_node_state_version, target_node_peers))
				else
					throw new Error
			else
				throw new Error
		@_handle_lookup(id, nodes_for_next_round)
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
	get_peers : ->
		@_dht.get_state()[2]
	del_peer : (peer_id) !->
		@_dht.del_peer(peer_id)
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
						@_dht.commit_state()
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
				return @_dht.get_state_proof(state_version, peer_id)
			case 'get_state'
				return @_dht.get_state(data).slice(1)
			case 'put_state'
				[state_version, proof, peers]	= data
				@_dht.set_peer(source_id, state_version, proof, peers)

test('es-dht', (t) !->
	t.plan(8)

	console.log 'Creating instances...'
	nodes				= []
	bootstrap_node_id	= random_bytes(20)
	Simple_DHT(bootstrap_node_id)
	for _ from 0 til 100
		id	= random_bytes(20)
		nodes.push(id)
		Simple_DHT(id, bootstrap_node_id)

	console.log 'Warm-up...'

	node_a	= instances.get(nodes[Math.floor(nodes.length * Math.random())])
	node_b	= instances.get(nodes[Math.floor(nodes.length * Math.random())])
	node_c	= instances.get(nodes[Math.floor(nodes.length * Math.random())])

	data		= random_bytes(10)
	infohash	= node_a.put(data)

	t.ok(infohash, 'put succeeded')
	t.equal(node_a.get(infohash), data, 'get on node a succeeded')
	t.equal(node_b.get(infohash), data, 'get on node b succeeded')
	t.equal(node_c.get(infohash), data, 'get on node c succeeded')

	lookup_nodes	= node_a.lookup(random_bytes(20))
	t.ok(lookup_nodes.length >= 2 && lookup_nodes.length <= 20, 'Found at most 20 nodes on random lookup, but not less than 2')
	t.ok(lookup_nodes[0] instanceof Uint8Array, 'Node has correct ID type')
	t.equal(lookup_nodes[0].length, 20, 'Node has correct ID length')

	t.doesNotThrow (!->
		node_a.del_peer(node_a.get_peers()[* - 1])
	), 'Peer deletion works fine'

	instances.forEach (instance) !->
		instance.destroy()
)
