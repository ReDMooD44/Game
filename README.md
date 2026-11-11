# Canyon Jet Racer

Godot 4.7 · GDScript · Android (arm64-v8a + x86_64, landscape) · v1.0-beta

Dar bir kanyonda alçak uçuşla arcade jet yarışı. Oyuncu + 5 bot, tur/sektör/madalya
sistemi, ghost'lu time trial. Referans: `SPEC.md` ve oynanış videosundan okunan
HUD/kanyon düzeni.

## Kurulum

`build/canyon-jet-racer.apk` — release imzalı, 58,5 MB, Android 7.0+ (minSdk 24).
Telefona kopyalayıp açman yeterli; "bilinmeyen kaynak" iznini istemesi normal.

## Kaynaktan derleme

Godot 4.7 ve Android SDK + JDK 17 gerekiyor. İmza bilgileri bilerek
`export_presets.cfg` içinde tutulmuyor — o dosya depoya giriyor ve anahtar
şifresinin depoda işi yok. Godot bunları ortam değişkenlerinden okuyor:

Taze bir klonda `.godot/` yok, o yüzden önce bir içe aktarma gerekiyor;
ikinci komut asıl derleme.

```bash
godot --path . --headless --import
```

```bash
export JAVA_HOME=/path/to/jdk
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=<alias>
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<parola>
godot --path . --headless --export-release "Android" build/canyon-jet-racer.apk
```

Anahtarın kendisi de depoda değil. Android'de bir uygulama yalnızca onu ilk
imzalayan anahtarla güncellenebilir, yani o dosya kaybolursa yayındaki sürüm
bir daha güncellenemez.

## Oyun akışı

1. **Ana menü** — YARIŞ (5 bota karşı) / TIME TRIAL (ghost ile) / zorluk / **harita seçimi** / ayarlar.
   Harita ekranı her pisti kendi spline'ından çizip en iyi turunla birlikte gösterir.
   En iyi turun ve madalyan başlıkta görünür, cihazda saklanır.
2. **3-2-1 geri sayım**, ardından 3 turluk yarış. Üst ortada tur/sektör paneli,
   solda hız (KT + Mach), sağda G ve G limiti, merkezde nişangâh + flight path marker.
3. **Duraklatıp devam ettiğinde yeniden 3-2-1 sayılır**, böylece parmağını
   yerleştirmeden kanyon duvarına girmezsin.
4. **Bitişte sonuç kartı** — sıralama, en iyi tur, son tur, Author hedefi, madalya.
   TEKRAR veya ANA MENÜ.
5. Sol üstteki **II** duraklatır: devam / yeniden başla / ayarlar / ana menü.
   Android geri tuşu da duraklatır.

## Kontroller

- **Gaz otomatik** — uçak hep tam gazda.
- **Joystick bırakılınca uçak kendini toparlar** — kanatlar düzleşir ve uçak
  pistin dikey profilini takip ederek duvar yüksekliğinin %45'inde seyreder.
  Dönüş verdiğinde yatar, bıraktığında tekrar düzlenir.
