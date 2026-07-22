'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"index.html": "e9c71dc63aed6ab76542122f19b0a587",
"/": "e9c71dc63aed6ab76542122f19b0a587",
"privacy.html": "7ff7c4be93051549221ffd179ea7bf4f",
"version.json": "4351f8cb3a5f0f10cdfee208e638c1cd",
"main.dart.js": "1984c8d3b03427dbbcd9adfe6dfef577",
"firebase-messaging-sw.js": "0aee37f114e26f62c460ce5bac3290e7",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"splash/img/dark-4x.png": "f15fd9e8a397cc62836da82768b20eec",
"splash/img/light-3x.png": "88c5da53c355c39c7d25946a0f76961c",
"splash/img/dark-2x.png": "595009d1bce66223b6cb5dce2b5228ff",
"splash/img/dark-1x.png": "1b67cc50ce82dbd2694ee03d448bfbe2",
"splash/img/light-4x.png": "f15fd9e8a397cc62836da82768b20eec",
"splash/img/light-2x.png": "595009d1bce66223b6cb5dce2b5228ff",
"splash/img/light-1x.png": "1b67cc50ce82dbd2694ee03d448bfbe2",
"splash/img/dark-3x.png": "88c5da53c355c39c7d25946a0f76961c",
"terms.html": "5751be3605f73fe7e92970d4dc09e025",
"oauth/google/callback.html": "489753c4909ce72222c6856eca3ee8a9",
"assets/packages/kakao_flutter_sdk_user/assets/images/icon_account_login.svg": "dd620fa3cc7d07464ed3f922d374c8c5",
"assets/packages/kakao_flutter_sdk_user/assets/images/icon_talk_login.svg": "f0ff106079063c1c73786e0a07da74ba",
"assets/packages/kakao_flutter_sdk_user/assets/images/logo_light.svg": "9d081a5a2d1089ccc1805ceca33d2cb9",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/fonts/MaterialIcons-Regular.otf": "615b008a997424fbbcabd9007751e6f0",
"assets/AssetManifest.bin": "fb7600a5c32c7464ef3f427e0f6cec87",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/NOTICES": "55ece8e55f23ebefc628cb33264da2a8",
"assets/FontManifest.json": "a1fbdba2a841769631bad0542f6a3d02",
"assets/AssetManifest.bin.json": "42efb25941e3e6e9742f108af933acff",
"assets/assets/logo_mark.png": "52d730de40126e968dbeae8844eb3466",
"assets/assets/fonts/BlackHanSans-Regular.ttf": "cc578387e3b6016b2c40847fc314cc2b",
"assets/assets/fonts/Jua-Regular.ttf": "501a644c20f33b8b21cc407fa6a51b75",
"assets/assets/fonts/DoHyeon-Regular.ttf": "7a1fcce495fba0b2009d3a484222abd1",
"assets/assets/logo_square.png": "296caed5a3b114857ca1545ba04c7415",
"assets/assets/legal/terms.md": "5ff13328f9ddfddfcbefc17b3f1ed83b",
"assets/assets/legal/privacy.md": "c5bd71513e4ab826abf6b4b0404d2357",
"assets/assets/logo.png": "42838f55fa48027f7755d381390b778f",
"favicon.png": "0b5ca33b7928bcd4386ee9d32b967d02",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"manifest.json": "e98b3092508ecccfa3ecb8434d9c0219",
"flutter_bootstrap.js": "189d4eaefc958ed889d7b82d60112dba",
"welcome.html": "1a723c09a17c3c2dead00f0618809973",
"icons/Icon-maskable-512.png": "c580f2502ec4bcd893ea5b3f99837a1c",
"icons/Icon-maskable-192.png": "c177d7c87e64ad2e88b63e75082c7fe3",
"icons/Icon-192.png": "c177d7c87e64ad2e88b63e75082c7fe3",
"icons/Icon-512.png": "c580f2502ec4bcd893ea5b3f99837a1c"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
