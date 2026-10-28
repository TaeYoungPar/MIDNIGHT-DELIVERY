"""Copy the verified Place as a direct Studio download; no ZIP is produced."""
from pathlib import Path
import shutil
import subprocess

subprocess.run(['python3', 'tools/check_project.py'], check=True)
source = Path('build/MidnightDelivery.rbxlx')
target = Path('downloads/MidnightDelivery.rbxlx')
target.parent.mkdir(exist_ok=True)
shutil.copyfile(source, target)
assert target.read_bytes() == source.read_bytes()
print(f'PASS {target} ({target.stat().st_size} bytes), matches verified artifact')
