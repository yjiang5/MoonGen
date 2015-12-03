-- configuration for all DPDK command line parameters
-- see DPDK documentation for more details
-- MoonGen tries to choose reasonable defaults, so this config file can almost always be empty
DPDKConfig {
	-- configure the cores to use, either as a bitmask or as a list
	-- default: all cores
	--cores = 0x0F, -- use the first 4 cores
	cores = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30},
	
	-- the number of memory channels (defaults to auto-detect)
	--memoryChannels = 2,

	-- disable hugetlb, see DPDK documentation for more information
	--noHugeTlbFs = true,
}

