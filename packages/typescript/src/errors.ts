export class InboxedError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "InboxedError";
  }
}

export class InboxedTimeoutError extends InboxedError {
  constructor(inbox: string, timeoutMs: number) {
    super(
      `No email arrived at ${inbox} within ${timeoutMs / 1000} seconds.`
    );
    this.name = "InboxedTimeoutError";
  }
}

export class InboxedNotFoundError extends InboxedError {
  constructor(resource: string) {
    super(`Not found: ${resource}`);
    this.name = "InboxedNotFoundError";
  }
}

export class InboxedAuthError extends InboxedError {
  constructor() {
    super("Authentication failed. Check your API key.");
    this.name = "InboxedAuthError";
  }
}
