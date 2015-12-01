local dpdk		= require "dpdk"
local memory	= require "memory"
local device	= require "device"
local stats		= require "stats"
local timer		= require "timer"

--memory.enableCache()

PKT_SIZE = 64

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
		task = dpdk.launchLua("loadSlave3", dev1:getTxQueue(0), dev2:getTxQueue(0), dev3:getTxQueue(0))
	elseif port1 and port2 then
		task = dpdk.launchLua("loadSlave2", dev1:getTxQueue(0), dev2:getTxQueue(0))
	else
		task = dpdk.launchLua("loadSlave1", dev1:getTxQueue(0))
	end
	local avg = task:wait()
	dpdk.waitForSlaves()
end

function loadSlave1(queue1)
	local mem = memory.createMemPool(function(buf)
		buf:getEthernetPacket():fill{
			pktLength = PKT_SIZE,
			ethSrc = "10:11:12:13:14:14",
			ethDst = "10:11:12:13:14:15",
		}
	end)
	bufs = mem:bufArray()
	local ctr1 = stats:newDevTxCounter(queue1.dev, "plain")
	while dpdk.running() do
		bufs:alloc(PKT_SIZE)
		queue1:send(bufs)
		ctr1:update()
	end
	ctr1:finalize()
	return nil -- TODO
end

function loadSlave2(queue1, queue2)
	local mem = memory.createMemPool(function(buf)
		buf:getEthernetPacket():fill{
			pktLength = PKT_SIZE,
			ethSrc = "10:11:12:13:14:14",
			ethDst = "10:11:12:13:14:15",
		}
	end)
	bufs = mem:bufArray()
	local ctr1 = stats:newDevTxCounter(queue1.dev, "plain")
	local ctr2 = stats:newDevTxCounter(queue2.dev, "plain")
	while dpdk.running() do
		bufs:alloc(PKT_SIZE)
		queue1:send(bufs)
		ctr1:update()
		bufs:alloc(PKT_SIZE)
		queue2:send(bufs)
		ctr2:update()
	end
	ctr1:finalize()
	ctr2:finalize()
	return nil -- TODO
end

function loadSlave3(queue1, queue2, queue3)
	local mem = memory.createMemPool(function(buf)
		buf:getEthernetPacket():fill{
			pktLength = PKT_SIZE,
			ethSrc = "10:11:12:13:14:14",
			ethDst = "10:11:12:13:14:15",
		}
	end)
	bufs = mem:bufArray()
	local ctr1 = stats:newDevTxCounter(queue1.dev, "plain")
	local ctr2 = stats:newDevTxCounter(queue2.dev, "plain")
	local ctr3 = stats:newDevTxCounter(queue3.dev, "plain")
	while dpdk.running() do
		bufs:alloc(PKT_SIZE)
		queue1:send(bufs)
		ctr1:update()
		bufs:alloc(PKT_SIZE)
		queue2:send(bufs)
		ctr2:update()
		bufs:alloc(PKT_SIZE)
		queue3:send(bufs)
		ctr3:update()
	end
	ctr1:finalize()
	ctr2:finalize()
	ctr3:finalize()
	return nil -- TODO
end

