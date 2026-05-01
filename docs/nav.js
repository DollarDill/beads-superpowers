// beads-superpowers docs — sidebar toggle + active page + TOC generation
(function () {
  'use strict';

  // Mark active nav link
  var path = location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('.sidebar a.nav-link').forEach(function (a) {
    if (a.getAttribute('href') === path) a.classList.add('active');
  });

  // Mobile hamburger toggle
  var hamburger = document.querySelector('.hamburger');
  var sidebar = document.querySelector('.sidebar');
  if (hamburger && sidebar) {
    hamburger.addEventListener('click', function () {
      sidebar.classList.toggle('open');
    });
    // Close sidebar when clicking a link (mobile)
    sidebar.querySelectorAll('a').forEach(function (a) {
      a.addEventListener('click', function () {
        if (window.innerWidth <= 768) sidebar.classList.remove('open');
      });
    });
  }

  // Render "Last updated" from GitHub API (git commit history)
  var article = document.querySelector('article');
  var pagePath = location.pathname.split('/').pop() || 'index.html';
  var repo = 'DollarDill/beads-superpowers';
  var filePath = 'docs/' + pagePath;

  if (article) {
    // Create placeholder so layout doesn't shift
    var el = document.createElement('p');
    el.className = 'last-updated';
    el.style.visibility = 'hidden';
    el.innerHTML = '&nbsp;';
    var subtitle = article.querySelector('.subtitle');
    if (subtitle) {
      subtitle.parentNode.insertBefore(el, subtitle.nextSibling);
    }

    fetch('https://api.github.com/repos/' + repo + '/commits?path=' + filePath + '&per_page=1')
      .then(function (r) { return r.ok ? r.json() : Promise.reject(); })
      .then(function (commits) {
        if (commits && commits.length > 0) {
          var date = new Date(commits[0].commit.committer.date);
          var formatted = date.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
          el.innerHTML = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M8 0a8 8 0 1 0 0 16A8 8 0 0 0 8 0zm.5 4.5v3.793l2.354 2.353a.5.5 0 0 1-.708.708l-2.5-2.5A.5.5 0 0 1 7.5 8.5v-4a.5.5 0 0 1 1 0z"/></svg>' +
            'Last updated: ' + formatted;
          el.style.visibility = 'visible';
        } else {
          el.remove();
        }
      })
      .catch(function () {
        el.remove(); // silently degrade if API unavailable or rate-limited
      });
  }

  // Auto-generate "On this page" TOC from h2 elements
  var toc = document.querySelector('.on-this-page');
  if (toc && article) {
    var headings = article.querySelectorAll('h2[id]');
    if (headings.length > 1) {
      var title = document.createElement('div');
      title.className = 'on-this-page-title';
      title.textContent = 'On this page';
      toc.appendChild(title);
      headings.forEach(function (h) {
        var a = document.createElement('a');
        a.href = '#' + h.id;
        a.textContent = h.textContent;
        toc.appendChild(a);
      });

      // Scroll spy
      var tocLinks = toc.querySelectorAll('a');
      var observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            tocLinks.forEach(function (l) { l.classList.remove('active'); });
            var active = toc.querySelector('a[href="#' + entry.target.id + '"]');
            if (active) active.classList.add('active');
          }
        });
      }, { rootMargin: '-80px 0px -70% 0px' });
      headings.forEach(function (h) { observer.observe(h); });
    }
  }
  // ─── Mermaid lightbox with panzoom ───
  var diagrams = document.querySelectorAll('.mermaid');
  if (diagrams.length > 0) {
    // Create lightbox DOM
    var lb = document.createElement('div');
    lb.className = 'mermaid-lightbox';
    lb.innerHTML = '<button class="mermaid-lightbox-close" aria-label="Close">&times;</button>' +
      '<div class="mermaid-lightbox-inner"></div>' +
      '<div class="mermaid-lightbox-hint">Scroll to zoom · Drag to pan · Click backdrop or Esc to close</div>';
    document.body.appendChild(lb);

    var lbInner = lb.querySelector('.mermaid-lightbox-inner');
    var lbClose = lb.querySelector('.mermaid-lightbox-close');
    var pzInstance = null;

    function closeLightbox() {
      lb.classList.remove('active');
      if (pzInstance) { pzInstance.dispose(); pzInstance = null; }
      lbInner.innerHTML = '';
      document.body.style.overflow = '';
    }

    lbClose.addEventListener('click', function (e) { e.stopPropagation(); closeLightbox(); });
    lb.addEventListener('click', function (e) { if (e.target === lb) closeLightbox(); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && lb.classList.contains('active')) closeLightbox(); });

    // Wait for Mermaid to finish rendering, then attach click handlers
    function attachClickHandlers() {
      diagrams.forEach(function (d) {
        d.addEventListener('click', function () {
          var svg = d.querySelector('svg');
          if (!svg) return;
          var clone = svg.cloneNode(true);
          clone.style.maxWidth = 'none';
          clone.style.width = 'auto';
          clone.style.height = 'auto';
          lbInner.innerHTML = '';
          lbInner.appendChild(clone);
          lb.classList.add('active');
          document.body.style.overflow = 'hidden';
          // Attach panzoom if available
          if (typeof panzoom === 'function') {
            pzInstance = panzoom(clone, { maxZoom: 10, minZoom: 0.5, smoothScroll: false });
          }
        });
      });
    }

    // Mermaid renders async — wait for SVGs to appear
    var checkInterval = setInterval(function () {
      var rendered = document.querySelector('.mermaid svg');
      if (rendered) {
        clearInterval(checkInterval);
        attachClickHandlers();
      }
    }, 200);
    // Safety timeout
    setTimeout(function () { clearInterval(checkInterval); attachClickHandlers(); }, 5000);
  }
})();
