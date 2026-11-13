// @vitest-environment happy-dom
import { expect, test, vi } from 'vitest';

// Smoke test: the interface builds, a run starts, and frames draw without throwing.
test('setup screen, run and pause work end to end', async () => {
  document.body.innerHTML = '<div id="app"></div>';
  const store: Record<string, unknown> = {};
  const ctx: unknown = new Proxy(store, { get: (t, k: string) => (k in t ? t[k] : () => ctx), set: (t, k: string, v) => { t[k] = v; return true; } });
  HTMLCanvasElement.prototype.getContext = (() => ctx) as never;
  let cb: FrameRequestCallback | null = null;
  vi.stubGlobal('requestAnimationFrame', (f: FrameRequestCallback) => { cb = f; return 1; });
  vi.stubGlobal('cancelAnimationFrame', () => {});

  await import('../src/main');
  expect(document.querySelector('.setup')).toBeTruthy();
  expect(document.querySelectorAll('.kit-row').length).toBe(6);
  // default hero is Sister Wren, a healer, so the click-cast editor is shown
  expect(document.querySelectorAll('.bind-row').length).toBe(4);
  // every hero has the key editor: six abilities, two key slots each
  expect(document.querySelectorAll('.slot-key').length).toBe(12);
  // rebind Rebuke (third ability, first slot) to F; W is kept for moving and is refused
  const slot = () => document.querySelectorAll('.slot-key')[4] as HTMLElement;
  slot().click();
  window.dispatchEvent(new KeyboardEvent('keydown', { code: 'KeyW' }));
  expect(slot().classList.contains('waiting')).toBe(true);
  window.dispatchEvent(new KeyboardEvent('keydown', { code: 'KeyF' }));
  expect(slot().textContent).toBe('F');
  expect(document.querySelectorAll('.kit-row .key')[2].textContent).toBe('F');

  (document.querySelector('button.start') as HTMLElement).click();
  expect(document.querySelectorAll('.frame').length).toBe(4);
  expect(document.querySelectorAll('.ability').length).toBe(6);

  let now = performance.now();
  const frames = (n: number) => { for (let i = 0; i < n; i++) { now += 16.7; cb!(now); } };
  frames(30);
  window.dispatchEvent(new KeyboardEvent('keydown', { code: 'KeyD' }));
  frames(600);
  window.dispatchEvent(new KeyboardEvent('keyup', { code: 'KeyD' }));
  window.dispatchEvent(new KeyboardEvent('keydown', { code: 'Tab' }));
  // 3 no longer casts Rebuke; F does. Q walks left like A.
  window.dispatchEvent(new KeyboardEvent('keydown', { code: 'Digit3' }));
  frames(5);
  expect((document.querySelector('.castbar') as HTMLElement).style.visibility).toBe('hidden');
  expect(document.querySelectorAll('.ability .key')[2].textContent).toBe('F');
  expect(document.querySelectorAll('.ability .key')[4].textContent).toBe('5 · `');
  // click-cast: left click on your own frame casts Warm Light on yourself
  const ownFrame = document.querySelector('.frame.me') as HTMLElement;
  ownFrame.dispatchEvent(new MouseEvent('mousedown', { button: 0, bubbles: true }));
  frames(20);
  expect((document.querySelector('.castbar span') as HTMLElement).textContent).toMatch(/^Warm Light /);
  frames(600);
  expect(document.querySelector('.timer')!.textContent).toMatch(/^\d+:\d\d \/ 14:00$/);

  window.dispatchEvent(new KeyboardEvent('keydown', { code: 'KeyP' }));
  expect(document.querySelector('.overlay')).toBeTruthy();
  (document.querySelector('.overlay .panel > button.ghost') as HTMLElement).click();
  expect(document.querySelector('.setup')).toBeTruthy();
});
