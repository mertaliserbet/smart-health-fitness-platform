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
- Trainer için danışana göre program listesi ve detay, egzersiz kataloğu ve program oluşturup atama formu. Haftanın günü benzersizliği, gün/egzersiz sıralama, set/tekrar veya süre, dinlenme, ağırlık ve not alanları desteklenir.
- Dietitian için danışana göre beslenme hedefi geçmişi ve yeni hedef atama formu. Günlük kalori, protein, karbonhidrat, yağ, su ve geçerlilik tarihleri desteklenir. Aktif hedefin bugün geçerli, henüz başlamamış veya süresi dolmuş olduğu ayrı gösterilir.
- Admin kullanıcı listesi, sayfalama ve temel hesap bilgileri. Admin ekranında kişisel sağlık verisi gösterilmez.
- Çoklu web rolünde yalnız hesaba atanmış rollerden panel seçimi. `User` hesabı mobil uygulamaya yönlendiren açıklama görür.
- Responsive koyu arayüz; klavye odağı, görünür alan etiketleri ve yükleniyor/boş/hata durumları.

Program düzenleme, beslenme kayıtları/ilerleme, görev/not, profil düzenleme, egzersiz/ekipman yönetimi ve Admin yazma işlemleri henüz uygulanmadı. Tamamlanmamış işlemler için işlevsiz düğmeler gösterilmez.

## Gerçek API bağlantısı

Varsayılan `/api` istekleri geliştirmede Vite proxy üzerinden `http://localhost:5000` adresine gider. Mert API'yi backend README'sine göre başlatır. Ayrı API adresi için `.env.example` dosyasını `.env.local` adıyla kopyalayıp `VITE_API_BASE_URL` ayarlayın. `VITE_` değişkenleri tarayıcıya açıktır; gizli anahtar eklemeyin.

API sözleşmesi değiştirilmez. Kullanılan istekler:

| İşlem                        | Endpoint                                       |
| ---------------------------- | ---------------------------------------------- |
| Giriş, yenileme, çıkış       | `POST /api/auth/login`, `/refresh`, `/logout`  |
| Profil                       | `GET /api/users/me`, `GET /api/users/{userId}` |
| Antrenörün danışanları       | `GET /api/trainers/me/clients`                 |
| Diyetisyenin danışanları     | `GET /api/dietitians/me/clients`               |
| Yönetici kullanıcı listesi   | `GET /api/users?page=...&pageSize=20`          |
| Egzersiz kataloğu            | `GET /api/exercises`                           |
| Danışanın programları        | `GET /api/users/{userId}/workout-plans`        |
| Program detayı               | `GET /api/workout-plans/{workoutPlanId}`       |
| Program oluşturma ve atama   | `POST /api/users/{userId}/workout-plans`       |
| Danışanın beslenme hedefleri | `GET /api/users/{userId}/nutrition-goals`      |
| Beslenme hedefi atama        | `POST /api/users/{userId}/nutrition-goals`     |

Refresh token `sessionStorage` içinde sekme oturumu boyunca saklanır; access token yalnız bellektedir. Sayfa yenilenince refresh ve ardından `/api/users/me` ile oturum doğrulanır. Eşzamanlı `401` cevapları tek refresh isteğini paylaşır. Başarısız yenileme veya tekrar `401` oturumu kapatır. `403` için refresh denenmez. Sunucu çıkışı başarısız olsa bile yerel oturum temizlenir ve kullanıcıya açıklanır.

Backend'de giriş, token yenileme, çıkış ve `/api/users/me` uygulanmıştır. Danışan listeleri, kullanıcı listesi ve başka kullanıcının profili için gereken endpointler henüz uygulanmamıştır. Web oturum akışı mevcut API sözleşmesini kullanır; bu aşamada gerçek API ve PostgreSQL ile uçtan uca doğrulama yapılmamıştır. Web'deki menü/route denetimleri arayüz içindir; korunan API işlemlerinde JWT, rol ve aktif `UserAdvisor` denetimi backend tarafından yapılmalıdır.

Program ve egzersiz endpointleri de henüz backend'de uygulanmamıştır. Program formu mevcut `CreateWorkoutPlanRequest` alanlarıyla POST gönderir; Trainer kimliği request'e eklenmez, backend access token'dan alır. Sözleşmedeki gövdesiz `201 Created` yanıtı desteklenir. Başarıdan sonra danışanın program listesi yeniden yüklenir; istek hatasında form korunur. Atamadan hemen önce aktif danışan listesi tekrar kontrol edilir. Backend ayrıca aktif ilişkiyi ve tek aktif program kuralını aynı işlemde uygulamalıdır. Bu bölüm web uygulaması olarak hazırlanmıştır; canlı program atama ve mobilde görüntüleme tamamlanmış sayılmaz.

