# Backend API

**Yapay Zekâ Destekli Sağlık ve Fitness Platformu** için tek ASP.NET Core Web API projesi.

## Manuel beslenme kayıtları

`AddManualNutritionRecords` yalnız `nutrition_records` tablosunu ekler. Mevcut `NutritionService`/`NutritionGoal` kullanılır; yeni hedef entity'si veya AI tablosu yoktur.

- `POST /api/users/me/nutrition-records`: manuel öğün ekleme.
- `GET /api/users/me/nutrition-records`: kendi geçmişini listeleme; tarih/aralık/öğün filtresi.
- `GET /api/users/me/nutrition-records/daily-summary`: kendi günlük kalori/makro toplamları ve geçerli aktif hedef.

Üç endpoint de JWT + `User` rolü ister. Sahiplik token'dan alınır; validation ve gün sınırları `docs/API_CONTRACT.md` 20. bölümündedir. Başlatıcı migration'ı uygular; ayrı başlangıçta aşağıdaki EF `database update` komutunu çalıştırın. `./backend/tests/AuthSmoke.ps1` gerçek geçici PostgreSQL'de beslenme, yetki, hedef, gün sınırı ve mevcut auth/atama kontrollerini içerir.

## GPS koşu kayıtları

`AddRunningActivities` yalnız `running_activities` tablosunu ekler. JWT + `User` rolüyle:

- `POST /api/users/me/running-activities`: tamamlanmış gerçek GPS koşusu; ilk gönderim 201, aynı ID/içerik tekrarı 200.
- `GET /api/users/me/running-activities`: yalnız kullanıcının kendi geçmiş özetleri.
- `GET /api/running-activities/{runningActivityId}`: kendi kayıt detayı/segmentli rota; başka kullanıcı veya bulunamayan ID için 404.

Mesafe GPS segmentlerinden backend'de hesaplanır; pace/hız duraklamalar hariç aktif süreyi kullanır. Rota JSONB'dir. Kalori tahmini yoktur. Alanlar, validation ve hata sözleşmesi `docs/API_CONTRACT.md` 21. bölümündedir. Başlatıcı migration'ı uygular; ayrı çalıştırmada aşağıdaki `database update` komutunu kullanın.

`./backend/tests/AuthSmoke.ps1`, aynı geçici PostgreSQL fixture'ında `RunningChecks.ps1` üzerinden metrik/rota, kullanıcı/rol izolasyonu, validation ve eşzamanlı tekrar gönderimini doğrular. Android konum servisi + PostgreSQL kontrolü: `./mobile/tool/auth_smoke.ps1 -RunningTest`.

## Antrenman programı düzenleme

`PUT /api/workout-plans/{workoutPlanId}` uygulanmıştır. Oluşturan Trainer + aktif danışan ilişkisi zorunludur; geçmiş program düzenlenmez. Tam içerik `UpdateWorkoutPlanRequest` ile gönderilir; korunan gün/egzersiz kimlikleri ve GET'ten gelen nullable `updatedAt` sürümü kullanılır. Eski sürüm `409` döner; işlem yeni plan oluşturmaz. Yeni migration yoktur. Ayrıntılar `docs/API_CONTRACT.md` 15.5'tedir. `AuthSmoke.ps1` içindeki `WorkoutPlanEditChecks.ps1`, gerçek PostgreSQL'de yetki, validation/rollback, yedi gün/sıra değişimi, kimliklerin korunması, pasif katalog, eşzamanlı düzenleme ve mobil okumaları doğrular.

## Antrenman oturumları ve egzersiz kayıtları

`AddWorkoutSessionsAndLogs` yalnız `workout_sessions` ve `workout_logs` tablolarını ekler. Kullanıcı kendi aktif programında oturum başlatır, günündeki egzersizleri PUT ile kaydeder ve oturumu tamamlar/iptal eder. Açık oturum tekrar başlatılınca aynı kimlik döner; tamamla/iptal tekrarları güvenlidir. Kullanıcı başına tek açık oturum ve oturum/egzersiz başına tek log DB unique indexleriyle korunur. Trainer sadece aktif bağlı danışanın geçmişini/detayını okur; User adına yazamaz. Sözleşme: `docs/API_CONTRACT.md` bölüm 16.