- **Asistan senin yerine dönmez.** Duvara yaklaşınca uçağı kendiliğinden
  yatıran düzeltme tamamen kaldırıldı. Geriye sadece irtifa koruma ve
  (pitch'e dokunmuyorsan) zeminden son çare kaçınma kaldı.
- **BOOST biter.** 3 saniye sonra kesilir; tekrar yanması için hem parmağını
  kaldırman hem deponun yarıya dolması gerekir. Buton doluluğu kalan şarjı,
  grileşmesi ise "şu an kullanılamaz"ı gösterir.
- **Jiroskop** ayarlardan açılır. Yarış başında telefonu nasıl tutuyorsan o
  nötr kabul edilir, masada yatık da olsa çalışır. Açıkken joystick kaybolur
  ve BOOST boşalan sol tarafa geçer. Hassasiyet ayarlardan 0,5x–2,0x arası.
- **Sıralama paneli** sağ üstte: tüm saha sırayla, sen yeşil şeritte,
  arkandakiler soluk. Altında öndeki ve arkandakine fark.
- **İz efekti** ayarlardan seçilir: standart beyaz + 8 lazer görünümü
  (ileride açılabilir içerik olarak tasarlandı, şimdilik hepsi açık).
- **Mini harita** alt ortada: pistin tamamı kuş bakışı, yeşil üçgen sen,
  renkli noktalar botlar, beyaz noktalar sektör kapıları.
- **Sol alt: joystick** — sürekli ekranda. Yukarı/aşağı pitch, sağa/sola roll.
  Floating: sol yarıda başka bir yere basarsan stick oraya taşınır.
- **Sağ alt: BOOST** (3 sn şarjlı afterburner, kalan şarj butonun dolgusunda)
  ve **BRAKE** (basılı tutuldukça airbrake).
- Yaw yok; roll'dan koordineli dönüş türetiliyor. Duvara sürtünce %20 hız kaybı +
  titreşim. Arka arkaya 5 kez sürtersen son checkpoint'e geri alınırsın.
- Flight assist varsayılan açık (duvara/zemine yaklaşınca yumuşak itme, roll düzleme).
  Tilt kontrolü ayarlardan açılır. Masaüstü testi için WASD + Space + X + R.

## Ses ve müzik

Hiçbir ses dosyası yok; hepsi `scripts/audio/sfx.gd` içinde kodla sentezleniyor:
türbin loop'u (hıza bağlı pitch), afterburner katmanı (crossfade), hıza bağlı
rüzgâr, checkpoint ding'i (yeşil/kırmızı iki varyant), sürtme gürültüsü, çarpışma
patlaması, geri sayım bip'leri, tur fanfarı, UI tıklaması. Aynı anda en fazla
12 kanal.

**Müzik de kodla üretiliyor:** 132 BPM'de dört barlık bir döngü — Am-F-C-G
üzerine vuruşlu bas, on altılık arpej ve offbeat hat. Sonuç ekranında kısılıyor.
Efekt sesi ve müzik sesi ayarlarda ayrı ayrı, %0-100 arasında kademeli.

## Nasıl test edildi

| Ne | Nerede | Sonuç |
|---|---|---|
| Menü → yarış → duraklat → ana menü → time trial | Android emülatörü (API 34, x86_64), release APK | Tamamı çalışıyor, log'da 0 hata |
| Dokunmatik joystick / BOOST / BRAKE | Aynı cihaz, `adb input` ile | Girdi alınıyor, uçak yönleniyor |
| Yarış sistemi (16 kapı, 4 sektör, 2 tur, madalya, bitiş) | `tools/race_check.gd` entegrasyon testi | Turlar 60.567 / 59.900 sn, SILVER, sıra doğru |
| Menü ekranları | `tools/ui_check.tscn` | Title / ayarlar / duraklat / sonuç kartı |
| Joystick yönü, auto-level, düz uçuş | `tools/roll_check.tscn` | Sağ = sağ kanat aşağı + sağa dönüş; girdi yokken bank ve tırmanış sıfırlanıyor |
| Geri sayımda kimse hareket etmiyor | `tools/countdown_check.tscn` | Botlar ve oyuncu GO'ya kadar 0,00 m |
| Harita dışı: sert tavan | `tools/bounds_check.tscn` | 900 m yukarı atılan uçak anında tavana kelepçeleniyor; 2,5 sn dayanırsa piste alınıyor |
| Elsiz uçuşta irtifa koruma | `tools/ride_check.tscn` | 20 sn boyunca ortalama ~37 m yerden yükseklik (hedef bandın içinde) |
| BOOST gerçekten bitiyor mu | `tools/roll_check.tscn` | Buton 10 sn basılı: 3 sn yanıyor, 7 sn kesik, kilitli kalıyor |
| Yarış sıralaması | `tools/standings_check.tscn` | Önde 1/6, arkada 6/6 |
| Tur bindirme ve bitiş anı | `tools/lap_check.tscn` | Geri kalanı bir tur geçip 12 kez respawn olarak tam yarış: tur sayımı sapması 0 m, bitişte sıra doğru |
| Pist kendini karıştırıyor mu | `tools/offset_check.gd` | İki pistte 8.100 nokta; konumdan geri okunan offset hiçbirinde sıçramıyor |
| Respawn noktalarında yer var mı | `tools/respawn_check.gd` | 16/16 noktada en az 60 m yarı genişlik, hiçbiri duvara bakmıyor |
| İz efekti merdiveni | `tools/progress_check.tscn` | Sekiz efekt sırayla açılıyor; kazanılmamış biri seçilemiyor |
| Harita seçim ekranı | `tools/map_check.tscn` | İki pistin kartı, kendi spline'ından çizilen şekliyle |
| Performans bütçesi | Headless rapor + mesh sayımı | Aşağıdaki tablo |

Emülatörde ölçülen kare hızı 60 fps (çözünürlük 2400×1080, yazılım ölçekli).

## Ölçülen bütçe

Aşağıdaki iki satır sahnenin toplamı değil, **ekranda gerçekten çizilen**
değerler: `tools/capture.gd` her kareyi kaydederken
`RenderingServer.get_rendering_info` okuyor. Görünürlük mesafesiyle elenen
geometri için sahne toplamı hiçbir şey söylemiyor.

| Metrik | Değer | Limit |
|---|---|---|
| Çizim çağrısı (en yoğun kare) | 96 | < 100 |
| Üçgen (en yoğun kare) | 128.571 | < 150k |
| Kanyon üçgen (toplam) | 34.272 | — |
| Pist uzunluğu | 18.581 m | — |
| Temiz tur süresi | 58,1 s | 58,5 s = Author |
| APK boyutu | 60,5 MB (sürüm 1.0-beta) | < 100 MB |
| Gerçek zamanlı gölge | yok (blob shadow decal) | yok |
| Fullscreen post-process | 1 geçiş (vignette + hız çizgileri) | ≤ 1 |
| Fragment shader noise | yok | yasak |

Kanyon duvarlarının ışığı kare başına değil, yükleme anında CPU'da bir kez
hesaplanıyor (`CanyonShading`): gökyüzü görünürlüğü ve karşı kenarın kestiği
gölge çizgisi köşe noktalarına yazılıyor. Gerçek zamanlı gölge yasak olduğu
için bir slot kanyonun biçimi başka türlü okunmuyordu.

## Mimari

```
scripts/
  core/settings.gd        kalıcı ayarlar + tur rekorları (autoload)
  core/strata_texture.gd  kumtaşı gradient şeridi + detay normal map (load'da bake)
  audio/sfx.gd            tüm sesleri kodla üreten dalga formu bankası
  audio/audio_bus.gd      one-shot havuzu, ses seviyesi (autoload)
  audio/jet_audio.gd      motor / afterburner / rüzgâr loop'ları
  flight/flight_model.gd  saf uçuş matematiği, Node bağımsız, 60 Hz deterministik
  flight/jet_controller.gd  girdi → model → move_and_collide, sürtme, sıkışma tespiti
  camera/chase_camera.gd  takip, hıza bağlı FOV, G'ye bağlı shake, vignette girdisi
  track/track_data.gd     pist kaynağı (spline, genişlik, madalya süreleri)
  track/track_gen.gd      varsayılan düzeni üretip .tres'e yazar
  track/canyon.gd         spline boyunca prosedürel mesh + ayrı basit collider
  track/checkpoint.gd     sıralı kapı, respawn noktası
  track/race_manager.gd   tur/sektör/madalya/sıralama/respawn/ghost
  track/ghost.gd          fizik tick'i başına pozisyon+rotasyon, user:// altına
  ai/bot_pilot.gd         spline şeridinde ilerleyen hafif bot
  jet/jet_build.gd        primitive jet + afterburner + blob shadow
  jet/contrail.gd         tek ribbon mesh
  jet/vfx.gd              speed line, kıvılcım, WorldEnvironment, güneş
  ui/title_screen.gd      ana menü
  ui/hud.gd               tek draw pass'lik HUD
  ui/touch_controls.gd    joystick + butonlar, safe area
  ui/menu.gd              duraklatma
  ui/settings_panel.gd    paylaşılan ayarlar paneli
  ui/results.gd           yarış sonu kartı
  ui/vignette.gd          tek fullscreen geçiş
tools/                    APK'ya girmez: pist üretici, ikon üretici,
                          ekran görüntüsü dökümü, UI ve yarış testleri
```

Ayarlanabilir her sayı `@export`: thrust, drag, FOV aralığı, G limiti, kamera lerp,
kanyon genişliği/yüksekliği, bot profilleri, assist mesafeleri, rubber band penceresi.

## Geliştirici komutları

```bash
godot --headless --path . --script tools/make_track.gd
```

```bash
godot --headless --path . --script tools/race_check.gd
# Uygulama ikonlarını yeniden üretir
godot --headless --path . --script tools/make_icons.gd
```

```bash
godot --headless --path . --export-release "Android" "build/canyon-jet-racer.apk"
```

## Dahil edilen asset'ler

| Dosya | Nerede kullanılıyor |
|---|---|
| `space-fighter` FBX + PBR texture'ları | Oyuncu ve beş botun gövdesi. 39 ayrı mesh tek malzemede birleştirilip 2 çizim çağrısına indiriliyor (`ShipMesh`), 11,5 m'ye ölçekleniyor. Texture'lar 512'ye sınırlanıp VRAM sıkıştırmalı. |
| Radial lines JPG | Artık kullanılmıyor: yerini senin verdiğin radyal çizgi shader'ı aldı (Godot 4'e taşındı, gürültü dokusu kodla üretiliyor, vignette ile aynı tek geçişte). |
| Laser beam sheet JPG | Kanat ucu izi "giyilebilir" görünümleri. Sayfa 2x4 hücreye bölünüp atlas olarak kullanılıyor; 8 lazer + standart beyaz. |
| `GROUND.fbx` | Pistin iki yanındaki kaya arazisi. Asset aslında 50x150 birimlik bir plaka ve içinden geçen bir yarık kanyon; üç özdeş kopyadan biri (5 mesh, ~26k üçgen) birleştirilip ~11 kat büyütülerek tur boyunca 16 noktada, kanyon kenarının üstünde duracak şekilde yerleştiriliyor. 1500 m'de eleniyor, aynı anda en fazla iki tanesi çiziliyor. |
| `rock.jpg` | Kanyon duvarlarının yüzey dokusu, tabaka renginin üzerine grenn olarak harmanlanıyor. |

