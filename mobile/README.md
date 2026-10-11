# Yapay Zekâ Destekli Sağlık ve Fitness Platformu — Mobil

Flutter Android/iOS temeli; kayıt, giriş, oturum kontrolü/yenileme ve çıkış.
Giriş sonrası ana uygulama beş alt menüden oluşur: **Ana Sayfa, Planım, AI, Takip, Rehberim**. Ana Sayfa kart tabanlı dashboard gösterir; Takip'te gerçek kilo, vücut ölçümü ve manuel beslenme kayıtları kullanılır. Planım ve Rehberim sözleşmedeki API yollarına HTTP isteği gönderir; AI şimdilik placeholder içeriktir. Profil/Ayarlar Ana Sayfa'nın sağ üst profil düğmesinden açılır; mevcut hesap adı/e-postası ve çıkış işlemi burada bulunur.

Ana Sayfa'daki karşılama doğrulanmış `/api/users/me` verisinden, tarih cihazın yerel takviminden gelir. Bugünkü antrenman, kalori/makro, günlük aktivite, kilo gelişimi ve koç/diyetisyen kartları hazırlanmıştır. Dashboard endpointi henüz uygulanmadığından Ana Sayfa'daki özetler açık boş durum mesajları ve sayısal değer yerine `—` gösterir; örnek kullanıcı verisi, sıfır hedef, yüzde veya grafik üretilmez. Ana Sayfa modül API çağrısı yapmaz. Kart butonları mevcut Planım, Takip veya Rehberim sekmesini açar; gerçek kilo özeti Takip'tedir.

## Takip: kilo ve vücut ölçümleri

- Takip ilk açıldığında kendi kilo/ölçüm listeleri API'den yüklenir. En yeni `recordedAt` kaydı güncel kilo olarak gösterilir; geçmişler en yeniden eskiye sıralıdır.
- **Kilo Ekle** / **Ölçüm Ekle** ayrı form açar. Ölçüm alanlarının hepsi zorunlu değildir; en az biri girilir. Kilo/çevre ölçümleri 0,01–1000, yağ yüzdesi 0–100; en fazla iki ondalık basamak. Virgül ve nokta kabul edilir.
- Tarih ve saat seçilebilir; gelecekteki zaman reddedilir. İstek UTC gönderilir, geçmiş cihazın yerel saatinde gösterilir. Başarılı kayıt sonrası gerçek listeler yeniden yüklenir.
- Veri yoksa boş durum; ağ/API hatasında görünür hata ve **Tekrar dene**. Önceki kayıtlar varsa yenileme hatasında korunur ve eski oldukları belirtilir. Listeyi aşağı çekerek yenileyebilirsin.
- Kaydetme sırasında yinelenen gönderim engellenir; alan hataları ve form girdileri korunur. Logout/oturum sona ermesi açık formu da kaldırır. Koşu ve sağlık entegrasyonları henüz yoktur.

## Takip → Beslenme: manuel kalori ve makro takibi

- **Beslenme** düğmesi günlük özet ve tüm günlerdeki kayıt geçmişini açar. Öğün/besin adı, öğün türü, isteğe bağlı porsiyon, kalori ve üç makro manuel girilir; tüm sayısal alanlar zorunludur, sıfır geçerlidir. Virgül/nokta ve en fazla iki ondalık basamak desteklenir.
- Seçilen günün gerçek toplamları mevcut, tarih aralığı geçerli aktif `NutritionGoal` ile karşılaştırılır. Kalan/aşılan değerler gösterilir; hedef yoksa hedef uydurulmaz. Gün seçilebilir; tüketim zamanı formda değiştirilebilir, gelecekte olamaz.
- Tüketim UTC gönderilir; özet için yerel günün gece yarısı sınırları offsetleriyle API'ye gönderilir. Geçmiş yerel saatle gösterilir. Kayıt sonrası API yeniden okunur; loading/empty/error/yeniden deneme ve oturum sona ermesi desteklenir.
- `AddManualNutritionRecords` migration'ı gerekir. `baslat.cmd` başlangıçta migration'ları uygular; ayrı backend çalıştırırken backend README'deki EF `database update` adımını kullanın.
- API/DB/Android kontrolü repository kökünden: `./mobile/tool/auth_smoke.ps1 -NutritionTest`. Docker Desktop ve `emulator-5554` açık olmalıdır; fixture ayrı geçici PostgreSQL kullanır ve sonunda silinir. Beslenme kayıtlarını gerçek Flutter formları oluşturur; aktif hedef mevcut Dietitian endpointi ile atanır. Uygulama başlangıcında test verisi eklenmez.

