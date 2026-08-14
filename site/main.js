/* ===========================================================================
   Aurora — site behaviour
   ---------------------------------------------------------------------------
   A plain-JS port of the logic in the Claude Design file "Aurora Website.dc.html".
   The design ran it as a React component (DCLogic) with three editable props;
   those are the CONFIG block below, since a static site has no props panel.

   Five jobs: nav background + reading progress, section spy, the device
   switcher, the player's ticking seek bar, and reveal-on-scroll. The design's
   cursor-following hero glow was cut on request.
   Everything degrades to a perfectly readable static page without JS.
   =========================================================================== */
(function () {
  'use strict';

  var CONFIG = {
    accentColor: null,   // e.g. '#4FD1C5' to retint the site; null keeps the token
    ambientMotion: true, // drifting aurora ribbons, ticking player
    revealOnScroll: true
  };

  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var motion = CONFIG.ambientMotion && !reduced;

  if (CONFIG.accentColor) {
    document.documentElement.style.setProperty('--violet', CONFIG.accentColor);
  }

  /* ---- nav background + reading progress -------------------------------- */
  var nav = document.querySelector('[data-nav]');
  var bar = document.querySelector('[data-progress]');

  function onScroll() {
    var y = window.scrollY;
    if (nav) nav.classList.toggle('is-stuck', y > 12);
    if (bar) {
      var h = document.documentElement.scrollHeight - window.innerHeight;
      bar.style.width = (h > 0 ? Math.min(1, y / h) * 100 : 0) + '%';
    }
  }

  /* ---- which section am I in -------------------------------------------- */
  var links = Array.prototype.slice.call(document.querySelectorAll('[data-navlinks] a[href^="#"]'));
  // The last link is the CTA — it keeps its own styling and never lights up.
  var spyLinks = links.filter(function (a) { return !a.classList.contains('nav-cta'); });

  function onSpy() {
    var active = null;
    spyLinks.forEach(function (a) {
      var el = document.querySelector(a.getAttribute('href'));
      if (!el) return;
      var r = el.getBoundingClientRect();
      if (r.top <= 140 && r.bottom > 140) active = a;
    });
    spyLinks.forEach(function (a) { a.classList.toggle('is-current', a === active); });
  }

  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('scroll', onSpy, { passive: true });
  onScroll();
  onSpy();

  /* ---- ambient motion off ----------------------------------------------- */
  if (!motion) {
    document.querySelectorAll('[data-ambient]').forEach(function (el) { el.style.animation = 'none'; });
  }

  /* ---- device switcher -------------------------------------------------- */
  (function initDeviceSwitcher() {
    var btns = Array.prototype.slice.call(document.querySelectorAll('[data-device]'));
    var screens = Array.prototype.slice.call(document.querySelectorAll('[data-screen]'));
    var note = document.querySelector('[data-devicenote]');
    if (!btns.length || !screens.length) return;

    var notes = {
      phone: 'Phone: a six-tab bar, rails you flick through, and posters sized for a thumb.',
      desktop: 'Windows: the rails become a wider grid, with a top nav and search instead of tabs.',
      tv: 'Television: a navigation rail, ten-foot type, and a white focus ring wherever the D-pad is.'
    };

    function apply(key) {
      screens.forEach(function (el) { el.hidden = el.dataset.screen !== key; });
      if (note) note.textContent = notes[key];
      btns.forEach(function (b) {
        var on = b.dataset.device === key;
        b.setAttribute('aria-selected', on ? 'true' : 'false');
        b.tabIndex = on ? 0 : -1;
      });
    }

    btns.forEach(function (b) {
      b.addEventListener('click', function () { apply(b.dataset.device); });
      // Roving focus: a tablist should answer the arrow keys, not just clicks.
      b.addEventListener('keydown', function (e) {
        var i = btns.indexOf(b);
        var next = e.key === 'ArrowRight' ? i + 1 : e.key === 'ArrowLeft' ? i - 1 : -1;
        if (next < 0 || next >= btns.length) return;
        e.preventDefault();
        btns[next].focus();
        apply(btns[next].dataset.device);
      });
    });

    apply('phone');
  })();

  /* ---- the player's seek bar keeps ticking ------------------------------ */
  (function initPlayerDemo() {
    var fill = document.querySelector('[data-seekfill]');
    var knob = document.querySelector('[data-seekknob]');
    var cur = document.querySelector('[data-tcur]');
    var rem = document.querySelector('[data-trem]');
    var up = document.querySelector('[data-upnext]');
    var section = document.getElementById('player');
    if (!fill || !section || !motion) return;

    var total = 4558;          // 1:15:58 — the episode's full length
    var left = 20;             // seconds remaining, as authored in the design
    var timer = null;

    function pad(n) { return (n < 10 ? '0' : '') + n; }
    function clock(s) { return Math.floor(s / 3600) + ':' + pad(Math.floor((s % 3600) / 60)) + ':' + pad(s % 60); }

    function paint() {
      var pct = ((total - left) / total) * 100;
      fill.style.width = pct.toFixed(2) + '%';
      if (knob) knob.style.left = pct.toFixed(2) + '%';
      if (cur) cur.textContent = clock(total - left);
      if (rem) rem.textContent = '−' + pad(Math.floor(left / 60)) + ':' + pad(left % 60);
      if (up) up.textContent = left + '…';
    }

    paint();

    // Only run while it is on screen — no point animating a section nobody sees.
    if (!('IntersectionObserver' in window)) return;
    new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting && !timer) {
          timer = setInterval(function () { left = left <= 1 ? 20 : left - 1; paint(); }, 1000);
        } else if (!e.isIntersecting && timer) {
          clearInterval(timer);
          timer = null;
        }
      });
    }, { threshold: 0.25 }).observe(section);
  })();

  /* ---- reveal on scroll ------------------------------------------------- */
  (function initReveal() {
    if (!CONFIG.revealOnScroll || reduced || !('IntersectionObserver' in window)) return;
    var ease = 'cubic-bezier(.2,.7,.2,1)';
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (!e.isIntersecting) return;
        e.target.style.opacity = '1';
        e.target.style.transform = 'none';
        io.unobserve(e.target);
      });
    }, { rootMargin: '0px 0px -12% 0px', threshold: 0.08 });

    document.querySelectorAll('[data-reveal]').forEach(function (el, i) {
      // Anything already in view stays put; only what is below the fold animates in.
      if (el.getBoundingClientRect().top < window.innerHeight * 0.9) return;
      var d = (i % 3) * 0.07 + 's';
      el.classList.add('reveal-init');
      el.style.transition = 'opacity .7s ' + ease + ' ' + d + ', transform .7s ' + ease + ' ' + d;
      io.observe(el);
    });
  })();
})();
