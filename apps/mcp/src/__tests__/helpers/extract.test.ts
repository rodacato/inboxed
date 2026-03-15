import { describe, it, expect } from "vitest";
import {
  extractCode,
  extractUrls,
  extractLabeledValue,
  stripHtml,
} from "../../helpers/extract.js";

describe("extractCode", () => {
  it("extracts a 6-digit code from plain text", () => {
    const body = "Your verification code is: 482910";
    expect(extractCode(body, null)).toBe("482910");
  });

  it("extracts a 4-digit code", () => {
    const body = "Enter code 7291 to verify.";
    expect(extractCode(body, null)).toBe("7291");
  });

  it("extracts an 8-digit code", () => {
    const body = "Confirmation: 12345678";
    expect(extractCode(body, null)).toBe("12345678");
  });

  it("returns the last match (code appears after context text)", () => {
    const body = "Reference 1234. Your code is 567890.";
    expect(extractCode(body, null)).toBe("567890");
  });

  it("falls back to HTML body when text is null", () => {
    const html = "<p>Your code is <strong>482910</strong></p>";
    expect(extractCode(null, html)).toBe("482910");
  });

  it("returns null when no code found", () => {
    const body = "Welcome to our app!";
    expect(extractCode(body, null)).toBeNull();
  });

  it("returns null for empty input", () => {
    expect(extractCode(null, null)).toBeNull();
  });

  it("supports custom regex pattern for alphanumeric codes", () => {
    const body = "Your code: AX8-KM2P";
    expect(extractCode(body, null, "[A-Z0-9]{3}-[A-Z0-9]{4}")).toBe(
      "AX8-KM2P"
    );
  });

  it("ignores numbers outside the 4-8 digit range", () => {
    const body = "Order 12 has code 567890. Total: 999999999.";
    expect(extractCode(body, null)).toBe("567890");
  });
});

describe("extractUrls", () => {
  it("extracts URLs from plain text", () => {
    const body =
      "Click here: https://app.example.com/verify?token=abc123 to confirm.";
    expect(extractUrls(body, null)).toEqual([
      "https://app.example.com/verify?token=abc123",
    ]);
  });

  it("extracts multiple URLs", () => {
    const body =
      "Visit https://example.com or http://other.com for more info.";
    const urls = extractUrls(body, null);
    expect(urls).toHaveLength(2);
    expect(urls[0]).toBe("https://example.com");
    expect(urls[1]).toBe("http://other.com");
  });

  it("extracts URLs from HTML href attributes when text is null", () => {
    const html =
      '<a href="https://app.example.com/verify?token=abc">Click here</a>';
    expect(extractUrls(null, html)).toEqual([
      "https://app.example.com/verify?token=abc",
    ]);
  });

  it("returns empty array when no URLs found", () => {
    expect(extractUrls("No links here.", null)).toEqual([]);
  });

  it("returns empty array for null inputs", () => {
    expect(extractUrls(null, null)).toEqual([]);
  });

  it("prefers body_text over body_html", () => {
    const text = "Visit https://text.com";
    const html = '<a href="https://html.com">Link</a>';
    expect(extractUrls(text, html)).toEqual(["https://text.com"]);
  });
});

describe("extractLabeledValue", () => {
  it("extracts a password after label", () => {
    const body = "Your temporary password: xK9#mP2!";
    expect(extractLabeledValue(body, null, "password")).toBe("xK9#mP2!");
  });

  it("extracts a username", () => {
    const body = "Username: user_8a7c3f";
    expect(extractLabeledValue(body, null, "Username")).toBe("user_8a7c3f");
  });

  it("extracts a reference number with hash separator", () => {
    const body = "Reference # ORD-99281";
    expect(extractLabeledValue(body, null, "Reference")).toBe("ORD-99281");
  });

  it("is case-insensitive for the label", () => {
    const body = "PASSWORD: xK9#mP2!";
    expect(extractLabeledValue(body, null, "password")).toBe("xK9#mP2!");
  });

  it("falls back to HTML body", () => {
    const html = "<p>Password: <b>secret123</b></p>";
    expect(extractLabeledValue(null, html, "Password")).toBe("secret123");
  });

  it("returns null when label not found", () => {
    const body = "Welcome to the app!";
    expect(extractLabeledValue(body, null, "password")).toBeNull();
  });

  it("supports custom value pattern", () => {
    const body = "Tracking number: 1Z999AA10123456784";
    expect(
      extractLabeledValue(body, null, "Tracking number", "[A-Z0-9]+")
    ).toBe("1Z999AA10123456784");
  });
});

describe("stripHtml", () => {
  it("removes HTML tags", () => {
    expect(stripHtml("<p>Hello <b>World</b></p>")).toBe("Hello World");
  });

  it("converts br to newlines", () => {
    expect(stripHtml("Line 1<br>Line 2<br/>Line 3")).toBe(
      "Line 1\nLine 2\nLine 3"
    );
  });

  it("converts closing p to double newlines", () => {
    expect(stripHtml("<p>Para 1</p><p>Para 2</p>")).toBe(
      "Para 1\n\nPara 2"
    );
  });

  it("decodes common HTML entities", () => {
    expect(stripHtml("&amp; &lt; &gt; &nbsp;")).toBe("& < >");
  });
});
