// İZBAN sefer saatleri — İzmir Büyükşehir Belediyesi açık veri servisi.
//
// https://openapi.izmir.bel.tr/api/izban/sefersaatleri/{kalkis}/{varis}
// Servis CORS'a açık (access-control-allow-origin: *), anahtar istemiyor.
//
// Servis YALNIZCA aktarmasız seferleri veriyor. Hat tek parça görünse de
// işletme üç dilime ayrılmış durumda ve dilimi aşan çiftler boş dönüyor:
//
//   Aliağa → Cumaovası   43 sefer      Aliağa → Torbalı    4 sefer
//   Aliağa → Tepeköy      4 sefer      Aliağa → Selçuk     0 sefer
//   Tepeköy → Selçuk     14 sefer      Halkapınar → Selçuk 0 sefer
//
// Kırılma noktaları ölçüldü: CUMAOVASI ve TEPEKÖY. Her durak bu ikisinin
// ikisine de bağlı (41 durağın tamamı denendi), dolayısıyla bu iki aktarmayla
// 41 × 40 çiftin hepsi kapsanıyor. Eskiden kapsam dışı çiftte "komşu durağa
// giden trenler" gösteriliyordu; artık gerçek aktarmalı yolculuk kuruluyor.
var SEFER_TABAN = 'https://openapi.izmir.bel.tr/api/izban/sefersaatleri';

// Servis dilimlerinin birleştiği duraklar — aktarma buralarda yapılır.
var SEFER_AKTARMA_DURAKLARI = ['cumaovasi', 'tepekoy'];

// Aktarma için gereken en az süre. Aynı istasyonda peron değiştirmek yeter;
// daha uzun tutmak yetişilebilecek bağlantıları eliyor.
var EN_AZ_AKTARMA_DK = 3;

// Bundan uzun bekleten bağlantı yolculuk sayılmaz: gece son trenle gelip
// sabahki ilk trene binmek "sıradaki tren" değildir.
var EN_COK_BEKLEME_DK = 180;

var GUN_DK = 24 * 60;

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

/** Bir seferin yolda geçirdiği süre; gece yarısını aşan seferlerde de doğru. */
function seferSuresi(sefer) {
  var varisDk = saatiDakikayaCevir(sefer.varis);
  if (varisDk === null) return 0;
  return ((varisDk - sefer.kalkisDk) % GUN_DK + GUN_DK) % GUN_DK;
}

/**
 * İki durak arasındaki AKTARMASIZ seferleri getirir.
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

// Tarife gün içinde değişmiyor; aynı çift için servis bir kez çağrılır.
var seferOnbellegi = {};

function seferleriAlOnbellekli(kalkisId, varisId) {
  var anahtar = kalkisId + '-' + varisId;
  if (!seferOnbellegi[anahtar]) {
    seferOnbellegi[anahtar] = seferleriAl(kalkisId, varisId)
      .catch(function (sorun) {
        // Başarısız istek önbelleğe yerleşmesin; kullanıcı yeniden deneyince
        // servise tekrar sorulsun.
        delete seferOnbellegi[anahtar];
        throw sorun;
      });
  }
  return seferOnbellegi[anahtar];
}

/**
 * Yolculuğun geçtiği durak zinciri: biniş, aradaki aktarma durakları, iniş.
 *
 * Aktarma durağı yolculuğun İÇİNDE değilse zincire girmez — Halkapınar'dan
 * Konak'a giderken Tepeköy'e uğramak anlamsız.
 */
function seferZinciri(duraklar, binisKod, inisKod) {
  var kodlar = duraklar.map(function (d) { return d.kod; });
  var binisSira = kodlar.indexOf(binisKod);
  var inisSira = kodlar.indexOf(inisKod);
  if (binisSira < 0 || inisSira < 0 || binisSira === inisSira) return null;

  var yon = inisSira > binisSira ? 1 : -1;
  var zincir = [duraklar[binisSira]];

  for (var sira = binisSira + yon; sira !== inisSira; sira += yon) {
    if (SEFER_AKTARMA_DURAKLARI.indexOf(duraklar[sira].kod) !== -1 &&
        duraklar[sira].izbanId) {
      zincir.push(duraklar[sira]);
    }
  }

  zincir.push(duraklar[inisSira]);
  return zincir.every(function (d) { return d.izbanId; }) ? zincir : null;
}

/**
 * Zincirdeki 0 → son arası artan tüm düğüm dizilişleri.
 *
 * İki aktarma durağı varsa dört yol çıkar: doğrudan, yalnızca birincisinden,
 * yalnızca ikincisinden ve ikisinden de. Hepsi denenip en iyisi seçilir —
 * hangisinin daha erken vardıracağı saate göre değişiyor.
 */
function zincirYollari(uzunluk) {
  var son = uzunluk - 1;
  var yollar = [];

  function ilerle(yol) {
    var suanki = yol[yol.length - 1];
    if (suanki === son) {
      yollar.push(yol.slice());
      return;
    }
    for (var sonraki = suanki + 1; sonraki <= son; sonraki++) {
      yol.push(sonraki);
      ilerle(yol);
      yol.pop();
    }
  }

  ilerle([0]);
  return yollar;
}

