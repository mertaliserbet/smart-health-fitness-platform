# Yapay Zekâ Destekli Sağlık ve Fitness Platformu — Mobil

Flutter Android/iOS temeli; kayıt, giriş, oturum kontrolü/yenileme ve çıkış.
Ana Sayfa bu aşamada yalnızca giriş yapan kullanıcının adı, e-postası ve çıkış butonudur.

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

`10.0.2.2`, Android emülatöründen bilgisayardaki backend'e ulaşır. Port, backend'in HTTP profilindeki `5000` değeridir. Backend URL'si uygulama kodunda varsayılan değildir; her çalıştırma/derlemede `API_BASE_URL` verilmelidir. URL yalnızca sunucu adresidir; sonuna `/api` eklemeyin. Eksik/geçersiz ayar açıklama ekranı gösterir.

- iOS simülatörü: `http://localhost:5000` (backend aynı Mac üzerinde çalışıyorsa).
- Fiziksel telefon: bilgisayarın aynı ağdaki IP adresini kullanın. Backend'i erişilebilir adresle başlatın (`dotnet run --project backend --urls http://0.0.0.0:5000`) ve yerel ağ erişimini kontrol edin. JWT/DB ayarlarını backend README'sindeki gibi sağlayın.
- HTTP sadece debug geliştirme için açıktır. Profile/release HTTPS ister; geçerli sertifikalı backend URL'si kullanın. Sertifika doğrulaması devre dışı bırakılmaz.
- `API_BASE_URL` derlemeye eklenir ve secret değildir. JWT secret veya veritabanı şifresi mobil uygulamaya verilmez.

## Dosya düzeni

```text
lib/
  main.dart                     Configuration ve servisleri bağlar
  app.dart                      Tema ve oturuma göre ekran seçimi
  core/
    app_config.dart             Merkezi URL/timeout/uygulama adı
    api_service.dart            JSON, Bearer, hata ve refresh işlemleri
  features/
    auth/
      user.dart                 Auth ekranlarının kullandığı User alanları
      token_store.dart          Native güvenli token saklama
      auth_service.dart         Kayıt/giriş/me/çıkış ve oturum durumu
      auth_form.dart            Ortak form bileşenleri ve doğrulama
      login_screen.dart
      register_screen.dart
    home/home_screen.dart       Geçici Ana Sayfa
test/                           Birim ve widget testleri
integration_test/               Android üzerinde gerçek backend auth testi
tool/auth_smoke.ps1              Geçici PostgreSQL/API test ortamı
```

Ek state yönetimi veya routing paketi kullanılmaz; Flutter `ChangeNotifier`, `ListenableBuilder` ve `Navigator` yeterlidir.

## Endpointler ve oturum davranışı

| İşlem | Backend |
|---|---|
| Kayıt | `POST /api/auth/register` |
| Giriş | `POST /api/auth/login` |
| Yenileme | `POST /api/auth/refresh` |
| Oturum doğrulama | `GET /api/users/me` |
| Çıkış | `POST /api/auth/logout` |

- Kayıt yalnızca `firstName`, `lastName`, `email`, `password` gönderir; rol seçimi yoktur. Başarıda e-posta doldurulmuş Giriş ekranına döner. Register token üretmez.
- Giriş ve uygulama açılışında `/me` doğrulanmadan Ana Sayfa açılmaz. `User` rolü olmayan hesaplara web panelini kullanma mesajı gösterilir ve mobil oturum kapatılır. Mobil `User`, bu ekranda gereken kimlik/isim/e-posta/rolleri okur; profil düzenleme geliştirilmemiştir.
- Access token süresi yaklaşmışsa veya korunan istek `401` dönerse yenileme yapılır. Eşzamanlı yenilemeler tek istekte birleşir. Başarılı refresh sonrası eski token çifti değiştirilir; istek en fazla bir kez tekrar edilir.
- Geçersiz refresh oturumu silip Giriş'e döndürür. Ağ/timeout/5xx hatasında mevcut token korunur ve tekrar deneme sunulur.
- Access/refresh çifti tek şifreli kayıt olarak, sunucu adresine göre ayrı anahtarla saklanır. Parola saklanmaz; tokenlar loglanmaz. Android native güvenli şifreleme, iOS Keychain kullanılır. Android yedeklemesi kapalıdır; iOS cihazla sınırlı Keychain erişimi ve entitlement ayarı vardır. Paket kuralları: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage).
- Çıkış sunucuda güncel refresh token'ı iptal eder ve cihaz kaydını siler. Ağ yokken cihazdan çıkış yapılır, sunucuda iptal edilemediği açıkça bildirilir. Backend sözleşmesine göre access token kısa süresi bitene kadar geçerlidir.
- Alan doğrulaması ve API `ProblemDetails.errors` ilgili inputlarda gösterilir. Bilinen auth hataları Türkçedir; tanınmayan backend alan hatası backend mesajını korur.

## Kontroller

`mobile` klasöründe:

```powershell
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

Gerçek Android + API + PostgreSQL testi için Docker Desktop ve mevcut Android emülatörü açıkken repository kökünde **PowerShell 7** ile:

```powershell
./mobile/tool/auth_smoke.ps1
```

Varsayılan cihaz `emulator-5554`, API portu `5061`, PostgreSQL portu `55433`; parametrelerle değiştirilebilir. Test adresi Android emülatörünün `10.0.2.2` adresidir; fiziksel cihaz için bu script kullanılmaz.

Script benzersiz Compose projesi/veritabanı açar, mevcut backend migration'ını yalnızca test veritabanına uygular, rastgele geçici secret kullanır; Flutter cihaz testi bitince kendi API sürecini ve PostgreSQL container/volume/network'ünü kaldırır. Mevcut kullanıcı veritabanına bağlanmaz. Native güvenli depolama, yeni servisle oturum açılışı, tek kullanımlık refresh, `401` kurtarma ve logout iptalini doğrular. Cihaz testinde klavye girdisi Flutter test aracıyla simüle edilir; HTTP ve güvenli depolama gerçek Android ortamını kullanır. `AUTH_TEST_FIXTURE` yalnızca entegrasyon testinin çalıştırma kontrolüdür; üretim özelliği değildir.

Doğrulama: `flutter analyze` temiz; 16 birim/widget testi ve 1 Android + gerçek backend entegrasyon testi başarılı. Normal uygulamanın Android debug APK'sı derlendi. Entegrasyon testi APK çıktısını test uygulamasıyla değiştirebilir; normal uygulama APK'sını almak için yukarıdaki `flutter build apk --debug ...` komutunu tekrar çalıştırın.

Manuel kontrol: gerçek telefonda klavye/form kaydırma, şifre göster/gizle, uygulamayı tamamen kapatıp açınca oturum, çevrimdışı tekrar deneme/çıkış ve iOS Keychain. iOS derlemesi bu Windows ortamında doğrulanamaz. Android release imzası Flutter'ın geliştirme ayarıdır; mağaza dağıtımı bu görevin kapsamı değildir.
