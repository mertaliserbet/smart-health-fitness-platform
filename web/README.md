# Web danışman paneli

React + TypeScript + Vite. Web çalışması Uğur'a aittir; aynı ASP.NET Core API'yi mobil ve web kullanır. Bu uygulama PostgreSQL'e veya AI servisine doğrudan bağlanmaz.

## Çalıştırma

Node.js 22.12 veya üstü gerekir. Repository kökünden:

```powershell
cd web
npm ci
npm run dev
```

Adres: http://localhost:5173. Port doluysa Vite başka port seçmez; backend CORS ayarlarıyla tutarlı kalır. Dev sunucusu yalnız bu bilgisayarda dinler.

## Bu aşamanın kapsamı

- Giriş formu, alan doğrulaması, `ProblemDetails` hata mesajları.
- Trainer / Dietitian / Admin için farklı menü, dashboard ve liste.
- Trainer ve Dietitian danışan listesinde yerel isim araması ve profil görüntüleme.
- Admin kullanıcı listesi, sayfalama ve temel hesap bilgileri. Admin ekranında kişisel sağlık verisi gösterilmez.
- Çoklu web rolünde yalnız hesaba atanmış rollerden panel seçimi. `User` hesabı mobil uygulamaya yönlendiren açıklama görür.
- Responsive koyu arayüz; klavye odağı, görünür alan etiketleri ve yükleniyor/boş/hata durumları.

Program/hedef atama, görev/not, profil düzenleme, egzersiz/ekipman ve Admin yazma işlemleri henüz uygulanmadı. Tamamlanmamış işlemler için işlevsiz düğmeler gösterilmez.

## Gerçek API bağlantısı

Varsayılan `/api` istekleri geliştirmede Vite proxy üzerinden `http://localhost:5000` adresine gider. Mert API'yi backend README'sine göre başlatır. Ayrı API adresi için `.env.example` dosyasını `.env.local` adıyla kopyalayıp `VITE_API_BASE_URL` ayarlayın. `VITE_` değişkenleri tarayıcıya açıktır; gizli anahtar eklemeyin.

API sözleşmesi değiştirilmez. Kullanılan istekler:

| İşlem                      | Endpoint                                       |
| -------------------------- | ---------------------------------------------- |
| Giriş, yenileme, çıkış     | `POST /api/auth/login`, `/refresh`, `/logout`  |
| Profil                     | `GET /api/users/me`, `GET /api/users/{userId}` |
| Antrenörün danışanları     | `GET /api/trainers/me/clients`                 |
| Diyetisyenin danışanları   | `GET /api/dietitians/me/clients`               |
| Yönetici kullanıcı listesi | `GET /api/users?page=...&pageSize=20`          |

Refresh token `sessionStorage` içinde sekme oturumu boyunca saklanır; access token yalnız bellektedir. Sayfa yenilenince refresh ve ardından `/api/users/me` ile oturum doğrulanır. Eşzamanlı `401` cevapları tek refresh isteğini paylaşır. Başarısız yenileme veya tekrar `401` oturumu kapatır. `403` için refresh denenmez. Sunucu çıkışı başarısız olsa bile yerel oturum temizlenir ve kullanıcıya açıklanır.

Backend'de giriş, token yenileme, çıkış ve `/api/users/me` uygulanmıştır. Danışan listeleri, kullanıcı listesi ve başka kullanıcının profili için gereken endpointler henüz uygulanmamıştır. Web oturum akışı mevcut API sözleşmesini kullanır; bu aşamada gerçek API ve PostgreSQL ile uçtan uca doğrulama yapılmamıştır. Web'deki menü/route denetimleri arayüz içindir; korunan API işlemlerinde JWT, rol ve aktif `UserAdvisor` denetimi backend tarafından yapılmalıdır.

## Örnek veri ile önizleme

`npm run dev` giriş ekranında Antrenör / Diyetisyen / Yönetici örnek panellerini açar. Bunlar gerçek oturum oluşturmaz, API'ye istek yapmaz ve veri kaydetmez. Panelde örnek veri bandı daima görünür. Örnek oturum sayfa yenilendiğinde sona erer. Gerçek API hatasında otomatik olarak örnek veriye geçilmez.

Örnek giriş yalnız Vite development modunda kullanılabilir; production build örnek veri modülünü ve giriş düğmelerini içermez. Production build'in `/api` yolunu ASP.NET Core'a ileten reverse proxy veya `VITE_API_BASE_URL` ayarı gerekir. Hosting, backend CORS ve HTTPS yayın aşamasında birlikte yapılandırılmalıdır.

## Kontroller

```powershell
npm test
npm run build
npm run format:check
```

Testler; token yenileme/eşzamanlı istek, çıkış sırasında yenileme, 401/403 ayrımı, alan hataları, rol sınırları, panel seçimi, danışan araması ve profil geçişini doğrular. API yanıtları testlerde taklit edilir; bu testler gerçek backend entegrasyonunun yerine geçmez.

## Kaynak düzeni

`src/pages`: ekranlar; `components`: ortak yerleşim ve tablo; `auth`: web oturumu ve rol seçimi; `services`: mevcut REST sözleşmesi; `types`: sözleşmedeki alanlar; `demo`: yalnız geliştirme örnekleri; `hooks/useLoad`: iptal edilebilir yükleme ve tekrar deneme.
