# Sleepify

Akıllı alarm, uyku analizi ve rahatlama uygulaması. Arayüzün tamamı tek bir HTML
dosyasında; Flutter kabuğu bunu WebView'de çalıştırır ve alarmları Android'in
kendi alarm servisine yazar — yani uygulama kapalıyken, telefon uykudayken de çalar.

```
sleepify/
├─ assets/web/index.html          uygulamanın tamamı (HTML + CSS + JS)
├─ assets/icon/                   uygulama simgesi
├─ lib/main.dart                  Flutter kabuğu, WebView ↔ Dart köprüsü
├─ lib/alarm_bridge.dart          AlarmManager kaydı + tam ekran bildirim
├─ tool/patch_android.sh          izinler, kilit ekranı, desugaring
├─ pubspec.yaml
└─ .github/workflows/build-apk.yml
```

---

## Yol 1 — Bilgisayarına hiçbir şey kurmadan APK al

1. GitHub'da yeni bir depo aç (**Public** seç, ücretsiz Actions için gerekli).
2. Bu klasörün **içeriğini** depoya yükle:

   ```bash
   cd sleepify
   git init
   git add .
   git commit -m "Sleepify ilk sürüm"
   git branch -M main
   git remote add origin https://github.com/KULLANICI_ADIN/sleepify.git
   git push -u origin main
   ```

   Sürükle-bırak da olur (**Add file → Upload files**), ancak gizli `.github`
   klasörünün de yüklendiğinden emin ol — yoksa derleme hiç başlamaz.

3. Depoda **Actions** sekmesine geç. "APK derle" iş akışı kendiliğinden başlar;
   başlamazsa **Run workflow** düğmesine bas.

4. 6–10 dakika sonra iş sayfasının altındaki **Artifacts → sleepify-apk**
   bağlantısından zip'i indir. İçinden telefonuna uygun olanı kur:

   | Dosya | Kimler için |
   |---|---|
   | `app-arm64-v8a-release.apk` | 2017 sonrası hemen her telefon (**bunu seç**) |
   | `app-armeabi-v7a-release.apk` | eski 32-bit cihazlar |
   | `app-release.apk` | evrensel, daha büyük ama her cihazda çalışır |

   Android "bilinmeyen kaynak" uyarısı verirse izin ver.

### Sürüm yayımlama

Bir etiket gönderirsen APK'lar otomatik olarak **Releases** sayfasına yüklenir:

```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## Yol 2 — Kendi bilgisayarında derle

Flutter SDK gerekir ([kurulum](https://docs.flutter.dev/get-started/install)):

```bash
flutter create . --platforms=android --project-name sleepify --org com.sleepify
bash tool/patch_android.sh
flutter pub get
dart run flutter_launcher_icons
flutter run                  # telefon bağlıyken canlı dene
flutter build apk --release  # APK üret
```

Çıktı: `build/app/outputs/flutter-apk/app-release.apk`

## Yol 3 — Kurulumsuz deneme (PWA)

`assets/web/index.html` tek başına çalışır. Depo → **Settings → Pages → main / root**,
açılan adresi telefonda Chrome ile aç ve menüden **Ana ekrana ekle** de.
Arka plan alarmı bu modda çalışmaz, gerisi çalışır.

---

## Alarm nasıl çalışıyor

1. Arayüzde bir alarm eklendiğinde köprü tüm listeyi Dart tarafına yollar.
2. `AlarmBridge.sync()` önceki kayıtları iptal eder ve açık her alarmın bir
   sonraki tekrarını `AndroidAlarmManager.oneShotAt(..., alarmClock: true,
   rescheduleOnReboot: true)` ile sisteme yazar. `alarmClock` bayrağı sayesinde
   Doze modu ve pil optimizasyonu alarmı geciktiremez; telefon yeniden başlasa
   bile kayıt korunur.
3. Saat geldiğinde `alarmCallback` ayrı bir isolate'te uyanır ve tam ekran
   bildirim (`fullScreenIntent`) gösterir: kilit ekranı açılır, ekran uyanır,
   ses `FLAG_INSISTENT` ile dokunulana kadar tekrar eder.
4. Bildirime dokunulup uygulama açıldığında çalan alarmın id'si arayüze iletilir
   (`window.SleepifyFire(id)`) ve uyandırma görevi orada işler.

## İlk açılışta verilecek izinler

- **Bildirim** (Android 13+) ve **tam zamanlı alarm** (Android 12+) izinleri
  uygulama tarafından istenir; reddedilirse alarm güvenilir çalışmaz.
- Telefonun **pil optimizasyonu** listesinden Sleepify'ı çıkarmak önerilir
  (Ayarlar → Uygulamalar → Sleepify → Pil → Kısıtlama yok).
  Xiaomi, Huawei, Samsung gibi markalarda ayrıca **Otomatik başlatma** izni gerekir.
- **Kamera** yalnızca barkodla alarm kapatma görevinde, **mikrofon** yalnızca
  gece sesi algılamada istenir. İkisi de isteğe bağlıdır ve ses kaydedilmez.

## Bilinen sınırlar

- **Ses mikseri, atmosfer sahneleri ve nefes rehberi** uygulama önde çalışır;
  ekran kapanınca Web Audio durur. Arka planda sürmesi için `audio_service`
  paketiyle bir medya servisi eklenmelidir.
- **iOS** desteklenmiyor: `AndroidAlarmManager`ın iOS karşılığı yoktur.
- **Uyku evreleri** bir uyku döngüsü modelinden tahmin edilir, klinik ölçüm değildir.
  Uygulama içinde de bu açıkça belirtilir.

## Kendi ses ve videolarını eklemek

Uygulama içinden: Alarm panelinde "Kendi müziğini ekle", Rahatla sekmesinde
"Kendi sesini ekle" ve "Kendi videonu ekle". Videolar IndexedDB'ye kaydedilir,
uygulama kapansa da kalır.

Pakete gömmek için `assets/web/videos/` klasörü açıp yanına bir manifest koy:

```json
{ "videos": [
  { "file": "rain.mp4",   "name": "Camda yağmur" },
  { "file": "forest.mp4", "name": "Sisli orman" }
]}
```

Dosya adı `assets/web/videos/manifest.json` olmalı; klipler kitaplıkta
kendiliğinden görünür ve silinemez.

## Sorun giderme

| Belirti | Sebep ve çözüm |
|---|---|
| Actions hiç başlamıyor | `.github` klasörü yüklenmemiş. Depoda **Add file → Upload files** ile ayrıca yükle. |
| "index.html yok" hatası | `assets/web/index.html` eksik. Klasör yapısını koru. |
| Derleme Gradle'da takılıyor | Actions'ta **Re-run jobs** de; genelde geçici ağ hatasıdır. |
| APK kuruluyor ama alarm çalmıyor | Pil optimizasyonu ve otomatik başlatma izinlerini ver. |
| Ekran boş açılıyor | Uygulamayı tamamen kapatıp yeniden aç; sorun sürerse depoda bir sorun bildir. |
