/**
 * Exporta o secrets.env já preenchido com os valores acessíveis ao runtime.
 * Protegido pela mesma credencial administrativa do /admincentral.
 * Valores mascarados pela plataforma são listados para preenchimento manual.
 */


const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const REQUIRED: readonly { name: string; source: string }[] = [
  { name: "BRIGHTDATA_API_TOKEN", source: "painel Bright Data" },
  { name: "BRIGHTDATA_WEB_UNLOCKER_ZONE", source: "zona Web Unlocker da Bright Data" },
  { name: "DEEPSEEK_API_KEY", source: "painel DeepSeek" },
  { name: "FACEBOOK_APP_ID", source: "app da Meta" },
  { name: "FACEBOOK_APP_SECRET", source: "app da Meta" },
  { name: "GOOGLE_CLIENT_ID", source: "credencial OAuth do Google" },
  { name: "GOOGLE_CLIENT_SECRET", source: "credencial OAuth do Google" },
  { name: "GOOGLE_OAUTH_CLIENT_SECRET", source: "usar o mesmo secret OAuth do Google, se essa variável estiver ativa" },
  { name: "INFINITEPAY_API_KEY", source: "painel InfinitePay" },
  { name: "INFINITEPAY_WEBHOOK_SECRET", source: "configuração do webhook InfinitePay" },
  { name: "INSTAGRAM_SESSION_ID", source: "sessão da integração Instagram" },
  { name: "LOVABLE_API_KEY", source: "substituir por um provedor de IA disponível fora do Lovable Cloud" },
  { name: "META_CONVERSIONS_API_TOKEN", source: "Gerenciador de Eventos da Meta" },
  { name: "META_WEBHOOK_VERIFY_TOKEN", source: "usar exatamente o mesmo token configurado no webhook da Meta" },
  { name: "OPENAI_API_KEY", source: "painel OpenAI, caso as rotas de transcrição/IA continuem ativas" },
  { name: "RAPIDAPI_KEY", source: "painel RapidAPI" },
  { name: "SMTP_PASSWORD", source: "provedor SMTP correspondente" },
  { name: "STRIPE_SECRET_KEY", source: "painel Stripe, caso os produtos Stripe continuem ativos" },
  { name: "WPP_BOT_TOKEN", source: "provedor do bot WhatsApp" },
  { name: "ZAPMRO_SMTP_PASSWORD", source: "provedor de e-mail do ZapMRO" },
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
  "ADMIN_JWT_SECRET",
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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") return json({ error: "Método não permitido" }, 405);

    const lines = REQUIRED.flatMap(({ name, source }) => [
      `# Obter em: ${source}`,
      `${name}=`,
    ]);

    const header = [
      "# ============================================================",
      "# secrets.env — modelo seguro para a VPS",
      `# Data: ${new Date().toISOString()}`,
      "#",
      "# Preencha diretamente na VPS; não envie os valores por chat.",
      "# Depois use chmod 600 e NUNCA versione este arquivo no git.",
      "#",
      "# Uso: deploy/postgres-stack/secrets.env",
      "# ============================================================",
      "",
    ].join("\n");

    const footer = [
      "",
      "APP_BASE_URL='https://zapmro.com.br'",
      "SITE_URL='https://zapmro.com.br'",
      "",
      "# ------------------------------------------------------------",
      "# Gerados automaticamente pela stack própria (NÃO copie os antigos):",
      ...REGENERATED.map((n) => `#   ${n}`),
      "# ------------------------------------------------------------",
      "",
    ].join("\n");

    return json({
      success: true,
      content: header + lines.join("\n") + footer,
      found: [],
      missing: REQUIRED.map(({ name }) => name),
      notice: "Os valores criptografados não podem ser recuperados pelo runtime; o arquivo gerado é um modelo para preenchimento seguro na VPS.",
    });
  } catch (err) {
    console.error("[export-secrets] erro:", err);
    return json({ error: "Erro interno" }, 500);
  }
});
