// OTOMATİK ÜRETİLDİ — elle düzenlemeyin.
// Kaynak: backend/veri/duraklar.json — değişiklik sonrası: node araclar/veri-dagit.js
const HAT_VERISI = {
  "surum": "1.0.0",
  "guncellemeTarihi": "2026-08-18",
  "uyari": "Durak sırası, ilçe ve aktarma bilgileri ile süreler TAHMİNİDİR. Yayına almadan önce izban.com.tr üzerinden doğrulanmalıdır.",
  "hat": {
    "ad": "İZBAN Banliyö Hattı",
    "kuzeyUcu": "Aliağa",
    "guneyUcu": "Selçuk"
  },
  "duraklar": [
    {
      "kod": "aliaga",
      "ad": "Aliağa",
      "ilce": "Aliağa",
      "dakika": 0,
      "aktarma": []
    },
    {
      "kod": "bicerova",
      "ad": "Biçerova",
      "ilce": "Aliağa",
      "dakika": 8,
      "aktarma": []
    },
    {
      "kod": "hatundere",
      "ad": "Hatundere",
      "ilce": "Menemen",
      "dakika": 13,
      "aktarma": []
    },
    {
      "kod": "menemen",
      "ad": "Menemen",
      "ilce": "Menemen",
      "dakika": 21,
      "aktarma": [
        "Şehirlerarası otobüs"
      ]
    },
    {
      "kod": "egekent",
      "ad": "Egekent",
      "ilce": "Menemen",
      "dakika": 26,
      "aktarma": []
    },
    {
      "kod": "ulukent",
      "ad": "Ulukent",
      "ilce": "Menemen",
      "dakika": 30,
      "aktarma": []
    },
    {
      "kod": "cigli",
      "ad": "Çiğli",
      "ilce": "Çiğli",
      "dakika": 35,
      "aktarma": []
    },
    {
      "kod": "mavisehir",
      "ad": "Mavişehir",
      "ilce": "Karşıyaka",
      "dakika": 40,
      "aktarma": [
        "Karşıyaka Tramvayı"
      ]
    },
    {
      "kod": "karsiyaka",
      "ad": "Karşıyaka",
      "ilce": "Karşıyaka",
      "dakika": 44,
      "aktarma": [
        "Karşıyaka Tramvayı",
        "Vapur"
      ]
    },
    {
      "kod": "alaybey",
      "ad": "Alaybey",
      "ilce": "Karşıyaka",
      "dakika": 47,
      "aktarma": []
    },
    {
      "kod": "turan",
      "ad": "Turan",
      "ilce": "Bayraklı",
      "dakika": 50,
      "aktarma": []
    },
    {
      "kod": "naldoken",
      "ad": "Naldöken",
      "ilce": "Bayraklı",
      "dakika": 53,
      "aktarma": []
    },
    {
      "kod": "halkapinar",
      "ad": "Halkapınar",
      "ilce": "Konak",
      "dakika": 58,
      "aktarma": [
        "Metro",
        "Konak Tramvayı",
        "Otobüs aktarma merkezi"
      ]
    },
    {
      "kod": "alsancak",
      "ad": "Alsancak",
      "ilce": "Konak",
      "dakika": 63,
      "aktarma": [
        "Konak Tramvayı",
        "Vapur"
      ]
    },
    {
      "kod": "kemer",
      "ad": "Kemer",
      "ilce": "Konak",
      "dakika": 67,
      "aktarma": []
    },
    {
      "kod": "sirinyer",
      "ad": "Şirinyer",
      "ilce": "Buca",
      "dakika": 72,
      "aktarma": []
    },
    {
      "kod": "gaziemir",
      "ad": "Gaziemir",
      "ilce": "Gaziemir",
      "dakika": 78,
      "aktarma": []
    },
    {
      "kod": "sarnic",
      "ad": "Sarnıç",
      "ilce": "Gaziemir",
      "dakika": 83,
      "aktarma": []
    },
    {
      "kod": "havalimani",
      "ad": "Adnan Menderes Havalimanı",
      "ilce": "Gaziemir",
      "dakika": 88,
      "aktarma": [
        "Havalimanı"
      ]
    },
    {
      "kod": "cumaovasi",
      "ad": "Cumaovası",
      "ilce": "Menderes",
      "dakika": 93,
      "aktarma": []
    },
    {
      "kod": "develi",
      "ad": "Develi",
      "ilce": "Menderes",
      "dakika": 98,
      "aktarma": []
    },
    {
      "kod": "tekeli",
      "ad": "Tekeli",
      "ilce": "Menderes",
      "dakika": 102,
      "aktarma": []
    },
    {
      "kod": "pancar",
      "ad": "Pancar",
      "ilce": "Torbalı",
      "dakika": 107,
      "aktarma": []
    },
    {
      "kod": "kuscuburun",
      "ad": "Kuşçuburun",
      "ilce": "Torbalı",
      "dakika": 112,
      "aktarma": []
    },
    {
      "kod": "torbali",
      "ad": "Torbalı",
      "ilce": "Torbalı",
      "dakika": 118,
      "aktarma": []
    },
    {
      "kod": "tepekoy",
      "ad": "Tepeköy",
      "ilce": "Torbalı",
      "dakika": 123,
      "aktarma": []
    },
    {
      "kod": "bagarasi",
      "ad": "Bağarası",
      "ilce": "Selçuk",
      "dakika": 131,
      "aktarma": []
    },
    {
      "kod": "selcuk",
      "ad": "Selçuk",
      "ilce": "Selçuk",
      "dakika": 140,
      "aktarma": [
        "Şehirlerarası otobüs"
      ]
    }
  ]
};
const DURAKLAR = HAT_VERISI.duraklar;
if (typeof module !== 'undefined') { module.exports = { HAT_VERISI, DURAKLAR }; }
