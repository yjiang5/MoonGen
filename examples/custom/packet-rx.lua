local dpdk		= require "dpdk"
local memory	= require "memory"
local device	= require "device"
local stats		= require "stats"
local timer		= require "timer"

--memory.enableCache()

local RUN_TIME = 10

-- TODO: this
function master(port1, port2, port3)
	if not port1 then
		return print("Usage: port1 [port2 [port3]]")
	end
	local dev1 = device.config(port1)
	local dev2
	if port2 then
		dev2 = device.config(port2)
	end
	local dev3
	if port3 then
		dev3 = device.config(port3)
	end
	device.waitForLinks()
	local task
	if port1 and port2 and port3 then
		task = dpdk.launchLua("rxSlave3", dev1:getRxQueue(0), dev2:getRxQueue(0), dev3:getRxQueue(0))
	elseif port1 and port2 then
		task = dpdk.launchLua("rxSlave2", dev1:getRxQueue(0), dev2:getRxQueue(0))
	else
		task = dpdk.launchLua("rxSlave1", dev1:getRxQueue(0))
	end
	local avgRx = task:wait()
	dpdk.waitForSlaves()
end

function rxSlave1(queue1)
	local bufs = memory.bufArray()
	local ctr1 = stats:newDevRxCounter(queue1.dev, "plain")
	local runtime = timer:new(RUN_TIME)
	while runtime:running() and dpdk.running() do
		queue1:tryRecv(bufs, 10)
		bufs:freeAll()
		ctr1:update()
	end
	ctr1:finalize()
	return nil -- TODO
end

function rxSlave2(queue1, queue2)
	local bufs = memory.bufArray()
	local ctr1 = stats:newDevRxCounter(queue1.dev, "plain")
	local ctr2 = stats:newDevRxCounter(queue2.dev, "plain")
	local runtime = timer:new(RUN_TIME)
	while runtime:running() and dpdk.running() do
		queue1:tryRecv(bufs, 10)
		bufs:freeAll()
		ctr1:update()
		queue2:tryRecv(bufs, 10)
		bufs:freeAll()
		ctr2:update()
	end
	ctr1:finalize()
	ctr2:finalize()
	return nil -- TODO
end

function rxSlave3(queue1, queue2, queue3)
	local bufs = memory.bufArray()
	local ctr1 = stats:newDevRxCounter(queue1.dev, "plain")
	local ctr2 = stats:newDevRxCounter(queue2.dev, "plain")
	local ctr3 = stats:newDevRxCounter(queue3.dev, "plain")
	local runtime = timer:new(RUN_TIME)
	while runtime:running() and dpdk.running() do
		queue1:tryRecv(bufs, 10)
		bufs:freeAll()
		ctr1:update()
		queue2:tryRecv(bufs, 10)
		bufs:freeAll()
		ctr2:update()
		queue3:tryRecv(bufs, 10)
		bufs:freeAll()
		ctr3:update()
	end
	ctr1:finalize()
	ctr2:finalize()
	ctr3:finalize()
	return nil -- TODO
end

