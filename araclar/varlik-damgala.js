#!/usr/bin/env node
/**
 * frontend/index.html içindeki js/css bağlantılarına içerik damgası basar:
 *
 *   <script src="js/uygulama.js">  →  <script src="js/uygulama.js?s=8f3a1c2d">
 *
 * Damga dosyanın içeriğinden üretilir. Dosya değişince damga değişir, tarayıcı
 * da onu yeni bir adres sayıp yeniden indirir. Derleme adımı olmayan bir sitede
 * önbellek sorununu çözmenin en basit yolu bu.
 *
 * Kullanım: node araclar/varlik-damgala.js
 * (veri-dagit.js bunu kendiliğinden çağırır.)
 */
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const kok = path.join(__dirname, '..', 'frontend');
const sayfaYolu = path.join(kok, 'index.html');

function damga(dosyaYolu) {
  const icerik = fs.readFileSync(dosyaYolu);
  return crypto.createHash('sha256').update(icerik).digest('hex').slice(0, 8);
}

function damgala() {
  let sayfa = fs.readFileSync(sayfaYolu, 'utf8');
  const degisenler = [];

  // src="js/..." ve href="css/..." bağlantıları; varsa eski damga atılır.
  sayfa = sayfa.replace(
    /(src|href)="((?:js|css)\/[^"?]+)(\?s=[^"]*)?"/g,
    (tam, nitelik, dosya) => {
      const tamYol = path.join(kok, dosya);
      if (!fs.existsSync(tamYol)) {
        console.warn(`  uyarı: ${dosya} bulunamadı, atlandı`);
        return tam;
      }
      const yeni = damga(tamYol);
      degisenler.push(`${dosya} → ${yeni}`);
      return `${nitelik}="${dosya}?s=${yeni}"`;
    }
  );

  fs.writeFileSync(sayfaYolu, sayfa, 'utf8');
  return degisenler;
}

if (require.main === module) {
  const sonuc = damgala();
  console.log(`${sonuc.length} varlık damgalandı:`);
  sonuc.forEach((s) => console.log('  ' + s));
}

module.exports = { damgala };
