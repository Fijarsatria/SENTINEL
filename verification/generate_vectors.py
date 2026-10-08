from pathlib import Path
import ctypes
import json
import random
import struct

ROOT = Path(__file__).resolve().parent
LIB = ctypes.CDLL(str(ROOT / 'ascon_ref.so'))
U64 = ctypes.c_ulonglong
LIB.crypto_aead_encrypt.restype = ctypes.c_int

def encrypt(key, nonce, ad, pt):
    out = ctypes.create_string_buffer(len(pt) + 16)
    size = U64()
    rc = LIB.crypto_aead_encrypt(out, ctypes.byref(size), pt, U64(len(pt)),
        ad, U64(len(ad)), None, nonce, key)
    assert rc == 0 and size.value == len(pt) + 16
    return out.raw[:size.value]

def littlehex(data, width):
    return f'{int.from_bytes(data, "little"):0{width * 2}x}'

records = []
categories = {}

def emit(category, key, nonce, ad, pt, ct_tag=None, guard=0, auth=1,
         commit=0, reprovision=0, action=0, stall=0, complete=1):
    c = encrypt(key, nonce, ad, pt) if ct_tag is None else ct_tag
    caseid = len(records) + 1
    line = ' '.join(map(str, [caseid, len(pt), len(ad), guard, auth, commit,
        reprovision, action, stall, complete]))
    line += ' ' + ' '.join([littlehex(key,16), littlehex(nonce,16),
        littlehex(ad,32), littlehex(c[:-16],64), littlehex(c[-16:],16),
        littlehex(pt,64)])
    records.append(line)
    categories[caseid] = category
    return line

kat_count = 0
kat = (ROOT / 'vendor/LWC_AEAD_KAT_128_128.txt').read_text()
for block in kat.strip().split('\n\n'):
    row = dict(line.split(' = ', 1) for line in block.splitlines() if ' = ' in line)
    key, nonce, ad, pt, c = [bytes.fromhex(row[x]) for x in ('Key','Nonce','AD','PT','CT')]
    assert encrypt(key, nonce, ad, pt) == c, f'C reference KAT mismatch {row["Count"]}'
    emit('official_kat', key, nonce, ad, pt, c)
    kat_count += 1

SESSION = 0x0102030405060708
DEST = 0x11223344
KEY = bytes(range(16))

def header(seq, size, dest=DEST, session=SESSION, version=1, opcode=2, reserved=0):
    return struct.pack('<BBHIQQQ',version,opcode,size,dest,session,seq,reserved)

def protocol(seq, pt, **fields):
    ad = header(seq, len(pt), **fields)
    session = fields.get('session', SESSION)
    nonce = struct.pack('<QQ',session,seq)
    return nonce, ad, encrypt(KEY,nonce,ad,pt)

rng = random.Random(20261008)
lengths = [1,4,15,16,17,31,32,33,63,64]
for i in range(256):
    size = lengths[i%len(lengths)] if i<100 else rng.randint(1,64)
    pt = bytes(rng.getrandbits(8) for _ in range(size))
    n, ad, c = protocol(i+1, pt)
    emit('valid_protocol',KEY,n,ad,pt,c,guard=1,commit=1,
         reprovision=int(i==0),stall=(2+i%17 if i%5==0 else 0))

