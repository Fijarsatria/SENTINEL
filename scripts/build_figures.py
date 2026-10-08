from pathlib import Path
import xml.etree.ElementTree as E,html,csv,json,math
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[1];ROOT=R;F=R/'figures';F.mkdir(exist_ok=True)
BLUE='#DCEAF4';GREEN='#E0EFEA';GRAY='#EEF0F2';RED='#FBE9E7';INK='#183544';WHITE='#FFFFFF'
def font(n,bold=False):
 candidates=['C:/Windows/Fonts/arialbd.ttf' if bold else 'C:/Windows/Fonts/arial.ttf','/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']
 return ImageFont.truetype(next(x for x in candidates if Path(x).exists()),n)
def lines(draw,text,ft,width):
 out=[]
 for para in text.split('\n'):
  line=''
  for word in para.split():
   test=(line+' '+word).strip()
   if draw.textlength(test,font=ft)>width and line:out.append(line);line=word
   else:line=test
  out.append(line)
 return out
class Diagram:
 def __init__(self,name,w,h):self.name=name;self.w=w;self.h=h;self.nodes=[];self.edges=[];self.bands=[]
 def node(self,id,label,x,y,w,h,fill=BLUE,shape='rect',size=24):self.nodes.append(dict(id=id,label=label,x=x,y=y,w=w,h=h,fill=fill,shape=shape,size=size));return id
 def edge(self,a,b,points=None,label='',pos=None,dashed=False):self.edges.append((a,b,points,label,pos,dashed))
 def band(self,label,x,y,w,h):self.bands.append((label,x,y,w,h))
 def export(self,model_root):
  root=E.SubElement(model_root,'diagram',name=self.name,id=self.name)
  m=E.SubElement(root,'mxGraphModel',dx=str(self.w),dy=str(self.h),grid='1',gridSize='10',page='1',pageScale='1',pageWidth=str(self.w),pageHeight=str(self.h))
  cells=E.SubElement(m,'root');E.SubElement(cells,'mxCell',id='0');E.SubElement(cells,'mxCell',id='1',parent='0')
  img=Image.new('RGB',(self.w,self.h),WHITE);d=ImageDraw.Draw(img)
  for i,(label,x,y,w,h) in enumerate(self.bands):
   d.rectangle((x,y,x+w,y+h),fill='#F7F9FA',outline='#BDC9CF',width=2)
   d.text((x+15,y+10),label,font=font(22,True),fill=INK)
   c=E.SubElement(cells,'mxCell',id='band'+str(i),value=html.escape(label),style='rounded=0;whiteSpace=wrap;html=1;fillColor=#F7F9FA;strokeColor=#BDC9CF;verticalAlign=top;align=left;spacing=12;fontSize=22;fontStyle=1;',vertex='1',parent='1')
   E.SubElement(c,'mxGeometry',x=str(x),y=str(y),width=str(w),height=str(h),attrib={'as':'geometry'})
  lookup={n['id']:n for n in self.nodes}
  for i,(a,b,points,label,pos,dashed) in enumerate(self.edges):
   an,bn=lookup[a],lookup[b]
   pts=points or [(an['x']+an['w'],an['y']+an['h']/2),(bn['x'],bn['y']+bn['h']/2)]
   for p,q in zip(pts,pts[1:]):
    if dashed:
     distance=math.dist(p,q)
     for t in range(0,int(distance),16):
      v=min(t+9,distance)
      d.line((p[0]+(q[0]-p[0])*t/distance,p[1]+(q[1]-p[1])*t/distance,p[0]+(q[0]-p[0])*v/distance,p[1]+(q[1]-p[1])*v/distance),fill=INK,width=3)
    else:d.line((p,q),fill=INK,width=3)
   p,q=pts[-2:];theta=math.atan2(q[1]-p[1],q[0]-p[0]);r=13
   d.polygon([q,(q[0]-r*math.cos(theta-.5),q[1]-r*math.sin(theta-.5)),(q[0]-r*math.cos(theta+.5),q[1]-r*math.sin(theta+.5))],fill=INK)
   if label and pos:
    bb=d.textbbox(pos,label,font=font(20));d.rectangle((bb[0]-5,bb[1]-4,bb[2]+5,bb[3]+4),fill=WHITE);d.text(pos,label,font=font(20),fill=INK)
   c=E.SubElement(cells,'mxCell',id='edge'+str(i),value=label,style='edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;endArrow=block;strokeColor='+INK+';fontSize=20;'+('dashed=1;' if dashed else ''),edge='1',parent='1',source=a,target=b)
   g=E.SubElement(c,'mxGeometry',relative='1',attrib={'as':'geometry'})
   if len(pts)>2:
    arr=E.SubElement(g,'Array',attrib={'as':'points'})
    for x,y in pts[1:-1]:E.SubElement(arr,'mxPoint',x=str(x),y=str(y))
  for n in self.nodes:
   x,y,w,h=n['x'],n['y'],n['w'],n['h'];shape=n['shape']
   if shape=='diamond':d.polygon([(x+w/2,y),(x+w,y+h/2),(x+w/2,y+h),(x,y+h/2)],fill=n['fill'],outline=INK,width=2)
   elif shape=='text':pass
   else:d.rectangle((x,y,x+w,y+h),fill=n['fill'],outline=INK,width=2)
   ft=font(n['size'],shape!='text');ls=lines(d,n['label'],ft,w-28);lh=n['size']+5
   yy=y+(h-lh*len(ls))/2
   for line in ls:d.text((x+(w-d.textlength(line,font=ft))/2,yy),line,font=ft,fill=INK);yy+=lh
   style=('rhombus;' if shape=='diamond' else 'text;' if shape=='text' else 'rounded=0;')+'whiteSpace=wrap;html=1;fontFamily=Arial;fontSize='+str(n['size'])+';fontStyle='+('0' if shape=='text' else '1')+';fontColor='+INK+';strokeColor='+('none' if shape=='text' else INK)+';fillColor='+('none' if shape=='text' else n['fill'])+';'
   c=E.SubElement(cells,'mxCell',id=n['id'],value=html.escape(n['label']).replace('\n','<br>'),style=style,vertex='1',parent='1')
   E.SubElement(c,'mxGeometry',x=str(x),y=str(y),width=str(w),height=str(h),attrib={'as':'geometry'})
  img.save(F/(self.name+'.png'))

