# Backend temel altyapısı

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
dotnet restore backend/SmartHealthFitness.Api.csproj
dotnet build backend/SmartHealthFitness.Api.csproj --no-restore
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
| `appsettings*.json`, `Properties/launchSettings.json` | Gizli olmayan ayarlar ve yerel HTTP çalıştırma profili. |
| `docker-compose.yml` | Yalnızca yerel PostgreSQL servisi. |

Swagger/OpenAPI ve CORS middleware yalnızca `Development` ortamında aktiftir. CORS, tarayıcıdaki istemcinin API'yi çağırmasına izin veren kuraldır; izinli adresler `appsettings.Development.json` içindeki `Cors:AllowedOrigins` listesindedir. Farklı bir geliştirme portu kullanıyorsanız listeyi güncelleyin. Production ortamı için CORS izni tanımlı değildir. Yerel profil HTTP kullanır; yayın ortamında HTTPS barındırma ayarı ayrıca yapılmalıdır.

EF Core ve Npgsql configuration üzerinden bağlanır. Bu aşamada business entity, `DbSet`, migration veya otomatik veritabanı şeması oluşturma işlemi yoktur. Ek mimari katman ve authentication altyapısı eklenmemiştir.
