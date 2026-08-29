const PUBLIC_STORAGE_OBJECT_PATH = /^\/storage\/v1\/object\/public\/(.+)$/i;

/**
 * Mantém URLs externas intactas, mas redireciona objetos do Storage antigo
 * para o Storage configurado atualmente no frontend (VPS em produção).
 */
export function resolveMediaUrl(value: unknown): string {
  if (typeof value !== "string") return "";

  const url = value.trim();
  if (!url || url.startsWith("blob:") || url.startsWith("data:")) return url;

  const currentBase = String(import.meta.env.VITE_SUPABASE_URL || "").replace(/\/$/, "");
  if (!currentBase) return url;

  try {
    const parsed = new URL(url);
    const currentOrigin = new URL(currentBase).origin;
    const match = parsed.pathname.match(PUBLIC_STORAGE_OBJECT_PATH);
    const isKnownStorageHost = parsed.hostname.endsWith(".supabase.co") || parsed.origin === currentOrigin;

    if (!match?.[1] || !isKnownStorageHost || parsed.origin === currentOrigin) return url;
    return `${currentBase}/storage/v1/object/public/${match[1]}${parsed.search}`;
  } catch {
    return url;
  }
}