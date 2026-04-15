(function () {
  document.addEventListener(
    'error',
    function (e) {
      var t = e.target;
      if (t.tagName !== 'IMG') return;
      t.classList.add('image-placeholder');
      var wrap = t.closest('.menu-item-image');
      if (wrap) wrap.classList.add('bg-image-error');
      t.style.display = 'none';
    },
    true
  );
})();
