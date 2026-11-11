# Proje: Kanyon Jet Yarışı (Godot 4, Mobil) — Claude Code Spec

Bu dosya hem başlangıç prompt'u hem de projenin yaşayan spec'i. Claude Code'a:
`SPEC.md dosyasını oku ve M0'dan başla.`

---

## 1. Hedef

Dar bir kanyonda alçak uçuşla yapılan **arcade jet yarışı**. Oyuncu + 5 bota karşı yarış, ayrıca time-trial modu. Trackmania'nın tur/sektör/madalya sistemi, süpersonik uçak ile.

**Platform: Android ve iOS telefon. Landscape (yatay) yönelim.**
Oyun hissi önceliği: **hız ve tek parmakla oynanabilirlik**. Grafik detayı değil.

> Yönelim kararı: yatay seçtim çünkü HUD referansı geniş formatlı ve kanyonun iki duvarını birden görmek oynanış için şart. Dikey/tek el isteniyorsa söyle, HUD yerleşimi ve kanyon genişliği buna göre değişir.

## 2. Teknik kısıtlar

- **Godot 4.4+**, **Mobile** rendering method (Forward+ değil, Compatibility değil)
- **GDScript** (C# kullanma — mobil export'ta ekstra toolchain derdi)
- Hedef cihaz: orta segment Android (Snapdragon 7-serisi sınıfı), **60 fps**, 30 fps fallback ayarı
- Yatay (landscape), `viewport` stretch mode, 3D render scale 0.8 + FSR 1.0
- Tüm art placeholder olarak başlar: kod ile üretilmiş primitive'ler. **Dışarıdan asset indirmeye çalışma**, internet erişimi olmadığını varsay.
- Fizik: `RigidBody3D` ve `VehicleBody3D` **kullanılmayacak**. Arcade uçuş modeli elle entegre edilecek.
- Her milestone sonunda proje `godot --headless --quit` ile hatasız açılmalı

### Mobil performans bütçesi (her milestone'da ihlal edilmeyecek)

| Metrik | Limit |
|---|---|
| Draw call | < 100 |
| Ekrandaki üçgen | < 150k |
| Gerçek zamanlı gölge | Yok. Uçaklar için blob shadow decal |
| Transparan overdraw | Minimum — tile GPU'ların katili |
| Fragment shader'da noise | Yasak (bkz. M6) |
| Fullscreen post-process | En fazla 1 geçiş |
| MSAA | Kapalı, FXAA yeterli |

## 3. Referans ölçümler

Bir oynanış videosundan (PC versiyonu) okunan değerler:

| Değer | Aralık |
|---|---|
| Hız | 630–1250 knot (324–643 m/s) |
| Mach | 1.09 – 1.85 |
| G kuvveti | normal dönüş 4.5–5.5, agresif 8.4 |
| Duvara sürtme cezası | yaklaşık %20 hız kaybı |
| Tur | 4 sektör, referans süre 55.662 s |

**Mobil için bunları doğrudan kullanma.** Dokunmatik kontrolle 600 m/s'de 50 metrelik kanyon oynanamaz. Başlangıç ayarı:

- Gerçek hız **220–380 m/s**, ama HUD'da knot ve Mach olarak gösterilsin (hava hissi bozulmasın)
- Kanyon genişliği **80–120 m**, duvar yüksekliği 60–100 m
- G limiti 9, ama dokunmatikte bu sınıra zaten zor varılır
- Zorluk arttıkça kanyon daralsın, hız artsın — aynı pisti yeniden kullanmanın en ucuz yolu

## 4. Kontrol şeması (mobil)

Klavye/joystick şeması **yok**. Dokunmatik tasarım:

- **Varsayılan: otomatik gaz.** Uçak hep tam gazda. Mobil yarış oyunlarının standardı, bir parmağı serbest bırakır.
- **Sol başparmak: sanal stick** — yukarı/aşağı = pitch, sağa/sola = roll. Ekranın sol yarısına basıldığı yerde belirir (sabit konumlu değil, "floating stick").
- **Sağ başparmak:** airbrake butonu (basılı tutulduğu sürece). İkinci buton: boost/afterburner, şarjlı.
- Yaw/rudder yok — roll'a bağlı otomatik koordineli dönüş yapılsın.
- **Flight assist** (varsayılan açık): otomatik roll düzleme, duvara yaklaşınca yumuşak itme. Ayarlardan kapatılabilir, kapalıyken madalya eşikleri daha cömert değil — leaderboard aynı.
- **Tilt kontrolü:** opsiyonel alternatif, ayarlardan açılır (`Input.get_accelerometer()`). Varsayılan kapalı.
- Duvara sürtünce **haptic feedback** (`Input.vibrate_handheld(50)`).
- Safe area: `DisplayServer.get_display_safe_area()` ile çentik/punch-hole dışında kal.

Masaüstünde test edebilmek için klavye eşlemesi de bırak (WASD + Space), ama tasarım kararlarını dokunmatiğe göre ver.

## 5. Klasör yapısı

```
res://
  scenes/
    main.tscn
    jet/jet.tscn
    track/canyon.tscn
    ui/hud.tscn
    ui/touch_controls.tscn
  scripts/
    flight/flight_model.gd
    flight/jet_controller.gd
    ai/bot_pilot.gd
    ai/difficulty.gd
    camera/chase_camera.gd
    track/checkpoint.gd
    track/race_manager.gd
    ui/hud.gd
    ui/touch_controls.gd
  shaders/
    sandstone.gdshader
  resources/
    track_data.tres
    bot_profiles.tres
  assets/
```

## 6. Milestone'lar

Her milestone ayrı commit. Bir milestone bitmeden sonrakine geçme. Her birinin sonunda **ne çalıştıracağımı tek satırda yaz.**

### M0 — İskelet
- Godot projesi: Mobile renderer, landscape zorunlu, render scale 0.8 + FSR
- Android export preset: arm64, ASTC texture sıkıştırma, min SDK 24
- Input map (masaüstü test için), klasör yapısı, `.gitignore`, git init
- `main.tscn`: düz zemin + iki duvar (gri kutu), `WorldEnvironment` (açık gökyüzü, Filmic tonemap, **SSAO/SSIL/volumetric fog kapalı** — Mobile renderer'da ya yok ya pahalı)
- **Bitti:** proje headless açılıyor, boş sahne yatay çalışıyor

### M1 — Uçuş modeli, kamera, dokunmatik (en kritik adım)
- `flight_model.gd`: saf veri sınıfı, Node bağımsız, test edilebilir
  - Durum: `velocity`, `throttle`, `boost`, `airbrake`, `g_force`, `mach`
  - Thrust → hız; hıza bağlı sürüklenme; airbrake çarpanı
  - Dönüş: pitch/roll girdisi → açısal hız; roll'dan otomatik yaw türet (koordineli dönüş)
  - **G hesabı:** `g = (v * omega) / 9.81`
  - Flight assist: girdi yokken roll'u yavaşça 0'a çek
  - Sabit 60 Hz `_physics_process` tick'i — deterministik olmalı, ghost ve bot tekrarı buna bağlı
- `jet_controller.gd`: girdi → model, `move_and_collide()` ile hareket, çarpışmada hız vektörünü duvara teğet yansıt + %20 kayıp + titreşim
- `touch_controls.gd`: floating virtual stick + airbrake + boost, safe area'ya saygılı
- `chase_camera.gd`:
  - Arkadan yumuşak takip (pozisyon lerp ~12, rotasyon ~8)
  - **FOV hıza bağlı:** 65° @ 220 m/s → 88° @ 380 m/s
  - G'ye bağlı hafif shake ve roll offset. Mobilde shake'i PC'dekinin yarısı tut, küçük ekranda mide bulandırır
- **Bitti:** gri kutular arasında parmakla uçulabiliyor, duvara sürtünce yavaşlıyor ve titriyor. **Hız hissi burada zaten iyi olmalı** — değilse ilerleme, bu adımı tekrar çalış.

### M2 — Kanyon
- Pist bir `Path3D` spline
- Spline boyunca prosedürel mesh (`SurfaceTool`): her kesitte sol duvar / zemin / sağ duvar; genişlik spline boyunca eğriyle değişsin
- **Vertex renk ile tabaka bilgisi bak** (M6'da shader bunu kullanacak, texture yerine)
- Collider: görsel mesh'ten ayrı, basitleştirilmiş `ConcavePolygonShape3D`
- Kanyon dışına çıkışı `Area3D` ile yakala → son checkpoint'e respawn
- Mesh'i chunk'lara böl ki frustum culling işe yarasın; `visibility_range` ile uzak chunk'lara LOD
- Spline noktaları ve genişlik eğrisi `.tres` kaynağından okunsun, el ile ayarlanabilsin
- **Bitti:** ~60 saniyede uçulabilen, en az 4 belirgin virajı olan kapalı kanyon var ve draw call < 100

### M3 — Yarış sistemi
- `checkpoint.gd`: `Area3D`, sıra numarası, sadece doğru sırada tetiklenir
- `race_manager.gd`: tur süresi, sektör süreleri, best lap, sektör delta
- Madalya eşikleri `track_data.tres`: Author / Gold / Silver / Bronze
- Respawn: her checkpoint bir respawn noktası
- Ghost kaydı: her fizik tick'inde pozisyon+rotasyon, en iyi tur `user://` altına, tekrar oynatılabilir
- İki mod: **Yarış** (botlarla) ve **Time Trial** (ghost ile)
- **Bitti:** tur bitiyor, süre ve madalya doğru, ghost oynuyor

### M4 — HUD
Control node'ları, monospace font, safe area içinde. Yerleşim referansı (yatay ekran):
- Sol orta: hız kutusu — büyük `KT` değeri, altında `M 1.75`, altında `BRAKE`
- Sağ orta: `G` kutusu + `G-LIM`. 8 G üstü sarı, 9 G kırmızı
- Merkez: nişangâh dairesi + **flight path marker** (yeşil, hız vektörünün ekran izdüşümü)
- Üst orta: tur paneli — `Lap / Last / Best`, `LAP n`, `SEC x/4`, madalya satırı. *(PC'de alttaydı; mobilde alt bölge başparmakların altında kalıyor, yukarı taşındı)*
- Sektör geçişinde delta popup: yeşil `-0.325` / kırmızı `+0.050`, 1.5 s'de yukarı kayarak sönsün
- Yarış modunda: sağ üstte sıralama (`3/6`) ve öndeki/arkadaki rakibe fark
- HUD yazı boyutları telefon için büyütülsün — PC referansındaki oranları birebir alma
- **Bitti:** her değer canlı ve doğru, 5.5" ekranda okunabiliyor

### M5 — VFX ve ses (mobil bütçesiyle)
- `GPUParticles3D` afterburner × 2, throttle'a göre boy. **Partikül sayısı düşük tut** (<64/emitter), additive blend overdraw'a dikkat
- Kontrail: particle trail yerine **tek bir mesh trail** — daha ucuz
- Duvar sürtmesinde kıvılcım + toz, kısa ömürlü, az partikül
- Botların VFX'i mesafeye göre kapansın (`visibility_range`)
- Uçak altına **blob shadow decal** — gerçek gölge yok, ama zeminle bağlantı hissi şart
- Ses: motor loop'u `AudioStreamPlayer3D` + throttle'a bağlı `pitch_scale`, afterburner katmanı crossfade; hıza bağlı rüzgâr; checkpoint ding (yeşil/kırmızı iki varyant); sürtme sesi
- Ses dosyası yoksa sessiz bırak ve TODO yaz — **ses aramak için internete çıkma**
- Aynı anda çalan ses kanalı sayısını sınırla (mobilde 16'yı geçme)
- **Bitti:** fps düşmeden görünüyor ve duyuluyor

### M6 — Görsel kimlik (mobil shader yaklaşımı)
Referans görsel: yatay tabakalı kırmızı-turuncu kumtaşı kanyon, kum zemin, açık mavi gökyüzü.

**Önemli:** fragment shader'da prosedürel noise **kullanma** — mobil GPU'da ALU maliyeti çok yüksek. Bunun yerine:
- Tabaka renklerini **512×64'lük tek bir gradient şerit texture'a** bake et (editor script'i ile üret, elle çizme). Shader world-space Y'yi bu texture'ın UV'sine çevirip örneklesin — tek texture fetch
- Varyasyon için M2'de bake edilen vertex color'ı çarpan olarak kullan
- Detay için tek bir küçük tiling normal map, düşük çözünürlük
- Kum zemini: aynı mantık, açık palet
- `WorldEnvironment`: öğle güneşi, hafif glow (mobilde glow pahalı — kapatıp test et, fark azsa kapalı kalsın), uzak mesafe fog (ucuz ve derinlik hissi verir)
- **Motion blur YOK.** Godot'ta built-in değil ve mobilde fullscreen compositor effect bütçeyi yer. Hız hissini bunlarla kur:
  - FOV punch (M1'de var)
  - Ekran kenarı vignette, hıza bağlı şiddet
  - Kameranın yanından geçen **speed line partikülleri** (birkaç düzine, çok ucuz)
  - Kanyon duvarına yakın geçişte kısa süreli FOV ve shake artışı
- **Bitti:** cihazda 60 fps'te referans videoya benzeyen bir görüntü var

### M7 — Botlar
5 bot + oyuncu = 6 araç.

- `bot_pilot.gd`: botlar **full flight model kullanmasın**. Spline üzerinde ilerleyen, lookahead ile yumuşatılmış hareket + hafif pitch/roll animasyonu. Çok daha ucuz ve davranışı kontrol edilebilir
- Her bot spline'dan sabit bir **lateral offset şeridinde** uçsun (−30 m … +30 m arası dağıtılmış) → birbirlerine girmezler, görsel olarak da dolu bir grid oluşur
- Offset'e düşük frekanslı salınım ekle ki robot gibi durmasınlar
- `bot_profiles.tres`: her bot için hız çarpanı, hat hatası miktarı, viraj agresifliği, isim, renk
- Zorluk kademeleri: Kolay / Normal / Zor → bot hız çarpanı ve oyuncunun hedef süresi
- **Hafif rubber-banding:** oyuncu çok geride kalırsa botlar %5 yavaşlar, çok öndeyse %5 hızlanır. Ayarlanabilir, kapatılabilir
- **Çarpışma: ghost (geçişli).** 6 süpersonik uçak dar kanyonda katı çarpışmayla oynanmaz. Görsel olarak birbirlerini kesmesinler diye şerit sistemi zaten var
- Bot görseli: 5 farklı livery rengi, uzakta düşük LOD ve VFX kapalı
- Start grid dizilişi + 3-2-1 geri sayım
- Sıralama hesabı: spline üzerindeki ilerleme (`progress`) + tur sayısı
- **Bitti:** 6 araçla yarış bitiyor, sıralama doğru, fps bütçesi hâlâ tutuyor

### M8 — Mobil optimizasyon ve export
- Gerçek cihazda profil çıkar; draw call, tris, fps ölç ve raporla
- Render scale'i cihaz gücüne göre otomatik ayarla (dinamik çözünürlük)
- Ayarlar menüsü: grafik kalitesi (Düşük/Orta/Yüksek), 30/60 fps, tilt kontrol, flight assist, haptic
- Termal test: 10 dakika kesintisiz oynanışta fps düşüşünü ölç
- APK boyutunu raporla, 100 MB altında tut
- **Bitti:** imzalı APK çıkıyor, cihazda 60 fps'te oynanıyor

## 7. Yapma

- `RigidBody3D` veya `VehicleBody3D` ile uçuş modeli kurma
- Fragment shader'da prosedürel noise kullanma
- Gerçek zamanlı gölge açma
- Fullscreen post-process zincirine girme (motion blur, DOF, SSR — hepsi yasak)
- Botlara full flight model + fizik çarpışması verme
- Dışarıdan asset/paket indirmeye çalışma
- M1 bitmeden görsel polish'e geçme — hissi yanlış olan güzel bir oyun kurtarılamaz
- 300 satırı geçen GDScript dosyası yazma, böl

## 8. Çalışma şekli

- Her milestone'da önce ne yapacağını bir paragrafla söyle, sonra yaz
- Her milestone sonunda commit at, mesajda milestone numarasını belirt
- Ayarlanabilir her sayıyı (thrust, drag, FOV aralığı, G limiti, kamera lerp, bot profilleri, kanyon genişliği) `@export` olarak aç — editörden kurcalayacağım
- **Her milestone sonunda performans bütçesini kontrol et ve rakamları yaz.** Bütçe aşılıyorsa sonraki milestone'a geçme
- Bir şey belirsizse tahmin et ve ne varsaydığını yaz, sorup bekleme
- `godot` CLI kurulu mu kontrol et; değilse söyle, ben kurayım
