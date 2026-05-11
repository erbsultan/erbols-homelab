// Tiny theme toggle: dark / light / system. State persists in localStorage.
// Applied as early as possible to avoid a flash of the wrong theme on load.
(function () {
  var KEY = 'theme';
  var root = document.documentElement;
  var saved = localStorage.getItem(KEY) || 'system';

  function apply(theme) {
    if (theme === 'system') {
      root.removeAttribute('data-theme');
    } else {
      root.setAttribute('data-theme', theme);
    }
    // Update button highlight state. Buttons may not exist yet on first call;
    // we call apply() again from DOMContentLoaded to be safe.
    var btns = document.querySelectorAll('.theme-btn');
    for (var i = 0; i < btns.length; i++) {
      btns[i].classList.toggle('active', btns[i].dataset.theme === theme);
      btns[i].setAttribute('aria-pressed', btns[i].dataset.theme === theme);
    }
  }

  apply(saved);

  document.addEventListener('DOMContentLoaded', function () {
    apply(saved);
    var btns = document.querySelectorAll('.theme-btn');
    for (var i = 0; i < btns.length; i++) {
      btns[i].addEventListener('click', function () {
        var t = this.dataset.theme;
        localStorage.setItem(KEY, t);
        apply(t);
      });
    }
  });
})();
