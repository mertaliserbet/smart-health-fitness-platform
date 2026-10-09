# Backend ve authentication

**Yapay Zekâ Destekli Sağlık ve Fitness Platformu** için tek ASP.NET Core Web API projesi.

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
| `tests/AuthSmoke.ps1` | Ayrı PostgreSQL servisiyle auth entegrasyon kontrolleri. |
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

Request/response ve hata detayları: `../docs/API_CONTRACT.md` bölüm 8, 9.1 ve 39.

Swagger'da register ile hesap oluşturun (`firstName`, `lastName`, `email`, `password`). Parola 12–128 karakter olmalı; e-posta aynıysa `409` döner. Public register'da rol alanı kabul edilmez. Ardından login yapın ve dönen `accessToken` değerini **Authorize → Bearer** alanına yapıştırın (`Bearer ` öneki olmadan). `GET /api/users/me` çağrısını deneyin. Refresh için login'in `refreshToken` alanını gönderin; eski refresh token tekrar kullanılırsa `401` döner.

## Migration ve otomatik kontroller

`InitialUserAuthentication` yalnızca `users`, `roles`, `user_roles`, `refresh_tokens` tablolarını oluşturur. Dört rol eklenir; hiçbir admin/trainer/dietitian kullanıcı hesabı seed edilmez. User profil alanları nullable olarak hazırdır; profil düzenleme endpointi bu aşamada yoktur.

Migration uygulama başlangıcında otomatik çalışmaz; yukarıdaki `database update` komutuyla uygulanır. EF migration oluşturmak için JWT secret gerekmez, ancak veritabanı connection string configuration'ı gerekir. Model ile migration uyumunu kontrol etmek için:

```powershell
dotnet tool run dotnet-ef migrations has-pending-model-changes --project backend/SmartHealthFitness.Api.csproj
```

Repository kökünde (Windows PowerShell veya PowerShell 7, çalışan Docker Desktop):

```powershell
& ./backend/tests/AuthSmoke.ps1
```

Script restore/build yapar, rastgele geçici credential kullanır, ayrı bir PostgreSQL Compose projesine migration uygular ve API'yi gizli bir işlem olarak başlatır. Register → login → me → refresh, role seçimi reddi, aynı email/eşzamanlı kayıt, JWT imza/süre/issuer/audience, refresh süre/tek kullanım/eşzamanlılık, hash saklama, logout sahipliği, pasif kullanıcı ve health kontrollerini yapar. Kendi geçici container/volume/process'ini sonunda temizler; geliştirme veritabanına bağlanmaz. Test portları `5059` ve `55432`; doluysa `-ApiPort` ve `-DatabasePort` parametrelerini kullanın. Güncel build zaten varsa `-NoBuild` verilebilir.

Bu aşamada Advisor, Workout, Nutrition, Running, AI veya Health tabloları ve istemci uygulamaları yoktur. Ek mimari katman veya repository abstraction eklenmemiştir.

Kullanılan framework bileşenleri: [JWT bearer authentication](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/configure-jwt-bearer-authentication?view=aspnetcore-10.0), [ASP.NET Core password hashing](https://learn.microsoft.com/en-us/aspnet/core/security/data-protection/consumer-apis/password-hashing?view=aspnetcore-10.0).
