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
- Admin için **Egzersizler → Yeni egzersiz / Düzenle**: açıklama, uygulama talimatları, video/görsel bağlantıları ve aktif/pasif durum yönetimi. İsim ve durum filtreleri birlikte çalışır; pasif egzersizler yeniden aktif edilebilir.
- Çoklu web rolünde yalnız hesaba atanmış rollerden panel seçimi. `User` hesabı mobil uygulamaya yönlendiren açıklama görür.
- Responsive koyu arayüz; klavye odağı, görünür alan etiketleri ve yükleniyor/boş/hata durumları.

Trainer ve Dietitian için **Danışanlar → profil → Kilo / Vücut ilerlemesi**: mevcut kilo ve vücut ölçüm kayıtları, dönem seçimi, zaman eksenli grafikler, son ölçüm/değişim özeti ve sayfalı kayıt tablosu.

Program düzenleme, beslenme kayıtları/ilerleme, profil düzenleme, rol yönetimi ve ekipman yönetim formu henüz uygulanmadı. Tamamlanmamış işlemler için işlevsiz düğmeler gösterilmez.

## Gerçek API bağlantısı

Varsayılan `/api` istekleri geliştirmede Vite proxy üzerinden `http://localhost:5000` adresine gider. API'yi backend README'sine göre başlatın. Ayrı API adresi için `.env.example` dosyasını `.env.local` adıyla kopyalayıp `VITE_API_BASE_URL` ayarlayın. `VITE_` değişkenleri tarayıcıya açıktır; gizli anahtar eklemeyin.

İstekler `docs/API_CONTRACT.md` sözleşmesini kullanır. Admin katalog listesi için mevcut route'a `includeInactive=true` seçeneği eklenmiştir; Trainer/mobil varsayılan liste yanıtı korunur. Kullanılan istekler:

| İşlem                         | Endpoint                                                                 |
| ----------------------------- | ------------------------------------------------------------------------ |
| Giriş, yenileme, çıkış        | `POST /api/auth/login`, `/refresh`, `/logout`                            |
| Profil                        | `GET /api/users/me`, `GET /api/users/{userId}`                           |
| Danışan kilo/vücut ilerlemesi | `GET /api/users/{userId}/weight-records`, `/body-measurements`           |
| Antrenörün danışanları        | `GET /api/trainers/me/clients`                                           |
| Diyetisyenin danışanları      | `GET /api/dietitians/me/clients`                                         |
| Yönetici kullanıcı listesi    | `GET /api/users?page=...&pageSize=20`                                    |
| Danışman adaylarını bulma     | `GET /api/users?page=...&pageSize=20&role=Trainer\|Dietitian&search=...` |
| Danışman ilişkileri ve atama  | `GET /api/user-advisors?userId=...`, `POST /api/user-advisors`           |
| İlişkiyi sonlandırma          | `PATCH /api/user-advisors/{userAdvisorId}`                               |
| Egzersiz kataloğu             | `GET /api/exercises`                                                     |
| Admin egzersiz kataloğu       | `GET /api/exercises?includeInactive=true`                                |
| Egzersiz detayı / güncelleme  | `GET/PUT /api/exercises/{exerciseId}`                                    |
| Egzersiz oluşturma            | `POST /api/exercises`                                                    |
| Danışanın programları         | `GET /api/users/{userId}/workout-plans`                                  |
| Program detayı                | `GET /api/workout-plans/{workoutPlanId}`                                 |
| Program oluşturma ve atama    | `POST /api/users/{userId}/workout-plans`                                 |
| Danışanın beslenme hedefleri  | `GET /api/users/{userId}/nutrition-goals`                                |
| Beslenme hedefi atama         | `POST /api/users/{userId}/nutrition-goals`                               |
| Görev/not listesi ve atama    | `GET/POST /api/users/{userId}/tasks`, `/advisor-notes`                   |

Refresh token `sessionStorage` içinde sekme oturumu boyunca saklanır; access token yalnız bellektedir. Sayfa yenilenince refresh ve ardından `/api/users/me` ile oturum doğrulanır. Eşzamanlı `401` cevapları tek refresh isteğini paylaşır. Başarısız yenileme veya tekrar `401` oturumu kapatır. `403` için refresh denenmez. Sunucu çıkışı başarısız olsa bile yerel oturum temizlenir ve kullanıcıya açıklanır.

