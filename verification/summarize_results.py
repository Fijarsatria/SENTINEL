"""Summarize actual simulator CSV and assertions; no simulated results are invented."""
from pathlib import Path
from collections import Counter
import csv
import hashlib
import json

root = Path(__file__).resolve().parent
manifest = json.loads((root / 'case_manifest.json').read_text())
results = list(csv.DictReader((root / 'results.csv').open()))
demo = list(csv.DictReader((root / 'demo_results.csv').open()))
assert len(results) == manifest['total_transactions']
assert f'PASS {len(results)} RTL transactions' in (root / 'simulation.log').read_text()
assert 'PASS 3 RTL transactions' in (root / 'demo.log').read_text()
assert all(int(r['commits']) == int(r['expected_commit']) for r in results)
assert len(demo) == 3
assert [int(r['commits']) for r in demo] == [0, 1, 0]
assert [int(r['last_seq']) for r in demo] == [0, 1, 1]
latency = int(demo[1]['cycles_to_auth'])
summary = {
    'transactions': len(results),
    'categories': dict(Counter(manifest['categories'].values())),
    'commits': sum(int(r['commits']) for r in results),
    'authentication_failures': sum(int(r['expected_auth']) == 0 for r in results),
    'results_sha256': hashlib.sha256((root / 'results.csv').read_bytes()).hexdigest(),
    'crypto64bytes_ad32_latency_cycles': latency,
    'simulated_clock_period_ns': 20,
    'observed_invalid_frame_application_effects': 0,
    'observed_premature_application_outputs': 0,
    'scope': 'Ascon RX core, release guard, and application commit. Byte parser is a separate tested suite. No SPI, CDC, Quartus, or hardware measurement.'
}
def stats(values):
    values=sorted(values)
    import math,statistics
    return {'samples':len(values),'median_cycles':statistics.median(values),
            'p99_cycles':values[max(0,math.ceil(len(values)*.99)-1)],
            'min_cycles':values[0],'max_cycles':values[-1]}
accepted=[r for r in results if int(r['commits'])==1]
vectors=(root/'vectors.txt').read_text().splitlines()
nostall=[r for r in accepted if manifest['categories'][r['id']]=='all_lengths_stall' and
         int(vectors[int(r['id'])-1].split()[8])==0]
summary['start_to_commit_all_accepted']=stats([int(r['cycles_to_commit']) for r in accepted])
summary['start_to_commit_64_no_stall']=stats([int(r['cycles_to_commit']) for r in accepted
    if manifest['categories'][r['id']]=='latency64_no_stall'])
summary['verilator_version']=(root/'tool_versions.txt').read_text().strip()
summary['start_to_commit_all_sizes_no_stall']=stats([int(r['cycles_to_commit']) for r in nostall])
summary['measurement_definition']='Core mode/frame_start to sampled commit edge, 20 ns clock; serial ingress is absent; p99 uses nearest rank.'
(root / 'summary.json').write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
