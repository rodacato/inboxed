/**
 * Extract a verification code from email body text.
 * Default pattern matches 4-8 digit codes. Supports custom regex for
 * alphanumeric codes (e.g., "AX8-KM2P" with pattern "[A-Z0-9]{3}-[A-Z0-9]{4}").
 */
export function extractCode(
  bodyText: string | null,
  bodyHtml: string | null,
  pattern?: string
): string | null {
  const text = bodyText ?? stripHtml(bodyHtml ?? "");
  if (!text) return null;
  const regex = new RegExp(pattern ?? "\\b\\d{4,8}\\b", "g");
  const matches = text.match(regex);
  return matches ? matches[matches.length - 1] : null;
}

/**
 * Extract URLs from email body.
 * Searches body_text first, falls back to href parsing in body_html.
 */
export function extractUrls(
  bodyText: string | null,
  bodyHtml: string | null
): string[] {
  if (bodyText) {
    const urlRegex = /https?:\/\/[^\s<>")\]]+/g;
    return bodyText.match(urlRegex) ?? [];
  }
  if (bodyHtml) {
    const hrefRegex = /href=["'](https?:\/\/[^"']+)["']/gi;
    const urls: string[] = [];
    let match;
    while ((match = hrefRegex.exec(bodyHtml)) !== null) {
      urls.push(match[1]);
    }
    return urls;
  }
  return [];
}

/**
 * Extract a labeled value from email body text.
 * Searches for patterns like "Password: xK9#mP2!" or "Username: user_8a7c3f".
 * The label match is case-insensitive.
 */
export function extractLabeledValue(
  bodyText: string | null,
  bodyHtml: string | null,
  label: string,
  valuePattern?: string
): string | null {
  const text = bodyText ?? stripHtml(bodyHtml ?? "");
  if (!text) return null;
  const valueCapture = valuePattern ?? "\\S+";
  const regex = new RegExp(
    `${escapeRegex(label)}[:#\\s]+\\s*(${valueCapture})`,
    "i"
  );
  const match = text.match(regex);
  return match ? match[1] : null;
}

/**
 * Escape special regex characters in a string (for label matching).
 */
function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Strip HTML tags to get plain text.
 */
export function stripHtml(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .trim();
}
