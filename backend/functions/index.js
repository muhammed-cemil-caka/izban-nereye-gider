/**
 * İZBAN Nereye Gider? — HTTP API
 * Uç noktalar:
 *   GET /api/duraklar                       → tüm duraklar
 *   GET /api/yolculuk?binis=..&inis=..      → yolculuk özeti
 *   GET /api/saglik                         → servis durumu
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

    yanit.status(404).json({ hata: 'Böyle bir uç nokta yok.' });
  } catch (sorun) {
    console.error('API hatası:', sorun);
    yanit.status(500).json({ hata: 'Sunucu hatası.' });
  }
});
