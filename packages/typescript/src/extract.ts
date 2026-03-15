/**
 * Extract a verification code from email body text.
 * Default pattern matches 4-8 digit codes. Returns the last match.
 */
export function extractCode(
  bodyText: string | null,
  bodyHtml: string | null,
  pattern?: string | RegExp
): string | null {
  const text = bodyText ?? stripHtml(bodyHtml ?? "");
  if (!text) return null;

  const regex =
    pattern instanceof RegExp
      ? new RegExp(pattern.source, "g")
      : new RegExp(pattern ?? "\\b\\d{4,8}\\b", "g");

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
 * Case-insensitive label matching.
 */
export function extractLabeledValue(
  bodyText: string | null,
  bodyHtml: string | null,
  label: string,
  valuePattern?: string | RegExp
): string | null {
  const text = bodyText ?? stripHtml(bodyHtml ?? "");
  if (!text) return null;

  const valueCapture =
    valuePattern instanceof RegExp ? valuePattern.source : (valuePattern ?? "\\S+");
  const regex = new RegExp(
    `${escapeRegex(label)}[:#\\s]+\\s*(${valueCapture})`,
    "i"
  );
  const match = text.match(regex);
  return match ? match[1] : null;
}

function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

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