D=[]
s=Diagram('01_solution',1400,520)
s.node('label','Dari paket serial ke efek aplikasi yang sah',30,10,1340,50,shape='text',size=30)
for id,label,x,fill in [('a','Paket diterima\nHeader + ciphertext + tag',30,GRAY),('b','Buffer privat\nPlaintext belum digunakan',365,BLUE),('c','Shadow aplikasi\nTag dan kebijakan telah lolos',700,GREEN),('d','Register aktif\nSatu edge commit',1035,GREEN)]:s.node(id,label,x,120,310,150,fill,size=27)
for a,b in [('a','b'),('b','c'),('c','d')]:s.edge(a,b)
s.node('reject','Tag salah / replay / frame tidak lengkap\nCommit = 0; live state dan last_seq tetap',300,345,800,100,RED,size=27)
s.edge('b','reject',[(520,270),(520,345)],label='gagal',pos=(535,296))
s.node('note','FPGA fabric memutuskan penerimaan. HPS tepercaya menyediakan kunci dan konteks sesi.',30,455,1340,50,shape='text',size=23);D.append(s)
a=Diagram('02_architecture',1400,850)
a.band('Batas kepercayaan   FPGA fabric memutuskan penerimaan',20,160,1360,655)
a.band('clk_io 25 MHz',35,215,235,340)
a.band('clk_sys 50 MHz   RTL dan integrasi',290,215,1075,340)
a.band('clk_sys 50 MHz   penerimaan dan efek transaksi',35,570,1330,185)
a.node('hps','HPS tepercaya\nProvisioning kunci/sesi dan status publik',300,20,740,95,GRAY,size=25)
a.node('spi','SPI mode 0\n2 Mbit/s target\nRencana',55,350,195,145,GRAY)
a.node('fifo','DCFIFO 128 × 10\nByte + SOP/EOP/ABORT\nRencana',315,350,230,145,GRAY)
a.node('parser','Parser + frame store\n32 + L + 16 byte\nRTL diuji terpisah',595,350,240,145,BLUE)
a.node('adapter','Adapter Ascon\nKey / nonce / AD / CT / tag\nRencana',885,350,230,145,GRAY)
a.node('core','Ascon RX\n32 bit\n1 round / siklus\nRTL diuji',1160,350,185,145,BLUE)
for x,y in [('spi','fifo'),('fifo','parser'),('parser','adapter'),('adapter','core')]:a.edge(x,y)
a.node('private','Buffer privat dan guard\nAutentikasi + kebijakan\n16 × 32 bit',900,605,400,115,BLUE,size=26)
a.node('shadow','Shadow aplikasi\nready / valid',520,605,290,115,GREEN,size=26)
a.node('live','Register aktif + last_seq\nCommit atomik',100,605,330,115,GREEN,size=26)
a.edge('core','private',[(1252,495),(1252,565),(1100,565),(1100,605)])
a.edge('private','shadow',[(900,662),(810,662)])
a.edge('shadow','live',[(520,662),(430,662)])
a.edge('hps','adapter',[(1000,115),(1000,320),(1000,350)],label='konteks',pos=(1010,260),dashed=True)
a.node('legend','Biru/hijau = RTL diuji; abu-abu = rencana integrasi. Parser belum diuji end-to-end dengan core.',300,765,1050,42,shape='text',size=22);D.append(a)
f=Diagram('03_acceptance',1400,1100)
f.band('Penerimaan per transaksi',20,20,920,1060);f.band('Pembatalan dan pemulihan',970,20,410,1060)
f.node('ready','READY dan sesi aktif\nSiap untuk satu frame',310,65,330,95,GRAY)
f.node('frame','Kumpulkan lalu freeze frame\nJumlah byte = 32 + L + 16',310,205,330,95,BLUE)
f.node('crypt','Ascon RX → buffer privat\nTunggu hasil autentikasi',310,345,330,95,BLUE)
f.node('policy','Tag / format sah?\nSesi / tujuan benar?\nSequence baru?',250,485,450,170,BLUE,'diamond',23)
f.node('release','Transfer ke shadow aplikasi\nvalid && ready',310,700,330,90,GREEN)
f.node('last','Beat terakhir diterima?',280,820,390,115,GREEN,'diamond',23)
f.node('commit','COMMIT satu edge\nLive payload + last_seq',285,985,380,75,GREEN,size=23)
f.node('stall','ready = 0\nTahan data bytes last\nWatchdog aktif',40,700,230,130,GRAY,size=23)
f.node('reject','BATALKAN\napp_valid = 0\nTidak ada commit',1030,485,290,120,RED,size=25)
f.node('cleanup','Buang shadow\nScrub buffer privat\nLive state tetap',1030,710,290,130,GRAY,size=25)
f.node('recover','Cleanup → READY\nReset/fault mencabut sesi\nProvisioning baru',1000,955,345,105,GRAY,size=23)
for aa,bb in [('ready','frame'),('frame','crypt'),('crypt','policy'),('policy','release'),('release','last'),('last','commit')]:
 n=next(x for x in f.nodes if x['id']==aa);m=next(x for x in f.nodes if x['id']==bb)
 f.edge(aa,bb,[(n['x']+n['w']/2,n['y']+n['h']),(m['x']+m['w']/2,m['y'])],label='ya' if aa in ['policy','last'] else '',pos=(490,n['y']+n['h']+8) if aa in ['policy','last'] else None)