Kilo/vücut ilerlemesi gerçek danışman hesabıyla kullanılır. Son 30/90 gün, son 1 yıl veya tüm geçmiş seçimi bugün dahil tarayıcının yerel takvim günlerini kapsar; API tüm geçmişi döner, dönem seçimi ve 20 satırlık tablo sayfaları web'de uygulanır. Grafikte kg/cm/% birimleri ve kayıt tarihleri gösterilir. Değişim seçili dönemdeki ilk ve son dolu alanı karşılaştırır; tek ölçümde değişim hesaplanmaz. Kısmi ölçümler “—” olarak kalır ve grafikte çizgiyi keser; sıfır yağ yüzdesi geçerli veridir. Son alan ölçümünün zamanı, başka alanları içeren daha yeni bir kaydın zamanı ile değiştirilmez. Ekran kayıt eklemez veya düzenlemez. Admin erişemez; aktif danışman ilişkisi ve güncel roller API tarafından tekrar doğrulanır. Gerçek API hatasında örnek veri gösterilmez.

Tablodaki endpointler backend'de uygulanmıştır. Danışan listesi yalnız aktif ilişkileri içerir; başka kullanıcının profilini yalnız atanmış danışman veya Admin okuyabilir. Admin temel hesap alanlarını görür; kişisel sağlık alanları ayrıca aktif danışman ilişkisi gerektirir. Web'deki menü/route denetimlerine ek olarak JWT, rol ve aktif `UserAdvisor` denetimi backend tarafından uygulanır. Public register yalnız User hesabı üretir; danışman/Admin rolleri güvenilir kurulum sırasında verilir. Admin ilişki atama/sonlandırma ve egzersiz oluşturma/güncelleme web formları hazırdır. Egzersiz oluşturma/güncelleme ve pasif kayıtların katalogda listelenmesi Admin rolü gerektirir; Trainer kataloğu salt okunurdur.

Danışman yönetimi yalnız `User` rolüne sahip hesaplara açılır. Yeni ilişkinin `startDate` değeri gönderim anındaki UTC takvim günüdür. Kullanıcının kendisi ve aynı kişiyle mevcut aktif ilişki seçimde engellenir; farklı danışmanlar atanabilir. Backend aktif hesap ve rolü tekrar doğrular. Sonlandırmada yalnız `Ended`/`Cancelled` seçilir; bitiş tarihi başlangıçtan önce veya bugünün UTC tarihinden sonra olamaz. Sonlandırma öncesinde sonuçları gösteren bir form açılır; geçmiş kayıtlar silinmez. Hata halinde form korunur, yinelenen gönderim engellenir; `409` halinde güncel ilişki geçmişi tekrar yüklenir. Geçmişteki ilişki yeniden açılmaz; yeni atama ayrı kayıt oluşturur. İlişki listesi yenilenemediğinde atama kapalı kalır.

Egzersiz formu POST/PUT işlemlerinde mevcut `CreateExerciseRequest` alanlarının tamamını gönderir; düzenlemede talimatlar ve bağlantılar korunur. Boş isteğe bağlı alanlar `null`, metinler kırpılarak gönderilir. Alan uzunlukları ve HTTP(S) bağlantıları formda doğrulanır. Başarı için `ExerciseDetailResponse` JSON yanıtı gerekir; hata halinde alanlar korunur ve yinelenen gönderim engellenir. Başarıdan sonra katalog yeniden okunur. Pasifleştirme geçmiş programları silmez, yeni programlarda seçimi engeller.

Admin giriş → egzersiz ekleme → düzenleme/pasifleştirme → yeniden aktifleştirme akışı tarayıcıda ayrı geçici PostgreSQL ile doğrulandı. Kayıtların ve talimatların kalıcılığı, pasif kaydın Trainer kataloğundan çıkarılması, yeniden aktif kaydın geri gelmesi ve Trainer'ın düzenleme URL'sine erişememesi kontrol edildi.

