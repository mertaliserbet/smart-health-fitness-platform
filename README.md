# Yapay Zekâ Destekli Sağlık ve Fitness Platformu

İki kişilik bitirme projesi. Mobil Flutter, web React + TypeScript, backend ASP.NET Core ve veritabanı PostgreSQL kullanır. İstemciler yalnızca backend'e bağlanır.

Mevcut backend kayıt/giriş, JWT, refresh, mevcut kullanıcı ve health endpointlerini içerir. Mobilde auth ve geçici Ana Sayfa vardır. Web'de gerçek auth bağlantısı ve geliştirme için örnek danışman panelleri vardır; danışan/program endpointleri henüz backend'de uygulanmamıştır. AI servisi bu çalıştırma sırasına dahil değildir.

## Projeyi Her Bilgisayar Açılışında Sıfırdan Çalıştırma

### Kolay yöntem — VS Code'da tek terminal

VS Code'da repository'yi aç, **Terminal → New Terminal** seç ve repository kökünde şunu çalıştır:

```powershell
.\baslat.cmd
```

Backend, web ve mobil aynı terminalde çalışır; ayrı terminal pencereleri açılmaz. Docker Desktop gerektiğinde başlatılır; PostgreSQL ve mevcut migration'lar hazırlanır; emülatör açılır ve Android hazır olduğunda Flutter çalışır. Web adresi `http://localhost:5173`. PostgreSQL imajı yerelde varsa Docker Hub'a tekrar bağlanmadan kullanılır; ilk indirme için internet gerekir.

İlk kullanımda mevcut PostgreSQL parolanı ve portunu gir (varsayılan port için Enter). JWT anahtarı otomatik üretilir ve sonraki açılışlarda aynı anahtar kullanılır. Ayarlar `.local/development.xml` içinde Windows DPAPI ile şifreli tutulur; yalnız aynı bilgisayar/Windows hesabı açabilir. `.local/` Git'e dahil edilmez. [Microsoft: şifreli yerel credential saklama](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/export-clixml?view=powershell-5.1).

Sonraki bilgisayar açılışlarında tekrar parola veya uzun komut girmen gerekmez. İlk çalıştırmada bağımlılık indirme/derleme zaman alabilir; internet gerekir. Web paketleri yalnız ilk kullanımda veya `package-lock.json` değiştiğinde kurulurlar. npm PATH'te yoksa mevcut yerel Codex Node/pnpm runtime'ı ile npm aracı kullanılır; bu da yoksa Node.js kurulumu gerektiği açıkça bildirilir.

Çıktılar `[Backend]`, `[Web]` ve `[Mobile]` etiketleriyle aynı terminalde görünür. Kapatırken `Ctrl+C` kullan; başlatıcının backend, web ve mobil süreçleri durdurulur. Windows `Terminate batch job (Y/N)?` sorarsa `Y` ve Enter bas. PostgreSQL ve emülatör açık kalabilir; veritabanı verileri korunur. Tekrar başlatmak için aynı komutu çalıştır. Açık servislerin ikinci kopyasını başlatmadan önce ilk çalıştırmayı durdur.

Terminalden alternatif: `cmd /c baslat.cmd`. Kayıtlı parola/port yanlışsa repository kökünde bir kez `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/start-dev.ps1 -Configure` çalıştır; bu işlem veritabanının parolasını değiştirmez, yalnız başlatıcının yerel ayarını günceller. Mevcut veritabanında doğru eski parola girilmelidir. Windows hesabı/bilgisayar değişirse yerel ayarların yeniden girilmesi gerekir.

### Elle çalıştırma (gerektiğinde)

Bu bölüm **Windows + VS Code + PowerShell** içindir. Burada sıfırdan çalıştırmak, servisleri yeniden başlatmak demektir; veritabanını veya kullanıcı verilerini silmek gerekmez.

### İlk kurulumda bir kez

- .NET 10 SDK, Flutter SDK, Android Studio/SDK, Docker Desktop ve Node.js 22.12 veya üstünü kurun. Flutter ve Dart VS Code eklentilerini etkinleştirin.
- Android Studio → **Device Manager** üzerinden bir Android emülatörü oluşturun. Bu bilgisayarda adı `deneme_cihazi`. Gerekli Android SDK lisanslarını `flutter doctor --android-licenses` ile kabul edin; `flutter doctor` ile kurulum durumunu kontrol edin.
- PostgreSQL için bir yerel parola belirleyip parola yöneticinizde saklayın. Daha önce oluşturulmuş veritabanı varsa **ilk kullanılan parolayı** kullanın. Yeni bir parola yazmak mevcut Docker volume'ündeki parolayı değiştirmez.
- JWT secret'ı bir kez üretip parola yöneticinize kaydedin. Repository kökünde aşağıdaki komutlar değeri terminale yazdırmadan panoya kopyalar; parola yöneticinize yapıştırdıktan sonra panoyu temizleyin:

