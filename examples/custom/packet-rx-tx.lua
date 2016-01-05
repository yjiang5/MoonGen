local dpdk		= require "dpdk"
local memory	= require "memory"
local device	= require "device"
local stats		= require "stats"
local timer		= require "timer"

--memory.enableCache()

PKT_SIZE = 64
RUN_TIME = 65

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
	local tx_task, rx_task
	if port1 and port2 and port3 then
	  rx_task = dpdk.launchLua("rxSlave3", dev1:getRxQueue(0), dev2:getRxQueue(0), dev3:getRxQueue(0))
	  dpdk.sleepMillis(5000) -- wait few ms to ensure rx threads are running
		tx_task = dpdk.launchLua("txSlave3", dev1:getTxQueue(0), dev2:getTxQueue(0), dev3:getTxQueue(0))
	elseif port1 and port2 then
	  rx_task = dpdk.launchLua("rxSlave2", dev1:getRxQueue(0), dev2:getRxQueue(0))
	  dpdk.sleepMillis(5000) -- wait few ms to ensure rx threads are running
		tx_task = dpdk.launchLua("txSlave2", dev1:getTxQueue(0), dev2:getTxQueue(0))
	else
	  rx_task = dpdk.launchLua("rxSlave1", dev1:getRxQueue(0))
	  dpdk.sleepMillis(5000) -- wait few ms to ensure rx threads are running
		tx_task = dpdk.launchLua("txSlave1", dev1:getTxQueue(0))
	end
	local avg = rx_task:wait()
	      avg = tx_task:wait()
	dpdk.waitForSlaves()
end

local function fillEthernetPacket(buf)
  buf:getEthernetPacket():fill{
    pktLength = PKT_SIZE,
    ethSrc = "10:11:12:13:14:14",
    ethDst = "10:11:12:13:14:15",
  }
end

local function fillIPPacket(buf)
  buf:getIPPacket():fill{
    pktLength = PKT_SIZE,
    ethSrc = "10:11:12:13:14:14",
    ethDst = "10:11:12:13:14:15",
    ip4Src = "10.0.0.14",
    ip4Dst = "10.0.0.15",
  }
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
  printf("Total Rx Mpps: %s (avg.), %s (stddev.)\r\nTotal Rx Mbps: %s (avg.), %s (stddev.)", ctr1.mpps.avg, ctr1.mpps.stdDev,
    ctr1.wireMbit.avg, ctr1.wireMbit.stdDev)
  return nil -- TODO
end

function txSlave1(queue1)
	local mem = memory.createMemPool(function(buf)
		fillEthernetPacket(buf)
	end)
	bufs = mem:bufArray()
	bufs:alloc(PKT_SIZE)
	bufs:offloadIPChecksums()
	local ctr1 = stats:newDevTxCounter(queue1.dev, "plain")
	local runtime = timer:new(RUN_TIME)
	while runtime:running() and dpdk.running() do
		queue1:send(bufs)
		ctr1:update()
	end
	ctr1:finalize()
	printf("Total Tx Mpps: %s (avg.), %s (stddev.)\r\nTotal Tx Mbps: %s (avg.), %s (stddev.)", ctr1.mpps.avg, ctr1.mpps.stdDev,
		ctr1.wireMbit.avg, ctr1.wireMbit.stdDev)
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
  printf("Total Rx Mpps: %s (avg.), %s (stddev.)\r\nTotal Rx Mbps: %s (avg.), %s (stddev.)",
    ctr1.mpps.avg + ctr2.mpps.avg, ctr1.mpps.stdDev + ctr2.mpps.stdDev,
    ctr1.wireMbit.avg + ctr2.wireMbit.avg, ctr1.wireMbit.stdDev + ctr2.wireMbit.stdDev)
  return nil -- TODO
end

