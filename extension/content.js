// A small dot at the right edge of YouTube video pages. Click it to show the
// Download buttons. Text only, no pictures. Only on video pages that are already
// open (so NetFree already allowed them).
(function () {
  const DOT_ID = 'vd-dot';
  const BOX_ID = 'vd-box';

  function isVideoPage() {
    return location.pathname === '/watch' || location.pathname.startsWith('/shorts/');
  }

  function closeBox() {
    const b = document.getElementById(BOX_ID);
    if (b) b.remove();
  }

  function makeButton(label, mode, status) {
    const b = document.createElement('button');
    b.textContent = label;
    b.style.cssText = 'display:block;width:100%;margin:6px 0 0 0;padding:7px 10px;font:600 13px Arial,sans-serif;' +
      'border:0;border-radius:6px;background:#1e6ec8;color:#fff;cursor:pointer;text-align:left;';
    b.addEventListener('click', () => {
      status.textContent = 'Sending...';
      chrome.runtime.sendMessage({ type: 'download', url: location.href, mode: mode }, (resp) => {
        if (chrome.runtime.lastError) {
          status.textContent = 'Error: ' + chrome.runtime.lastError.message;
        } else if (resp && resp.ok) {
          status.textContent = 'Sent to Video Downloader';
          setTimeout(closeBox, 2500);
        } else {
          status.textContent = 'Not sent. Open Video Downloader once, then try again.';
        }
      });
    });
    return b;
  }

  function openBox() {
    if (document.getElementById(BOX_ID)) { closeBox(); return; }
    const box = document.createElement('div');
    box.id = BOX_ID;
    box.style.cssText = 'position:fixed;right:4px;bottom:26px;z-index:2147483647;' +
      'width:150px;background:#fff;color:#111;border:1px solid #bbb;border-radius:8px;padding:8px 10px 10px;' +
      'font:13px Arial,sans-serif;box-shadow:0 2px 8px rgba(0,0,0,.25);';
    const top = document.createElement('div');
    top.style.cssText = 'display:flex;justify-content:space-between;align-items:center;font-weight:700;';
    const title = document.createElement('span');
    title.textContent = 'Download';
    const x = document.createElement('span');
    x.textContent = 'x';
    x.title = 'Close';
    x.style.cssText = 'cursor:pointer;padding:0 4px;color:#555;';
    x.addEventListener('click', closeBox);
    top.appendChild(title);
    top.appendChild(x);
    const status = document.createElement('div');
    status.style.cssText = 'margin-top:6px;font-size:12px;color:#333;';
    box.appendChild(top);
    box.appendChild(makeButton('Video', 'video', status));
    box.appendChild(makeButton('MP3', 'mp3', status));
    box.appendChild(makeButton('Best sound', 'wav', status));
    box.appendChild(status);
    document.documentElement.appendChild(box);
  }

  function addDot() {
    if (document.getElementById(DOT_ID)) return;
    const dot = document.createElement('div');
    dot.id = DOT_ID;
    dot.title = 'Download';
    // A small tab in the very bottom-right corner
    dot.textContent = '\u2193';
    dot.style.cssText = 'position:fixed;right:0;bottom:0;z-index:2147483647;' +
      'width:24px;height:20px;line-height:20px;text-align:center;border-radius:8px 0 0 0;' +
      'background:#1e6ec8;color:#fff;font:700 14px Arial,sans-serif;opacity:.45;cursor:pointer;user-select:none;';
    dot.addEventListener('mouseenter', () => { dot.style.opacity = '1'; });
    dot.addEventListener('mouseleave', () => { dot.style.opacity = '.45'; });
    dot.addEventListener('click', openBox);
    document.documentElement.appendChild(dot);
  }

  function removeAll() {
    const d = document.getElementById(DOT_ID);
    if (d) d.remove();
    closeBox();
  }

  // YouTube changes pages without reloading, so check often
  let lastUrl = location.href;
  setInterval(() => {
    if (location.href !== lastUrl) { lastUrl = location.href; closeBox(); }
    if (isVideoPage()) addDot(); else removeAll();
  }, 1000);
})();
