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
  // default hero is the Mender, so the click-cast editor is shown
  expect(document.querySelectorAll('.bind-row').length).toBe(4);

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
  window.dispatchEvent(new KeyboardEvent('keydown', { code: 'Digit3' }));
  // click-cast: left click on your own frame casts Mend on yourself
  const ownFrame = document.querySelector('.frame.me') as HTMLElement;
  ownFrame.dispatchEvent(new MouseEvent('mousedown', { button: 0, bubbles: true }));
  frames(20);
  expect((document.querySelector('.castbar span') as HTMLElement).textContent).toMatch(/^Mend /);
  frames(600);
  expect(document.querySelector('.timer')!.textContent).toMatch(/^\d+:\d\d \/ 14:00$/);

  window.dispatchEvent(new KeyboardEvent('keydown', { code: 'KeyP' }));
  expect(document.querySelector('.overlay')).toBeTruthy();
  (document.querySelector('.overlay button.ghost') as HTMLElement).click();
  expect(document.querySelector('.setup')).toBeTruthy();
});
