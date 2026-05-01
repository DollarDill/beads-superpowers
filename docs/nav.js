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

  // Auto-generate "On this page" TOC from h2 elements
  var toc = document.querySelector('.on-this-page');
  var article = document.querySelector('article');
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
})();
