import { test, expect } from '@playwright/test';

async function connectApi(page, options = {}) {
  const state = {
    users: options.users ?? [{ id: 1, name: 'Ada Lovelace' }, { id: 2, name: 'Grace Hopper' }],
    requests: [],
    failNext: null,
    malformed: false,
    holdWrite: null,
    ...options
  };
  await page.route(/\/api\/users(?:\/\d+)?$/, async route => {
    const request = route.request();
    const method = request.method();
    const path = new URL(request.url()).pathname;
    state.requests.push({ method, path, body: method === 'POST' || method === 'PUT' ? request.postDataJSON() : null });
    if (state.failNext === method) {
      state.failNext = null;
      await route.fulfill({ status: 503, json: { error: 'Unavailable' } });
      return;
    }
    if (method === 'GET') {
      await route.fulfill({ json: state.malformed ? { unexpected: true } : state.users });
      return;
    }
    if (state.holdWrite) await state.holdWrite;
    const identifier = Number(path.split('/').at(-1));
    if (method === 'POST') {
      const user = { id: Math.max(0, ...state.users.map(user => user.id)) + 1, name: request.postDataJSON().name };
      state.users.push(user);
      await route.fulfill({ status: 201, json: user });
    } else if (method === 'PUT') {
      const user = { id: identifier, name: request.postDataJSON().name };
      state.users = state.users.map(existing => existing.id === identifier ? user : existing);
      await route.fulfill({ json: user });
    } else if (method === 'DELETE') {
      state.users = state.users.filter(user => user.id !== identifier);
      await route.fulfill({ status: 204, body: '' });
    } else {
      await route.fulfill({ status: 405 });
    }
  });
  return state;
}

test('creates, searches, edits, confirms and deletes people', async ({ page }) => {
  const api = await connectApi(page);
  await page.goto('/');
  await expect(page.getByText('Ada Lovelace', { exact: true })).toBeVisible();
  await page.getByLabel('Full name').fill('  Katherine Johnson  ');
  await page.getByRole('button', { name: 'Add person' }).click();
  await expect(page.getByText('Katherine Johnson', { exact: true })).toBeVisible();
  expect(api.requests.find(request => request.method === 'POST')).toEqual({ method: 'POST', path: '/api/users', body: { name: 'Katherine Johnson' } });
  await page.getByLabel('Search people').fill('kAtHeRiNe');
  await expect(page.getByText('Ada Lovelace', { exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Edit Katherine Johnson' }).click();
  await expect(page.getByLabel('Full name')).toBeFocused();
  await expect(page.getByLabel('Full name')).toHaveValue('Katherine Johnson');
  await page.getByLabel('Full name').fill('Katherine Coleman Johnson');
  await page.getByRole('button', { name: 'Save changes' }).click();
  await expect(page.getByText('Katherine Coleman Johnson', { exact: true })).toBeVisible();
  expect(api.requests.find(request => request.method === 'PUT')).toEqual({ method: 'PUT', path: '/api/users/3', body: { name: 'Katherine Coleman Johnson' } });
  await page.getByRole('button', { name: 'Delete Katherine Coleman Johnson', exact: true }).click();
  await page.getByRole('button', { name: 'Keep user' }).click();
  expect(api.requests.filter(request => request.method === 'DELETE')).toHaveLength(0);
  await page.getByRole('button', { name: 'Delete Katherine Coleman Johnson', exact: true }).click();
  await page.getByRole('button', { name: 'Delete permanently' }).click();
  await expect(page.getByText('No one by that name. Yet.')).toBeVisible();
  expect(api.requests.find(request => request.method === 'DELETE').path).toBe('/api/users/3');
  await page.getByRole('button', { name: 'Clear search' }).click();
  await expect(page.getByText('Ada Lovelace', { exact: true })).toBeVisible();
});

test('validates names without sending a write request', async ({ page }) => {
  const api = await connectApi(page, { users: [] });
  await page.goto('/');
  await expect(page.getByText('Every team starts with someone.')).toBeVisible();
  await page.getByLabel('Full name').fill('   ');
  await page.getByRole('button', { name: 'Add person' }).click();
  await expect(page.getByText('Please enter a name.')).toBeVisible();
  expect(api.requests.filter(request => request.method === 'POST')).toHaveLength(0);
});

test('preserves input after a failed save and supports retry', async ({ page }) => {
  const api = await connectApi(page);
  await page.goto('/');
  await expect(page.getByLabel('Full name')).toBeEnabled();
  api.failNext = 'POST';
  await page.getByLabel('Full name').fill('Margaret Hamilton');
  await page.getByRole('button', { name: 'Add person' }).click();
  await expect(page.getByRole('alert')).toContainText("couldn't complete");
  await expect(page.getByLabel('Full name')).toHaveValue('Margaret Hamilton');
  await page.getByRole('button', { name: 'Add person' }).click();
  await expect(page.getByText('Margaret Hamilton', { exact: true })).toBeVisible();
});

test('recovers from a failed directory request', async ({ page }) => {
  await connectApi(page, { failNext: 'GET' });
  await page.goto('/');
  await expect(page.getByRole('alert')).toContainText('Let’s try that again.');
  await page.getByRole('button', { name: 'Try again' }).click();
  await expect(page.getByText('Ada Lovelace', { exact: true })).toBeVisible();
});

test('reports malformed API data and recovers', async ({ page }) => {
  const api = await connectApi(page, { malformed: true });
  await page.goto('/');
  await expect(page.getByRole('alert')).toContainText('unexpected data');
  api.malformed = false;
  await page.getByRole('button', { name: 'Try again' }).click();
  await expect(page.getByText('Grace Hopper', { exact: true })).toBeVisible();
});

test('renders hostile names as text and fits narrow screens', async ({ page }, testInfo) => {
  const hostile = '<img src=x onerror="window.compromised=true">';
  await connectApi(page, { users: [{ id: 42, name: hostile }, { id: 2, name: 'A'.repeat(150) }] });
  await page.goto('/');
  await expect(page.getByText(hostile, { exact: true })).toBeVisible();
  expect(await page.evaluate(() => window.compromised)).toBeUndefined();
  expect(await page.locator('.person-name img').count()).toBe(0);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('directory.png'), fullPage: true });
});

test('prevents duplicate writes while waiting for the server', async ({ page }) => {
  let releaseWrite;
  const holdWrite = new Promise(resolve => { releaseWrite = resolve; });
  const api = await connectApi(page, { holdWrite });
  await page.goto('/');
  await expect(page.getByLabel('Full name')).toBeEnabled();
  await page.getByLabel('Full name').fill('Dorothy Vaughan');
  await page.getByRole('button', { name: 'Add person' }).click();
  await expect(page.getByRole('button', { name: 'Adding person' })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Edit Ada Lovelace' })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Refresh', exact: true })).toBeDisabled();
  expect(api.requests.filter(request => request.method === 'POST')).toHaveLength(1);
  releaseWrite();
  await expect(page.getByText('Dorothy Vaughan', { exact: true })).toBeVisible();
});

