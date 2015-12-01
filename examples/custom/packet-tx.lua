local dpdk		= require "dpdk"
local memory	= require "memory"
local device	= require "device"
local stats		= require "stats"
local timer		= require "timer"

--memory.enableCache()

-- TODO: this
function master(port1, port2, port3)
	if not port1 or not port2 or not port3 then
		return print("Usage: port1 port2 port3")
	end
	local dev1 = device.config(port1)
	local dev2 = device.config(port2)
	local dev3 = device.config(port3)
	device.waitForLinks()
	local task = dpdk.launchLua("loadSlave", dev1:getTxQueue(0), dev2:getTxQueue(0), dev3:getTxQueue(0))
	local avg = task:wait()
	dpdk.waitForSlaves()
end

function loadSlave(queue1, queue2, queue3)
	local mem = memory.createMemPool(function(buf)
		buf:getEthernetPacket():fill{
			pktLength = size,
			ethSrc = queue,
			ethDst = "10:11:12:13:14:15",
		}
	end)
	bufs = mem:bufArray()
	local ctr1 = stats:newDevTxCounter(queue1.dev, "plain")
	local ctr2 = stats:newDevTxCounter(queue2.dev, "plain")
	local ctr3 = stats:newDevTxCounter(queue3.dev, "plain")
	while dpdk.running() do
		bufs:alloc(size)
		queue1:send(bufs)
		ctr1:update()
		bufs:alloc(size)
		queue2:send(bufs)
		ctr2:update()
		bufs:alloc(size)
		queue3:send(bufs)
		ctr3:update()
	end
	ctr1:finalize()
	ctr2:finalize()
	ctr3:finalize()
	return nil -- TODO
end

