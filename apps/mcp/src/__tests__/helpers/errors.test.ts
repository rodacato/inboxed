import { describe, it, expect } from "vitest";
import {
  ApiError,
  mapApiError,
  toolSuccess,
  toolError,
} from "../../helpers/errors.js";

describe("toolSuccess", () => {
  it("returns structured success result", () => {
    const result = toolSuccess({ code: "123456" });
    expect(result.isError).toBeUndefined();
    expect(result.content).toHaveLength(1);
    expect(result.content[0].type).toBe("text");
    expect(JSON.parse(result.content[0].text)).toEqual({ code: "123456" });
  });
});

describe("toolError", () => {
  it("returns structured error result", () => {
    const result = toolError("Something went wrong");
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toBe("Something went wrong");
  });
});

describe("mapApiError", () => {
  it("maps 401 to authentication error", () => {
    const error = new ApiError(401, "Unauthorized", "/api/v1/inboxes");
    const result = mapApiError(error);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Authentication failed");
  });

  it("maps 403 to authentication error", () => {
    const error = new ApiError(403, "Forbidden", "/api/v1/inboxes");
    const result = mapApiError(error);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Authentication failed");
  });

  it("maps 404 to not found error", () => {
    const error = new ApiError(
      404,
      "Not Found",
      "/api/v1/inboxes/abc"
    );
    const result = mapApiError(error);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Not found");
  });

  it("maps 422 to invalid input error", () => {
    const error = new ApiError(
      422,
      "Unprocessable Entity",
      "/api/v1/emails"
    );
    const result = mapApiError(error);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Invalid input");
  });

  it("maps 429 to rate limit error", () => {
    const error = new ApiError(429, "Too Many Requests", "/api/v1/search");
    const result = mapApiError(error);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Rate limited");
  });

  it("maps 500 to server error", () => {
    const error = new ApiError(
      500,
      "Internal Server Error",
      "/api/v1/status"
    );
    const result = mapApiError(error);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("temporarily unavailable");
  });

  it("maps fetch TypeError to connection error", () => {
    const error = new TypeError("fetch failed");
    const result = mapApiError(error);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Cannot reach Inboxed API");
  });

  it("maps unknown errors gracefully", () => {
    const result = mapApiError(new Error("Something unexpected"));
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toBe("Something unexpected");
  });
});
