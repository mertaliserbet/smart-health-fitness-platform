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
- Trainer/Dietitian için **Danışan Detayı → Görevler / Notlar**: gerçek görev/not atama, geçmiş ve görev durumu. İstek hatasında form korunur; gönderim sırasında yinelenen kaydetme engellenir. Mobil kullanıcı görevi tamamlayınca sayfa yeniden açıldığında veya yenilendiğinde güncel durum görülür.
- Admin kullanıcı listesi, sayfalama ve temel hesap bilgileri. Admin ekranında kişisel sağlık verisi gösterilmez.
- Admin için **Kullanıcılar → kullanıcı profili → Danışmanları yönet**: rol/isim/e-posta filtreli, sayfalı danışman seçimi; antrenör/diyetisyen atama; aktif ilişkiyi sonlandırma veya iptal etme; salt okunur ilişki geçmişi.
- Çoklu web rolünde yalnız hesaba atanmış rollerden panel seçimi. `User` hesabı mobil uygulamaya yönlendiren açıklama görür.
- Responsive koyu arayüz; klavye odağı, görünür alan etiketleri ve yükleniyor/boş/hata durumları.

Trainer, danışan profilinden veya program listesinden **Antrenman geçmişi** ekranına ulaşır. Durum filtresi ve sayfalama gerçek API'yi kullanır; detayda hedefler, gerçekleşen set/tekrar/süre/ağırlık, notlar ve kaydı olmayan egzersizler gösterilir. Tamamlanmış oturum kısmi olabilir. Geçmiş yalnız aktif bağlı Trainer'a açıktır; demo modunda gerçek giriş açıklaması gösterilir. Oturum başlatılmış programın düzenleme bağlantısı kapanır; yeni program atanabilir.

Beslenme kayıtları/ilerleme, profil düzenleme, rol yönetimi ve egzersiz/ekipman yönetim formları henüz uygulanmadı. Tamamlanmamış işlemler için işlevsiz düğmeler gösterilmez.

## Gerçek API bağlantısı

Varsayılan `/api` istekleri geliştirmede Vite proxy üzerinden `http://localhost:5000` adresine gider. API'yi backend README'sine göre başlatın. Ayrı API adresi için `.env.example` dosyasını `.env.local` adıyla kopyalayıp `VITE_API_BASE_URL` ayarlayın. `VITE_` değişkenleri tarayıcıya açıktır; gizli anahtar eklemeyin.

İstekler `docs/API_CONTRACT.md` sözleşmesini izler. Kullanılan istekler:

| İşlem                        | Endpoint                                                                 |
| ---------------------------- | ------------------------------------------------------------------------ |
| Giriş, yenileme, çıkış       | `POST /api/auth/login`, `/refresh`, `/logout`                            |
| Profil                       | `GET /api/users/me`, `GET /api/users/{userId}`                           |
| Antrenörün danışanları       | `GET /api/trainers/me/clients`                                           |
| Diyetisyenin danışanları     | `GET /api/dietitians/me/clients`                                         |
| Yönetici kullanıcı listesi   | `GET /api/users?page=...&pageSize=20`                                    |
| Danışman adaylarını bulma    | `GET /api/users?page=...&pageSize=20&role=Trainer\|Dietitian&search=...` |
| Danışman ilişkileri ve atama | `GET /api/user-advisors?userId=...`, `POST /api/user-advisors`           |
| İlişkiyi sonlandırma         | `PATCH /api/user-advisors/{userAdvisorId}`                               |
| Egzersiz kataloğu            | `GET /api/exercises`                                                     |
| Danışanın programları        | `GET /api/users/{userId}/workout-plans`                                  |
| Program detayı               | `GET /api/workout-plans/{workoutPlanId}`                                 |
| Aktif programı düzenleme     | `PUT /api/workout-plans/{workoutPlanId}`                                 |
| Danışanın antrenman geçmişi  | `GET /api/users/{userId}/workout-sessions?page=1&pageSize=20&status=...` |
| Antrenman oturumu detayı     | `GET /api/workout-sessions/{sessionId}`                                  |
| Program oluşturma ve atama   | `POST /api/users/{userId}/workout-plans`                                 |
| Danışanın beslenme hedefleri | `GET /api/users/{userId}/nutrition-goals`                                |
| Beslenme hedefi atama        | `POST /api/users/{userId}/nutrition-goals`                               |
| Görev/not listesi ve atama   | `GET/POST /api/users/{userId}/tasks`, `/advisor-notes`                   |

Refresh token `sessionStorage` içinde sekme oturumu boyunca saklanır; access token yalnız bellektedir. Sayfa yenilenince refresh ve ardından `/api/users/me` ile oturum doğrulanır. Eşzamanlı `401` cevapları tek refresh isteğini paylaşır. Başarısız yenileme veya tekrar `401` oturumu kapatır. `403` için refresh denenmez. Sunucu çıkışı başarısız olsa bile yerel oturum temizlenir ve kullanıcıya açıklanır.

