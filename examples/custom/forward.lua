local dpdk	= require "dpdk"
local memory	= require "memory"
local dev	= require "device"
local dpdkc	= require "dpdkc"

local ffi	= require "ffi"

function master(...)
	local rxPort1, txPort1, rxPort2, txPort2, rxPort3, txPort3 = tonumberall(...)
	-- TODO: NUMA-aware mempool allocation
	local isFwd1En = rxPort1 and txPort1
	local isFwd2En = rxPort2 and txPort2
	local isFwd3En = rxPort3 and txPort3
	local mempool1
	if isFwd1En then
		mempool1 = memory.createMemPool(1024)
		dev.config(rxPort1, mempool1)
		if rxPort1 ~= txPort1 then
			dev.config(txPort1, mempool1)
		end
	end	
	local mempool2
	if isFwd2En then
		mempool2 = memory.createMemPool(1024)
		dev.config(rxPort2, mempool2)
		if rxPort2 ~= txPort2 then
			dev.config(txPort2, mempool2)
		end
	end	
	local mempool3
	if isFwd3En then
		mempool3 = memory.createMemPool(1024)
		dev.config(rxPort3, mempool3)
		if rxPort3 ~= txPort3 then
			dev.config(txPort3, mempool3)
		end
	end	
	dev.waitForLinks()
	if isFwd1En then
		dpdk.launchLua("slave", rxPort1, txPort1, mempool1)
	end
	if isFwd2En then
		dpdk.launchLua("slave", rxPort2, txPort2, mempool2)
	end
	if isFwd3En then
		dpdk.launchLua("slave", rxPort3, txPort3, mempool3)
	end
	dpdk.waitForSlaves()
end

function slave(rxPort, txPort, mempool)
	local burstSize = 16
	local bufs = ffi.new("struct rte_mbuf*[?]", burstSize)
	while true do
		local n = dpdkc.rte_eth_rx_burst_export(rxPort, 0, bufs, burstSize)
		if n ~= 0 then
			-- send
			local sent = dpdkc.rte_eth_tx_burst_export(txPort, 0, bufs, n)
			for i = sent, n - 1 do
				dpdkc.rte_pktmbuf_free_export(bufs[i])
			end
		end
	end
end