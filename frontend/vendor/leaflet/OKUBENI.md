# Leaflet 1.9.4

Harita kütüphanesi — <https://leafletjs.com>, BSD-2-Clause lisanslı.

CDN yerine depoya alındı: proje derleme adımı olmadan çalışıyor ve dış bir
servisin erişilebilirliğine bağlı kalmak istemiyoruz.

Güncellemek için:

```bash
SURUM=1.9.4
curl -sfL "https://unpkg.com/leaflet@$SURUM/dist/leaflet.js"  -o leaflet.js
curl -sfL "https://unpkg.com/leaflet@$SURUM/dist/leaflet.css" -o leaflet.css
for G in marker-icon.png marker-icon-2x.png marker-shadow.png layers.png layers-2x.png; do
  curl -sfL "https://unpkg.com/leaflet@$SURUM/dist/images/$G" -o "images/$G"
done
```

Döşemeler (tile) OpenStreetMap'ten gelir ve ODbL lisanslıdır; haritada
"© OpenStreetMap katkıcıları" ibaresi bulunmak zorundadır.

## leaflet-rotate 0.2.8

Haritayı gidiş yönüne çevirmek için (Leaflet bunu yerleşik desteklemiyor).
MIT lisanslı — <https://github.com/Raruto/leaflet-rotate>

```bash
curl -sfL "https://unpkg.com/leaflet-rotate@0.2.8/dist/leaflet-rotate-src.js" \
  -o leaflet-rotate.js
```
