/*
 * File input bridge for the Flutter studio.
 *
 * Flutter web cannot read a `File` object directly, so this helper opens a
 * native file picker and resolves with plain data: `{name, base64}`. The
 * studio decodes the base64 into bytes and keeps them in the layer stack.
 */
(function () {
  'use strict';

  function pickImage(anyFile) {
    return new Promise(function (resolve) {
      var input = document.createElement('input');
      input.type = 'file';
      input.accept = anyFile ? '*/*' : 'image/png,image/jpeg,image/webp,image/gif';
      input.style.position = 'fixed';
      input.style.left = '-10000px';
      input.style.opacity = '0';

      var settled = false;
      function finish(value) {
        if (settled) return;
        settled = true;
        input.remove();
        resolve(value);
      }

      input.addEventListener('change', function () {
        var file = input.files && input.files[0];
        if (!file) {
          finish(null);
          return;
        }
        var reader = new FileReader();
        reader.onload = function () {
          var result = String(reader.result || '');
          var comma = result.indexOf(',');
          finish({
            name: file.name || 'logo',
            base64: comma >= 0 ? result.slice(comma + 1) : result,
            size: file.size || 0,
            type: file.type || ''
          });
        };
        reader.onerror = function () {
          finish(null);
        };
        reader.readAsDataURL(file);
      });

      // A cancelled dialog fires no event in some browsers; the window focus
      // coming back is the only signal. The promise stays pending otherwise,
      // which is harmless: the caller treats null as "nothing picked".
      window.addEventListener(
        'focus',
        function () {
          window.setTimeout(function () {
            if (!input.files || input.files.length === 0) finish(null);
          }, 500);
        },
        { once: true }
      );

      document.body.appendChild(input);
      input.click();
    });
  }

  window.studioFiles = { pickImage: pickImage };
})();