test('exposes design tokens and keyboard accessible form controls', async ({ page }, testInfo) => {
  await connectApi(page);
  await page.goto('/');
  await expect(page.getByLabel('Full name')).toBeEnabled();
  await expect(page.locator('body')).toHaveCSS('background-color', 'rgb(250, 249, 245)');
  await expect(page.getByRole('button', { name: 'Add person' })).toHaveCSS('background-color', 'rgb(204, 120, 92)');
  await expect(page.locator('h1')).toHaveCSS('font-weight', '400');
  await page.getByLabel('Full name').focus();
  await page.keyboard.type('Mary Jackson');
  await page.keyboard.press('Enter');
  await expect(page.getByText('Mary Jackson', { exact: true })).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath('workspace.png'), fullPage: true });
});

test('changing search while confirming deletion does not block creation', async ({ page }) => {
  await connectApi(page);
  await page.goto('/');
  await page.getByRole('button', { name: 'Delete Ada Lovelace', exact: true }).click();
  await page.getByLabel('Search people').fill('Nobody');
  await expect(page.getByRole('button', { name: 'Add person', exact: true })).toBeEnabled();
});

test('the add shortcut starts a fresh form after editing', async ({ page }, testInfo) => {
  await connectApi(page);
  await page.goto('/');
  await page.getByRole('button', { name: 'Edit Ada Lovelace' }).click();
  await expect(page.getByLabel('Full name')).toHaveValue('Ada Lovelace');
  if (testInfo.project.name === 'mobile') {
    await page.getByRole('button', { name: 'Open navigation' }).click();
  }
  await page.getByRole('link', { name: 'Add a person' }).click();
  await expect(page.getByLabel('Full name')).toHaveValue('');
  await expect(page.getByLabel('Full name')).toBeFocused();
  await expect(page.getByRole('button', { name: 'Add person', exact: true })).toBeVisible();
});

test('a stalled directory request times out and can be retried', async ({ page }) => {
  let stalled = true;
  await page.route(/\/api\/users$/, async route => {
    if (!stalled) await route.fulfill({ json: [] });
  });
  await page.goto('/');
  await expect(page.getByRole('alert')).toContainText('timed out', { timeout: 20000 });
  stalled = false;
  await page.getByRole('button', { name: 'Try again' }).click();
  await expect(page.getByText('Every team starts with someone.')).toBeVisible();
});
