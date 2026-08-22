/**
 * İZBAN Nereye Gider? — HTTP API
 *
 * Uç noktalar:
 *   GET /api/duraklar                        → tüm duraklar
 *   GET /api/yolculuk?binis=..&inis=..       → yolculuk özeti
 *   GET /api/sefer/:kalkis/:varis            → İZBAN sefer saatleri (vekil)
 *   GET /api/rota?baslangic=..&bitis=..&kip= → OSRM rotası (vekil)
 *   GET /api/mesafe?baslangic=..&hedefler=.. → OSRM mesafe matrisi (vekil)
 *   GET /api/saglik                          → servis durumu
 *
 * VEKİL UÇLARI NEDEN VAR
 *
 * İstemciler dış servisleri doğrudan çağırıyordu. Tek kullanıcıda sorun yok;
 * yüzlerce yolcuda üç sorun birden çıkıyor:
 *
 *   1. Yük — her kullanıcı aynı sefer tarifesini ayrı ayrı çekiyor. 500 kişi
 *      × 6 istek = 3000 istek; oysa tarife günde bir değişiyor.
 *   2. Engellenme — FOSSGIS'in gönüllü OSRM sunucusu Referer'a bakarak
 *      sınırlıyor. Ölçüldü: 400 ms aralıkla 190 istekte bağlantı kabul
 *      etmez oldu.
 *   3. Anahtar — ücretli bir sağlayıcıya geçince anahtar istemcide görünür.
 *
 * Vekil üçünü de çözüyor. Asıl kazanç Cloud Functions değil, **Firebase
 * Hosting'in CDN'i**: yanıtlar `Cache-Control` ile işaretlendiği için aynı
 * istek ikinci kez fonksiyona bile uğramıyor. Yüzlerce kullanıcı → avuç dolusu
 * dış istek.
 *
 * Sağlayıcı değişirse yalnızca burası değişir; istemcilere dokunulmaz.
 */
const { onRequest } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

setGlobalOptions({ region: 'europe-west1', maxInstances: 10 });
admin.initializeApp();

const veritabani = admin.firestore();

/** Durakları Firestore'dan sıralı biçimde okur. */
async function duraklariGetir() {
  const anlik = await veritabani.collection('duraklar').orderBy('sira').get();
  return anlik.docs.map((belge) => belge.data());
}

function sureBicimle(dakika) {
  if (dakika < 60) return `${dakika} dk`;
  const saat = Math.floor(dakika / 60);
  const kalan = dakika % 60;
  return kalan === 0 ? `${saat} sa` : `${saat} sa ${kalan} dk`;
}

function yolculukHesapla(duraklar, binisKod, inisKod) {
  const binisIndeks = duraklar.findIndex((d) => d.kod === binisKod);
  const inisIndeks = duraklar.findIndex((d) => d.kod === inisKod);

  if (binisIndeks === -1 || inisIndeks === -1) {
    return { gecerli: false, hata: 'Durak bulunamadı.' };
  }
  if (binisIndeks === inisIndeks) {
    return { gecerli: false, hata: 'Biniş ve iniş durağı aynı olamaz.' };
  }

  const guneyeGidiyor = inisIndeks > binisIndeks;
  const ilk = Math.min(binisIndeks, inisIndeks);
  const son = Math.max(binisIndeks, inisIndeks);

  let guzergah = duraklar.slice(ilk, son + 1);
  if (!guneyeGidiyor) guzergah = guzergah.reverse();

  const dakika = Math.abs(duraklar[inisIndeks].dakika - duraklar[binisIndeks].dakika);

  return {
    gecerli: true,
    binis: duraklar[binisIndeks],
    inis: duraklar[inisIndeks],
    yon: guneyeGidiyor ? 'guney' : 'kuzey',
    yonEtiketi: guneyeGidiyor
      ? `${duraklar[duraklar.length - 1].ad} yönü`
      : `${duraklar[0].ad} yönü`,
    durakSayisi: son - ilk,
    dakika,
    sureMetni: sureBicimle(dakika),
    guzergah,
    aktarmalar: guzergah
      .filter((d) => Array.isArray(d.aktarma) && d.aktarma.length > 0)
      .map((d) => ({ ad: d.ad, hatlar: d.aktarma }))
  };
}

