// Gets YouTube's pass (cookies) from Chrome and sends the video link to the
// Video Downloader app on this computer. Nothing is sent anywhere else.
const HOST = 'com.videodownloader.host';

function toNetscape(cookies) {
  const lines = ['# Netscape HTTP Cookie File'];
  for (const c of cookies) {
    let domain = c.domain;
    const sub = c.hostOnly ? 'FALSE' : 'TRUE';
    if (!c.hostOnly && !domain.startsWith('.')) domain = '.' + domain;
    const prefix = c.httpOnly ? '#HttpOnly_' : '';
    const exp = c.session ? 0 : Math.floor(c.expirationDate || 0);
    lines.push([prefix + domain, sub, c.path || '/', c.secure ? 'TRUE' : 'FALSE', String(exp), c.name, c.value].join('\t'));
  }
  return lines.join('\n') + '\n';
}

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (!msg || msg.type !== 'download') return;
  (async () => {
    try {
      const cookies = await chrome.cookies.getAll({ domain: 'youtube.com' });
      chrome.runtime.sendNativeMessage(HOST, {
        url: msg.url,
        mode: msg.mode,
        ua: navigator.userAgent,
        cookies: toNetscape(cookies)
      }, (resp) => {
        if (chrome.runtime.lastError) {
          sendResponse({ ok: false, error: chrome.runtime.lastError.message });
        } else {
          sendResponse(resp || { ok: true });
        }
      });
    } catch (e) {
      sendResponse({ ok: false, error: String(e) });
    }
  })();
  return true; // answer comes later
});

// The Download box asks how its download is going. Keeps a line open to the app's
// helper, which passes on progress until the download is done or failed.
chrome.runtime.onConnect.addListener((port) => {
  if (port.name !== 'vd-watch') return;
  let nat = null;
  port.onMessage.addListener((msg) => {
    if (!msg || !msg.job || nat) return;
    try {
      nat = chrome.runtime.connectNative(HOST);
    } catch (e) {
      port.postMessage({ state: 'lost', text: String(e) });
      return;
    }
    nat.onMessage.addListener((m) => { try { port.postMessage(m); } catch (e) {} });
    nat.onDisconnect.addListener(() => {
      const err = chrome.runtime.lastError;
      try { port.postMessage({ state: 'lost', text: err ? err.message : '' }); } catch (e) {}
    });
    nat.postMessage({ type: 'watch', job: msg.job });
  });
  port.onDisconnect.addListener(() => { if (nat) { try { nat.disconnect(); } catch (e) {} } });
});