function txSlave2(queue1, queue2)
	local mem1 = memory.createMemPool(function(buf)
    fillEthernetPacket(buf)
	end)
	local mem2 = memory.createMemPool(function(buf)
    fillEthernetPacket(buf)
	end)
	bufs1 = mem1:bufArray()
	bufs1:alloc(PKT_SIZE)
	bufs1:offloadIPChecksums()
	bufs2 = mem2:bufArray()
	bufs2:alloc(PKT_SIZE)
	bufs2:offloadIPChecksums()
	local ctr1 = stats:newDevTxCounter(queue1.dev, "plain")
	local ctr2 = stats:newDevTxCounter(queue2.dev, "plain")
	local runtime = timer:new(RUN_TIME)
	while runtime:running() and dpdk.running() do
		queue1:send(bufs1)
		ctr1:update()
		queue2:send(bufs2)
		ctr2:update()
	end
	ctr1:finalize()
	ctr2:finalize()
	printf("Total Tx Mpps: %s (avg.), %s (stddev.)\r\nTotal Tx Mbps: %s (avg.), %s (stddev.)",
		ctr1.mpps.avg + ctr2.mpps.avg, ctr1.mpps.stdDev + ctr2.mpps.stdDev,
		ctr1.wireMbit.avg + ctr2.wireMbit.avg, ctr1.wireMbit.stdDev + ctr2.wireMbit.stdDev)
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
  printf("Total Rx Mpps: %s (avg.), %s (stddev.)\r\nTotal Rx Mbps: %s (avg.), %s (stddev.)",
    ctr1.mpps.avg + ctr2.mpps.avg + ctr3.mpps.avg, ctr1.mpps.stdDev + ctr2.mpps.stdDev + ctr3.mpps.stdDev,
    ctr1.wireMbit.avg + ctr2.wireMbit.avg + ctr3.wireMbit.avg, ctr1.wireMbit.stdDev + ctr2.wireMbit.stdDev + ctr3.wireMbit.stdDev)
  return nil -- TODO
end

function txSlave3(queue1, queue2, queue3)
	local mem1 = memory.createMemPool(function(buf)
    fillEthernetPacket(buf)
	end)
	local mem2 = memory.createMemPool(function(buf)
    fillEthernetPacket(buf)
	end)
	local mem3 = memory.createMemPool(function(buf)
    fillEthernetPacket(buf)
	end)

	bufs1 = mem1:bufArray()
	bufs1:alloc(PKT_SIZE)
	bufs1:offloadIPChecksums()
	bufs2 = mem2:bufArray()
	bufs2:alloc(PKT_SIZE)
	bufs2:offloadIPChecksums()
	bufs3 = mem3:bufArray()
	bufs3:alloc(PKT_SIZE)
	bufs3:offloadIPChecksums()
	local ctr1 = stats:newDevTxCounter(queue1.dev, "plain")
	local ctr2 = stats:newDevTxCounter(queue2.dev, "plain")
	local ctr3 = stats:newDevTxCounter(queue3.dev, "plain")
	local runtime = timer:new(RUN_TIME)
	while runtime:running() and dpdk.running() do
		queue1:send(bufs1)
		ctr1:update()
		queue2:send(bufs2)
		ctr2:update()
		queue3:send(bufs3)
		ctr3:update()
	end
	ctr1:finalize()
	ctr2:finalize()
	ctr3:finalize()
	printf("Total Tx Mpps: %s (avg.), %s (stddev.)\r\nTotal Tx Mbps: %s (avg.), %s (stddev.)",
		ctr1.mpps.avg + ctr2.mpps.avg + ctr3.mpps.avg, ctr1.mpps.stdDev + ctr2.mpps.stdDev + ctr3.mpps.stdDev,
		ctr1.wireMbit.avg + ctr2.wireMbit.avg + ctr3.wireMbit.avg, ctr1.wireMbit.stdDev + ctr2.wireMbit.stdDev + ctr3.wireMbit.stdDev)
	return nil -- TODO
end

