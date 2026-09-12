// N-031 R3 versioned browser save store (P0-4).
//
// Game progress lives in IndexedDB, never only localStorage. Semantics mirror
// the macOS SaveStore/CampaignSaveCoordinator contract at browser level:
//   - auto slot + manual slots per campaign + mission/protection generations
//   - serialize -> full validate -> write -> read-back confirm -> backup chain
//   - corruption / unknown schema / illegal imports are rejected and never
//     blank the page
// Web saves are independent from macOS saves (behavior fields only).

export const SAVE_DB = 'creek-sprout-saves';
export const SAVE_STORE = 'generations';
export const SCHEMA_VERSION = 3;

export type SaveKind = 'auto' | 'manual' | 'mission_current' | 'pre_reveal';
export type SaveMeta = {
  version: number;
  campaignId: string;
  kind: SaveKind;
  slotIndex: number;
  createdAt: string;
  updatedAt: string;
  day: number;
  map: string;
  checksum: string;
};

export type SaveGeneration = {
  key: string; // generation id `${campaignId}:${kind}:${index}:${createdAt}`
  payload: string; // serialized GameState JSON
  meta: SaveMeta;
};

export type SavePointer = { key: string; generationId: string };

export type StoredRow =
  | (SaveGeneration & { pointer?: never })
  | (SavePointer & { payload?: never; meta?: never });

/** Minimal backend so the same logic runs in browsers and node tests. */
export type SaveBackend = {
  open(): Promise<void>;
  get(key: string): Promise<StoredRow | undefined>;
  put(row: StoredRow): Promise<void>;
  getAll(): Promise<StoredRow[]>;
  deleteRow(key: string): Promise<void>;
};

export function sha256Hex(input: string): Promise<string> {
  return crypto.subtle.digest('SHA-256', new TextEncoder().encode(input)).then(
    (buffer) =>
      Array.from(new Uint8Array(buffer))
        .map((byte) => byte.toString(16).padStart(2, '0'))
        .join(''),
  );
}

export function generationKey(
  campaignId: string,
  kind: SaveKind,
  index: number,
  createdAt: string,
) {
  return `${campaignId}:${kind}:${index}:${createdAt}`;
}

export function slotKey(campaignId: string, kind: SaveKind, index: number) {
  return `${campaignId}:${kind}:${index}`;
}

export type SaveValidator = {
  validate: (payload: string) => { ok: boolean; error?: string };
  currentVersion: number;
};

export class BrowserSaveStore {
  private readonly backend: SaveBackend;
  private readonly validator: SaveValidator;
  private openPromise: Promise<void> | null = null;

  constructor(backend: SaveBackend, validator: SaveValidator) {
    this.backend = backend;
    this.validator = validator;
  }

  private async ensureOpen(): Promise<void> {
    if (!this.openPromise) {
      this.openPromise = this.backend.open().catch((error: unknown) => {
        this.openPromise = null;
        throw error;
      });
    }
    await this.openPromise;
  }

  async save(payload: string, kind: SaveKind, slotIndex: number): Promise<SaveGeneration> {
    const validated = this.validator.validate(payload);
    if (!validated.ok) {
      throw new Error(`save validation failed: ${validated.error ?? 'unknown'}`);
    }
    await this.ensureOpen();
    const parsed = JSON.parse(payload) as { campaignId?: string; day?: number; map?: string };
    const campaignId = parsed.campaignId ?? 'legacy';
    const now = new Date().toISOString();
    const checksum = await sha256Hex(payload);
    // generation keys must stay unique even for same-millisecond saves so the
    // backup chain is never silently collapsed
    const existing = await this.backend.getAll();
    const prefix = `${campaignId}:${kind}:${slotIndex}:`;
    const sameSlotCount = existing.filter(
      (row) => 'payload' in row && row.key.startsWith(prefix),
    ).length;
    const generation: SaveGeneration = {
      key: generationKey(campaignId, kind, slotIndex, `${now}:${sameSlotCount + 1}`),
      payload,
      meta: {
        version: this.validator.currentVersion,
        campaignId,
        kind,
        slotIndex,
        createdAt: now,
        updatedAt: now,
        day: parsed.day ?? 1,
        map: parsed.map ?? 'farm',
        checksum,
      },
    };
    await this.backend.put(generation);
    const pointer: SavePointer = {
      key: slotKey(campaignId, kind, slotIndex),
      generationId: generation.key,
    };
    await this.backend.put(pointer);
    const confirmed = await this.backend.get(generation.key);
    if (!confirmed || !('payload' in confirmed) || confirmed.key !== generation.key) {
      throw new Error('save read-back confirmation failed');
    }
    return generation;
  }

  async readGeneration(
    campaignId: string,
    kind: SaveKind,
    slotIndex: number,
  ): Promise<SaveGeneration | null> {
    await this.ensureOpen();
    const pointer = (await this.backend.get(
      slotKey(campaignId, kind, slotIndex),
    )) as SavePointer | undefined;
    if (!pointer || !('generationId' in pointer)) return null;
    const record = (await this.backend.get(pointer.generationId)) as
      | SaveGeneration
      | undefined;
    if (!record || !('payload' in record)) return null;
    const checksum = await sha256Hex(record.payload);
    if (checksum !== record.meta.checksum) return null;
    return record;
  }

  /** Best valid generation for a slot: primary -> previous generation chain. */
  async loadSlot(
    campaignId: string,
    kind: SaveKind,
    slotIndex: number,
  ): Promise<{ payload: string; generation: SaveGeneration } | null> {
    const primary = await this.readGeneration(campaignId, kind, slotIndex);
    if (primary && this.validator.validate(primary.payload).ok) {
      return { payload: primary.payload, generation: primary };
    }
    await this.ensureOpen();
    const all = await this.backend.getAll();
    const prefix = `${campaignId}:${kind}:${slotIndex}:`;
    const candidates = all
      .filter((row) => 'payload' in row && row.key.startsWith(prefix))
      .map((row) => row as SaveGeneration)
      .sort((a, b) => b.key.localeCompare(a.key));
    for (const candidate of candidates) {
      const checksum = await sha256Hex(candidate.payload);
      if (checksum !== candidate.meta.checksum) continue;
      if (!this.validator.validate(candidate.payload).ok) continue;
      return { payload: candidate.payload, generation: candidate };
    }
    return null;
  }

  async listSlots(campaignId: string): Promise<SaveGeneration[]> {
    await this.ensureOpen();
    const all = await this.backend.getAll();
    const prefix = `${campaignId}:`;
    return all
      .filter((row) => 'payload' in row && row.key.startsWith(prefix))
      .map((row) => row as SaveGeneration)
      .sort((a, b) => b.meta.createdAt.localeCompare(a.meta.createdAt));
  }

  async deleteSlot(campaignId: string, kind: SaveKind, slotIndex: number): Promise<void> {
    await this.ensureOpen();
    await this.backend.deleteRow(slotKey(campaignId, kind, slotIndex));
  }
}

/** In-memory backend for node verification and tests. */
export function memoryBackend(): { backend: SaveBackend; rows: Map<string, StoredRow> } {
  const rows = new Map<string, StoredRow>();
  const backend: SaveBackend = {
    async open() {
      /* no-op */
    },
    async get(key) {
      return rows.get(key);
    },
    async put(row) {
      rows.set(row.key, row);
    },
    async getAll() {
      return [...rows.values()];
    },
    async deleteRow(key) {
      rows.delete(key);
    },
  };
  return { backend, rows };
}
