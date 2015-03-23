--- This script can be used to determine if a device is affected by the corrupted packets
--  that are generated by the software rate control method.
--  It generates CBR traffic via both methods and compares the resulting latency distributions.
--  TODO: this module should also test L3 traffic (but not just L3 due to size constraints (timestamping limitations))
local dpdk		= require "dpdk"
local memory	= require "memory"
local ts		= require "timestamping"
local device	= require "device"
local filter	= require "filter"
local timer		= require "timer"
local stats		= require "stats"

local REPS = 1
local RUN_TIME = 10
local PKT_SIZE = 60

function master(...)
	local txPort, rxPort, maxRate = tonumberall(...)
	if not txPort or not rxPort then
		errorf("usage: txPort rxPort [maxRate (Mpps)] [steps]")
	end
	local minRate = 0.02
	maxRate = maxRate or 7.44
	steps = steps or 20
	local txDev = device.config(txPort, 2, 2)
	local rxDev = device.config(rxPort, 2, 2)
	local txQueue = txDev:getTxQueue(0)
	local txQueueTs = txDev:getTxQueue(1)
	local rxQueueTs = rxDev:getRxQueue(1)
	rxDev:l2Filter(0x1234, filter.DROP)
	device.waitForLinks()
	for rate = minRate, maxRate, (maxRate - minRate) / 20 do
		for i = 1, REPS do
			for method = 1, 2 do
				printf("Testing rate %f Mpps with %s rate control, test run %d", rate, method == 1 and "hardware" or "software", i)
				txQueue:setRateMpps(method == 1 and rate or 0)
				local loadTask = dpdk.launchLua("loadSlave", txQueue, rxDev, method == 2 and rate)
				local timerTask = dpdk.launchLua("timerSlave", txDev, rxDev, txQueueTs, rxQueueTs)
				loadTask:wait()
				local hist = timerTask:wait()
				printf("\n")
				dpdk.sleepMillis(500)
			end
			if not dpdk.running() then
				break
			end
		end
		if not dpdk.running() then
			break
		end
	end
end

function loadSlave(queue, rxDev, rate)
	-- TODO: this leaks memory as mempools cannot be deleted in DPDK
	local mem = memory.createMemPool(function(buf)
		buf:getEthernetPacket():fill{
			ethType = 0x1234,
		}
	end)
	local bufs = mem:bufArray()
	local runtime = timer:new(RUN_TIME)
	local rxStats = stats:newRxCounter(rxDev, "plain")
	local txStats = stats:newTxCounter(queue, "plain")
	while runtime:running() and dpdk.running() do
		bufs:alloc(PKT_SIZE)
		if rate then
			for _, buf in ipairs(bufs) do
				buf:setRate(rate)
			end
			queue:sendWithDelay(bufs)
		else
			queue:send(bufs)
		end
		rxStats:update()
		txStats:update()
	end
	-- wait for packets in flight/in the tx queue
	dpdk.sleepMillis(500)
	txStats:finalize()
	rxStats:finalize()
end


local timestamper = {}
timestamper.__index = timestamper

local function newTimestamper(txQueue, rxQueue, mem)
	mem = mem or memory.createMemPool(function(buf)
		buf:getPtpPacket():fill{} -- defaults are good enough for us
	end)
	txQueue:enableTimestamps()
	rxQueue:enableTimestamps()
	return setmetatable({
		mem = mem,
		txBufs = mem:bufArray(1),
		rxBufs = mem:bufArray(128),
		txQueue = txQueue,
		rxQueue = rxQueue,
		txDev = txQueue.dev,
		rxDev = rxQueue.dev,
		seq = 1,
	}, timestamper)
end

--- Try to measure the latency of a single packet.
-- @param pktSize the size of the generated packet
-- @param packetModifier a function that is called with the generated packet, e.g. to modified addresses
-- @param maxWait the time in ms to wait before the packet is assumed to be lost (default = 15)
function timestamper:measureLatency(pktSize, packetModifier, maxWait)
	maxWait = (maxWait or 15) / 1000
	self.txBufs:alloc(pktSize)
	local buf = self.txBufs[1]
	buf:enableTimestamps()
	buf:getPtpPacket().ptp:setSequenceID(self.seq)
	local expectedSeq = self.seq
	if packetModifier then
		packetModifier(buf, pktSize)
	end
	self.seq = self.seq + 1
	ts.syncClocks(self.txDev, self.rxDev)
	self.txQueue:send(self.txBufs)
	local tx = self.txQueue:getTimestamp(500)
	if tx then
		-- sent was successful, try to get the packet back (assume that it is lost after a given delay)
		local timer = timer:new(maxWait)
		while timer:running() do
			local rx = self.rxQueue:tryRecv(self.rxBufs, 1000)
			-- only one packet in a batch can be timestamped as the register must be read before a new packet is timestamped
			for i = 1, rx do
				local buf = self.rxBufs[i]
				local pkt = buf:getPtpPacket()
				local seq = pkt.ptp:getSequenceID()
				if buf:hasTimestamp() and seq == expectedSeq then
					-- yay!
					local delay = (self.rxQueue:getTimestamp() - tx) * 6.4
					self.rxBufs:freeAll()
					return delay
				elseif buf:hasTimestamp() then
					-- we got a timestamp but the wrong sequence number. meh.
					self.rxQueue:getTimestamp() -- clears the register
					-- continue, we may still get our packet :)
				elseif seq == expectedSeq then
					-- we got our packet back but it wasn't timestamped
					-- we likely ran into the previous case earlier and cleared the ts register too late
					self.rxBufs:freeAll()
					return
				end
			end
		end
		-- looks like our packet got lost :(
		return
	else
		-- uhm, how did this happen? an unsupported NIC should throw an error earlier
		print("Warning: failed to timestamp packet on transmission")
		timer:new(maxWait):wait()
	end
end

function timerSlave(txDev, rxDev, txQueue, rxQueue)
	local timestamper = newTimestamper(txQueue, rxQueue) -- ts:newTimestamper()
	local hist = {}
	-- wait for a second to give the other task a chance to start
	-- TODO: maybe add sync points? but we don't want to start timestamping right away anyways
	dpdk.sleepMillis(1000)
	local runtime = timer:new(RUN_TIME - 2)
	local rateLimiter = timer:new(0.001)
	while runtime:running() and dpdk.running() do
		rateLimiter:reset()
		print(timestamper:measureLatency(PKT_SIZE))
		-- keep the timestamping packets limited to about 1 kpps
		-- this is important when testing low rates
		rateLimiter:busyWait()
	end
	local sortedHist = {}
	for k, v in pairs(hist) do 
		table.insert(sortedHist,  { k = k, v = v })
	end
	local sum = 0
	local samples = 0
	table.sort(sortedHist, function(e1, e2) return e1.k < e2.k end)
	for _, v in ipairs(sortedHist) do
		sum = sum + v.k * v.v
		samples = samples + v.v
		--print(v.k, v.v)
	end
	print("Average: " .. (sum / samples) .. " ns, " .. samples .. " samples")
	print("----------------------------------------------")
	io.stdout:flush()
	return hist
end

