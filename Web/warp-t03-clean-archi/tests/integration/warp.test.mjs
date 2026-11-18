import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdtemp, rm, symlink } from 'node:fs/promises';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';
import { chromium, expect } from '@playwright/test';

test('Warp serves the Elm app and supports real user CRUD in an isolated database', { timeout: 30000 }, async t => {
  const portCheck = createServer();
  portCheck.listen(8000, '127.0.0.1');
  await once(portCheck, 'listening');
  await new Promise(resolve => portCheck.close(resolve));

  const root = fileURLToPath(new URL('../../', import.meta.url));
  const installRoot = execFileSync('stack', ['path', '--local-install-root'], { cwd: root, encoding: 'utf8' }).trim();
  const workspace = await mkdtemp(join(tmpdir(), 'warp-elm-'));
  let browser;
  let server;
  t.after(async () => {
    await browser?.close();
    if (server && server.exitCode === null && server.signalCode === null) {
      const exited = once(server, 'exit');
      server.kill();
      await exited;
    }
    await rm(workspace, { recursive: true, force: true });
  });
  await symlink(join(root, 'www'), join(workspace, 'www'), 'junction');
  const executable = process.platform === 'win32' ? 'warp-t03-clean-archi-exe.exe' : 'warp-t03-clean-archi-exe';
  server = spawn(join(installRoot, 'bin', executable), [], { cwd: workspace, stdio: ['ignore', 'pipe', 'pipe'] });
  let output = '';
  server.stdout.on('data', data => { output += data; });
  server.stderr.on('data', data => { output += data; });

  let ready = false;
  for (let attempt = 0; attempt < 100; attempt += 1) {
    assert.equal(server.exitCode, null, output);
    try {
      const response = await fetch('http://127.0.0.1:8000/api/users');
      assert.equal(response.status, 200);
      assert.deepEqual(await response.json(), []);
      ready = true;
      break;
    } catch (error) {
      if (attempt === 99) throw error;
      await setTimeout(50);
    }
  }
  assert.ok(ready, output);
  const asset = await fetch('http://127.0.0.1:8000/elm.js');
  assert.equal(asset.status, 200);
  assert.match(asset.headers.get('content-type'), /javascript/);

  browser = await chromium.launch();
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('http://127.0.0.1:8000/');
  await expect(page.getByText('Every team starts with someone.')).toBeVisible();
  await page.getByLabel('Full name').fill('Elm integration user');
  await page.getByRole('button', { name: 'Add person' }).click();
  await expect(page.getByText('Elm integration user', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Edit Elm integration user' }).click();
  await page.getByLabel('Full name').fill('Elm 0.19.3');
  await page.getByRole('button', { name: 'Save changes' }).click();
  await expect(page.getByText('Elm 0.19.3', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Delete Elm 0.19.3', exact: true }).click();
  await page.getByRole('button', { name: 'Delete permanently' }).click();
  await expect(page.getByText('Every team starts with someone.')).toBeVisible();
  assert.deepEqual(await (await fetch('http://127.0.0.1:8000/api/users')).json(), []);
  assert.deepEqual(errors, []);
});