/** Verilen ana en yakın bağlantı: en az bekleme, gece yarısını da aşarak. */
function ilkBaglanti(seferler, hazirDk) {
  var enIyi = null;

  seferler.forEach(function (sefer) {
    var bekleme = ((sefer.kalkisDk - hazirDk) % GUN_DK + GUN_DK) % GUN_DK;
    // Yetişilemeyecek kadar yakınsa o tren bugün kaçtı, sıradakine bakılır.
    if (bekleme < EN_AZ_AKTARMA_DK) bekleme += GUN_DK;
    if (!enIyi || bekleme < enIyi.beklemeDk) {
      enIyi = { sefer: sefer, beklemeDk: bekleme, kalkisDk: hazirDk + bekleme };
    }
  });

  return enIyi;
}

/** Bir yolu, ilk seferi verilmiş hâlde sonuna kadar bağlar. */
function yolculuguKur(yol, zincir, kenarlar, ilkSefer) {
  var anVarisDk = ilkSefer.kalkisDk + seferSuresi(ilkSefer);
  var sonVaris = ilkSefer.varis;
  var aktarmalar = [];

  for (var adim = 1; adim < yol.length - 1; adim++) {
    var liste = kenarlar[yol[adim] + '-' + yol[adim + 1]] || [];
    var baglanti = ilkBaglanti(liste, anVarisDk);
    if (!baglanti || baglanti.beklemeDk > EN_COK_BEKLEME_DK) return null;

    aktarmalar.push({
      durak: zincir[yol[adim]].ad,
      inis: sonVaris,
      binis: baglanti.sefer.kalkis,
      beklemeDk: baglanti.beklemeDk
    });

    anVarisDk = baglanti.kalkisDk + seferSuresi(baglanti.sefer);
    sonVaris = baglanti.sefer.varis;
  }

  return {
    kalkis: ilkSefer.kalkis,
    varis: sonVaris,
    kalkisDk: ilkSefer.kalkisDk,
    varisDk: anVarisDk,
    aktarmalar: aktarmalar
  };
}

/**
 * Baskın olmayanları eler.
 *
 * Aynı Selçuk trenine binmek için 06:05'te de 06:57'de de yola çıkılabiliyor;
 * ikisi de 08:16'da varıyor. Erken kalkanı göstermek yolcuyu Tepeköy'de bir
 * saat bekletir. Daha geç kalkıp daha erken (ya da aynı anda) varan bir
 * yolculuk varsa diğeri listeden düşer.
 */
function baskinOlanlar(yolculuklar) {
  var sirali = yolculuklar.slice().sort(function (a, b) {
    return a.kalkisDk - b.kalkisDk || b.varisDk - a.varisDk;
  });

  var kalanlar = [];
  var enErkenVaris = Infinity;

  for (var i = sirali.length - 1; i >= 0; i--) {
    if (sirali[i].varisDk >= enErkenVaris) continue;
    enErkenVaris = sirali[i].varisDk;
    kalanlar.push(sirali[i]);
  }

  return kalanlar.reverse();
}

/**
 * Bir yolculuğun tüm seferleri — gerekiyorsa aktarmalı.
 *
 * @param {Array} duraklar hat sırasına göre durak listesi
 * @returns {Promise<Array>} kalkışa göre sıralı yolculuklar
 */
function yolculukSeferleriAl(duraklar, binisKod, inisKod) {
  var zincir = seferZinciri(duraklar, binisKod, inisKod);
  if (!zincir) return Promise.resolve([]);

  var kenarlar = {};
  var istekler = [];
  var basarili = 0;

  for (var i = 0; i < zincir.length; i++) {
    for (var j = i + 1; j < zincir.length; j++) {
      istekler.push(function (i, j) {
        return seferleriAlOnbellekli(zincir[i].izbanId, zincir[j].izbanId)
          .then(function (liste) {
            kenarlar[i + '-' + j] = liste;
            basarili++;
          })
          .catch(function () { kenarlar[i + '-' + j] = []; });
      }(i, j));
    }
  }

  return Promise.all(istekler).then(function () {
    // Tek bir istek bile geçmediyse bu "sefer yok" değil, "servise
    // ulaşılamadı" demektir; çağıran ikisini ayırabilsin.
    if (!basarili) throw new Error('Sefer servisine ulaşılamadı.');

    var yolculuklar = [];
    zincirYollari(zincir.length).forEach(function (yol) {
      (kenarlar[yol[0] + '-' + yol[1]] || []).forEach(function (ilk) {
        var yolculuk = yolculuguKur(yol, zincir, kenarlar, ilk);
        if (yolculuk) yolculuklar.push(yolculuk);
      });
    });

    return baskinOlanlar(yolculuklar);
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
        return Object.assign({}, s, { ertesiGun: true });
      })
    );
  }

  return secilen.map(function (s) {
    return {
      kalkis: s.kalkis,
      varis: s.varis,
      aktarmalar: s.aktarmalar || [],
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
    seferSuresi: seferSuresi,
    seferZinciri: seferZinciri,
    zincirYollari: zincirYollari,
    ilkBaglanti: ilkBaglanti,
    yolculuguKur: yolculuguKur,
    baskinOlanlar: baskinOlanlar,
    siradakiSeferler: siradakiSeferler
  };
}
