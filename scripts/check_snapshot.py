"""Verify shipped evidence and its source identity without a simulator."""
from pathlib import Path
from collections import Counter
import csv,json,hashlib
root=Path(__file__).resolve().parents[1];e=root/'evidence'
r=list(csv.DictReader((e/'results.csv').open()));s=json.loads((e/'summary.json').read_text())
m=json.loads((e/'case_manifest.json').read_text())
assert len(r)==s['transactions']==m['total_transactions']
assert [int(x['id']) for x in r]==list(range(1,len(r)+1))
assert Counter(m['categories'].values())==s['categories']
assert all(int(x['commits'])==int(x['expected_commit']) for x in r)
assert sum(int(x['commits']) for x in r)==s['commits']
assert hashlib.sha256((e/'results.csv').read_bytes()).hexdigest()==s['results_sha256']
assert f"PASS {len(r)} RTL transactions" in (e/'simulation.log').read_text()
d=list(csv.DictReader((e/'demo_results.csv').open()))
assert [int(x['commits']) for x in d]==[0,1,0]
assert [int(x['last_seq']) for x in d]==[0,1,1]
assert 'PASS 3 RTL transactions' in (e/'demo.log').read_text()
p=list(csv.DictReader((e/'parser_results.csv').open()))
assert len(p)==10290 and sum(int(x['accepted']) for x in p)==1314
assert sum(int(x['rejected']) for x in p)==8976
assert 'PASS 10290 parser frames' in (e/'parser.log').read_text()
c=list(csv.DictReader((e/'guard_contract_results.csv').open()))
assert len(c)==7 and all(x['commits']==x['expected_commits'] for x in c)
assert 'PASS 7 guard interface contracts' in (e/'guard_contract.log').read_text()
u=json.loads((e/'mutation_results.json').read_text())
assert len(u)==2 and all(x['detected'] for x in u)
for line in (root/'SHA256SUMS.txt').read_text().splitlines():
    digest,path=line.split('  ',1)
    assert hashlib.sha256((root/path).read_bytes()).hexdigest()==digest,f'Hash mismatch {path}'
print(f"Snapshot verified: {len(r)} core/guard/app transactions; {s['commits']} expected commits; "
      f"{len(p)} parser frames; {len(c)} contracts; 2 mutants detected.")
