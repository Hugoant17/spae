import {PGlite} from '@electric-sql/pglite';
import {pgcrypto} from '@electric-sql/pglite/contrib/pgcrypto';
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
const db=new PGlite({extensions:{pgcrypto}});
const base=fileURLToPath(new URL('../',import.meta.url));
const files=['tests/postgres_fixture.sql','supabase/schema.sql',...fs.readdirSync(base+'supabase/migrations').sort().map(n=>'supabase/migrations/'+n),'tests/backend_smoke.sql','tests/participant_actions.sql','tests/three_roles.sql'];
for(const f of files){try{await db.exec(fs.readFileSync(base+f,'utf8'));console.log('PASS '+f);}catch(e){console.error('FAIL '+f+': '+e.message); console.error(e.where??'');process.exitCode=1;break;}}
await db.close();