```powershell
$jwtKeyBytes = New-Object byte[] 64
$jwtRandom = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $jwtRandom.GetBytes($jwtKeyBytes) } finally { $jwtRandom.Dispose() }
$jwtSecret = [Convert]::ToBase64String($jwtKeyBytes)
Set-Clipboard -Value $jwtSecret
```

Şimdi panodaki değeri parola yöneticinize yapıştırıp kaydedin. Kaydettikten sonra ayrı olarak çalıştırın:

```powershell
Set-Clipboard -Value ''
Remove-Variable jwtSecret, jwtKeyBytes, jwtRandom
```

JWT secret backend'in token imzalama anahtarıdır; en az 32 byte olmalıdır. Sonraki açılışlarda aynı değeri kullanın. Değişirse mevcut access token'lar geçersiz olur. Gerçek şifre/secret'ı kaynak dosyalara, `appsettings.json`, Git veya mobil/web ayarlarına yazmayın.

### 1. Repository ve Docker Desktop'ı açın

VS Code → **File → Open Folder** ile `smart-health-fitness-platform` klasörünü açın. **Terminal → New Terminal** ile PowerShell terminali açın. Aşağıdaki Terminal 1 komutları repository kökünden çalışır.

Windows Başlat menüsünden **Docker Desktop**'ı açın ve Engine hazır olana kadar bekleyin. Kontrol:

```powershell
docker info
```

Docker Engine bağlantı hatası varsa önce Docker Desktop'ın açılmasını tamamlayın.

### 2. Terminal 1 — PostgreSQL ve backend

Her yeni terminalde ortam değişkenleri yeniden ayarlanmalıdır. Aşağıdaki iki giriş ekranda görünmez. PostgreSQL parolasını ve ilk kurulumda sakladığınız JWT secret'ı girin:

```powershell
$databasePasswordInput = Read-Host 'PostgreSQL parolası' -AsSecureString
$env:POSTGRES_PASSWORD = [System.Net.NetworkCredential]::new('', $databasePasswordInput).Password
$jwtSecretInput = Read-Host 'Kaydettiğiniz JWT secret' -AsSecureString
$env:JWT_SECRET = [System.Net.NetworkCredential]::new('', $jwtSecretInput).Password

# Önceki kurulumda 5433 kullandıysanız bu satırdan önce:
# $env:POSTGRES_PORT = '5433'
docker compose -f backend/docker-compose.yml up -d --wait
docker compose -f backend/docker-compose.yml ps

$databasePort = if ($env:POSTGRES_PORT) { $env:POSTGRES_PORT } else { '5432' }
$quotedDatabasePassword = $env:POSTGRES_PASSWORD.Replace('"', '""')
$env:DATABASE_CONNECTION_STRING = "Host=localhost;Port=$databasePort;Database=smart_health_fitness;Username=smart_health_fitness;Password=`"$quotedDatabasePassword`";Timeout=5;Command Timeout=5"

dotnet tool restore
dotnet restore backend/SmartHealthFitness.Api.csproj
dotnet build backend/SmartHealthFitness.Api.csproj --no-restore
dotnet tool run dotnet-ef database update --project backend/SmartHealthFitness.Api.csproj --no-build
dotnet run --project backend/SmartHealthFitness.Api.csproj --launch-profile http --no-build
```

`database update`, mevcut migration'ları uygular; yeni migration üretmez ve her açılışta tekrar çalıştırılabilir. EF Core, backend'in veritabanıyla konuştuğu araçtır. Migration, tablo yapısını kuran/sürümleyen kayıttır.

`Now listening on: http://localhost:5000` görünmeli. **Terminal 1 açık kalmalı.** Tarayıcıdan `http://localhost:5000/api/health` adresini açın: `Healthy` ve `Connected` beklenir. Swagger (API'yi elle deneme ekranı): `http://localhost:5000/swagger`.

