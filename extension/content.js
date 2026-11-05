// A small dot at the right edge of YouTube video pages. Click it to show the
// Download buttons. Text only, no pictures. Only on video pages that are already
// open (so NetFree already allowed them).
(function () {
  const DOT_ID = 'vd-dot';
  const BOX_ID = 'vd-box';

  function isVideoPage() {
    return location.pathname === '/watch' || location.pathname.startsWith('/shorts/');
  }

  // Every click starts its own download right away. Each one gets its own line in the
  // box, with its own progress, so several can run at the same time.
  let rows = [];

  function stopWatching() {
    for (const r of rows) {
      if (r.port) { try { r.port.disconnect(); } catch (e) {} r.port = null; }
    }
  }

  function closeBox() {
    stopWatching();
    rows = [];
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

  function showStatus(row, text, percent, color) {
    row.status.textContent = row.label + ': ' + text;
    row.status.style.color = color || '#333';
    if (percent >= 0) {
      row.bar.style.display = 'block';
      row.fill.style.width = Math.max(0, Math.min(100, percent)) + '%';
    } else {
      row.bar.style.display = 'none';
    }
  }

  // The button can be clicked again once its download has ended
  function endRow(row) {
    row.active = false;
    if (row.button) row.button.disabled = false;
    if (row.button) row.button.style.opacity = '1';
    if (row.port) { try { row.port.disconnect(); } catch (e) {} row.port = null; }
  }

  // When every download in the box is done, close it after a few seconds
  function maybeAutoClose() {
    if (rows.length && rows.every((r) => r.done)) {
      setTimeout(() => {
        if (rows.length && rows.every((r) => r.done)) closeBox();
      }, 8000);
    }
  }

  const LOST = 'Lost contact with Video Downloader. Check its window to see how the download is going.';

  // Follow one download in the app and show how it is going
  function watchJob(row, job) {
    let port;
    try {
      port = chrome.runtime.connect({ name: 'vd-watch' });
    } catch (e) {
      showStatus(row, 'Sent. Watch the Video Downloader window for progress.', -1);
      endRow(row);
      return;
    }
    row.port = port;
    port.onMessage.addListener((m) => {
      if (!m || !row.active) return;
      if (m.state === 'done') {
        showStatus(row, m.text || 'Done!', 100, '#1a7f37');
        row.done = true;
        endRow(row);
        maybeAutoClose();
      } else if (m.state === 'failed') {
        showStatus(row, m.text || 'Download failed. See the Video Downloader window.', -1, '#b42318');
        endRow(row);
      } else if (m.state === 'lost') {
        showStatus(row, LOST, -1, '#b42318');
        endRow(row);
      } else {
        showStatus(row, m.text || 'Working...', typeof m.percent === 'number' ? m.percent : -1);
      }
    });
    port.onDisconnect.addListener(() => {
      if (row.port === port) row.port = null;
      if (row.active) {
        showStatus(row, LOST, -1, '#b42318');
        endRow(row);
      }
    });
    port.postMessage({ job: job });
  }

  function addRow(list, label, button) {
    const wrap = document.createElement('div');
    wrap.style.cssText = 'margin-top:8px;';
    const status = document.createElement('div');
    status.style.cssText = 'font-size:12px;color:#333;word-wrap:break-word;';
    // Plain progress bar (just colored boxes, no pictures)
    const bar = document.createElement('div');
    bar.style.cssText = 'display:none;margin-top:4px;height:8px;background:#e3e8ef;border-radius:4px;overflow:hidden;';
    const fill = document.createElement('div');
    fill.style.cssText = 'height:100%;width:0;background:#1e6ec8;transition:width .3s;';
    bar.appendChild(fill);
    wrap.appendChild(status);
    wrap.appendChild(bar);
    list.appendChild(wrap);
    const row = { label: label, status: status, bar: bar, fill: fill, button: button, port: null, active: true, done: false };
    rows.push(row);
    return row;
  }

  function makeButton(label, mode, list) {
    const b = document.createElement('button');
    b.textContent = label;
    b.style.cssText = 'display:block;width:100%;margin:6px 0 0 0;padding:7px 10px;font:600 13px Arial,sans-serif;' +
      'border:0;border-radius:6px;background:#1e6ec8;color:#fff;cursor:pointer;text-align:left;';
    b.addEventListener('click', () => {
      if (b.disabled) return;
      // The same type of the same video only once at a time (two would fight over one file)
      b.disabled = true;
      b.style.opacity = '.5';
      const row = addRow(list, label, b);
      showStatus(row, 'Sending...', -1);
      try {
        chrome.runtime.sendMessage({ type: 'download', url: location.href, mode: mode }, (resp) => {
          if (chrome.runtime.lastError) {
            showStatus(row, friendlyError(chrome.runtime.lastError.message), -1, '#b42318');
            endRow(row);
          } else if (resp && resp.ok && resp.job) {
            showStatus(row, 'Sent to Video Downloader...', -1);
            watchJob(row, String(resp.job));
          } else if (resp && resp.ok) {
            // Older app without progress: just say it was sent
            showStatus(row, 'Sent to Video Downloader', -1);
            row.done = true;
            endRow(row);
            maybeAutoClose();
          } else {
            showStatus(row, friendlyError(resp && resp.error), -1, '#b42318');
            endRow(row);
          }
        });
      } catch (e) {
        showStatus(row, friendlyError(e && e.message), -1, '#b42318');
        endRow(row);
      }
    });
    return b;
  }

  function openBox() {
    if (document.getElementById(BOX_ID)) { closeBox(); return; }
    const box = document.createElement('div');
    box.id = BOX_ID;
    box.style.cssText = 'position:fixed;right:4px;bottom:26px;z-index:2147483647;' +
      'width:200px;max-height:70vh;overflow-y:auto;background:#fff;color:#111;border:1px solid #bbb;border-radius:8px;padding:8px 10px 10px;' +
      'font:13px Arial,sans-serif;box-shadow:0 2px 8px rgba(0,0,0,.25);';
    const top = document.createElement('div');
    top.style.cssText = 'display:flex;justify-content:space-between;align-items:center;font-weight:700;';
    const title = document.createElement('span');
    title.textContent = 'Download';
    const x = document.createElement('span');
    x.textContent = 'x';
    x.title = 'Close (downloads keep going in the app)';
    x.style.cssText = 'cursor:pointer;padding:0 4px;color:#555;';
    x.addEventListener('click', closeBox);
    top.appendChild(title);
    top.appendChild(x);
    const list = document.createElement('div');
    box.appendChild(top);
    box.appendChild(makeButton('Video', 'video', list));
    box.appendChild(makeButton('MP3', 'mp3', list));
    box.appendChild(makeButton('Best sound', 'wav', list));
    box.appendChild(list);
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
