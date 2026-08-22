// Dış servislere nereden gidileceğini belirler.
//
// İki yol var:
//
//   VEKİL   /api/...  — kendi Cloud Function'ımız. Yanıtlar Firebase Hosting
//                       CDN'inde önbelleklenir, dış servise avuç dolusu istek
//                       gider. Yüzlerce yolcuyu kaldıran yol bu.
//   DOĞRUDAN          — dış servisin kendisi. Yerel geliştirmede (file://,
//                       python sunucusu) ve vekil ayakta değilken kullanılır.
//
// Vekil bir kez denenir; olmadığı anlaşılırsa oturum boyunca doğrudan gidilir.
// Böylece yayına alınmamış bir kurulumda da uygulama çalışmaya devam eder.

var VEKIL_TABANI = '/api';

// Vekilin durumu: null = bilinmiyor, true = var, false = yok.
var vekilVarMi = null;

// Sunucudan servis edilmiyorsak (file://) vekil zaten yok.
if (typeof location !== 'undefined' && location.protocol === 'file:') {
  vekilVarMi = false;
}

/** Vekil bir kez yoklanır; sonuç oturum boyunca saklanır. */
function vekiliYokla() {
  if (vekilVarMi !== null) return Promise.resolve(vekilVarMi);

  return fetch(VEKIL_TABANI + '/saglik', { signal: zamanAsimi(4000) })
    .then(function (yanit) {
      vekilVarMi = yanit.ok;
      return vekilVarMi;
    })
    .catch(function () {
      vekilVarMi = false;
      return false;
    });
}

function zamanAsimi(ms) {
  return typeof AbortSignal !== 'undefined' && AbortSignal.timeout
    ? AbortSignal.timeout(ms)
    : undefined;
}

/**
 * Vekil varsa vekil adresini, yoksa doğrudan adresi döndürür.
 * @param {function} vekilAdres  () => string
 * @param {function} dogrudanAdres  () => string
 * @returns {Promise<string>}
 */
function servisAdresi(vekilAdres, dogrudanAdres) {
  return vekiliYokla().then(function (var_) {
    return var_ ? vekilAdres() : dogrudanAdres();
  });
}

if (typeof module !== 'undefined') {
  module.exports = { servisAdresi: servisAdresi };
}