/* ---------- Dış servis vekilleri ---------- */

const IZBAN_SEFER = 'https://openapi.izmir.bel.tr/api/izban/sefersaatleri';

const OSRM = {
  yuruyus: 'https://routing.openstreetmap.de/routed-foot',
  araba: 'https://routing.openstreetmap.de/routed-car'
};
const OSRM_PROFIL = { yuruyus: 'foot', araba: 'driving' };

const DIS_ZAMAN_ASIMI_MS = 12000;

// Sıcak örnekte tekrar eden istekler dışarı hiç çıkmasın. CDN'in altındaki
// ikinci katman: CDN soğukken ya da farklı bölgeden gelen isteklerde işe yarar.
const bellek = new Map();
const BELLEK_SINIRI = 500;

function bellektenAl(anahtar) {
  const kayit = bellek.get(anahtar);
  if (!kayit || kayit.bitis < Date.now()) return null;
  return kayit.veri;
}

function bellegeKoy(anahtar, veri, saniye) {
  if (bellek.size >= BELLEK_SINIRI) bellek.delete(bellek.keys().next().value);
  bellek.set(anahtar, { veri, bitis: Date.now() + saniye * 1000 });
}

/** Dış servisten JSON; zaman aşımlı ve bir kez yeniden denemeli. */
async function disServis(adres, deneme = 0) {
  try {
    const yanit = await fetch(adres, {
      signal: AbortSignal.timeout(DIS_ZAMAN_ASIMI_MS),
      headers: { 'User-Agent': 'izban-nereye-gider (+https://izban-nereye-gider.web.app)' }
    });
    if (yanit.ok) return await yanit.json();
    if (yanit.status >= 400 && yanit.status < 500) return null;
    throw new Error(`durum ${yanit.status}`);
  } catch (sorun) {
    if (deneme >= 1) throw sorun;
    await new Promise((c) => setTimeout(c, 500));
    return disServis(adres, deneme + 1);
  }
}

/** "27.1234,38.4321" → geçerliyse aynı metin, değilse null. */
function koordinat(metin) {
  const e = /^(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)$/.exec(String(metin || ''));
  if (!e) return null;
  const boylam = Number(e[1]);
  const enlem = Number(e[2]);
  if (Math.abs(boylam) > 180 || Math.abs(enlem) > 90) return null;
  // Beş hane ≈ 1 m. Yuvarlamak önbellek isabetini artırıyor: aynı durak için
  // gelen istekler tek anahtarda toplanıyor.
  return `${boylam.toFixed(5)},${enlem.toFixed(5)}`;
}

/**
 * Vekil yanıtı yazar.
 * @param {number} cdnSaniye CDN'de ne kadar tutulacağı
 */
async function vekilYanit(yanit, anahtar, adresUret, cdnSaniye) {
  const hazir = bellektenAl(anahtar);
  if (hazir) {
    yanit.set('Cache-Control', `public, max-age=${cdnSaniye}, s-maxage=${cdnSaniye}`);
    yanit.set('X-Onbellek', 'bellek');
    yanit.json(hazir);
    return;
  }

  const veri = await disServis(adresUret());
  if (veri === null) {
    yanit.status(502).json({ hata: 'Dış servis yanıt vermedi.' });
    return;
  }

  bellegeKoy(anahtar, veri, cdnSaniye);
  // stale-while-revalidate: süre dolduğunda kullanıcı beklemez, CDN eski
  // yanıtı verip arkada tazeler.
  yanit.set(
    'Cache-Control',
    `public, max-age=${cdnSaniye}, s-maxage=${cdnSaniye}, stale-while-revalidate=86400`
  );
  yanit.set('X-Onbellek', 'yeni');
  yanit.json(veri);
}