Program ilk oturumundan sonra düzenlenmez; yeni program atanır. `WorkoutPlanResponse.hasSessions` web formunu buna göre kapatır; FK RESTRICT geçmişin silinmesini engeller. Eski programda açık oturum bitirilebilir. Tamamlama tüm egzersizlerin yapıldığı anlamına gelmez; web hedef/gerçekleşen ve eksik egzersizleri ayrı gösterir. Mobil ekran entegrasyonu Mert'in sorumluluğundadır; adımlar `docs/WORKOUT_SESSION_INTEGRATION.md` içindedir.

`AuthSmoke.ps1` içindeki `WorkoutSessionChecks.ps1` gerçek PostgreSQL'de sahiplik/rol, validation, yeniden gönderim, eşzamanlı başlatma/log/tamamlama/program düzenleme, kısmi ilerleme, program değiştirme, sayfalama ve bitmiş/pasif ilişkileri sınar.

## Gereksinimler

- .NET 10 SDK
- PostgreSQL (yerelde aşağıdaki Docker Compose servisi kullanılabilir)
- Docker Compose kullanılıyorsa çalışan Docker Desktop / Docker Engine

## Yerelde çalıştırma (PowerShell)

Aşağıdaki komutları repository kökünde, aynı terminalde çalıştırın.

### 1. PostgreSQL'i başlatın

Yerel geliştirme için bir parola belirleyin. Komut parolayı ekranda göstermez; değer yalnızca terminalin ortam değişkeninde tutulur.

```powershell
$databasePasswordInput = Read-Host 'Yerel PostgreSQL parolası' -AsSecureString
$env:POSTGRES_PASSWORD = [System.Net.NetworkCredential]::new('', $databasePasswordInput).Password
docker compose -f backend/docker-compose.yml up -d --wait
```

Varsayılan veritabanı ve kullanıcı: `smart_health_fitness`. Port: `5432`.
Port kullanılıyorsa Compose komutundan önce `$env:POSTGRES_PORT = '5433'` ayarlayın ve aşağıdaki bağlantı bilgisinde aynı portu kullanın.

Veri `postgres_data` volume'ünde kalıcıdır. Sonraki çalıştırmalarda ilk oluşturduğunuz parolayı kullanın; ortam değişkenini değiştirmek mevcut veritabanının parolasını değiştirmez.

### 2. API bağlantısını ayarlayın ve çalıştırın

```powershell
$databasePort = if ($env:POSTGRES_PORT) { $env:POSTGRES_PORT } else { '5432' }
# Connection string içindeki özel karakterlerin doğru işlenmesi için parolayı alıntılayın.
$quotedDatabasePassword = $env:POSTGRES_PASSWORD.Replace('"', '""')
$env:DATABASE_CONNECTION_STRING = "Host=localhost;Port=$databasePort;Database=smart_health_fitness;Username=smart_health_fitness;Password=`"$quotedDatabasePassword`";Timeout=5;Command Timeout=5"

# İlk kurulumda bir JWT secret üretin; aynı ortamda sonraki çalıştırmalarda aynı değeri kullanın.
# Üretilen değeri repository'ye veya loglara yazmayın; güvenli secret yönetiminde saklayın.
$jwtKeyBytes = New-Object byte[] 64
$jwtRandom = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $jwtRandom.GetBytes($jwtKeyBytes) } finally { $jwtRandom.Dispose() }
$env:JWT_SECRET = [Convert]::ToBase64String($jwtKeyBytes)

