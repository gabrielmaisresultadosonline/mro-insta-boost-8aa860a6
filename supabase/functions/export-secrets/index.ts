import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.2";

/**
 * export-secrets — exportador ÚNICO e protegido dos valores dos secrets.
 *
 * Regras de segurança aplicadas:
 *  - exige a senha de admin (mesma fonte usada por verify-admin-password);
 *  - responde apenas via POST com JSON;
 *  - nunca loga valores; apenas nomes e contagem;
 *  - a resposta é no-store (não fica em cache de proxy/browser).
 *
 * Após colar o conteúdo no VPS, remova esta função do projeto.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/** Secrets que fazem sentido migrar para a stack própria. */
const EXPORTABLE: readonly string[] = [
  "BRIGHTDATA_API_TOKEN",
  "BRIGHTDATA_WEB_UNLOCKER_ZONE",
  "DEEPSEEK_API_KEY",
  "FACEBOOK_APP_ID",
  "FACEBOOK_APP_SECRET",
  "GOOGLE_CLIENT_ID",
  "GOOGLE_CLIENT_SECRET",
  "INSTAGRAM_SESSION_ID",
  "LOVABLE_API_KEY",
  "META_CONVERSIONS_API_TOKEN",
  "RAPIDAPI_KEY",
  "SMTP_PASSWORD",
  "WPP_BOT_TOKEN",
  "ZAPMRO_SMTP_PASSWORD",
];

/**
 * Secrets gerados pela própria stack no VPS — exportados apenas como comentário
 * para evitar que alguém reaproveite chaves do ambiente antigo por engano.
 */
const REGENERATED: readonly string[] = [
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "SUPABASE_DB_URL",
  "SUPABASE_JWKS",
  "SUPABASE_PUBLISHABLE_KEYS",
  "SUPABASE_SECRET_KEYS",
];

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

/** Escapa valor para formato dotenv (aspas simples preservam tudo, menos aspas simples). */
function toEnvLine(name: string, value: string): string {
  const safe = value.replace(/'/g, `'"'"'`);
  return `${name}='${safe}'`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const raw = await req.text();
    let password = "";
    try {
      password = String(JSON.parse(raw || "{}")?.password ?? "").trim();
    } catch {
      password = "";
    }

    if (!password || password.length > 100) {
      return json({ error: "Senha obrigatória" }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const { data, error } = await supabase
      .from("license_settings")
      .select("admin_password")
      .limit(1)
      .single();

    if (error || !data) {
      return json({ error: "Configuração de admin não encontrada" }, 500);
    }

    if (password !== String(data.admin_password).trim()) {
      console.warn("[export-secrets] tentativa com senha inválida");
      return json({ error: "Senha incorreta" }, 401);
    }

    const found: string[] = [];
    const missing: string[] = [];
    const lines: string[] = [];

    for (const name of EXPORTABLE) {
      const value = Deno.env.get(name);
      if (value && value.length > 0) {
        found.push(name);
        lines.push(toEnvLine(name, value));
      } else {
        missing.push(name);
        lines.push(`# ${name}= (não configurado neste ambiente)`);
      }
    }

    const header = [
      "# ============================================================",
      "# secrets.env — gerado automaticamente pelo exportador do painel",
      `# Data: ${new Date().toISOString()}`,
      "#",
      "# ATENÇÃO: este arquivo contém credenciais em texto puro.",
      "# Guarde com chmod 600 e NUNCA versione no git.",
      "#",
      "# Uso: deploy/postgres-stack/secrets.env",
      "# ============================================================",
      "",
    ].join("\n");

    const footer = [
      "",
      "APP_BASE_URL='https://zapmro.com.br'",
      "",
      "# ------------------------------------------------------------",
      "# Gerados automaticamente pela stack própria (NÃO copie os antigos):",
      ...REGENERATED.map((n) => `#   ${n}`),
      "# ------------------------------------------------------------",
      "",
    ].join("\n");

    console.log(
      `[export-secrets] exportados=${found.length} ausentes=${missing.length}`,
    );

    return json({
      success: true,
      content: header + lines.join("\n") + footer,
      found,
      missing,
    });
  } catch (err) {
    console.error("[export-secrets] erro:", err);
    return json({ error: "Erro interno" }, 500);
  }
});
