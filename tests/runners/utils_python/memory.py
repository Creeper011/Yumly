import sys

def get_rss() -> int:
    """Return current RSS memory usage in bytes (cross-platform)."""
    try:
        import psutil
        return psutil.Process().memory_info().rss
    except (ImportError, Exception):
        pass

    if sys.platform != "win32":
        try:
            with open("/proc/self/status") as f:
                for line in f:
                    if line.startswith("VmRSS:"):
                        return int(line.split()[1]) * 1024
        except Exception:
            pass

    try:
        import resource
        mult = 1024 if sys.platform != "darwin" else 1
        return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss * mult
    except (ImportError, Exception):
        pass

    return 0