EPS dosyaları Godot'ta kullanılamadığı için paketlerin JPG sürümleri alındı.

| `canyon_wall.png`, `canyon_floor.png` | Duvar ve zemin dokuları. Higgsfield ile üretildi; duvar, Antelope Canyon referans fotoğrafından. İkisi de düz, eşit ışıklı ve gölgesiz — doku olmaları gereken şey. |
| Loafbrr **Canyon Set** (CC0) | Kenar hattındaki ve duvar diplerindeki kayalar, kaktüsler, otlar. 67 mesh `tools/bake_props.gd` ile bir kez `resources/canyon_props.tres` içine pişiriliyor; paketin kendisi ne depoda ne APK'da. Ayrıntı ve gerekçe için `CREDITS.md`. |

## Üçüncü taraf asset notu

`Free Warp Drive Effects` (VOiD1 Gaming) paketi Unity içindir ve yalnızca iki
`.prefab` ile Unity'nin yerleşik shader'ına ve yerleşik parçacık texture'ına
referans veren bir `.mat` içerir — tek bir görsel veya mesh dosyası yoktur.
Godot'a aktarılabilecek hiçbir dosyası olmadığı için **paketten hiçbir dosya
projeye kopyalanmadı veya dağıtılmadı.** Efekt, prefab'daki parçacık
ayarlarından (gerilmiş billboard, uzunluk çarpanı 15, ömür 2 sn, hız 40,
boyut 0,2, 250/sn emisyon) okunup Godot'un kendi parçacık sistemiyle yeniden
kuruldu: `Vfx.warp_streaks()`. Lisans PDF'inin metni görüntü olarak gömülü
olduğu için okunamadı; asset'in kendisi kullanılmadığından bu bir engel değil,
ama dosyaları doğrudan dağıtmak istersen lisansı kendin kontrol etmelisin.

