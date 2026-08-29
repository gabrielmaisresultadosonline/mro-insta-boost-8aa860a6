// Copia os arquivos do Storage da nuvem para a stack local (idempotente/upsert).
// Lista via edge function exportar-storage-vps; baixa por URL pública da nuvem.

const CLOUD = process.env.CLOUD_URL.replace(/\/$/, "");
const ANON = process.env.CLOUD_ANON;
const ADMIN = process.env.ADMIN_PASSWORD;
const LOCAL = process.env.LOCAL_URL.replace(/\/$/, "");
const KEY = process.env.LOCAL_SERVICE_KEY;
const CONC = Number(process.env.CONCURRENCY || 8);

const FN = `${CLOUD}/functions/v1/exportar-storage-vps`;
const localHeaders = { Authorization: `Bearer ${KEY}`, apikey: KEY };

async function callFn(payload) {
  const r = await fetch(FN, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${ANON}`,
      apikey: ANON,
    },
    body: JSON.stringify({ adminPassword: ADMIN, ...payload }),
  });
  const json = await r.json();
  if (json.error) throw new Error(json.error);
  return json;
}

async function listAll(bucket, prefix = "") {
  const out = [];
  let offset = 0;
  for (;;) {
    const { items, done } = await callFn({ action: "objects", bucket, prefix, offset, limit: 1000 });
    for (const it of items) {
      const path = prefix ? `${prefix}/${it.name}` : it.name;
      if (it.isFolder) out.push(...(await listAll(bucket, path)));
      else out.push(path);
    }
    if (done) break;
    offset += 1000;
  }
  return out;
}

async function ensureBucket(b) {
  const r = await fetch(`${LOCAL}/storage/v1/bucket`, {
    method: "POST",
    headers: { ...localHeaders, "Content-Type": "application/json" },
    body: JSON.stringify({
      id: b.id ?? b.name,
      name: b.name,
      public: !!b.public,
      file_size_limit: b.file_size_limit ?? null,
      allowed_mime_types: b.allowed_mime_types ?? null,
    }),
  });
  if (!r.ok && r.status !== 409) console.log(`  bucket ${b.name}: HTTP ${r.status}`);
}

async function pool(items, worker) {
  let i = 0, done = 0, fail = 0;
  await Promise.all(
    Array.from({ length: CONC }, async () => {
      while (i < items.length) {
        const item = items[i++];
        try {
          await worker(item);
        } catch (e) {
          fail++;
          console.error(`  erro: ${item} — ${e.message}`);
        }
        if (++done % 100 === 0) console.log(`  ${done}/${items.length}`);
      }
    }),
  );
  return { done, fail };
}

const { buckets } = await callFn({ action: "buckets" });
console.log(`buckets na nuvem: ${buckets.map((b) => b.name).join(", ")}`);

let totalOk = 0, totalFail = 0;
for (const b of buckets) {
  await ensureBucket(b);
  const files = await listAll(b.name);
  console.log(`${b.name}: ${files.length} arquivos`);
  const { done, fail } = await pool(files, async (path) => {
    const src = await fetch(`${CLOUD}/storage/v1/object/public/${b.name}/${encodeURI(path)}`, {
      headers: { Authorization: `Bearer ${ANON}`, apikey: ANON },
    });
    if (!src.ok) throw new Error(`download HTTP ${src.status}`);
    const buf = Buffer.from(await src.arrayBuffer());
    const contentType = src.headers.get("content-type") || "application/octet-stream";
    const up = await fetch(`${LOCAL}/storage/v1/object/${b.name}/${encodeURI(path)}`, {
      method: "POST",
      headers: { ...localHeaders, "x-upsert": "true", "Content-Type": contentType },
      body: buf,
    });
    if (!up.ok && up.status !== 409) throw new Error(`upload HTTP ${up.status}`);
  });
  totalOk += done - fail;
  totalFail += fail;
}
console.log(`\nconcluído — ${totalOk} arquivos ok, ${totalFail} falhas`);
