from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
errors=[]
for p in (root/'lib').rglob('*.dart'):
 source=p.read_text()
 for name in re.findall(r"import '([^']+)'",source):
  if not name.startswith(('package:','dart:')) and not (p.parent/name).resolve().exists():errors.append(f'Missing import {p}: {name}')
 # Delimiter smoke check; not a Dart parser or compiler.
 s=re.sub(r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"",'""',source)
 s=re.sub(r'//[^\n]*','',s);stack=[];pairs={')':'(',']':'[','}':'{'}
 for i,c in enumerate(s):
  if c in '([{':stack.append((c,i))
  elif c in ')]}':
   if not stack or stack.pop()[0]!=pairs[c]:errors.append(f'Mismatched delimiter {p}:{s[:i].count(chr(10))+1}');break
 else:
  if stack:errors.append(f'Unclosed delimiter {p}')
 if re.search(r'onPressed:\s*\(\)\s*\{\s*\}',source):errors.append(f'Empty action {p}')
print('Errors:',len(errors))
for e in errors:print(e)
print('Screen files:',len(list((root/'lib/features').rglob('*_page.dart'))))
raise SystemExit(bool(errors))
