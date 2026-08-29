const STORAGE_OBJECT_PATH = /\/storage\/v1\/object\/(?:public\/)?(.+)$/i;

/**
 * Mantém URLs externas intactas, mas redireciona objetos do Storage antigo
 * para o Storage configurado atualmente no frontend (VPS em produção).
 */
export function resolveMediaUrl(value: unknown): string {
  if (typeof value !== "string") return "";

  const url = value.trim();
  if (!url || url.startsWith("blob:") || url.startsWith("data:")) return url;

  const match = url.match(STORAGE_OBJECT_PATH);
  if (!match?.[1]) return url;

  const currentBase = String(import.meta.env.VITE_SUPABASE_URL || "").replace(/\/$/, "");
  if (!currentBase) return url;

  return `${currentBase}/storage/v1/object/public/${match[1]}`;
}