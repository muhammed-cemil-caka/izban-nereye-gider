#!/usr/bin/env node
/**
 * Tek doğruluk kaynağı: backend/veri/duraklar.json
 * Bu betik o dosyayı frontend ve mobile tarafına dağıtır.
 * Kullanım: node araclar/veri-dagit.js
 */
const fs = require('fs');
const path = require('path');

const kok = path.join(__dirname, '..');
const kaynakYolu = path.join(kok, 'backend', 'veri', 'duraklar.json');
const kaynak = JSON.parse(fs.readFileSync(kaynakYolu, 'utf8'));

// 1) Frontend: build adımı olmadan file:// üzerinden de çalışsın diye JS modülü olarak yazılır.
const frontendYolu = path.join(kok, 'frontend', 'js', 'duraklar.js');
// Klasik script olarak yazılır ki index.html sunucu olmadan, çift tıklayarak da açılabilsin
// (file:// üzerinde ES modülü import'ları tarayıcı tarafından engelleniyor).
const frontendIcerik =
  '// OTOMATİK ÜRETİLDİ — elle düzenlemeyin.\n' +
  '// Kaynak: backend/veri/duraklar.json — değişiklik sonrası: node araclar/veri-dagit.js\n' +
  'const HAT_VERISI = ' + JSON.stringify(kaynak, null, 2) + ';\n' +
  'const DURAKLAR = HAT_VERISI.duraklar;\n' +
  'if (typeof module !== \'undefined\') { module.exports = { HAT_VERISI, DURAKLAR }; }\n';
fs.writeFileSync(frontendYolu, frontendIcerik, 'utf8');

// 2) Mobile: Flutter asset olarak ham JSON.
const mobilKlasor = path.join(kok, 'mobile', 'assets');
fs.mkdirSync(mobilKlasor, { recursive: true });
fs.writeFileSync(
  path.join(mobilKlasor, 'duraklar.json'),
  JSON.stringify(kaynak, null, 2) + '\n',
  'utf8'
);

console.log(`${kaynak.duraklar.length} durak dağıtıldı:`);
console.log('  → frontend/js/duraklar.js');
console.log('  → mobile/assets/duraklar.json');