Program formu mevcut `CreateWorkoutPlanRequest` alanlarıyla POST gönderir; Trainer kimliği request'e eklenmez, backend access token'dan alır. Güncel API `201 WorkoutPlanResponse` JSON yanıtı döner; web daha eski gövdesiz `201` yanıtıyla da çalışabilir. Başarıdan sonra danışanın program listesi yeniden yüklenir; istek hatasında form korunur. Atamadan hemen önce aktif danışan listesi tekrar kontrol edilir. Backend aktif ilişkiyi ve tek aktif program kuralını aynı transaction içinde uygular; pasif egzersizler yeni atamada kullanılamaz. Gün/egzersiz sıra kuralları ve ağırlık alanındaki en fazla iki ondalık basamak hem formda hem backend'de doğrulanır.

Beslenme hedefi formu mevcut sözleşmedeki yedi alanı gönderir; Dietitian kimliğini backend token üzerinden alır. Başarı için sözleşmedeki oluşturulan aktif hedefi içeren JSON yanıtı beklenir; gövdesiz `201` beslenme ataması için başarı sayılmaz. Atamadan önce aktif danışan ilişkisi tekrar kontrol edilir; hata halinde form korunur. Backend yeni hedefi aktif edip önceki hedefi aynı veritabanı işleminde pasifleştirir. Sayı alanları en fazla iki ondalık basamak kabul eder. Su alanı yalnız hedeftir; tüketim verisi gösterilmez.

Yerel tarayıcı kontrolünde gerçek giriş → danışan seçimi → antrenman programı atama/detay ve diyetisyen beslenme hedefi atama/liste akışları ayrı geçici PostgreSQL veritabanıyla doğrulandı. Bu atamalar mobilin kullandığı `/api/users/me/workout-plans` ve `/api/users/me/nutrition-goals/active` yanıtlarında da doğrulandı. Flutter ekranları bu kontrolün kapsamına dahil değildir.

## Örnek veri ile önizleme

`npm run dev` giriş ekranında Antrenör / Diyetisyen / Yönetici örnek panellerini açar. Bunlar gerçek oturum oluşturmaz, API'ye istek yapmaz ve sunucuya veri kaydetmez. Panelde örnek veri bandı daima görünür. Örnek oturum sayfa yenilendiğinde sona erer. Gerçek API hatasında otomatik olarak örnek veriye geçilmez.

Antrenör önizlemesinde **Antrenman Programları → danışan seç → Yeni program → gün/egzersiz ekle → Örnek atamayı dene** akışı kullanılabilir. Örnek atama yalnız bellekte tutulur ve sayfa yenilendiğinde sıfırlanır. Önceki örnek aktif program pasif hale gelir; yeni program listeden açılabilir. Sunucuya veya mobil uygulamaya veri gönderilmez.

Diyetisyen önizlemesinde **Beslenme Hedefleri → danışan seç → Yeni hedef → günlük hedefleri ve tarihleri gir → Örnek hedef atamasını dene** akışı kullanılabilir. Yeni örnek hedef, yalnız seçili danışanın önceki aktif hedefini pasifleştirir. Örnek hedefler bellekte tutulur; sayfa yenilendiğinde sıfırlanır. Gelecekte başlayacak aktif hedef, başlangıç tarihine kadar geçerli günlük hedef olarak gösterilmez.

Danışman ilişkisi yönetimi, görev/not ekranı gibi gerçek yetkili hesapla kullanılır. Yönetici önizlemesinde bu ekrana girildiğinde açıklama gösterilir; gerçek API'ye istek veya atama gönderilmez.

Yönetici önizlemesinde egzersiz kataloğu salt okunur. Ekleme/düzenleme için gerçek Admin oturumu gerekir; önizlemeden bu sayfaların URL'leri açılsa da sunucuya istek gönderilmez.

Örnek giriş yalnız Vite development modunda kullanılabilir; production build örnek veri modülünü ve giriş düğmelerini içermez. Production build'in `/api` yolunu ASP.NET Core'a ileten reverse proxy veya `VITE_API_BASE_URL` ayarı gerekir. Hosting, backend CORS ve HTTPS yayın aşamasında birlikte yapılandırılmalıdır.

## Kontroller

```powershell
npm test
npm run build
npm run format:check
```

Testler; token yenileme/eşzamanlı istek, çıkış sırasında yenileme, 401/403 ayrımı, alan hataları, rol sınırları, panel seçimi, danışan araması ve profil geçişini doğrular. API yanıtları testlerde taklit edilir; bu testler gerçek backend entegrasyonunun yerine geçmez.

