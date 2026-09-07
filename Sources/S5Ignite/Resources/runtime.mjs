export class APIError extends Error {
  constructor(status, code, message) {
    super(message);
    this.name = 'APIError';
    this.status = status;
    this.code = code;
  }
}

// No credentials or server implementation are embedded in generated assets.
// Only same-origin, versioned S5 paths are accepted. Mutations are never retried automatically.
export function createClient(routes, fetchImpl = globalThis.fetch) {
  return Object.freeze(Object.fromEntries(Object.entries(routes).map(([key, path]) => {
    if (!/^\/api\/v[1-9][0-9]*\/[a-z0-9-]+(?:\.[a-z0-9-]+)*$/.test(path)) {
      throw new TypeError(`Invalid endpoint path for ${key}`);
    }
    return [key, async (input = {}, { signal, headers = {} } = {}) => {
      const response = await fetchImpl(path, {
        method: 'POST',
        credentials: 'same-origin',
        headers: { ...headers, 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify(input),
        signal: signal ?? AbortSignal.timeout(30000),
      });
      let payload;
      try { payload = await response.json(); }
      catch { throw new APIError(response.status, 'invalid_response', 'The server returned an invalid response.'); }
      if (!response.ok) {
        throw new APIError(response.status, payload?.code ?? 'http_error',
          typeof payload?.message === 'string' ? payload.message : 'The request failed.');
      }
      return payload;
    }];
  })));
}