## Planım ve Rehberim: gerçek backend okumaları

Backend, `AddMobileAssignmentReads` migration'ı ile danışman, program, hedef, görev ve not verilerini kalıcı olarak tutar ve aşağıdaki altı okuma endpointini sunar. Mobil yalnız gerçek HTTP/DB verisini kullanır; kayıt yoksa empty state gösterir. Web'in geliştirme önizlemesindeki örnekler mobilde kullanılmaz. Trainer/Dietitian program/hedef/görev/not yazmaları ve mobil görev tamamlama hazırdır; Admin rol/ilişki atama bu çalışmada eklenmez.

- **Planım → Antrenman:** atanmış program listesi; Programı Gör ile haftanın günleri, egzersizler, set/tekrar, süre, dinlenme, ağırlık ve notlar. Bu çalışma salt okunurdur; antrenman tamamlama eklenmedi.
- **Planım → Beslenme:** yerel cihaz tarihiyle geçerli tek aktif kalori/makro/su hedefi. Hedefler tüketim gibi gösterilmez; yüzde veya sahte ilerleme üretilmez.
- **Planım → Görevler:** görev başlığı, açıklaması, son tarihi ve durumu; bekleyen/devam eden görevleri tamamlayabilme; ayrı kaynaktan tarihli danışman notları.
- **Rehberim:** aktif koç ve diyetisyenler ayrı listelenir; birden fazla danışman desteklenir. Ad/soyad, varsa ünvan ve uzmanlık, atama tarihi gösterilir. API'de bulunmayan fotoğraf, iletişim veya biyografi üretilmez.
- Kaynaklar ilk ziyaretlerinde yüklenir; **Yenile / Tekrar dene** ile yeniden okunur. Sekme/kaydırma konumu korunur. Bir kaynağın hatası diğerinin verisini gizlemez; yenileme hatasında önceki veriler eski oldukları belirtilerek korunur.
- `200 []` yanıtı boş durumdur. Beslenmede yalnız `404` + `code: NutritionGoalNotFound` hedef yok anlamına gelir. Genel `404` için **servis henüz hazır değil veya kullanılamıyor** mesajı gösterilir; eksik backend boş atama gibi sunulmaz. Ağ/izin/yanıt hataları görünürdür; mevcut Bearer/refresh/oturum sona ermesi akışı kullanılır.

Mevcut `AddMobileAssignmentReads` migration'ı uygulanmalıdır: `baslat.cmd` başlatıcısı bunu backend başlangıcında yapar; ayrı çalıştırırken backend README'sindeki `database update` adımını kullanın. Yazma entegrasyonu yeni migration gerektirmez. Test kayıtları yalnız geçici PostgreSQL'de oluşturulur; gerçek kullanım için aktif danışman ilişkisi ve egzersiz kataloğu hazır olmalıdır. Admin ilişki atama bu görevin kapsamı dışındadır. `-AssignmentTest` okuma fixture'ını, `-AssignmentWriteTest` gerçek web formu → API → PostgreSQL → Android okuma/tamamlama akışını doğrular.

## Gereksinimler ve çalıştırma

- Flutter stable (bu çalışma: 3.44.6 / Dart 3.12.2).
- Android SDK, kabul edilmiş gerekli SDK lisansları ve Android emülatörü/cihazı.
- iOS için macOS ve Xcode gerekir.
- Backend ve PostgreSQL: önce `../backend/README.md` içindeki kurulum, configuration ve migration adımlarını uygulayın.

`mobile` klasöründe:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

`10.0.2.2`, Android emülatöründen bilgisayardaki backend'e ulaşır. Port, backend'in HTTP profilindeki `5000` değeridir. Merkezi `AppConfig`, yalnız Android debug açılışında eksik `API_BASE_URL` için bu geliştirme adresini kullanır. Diğer cihazlar ve profile/release için adresi açıkça verin. URL yalnızca sunucu adresidir; sonuna `/api` eklemeyin. Geçersiz ayar açıklama ekranı gösterir. Windows + VS Code ile her bilgisayar açılışındaki tüm servislerin sırası repository kökündeki `README.md` içindedir.

