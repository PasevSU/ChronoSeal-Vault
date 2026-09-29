from pathlib import Path
import subprocess, sys
root=Path(__file__).resolve().parents[1]
addon=root/'chronoseal_vault'
if not (root/'repository.yaml').is_file(): raise SystemExit('[FAIL] repository.yaml missing')
if not addon.is_dir(): raise SystemExit('[FAIL] chronoseal_vault directory missing')
r=subprocess.run([sys.executable,str(addon/'tools/release_gate.py')])
raise SystemExit(r.returncode)