f.edge('frame','reject',[(640,252),(880,252),(880,545),(1030,545)],label='terpotong / berlebih / overflow',pos=(675,215))
f.edge('policy','reject',[(670,570),(1030,570)],label='gagal',pos=(800,540))
f.edge('release','stall',[(310,745),(270,745)])
f.edge('stall','release',[(160,700),(160,670),(475,670),(475,700)],label='ready = 1',pos=(175,642))
f.edge('last','release',[(670,877),(825,877),(825,745),(640,745)],label='belum',pos=(752,886))
f.edge('reject','cleanup',[(1175,605),(1175,710)])
f.edge('cleanup','recover',[(1175,840),(1175,955)])
f.edge('commit','recover',[(665,1022),(1000,1022)],label='scrub',pos=(800,988))
f.node('interrupt','Abort / reset / timeout\nTutup gate di setiap tahap',1000,190,345,160,GRAY,size=23)
f.edge('interrupt','reject',[(1172,350),(1172,485)],dashed=True)
D.append(f)
b=Diagram('04_budget',1400,710)
b.node('title','Anggaran integrasi DE10-Nano   belum hasil fitting',30,10,1340,55,shape='text',size=31)
rows=[('Resource','Batas rancangan','Kapasitas A6','Porsi anggaran'),('ALM','≤6.000','41.910','14,32%'),('Register','≤5.000','167.640','2,98%'),('M10K','≤6 blok','557 blok','1,08%'),('DSP','0','112 blok','0%'),('FPGA PLL','≤1','6','16,67%')]
widths=[280,320,340,360]
for r,row in enumerate(rows):
 x=30
 for c,t in enumerate(row):b.node(f't{r}_{c}',t,x,100+r*65,widths[c],65,BLUE if r==0 else WHITE if r%2 else GRAY,size=26);x+=widths[c]
