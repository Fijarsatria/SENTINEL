"""Prove the regression rejects two deliberate acceptance bugs; source is unchanged."""
from pathlib import Path
import tempfile, subprocess, json
root=Path(__file__).resolve().parents[1]
source=(root/'verification/sentinel_guard.sv').read_text()
mutants={
    'skip_authentication':('if (auth && candidate_ok','if (candidate_ok'),
    'skip_replay_check':('header[191:128]>last_seq','1\'b1'),
}
results=[]
for name,(before,after) in mutants.items():
    assert before in source
    with tempfile.TemporaryDirectory(prefix='sentinel_mutation_') as d:
        p=Path(d);(p/'guard.sv').write_text(source.replace(before,after,1))
        cmd=['verilator','--binary','--timing','-Wno-fatal',
             '-I'+str(root/'verification/vendor/ascon-rtl'),'--top-module','tb_sentinel',
             '--Mdir',str(p/'build'),str(root/'verification/tb_sentinel.sv'),
             str(p/'guard.sv'),str(root/'verification/sentinel_app.sv')]
        build=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
        if build.returncode:raise RuntimeError(build.stdout[-4000:])
        run=subprocess.run([str(p/'build/Vtb_sentinel'),
             '+VECTORS='+str(root/'verification/demo_vectors.txt'),
             '+RESULTS='+str(p/'results.csv')],cwd=p,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
        detected=run.returncode!=0 and ('Premature application output' in run.stdout or
                                      'Commit mismatch' in run.stdout)
        if not detected:raise AssertionError(f'Mutant survived: {name}: {run.stdout}')
        results.append({'mutation':name,'detected':True,'expected_failure':run.stdout.splitlines()[0]})
(root/'verification/mutation_results.json').write_text(json.dumps(results,indent=2))
print('PASS 2 deliberate acceptance mutations detected by the regression')
