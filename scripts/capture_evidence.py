"""Capture completed simulator runs and the exact source files."""
from pathlib import Path
import shutil,hashlib
root=Path(__file__).resolve().parents[1];v=root/'verification';e=root/'evidence'
required=['summary.json','case_manifest.json','results.csv','simulation.log','demo_results.csv',
 'demo.log','vectors.txt','demo_vectors.txt','trace.csv','sentinel.vcd','tool_versions.txt',
 'parser_results.csv','parser.log','guard_contract_results.csv','guard_contract.log','mutation_results.json']
assert 'PASS ' in (v/'simulation.log').read_text()
for name in required:assert (v/name).is_file(),f'Missing completed result {name}'
for name in required:shutil.copy2(v/name,e/name)
paths=sorted(p for p in root.rglob('*') if p.is_file() and
 (p.is_relative_to(e) or p.is_relative_to(root/'rtl') or p.is_relative_to(root/'scripts') or
  p.is_relative_to(root/'figures') or p.is_relative_to(root/'diagrams') or
  (p.is_relative_to(v) and (p.suffix in ['.sv','.py','.sh'] or 'vendor' in p.parts))) and
 '__pycache__' not in p.parts and not any(x.startswith('build') for x in p.parts[:-1]))
with (root/'SHA256SUMS.txt').open('w',encoding='utf-8',newline='\n') as output:
 output.write(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+
  p.relative_to(root).as_posix()+'\n' for p in paths))
print(f'Captured evidence; {len(paths)} files hashed.')
