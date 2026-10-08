from pathlib import Path
import csv,json
root=Path(__file__).resolve().parents[1]
s=json.loads((root/'evidence/summary.json').read_text())
print('SENTINEL | demo bukti RTL | bukan pengukuran board')
for name,r in zip(['Tag salah','Paket sah dengan stall','Replay paket sah'],
 csv.DictReader((root/'evidence/demo_results.csv').open())):
 print(f"{name:24} tag={r['expected_auth']} commit={r['commits']} last_seq={r['last_seq']} word tanpa gate={r['unsafe_writes']}")
x=s['start_to_commit_64_no_stall']
print(f"64 byte, {x['samples']} sampel tanpa stall: median={x['median_cycles']*0.02:.2f} us; p99={x['p99_cycles']*0.02:.2f} us; start core ke commit.")
print('SPI/CDC, MMIO, Quartus, daya, dan board menunggu integrasi.')
