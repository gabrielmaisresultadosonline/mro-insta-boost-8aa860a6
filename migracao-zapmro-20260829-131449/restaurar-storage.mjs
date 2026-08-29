// restaurar-storage.mjs — sobe os binários da pasta ./06_storage para o Storage de destino.
// Uso:  DESTINO_URL=... DESTINO_KEY=<service_role> node restaurar-storage.mjs
import { createClient } from "@supabase/supabase-js";
import { readdir, readFile, stat } from "fs/promises"; import { join, dirname } from "path";
const url=process.env.DESTINO_URL, key=process.env.DESTINO_KEY;
if(!url||!key){ console.error("defina DESTINO_URL e DESTINO_KEY (service_role)"); process.exit(1); }
const c=createClient(url,key,{auth:{persistSession:false}});
const BUCKETS=["assets","crm-media","inteligencia-fotos","metodo-seguidor-backup",
  "metodo-seguidor-content","profile-cache","trial-screenshots","user-data"];
let ok=0,fail=0;
for(const b of BUCKETS){
  const dir=join("06_storage",b); let root;
  try{ root=await readdir(dir);}catch{ console.log(`${b}: sem pasta, pulando`); continue; }
  console.log(`\n=== ${b} ===`);
  async function walk(d){ const ents=await readdir(d,{withFileTypes:true});
    for(const e of ents){ const full=join(d,e.name);
      if(e.isDirectory()) await walk(full); else {
        const rel=full.slice(dir.length+1).split("/"); // path relativo dentro do bucket
        const buf=await readFile(full);
        const {error}=await c.storage.from(b).upload(rel.join("/"),buf,{upsert:true});
        if(error){fail++;console.error(`  FALHA ${b}/${rel.join("/")}: ${error.message}`);}
        else{ok++; if(ok%50===0)console.log(`  ${ok} enviados`);} } } }
  await walk(dir).catch(e=>console.error(`walk ${b}:`,e.message));
}
console.log(`\nTOTAL: ${ok} enviados, ${fail} falhas`);