## Bağımlılık PDF'i karşısındaki duruş

Brief'le gelen metin iki ayrı şey anlatıyor ve ikisine aynı şekilde
davranılmadı.

**Eklenmeyenler.** Metnin en güçlü bağımlılık mekanizmaları olarak saydıkları:
öngörülemeyen ödüller (loot box, gacha), günlük giriş serileri, girmeyince
kaybettiğin süreli etkinlikler, bitmeyen içerik. Bunların hiçbiri yok ve
olmayacak — hepsi oyuncuyu *oynamadığı için* tedirgin ederek çalışıyor, ki
metnin uyardığı zarar tam olarak bu.

**Eklenenler.** Aynı metnin "ilerleme hissi" ve "yetkinlik" başlıkları: sekiz
iz efekti artık bedava değil, baştan ilan edilmiş ve biten bir merdiven. Bir
yarış bitir, ilk üçe gir, kazan, her madalya, iki haritayı da kazan, AUTHOR
süresini geç. Sıradaki hedef ayarlarda yazıyor; hiçbiri rastgele değil,
hiçbiri süreyle kaybolmuyor.

**Oyuncu tarafı.** Metnin "kontrolü geri kazanmak" bölümü de yarısı kadar yer
tutuyor, o da burada: sonuç ekranı oturumun ne kadar sürdüğünü yazıyor — metnin
önerdiği doğal durma noktasında — ve 45 dakikada bir hatırlatma geçiyor.
Ayarlardan değiştirilebiliyor ve kapatılabiliyor.

