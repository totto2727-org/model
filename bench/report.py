import json
import math
import platform
import statistics
import subprocess
import sys

methods = ("pattern", "lens-per-call", "lens-prebuilt", "serde")
modes = ("text", "json")
lanes = range(8)
expected = {f"{lane}/{mode}/{method}" for lane in lanes for mode in modes for method in methods}
rows = json.load(sys.stdin)
medians = {row["name"]: row["median"] for row in rows}
if len(rows) != len(expected) or medians.keys() != expected:
    sys.exit("Expected one benchmark summary per lane, mode, and method")
if not all(math.isfinite(value) and value > 0 for value in medians.values()):
    sys.exit("Invalid benchmark latency")

cpu = platform.processor()
if platform.system() == "Darwin":
    cpu = subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip()
print(f"Platform: {platform.platform()}, {cpu}, native release")
print(subprocess.check_output(["moon", "version"], text=True).splitlines()[0])
print(f"{len(lanes)} interleaved lane medians per case, in µs/op")
print("| Input | Method | Median | Range |")
print("| --- | --- | ---: | ---: |")
for mode in modes:
    for method in methods:
        samples = [medians[f"{lane}/{mode}/{method}"] for lane in lanes]
        print(f"| {mode} | {method} | {statistics.median(samples):.3f} | {min(samples):.3f} to {max(samples):.3f} |")
