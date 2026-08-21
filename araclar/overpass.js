/**
 * Overpass sorgularını çalıştıran ortak yardımcı.
 *
 * Neden bu kadar kalabalık: OpenStreetMap'in halka açık Overpass sunucuları
 * gönüllü altyapı ve üç ayrı şekilde sessizce yanlış veri döndürebiliyor —
 * üçü de veriyi silecek kadar tehlikeli:
 *
 *  1. Bölgesel aynalar. overpass.osm.ch yalnızca İsviçre çıkartmasını tutuyor;
 *     Türkiye sorgularına 200 + BOŞ sonuç dönüyor, yani "hiç yok" gibi
 *     görünüyor. Bu yüzden her sunucu, veri çekilmeden önce SONDA sorgusuyla
 *     sınanıyor: cevabı bilinen bir sorgu boş dönerse o sunucu atlanıyor.
 *  2. Zaman aşımı da 200 dönüyor; hata gövdedeki "remark" alanında yazıyor.
 *  3. Yoğunlukta boş gövde gelebiliyor.
 *
 * Bu yüzden boş yanıt hiçbir zaman geçerli sayılmaz.
 */
const SUNUCULAR = [
  'https://overpass-api.de/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.private.coffee/api/interpreter'
];

// Halkapınar çevresinde otobüs hattı olduğu biliniyor.
const SONDA_SORGUSU = `
  [out:json][timeout:60];
  node(around:400,38.43519,27.168837)["highway"="bus_stop"];
  rel(bn)["type"="route"]["route"="bus"];
  out tags;
`;

const KIMLIK = 'izban-nereye-gider/1.0 (data setup script)';

const bekle = (ms) => new Promise((c) => setTimeout(c, ms));

/** Sorguyu verilen sunucuda çalıştırır; sorun varsa null döner. */
async function sorgula(adres, sorgu, zamanAsimiMs = 300000) {
  try {
    const yanit = await fetch(adres, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': KIMLIK
      },
      body: 'data=' + encodeURIComponent(sorgu),
      signal: AbortSignal.timeout(zamanAsimiMs)
    });

    if (!yanit.ok) {
      console.log(`    ${yanit.status}`);
      return null;
    }

    const veri = await yanit.json();

    if (veri && typeof veri.remark === 'string' &&
        /error|timed out|out of memory/i.test(veri.remark)) {
      console.log(`    uyarı: ${veri.remark.slice(0, 70)}`);
      return null;
    }
    if (!veri || !Array.isArray(veri.elements) || !veri.elements.length) {
      console.log('    boş yanıt');
      return null;
    }

    return veri;
  } catch (sorun) {
    console.log(`    ${sorun.message}`);
    return null;
  }
}

/**
 * Çalışan ve Türkiye verisi tutan bir sunucu bulup sorguyu orada çalıştırır.
 * @param {string} sorgu
 * @param {number} [tur] kaç tur denenecek
 * @returns {Promise<object|null>}
 */
async function calistir(sorgu, turSayisi = 3) {
  for (let tur = 0; tur < turSayisi; tur++) {
    if (tur > 0) {
      const saniye = 30 * tur;
      console.log(`  ${saniye} sn bekleniyor, sonra ${tur + 1}. tur...`);
      await bekle(saniye * 1000);
    }

    for (const adres of SUNUCULAR) {
      const sunucu = new URL(adres).host;
      console.log(`  ${sunucu} sınanıyor...`);
      if (!(await sorgula(adres, SONDA_SORGUSU, 60000))) continue;

      console.log(`  ${sunucu} uygun, veri indiriliyor...`);
      const veri = await sorgula(adres, sorgu);
      if (veri) return veri;
    }
  }

  return null;
}

module.exports = { calistir, sorgula, bekle, SUNUCULAR, KIMLIK };