## Spec'ten sapmalar

1. **Renderer: Mobile (Vulkan) değil, Compatibility (OpenGL ES 3).** Bu bilinçli bir
   karar: Mobile/Vulkan derlemesi elimdeki hiçbir ortamda kare basamadı (emülatörün
   Vulkan katmanı `Couldn't present to Vulkan queue` ile takılıyor), yani test
   edemeyeceğim bir yapı olurdu. Compatibility hem cihazda uçtan uca test edildi hem
   de Android'de en geniş uyumluluğa sahip. Bütçe zaten çok altında (17 draw call),
   performans kaybı pratikte yok. Elinde Vulkan'ı sorunsuz çalışan bir cihaz varsa
   `project.godot` içinde `rendering_method` değerlerini `mobile` yapıp yeniden
   derlemek yeterli.
2. **FSR 1.0 yok** — Godot 4.7'de FSR yalnızca Forward+ ile çalışıyor. Bilinear
   ölçekleme kullanıldı (Düşük/Orta/Yüksek = 0,6 / 0,8 / 1,0).
3. **Kanyon dışı: görünmez tavan.** Yanlar zaten katı duvar, tek kaçış yolu
   tepeden. Bu yüzden tavan her fizik adımında sert kelepçe (duvar yüksekliğinin
   1,15 katı, rim 1,25'te bitiyor) — yukarı çıkmak mümkün değil. Yanlara ve
   zemine ise gevşek bir ağ var: oraya düşersen uyarı çıkıyor ve 2,5 sn içinde
   dönmezsen son checkpoint'e alınıyorsun. Yanal kelepçe denendi ve kanyonun V
   kesitiyle çeliştiği için çarpışma motoruyla kavga etti, kaldırıldı.
4. **Gradient şerit çalışma anında bake ediliyor**, editör script'i yerine
   `StrataTexture.strip()` içinde. Fragment shader'da yine tek texture fetch, noise yok.
5. **HUD hız/Mach/G değerleri ölçekli** — gerçek hız 220–380 m/s (dokunmatikte
   oynanabilir olan bu), gösterge referanstaki 630–1250 kt / M 1.09–1.85 aralığına
   eşleniyor. G limiti tam 9'da kesiyor.
6. **Hız ve madalya süreleri oynanabilirlik için düşürüldü.** Gerçek hız artık
   185–320 m/s (boost 372), kanyon Normal zorlukta %25 geniş. HUD hâlâ referans
   aralığını (630–1250 kt, M 1.09–1.85) gösteriyor. Madalya eşikleri buna göre
   yeniden ölçüldü: Author 58,5 / Gold 62 / Silver 70 / Bronze 82 sn. Spec'teki
   55,662 sn bu jet hızıyla ulaşılamaz olurdu. Kanyon da genişletildi:
   tam genişlik 104–152 m, Normal zorlukta %15 daha fazlası. Turun %16,7'si
   koridor: üç noktada duvarlar kapanıp genişlik 50 m'ye iniyor.
7. **Milestone'lar ayrı ayrı commit'lenmedi**; dört commit'te toplandı.

## Bilinen eksikler

- Gerçek bir telefonda çalıştırılmadı; tüm cihaz testleri Android emülatöründe
  yapıldı. Termal/pil davranışı ve dokunmatik his gerçek cihazda ölçülmeli.
- İki pist var: **Red Mesa** ve **Dust Basin**. Yeni pist `track_gen.gd` içindeki
  `PRESETS` listesine bir satır eklemekle geliyor; `tools/make_track.gd` hepsini
  `resources/track_N.tres` olarak yazıyor.
- Kanyon kayası hâlâ placeholder: tabakalar görünüyor ama referans videodaki
  keskin katman geçişleri kadar belirgin değil.
- Botların görsel LOD'u mesafeye göre kapanıyor ama ayrı bir düşük-poli modeli yok.