dotnet tool restore
dotnet restore backend/SmartHealthFitness.Api.csproj
dotnet build backend/SmartHealthFitness.Api.csproj --no-restore
dotnet tool run dotnet-ef database update --project backend/SmartHealthFitness.Api.csproj --no-build
dotnet run --project backend/SmartHealthFitness.Api.csproj --launch-profile http --no-build
```

Mevcut PostgreSQL sunucusunu kullanıyorsanız Compose adımı gerekmez. `DATABASE_CONNECTION_STRING` değerini kendi sunucunuzun bilgileriyle ayarlayın.

Bağlantı bilgisi önce configuration içindeki `DATABASE_CONNECTION_STRING` anahtarından, boşsa `ConnectionStrings:DefaultConnection` anahtarından okunur. İkinci seçenek ortam değişkeni olarak `ConnectionStrings__DefaultConnection` adıyla da verilebilir. İki değer de boşsa API açık bir configuration hatasıyla başlamaz. Gerçek bağlantı bilgisini `appsettings.json`, launch profile veya repository içindeki başka bir dosyaya yazmayın.

### 3. Kontrol edin

- Swagger UI: <http://localhost:5000/swagger>
- OpenAPI JSON: <http://localhost:5000/swagger/v1/swagger.json>
- Sağlık kontrolü: <http://localhost:5000/api/health>

```powershell
Invoke-RestMethod http://localhost:5000/api/health
```

PostgreSQL'e bağlanabiliyorsa `200 OK`:

```json
{
  "status": "Healthy",
  "database": "Connected",
  "checkedAt": "2026-10-07T12:00:00Z"
}
```

Bağlantı kurulamıyorsa `503 Service Unavailable` ve `ProblemDetails` döner. Yanıtta bağlantı bilgisi/parola bulunmaz. Bu kontrol uygulama tabloları veya migration oluşturmaz.

### Durdurma

API için terminalde `Ctrl+C`. PostgreSQL için:

```powershell
docker compose -f backend/docker-compose.yml stop
```

## Configuration ve dosya sorumlulukları

| Dosya | Sorumluluk |
|---|---|
| `Program.cs` | Uygulamayı ve middleware sırasını kurar; controller'ları yayınlar. |
| `Configuration/ServiceCollectionExtensions.cs` | Controller, JSON, DbContext, PostgreSQL, Swagger, ProblemDetails ve CORS servislerini kaydeder. |
| `Data/AppDbContext.cs` | EF Core'un merkezi veritabanı erişim noktasıdır; DI üzerinden her istekte ayrı örnek kullanılır. |
| `Controllers/HealthController.cs` | `/api/health` üzerinden veritabanına erişilebilirliği kontrol eder. |
| `Contracts/HealthResponse.cs` | Başarılı sağlık kontrolünün JSON yanıtını tanımlar. |
| `Entities/`, `Data/AuthEntityConfiguration.cs` | User, rol ilişkileri, refresh token ve PostgreSQL eşleştirmeleri. |
| `Data/AppDbContextFactory.cs` | EF CLI için yalnızca veritabanı configuration'ını kullanır. |
| `Services/AuthService.cs` | Kayıt, parola kontrolü, login, refresh transaction'ı, logout ve mevcut kullanıcı okuma. |
| `Services/TokenService.cs` | JWT ve rastgele refresh token üretimi; refresh token hash'i. |
| `Configuration/AuthenticationConfiguration.cs`, `JwtOptions.cs` | JWT validation, password hasher ve rol policy'leri. |
| `Controllers/AuthController.cs`, `UsersController.cs`, `Contracts/` | HTTP akışı, validation ve request/response sözleşmeleri. |
| `Configuration/AuthenticationDocumentFilter.cs` | Swagger'da yalnızca korunan işlemlere Bearer gereksinimi ekler. |
| `Migrations/`, `../.config/dotnet-tools.json` | EF migration ve sürümü sabitlenmiş yerel EF CLI. |
| `Services/AdvisorService.cs`, `WorkoutService.cs`, `NutritionService.cs`, `ExerciseService.cs` | Danışan ilişkileri, program/hedef atamaları ve egzersiz kataloğu. |
| `tests/AuthSmoke.ps1` | Ayrı PostgreSQL servisiyle auth, tracking ve danışman iş akışı entegrasyon kontrolleri. |
| `appsettings*.json`, `Properties/launchSettings.json` | Gizli olmayan ayarlar ve yerel HTTP çalıştırma profili. |
| `docker-compose.yml` | Yalnızca yerel PostgreSQL servisi. |

Swagger/OpenAPI ve CORS middleware yalnızca `Development` ortamında aktiftir. CORS, tarayıcıdaki istemcinin API'yi çağırmasına izin veren kuraldır; izinli adresler `appsettings.Development.json` içindeki `Cors:AllowedOrigins` listesindedir. Farklı bir geliştirme portu kullanıyorsanız listeyi güncelleyin. Production ortamı için CORS izni tanımlı değildir. Yerel profil HTTP kullanır; yayın ortamında HTTPS barındırma ayarı ayrıca yapılmalıdır.

## Auth configuration

`Jwt` bölümü `appsettings.json` içinde gizli olmayan varsayılanları taşır. Secret boş bırakılmıştır; `JWT_SECRET` veya `Jwt__Secret` ortam değişkeniyle verilir. En az 32 byte gerekir; yukarıdaki örnek kriptografik rastgele değer üretir. Secret eksik/zayıfsa API başlamaz. Secret değişirse mevcut access token'lar geçersiz olur.

- `Jwt:Issuer` / `JWT_ISSUER`: `SmartHealthFitness.Api`
- `Jwt:Audience` / `JWT_AUDIENCE`: `SmartHealthFitness.Clients`
- `Jwt:AccessTokenMinutes` / `Jwt__AccessTokenMinutes`: varsayılan `15`, aralık `1–60`
- `Jwt:RefreshTokenDays` / `Jwt__RefreshTokenDays`: varsayılan `7`, aralık `1–30`

JWT'de kullanıcı kimliği `sub`, rol adları `role` claim'lerinde bulunur. `User`, `Trainer`, `Dietitian`, `Admin` isimli policy'ler aynı isimli rolü gerektirir. Korunan controller/action için `[Authorize]`, rol için `[Authorize(Roles = "Admin")]` veya `[Authorize(Policy = "Admin")]` kullanılabilir. Fallback policy yeni endpointleri varsayılan olarak korur; public endpointlerde `[AllowAnonymous]` gerekir.

Parolalar ASP.NET Core `PasswordHasher<User>` ile salt içeren PBKDF2 hash'i olarak saklanır. Refresh token 64 rastgele byte'tan üretilir; veritabanında yalnızca SHA-256 hash'i bulunur. Refresh sırasında eski token iptal edilir ve yeni çift döner; istemci refresh token'ını güncellemelidir. Süre/revocation ve pasif hesap kontrolü backend'de uygulanır. Logout refresh token'ı iptal eder; mevcut access token kısa süresi sonuna kadar geçerli kalır. Rol değişikliği yeni login/refresh ile JWT'ye yansır.

## Endpointler ve manuel auth kontrolü

| İşlem | Endpoint | Başarı | Yetki |
|---|---|---|---|
| Register | `POST /api/auth/register` | `201` kullanıcı özeti | Public, yalnızca `User` rolü |
| Login | `POST /api/auth/login` | `200` access/refresh + kullanıcı | Public |
| Refresh | `POST /api/auth/refresh` | `200` yeni access/refresh | Public, geçerli refresh zorunlu |
| Me | `GET /api/users/me` | `200` mevcut kullanıcı | Bearer JWT |
| Logout | `POST /api/auth/logout` | `204` | Bearer JWT, kendi refresh token'ı |
| Health | `GET /api/health` | `200` / `503` | Public |
| Kilo geçmişi / ekleme | `GET/POST /api/users/me/weight-records` | `200` liste / `201` kayıt | Bearer JWT + `User` |
| Ölçüm geçmişi / ekleme | `GET/POST /api/users/me/body-measurements` | `200` liste / `201` kayıt | Bearer JWT + `User` |

Request/response ve hata detayları: `../docs/API_CONTRACT.md` bölüm 8, 9.1 ve 39.

Swagger'da register ile hesap oluşturun (`firstName`, `lastName`, `email`, `password`). Parola 12–128 karakter olmalı; e-posta aynıysa `409` döner. Public register'da rol alanı kabul edilmez. Ardından login yapın ve dönen `accessToken` değerini **Authorize → Bearer** alanına yapıştırın (`Bearer ` öneki olmadan). `GET /api/users/me` çağrısını deneyin. Refresh için login'in `refreshToken` alanını gönderin; eski refresh token tekrar kullanılırsa `401` döner.

## Migration ve otomatik kontroller

`InitialUserAuthentication` yalnızca `users`, `roles`, `user_roles`, `refresh_tokens` tablolarını oluşturur. Dört rol eklenir; hiçbir admin/trainer/dietitian kullanıcı hesabı seed edilmez. User profil alanları nullable olarak hazırdır; profil düzenleme endpointi bu aşamada yoktur.

`AddWeightRecordsAndBodyMeasurements` yalnızca `weight_records` ve `body_measurements` tablolarını ekler. Kayıtlar JWT'deki kullanıcıya aittir; `userId` request'ten seçilemez. Sayı aralıkları ve boş ölçüm kuralları API validation ve PostgreSQL check constraint'leriyle korunur. UTC tarihleri ve kullanıcı/tarih indeksleri kullanılır. İki endpoint grubunun sözleşmesi `API_CONTRACT.md` bölüm 17–18'de bulunur. Aktif bağlı Trainer/Dietitian için danışan kilo/ölçüm okuma endpointleri de uygulanmıştır; erişim kuralları aşağıdaki danışman iş akışında açıklanır.

Migration uygulama başlangıcında otomatik çalışmaz; yukarıdaki `database update` komutuyla uygulanır. EF migration oluşturmak için JWT secret gerekmez, ancak veritabanı connection string configuration'ı gerekir. Model ile migration uyumunu kontrol etmek için:

```powershell
dotnet tool run dotnet-ef migrations has-pending-model-changes --project backend/SmartHealthFitness.Api.csproj
```

Repository kökünde (Windows PowerShell veya PowerShell 7, çalışan Docker Desktop):

```powershell
& ./backend/tests/AuthSmoke.ps1
```

Script restore/build yapar, rastgele geçici credential kullanır, ayrı bir PostgreSQL Compose projesine migration uygular ve API'yi gizli bir işlem olarak başlatır. Register → login → me → refresh, role seçimi reddi, aynı email/eşzamanlı kayıt, JWT imza/süre/issuer/audience, refresh süre/tek kullanım/eşzamanlılık, hash saklama, logout sahipliği, pasif kullanıcı ve health kontrollerini yapar. Aynı fixture içindeki `TrackingChecks.ps1`, kilo/ölçüm ekleme ve sıralı geçmişi, sayı/tarih validation'ını, kısmi ölçümleri, rol kontrolünü ve iki kullanıcı arasında veri izolasyonunu test eder. Kendi geçici container/volume/process'ini sonunda temizler; geliştirme veritabanına bağlanmaz. Test portları `5059` ve `55432`; doluysa `-ApiPort` ve `-DatabasePort` parametrelerini kullanın. Güncel build zaten varsa `-NoBuild` verilebilir.

`AddMobileAssignmentReads`, mobil Planım/Rehberim okumaları için `advisor_profiles`, `user_advisors`, `advisor_notes`, `user_tasks`, `exercises`, `workout_plans`, `workout_days`, `workout_exercises`, `nutrition_goals` tablolarını ekler. Domain/alan isimleri veri sözlüğünü kullanır; fake veri/hesap seed edilmez. Running, AI veya Health tablosu eklenmez. Ek mimari katman veya repository abstraction eklenmemiştir. Mevcut `baslat.cmd` başlatıcısı backend'i açarken migration'ları uygular; ayrı çalıştırırken yukarıdaki `database update` adımı gereklidir.

### Planım / Rehberim okuma endpointleri

| Endpoint | Başarı / boş yanıt | Yetki |
|---|---|---|
| `GET /api/users/me/advisors` | `200` aktif koç/diyetisyen listesi, yoksa `[]` | User, kendi atamaları |
| `GET /api/users/me/workout-plans` | `200` aktif ve geçmiş programlar, yoksa `[]` | User, kendi programları |
| `GET /api/workout-plans/{workoutPlanId}` | `200` sıralı gün/egzersiz detayı; bulunamayan/yetkisiz kayıt `404` | Owner User veya Active Assigned Trainer |
| `GET /api/users/me/nutrition-goals/active?date=YYYY-MM-DD` | `200` geçerli aktif hedef; yoksa `404` + `code: NutritionGoalNotFound` | User, kendi hedefi |
| `GET /api/users/me/tasks?status=Pending` | `200` görevler, yoksa `[]`; geçersiz status `400` | User, kendi görevleri |
| `GET /api/users/me/advisor-notes` | `200` tarihli notlar, yoksa `[]` | User, kendi notları |

Tüm yanıtlar `no-store` kullanır. Kullanıcı kimliği JWT `sub` claim'inden alınır; query ile `userId` seçilemez. Beslenme hedefinde cihazın takvim tarihi gönderilir; tarih yoksa UTC gün kullanılır, sınırlar dahildir. Tek aktif program/hedef ve tek haftanın günü DB indeksleriyle korunur.

### Web danışman iş akışı

| Endpoint | Başarı | Yetki |
|---|---|---|
| `GET /api/trainers/me/clients` | `200` aktif danışan listesi | Trainer |
| `GET /api/dietitians/me/clients` | `200` aktif danışan listesi | Dietitian |
| `GET /api/users/{userId}` | `200` profil | Atanmış Trainer/Dietitian veya Admin |
| `GET /api/users/{userId}/weight-records` | `200` kilo geçmişi, yoksa `[]` | Aktif atanmış Trainer/Dietitian |
| `GET /api/users/{userId}/body-measurements` | `200` vücut ölçüm geçmişi, yoksa `[]` | Aktif atanmış Trainer/Dietitian |
| `GET /api/users?page=1&pageSize=20` | `200` sayfalı kullanıcı özeti | Admin |
| `GET /api/user-advisors?userId={userId}` | `200` ilişki geçmişi | Admin |
| `POST /api/user-advisors` | `201` oluşturulan ilişki | Admin |
| `PATCH /api/user-advisors/{userAdvisorId}` | `200` sonlandırılan ilişki | Admin |
| `GET /api/exercises` | `200` aktif katalog | Bearer JWT |
| `GET /api/exercises?includeInactive=true` | `200 ExerciseDetailResponse[]`, aktif/pasif kayıtlar ve `isActive` | Admin; diğer roller `403` |
| `GET /api/exercises/{exerciseId}` | `200` detay | Bearer JWT; pasif kayıt yalnız Admin |
| `POST /api/exercises`, `PUT /api/exercises/{exerciseId}` | `201` / `200` detay | Admin |
| `GET/POST /api/users/{userId}/workout-plans` | `200` liste / `201` program JSON + Location | Atanmış Trainer |
| `GET/POST /api/users/{userId}/nutrition-goals` | `200` liste / `201` oluşturulan hedef | Atanmış Dietitian |
| `GET/POST /api/users/{userId}/tasks` | `200` liste / `201` oluşturulan görev | Atanmış Trainer/Dietitian |
| `GET/POST /api/users/{userId}/advisor-notes` | `200` liste / `201` oluşturulan not | Atanmış Trainer/Dietitian |
| `PATCH /api/tasks/{taskId}` | `200` güncel görev | Görev sahibi User veya görevi oluşturan aktif danışman |

Bu endpointler mevcut `AddMobileAssignmentReads` tablolarını kullanır; ek migration gerekmez. Yeni program veya hedef ataması, önceki aktif kaydı aynı transaction içinde pasifleştirir ve geçmişi korur. Danışan satırı kilidi eşzamanlı atamaları ve Admin ilişki sonlandırmasını sıralar. Atama kimliği request'ten seçilemez; Trainer/Dietitian JWT'den alınır. Geçersiz gün/egzersiz sırası, eksik hedefler, pasif egzersiz, tarih aralığı ve sayı hassasiyeti `400` alan hatası verir. Aktif bağlantısı olmayan danışan veya uygun olmayan rol `403`, bulunamayan kayıt `404`, yinelenen aktif danışman ilişkisi `409` döner. Yanıtlar `no-store` kullanır.

Admin kullanıcı özeti kişisel sağlık alanlarını içermez; Admin'in profil okumasında doğum tarihi, cinsiyet ve boy yalnız aynı hesaba ayrıca aktif danışman ilişkisi varsa döner. Admin ilişki yönetimi `UserAdvisorManagementResponse`, mobil rehber okuması mevcut `UserAdvisorResponse` kullanır. Ayrıntılı request/response sözleşmeleri `docs/API_CONTRACT.md` içindedir.

Danışan kilo/vücut geçmişi, mevcut `TrackingService`, `WeightRecordResponse` ve `BodyMeasurementResponse` ile okunur; yeni tablo/migration eklenmez. Aktif `UserAdvisor` ilişkisi, danışanın aktif `User` hesabı ve danışmanın güncel uygun rolü kontrol edilir. Tek danışman rolü içeren token ilişki türüyle eşleşmelidir; iki rol içeren token uygun aktif ilişkilerden birini kullanabilir. Admin/User tek başına yetkili değildir; bulunamayan veya bağlantısız danışan `403` verir. Kayıtlar mevcut mobil API sırasını ve null/sıfır değerleri korur. Yanıtlar `no-store`; sunucu dönem filtresi/sayfalama yoktur. Danışman rotalarında yazma metodu bulunmaz; danışan kendi kayıtlarını mevcut `/api/users/me/...` API'leriyle yönetir.

`ClientProgressChecks.ps1`, aynı geçici fixture'da Trainer/Dietitian okumalarını mobil DTO'larıyla karşılaştırır. Boş/kısmi kayıtlar, sıfır değer, query ile sahiplik değiştirme, salt okunur rotalar, token/ilişki rolü, kaldırılan rol, pasif danışan ve sonlanan/iptal edilen ilişki kontrollerini kapsar.

Trainer/Dietitian/Admin hesabı otomatik oluşturulmaz. Public register yalnız `User` üretir; ilk yetkili hesabın rolü güvenilir geliştirme/dağıtım kurulumu sırasında verilmelidir. Rol yönetimi endpointi beklemektedir. Web'deki danışan, program oluşturma/düzenleme, beslenme ve görev/not atama ekranları gerçek API ile çalışır. Admin, kullanıcı profilindeki Danışmanları yönet ekranından ilişki oluşturabilir, sonlandırabilir ve geçmişi görebilir; egzersiz kataloğunu web formundan oluşturup güncelleyebilir. User kendi bekleyen/devam eden görevini tamamlayabilir; aynı tamamlamanın tekrarı tarihi değiştirmez, bitmiş görev yeniden açılamaz.

`AuthSmoke.ps1`, `AssignmentChecks.ps1` ile gerçek PostgreSQL'de boş/atanmış kullanıcıyı, DTO/enum/tarih biçimlerini, sahiplik/rol ve biten danışman ilişkisi erişimini, beslenme hedefi geçerlilik sınırlarını, validation ve DB benzersiz indekslerini de test eder. `AssignmentWriteChecks.ps1` görev/not yazma, mobil okuma ve görev tamamlamanın tekrar gönderilmesini doğrular. `AssignmentFixture.ps1` yalnız geçici veritabanına test atamaları ekler. `AdvisorWorkflowChecks.ps1` aynı geçici ortamda farklı rollerde hesaplar oluşturur; Admin ilişki/katalog yönetimi → Trainer programı → Dietitian hedefi → mobil okuma akışını gerçek HTTP ile doğrular. Alan hataları, sağlık alanlarının Admin'den gizlenmesi, pasif egzersizler, eşzamanlı ilişki/program/hedef atamaları ve sonlanan ilişkide erişimin kesilmesi de kontrol edilir. Test hesapları ve roller yalnız geçici veritabanında tutulur.

Kullanılan framework bileşenleri: [JWT bearer authentication](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/configure-jwt-bearer-authentication?view=aspnetcore-10.0), [ASP.NET Core password hashing](https://learn.microsoft.com/en-us/aspnet/core/security/data-protection/consumer-apis/password-hashing?view=aspnetcore-10.0).
