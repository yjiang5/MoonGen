local dpdk		= require "dpdk"
local memory	= require "memory"
local device	= require "device"
local stats		= require "stats"
local timer		= require "timer"

--memory.enableCache()

local RUN_TIME = 10

-- TODO: this
function master(port1, port2, port3)
	if not port1 or not port2 or not port3 then
		return print("Usage: port1 port2 port3")
	end
	local dev1 = device.config(port1)
	local dev2 = device.config(port2)
	local dev3 = device.config(port3)
	device.waitForLinks()
	local task = dpdk.launchLua("rxSlave", dev1:getRxQueue(0), dev2:getRxQueue(0), dev3:getRxQueue(0))
	local avgRx = task:wait()
	dpdk.waitForSlaves()
end

function rxSlave(queue1, queue2, queue3)
	local bufs = memory.bufArray()
	local ctr1 = stats:newDevRxCounter(queue1.dev, "plain")
	local ctr2 = stats:newDevRxCounter(queue2.dev, "plain")
	local ctr3 = stats:newDevRxCounter(queue3.dev, "plain")
	while dpdk.running() do
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

