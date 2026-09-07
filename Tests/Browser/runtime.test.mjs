import test from 'node:test';
import assert from 'node:assert/strict';
import { createClient, APIError } from '../../Sources/S5Ignite/Resources/runtime.mjs';

test('sends a same-origin JSON request using the generated route', async () => {
  let calls = 0;
  const api = createClient({ create: '/api/v2/notes.create' }, async (path, options) => {
    calls++;
    assert.equal(path, '/api/v2/notes.create');
    assert.equal(options.method, 'POST');
    assert.equal(options.credentials, 'same-origin');
    assert.equal(options.headers['Content-Type'], 'application/json');
    assert.deepEqual(JSON.parse(options.body), { text: 'hello' });
    return new Response(JSON.stringify({ id: 'one' }), { status: 200 });
  });
  assert.deepEqual(await api.create({ text: 'hello' }), { id: 'one' });
  assert.equal(calls, 1);
});

test('preserves structured errors and does not retry a mutation', async () => {
  let calls = 0;
  const api = createClient({ create: '/api/v1/notes.create' }, async () => {
    calls++;
    return new Response(JSON.stringify({ code: 'future_code', message: 'Try later.' }), { status: 429 });
  });
  await assert.rejects(api.create({}), error => error instanceof APIError && error.status === 429 && error.code === 'future_code');
  assert.equal(calls, 1);
});

test('rejects cross-origin and traversal routes', () => {
  for (const path of ['https://example.com/api', '//evil.test', '/api/v1/../private', '/api/v0/notes']) {
    assert.throws(() => createClient({ operation: path }), TypeError);
  }
});

test('cancellation reaches the transport and invalid JSON is reported', async () => {
  const controller = new AbortController();
  const api = createClient({ list: '/api/v1/notes.list' }, async (_, options) => {
    assert.equal(options.signal, controller.signal);
    return new Response('not json', { status: 502 });
  });
  await assert.rejects(api.list({}, { signal: controller.signal }), error => error.code === 'invalid_response');
});
