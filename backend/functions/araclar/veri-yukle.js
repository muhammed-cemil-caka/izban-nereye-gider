#!/usr/bin/env node
/**
 * backend/veri/duraklar.json dosyasını Firestore'a yükler.
 *
 * Emülatöre yüklemek için:
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 node araclar/veri-yukle.js
 *
 * Gerçek projeye yüklemek için (servis hesabı anahtarıyla):
 *   GOOGLE_APPLICATION_CREDENTIALS=/yol/anahtar.json node araclar/veri-yukle.js
 */
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const kaynakYolu = path.join(__dirname, '..', '..', 'veri', 'duraklar.json');
const kaynak = JSON.parse(fs.readFileSync(kaynakYolu, 'utf8'));

if (!process.env.FIRESTORE_EMULATOR_HOST && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Kimlik bulunamadı. FIRESTORE_EMULATOR_HOST veya GOOGLE_APPLICATION_CREDENTIALS ayarlayın.');
  process.exit(1);
}

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'izban-nereye-gider' });
const veritabani = admin.firestore();

async function yukle() {
  const toplu = veritabani.batch();

  kaynak.duraklar.forEach((durak, sira) => {
    const belge = veritabani.collection('duraklar').doc(durak.kod);
    toplu.set(belge, { ...durak, sira });
  });

  toplu.set(veritabani.collection('hat').doc('bilgi'), {
    ...kaynak.hat,
    surum: kaynak.surum,
    guncellemeTarihi: kaynak.guncellemeTarihi,
    durakSayisi: kaynak.duraklar.length
  });

  await toplu.commit();
  console.log(`${kaynak.duraklar.length} durak Firestore'a yüklendi.`);
}

yukle().catch((sorun) => {
  console.error('Yükleme başarısız:', sorun);
  process.exit(1);
});
