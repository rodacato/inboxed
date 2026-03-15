import { describe, it, expect } from "vitest";
import {
  extractCode,
  extractUrls,
  extractLabeledValue,
  stripHtml,
} from "../extract.js";

describe("extractCode", () => {
  it("extracts a 6-digit code", () => {
    expect(extractCode("Your code is 482910", null)).toBe("482910");
  });

  it("extracts a 4-digit code", () => {
    expect(extractCode("Code: 1234", null)).toBe("1234");
  });

  it("extracts an 8-digit code", () => {
    expect(extractCode("Use 12345678 to verify", null)).toBe("12345678");
  });

  it("returns null when no code found", () => {
    expect(extractCode("No code here", null)).toBeNull();
  });

  it("returns last match (code after context text)", () => {
    expect(extractCode("First 111 then 222333", null)).toBe("222333");
  });

  it("supports custom string pattern", () => {
    expect(
      extractCode("Code: AXK-9281", null, "[A-Z]{3}-\\d{4}")
    ).toBe("AXK-9281");
  });

  it("supports custom RegExp pattern", () => {
    expect(
      extractCode("Code: AXK-9281", null, /[A-Z]{3}-\d{4}/)
    ).toBe("AXK-9281");
  });

  it("falls back to HTML body", () => {
    expect(extractCode(null, "<p>Code: <b>482910</b></p>")).toBe("482910");
  });

  it("returns null for empty input", () => {
    expect(extractCode(null, null)).toBeNull();
  });
});

describe("extractUrls", () => {
  it("extracts URLs from plain text", () => {
    expect(
      extractUrls("Click https://app.com/verify?t=abc to verify", null)
    ).toEqual(["https://app.com/verify?t=abc"]);
  });

  it("extracts URLs from HTML href when text is null", () => {
    expect(
      extractUrls(null, '<a href="https://app.com/reset">Reset</a>')
    ).toEqual(["https://app.com/reset"]);
  });

  it("returns empty array when no links", () => {
    expect(extractUrls("No links here", null)).toEqual([]);
  });

  it("returns empty for null inputs", () => {
    expect(extractUrls(null, null)).toEqual([]);
  });

  it("prefers body_text over body_html", () => {
    expect(
      extractUrls("Visit https://text.com", '<a href="https://html.com">x</a>')
    ).toEqual(["https://text.com"]);
  });
});

describe("extractLabeledValue", () => {
  it("extracts password", () => {
    expect(
      extractLabeledValue("Temporary password: xK9#mP2!", null, "password")
    ).toBe("xK9#mP2!");
  });

  it("extracts username", () => {
    expect(
      extractLabeledValue("Your username: user_8a7c3f", null, "username")
    ).toBe("user_8a7c3f");
  });

  it("extracts reference number", () => {
    expect(
      extractLabeledValue("Reference #: ORD-99281", null, "Reference")
    ).toBe("ORD-99281");
  });

  it("returns null when not found", () => {
    expect(
      extractLabeledValue("Welcome to our app!", null, "password")
    ).toBeNull();
  });

  it("is case-insensitive", () => {
    expect(
      extractLabeledValue("PASSWORD: secret123", null, "password")
    ).toBe("secret123");
  });

  it("supports custom pattern as string", () => {
    expect(
      extractLabeledValue("Tracking: 1Z999AA1", null, "Tracking", "[A-Z0-9]+")
    ).toBe("1Z999AA1");
  });

  it("supports custom pattern as RegExp", () => {
    expect(
      extractLabeledValue("Tracking: 1Z999AA1", null, "Tracking", /[A-Z0-9]+/)
    ).toBe("1Z999AA1");
  });

  it("returns null for empty input", () => {
    expect(extractLabeledValue(null, null, "password")).toBeNull();
  });
});

describe("stripHtml", () => {
  it("removes tags", () => {
    expect(stripHtml("<p>Hello <b>World</b></p>")).toBe("Hello World");
  });

  it("converts br to newlines", () => {
    expect(stripHtml("A<br>B<br/>C")).toBe("A\nB\nC");
  });

  it("decodes entities", () => {
    expect(stripHtml("&amp; &lt; &gt;")).toBe("& < >");
  });
});
