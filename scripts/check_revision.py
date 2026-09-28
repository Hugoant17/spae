"""Comprobaciones estáticas: no sustituyen flutter analyze ni PostgreSQL."""
from pathlib import Path
import re,ast,zipfile,xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
source=(root/'lib/core/live/indicator_values.dart').read_text()
fields=dict((ast.literal_eval("'"+a+"'"),ast.literal_eval("'"+b+"'")) for a,b in re.findall(r"'([^']*)':'([^']*)'",source.split('const trcFields=')[1].split(';')[0]))
expected={'NAA':['N.°','Código de\nparticipante','B1','B2','B3','B4','B5','NAAi (%)'],'TEC':['N.°','Código de participante','Hora de cumplimiento','Hora de emisión','TECi (horas)'],'TRC':['N.°','Código de\nparticipante',*fields.values(),'% de completitud\ndel registro']}
ns={'x':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
for kind,line in [('NAA',15),('TEC',14),('TRC',21)]:
 file=next((root/'docs/referencias').glob(f'Ficha_de_registro_{kind}*'))
 with zipfile.ZipFile(file) as z:
  shared=ET.fromstring(z.read('xl/sharedStrings.xml'))
  strings=[''.join(si.itertext()) for si in shared]
  sheet=ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
  cells=sheet.find(f'.//x:row[@r="{line}"]',ns)
  values=[strings[int(c.find('x:v',ns).text)] for c in cells if c.get('t')=='s']
  assert values==expected[kind],(kind,values,expected[kind])
print('Cabeceras NAA / TRC / TEC coinciden con las fichas originales.')
components=(root/'lib/core/live/components.dart').read_text()
assert 'setState(()=>future=' not in components
assert 'if(!mounted)return;setState((){future=widget.load();});' in components
assert 'dateTime:true' in (root/'lib/core/live/admin_pages.dart').read_text()
edge=(root/'supabase/functions/spae-api/index.ts').read_text()
assert 'delete values._member_id' in edge
sql='\n'.join(p.read_text() for p in (root/'supabase').rglob('*.sql'))
for f in (root/'lib').rglob('*.dart'):
 for rpc in re.findall(r"\.rpc\('([^']+)'",f.read_text()):
  assert f'function public.{rpc}(' in sql,rpc
print('RPC declaradas, calendario y corrección de recarga presentes.')

assert not re.search(r',\s*else\b', components), 'Coma interrumpe if/else de colección Dart'
