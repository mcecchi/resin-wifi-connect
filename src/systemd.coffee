Promise = require 'bluebird'
DBus = require './dbus-promise'
dbus = new DBus()
bus = dbus.getBus('system')
_ = require 'lodash'

SERVICE = 'org.freedesktop.systemd1'
MANAGER_OBJECT = '/org/freedesktop/systemd1'
MANAGER_INTERFACE = 'org.freedesktop.systemd1.Manager'
UNIT_INTERFACE = 'org.freedesktop.systemd1.Unit'

exports.start = (unit, mode = 'fail') ->
	bus.getInterfaceAsync(SERVICE, MANAGER_OBJECT, MANAGER_INTERFACE)
	.then (manager) ->
		manager.StartUnitAsync(unit, mode)
	.then ->
		waitUntilState(unit, 'active') 

exports.stop = (unit, mode = 'fail') ->
	bus.getInterfaceAsync(SERVICE, MANAGER_OBJECT, MANAGER_INTERFACE)
	.then (manager) ->
		manager.StopUnitAsync(unit, mode)
	.then ->
		waitUntilState(unit, 'inactive') 

exports.exists = (unit, mode = 'fail') ->
	bus.getInterfaceAsync(SERVICE, MANAGER_OBJECT, MANAGER_INTERFACE)
	.call('ListUnitsAsync')
	.then (units) ->
		_.has(units[0], unit)

waitUntilState = (unit, targetState) ->
	currentState = null

	promiseWhile((->
		currentState != targetState
	), ->
		getState(unit)
		.then (state) ->
			currentState = state
		.delay(1000)	
	).then ->
		return

getState = (unit) ->
	bus.getInterfaceAsync(SERVICE, MANAGER_OBJECT, MANAGER_INTERFACE)
	.then (manager) ->
		manager.GetUnitAsync(unit)
	.then (objectPath) ->
		bus.getInterfaceAsync(SERVICE, objectPath, UNIT_INTERFACE)
	.then (unit) ->
		unit.getPropertyAsync('ActiveState')

promiseWhile = (condition, action) ->
	resolver = Promise.defer()

	l = ->
		if !condition()
			return resolver.resolve()
		Promise.cast(action()).then(l).catch resolver.reject

	process.nextTick l
	resolver.promise