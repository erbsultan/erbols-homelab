// Background starfield — dim ambient stars + occasional shooting stars.
// Pauses cheaply when canvas is hidden (light theme). Respects reduced motion.
(function () {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  var canvas = document.getElementById('starfield');
  if (!canvas) return;
  var ctx = canvas.getContext('2d');

  var W = 0, H = 0;
  var ambient = [];
  var shooting = [];

  function resize() {
    var dpr = window.devicePixelRatio || 1;
    W = window.innerWidth;
    H = window.innerHeight;
    canvas.width = W * dpr;
    canvas.height = H * dpr;
    canvas.style.width = W + 'px';
    canvas.style.height = H + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    // Ambient stars: roughly one per 18,000 px² — sparse, never crowded.
    var count = Math.round(W * H / 18000);
    ambient = [];
    for (var i = 0; i < count; i++) {
      ambient.push({
        x: Math.random() * W,
        y: Math.random() * H,
        r: 0.3 + Math.random() * 0.7,
        baseAlpha: 0.15 + Math.random() * 0.35,
        twinkleSpeed: 0.3 + Math.random() * 0.7,
        twinklePhase: Math.random() * Math.PI * 2
      });
    }
  }

  function spawnShooting() {
    // Diagonal angle from upper-left to lower-right, 25°–50° below horizontal.
    var angle = (25 + Math.random() * 25) * Math.PI / 180;
    var speed = 0.4 + Math.random() * 0.25;
    shooting.push({
      x: Math.random() * W * 1.1 - W * 0.1,
      y: -30,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      length: 100 + Math.random() * 80,
      alpha: 0.75 + Math.random() * 0.25
    });
  }

  var lastSpawn = 0;
  var nextInterval = 4000 + Math.random() * 2000;   // 4–6 seconds
  var lastFrame = 0;

  function tick(now) {
    // Cheap pause when the canvas is display:none (light theme switch).
    if (getComputedStyle(canvas).display === 'none') {
      lastFrame = now;
      lastSpawn = now;
      requestAnimationFrame(tick);
      return;
    }

    var dt = Math.min(now - lastFrame, 50);
    lastFrame = now;

    if (now - lastSpawn > nextInterval) {
      spawnShooting();
      lastSpawn = now;
      nextInterval = 4000 + Math.random() * 2000;
    }

    ctx.clearRect(0, 0, W, H);

    // Ambient: dim stars with subtle twinkle
    for (var i = 0; i < ambient.length; i++) {
      var s = ambient[i];
      var t = Math.sin(now * 0.001 * s.twinkleSpeed + s.twinklePhase);
      var alpha = s.baseAlpha * (0.6 + 0.4 * (t * 0.5 + 0.5));
      ctx.fillStyle = 'rgba(255, 255, 255, ' + alpha + ')';
      ctx.beginPath();
      ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
      ctx.fill();
    }

    // Shooting: lines with gradient tails + bright heads
    for (var j = shooting.length - 1; j >= 0; j--) {
      var ss = shooting[j];
      ss.x += ss.vx * dt;
      ss.y += ss.vy * dt;

      var mag = Math.hypot(ss.vx, ss.vy);
      var dx = ss.vx / mag, dy = ss.vy / mag;
      var tx = ss.x - dx * ss.length;
      var ty = ss.y - dy * ss.length;

      var grad = ctx.createLinearGradient(ss.x, ss.y, tx, ty);
      grad.addColorStop(0, 'rgba(255, 255, 255, ' + ss.alpha + ')');
      grad.addColorStop(1, 'rgba(255, 255, 255, 0)');
      ctx.strokeStyle = grad;
      ctx.lineWidth = 1.5;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(ss.x, ss.y);
      ctx.lineTo(tx, ty);
      ctx.stroke();

      ctx.fillStyle = 'rgba(255, 255, 255, ' + ss.alpha + ')';
      ctx.beginPath();
      ctx.arc(ss.x, ss.y, 1.5, 0, Math.PI * 2);
      ctx.fill();

      if (ss.x > W + 200 || ss.y > H + 200) shooting.splice(j, 1);
    }

    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', resize);
  resize();
  requestAnimationFrame(tick);
})();