exports.api = onRequest({ cors: true }, async (istek, yanit) => {
  // Bu API salt okunur; yalnızca GET kabul edilir.
  if (istek.method !== 'GET') {
    yanit.status(405).json({ hata: 'Yalnızca GET destekleniyor.' });
    return;
  }

  const yol = istek.path.replace(/^\/api/, '') || '/';

  try {
    if (yol === '/saglik' || yol === '/') {
      yanit.json({ durum: 'ayakta', zaman: new Date().toISOString() });
      return;
    }

    if (yol === '/duraklar') {
      const duraklar = await duraklariGetir();
      yanit.set('Cache-Control', 'public, max-age=3600');
      yanit.json({ sayi: duraklar.length, duraklar });
      return;
    }

    if (yol === '/yolculuk') {
      const { binis, inis } = istek.query;
      if (!binis || !inis) {
        yanit.status(400).json({ hata: 'binis ve inis parametreleri zorunludur.' });
        return;
      }
      const duraklar = await duraklariGetir();
      const sonuc = yolculukHesapla(duraklar, String(binis), String(inis));
      yanit.status(sonuc.gecerli ? 200 : 400).json(sonuc);
      return;
    }

    // Sefer saatleri — tarife gün içinde değişmiyor, 6 saat tutulur.
    const sefer = /^\/sefer\/(\d+)\/(\d+)$/.exec(yol);
    if (sefer) {
      await vekilYanit(
        yanit,
        `sefer:${sefer[1]}:${sefer[2]}`,
        () => `${IZBAN_SEFER}/${sefer[1]}/${sefer[2]}`,
        6 * 3600
      );
      return;
    }

    // Rota — yol geometrisi neredeyse hiç değişmiyor, 7 gün tutulur.
    if (yol === '/rota') {
      const baslangic = koordinat(istek.query.baslangic);
      const bitis = koordinat(istek.query.bitis);
      const kip = istek.query.kip === 'araba' ? 'araba' : 'yuruyus';
      if (!baslangic || !bitis) {
        yanit.status(400).json({ hata: 'baslangic ve bitis "boylam,enlem" olmalı.' });
        return;
      }
      await vekilYanit(
        yanit,
        `rota:${kip}:${baslangic}:${bitis}`,
        () => `${OSRM[kip]}/route/v1/${OSRM_PROFIL[kip]}/${baslangic};${bitis}` +
              '?overview=full&geometries=geojson&steps=true',
        7 * 24 * 3600
      );
      return;
    }

    // Mesafe matrisi — aynı sabitlik.
    if (yol === '/mesafe') {
      const baslangic = koordinat(istek.query.baslangic);
      const hedefler = String(istek.query.hedefler || '').split(';').map(koordinat);
      const kip = istek.query.kip === 'araba' ? 'araba' : 'yuruyus';
      if (!baslangic || !hedefler.length || hedefler.some((h) => h === null)) {
        yanit.status(400).json({ hata: 'baslangic ve hedefler "boylam,enlem" olmalı.' });
        return;
      }
      if (hedefler.length > 25) {
        yanit.status(400).json({ hata: 'En çok 25 hedef.' });
        return;
      }
      const noktalar = [baslangic, ...hedefler].join(';');
      await vekilYanit(
        yanit,
        `mesafe:${kip}:${noktalar}`,
        () => `${OSRM[kip]}/table/v1/${OSRM_PROFIL[kip]}/${noktalar}` +
              '?sources=0&annotations=distance,duration',
        7 * 24 * 3600
      );
      return;
    }

    yanit.status(404).json({ hata: 'Böyle bir uç nokta yok.' });
  } catch (sorun) {
    console.error('API hatası:', sorun);
    yanit.status(500).json({ hata: 'Sunucu hatası.' });
  }
});
