local dpdk		= require "dpdk"
local memory	= require "memory"
local device	= require "device"

function master(port1, cores, rate)
	if not port1 or not cores then
		return print("Usage: port1 numCores [rate x50Mbps]")
	end
	rate = rate or 0
	local dev1 = device.config(port1, 1, cores)
	if dev1:getPciId() ~= device.PCI_ID_X710 and dev1:getPciId() ~= device.PCI_ID_XL710 then
		errorf("Invalid NIC")
	end
	dev1:setRate(rate)
	device.waitForLinks()
	for i = 0, cores - 1 do
		dpdk.launchLua("loadSlave", dev1:getTxQueue(i))
	end
	dpdk.waitForSlaves()
end

function loadSlave(queue1)
	printf("Starting task for %s", queue1)
	local mem = memory.createMemPool(function(buf)
		buf:getUdpPacket():fill({
			pktLength = 60
		})
	end)
	local lastPrint = dpdk.getTime()
	local totalSent = 0
	local lastTotal = 0
	local lastSent = 0
	local bufs = mem:bufArray()
	local queues = { queue1 }
	while dpdk.running() do
		for _, queue in ipairs(queues) do
			bufs:alloc(60)
			for _, buf in ipairs(bufs) do
				local pkt = buf:getUdpPacket()
				-- TODO: figure out if using a custom random number generator is faster
				-- 'good random' isn't needed here, a simple xorshift would be sufficient (and could run on 64bit datatypes)
				pkt.payload.uint32[0] = math.random(0, 2^32 - 1) 
				pkt.payload.uint32[1] = math.random(0, 2^32 - 1)
				pkt.payload.uint32[2] = math.random(0, 2^32 - 1)
				pkt.payload.uint32[3] = math.random(0, 2^32 - 1)
				pkt.udp.src = math.random(0, 2^16 - 1)
				pkt.udp.dst = math.random(0, 2^16 - 1)
				pkt.ip4.src.uint32 = math.random(0, 2^32 - 1)
				pkt.ip4.dst.uint32 = math.random(0, 2^32 - 1)
			end
			bufs:offloadIPChecksums()
			totalSent = totalSent + queue:send(bufs)
		end
		-- TODO: stats counters
		local time = dpdk.getTime()
		if time - lastPrint > 1 then
		local mpps = (totalSent - lastTotal) / (time - lastPrint) / 10^6
			printf("[Core %d] Sent %d packets, current rate %.2f Mpps, %.2f MBit/s, %.2f MBit/s wire rate", dpdk.getCore(), totalSent, mpps, mpps * 64 * 8, mpps * 84 * 8)
			lastTotal = totalSent
			lastPrint = time
		end
	end
	printf("%s Sent %d packets", queue1, totalSent)
end

