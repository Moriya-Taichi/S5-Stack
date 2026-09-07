import assert from 'node:assert/strict';
import { chromium } from 'playwright';

const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(process.env.S5_BASE_URL ?? 'http://127.0.0.1:8080');
  await page.locator('#status').filter({ hasText: 'notebook is empty' }).waitFor();
  const note = '<script>window.injected=true</script> A note from the browser';
  await page.getByLabel('Your note').fill(note);
  await page.getByRole('button', { name: 'Add note', exact: true }).click();
  await page.locator('.note').filter({ hasText: note }).waitFor();
  assert.equal(await page.evaluate(() => window.injected), undefined);
  await page.reload();
  await page.locator('.note').filter({ hasText: note }).waitFor();
  await page.getByRole('checkbox').check();
  await page.locator('.note.completed').waitFor();
  await page.screenshot({ path: process.env.S5_SCREENSHOT ?? 'notebook.png', fullPage: true });
  await page.getByRole('button', { name: `Delete ${note}`, exact: true }).click();
  await page.locator('#status').filter({ hasText: 'notebook is empty' }).waitFor();
  await page.setViewportSize({ width: 390, height: 844 });
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), true);
  assert.deepEqual(errors, []);
} finally { await browser.close(); }