Tablodaki endpointler backend'de uygulanmıştır. Danışan listesi yalnız aktif ilişkileri içerir; başka kullanıcının profilini yalnız atanmış danışman veya Admin okuyabilir. Admin temel hesap alanlarını görür; kişisel sağlık alanları ayrıca aktif danışman ilişkisi gerektirir. Web'deki menü/route denetimlerine ek olarak JWT, rol ve aktif `UserAdvisor` denetimi backend tarafından uygulanır. Public register yalnız User hesabı üretir; danışman/Admin rolleri güvenilir kurulum sırasında verilir. Admin ilişki atama/sonlandırma web formu hazırdır; egzersiz oluşturma/güncelleme web formu henüz yoktur.

Danışman yönetimi yalnız `User` rolüne sahip hesaplara açılır. Yeni ilişkinin `startDate` değeri gönderim anındaki UTC takvim günüdür. Kullanıcının kendisi ve aynı kişiyle mevcut aktif ilişki seçimde engellenir; farklı danışmanlar atanabilir. Backend aktif hesap ve rolü tekrar doğrular. Sonlandırmada yalnız `Ended`/`Cancelled` seçilir; bitiş tarihi başlangıçtan önce veya bugünün UTC tarihinden sonra olamaz. Sonlandırma öncesinde sonuçları gösteren bir form açılır; geçmiş kayıtlar silinmez. Hata halinde form korunur, yinelenen gönderim engellenir; `409` halinde güncel ilişki geçmişi tekrar yüklenir. Geçmişteki ilişki yeniden açılmaz; yeni atama ayrı kayıt oluşturur. İlişki listesi yenilenemediğinde atama kapalı kalır.

Program formu mevcut `CreateWorkoutPlanRequest` alanlarıyla POST gönderir; Trainer kimliği request'e eklenmez, backend access token'dan alır. Güncel API `201 WorkoutPlanResponse` JSON yanıtı döner; web daha eski gövdesiz `201` yanıtıyla da çalışabilir. Başarıdan sonra danışanın program listesi yeniden yüklenir; istek hatasında form korunur. Atamadan hemen önce aktif danışan listesi tekrar kontrol edilir. Backend aktif ilişkiyi ve tek aktif program kuralını aynı transaction içinde uygular; pasif egzersizler yeni atamada kullanılamaz. Gün/egzersiz sıra kuralları ve ağırlık alanındaki en fazla iki ondalık basamak hem formda hem backend'de doğrulanır.

Trainer, kendi oluşturduğu aktif programın detayındaki **Programı düzenle** bağlantısıyla aynı formu mevcut gün/hedeflerle açar. `/programlar/:userId/:workoutPlanId/duzenle`, `PUT /api/workout-plans/{id}` kullanır. Mevcut gün/satır kimlikleri korunur; yeni satırlar null kimlikle gönderilir. GET yanıtındaki `updatedAt`, request'in zorunlu `expectedUpdatedAt` alanına aynen aktarılır. Eski sürüm veya pasifleştirilen plan için `409` geldiğinde yeniden gönderim kapatılır ve güncel programa dönüş sunulur. Diğer hatalarda form korunur; başarıda detay API'den tekrar okunur. Geçmiş program ve başka Trainer'ın oluşturduğu program düzenlenmez; backend aynı yetkiyi tekrar denetler. Katalogdaki pasifleşmiş mevcut satır korunabilir, yeni satırlar yalnız aktif katalogdan seçilir. Önizleme düzenlemesi yalnız bellekte tutulur.

Beslenme hedefi formu mevcut sözleşmedeki yedi alanı gönderir; Dietitian kimliğini backend token üzerinden alır. Başarı için sözleşmedeki oluşturulan aktif hedefi içeren JSON yanıtı beklenir; gövdesiz `201` beslenme ataması için başarı sayılmaz. Atamadan önce aktif danışan ilişkisi tekrar kontrol edilir; hata halinde form korunur. Backend yeni hedefi aktif edip önceki hedefi aynı veritabanı işleminde pasifleştirir. Sayı alanları en fazla iki ondalık basamak kabul eder. Su alanı yalnız hedeftir; tüketim verisi gösterilmez.

Yerel tarayıcı kontrolünde gerçek giriş → danışan seçimi → antrenman programı atama/detay ve diyetisyen beslenme hedefi atama/liste akışları ayrı geçici PostgreSQL veritabanıyla doğrulandı. Bu atamalar mobilin kullandığı `/api/users/me/workout-plans` ve `/api/users/me/nutrition-goals/active` yanıtlarında da doğrulandı. Flutter ekranları bu kontrolün kapsamına dahil değildir.

## Örnek veri ile önizleme

`npm run dev` giriş ekranında Antrenör / Diyetisyen / Yönetici örnek panellerini açar. Bunlar gerçek oturum oluşturmaz, API'ye istek yapmaz ve sunucuya veri kaydetmez. Panelde örnek veri bandı daima görünür. Örnek oturum sayfa yenilendiğinde sona erer. Gerçek API hatasında otomatik olarak örnek veriye geçilmez.

