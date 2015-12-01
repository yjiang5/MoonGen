local dpdk	= require "dpdk"
local memory	= require "memory"
local dev	= require "device"
local dpdkc	= require "dpdkc"

local ffi	= require "ffi"

function master(...)
	local rxPort0, txPort0, rxPort1, txPort1 = tonumberall(...)
	-- TODO: NUMA-aware mempool allocation
	local mempool0 = memory.createMemPool(1024)
	local mempool1 = memory.createMemPool(1024)
	dev.config(rxPort0, mempool0)
	if rxPort0 ~= txPort0 then
		dev.config(txPort0, mempool0)
	end
	dev.config(rxPort1, mempool1)
	if rxPort1 ~= txPort1 then
		dev.config(txPort1, mempool1)
	end
	dev.waitForLinks(rxPort0, txPort0, rxPort1, txPort1)
	dpdk.launchLua("slave", rxPort0, txPort0, mempool0)
	dpdk.launchLua("slave", rxPort1, txPort1, mempool1)
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