b.node('mem','Buffer logis 3.200 bit = FIFO 1.280 + frame 896 + privat 512 + shadow 512\nLive payload 512 bit, core state, key/context dan packing dihitung terpisah.',30,520,1340,85,GRAY,size=25)
b.node('note','Pemetaan M10K bergantung pada bank, port dan inference. Laporkan delta wrapper terhadap core pada part dan konfigurasi yang sama.',30,630,1340,60,shape='text',size=24);D.append(b)
mx=E.Element('mxfile',host='app.diagrams.net',version='24.7.17',type='device')
for item in D:item.export(mx)
(R/'diagrams').mkdir(exist_ok=True)
E.indent(mx);(R/'diagrams/SENTINEL_Design.drawio').write_bytes(E.tostring(mx,encoding='utf-8',xml_declaration=True))

# Waveform from CSV, with exact event boundaries derived from the run.
rows=list(csv.DictReader((R/'evidence/trace.csv').open()))
rows=[r for r in rows if int(r['case']) in (2498,2499,2500)]
start=int(rows[0]['cycle']);W,H=1600,700
img=Image.new('RGB',(W,H),'white');d=ImageDraw.Draw(img)
x0,x1=235,1540;y0=120;maxc=int(rows[-1]['cycle'])-start
def xx(c):return x0+(c-start)/maxc*(x1-x0)
for case,title in [(2498,'Tag salah'),(2499,'Sah dengan stall'),(2500,'Replay sah')]:
 rs=[r for r in rows if int(r['case'])==case];left,right=xx(int(rs[0]['cycle'])),xx(int(rs[-1]['cycle']))
 d.rectangle((left,80,right,H-90),fill='#F9FAFB' if case!=2499 else '#F1F7F5');d.text((left+10,90),title,font=font(23,True),fill=INK)
signals=[('raw_pt_valid','Plaintext core'),('auth_valid','Hasil tag valid'),('auth','Tag sah'),('app_valid','Release ke shadow'),('app_ready','Aplikasi ready'),('app_commit','Commit'),('last_seq','Sequence aktif')]
for j,(sig,label) in enumerate(signals):
 base=y0+j*66;d.text((20,base+7),label,font=font(23),fill=INK);pts=[]
 for r in rows:
  v=int(r[sig]);x=xx(int(r['cycle']));y=base+38-(25 if v else 0)
  if pts:pts.append((x,pts[-1][1]))
  pts.append((x,y))
 d.line(pts,fill=INK if sig!='app_commit' else '#11775F',width=3)
for t in range(0,maxc+1,50):
 x=x0+t/maxc*(x1-x0);d.line((x,580,x,590),fill=INK,width=2);d.text((x-15,600),str(t),font=font(19),fill=INK)
d.text((x0,647),'Siklus relatif, 20 ns per siklus. Trace RTL, tidak termasuk jalur SPI/CDC.',font=font(23),fill=INK)
img.save(F/'06_trace.png')
stats=json.loads((R/'evidence/summary.json').read_text())
ROOT.joinpath('figures/visual_metrics.json').write_text(json.dumps({'trace_start_cycle':start,'trace_cycles':maxc,'core_stats':stats},indent=2)+'\n',encoding='utf-8',newline='\n')
print('Generated editable draw.io diagrams, proposal figures and trace from actual CSV.')