Antrenör önizlemesinde **Antrenman Programları → danışan seç → Yeni program → gün/egzersiz ekle → Örnek atamayı dene** akışı kullanılabilir. Örnek atama yalnız bellekte tutulur ve sayfa yenilendiğinde sıfırlanır. Önceki örnek aktif program pasif hale gelir; yeni program listeden açılabilir. Sunucuya veya mobil uygulamaya veri gönderilmez.

Diyetisyen önizlemesinde **Beslenme Hedefleri → danışan seç → Yeni hedef → günlük hedefleri ve tarihleri gir → Örnek hedef atamasını dene** akışı kullanılabilir. Yeni örnek hedef, yalnız seçili danışanın önceki aktif hedefini pasifleştirir. Örnek hedefler bellekte tutulur; sayfa yenilendiğinde sıfırlanır. Gelecekte başlayacak aktif hedef, başlangıç tarihine kadar geçerli günlük hedef olarak gösterilmez.

Danışman ilişkisi yönetimi, görev/not ekranı gibi gerçek yetkili hesapla kullanılır. Yönetici önizlemesinde bu ekrana girildiğinde açıklama gösterilir; gerçek API'ye istek veya atama gönderilmez.

Örnek giriş yalnız Vite development modunda kullanılabilir; production build örnek veri modülünü ve giriş düğmelerini içermez. Production build'in `/api` yolunu ASP.NET Core'a ileten reverse proxy veya `VITE_API_BASE_URL` ayarı gerekir. Hosting, backend CORS ve HTTPS yayın aşamasında birlikte yapılandırılmalıdır.

## Kontroller

```powershell
npm test
npm run build
npm run format:check
```

Testler; token yenileme/eşzamanlı istek, çıkış sırasında yenileme, 401/403 ayrımı, alan hataları, rol sınırları, panel seçimi, danışan araması ve profil geçişini doğrular. API yanıtları testlerde taklit edilir; bu testler gerçek backend entegrasyonunun yerine geçmez.

Danışman yönetimi testleri; profil bağlantısı/rol sınırları, UTC atama tarihi ve request alanları, sunucuda filtreleme/sayfalama, kendine/yinelenen aktif ilişkiye atama engeli, API hatasında seçimlerin korunması, çift gönderim, eşzamanlı atamada `409` sonrası yenileme, tarih doğrulaması, ilişki iptali/geçmiş ve sayfadan ayrılınca istek iptalini kapsar. Yerel tarayıcı kontrolünde iki danışman gerçek PostgreSQL'e atanmış; mobil danışman API'sinde ve danışman listelerinde görülmüş; `Ended`/`Cancelled` sonrası aktif okumalardan kaldırılıp Admin geçmişinde korundukları doğrulanmıştır. Flutter ekranı bu kontrol kapsamında çalıştırılmaz.

Program testleri; sözleşmeye uygun POST ve gövdesiz 201, geçersiz tarih/sayı, benzersiz gün seçimi, sıralama ve süre hedefleri, backend alan hatalarında formun korunması, yinelenen gönderimin engellenmesi ve farklı danışanın programına erişim sınırlarını kapsar. Windows sandbox ortamında Vitest geçici dosyaları görünmezse, test komutunun `TEMP` ve `TMP` değişkenleri yazılabilir `web/node_modules/.vitest-tmp` dizinine yönlendirilebilir.

Opt-in web/API/PostgreSQL/Android kontrolü: Docker Desktop ve emülatör açıkken repository kökünde `pwsh -File mobile/tool/auth_smoke.ps1 -AssignmentWriteTest`. Test yalnız geçici veritabanına bağlanır; `AssignmentLive.test.tsx` gerçek React formlarını JSDOM içinde, taklit edilmemiş HTTP ile kullanır. Sonra Android Planım ekranı atamaları okur ve görevi tamamlar. Bu opt-in test normal `npm test` içinde atlanır. Test API portu `5064` kullanılır; `5060/5061` web fetch tarafından engellendiğinden web testi için kullanılmaz.

Beslenme testleri; sözleşmeye uygun POST ve JSON yanıtı, hedef listesinin tekrar yüklenmesi, sıfır/ondalık değerler, geçersiz sayı/tarih ve sayı hassasiyeti, API alan hataları, sonlanan ilişkide atamanın engellenmesi, rol sınırları, yinelenen gönderim, hata sonrası tekrar deneme, hedef geçerlilik sınırları ve örnek hedeflerin tek aktif hedef davranışını doğrular. Gerçek API/PostgreSQL kontrolleri repository kökünden `./backend/tests/AuthSmoke.ps1` ile çalıştırılır; ayrıntılar backend README'sindedir.

## Kaynak düzeni

`src/pages`: ekranlar; `components`: ortak yerleşim ve tablo; `auth`: web oturumu ve rol seçimi; `services`: mevcut REST sözleşmesi; `types`: sözleşmedeki alanlar; `demo`: yalnız geliştirme örnekleri; `hooks/useLoad`: iptal edilebilir yükleme ve tekrar deneme.
