// Fetches the imported scans. Nothing else in the lab touches the network.
import type { NewsFile, ScanFile, ScanIndex } from "./types";

const DATA_ROOT = "/data";

async function getJson<T>(path: string): Promise<T> {
  const response = await fetch(path);
  if (!response.ok) throw new Error(`${path}: ${response.status}`);
  return (await response.json()) as T;
}

export async function loadIndex(): Promise<ScanIndex> {
  try {
    return await getJson<ScanIndex>(`${DATA_ROOT}/index.json`);
  } catch {
    return { scans: [] }; // nothing imported yet
  }
}

export function loadScan(file: string): Promise<ScanFile> {
  return getJson<ScanFile>(`${DATA_ROOT}/scans/${file}`);
}

// Icon ids the fetch script could not find an image for.
export async function loadMissingIcons(): Promise<Set<number>> {
  try {
    return new Set(await getJson<number[]>("/icons/missing.json"));
  } catch {
    return new Set();
  }
}

// News saved by `npm run news`. Empty when it has never been fetched.
export async function loadNews(): Promise<NewsFile> {
  try {
    return await getJson<NewsFile>(`${DATA_ROOT}/news.json`);
  } catch {
    return { fetched: 0, articles: [] };
  }
}
