import { useCallback, useEffect, useState, type DependencyList } from 'react';

export function useLoad<T>(
  load: (signal: AbortSignal) => Promise<T>,
  dependencies: DependencyList,
) {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [revision, setRevision] = useState(0);
  const retry = useCallback(() => setRevision((value) => value + 1), []);
  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setData(null);
    load(controller.signal)
      .then((value) => {
        if (!controller.signal.aborted) setData(value);
      })
      .catch((reason: unknown) => {
        if (!controller.signal.aborted)
          setError(reason instanceof Error ? reason.message : 'Veriler yüklenemedi.');
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false);
      });
    return () => controller.abort();
    // Yükleyicinin girdileri çağıran bileşenin dependency listesiyle belirlenir.
  }, [...dependencies, revision]);
  return { data, loading, error, retry };
}