Egzersiz yönetimi testleri aktif/pasif arama, POST/PUT sözleşmesi, talimatların korunması, pasifleştirme/yeniden aktifleştirme, alan ve sunucu hataları, geçersiz başarı yanıtı, yinelenen gönderim, sayfadan ayrılınca istek iptali, yeniden deneme ve rol/önizleme sınırlarını kapsar. `backend/tests/AdvisorWorkflowChecks.ps1` geçici PostgreSQL üzerinde Admin katalog görünümünü, diğer rollerin erişiminin reddini ve pasif egzersizlerin Trainer/mobil varsayılan kataloğundan çıkarılıp geçmiş programlarda korunmasını doğrular.

Danışman yönetimi testleri; profil bağlantısı/rol sınırları, UTC atama tarihi ve request alanları, sunucuda filtreleme/sayfalama, kendine/yinelenen aktif ilişkiye atama engeli, API hatasında seçimlerin korunması, çift gönderim, eşzamanlı atamada `409` sonrası yenileme, tarih doğrulaması, ilişki iptali/geçmiş ve sayfadan ayrılınca istek iptalini kapsar. Yerel tarayıcı kontrolünde iki danışman gerçek PostgreSQL'e atanmış; mobil danışman API'sinde ve danışman listelerinde görülmüş; `Ended`/`Cancelled` sonrası aktif okumalardan kaldırılıp Admin geçmişinde korundukları doğrulanmıştır. Flutter ekranı bu kontrol kapsamında çalıştırılmaz.

Program testleri; sözleşmeye uygun POST ve gövdesiz 201, geçersiz tarih/sayı, benzersiz gün seçimi, sıralama ve süre hedefleri, backend alan hatalarında formun korunması, yinelenen gönderimin engellenmesi ve farklı danışanın programına erişim sınırlarını kapsar. Windows sandbox ortamında Vitest geçici dosyaları görünmezse, test komutunun `TEMP` ve `TMP` değişkenleri yazılabilir `web/node_modules/.vitest-tmp` dizinine yönlendirilebilir.

Opt-in web/API/PostgreSQL/Android kontrolü: Docker Desktop ve emülatör açıkken repository kökünde `pwsh -File mobile/tool/auth_smoke.ps1 -AssignmentWriteTest`. Test yalnız geçici veritabanına bağlanır; `AssignmentLive.test.tsx` gerçek React formlarını JSDOM içinde, taklit edilmemiş HTTP ile kullanır. Sonra Android Planım ekranı atamaları okur ve görevi tamamlar. Bu opt-in test normal `npm test` içinde atlanır. Test API portu `5064` kullanılır; `5060/5061` web fetch tarafından engellendiğinden web testi için kullanılmaz.

Beslenme testleri; sözleşmeye uygun POST ve JSON yanıtı, hedef listesinin tekrar yüklenmesi, sıfır/ondalık değerler, geçersiz sayı/tarih ve sayı hassasiyeti, API alan hataları, sonlanan ilişkide atamanın engellenmesi, rol sınırları, yinelenen gönderim, hata sonrası tekrar deneme, hedef geçerlilik sınırları ve örnek hedeflerin tek aktif hedef davranışını doğrular. Gerçek API/PostgreSQL kontrolleri repository kökünden `./backend/tests/AuthSmoke.ps1` ile çalıştırılır; ayrıntılar backend README'sindedir.

İlerleme testleri; Trainer/Dietitian profil geçişi, rol/aktif danışan sınırları, API hatasında tekrar deneme, yanıt doğrulama, yerel dönem sınırları, eşzamanlı kayıt sırası, kısmi/sıfır ölçümler, grafik boşlukları ve tablo sayfalarını kapsar. Backend'in geçici PostgreSQL testi mevcut mobil DTO'ları ve salt okunur danışman erişimini karşılaştırır.

## Kaynak düzeni

`src/pages`: ekranlar; `components`: ortak yerleşim ve tablo; `auth`: web oturumu ve rol seçimi; `services`: mevcut REST sözleşmesi; `types`: sözleşmedeki alanlar; `demo`: yalnız geliştirme örnekleri; `hooks/useLoad`: iptal edilebilir yükleme ve tekrar deneme.
