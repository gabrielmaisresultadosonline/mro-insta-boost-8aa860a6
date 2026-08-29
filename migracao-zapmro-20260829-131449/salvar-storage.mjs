// salvar-storage.mjs — baixa TODOS os binários do Storage (origem) para pastas locais.
// Uso:  ORIGEM_URL=... ORIGEM_KEY=<service_role> node salvar-storage.mjs
import { createClient } from "@supabase/supabase-js";
const url = process.env.ORIGEM_URL, key = process.env.ORIGEM_KEY;
if (!url || !key) { console.error("defina ORIGEM_URL e ORIGEM_KEY (service_role)"); process.exit(1); }
const c = createClient(url, key, { auth: { persistSession: false } });
const BUCKETS = ["assets","crm-media","inteligencia-fotos","metodo-seguidor-backup",
  "metodo-seguidor-content","profile-cache","trial-screenshots","user-data"];
async function listAll(bucket, prefix="") {
  const out=[]; let off=0;
  for(;;){ const {data,error}=await c.storage.from(bucket).list(prefix,{limit:1000,offset:off});
    if(error)throw error; if(!data||!data.length)break;
    for(const it of data){ const p=prefix?`${prefix}/${it.name}`:it.name;
      if(it.id===null) out.push(...await listAll(bucket,p)); else out.push(p); }
    if(data.length<1000)break; off+=data.length; }
  return out;
}
let totOk=0,totFail=0;
for(const b of BUCKETS){
  console.log(`\n=== ${b} ===`);
  let files=[]; try{ files=await listAll(b);}catch(e){ console.error(`list ${b}:`,e.message); continue; }
  console.log(`${files.length} arquivos`);
  let ok=0,fail=0;
  for(const path of files){
    try{ const {data,error}=await c.storage.from(b).download(path); if(error)throw error;
      const buf=Buffer.from(await data.arrayBuffer());
      const fs=await import("fs/promises"),p=require("path");
      const dest=p.join("06_storage",b,path); await fs.mkdir(p.dirname(dest),{recursive:true});
      await fs.writeFile(dest,buf); ok++;
      if(ok%50===0)console.log(`  ${ok}/${files.length}`); }
    catch(e){ fail++; console.error(`  FALHA ${b}/${path}: ${e.message}`); }
  }
  totOk+=ok; totFail+=fail;
}
console.log(`\nTOTAL: ${totOk} baixados, ${totFail} falhas -> ./06_storage/`);
