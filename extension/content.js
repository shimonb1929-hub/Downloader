// A small dot at the right edge of YouTube video pages. Click it to show the
// Download buttons. Text only, no pictures. Only on video pages that are already
// open (so NetFree already allowed them).
(function () {
  const DOT_ID = 'vd-dot';
  const BOX_ID = 'vd-box';

  function isVideoPage() {
    return location.pathname === '/watch' || location.pathname.startsWith('/shorts/');
  }

  let watchPort = null;

  function stopWatching() {
    if (watchPort) { try { watchPort.disconnect(); } catch (e) {} }
    watchPort = null;
  }

  function closeBox() {
    stopWatching();
    const b = document.getElementById(BOX_ID);
    if (b) b.remove();
  }

  // Turns Chrome's technical messages into simple steps
  function friendlyError(err) {
    const e = String(err || '');
    if (/Extension context invalidated|Could not establish connection|Receiving end does not exist/i.test(e)) {
      return 'The button was updated. Reload this page (F5), then try again.';
    }
    if (/native messaging host not found|forbidden/i.test(e)) {
      return 'Chrome is not connected to Video Downloader. Double-click "Add Download Button to Chrome.bat" once, then try again.';
    }
    if (/Native host has exited|Error when communicating/i.test(e)) {
      return 'Video Downloader did not answer. Open it once from its folder, then try again.';
    }
    if (/Not a YouTube video page/i.test(e)) return 'This is not a YouTube video page.';
    if (!e) return 'Not sent. Open Video Downloader once, then try again.';
    return 'Not sent: ' + e;
  }

  function showStatus(ui, text, percent, color) {
    ui.status.textContent = text;
    ui.status.style.color = color || '#333';
    if (percent >= 0) {
      ui.bar.style.display = 'block';
      ui.fill.style.width = Math.max(0, Math.min(100, percent)) + '%';
    } else {
      ui.bar.style.display = 'none';
    }
  }

  // Follow the download in the app and show how it is going
  function watchJob(ui, job) {
    stopWatching();
    let finished = false;
    let port;
    try {
      port = chrome.runtime.connect({ name: 'vd-watch' });
    } catch (e) {
      showStatus(ui, 'Sent. Watch the Video Downloader window for progress.', -1);
      return;
    }
    watchPort = port;
    port.onMessage.addListener((m) => {
      if (!m || finished) return;
      if (m.state === 'done') {
        finished = true;
        showStatus(ui, m.text || 'Done!', 100, '#1a7f37');
        stopWatching();
        setTimeout(() => { if (watchPort === null) closeBox(); }, 8000);
      } else if (m.state === 'failed') {
        finished = true;
        showStatus(ui, m.text || 'Download failed. See the Video Downloader window.', -1, '#b42318');
        stopWatching();
      } else if (m.state === 'lost') {
        finished = true;
        showStatus(ui, 'Lost contact with Video Downloader. Check its window to see how the download is going.', -1, '#b42318');
        stopWatching();
      } else {
        showStatus(ui, m.text || 'Working...', typeof m.percent === 'number' ? m.percent : -1);
      }
    });
    port.onDisconnect.addListener(() => {
      if (watchPort === port) watchPort = null;
      if (!finished) {
        finished = true;
        showStatus(ui, 'Lost contact with Video Downloader. Check its window to see how the download is going.', -1, '#b42318');
      }
    });
    port.postMessage({ job: job });
  }

  function makeButton(label, mode, ui) {
    const b = document.createElement('button');
    b.textContent = label;
    b.style.cssText = 'display:block;width:100%;margin:6px 0 0 0;padding:7px 10px;font:600 13px Arial,sans-serif;' +
      'border:0;border-radius:6px;background:#1e6ec8;color:#fff;cursor:pointer;text-align:left;';
    b.addEventListener('click', () => {
      stopWatching();
      showStatus(ui, 'Sending...', -1);
      try {
        chrome.runtime.sendMessage({ type: 'download', url: location.href, mode: mode }, (resp) => {
          if (chrome.runtime.lastError) {
            showStatus(ui, friendlyError(chrome.runtime.lastError.message), -1, '#b42318');
          } else if (resp && resp.ok && resp.job) {
            showStatus(ui, 'Sent to Video Downloader...', -1);
            watchJob(ui, String(resp.job));
          } else if (resp && resp.ok) {
            // Older app without progress: just say it was sent
            showStatus(ui, 'Sent to Video Downloader', -1);
            setTimeout(closeBox, 2500);
          } else {
            showStatus(ui, friendlyError(resp && resp.error), -1, '#b42318');
          }
        });
      } catch (e) {
        showStatus(ui, friendlyError(e && e.message), -1, '#b42318');
      }
    });
    return b;
  }

  function openBox() {
    if (document.getElementById(BOX_ID)) { closeBox(); return; }
    const box = document.createElement('div');
    box.id = BOX_ID;
    box.style.cssText = 'position:fixed;right:4px;bottom:26px;z-index:2147483647;' +
      'width:180px;background:#fff;color:#111;border:1px solid #bbb;border-radius:8px;padding:8px 10px 10px;' +
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
    status.style.cssText = 'margin-top:6px;font-size:12px;color:#333;word-wrap:break-word;';
    // Plain progress bar (just colored boxes, no pictures)
    const bar = document.createElement('div');
    bar.style.cssText = 'display:none;margin-top:6px;height:8px;background:#e3e8ef;border-radius:4px;overflow:hidden;';
    const fill = document.createElement('div');
    fill.style.cssText = 'height:100%;width:0;background:#1e6ec8;transition:width .3s;';
    bar.appendChild(fill);
    const ui = { status: status, bar: bar, fill: fill };
    box.appendChild(top);
    box.appendChild(makeButton('Video', 'video', ui));
    box.appendChild(makeButton('MP3', 'mp3', ui));
    box.appendChild(makeButton('Best sound', 'wav', ui));
    box.appendChild(bar);
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
