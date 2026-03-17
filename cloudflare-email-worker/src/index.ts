interface Env {
  INBOXED_API_URL: string;
  INBOUND_WEBHOOK_SECRET: string;
}

interface EmailMessage {
  from: string;
  to: string;
  raw: ReadableStream;
  rawSize: number;
  headers: Headers;
  forward(to: string): Promise<void>;
  reject(reason: string): void;
}

export default {
  async email(message: EmailMessage, env: Env) {
    const rawEmail = await streamToArrayBuffer(message.raw);

    const response = await fetch(`${env.INBOXED_API_URL}/hooks/inbound`, {
      method: "POST",
      headers: {
        "Content-Type": "message/rfc822",
        Authorization: `Bearer ${env.INBOUND_WEBHOOK_SECRET}`,
        "X-Envelope-From": message.from,
        "X-Envelope-To": message.to,
      },
      body: rawEmail,
    });

    if (!response.ok) {
      throw new Error(`Inboxed API returned ${response.status}`);
    }
  },
};

async function streamToArrayBuffer(
  stream: ReadableStream,
): Promise<ArrayBuffer> {
  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
  }
  return new Blob(chunks).arrayBuffer();
}
