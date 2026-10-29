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
