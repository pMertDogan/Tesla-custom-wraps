/*
 * Bridge between the Flutter studio and the <model-viewer> element.
 *
 * Two things live here:
 *
 * - `load()` downloads the model-viewer bundle and its Draco decoder the first
 *   time the studio opens the 3D tab. Keeping it out of index.html means the
 *   home page and the 2D studio do not pay for 1.1 MB of viewer they never
 *   use.
 * - `attach()` hands a prepared GLB (the vehicle model with the wrap already
 *   written into its paint material) to an element Flutter created, through an
 *   object URL instead of a second copy of the bytes in the Flutter layer.
 */
(function () {
  'use strict';

  var loading = null;
  var objectUrls = [];

  /*
   * model-viewer reads `window.ModelViewerElement` when its script evaluates,
   * so the decoder location has to be set before the script is injected. The
   * Draco decoder is served from this site; without this the viewer would
   * fetch it from a Google CDN.
   */
  window.ModelViewerElement = window.ModelViewerElement || {};
  window.ModelViewerElement.dracoDecoderLocation = 'vendor/draco/';

  /** Downloads the viewer once and resolves when the element is defined. */
  function load() {
    if (window.customElements && customElements.get('model-viewer')) {
      return Promise.resolve();
    }
    if (loading) {
      return loading;
    }

    loading = new Promise(function (resolve, reject) {
      var script = document.createElement('script');
      script.src = 'vendor/model-viewer.min.js';
      script.async = true;
      script.onload = function () {
        if (window.customElements && customElements.get('model-viewer')) {
          resolve();
        } else {
          reject(new Error('model-viewer did not register'));
        }
      };
      script.onerror = function () {
        loading = null;
        reject(new Error('model-viewer could not be downloaded'));
      };
      document.head.appendChild(script);
    });

    return loading;
  }

  function releaseAll(keep) {
    var kept = [];
    for (var i = 0; i < objectUrls.length; i++) {
      if (objectUrls[i] === keep) {
        kept.push(objectUrls[i]);
      } else {
        URL.revokeObjectURL(objectUrls[i]);
      }
    }
    objectUrls = kept;
  }

  /**
   * Points an element at a GLB.
   *
   * @param {HTMLElement} element the <model-viewer> created by Flutter
   * @param {Uint8Array} bytes the patched GLB
   * @param {string} background CSS colour for the stage
   */
  function attach(element, bytes, background) {
    var blob = new Blob([bytes], { type: 'model/gltf-binary' });
    var url = URL.createObjectURL(blob);

    element.setAttribute('camera-controls', '');
    element.setAttribute('touch-action', 'pan-y');
    element.setAttribute('interaction-prompt', 'auto');
    element.setAttribute('shadow-intensity', '0.6');
    element.setAttribute('shadow-softness', '0.8');
    element.setAttribute('exposure', '1.1');
    element.setAttribute('environment-image', 'neutral');
    element.setAttribute('alt', '3D preview of the vehicle wrap');
    element.style.width = '100%';
    element.style.height = '100%';
    element.style.backgroundColor = background || 'transparent';
    element.setAttribute('src', url);

    releaseAll(url);
  }

  window.studioViewer = { load: load, attach: attach };
})();
