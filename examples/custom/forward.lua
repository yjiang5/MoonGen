local dpdk	= require "dpdk"
local memory	= require "memory"
local dev	= require "device"
local dpdkc	= require "dpdkc"

local ffi	= require "ffi"

function master(...)
	local rxPort1, txPort1, rxPort2, txPort2, rxPort3, txPort3 = tonumberall(...)
	-- TODO: NUMA-aware mempool allocation
	local mempool1 = memory.createMemPool(1024)
	local mempool2 = memory.createMemPool(1024)
	local mempool3 = memory.createMemPool(1024)
	dev.config(rxPort1, mempool1)
	dev.config(rxPort2, mempool2)
	dev.config(rxPort3, mempool3)
	if rxPort1 ~= txPort1 then
		dev.config(txPort1, mempool1)
	end
	if rxPort2 ~= txPort2 then
		dev.config(txPort2, mempool2)
	end
	if rxPort3 ~= txPort3 then
		dev.config(txPort3, mempool3)
	end
	dev.waitForLinks()
	dpdk.launchLua("slave", rxPort1, txPort1, mempool1)
	dpdk.launchLua("slave", rxPort2, txPort2, mempool2)
	dpdk.launchLua("slave", rxPort3, txPort3, mempool3)
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