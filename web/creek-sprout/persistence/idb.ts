// IndexedDB backend for the save store (browser only).
import {
  SAVE_DB,
  SAVE_STORE,
  type SaveBackend,
  type StoredRow,
} from './save-store.ts';

export function indexedDbBackend(): SaveBackend {
  let database: IDBDatabase | null = null;

  const open = () =>
    new Promise<void>((resolve, reject) => {
      if (database) {
        resolve();
        return;
      }
      const request = indexedDB.open(SAVE_DB, 1);
      request.onupgradeneeded = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains(SAVE_STORE)) {
          db.createObjectStore(SAVE_STORE, { keyPath: 'key' });
        }
      };
      request.onsuccess = () => {
        database = request.result;
        database.onversionchange = () => database?.close();
        resolve();
      };
      request.onerror = () => reject(request.error ?? new Error('indexedDB open failed'));
      request.onblocked = () => reject(new Error('indexedDB open blocked'));
    });

  const withStore = <T>(
    mode: IDBTransactionMode,
    run: (store: IDBObjectStore) => IDBRequest<T>,
  ) =>
    open().then(
      () =>
        new Promise<T>((resolve, reject) => {
          if (!database) {
            reject(new Error('indexedDB not open'));
            return;
          }
          const transaction = database.transaction(SAVE_STORE, mode);
          const store = transaction.objectStore(SAVE_STORE);
          const request = run(store);
          request.onsuccess = () => resolve(request.result);
          request.onerror = () => reject(request.error ?? new Error('indexedDB request failed'));
        }),
    );

  return {
    async open() {
      await open();
    },
    async get(key) {
      const row = await withStore('readonly', (store) => store.get(key));
      return row as StoredRow | undefined;
    },
    async put(row) {
      await withStore('readwrite', (store) => store.put(row));
    },
    async getAll() {
      const rows = await withStore('readonly', (store) => store.getAll());
      return (rows ?? []) as StoredRow[];
    },
    async deleteRow(key) {
      await withStore('readwrite', (store) => store.delete(key));
    },
  };
}
