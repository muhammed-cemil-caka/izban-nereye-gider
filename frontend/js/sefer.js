// İZBAN sefer saatleri — İzmir Büyükşehir Belediyesi açık veri servisi.
//
// https://openapi.izmir.bel.tr/api/izban/sefersaatleri/{kalkis}/{varis}
// Servis CORS'a açık (access-control-allow-origin: *), anahtar istemiyor.
//
// Kapsam: Aliağa – Tepeköy arası. Selçuk uzantısında (Sağlık, Belevi, Selçuk)
// servis boş liste döndürüyor; uydurmak yerine "veri yok" denir.
var SEFER_TABAN = 'https://openapi.izmir.bel.tr/api/izban/sefersaatleri';

/** "07:35:00" → dakika (07:35 → 455). Gece yarısı sonrası da doğru sıralanır. */
function saatiDakikayaCevir(metin) {
  var parca = String(metin || '').split(':');
  if (parca.length < 2) return null;
  var saat = Number(parca[0]);
  var dakika = Number(parca[1]);
  if (!isFinite(saat) || !isFinite(dakika)) return null;
  return saat * 60 + dakika;
}

/** "07:35:00" → "07:35" */
function saatiKisalt(metin) {
  return String(metin || '').slice(0, 5);
}

/**
 * İki durak arasındaki seferleri getirir.
 * @returns {Promise<Array<{kalkis: string, varis: string, kalkisDk: number}>>}
 */
function seferleriAl(kalkisId, varisId) {
  if (!kalkisId || !varisId) return Promise.resolve([]);

  return fetch(SEFER_TABAN + '/' + kalkisId + '/' + varisId)
    .then(function (yanit) {
      if (!yanit.ok) throw new Error('Sefer servisi yanıtı: ' + yanit.status);
      return yanit.json();
    })
    .then(function (liste) {
      if (!Array.isArray(liste)) return [];

      return liste
        .map(function (s) {
          return {
            kalkis: saatiKisalt(s.HareketSaati),
            varis: saatiKisalt(s.VarisSaati),
            kalkisDk: saatiDakikayaCevir(s.HareketSaati)
          };
        })
        .filter(function (s) { return s.kalkisDk !== null; })
        .sort(function (a, b) { return a.kalkisDk - b.kalkisDk; });
    });
}

/**
 * Şu andan sonraki ilk seferler.
 *
 * Gün sonunda liste boşalmasın diye başa sarılır: gece 23:50'de bakan
 * kullanıcıya ertesi günün ilk seferleri gösterilir.
 */
function siradakiSeferler(seferler, adet, simdiDk) {
  if (!seferler.length) return [];

  var an = typeof simdiDk === 'number' ? simdiDk : (function () {
    var d = new Date();
    return d.getHours() * 60 + d.getMinutes();
  })();

  var sonrakiler = seferler.filter(function (s) { return s.kalkisDk >= an; });
  var secilen = sonrakiler.slice(0, adet);

  // Gün bitmişse ertesi günün başından tamamla.
  if (secilen.length < adet) {
    secilen = secilen.concat(
      seferler.slice(0, adet - secilen.length).map(function (s) {
        return { kalkis: s.kalkis, varis: s.varis, kalkisDk: s.kalkisDk, ertesiGun: true };
      })
    );
  }

  return secilen.map(function (s) {
    return {
      kalkis: s.kalkis,
      varis: s.varis,
      ertesiGun: Boolean(s.ertesiGun),
      // Kalkışa kalan dakika; ertesi güne sarkanlarda gösterilmez.
      kalanDk: s.ertesiGun ? null : s.kalkisDk - an
    };
  });
}

if (typeof module !== 'undefined') {
  module.exports = {
    saatiDakikayaCevir: saatiDakikayaCevir,
    saatiKisalt: saatiKisalt,
    siradakiSeferler: siradakiSeferler
  };
}
