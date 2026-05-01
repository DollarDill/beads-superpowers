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

  // Render "Last updated" from meta tag
  var article = document.querySelector('article');
  var lastUpdatedMeta = document.querySelector('meta[name="last-updated"]');
  if (lastUpdatedMeta && article) {
    var dateStr = lastUpdatedMeta.getAttribute('content');
    var parts = dateStr.split('-');
    var date = new Date(+parts[0], +parts[1] - 1, +parts[2]);
    var formatted = date.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
    var el = document.createElement('p');
    el.className = 'last-updated';
    el.innerHTML = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M8 0a8 8 0 1 0 0 16A8 8 0 0 0 8 0zm.5 4.5v3.793l2.354 2.353a.5.5 0 0 1-.708.708l-2.5-2.5A.5.5 0 0 1 7.5 8.5v-4a.5.5 0 0 1 1 0z"/></svg>' +
      'Last updated: ' + formatted;
    var subtitle = article.querySelector('.subtitle');
    if (subtitle) {
      subtitle.parentNode.insertBefore(el, subtitle.nextSibling);
    }
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
})();
