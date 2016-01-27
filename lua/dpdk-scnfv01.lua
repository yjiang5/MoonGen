-- configuration for all DPDK command line parameters
-- see DPDK documentation for more details
-- MoonGen tries to choose reasonable defaults, so this config file can almost always be empty
DPDKConfig {
	-- configure the cores to use, either as a bitmask or as a list
	-- default: all cores
	--cores = 0x0F, -- use the first 4 cores
	cores = {2,4,6,8}, -- 0x66666664
	
	-- the number of memory channels (defaults to auto-detect)
	--memoryChannels = 2,

	-- the configures requried to run multiple DPDK applications. Refer to
	-- http://dpdk.org/doc/guides/prog_guide/multi_proc_support.html#running-multiple-independent-dpdk-applications
	-- for more information.
	
	-- a string to be the prefix, corresponding to EAL argument "--file-prefix"
	fileprefix = "nfv01",

	-- A string to specify the socket memory allocation, corresponding to EAL argument "--socket-mem"
	socketmem = "4096,4096",
	--
	-- PCI black list to avoid resetting PCI device assigned to other DPDK apps.
	-- Corresponding to ELA argument "--pci-blacklist"
	pciblack = {"0000:05:00.0","0000:05:00.1", "0000:05:00.2","0000:05:00.3"},

	-- disable hugetlb, see DPDK documentation for more information
	--noHugeTlbFs = true,
}
