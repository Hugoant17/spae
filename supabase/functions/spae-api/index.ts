import { createClient } from 'npm:@supabase/supabase-js@2.49.8';
import { renderCertificate } from './certificate.ts';
const url = Deno.env.get('SUPABASE_URL')!;
const admin = createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,x-client-info,apikey,content-type','Access-Control-Allow-Methods':'POST,OPTIONS'};
const respond=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...cors,'Content-Type':'application/json'}});
function must<T>(response:{data:T,error:any}):T {if(response.error) throw new Error(response.error.message); return response.data;}
async function hash(text:string) {return [...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text)))].map(x=>x.toString(16).padStart(2,'0')).join('');}
function randomCode(){const alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';return Array.from(crypto.getRandomValues(new Uint8Array(16)),b=>alphabet[b&31]).join('');}
function fileBytes(p:any):{bytes:Uint8Array,mime:string,ext:string} {
 if(typeof p.file_base64!=='string'||p.file_base64.length>7100000) throw new Error('Comprobante máximo 5 MB');
 const bytes=Uint8Array.from(atob(p.file_base64),c=>c.charCodeAt(0));
 let mime='',ext='';
 if(bytes[0]===0x25&&bytes[1]===0x50&&bytes[2]===0x44&&bytes[3]===0x46){mime='application/pdf';ext='pdf';}
 else if(bytes[0]===0xff&&bytes[1]===0xd8&&bytes[2]===0xff){mime='image/jpeg';ext='jpg';}
 else if(bytes[0]===137&&bytes[1]===80&&bytes[2]===78&&bytes[3]===71){mime='image/png';ext='png';}
 else throw new Error('Solo se admiten PDF, JPG o PNG válidos');
 if(!bytes.length||bytes.length>5*1024*1024) throw new Error('Comprobante máximo 5 MB');
 return {bytes,mime,ext};
}
async function receipt(p:any,prefix:string){
 const {bytes,mime,ext}=fileBytes(p);
 const cfg=must(await admin.rpc('spae_public_settings'));
 if(bytes.length>Number(cfg.receipt_max_mb||5)*1024*1024) throw new Error('El archivo excede el límite configurado');
 const path=`${prefix}/${crypto.randomUUID()}.${ext}`;
 must(await admin.storage.from('payment-receipts').upload(path,bytes,{contentType:mime}));
 return path;
}
async function makeCertificate(c:any){
 const path=`v7/${c.id}.pdf`;
 if(c.pdf_path===path) return path;
 must(await admin.storage.from('certificates').upload(path,await renderCertificate(c),{contentType:'application/pdf',upsert:true}));
 must(await admin.from('certificates').update({pdf_path:path}).eq('id',c.id));return path;
}
async function removeReceiptFiles(paths:string[]){
 const unique=[...new Set(paths.filter(Boolean))];
 if(!unique.length)return;
 const removed=await admin.storage.from('payment-receipts').remove(unique);
 if(removed.error)console.error('No se pudieron depurar comprobantes:',removed.error.message);
}
Deno.serve(async(req)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return respond({error:'Método no permitido'},405);
 try{
  // Limitar el tamaño antes de procesar JSON; no depender de Content-Length.
  const reader=req.body?.getReader(); if(!reader) return respond({error:'Cuerpo vacío'},400);
  let size=0;const chunks:Uint8Array[]=[];
  while(true){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>7300000){await reader.cancel();return respond({error:'Solicitud demasiado grande'},413);}chunks.push(value);}
  const all=new Uint8Array(size);let offset=0;for(const c of chunks){all.set(c,offset);offset+=c.length;}
  const body=JSON.parse(new TextDecoder().decode(all)); const action=body.action; const p=body.payload||{};
  const ip=req.headers.get('x-forwarded-for')?.split(',')[0]||'unknown';
  if(!must(await admin.rpc('spae_rate_limit',{p_key:await hash(ip+':'+String(action))})))return respond({error:'Demasiadas solicitudes. Espera 10 minutos.'},429);
  if(action==='enroll'){
   if(p.previous_code && (typeof p.previous_code!=='string'||p.previous_code.length<10))throw new Error('El código anterior debe tener al menos 10 caracteres. Déjalo vacío si es tu primera inscripción.');

   const path=await receipt(p,'public');
   try{
    const code=p.previous_code||randomCode();
    const values={...p,lookup_hash:await hash(code),receipt_path:path};delete values.file_base64;delete values._member_id;
    const result=must(await admin.rpc('spae_public_enroll',{p:values}));
    return respond({...result,private_code:code});
   }catch(e){await admin.storage.from('payment-receipts').remove([path]);throw e;}
  }
  if(action==='lookup'){
   const rows=must(await admin.rpc('spae_public_history',{p_term:String(p.term||''),p_code:String(p.code||'')}));
   return respond(rows);
  }
  if(action==='resubmit'){
   const rows=must(await admin.rpc('spae_public_history',{p_term:String(p.term||''),p_code:String(p.code||'')}));
   if(!rows.some((x:any)=>x.id===p.id&&x.status==='rejected'))return respond({error:'Inscripción no disponible'},404);
   const path=await receipt(p,'public');
   try{return respond(must(await admin.rpc('spae_resubmit',{p:{id:p.id,operation_number:p.operation_number,receipt_path:path}})));}
   catch(e){await admin.storage.from('payment-receipts').remove([path]);throw e;}
  }
  if(action==='public_certificate'){
   const rows=must(await admin.rpc('spae_public_history',{p_term:String(p.term||''),p_code:String(p.code||'')}));
   const row=rows.find((x:any)=>x.id===p.id&&x.certificate_number);
   if(!row)return respond({error:'Documento no disponible'},404);
   const c=must(await admin.from('certificates').select().eq('enrollment_id',row.id).single());
   const path=await makeCertificate(c);
   return respond(must(await admin.storage.from('certificates').createSignedUrl(path,120)));
  }
  const token=req.headers.get('Authorization')?.replace(/^Bearer /i,'');
  if(!token)return respond({error:'Inicia sesión'},401);
  const user=must(await admin.auth.getUser(token)).user;
  if(!user)return respond({error:'Sesión no válida'},401);
  const profile=must(await admin.from('profiles').select().eq('id',user.id).single());
  if(!profile.enabled)return respond({error:'Cuenta desactivada'},403);
  const client=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false}});
  if(action==='health')return respond({version:'2026-09-27.2',ok:true});
  if(action==='review_member'){
   if(!['administrator','assistant'].includes(profile.role))return respond({error:'Solo personal autorizado'},403);
   must(await client.rpc('spae_review_member',{p_id:p.id,p_status:p.status,p_reason:p.reason??null}));
   if(p.status==='rejected'){
    const deleted=await admin.auth.admin.deleteUser(p.id);
    if(deleted.error)throw new Error(deleted.error.message);
   }
   return respond({ok:true,removed:p.status==='rejected'});
  }
  if(action==='review_enrollment'){
   if(!['administrator','assistant'].includes(profile.role))return respond({error:'Solo personal autorizado'},403);
   return respond(must(await client.rpc('spae_review_enrollment_v2',{p_id:p.id,p_status:p.status,p_reason:p.reason??null})));
  }
  if(action==='participant_delete'){
   if(!['administrator','assistant'].includes(profile.role))return respond({error:'Solo personal autorizado'},403);
   return respond(must(await client.rpc('spae_delete_participant',{p_id:p.id})));
  }

  if(action==='member_state'){
   if(!['administrator','assistant'].includes(profile.role))return respond({error:'Solo personal autorizado'},403);
   return respond(must(await client.rpc('spae_member_state',{p_id:p.id,p_enabled:p.enabled})));
  }
  if(action==='member_delete'){
   if(!['administrator','assistant'].includes(profile.role))return respond({error:'Solo personal autorizado'},403);
   const target=must(await admin.from('profiles').select('id,full_name,role').eq('id',p.id).single());
   if(target.role!=='member')throw new Error('La cuenta seleccionada no es de miembro');
   const participant=must(await admin.from('participants').select('id').eq('profile_id',target.id).maybeSingle());
   if(participant){
    const history=await admin.from('enrollments').select('id',{count:'exact',head:true}).eq('participant_id',participant.id);
    if(history.error)throw new Error(history.error.message);
    if((history.count??0)>0)throw new Error('Este miembro tiene historial de inscripciones. Usa «Inactivar cuenta» para conservar sus registros.');

   }
   must(await admin.from('audit_logs').insert({actor_id:user.id,action:'member_delete_requested',entity:'profiles',entity_id:target.id,details:{full_name:target.full_name}}));
   const deleted=await admin.auth.admin.deleteUser(target.id);
   if(deleted.error)throw new Error(deleted.error.message);

   const audit=await admin.from('audit_logs').insert({actor_id:user.id,action:'member_delete',entity:'profiles',entity_id:target.id,details:{full_name:target.full_name}});
   if(audit.error)console.error('Cuenta eliminada; auditoría final no disponible:',audit.error.message);
   return respond({ok:true});
  }
  if(action==='member_enroll'){
   if(profile.role!=='member'||profile.registration_status!=='approved')throw new Error('Tu solicitud de miembro debe ser aprobada por la asistente');
   if(!user.email_confirmed_at)throw new Error('Confirma tu correo antes de inscribirte');
   let memberDni=String(profile.dni||'').trim();
   if(!memberDni){
    const entered=String(p.dni||'').trim();
    if(!/^\d{8}$/.test(entered))throw new Error('Completa tu DNI de 8 dígitos');
    const duplicate=must(await admin.from('profiles').select('id').eq('dni',entered).neq('id',user.id).maybeSingle());
    if(duplicate)throw new Error('El DNI ya está registrado en otra cuenta');
    must(await admin.from('profiles').update({dni:entered,updated_at:new Date().toISOString()}).eq('id',user.id));
    memberDni=entered;
   }
   const free=p.wants_certificate===false;
   const path=free?null:await receipt(p,user.id);
   try{
    const code=randomCode();
    const values={...p,file_base64:undefined,_member_id:user.id,dni:memberDni,email:profile.email,lookup_hash:await hash(code),receipt_path:path};
    const result=must(await admin.rpc('spae_public_enroll',{p:values}));
    return respond(result);
   }catch(e){if(path)await admin.storage.from('payment-receipts').remove([path]);throw e;}
  }
  if(action==='upload_flyer'){
   if(profile.role!=='administrator')return respond({error:'Solo administrador'},403);
   const {bytes,mime,ext}=fileBytes(p);
   if(mime==='application/pdf'||bytes.length>3*1024*1024)throw new Error('El flyer debe ser JPG o PNG de hasta 3 MB');
   const path=`flyers/${crypto.randomUUID()}.${ext}`;
   must(await admin.storage.from('training-flyers').upload(path,bytes,{contentType:mime}));
   return respond({url:admin.storage.from('training-flyers').getPublicUrl(path).data.publicUrl});
  }
  if(action==='recover_code'){
   const code=randomCode();must(await client.rpc('spae_action',{p_action:'recover_code',p:{id:p.id,code}}));return respond({code});
  }
  if(action==='membership_payment'){
   const path=await receipt(p,user.id);
   try{return respond(must(await client.rpc('spae_action',{p_action:'submit_membership',p:{...p,file_base64:undefined,receipt_path:path}})));}
   catch(e){await admin.storage.from('payment-receipts').remove([path]);throw e;}
  }
  if(action==='bulk_certificates'){
   if(!['administrator','assistant'].includes(profile.role))return respond({error:'Solo personal autorizado'},403);
   if(!Array.isArray(p.ids)||p.ids.length<1||p.ids.length>20)throw new Error('Selecciona entre 1 y 20 registros por lote');
   const rows=must(await client.rpc('spae_data',{p_scope:'certificates'}));
   const results=[];
   for(const id of [...new Set(p.ids)]){
    const row=rows.find((r:any)=>r.id===id);
    try{
     if(!row)throw new Error('Inscripción no disponible');
     const c=must(await client.rpc('spae_issue_certificate_v2',{p_id:id}));
     await makeCertificate(c);results.push({id,name:row.full_name,ok:true});
    }catch(e){results.push({id,name:row?.full_name,ok:false,error:e instanceof Error?e.message:'Error al emitir'});}
   }
   return respond({results});
  }
  if(action==='certificate'||action==='issue_certificate'){
   if(action==='issue_certificate')must(await client.rpc('spae_issue_certificate_v2',{p_id:p.id}));
   const rows=must(await client.rpc('spae_data',{p_scope:'certificates'}));
   if(!rows.some((x:any)=>x.id===p.id&&x.certificate_number))return respond({error:'Documento no disponible'},404);
   const c=must(await admin.from('certificates').select().eq('enrollment_id',p.id).single());
   const path=await makeCertificate(c);
   return respond(must(await admin.storage.from('certificates').createSignedUrl(path,120)));
  }
  if(action==='receipt'){
   const path=String(p.path||'');
   let allowed=profile.role==='assistant'||profile.role==='administrator';
   if(!allowed){const data=must(await client.rpc('spae_data',{p_scope:'memberships'}));allowed=data.some((m:any)=>m.payments.some((pay:any)=>pay.receipt_path===path));}
   if(!allowed){const data=must(await client.rpc('spae_data',{p_scope:'enrollments'}));allowed=data.some((e:any)=>e.receipt_path===path);}
   if(!allowed)return respond({error:'Acceso denegado'},403);
   return respond(must(await admin.storage.from('payment-receipts').createSignedUrl(path,120)));
  }
  if(action==='assistant_save'||action==='assistant_delete'){
   if(profile.role!=='administrator')return respond({error:'Solo administrador'},403);
   if(p.id){const target=must(await admin.from('profiles').select('role').eq('id',p.id).single());if(target.role!=='assistant')return respond({error:'Solo se gestionan asistentes'},403);}
   if(action==='assistant_delete'){
    if(!p.id)throw new Error('Selecciona una cuenta');
    // FK conservan la trazabilidad. Si hay actividad, se debe desactivar.
    must(await admin.auth.admin.deleteUser(p.id));return respond({ok:true});
   }
   if(!p.full_name||!p.email)throw new Error('Nombre y correo obligatorios');
   if(p.password&&String(p.password).length<10)throw new Error('Contraseña mínima de 10 caracteres');
   let id=p.id;
   if(!id){
    if(!p.password)throw new Error('Contraseña inicial obligatoria');
    id=must(await admin.auth.admin.createUser({email:p.email,password:p.password,email_confirm:true,user_metadata:{full_name:p.full_name}})).user.id;
    try {must(await admin.from('profiles').update({role:'assistant',full_name:p.full_name,enabled:true}).eq('id',id));}
    catch(e){await admin.auth.admin.deleteUser(id);throw e;}
   }else{
    must(await admin.auth.admin.updateUserById(id,{email:p.email,...(p.password?{password:p.password}:{}),user_metadata:{full_name:p.full_name}}));
    must(await admin.from('profiles').update({full_name:p.full_name,email:p.email}).eq('id',id));
   }
   must(await admin.from('audit_logs').insert({actor_id:user.id,action,entity:'profiles',entity_id:id,details:{email:p.email}}));
   return respond({id});
  }
  return respond({error:'Acción no admitida'},400);
 }catch(e){return respond({error:e instanceof Error?e.message:'Error de servidor'},400);}
});