- iOS simülatörü: `http://localhost:5000` (backend aynı Mac üzerinde çalışıyorsa).
- Fiziksel telefon: bilgisayarın aynı ağdaki IP adresini kullanın. Backend'i erişilebilir adresle başlatın (`dotnet run --project backend --urls http://0.0.0.0:5000`) ve yerel ağ erişimini kontrol edin. JWT/DB ayarlarını backend README'sindeki gibi sağlayın.
- HTTP sadece debug geliştirme için açıktır. Profile/release HTTPS ister; geçerli sertifikalı backend URL'si kullanın. Sertifika doğrulaması devre dışı bırakılmaz.
- `API_BASE_URL` derlemeye eklenir ve secret değildir. JWT secret veya veritabanı şifresi mobil uygulamaya verilmez.

## Dosya düzeni

```text
lib/
  main.dart                     Configuration ve servisleri bağlar
  app.dart                      Oturuma göre ekran seçimi
  core/
    app_config.dart             Merkezi URL/timeout/uygulama adı
    app_theme.dart              Ortak koyu tema ve mavi vurgu
    api_service.dart            JSON, Bearer, hata ve refresh işlemleri
  features/
    auth/
      user.dart                 Auth ekranlarının kullandığı User alanları
      token_store.dart          Native güvenli token saklama
      auth_service.dart         Kayıt/giriş/me/çıkış ve oturum durumu
      auth_form.dart            Ortak form bileşenleri ve doğrulama
      login_screen.dart
      register_screen.dart
    home/
      home_screen.dart          Karşılama, dashboard ve sekme bağlantıları
      dashboard_widgets.dart    Ortak özet kartı ve boş metrik görünümü
    navigation/
      app_shell.dart            Beş alt menü ve korunan profil navigasyonu
      section_screens.dart      AI placeholder'ı
      section_placeholder.dart  Kaydırılabilir, genişliği sınırlı ortak içerik
    profile/profile_screen.dart Profil/Ayarlar girişi ve mevcut çıkış işlemi
    assignments/
      assignment_models.dart    Sözleşmedeki program/hedef/danışman/görev/not alanları
      assignment_service.dart   Kimliği doğrulanmış okuma istekleri
      assignment_widgets.dart   Ortak kart, sayfa ve bağımsız yükleme/hata görünümü
    plans/my_plan_screen.dart   Planım sekmeleri ve salt okunur program detayı
    advisors/my_advisors_screen.dart Koç/diyetisyen listeleri
    tracking/
      tracking_models.dart      WeightRecord/BodyMeasurement ve gösterim biçimi
      tracking_service.dart     Kimliği doğrulanmış listeleme/ekleme istekleri
      tracking_screen.dart      Güncel kilo, geçmişler ve yükleme/hata durumu
      tracking_entry_screen.dart Kilo/ölçüm formu ve kayıt zamanı seçimi
test/                           Birim ve widget testleri
integration_test/               Android üzerinde gerçek backend auth testi
tool/auth_smoke.ps1              Geçici PostgreSQL/API test ortamı
```

Ek state yönetimi veya routing paketi kullanılmaz; Flutter `ChangeNotifier`, `ListenableBuilder` ve `Navigator` yeterlidir.

Shell içindeki `IndexedStack` sekme içeriklerini ve kaydırma konumlarını korur. Profil route'u shell'in kendi `Navigator`'ında açılır; geri tuşu Ana Sayfa'ya döner. Logout veya oturumun sona ermesi shell ile tüm korunan alt ekranları kaldırır. Yeniden giriş Ana Sayfa'dan başlar. Ortak tema giriş/kayıt ekranlarında da kullanılır. Dashboard geniş ekranlarda en fazla 1040 piksel genişlik ve iki sütun kullanır; dar ekranlarda veya büyütülmüş metinde tek sütuna döner. Diğer ekranların içeriği 680 piksel ile sınırlıdır. İçerikler kaydırılabilir.

## Endpointler ve oturum davranışı