pt = bytes(range(64))
n, ad, c = protocol(1, pt)
base_parts = {'key':KEY,'nonce':n,'ad':ad,'ciphertext':c[:-16],'tag':c[-16:]}
first = True
for field, original in base_parts.items():
    for bit in range(len(original)*8):
        altered = bytearray(original)
        altered[bit//8] ^= 1<<(bit%8)
        p = dict(base_parts);p[field]=bytes(altered)
        emit('single_bit_'+field,p['key'],p['nonce'],p['ad'],pt,
             p['ciphertext']+p['tag'],guard=1,auth=0,
             reprovision=int(first))
        first=False

demo=[]
def directed(category,seq,pt,expected_commit=0,**kwargs):
    opts={k:kwargs.pop(k) for k in list(kwargs) if k in ['dest','session','version','opcode','reserved']}
    n,ad,c=protocol(seq,pt,**opts)
    corrupt=kwargs.pop('corrupt',False)
    if corrupt:c=c[:-1]+bytes([c[-1]^1])
    row=emit(category,KEY,n,ad,pt,c,guard=1,auth=int(not corrupt),
             commit=expected_commit,**kwargs)
    return row

demo.append(directed('demo_bad_tag',1,pt,corrupt=True,reprovision=1))
demo.append(directed('demo_valid_stalled',1,pt,1,stall=8))
demo.append(directed('demo_replay',1,pt))
directed('huge_seq_bad_tag',2**64-1,pt,corrupt=True)
directed('valid_after_poison_attempt',2,pt,1)
directed('authenticated_wrong_destination',3,pt,dest=0x11223345)
directed('authenticated_wrong_session',3,pt,session=SESSION+1)
directed('authenticated_reserved_bits',3,pt,reserved=1)
directed('authenticated_wrong_version',3,pt,version=2)
directed('authenticated_unknown_opcode',3,pt,opcode=0x80)
directed('incomplete_frame',3,pt,complete=0)
for action in [1,2,3,4]:
    directed(['','reset_before_tag','abort_before_tag','fault_before_tag',
        'reset_during_release'][action],3,pt,reprovision=1,action=action)
directed('set_cfg_command',1,b'\x78\x56\x34\x12',1,opcode=1,reprovision=1)
directed('busy_descriptor_overwrite',2,pt,1,action=6)
for plen,actual in [(0,0),(65,64),(64,63)]:
    p=pt[:actual]
    h=header(3,plen)
    n=struct.pack('<QQ',SESSION,3)
    emit('malformed_payload_length',KEY,n,h,p,guard=1)
for action in list(range(10,15))+list(range(20,25))+list(range(30,32))+list(range(40,42)):
    directed('single_bit_control_fault',3,pt,action=action,reprovision=1)

# Extended campaign: all legal sizes and meaningful interruption positions.
for _ in range(1024):
    payload=bytes(rng.getrandbits(8) for _ in range(64))
    directed('latency64_no_stall',1,payload,1,reprovision=1)
for size in range(1,65):
    payload=bytes(rng.getrandbits(8) for _ in range(size))
    for delay in (0,1,8,100):
        directed('all_lengths_stall',1,payload,1,reprovision=1,stall=delay)
for size in (1,15,16,17,31,32,33,63):
    payload=bytes(rng.getrandbits(8) for _ in range(size))
    n,h,c=protocol(1,payload)
    parts={'key':KEY,'nonce':n,'ad':h,'ciphertext':c[:-16],'tag':c[-16:]}
    first=True
    for field,original in parts.items():
        for bit in range(len(original)*8):
            changed=bytearray(original);changed[bit//8]^=1<<(bit%8)
            p=dict(parts);p[field]=bytes(changed)
            emit('extended_bit_'+field,p['key'],p['nonce'],p['ad'],payload,
                 p['ciphertext']+p['tag'],guard=1,auth=0,reprovision=int(first))
            first=False
for beat in range(16):
    for delay in (1,8,100):
        directed('stall_each_release_beat',1,pt,1,reprovision=1,action=50+beat,stall=delay)
    directed('abort_each_release_beat',1,pt,reprovision=1,action=100+beat)
    directed('reset_each_release_beat',1,pt,reprovision=1,action=200+beat)
for seq in (0,1,2**32-1,2**32,2**63,2**64-1):
    directed('sequence_boundaries',seq,pt,int(seq!=0),reprovision=1)
    directed('sequence_boundary_replay',seq,pt)
for size in (1,4,15,16,17,31,32,33,63,64):
    directed('release_watchdog',1,pt[:size],reprovision=1,action=300)

(ROOT/'vectors.txt').write_text('\n'.join(records)+'\n')
(ROOT/'demo_vectors.txt').write_text('\n'.join(demo)+'\n')
(ROOT/'case_manifest.json').write_text(json.dumps({
    'seed':20261008,'official_kat_count':kat_count,'total_transactions':len(records),
    'categories':categories,'core':'rprimas/ascon-verilog',
    'core_commit':'e1069549a1895f376391530a1842694ea8bb044b',
    'scope':'RX cryptographic core, quarantine/release guard and application commit; SPI/CDC and board integration pending'
},indent=2))
print(f'Generated {len(records)} real RTL transactions including {kat_count} official KAT vectors')