- API başlamıyorsa eksik connection string/JWT secret mesajını kontrol edin.
- Health `503` veriyorsa Docker, PostgreSQL parolası ve portunu kontrol edin.
- Varsayılan DB ve DB kullanıcı adı `smart_health_fitness`. Özel `POSTGRES_DB` / `POSTGRES_USER` kullanıyorsanız connection string'de de aynı değerleri kullanın.

### 3. Terminal 2 — Android emülatörünü açın

Yeni VS Code terminali açın; repository kökünden:

```powershell
flutter emulators
flutter emulators --launch deneme_cihazi
flutter devices
```

Başka bilgisayarda listede görünen kendi emülatör adınızı kullanın. Zaten açıksa tekrar açmayın. Android ana ekranı gelene kadar bekleyin. Alternatif: Android Studio → Device Manager → emülatörün **Play** düğmesi. `flutter devices` çıktısında Android cihazını görmeden mobil komutuna geçmeyin.

### 4. Terminal 2 — Flutter mobil uygulamayı çalıştırın

```powershell
cd mobile
flutter pub get
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

Cihaz ID'si farklıysa `flutter devices` çıktısındaki ID'yi kullanın. **Terminal 2 ve emülatör açık kalmalı.** Terminalde `r` hot reload, `R` hot restart yapar. API adresini değiştirdiğinizde `q` ile durdurup yeni `--dart-define` ile yeniden çalıştırın.

Android debug modunda URL verilmezse merkezi `AppConfig` geliştirme adresini (`http://10.0.2.2:5000`) kullanır; VS Code'da `mobile/lib/main.dart` dosyasından varsayılan debug açılışı da desteklenir. Başka cihaz/port için URL'yi açıkça verin. Release/profile için `API_BASE_URL` zorunludur ve HTTPS olmalıdır.

Giriş yapılmadıysa token okunduktan sonra **Giriş Yap** ekranı backend'e bağlanmadan açılır. Backend kapalıysa giriş denemesi açıklayıcı hata verir. Kayıtlı oturum doğrulanamazsa hata/tekrar deneme ekranı açılır; doğrulama tamamlanmadan Ana Sayfa açılmaz.

### 5. Terminal 3 — Web uygulamasını çalıştırın

Repository kökünde yeni terminal açın:

```powershell
cd web
npm ci
npm run dev
```

Tarayıcıda `http://localhost:5173` açın. **Terminal 3 açık kalmalı.** `npm ci` ilk kurulumda veya `package-lock.json` değişince gereklidir; diğer açılışlarda doğrudan `npm run dev` yeterlidir. Vite, web geliştirme sunucusudur; port 5173 doluysa başka porta otomatik geçmez.

Varsayılan `/api` istekleri Vite proxy üzerinden backend'in `http://localhost:5000` adresine gider. Proxy, isteği doğru sunucuya iletir. Bu varsayılan için `.env.local` gerekmez. Backend adresi farklıysa:

```powershell
Copy-Item .env.example .env.local
```

Mevcut `.env.local` dosyanız varsa üzerine kopyalamayın. İçindeki `VITE_API_BASE_URL` değerini örneğin `http://localhost:5001` olarak düzenleyin ve web sunucusunu yeniden başlatın. `VITE_` ayarları tarayıcıya açıktır; secret içermez. Direkt bağlantıda backend CORS listesinde web adresi bulunmalıdır; mevcut geliştirme listesi `localhost:5173` ve `localhost:3000` içerir.

Public register yalnız `User` rolü oluşturur; bu hesap mobil içindir. Trainer/Dietitian/Admin hesabı kendiliğinden oluşturulmaz. Web'deki örnek panel düğmeleri development modunda arayüzü denemek içindir; gerçek giriş veya backend'e kayıt yapmaz. Henüz uygulanmamış danışan/program endpointleri gerçek oturumla hata dönebilir.

### Adresler ve configuration özeti

