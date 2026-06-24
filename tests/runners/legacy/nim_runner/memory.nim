proc bytesToMb(bytes: int): float =
  bytes.float / 1024.0 / 1024.0

proc occupiedMemoryMb*(): float =
  bytesToMb(getOccupiedMem())

proc peakManagedMemoryMb*(): float =
  when declared(system.getMaxMem):
    bytesToMb(system.getMaxMem())
  else:
    bytesToMb(getTotalMem())

proc benchmarkMemoryDeltaMb*(baselineOccupied, baselinePeak: float): float =
  max(
    occupiedMemoryMb() - baselineOccupied,
    peakManagedMemoryMb() - baselinePeak)