| İşlem | Backend |
|---|---|
| Kayıt | `POST /api/auth/register` |
| Giriş | `POST /api/auth/login` |
| Yenileme | `POST /api/auth/refresh` |
| Oturum doğrulama | `GET /api/users/me` |
| Çıkış | `POST /api/auth/logout` |
| Kilo geçmişi / ekleme | `GET/POST /api/users/me/weight-records` |
| Ölçüm geçmişi / ekleme | `GET/POST /api/users/me/body-measurements` |
| Atanmış programlar | `GET /api/users/me/workout-plans` |
| Program detayı | `GET /api/workout-plans/{workoutPlanId}` |
| Aktif hedef | `GET /api/users/me/nutrition-goals/active?date=YYYY-MM-DD` |
| Görevler / notlar | `GET /api/users/me/tasks`, `GET /api/users/me/advisor-notes` |
| Danışmanlar | `GET /api/users/me/advisors` |

- Kayıt yalnızca `firstName`, `lastName`, `email`, `password` gönderir; rol seçimi yoktur. Başarıda e-posta doldurulmuş Giriş ekranına döner. Register token üretmez.
- Giriş ve uygulama açılışında `/me` doğrulanmadan Ana Sayfa açılmaz. `User` rolü olmayan hesaplara web panelini kullanma mesajı gösterilir ve mobil oturum kapatılır. Mobil `User`, bu ekranda gereken kimlik/isim/e-posta/rolleri okur; profil düzenleme geliştirilmemiştir.
- Access token süresi yaklaşmışsa veya korunan istek `401` dönerse yenileme yapılır. Eşzamanlı yenilemeler tek istekte birleşir. Başarılı refresh sonrası eski token çifti değiştirilir; istek en fazla bir kez tekrar edilir.
- Geçersiz refresh oturumu silip Giriş'e döndürür. Ağ/timeout/5xx hatasında mevcut token korunur ve tekrar deneme sunulur.
- Token yoksa açılışta backend çağrılmaz; Giriş ekranı açılır. Native token okuma/yazma/silme 5 saniye, HTTP başlık/gövde okuması 20 saniye ile sınırlıdır. Beklenmeyen oturum hataları görünür hata ekranına geçer; sonsuz loading bırakılmaz.
- Access/refresh çifti tek şifreli kayıt olarak, sunucu adresine göre ayrı anahtarla saklanır. Parola saklanmaz; tokenlar loglanmaz. Android native güvenli şifreleme, iOS Keychain kullanılır. Android yedeklemesi kapalıdır; iOS cihazla sınırlı Keychain erişimi ve entitlement ayarı vardır. Paket kuralları: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage).
- Çıkış sunucuda güncel refresh token'ı iptal eder ve cihaz kaydını siler. Ağ yokken cihazdan çıkış yapılır, sunucuda iptal edilemediği açıkça bildirilir. Backend sözleşmesine göre access token kısa süresi bitene kadar geçerlidir.
- Alan doğrulaması ve API `ProblemDetails.errors` ilgili inputlarda gösterilir. Bilinen auth hataları Türkçedir; tanınmayan backend alan hatası backend mesajını korur.

## Kontroller

Planım/Rehberim testleri Bearer header, yerel hedef tarihi, salt okunur program detayı, birden fazla danışman, görev/not kaynaklarının bağımsızlığı, boş yanıt, eksik servis, tekrar deneme, bozuk yanıt, eski veriyi koruma, detay ekranında oturum sona ermesi ve dar/yatay/geniş ekranlarda büyük metin davranışını kapsar.

Dashboard widget testleri `/me` karşılamasını, boş kartları, modül API çağrılmamasını, kartlardan sekmelere geçişi, kaydırma konumunun korunmasını ve dar/yatay/geniş ekranlarda yerleşimi kapsar.

Takip testleri kimliği doğrulanmış JSON liste/refresh akışını, boş durum ve yeniden denemeyi, kilo/ölçüm ekleme ve yenilenmiş geçmişi, form validation'ını, yinelenen kayıt engelini, korunmuş girdileri, dar ekran/büyük metni ve açık formda oturum sona ermesini kontrol eder. Android entegrasyon testi aynı formları gerçek API/PostgreSQL ile çalıştırır.

`mobile` klasöründe:

```powershell
flutter analyze
flutter test
flutter test integration_test/startup_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5063
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

Gerçek Android + API + PostgreSQL testi için Docker Desktop ve mevcut Android emülatörü açıkken repository kökünde **PowerShell 7** ile:

```powershell
./mobile/tool/auth_smoke.ps1
./mobile/tool/auth_smoke.ps1 -AssignmentTest
./mobile/tool/auth_smoke.ps1 -AssignmentWriteTest
```

Varsayılan cihaz `emulator-5554`, API portu `5061` (web yazma testinde `5064`), PostgreSQL portu `55433`; parametrelerle değiştirilebilir. Test adresi Android emülatörünün `10.0.2.2` adresidir; fiziksel cihaz için bu script kullanılmaz.

`-AssignmentTest` ayrı `assignment_flow_test.dart` testini çalıştırır: fixture hesaplarını API ile oluşturur, yalnız geçici PostgreSQL'e program/hedef/görev/not/danışman ilişkisi ekler; Android'de login → Planım/program detayı/hedef/görev/not → Rehberim → logout → ikinci kullanıcı veri izolasyonu akışını doğrular. `ASSIGNMENT_TEST_FIXTURE` yalnız test ortamı kontrolüdür. Sabit test kimlikleri ve test parolası geliştirme/üretim hesabı değildir; uygulama startup'ına seed eklenmez.

`-AssignmentWriteTest`: ilişkiler ve egzersiz kataloğu test fixture'ından gelir; güncel program/hedef/görev/not atamaları gerçek React formlarından HTTP ile oluşturulur (`web/src/AssignmentLive.test.tsx`, JSDOM). Android emülatöründeki Planım aynı PostgreSQL kayıtlarını okur, kullanıcı görevi tamamlar, tamamlanma DB sorgusuyla doğrulanır. Web test bağımlılıkları da kurulmuş olmalıdır. Bu kontrol tarayıcı görünüm testi değildir; gerçek form gönderimi ve gerçek API/veritabanı ile native Android entegrasyonudur.

Planım → Görevler: bekleyen/devam eden görevde **Tamamlandı olarak işaretle** sunucuya `PATCH /api/tasks/{taskId}` gönderir. Görev başarılı yanıttan sonra tamamlandı gösterilir; kaydederken tekrar gönderim kapalıdır. Hata halinde görev korunur ve tekrar denenebilir. Tamamlanan/iptal edilen görevde buton gösterilmez; oturum yenileme mevcut ortak API istemcisini kullanır.

Script benzersiz Compose projesi/veritabanı açar, mevcut backend migration'larını yalnızca test veritabanına uygular, rastgele geçici secret kullanır; Flutter cihaz testi bitince kendi API sürecini ve PostgreSQL container/volume/network'ünü kaldırır. Mevcut kullanıcı veritabanına bağlanmaz. Native güvenli depolama, yeni servisle oturum açılışı, tek kullanımlık refresh, `401` kurtarma, gerçek kilo/ölçüm ekleme ve geçmiş, logout iptalini doğrular. Cihaz testinde klavye girdisi Flutter test aracıyla simüle edilir; HTTP ve güvenli depolama gerçek Android ortamını kullanır. `AUTH_TEST_FIXTURE` yalnızca entegrasyon testinin çalıştırma kontrolüdür; üretim özelliği değildir.

Shell widget testleri giriş ve kayıtlı oturumdan açılışı, beş sekme geçişini, profil/geri davranışını, logout ve oturumun sona ermesini, dar/yatay/geniş ekranlarda büyütülmüş metni kontrol eder. Auth birim testleri mevcut token/refresh davranışını da kapsar. Android açılış testi için `5063` portu kapalı olmalıdır; gerçek `main.dart` ve native token okuma kullanılır. Entegrasyon testi cihazda test uygulamasını bırakabilir; normal uygulamaya dönmek için `flutter run` çalıştırın. Yalnız APK çıktısı almak için yukarıdaki `flutter build apk --debug ...` komutunu kullanın.

Manuel kontrol: gerçek telefonda klavye/form kaydırma, şifre göster/gizle, uygulamayı tamamen kapatıp açınca oturum, çevrimdışı tekrar deneme/çıkış ve iOS Keychain. iOS derlemesi bu Windows ortamında doğrulanamaz. Android release imzası Flutter'ın geliştirme ayarıdır; mağaza dağıtımı bu görevin kapsamı değildir.