| Bileşen / ayar | Değer / kullanım |
|---|---|
| PostgreSQL | Bilgisayarda `localhost:5432`; özel port kullanılıyorsa aynı portu connection string'e yazın |
| Backend | `http://localhost:5000`; Development HTTP profili |
| Swagger / health | `/swagger` / `/api/health` |
| Android emülatöründen backend | `http://10.0.2.2:5000`; `10.0.2.2` bilgisayara ulaşır, emülatörde `localhost` emülatörün kendisidir |
| Mobil `API_BASE_URL` | Derleme/çalıştırma ayarı; sonuna `/api` eklemeyin; sadece debug Android'de merkezi varsayılan vardır |
| Web | `http://localhost:5173`; varsayılan proxy backend portu 5000 |
| Web `VITE_API_BASE_URL` | Varsayılan boş; alternatif backend adresi için `.env.local` |
| `POSTGRES_PASSWORD` | Terminal 1; kalıcı DB'nin mevcut parolası |
| `POSTGRES_PORT` / DB / USER | İsteğe bağlı; varsayılan `5432` / `smart_health_fitness` / `smart_health_fitness` |
| `DATABASE_CONNECTION_STRING` | Terminal 1; backend ve EF komutları için bağlantı bilgisi |
| `JWT_SECRET` | Terminal 1; sabit, gizli, en az 32 byte anahtar |
| JWT süreleri | Varsayılan access 15 dakika, refresh 7 gün; gerekirse `Jwt__AccessTokenMinutes` / `Jwt__RefreshTokenDays` |

Mobil/web'e JWT secret veya PostgreSQL parolası verilmez. Fiziksel Android telefonda `10.0.2.2` yerine bilgisayarın yerel ağ IP'si gerekir; ayrıntılar `mobile/README.md` içindedir.

### Kapatma ve yeniden başlatma

1. Flutter terminalinde `q`; web terminalinde `Ctrl+C`; backend terminalinde `Ctrl+C` kullanın.
2. Backend durunca **aynı Terminal 1'de**, repository kökünde `docker compose -f backend/docker-compose.yml stop` çalıştırın. Parola ortam değişkeni bu terminalde hâlâ vardır. PostgreSQL verileri korunur.
3. Android emülatör penceresini kapatın. Docker Desktop'ı isterseniz son olarak kapatın.
4. Aynı açık terminalde yeniden başlatırken configuration tekrar gerekmez: PostgreSQL `up -d --wait` → backend `dotnet run ...` → emülatör → Flutter `flutter run ...` → web `npm run dev`.
5. Bilgisayar/terminaller kapandıysa bu bölümdeki sırayı ve Terminal 1 ortam değişkenlerini yeniden uygulayın. Bağımlılıklar/kod değişmediyse restore/install/build adımları atlanabilir; yeni migration geldiyse `database update` çalıştırın.

Geliştirme verilerini korumak için `down --volumes`, **Wipe Data** veya uygulamayı kaldırma adımlarını rutin başlatma olarak kullanmayın.

### Siyah ekran / açılış sorunu

- Bu incelemede Flutter crash'i olmadan siyah ekranla birlikte Android **“System UI isn't responding”** uyarısı görüldü. Emülatörün Android sistemi yeniden başlatılınca aynı uygulama normal Impeller motoruyla Giriş ekranını çizdi. Çizim motorunu değiştirmek sorunu çözmedi; uygulamada kalıcı motor değişikliği yapılmadı.
- Böyle bir durumda Flutter'ı durdurun; emülatörü kapatıp Android Studio Device Manager'da **Cold Boot Now** ile açın. Bu işlem uygulama verilerini silmez. `flutter devices` sonrası normal `flutter run` ile tekrar deneyin.
- Oturum depolama işlemleri 5 saniye, her HTTP isteğinin başlık/gövde okuması 20 saniye ile sınırlıdır. Refresh gerektiğinde birden fazla sıralı işlem olabileceğinden toplam oturum doğrulaması daha uzun olabilir; hata ekranda gösterilir. Beklenmeyen başlangıç hataları boş ekran yerine açıklama gösterir.
- Entegrasyon testi cihazda test APK'sını bırakabilir. Test sonrası normal uygulamayı yeniden kurmak/açmak için `flutter run` kullanın; test APK'sı normal uygulama başlangıcı değildir.

## Mobil kontroller

`mobile` klasöründe:

```powershell
flutter analyze
flutter test
flutter test integration_test/startup_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5063
```

Son test gerçek `main.dart`, native token okuma, görünür Login ve backend kapalı giriş hatasını doğrular. **5063 portunda backend çalışmamalıdır.** Gerçek auth akışının ayrı geçici PostgreSQL/backend ile testi için repository kökünde PowerShell 7 ile `./mobile/tool/auth_smoke.ps1` çalıştırın. Testler geliştirme veritabanına bağlanmaz. Android testi bitince normal `flutter run` ile mobil uygulamayı tekrar başlatın.

Alan ayrıntıları: `backend/README.md`, `mobile/README.md`, `web/README.md`. Proje kuralları: `AGENTS.md` ve `docs/`.
