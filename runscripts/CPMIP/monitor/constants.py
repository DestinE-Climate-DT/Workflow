"""
Global constants for SLURM monitoring.
"""

# Minimum number of columns expected in pidstat output (with -h -urw flags):
# Time, UID, PID, %usr, %system, %guest, %wait, %CPU, CPU,
# minflt/s, majflt/s, VSZ, RSS, %MEM, cswch/s, nvcswch/s, Command
PIDSTAT_MIN_COLUMNS = 17

# Expected columns in 'free -k' output for "Mem:" line:
# Mem: total used free shared buff/cache available
# Example: Mem:       263568128 78521856 66241280  2351232 118804992 180419200
FREE_MEM_MIN_COLUMNS = 7

# Column indices for 'free -k' memory line parsing
FREE_MEM_COLUMNS = {
    "total": 1,
    "used": 2,
    "free": 3,
    "shared": 4,
    "buff_cache": 5,
    "available": 6,
}

# Fields to collect from sstat command
SSTAT_FIELDS = [
    # Memory (with Node/Task information)
    "MaxVMSize",
    "MaxVMSizeNode",
    "MaxVMSizeTask",
    "AveVMSize",
    "MaxRSS",
    "MaxRSSNode",
    "MaxRSSTask",
    "AveRSS",
    # Disk I/O (with Node/Task information)
    "MaxDiskRead",
    "MaxDiskReadNode",
    "MaxDiskReadTask",
    "AveDiskRead",
    "MaxDiskWrite",
    "MaxDiskWriteNode",
    "MaxDiskWriteTask",
    "AveDiskWrite",
    # Paging (with Node/Task information)
    "MaxPages",
    "MaxPagesNode",
    "MaxPagesTask",
    "AvePages",
    # Energy
    "ConsumedEnergy",
    # Tasks / CPU time / frequency
    "NTasks",
    "MinCPU",
    "MinCPUNode",
    "MinCPUTask",
    "AveCPU",
    "AveCPUFreq",
    # Requested frequency (if available in the cluster)
    "ReqCPUFreqMin",
    "ReqCPUFreqMax",
    "ReqCPUFreqGov",
    # TRES usage (with Node/Task information for Max/Min)
    "TRESUsageInTot",
    "TRESUsageOutTot",
    "TRESUsageInMax",
    "TRESUsageInMaxNode",
    "TRESUsageInMaxTask",
    "TRESUsageOutMax",
    "TRESUsageOutMaxNode",
    "TRESUsageOutMaxTask",
    "TRESUsageInMin",
    "TRESUsageInMinNode",
    "TRESUsageInMinTask",
    "TRESUsageOutMin",
    "TRESUsageOutMinNode",
    "TRESUsageOutMinTask",
    "TRESUsageInAve",
    "TRESUsageOutAve",
]

# Kernel/infra process patterns to filter out
KERNEL_PROCESS_PATTERNS = (
    "kworker",
    "migration",
    "watchdog",
    "rcu_",
    "ksoftirqd",
    "kswapd",
)