Beslenme hedefi formu mevcut sözleşmedeki yedi alanı gönderir; Dietitian kimliğini backend token üzerinden alır. Başarı için sözleşmedeki oluşturulan aktif hedefi içeren JSON yanıtı beklenir; antrenman POST'undan farklı olarak gövdesiz `201` beslenme ataması için başarı sayılmaz. Atamadan önce aktif danışan ilişkisi tekrar kontrol edilir; hata halinde form korunur. Backend yeni hedefi aktif edip önceki hedefi aynı veritabanı işleminde pasifleştirmelidir. Hedef endpointleri henüz uygulanmadığından gerçek PostgreSQL ataması ve mobilde görüntüleme beklemektedir. Su alanı yalnız hedeftir; tüketim verisi gösterilmez.

## Örnek veri ile önizleme

`npm run dev` giriş ekranında Antrenör / Diyetisyen / Yönetici örnek panellerini açar. Bunlar gerçek oturum oluşturmaz, API'ye istek yapmaz ve sunucuya veri kaydetmez. Panelde örnek veri bandı daima görünür. Örnek oturum sayfa yenilendiğinde sona erer. Gerçek API hatasında otomatik olarak örnek veriye geçilmez.

Antrenör önizlemesinde **Antrenman Programları → danışan seç → Yeni program → gün/egzersiz ekle → Örnek atamayı dene** akışı kullanılabilir. Örnek atama yalnız bellekte tutulur ve sayfa yenilendiğinde sıfırlanır. Önceki örnek aktif program pasif hale gelir; yeni program listeden açılabilir. Sunucuya veya mobil uygulamaya veri gönderilmez.

Diyetisyen önizlemesinde **Beslenme Hedefleri → danışan seç → Yeni hedef → günlük hedefleri ve tarihleri gir → Örnek hedef atamasını dene** akışı kullanılabilir. Yeni örnek hedef, yalnız seçili danışanın önceki aktif hedefini pasifleştirir. Örnek hedefler bellekte tutulur; sayfa yenilendiğinde sıfırlanır. Gelecekte başlayacak aktif hedef, başlangıç tarihine kadar geçerli günlük hedef olarak gösterilmez.

Örnek giriş yalnız Vite development modunda kullanılabilir; production build örnek veri modülünü ve giriş düğmelerini içermez. Production build'in `/api` yolunu ASP.NET Core'a ileten reverse proxy veya `VITE_API_BASE_URL` ayarı gerekir. Hosting, backend CORS ve HTTPS yayın aşamasında birlikte yapılandırılmalıdır.

## Kontroller

```powershell
npm test
npm run build
npm run format:check
```

Testler; token yenileme/eşzamanlı istek, çıkış sırasında yenileme, 401/403 ayrımı, alan hataları, rol sınırları, panel seçimi, danışan araması ve profil geçişini doğrular. API yanıtları testlerde taklit edilir; bu testler gerçek backend entegrasyonunun yerine geçmez.

Program testleri; sözleşmeye uygun POST ve gövdesiz 201, geçersiz tarih/sayı, benzersiz gün seçimi, sıralama ve süre hedefleri, backend alan hatalarında formun korunması, yinelenen gönderimin engellenmesi ve farklı danışanın programına erişim sınırlarını kapsar. Windows sandbox ortamında Vitest geçici dosyaları görünmezse, test komutunun `TEMP` ve `TMP` değişkenleri yazılabilir `web/node_modules/.vitest-tmp` dizinine yönlendirilebilir.

Beslenme testleri; sözleşmeye uygun POST ve JSON yanıtı, hedef listesinin tekrar yüklenmesi, sıfır/ondalık değerler, geçersiz sayı/tarih, API alan hataları, sonlanan ilişkide atamanın engellenmesi, rol sınırları, yinelenen gönderim, hata sonrası tekrar deneme, hedef geçerlilik sınırları ve örnek hedeflerin tek aktif hedef davranışını doğrular.

## Kaynak düzeni

`src/pages`: ekranlar; `components`: ortak yerleşim ve tablo; `auth`: web oturumu ve rol seçimi; `services`: mevcut REST sözleşmesi; `types`: sözleşmedeki alanlar; `demo`: yalnız geliştirme örnekleri; `hooks/useLoad`: iptal edilebilir yükleme ve tekrar deneme.
