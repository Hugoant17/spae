import { PDFDocument, StandardFonts, rgb } from 'npm:pdf-lib@1.17.1';
import { certificateTemplate } from './certificate_template.ts';
import { regularGlyphs, boldGlyphs, italicGlyphs } from './certificate_glyphs.ts';

const bytes = (data:string) => Uint8Array.from(atob(data), ch => ch.charCodeAt(0));
const normalize = (value:any) => String(value ?? '')
  .replace(/[\u201c\u201d]/g, '"').replace(/[\u2018\u2019]/g, "'")
  .replace(/[\u2013\u2014]/g, '-').replace(/[^\x20-\x7E\xA0-\xFF]/g, ' ')
  .replace(/\s+/g, ' ').trim();

// El PNG suministrado conserva el logo, la tipografía institucional, los adornos
// y las firmas. Las zonas que contienen datos del ejemplo se cubren antes de
// dibujar los valores reales de cada participante.
export async function renderCertificate(c:any):Promise<Uint8Array> {
 const pdf=await PDFDocument.create();
 const page=pdf.addPage([842,590]);
 const original=await pdf.embedPng(bytes(certificateTemplate));
 page.drawImage(original,{x:0,y:0,width:842,height:590});
 const white=rgb(1,1,1), ink=rgb(.13,.13,.14), blue=rgb(29/255,102/255,154/255);
 type GlyphFont={units:number,glyphs:Record<string,{a:number,p:string}>};
 const regular:GlyphFont=regularGlyphs,bold:GlyphFont=boldGlyphs,italic:GlyphFont=italicGlyphs;
 const width=(value:string,size:number,font:GlyphFont)=>[...value].reduce((sum,ch)=>sum+(font.glyphs[ch]?.a??font.glyphs['?'].a)*size/font.units,0);
 const draw=(value:string,x:number,y:number,size:number,font:GlyphFont,color=ink)=>{
  for(const ch of value){
   const glyph=font.glyphs[ch]??font.glyphs['?'];
   if(glyph.p)page.drawSvgPath(glyph.p,{x,y,scale:size/font.units,color});
   x+=glyph.a*size/font.units;
  }
 };

 // Nombre y párrafo de la muestra, sin alterar el logo ni las firmas.
 page.drawRectangle({x:145,y:244,width:553,height:56,color:white});
 page.drawRectangle({x:128,y:145,width:608,height:101,color:white});

 const rawPerson=normalize(c.snapshot?.full_name);
 if(!rawPerson)throw new Error('El certificado no tiene nombre de participante');
 const person=/^Lic\.?\s/i.test(rawPerson)?rawPerson:`Lic. ${rawPerson}`;
 const nameSize=Math.min(34,660/Math.max(width(person,1,italic),1));
 draw(person,(842-width(person,nameSize,italic))/2,258,nameSize,italic);

 const title=normalize(c.snapshot?.training);
 if(!title)throw new Error('El certificado no tiene capacitación');
 const rawTrainingDate=normalize(c.snapshot?.training_date||c.issued_at);
 let date:Date;
 // YYYY-MM-DD representa un día civil, no un instante UTC. Se fija al mediodía
 // UTC para impedir que America/Lima retroceda al día anterior (23 -> 22).
 const civil=rawTrainingDate.match(/^(\d{4})-(\d{2})-(\d{2})$/);
 if(civil){
  date=new Date(Date.UTC(Number(civil[1]),Number(civil[2])-1,Number(civil[3]),12));
 }else{
  date=new Date(rawTrainingDate);
 }
 if(Number.isNaN(date.getTime()))throw new Error('La fecha de capacitación no es válida');
 const dateText=new Intl.DateTimeFormat('es-PE',{day:'numeric',month:'long',year:'numeric',timeZone:'America/Lima'}).format(date);
 const hours=Number(c.snapshot?.hours);
 const hoursText=Number.isFinite(hours)?String(hours).padStart(2,'0'):normalize(c.snapshot?.hours);

 const segments=[
  {text:'Por su participación en calidad de ',font:regular},
  {text:'asistente',font:bold},
  {text:' en la ',font:regular},
  {text:title.replace(/[,\s]+$/, '')+',',font:bold},
  {text:` realizado el día ${dateText}, con una duración de ${hoursText} horas académicas`,font:regular},
 ];
 type Token={text:string,font:GlyphFont};
 const tokens:Token[]=[];
 for(const segment of segments)for(const word of segment.text.trim().split(/\s+/)){
  if(word)tokens.push({text:word,font:segment.font});
 }
 const layout=(size:number)=>{
  const lines:Token[][]=[];let line:Token[]=[],lineWidth=0;
  for(const token of tokens){
   const space=line.length?width(' ',size,token.font):0;
   const next=width(token.text,size,token.font)+space;
   if(line.length&&lineWidth+next>581){lines.push(line);line=[];lineWidth=0;}
   if(line.length){line.push({text:' ',font:token.font});lineWidth+=space;}
   line.push(token);lineWidth+=width(token.text,size,token.font);
  }
  if(line.length)lines.push(line);
  return lines;
 };
 let textSize=17;let lines=layout(textSize);
 while(lines.length>4&&textSize>11){textSize-=.5;lines=layout(textSize);}
 if(lines.length>4)throw new Error('El nombre de la capacitación es demasiado largo para el certificado');
 const firstBaseline=lines.length<=3?221:227;
 for(let i=0;i<lines.length;i++){
  const line=lines[i];const lineWidth=line.reduce((sum,run)=>sum+width(run.text,textSize,run.font),0);
  let x=(842-lineWidth)/2;
  for(const run of line){draw(run.text,x,firstBaseline-i*20,textSize,run.font);x+=width(run.text,textSize,run.font);}
 }

 // Sustituye el registro de muestra; el número de resolución permanece igual.
 // Un pequeño panel azul cubre el texto anterior dentro de la esquina azul.
 page.drawSvgPath('M 40 0 L 177 0 L 177 46 L 0 46 Z',{x:665,y:46,color:blue});
 const registry=normalize(c.certificate_number);
 const first=`Registro N° ${registry}`;
 const second='Resolución N° 105-CDN-SPAE-2026';
 for(const [text,y] of [[first,26],[second,11]] as const){
  const left=y===26?705:690;
  const size=Math.min(8.8,(835-left)/Math.max(width(text,1,bold),1));
  draw(text,835-width(text,size,bold),y,size,bold,white);
 }
 // Mantiene el texto variable accesible para búsqueda y copia sin alterar el dibujo.
 const searchable=await pdf.embedFont(StandardFonts.Helvetica);
 page.drawText(person,{x:220,y:258,size:10,font:searchable,opacity:0});
 page.drawText(`${title}. ${dateText}. ${hoursText} horas académicas`,{x:160,y:172,size:8,font:searchable,opacity:0});
 page.drawText(registry,{x:700,y:14,size:8,font:searchable,opacity:0});
 pdf.setTitle(`Certificado SPAE ${registry}`);
 return pdf.save();
}
