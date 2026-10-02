'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"splash/img/dark-4x.png": "bf61a691110e96a55e6aa3d627cb89ca",
"splash/img/light-2x.png": "6848e2c60a5b6b479d30f0731d81ba95",
"splash/img/dark-1x.png": "205a949b3cb7711406d12ac799a6cc7f",
"splash/img/light-3x.png": "a878f604b84f6c6933ca9a816bcf139f",
"splash/img/dark-2x.png": "6848e2c60a5b6b479d30f0731d81ba95",
"splash/img/light-4x.png": "bf61a691110e96a55e6aa3d627cb89ca",
"splash/img/dark-3x.png": "a878f604b84f6c6933ca9a816bcf139f",
"splash/img/light-1x.png": "205a949b3cb7711406d12ac799a6cc7f",
"manifest.json": "a2e00265aca0bf0915bd1c411d28daf9",
"icons/Icon-512.png": "6848e2c60a5b6b479d30f0731d81ba95",
"icons/Icon-192.png": "56769b09f31b5cdafe6560e46d46c513",
"icons/Icon-maskable-192.png": "56769b09f31b5cdafe6560e46d46c513",
"icons/Icon-maskable-512.png": "6848e2c60a5b6b479d30f0731d81ba95",
"oauth/google/connected.html": "aed94bf66ae85e3e43b0f9aa420628f1",
"oauth/google/callback.html": "de47a54e4106bb7daee8b234d55e3c58",
"welcome.html": "1a723c09a17c3c2dead00f0618809973",
"flutter_bootstrap.js": "3113dd7be0af1cabacea0bf6de4a83be",
"assets/AssetManifest.bin.json": "296ea0c835a9d2bb6243256834ad9e12",
"assets/assets/logo.png": "d47c506f47c603f32467a4ddf37cc653",
"assets/assets/logo_3d_app_icon.png": "387dcc1fb45b99f442f3009234d73f6e",
"assets/assets/logo_mark.png": "9a3a7b1666813b9ec596585ac791fb33",
"assets/assets/3d/portfolio_binder_3d.png": "6e2d470a4a35bdb6c1d23538ed6e4a16",
"assets/assets/3d/announcement_3d.png": "7edd106baadfff6a141dda27454e6f8a",
"assets/assets/3d/ribbon_badge_3d.png": "0690c992d3a9ae4fcdbad3fcc30c1678",
"assets/assets/3d/study_books_3d.png": "35d122ff69b82e597f15b01ca351d171",
"assets/assets/3d/empty_nest_3d.png": "a32949196f4fc0ba4b8d4a4779f056f6",
"assets/assets/3d/calendar_3d.png": "acb55fe897fe9c1be60030d583a3e7b0",
"assets/assets/3d/achievement_star_3d.png": "2c7fcc861d67616fc864a591b0ff3638",
"assets/assets/3d/camera_memory_3d.png": "b81f0baa90fabdec3a291ab42906dcfb",
"assets/assets/3d/tips_lightbulb_3d.png": "27b9f155a1a2e9bddfbfcce761d60410",
"assets/assets/legal/terms.md": "5ff13328f9ddfddfcbefc17b3f1ed83b",
"assets/assets/legal/privacy.md": "c5bd71513e4ab826abf6b4b0404d2357",
"assets/assets/logo_3d_mark.png": "4e112dc951b84d0b8bf1875f90325423",
"assets/assets/app_icon_foreground.png": "3435da010782686220300381f4ef9fef",
"assets/assets/app_icon_1024.png": "ae0ca056f3c754902316513bca611c70",
"assets/assets/logo_square.png": "f3e7c48466c4d152dcaf95cbd50b3bb9",
"assets/assets/fonts/DoHyeon-Regular.ttf": "7a1fcce495fba0b2009d3a484222abd1",
"assets/assets/fonts/Jua-Regular.ttf": "501a644c20f33b8b21cc407fa6a51b75",
"assets/assets/fonts/BlackHanSans-Regular.ttf": "cc578387e3b6016b2c40847fc314cc2b",
"assets/NOTICES": "b4019b1adcf26b957d6b7d1d3a4f536e",
"assets/AssetManifest.bin": "e5c09a8e01630620ace6fb29b40fbb5f",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/kakao_flutter_sdk_user/assets/images/icon_talk_login.svg": "f0ff106079063c1c73786e0a07da74ba",
"assets/packages/kakao_flutter_sdk_user/assets/images/logo_light.svg": "9d081a5a2d1089ccc1805ceca33d2cb9",
"assets/packages/kakao_flutter_sdk_user/assets/images/icon_account_login.svg": "dd620fa3cc7d07464ed3f922d374c8c5",
"assets/FontManifest.json": "a1fbdba2a841769631bad0542f6a3d02",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/fonts/MaterialIcons-Regular.otf": "52c50378b3d83d440a8f0a079614f8c8",
"index.html": "25b90dda9f085e7ada1b4393cd4a0415",
"/": "25b90dda9f085e7ada1b4393cd4a0415",
"version.json": "d36e5bae8f833030e0859c20f5f2c106",
"firebase-messaging-sw.js": "0aee37f114e26f62c460ce5bac3290e7",
"terms.html": "5751be3605f73fe7e92970d4dc09e025",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"favicon.png": "770a9a9203060b762b033e0a489e3423",
"privacy.html": "7ff7c4be93051549221ffd179ea7bf4f",
"main.dart.js": "35e1a00ef21bafeb029543adf61585d2",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4"};
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
