import { randomUUID } from "node:crypto";
import { ServiceUnavailableException } from "@nestjs/common";
import type { AppConfig } from "../config/config.js";

// Verification documents are CNIC / licence / vehicle photos — sensitive PII.
// They live in a PRIVATE bucket: the app uploads straight to storage with a
// short-lived signed URL (multi-MB photos never touch the API), and reviewers
// get a short-lived signed view URL. Nothing is ever publicly readable.

export type DocumentPurpose = "cnic" | "license" | "vehicle";

export interface SignedUpload {
  /** Absolute URL the client PUTs the file bytes to. */
  uploadUrl: string;
  /** Opaque storage key to hand back to /verifications as `docKey`. */
  key: string;
  expiresInSeconds: number;
}

export interface DocumentStorage {
  readonly enabled: boolean;
  createUploadUrl(userId: string, purpose: DocumentPurpose, contentType: string): Promise<SignedUpload>;
  /** Short-lived read URL for reviewers. */
  createViewUrl(key: string, ttlSeconds: number): Promise<string>;
}

export const ALLOWED_DOC_TYPES = ["image/jpeg", "image/png", "image/webp", "application/pdf"];

const UPLOAD_TTL_SECONDS = 300;

function extensionFor(contentType: string): string {
  switch (contentType) {
    case "image/png":
      return "png";
    case "image/webp":
      return "webp";
    case "application/pdf":
      return "pdf";
    default:
      return "jpg";
  }
}

/** Used when no storage is configured — endpoints report 503 instead of pretending. */
export class DisabledDocumentStorage implements DocumentStorage {
  readonly enabled = false;

  async createUploadUrl(): Promise<SignedUpload> {
    throw new ServiceUnavailableException(
      "Document uploads are not configured yet. Set STORAGE_PROVIDER and the Supabase keys."
    );
  }

  async createViewUrl(): Promise<string> {
    throw new ServiceUnavailableException("Document storage is not configured yet.");
  }
}

export class SupabaseDocumentStorage implements DocumentStorage {
  readonly enabled = true;

  constructor(
    private readonly baseUrl: string,
    private readonly serviceKey: string,
    private readonly bucket: string
  ) {}

  private get headers(): Record<string, string> {
    return {
      authorization: `Bearer ${this.serviceKey}`,
      apikey: this.serviceKey,
      "content-type": "application/json"
    };
  }

  async createUploadUrl(
    userId: string,
    purpose: DocumentPurpose,
    contentType: string
  ): Promise<SignedUpload> {
    // Namespaced by user so one user can never overwrite another's document,
    // and a random suffix so a re-submission never collides.
    const key = `${userId}/${purpose}-${randomUUID()}.${extensionFor(contentType)}`;

    const res = await fetch(
      `${this.baseUrl}/storage/v1/object/upload/sign/${this.bucket}/${key}`,
      { method: "POST", headers: this.headers, signal: AbortSignal.timeout(10_000) }
    );
    if (!res.ok) {
      console.error(
        JSON.stringify({ level: "error", msg: "signed upload failed", status: res.status })
      );
      throw new ServiceUnavailableException("Could not start the upload. Please try again.");
    }

    // Supabase returns a relative signed path, e.g. "/object/upload/sign/<bucket>/<key>?token=…"
    const { url } = (await res.json()) as { url: string };
    return {
      uploadUrl: `${this.baseUrl}/storage/v1${url}`,
      key,
      expiresInSeconds: UPLOAD_TTL_SECONDS
    };
  }

  async createViewUrl(key: string, ttlSeconds: number): Promise<string> {
    const res = await fetch(`${this.baseUrl}/storage/v1/object/sign/${this.bucket}/${key}`, {
      method: "POST",
      headers: this.headers,
      body: JSON.stringify({ expiresIn: ttlSeconds }),
      signal: AbortSignal.timeout(10_000)
    });
    if (!res.ok) {
      console.error(
        JSON.stringify({ level: "error", msg: "signed view failed", status: res.status })
      );
      throw new ServiceUnavailableException("Could not open the document. Please try again.");
    }
    const { signedURL } = (await res.json()) as { signedURL: string };
    return `${this.baseUrl}/storage/v1${signedURL}`;
  }
}

export function createDocumentStorage(config: AppConfig): DocumentStorage {
  if (config.STORAGE_PROVIDER !== "supabase") return new DisabledDocumentStorage();
  if (!config.SUPABASE_URL || !config.SUPABASE_SERVICE_KEY) {
    console.warn(
      'STORAGE_PROVIDER="supabase" but SUPABASE_URL/SUPABASE_SERVICE_KEY are missing — ' +
        "document uploads stay disabled."
    );
    return new DisabledDocumentStorage();
  }
  return new SupabaseDocumentStorage(
    config.SUPABASE_URL.replace(/\/+$/, ""),
    config.SUPABASE_SERVICE_KEY,
    config.STORAGE_BUCKET
  );
}
