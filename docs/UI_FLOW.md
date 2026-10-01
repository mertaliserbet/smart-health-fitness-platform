# Yapay Zekâ Destekli Sağlık ve Fitness Platformu — Ekranlar ve Kullanıcı Akışları

Bu belge V1 ekran yapısını ve kullanıcıların ekranlar arasında nasıl ilerleyeceğini tanımlar. Teknik terimler `DATA_DICTIONARY.md` ile, mevcut API yolları `API_CONTRACT.md` ile uyumludur. Buradaki ekran adları kullanıcıya görünen Türkçe adlardır; yeni entity veya endpoint tanımı değildir. Durumu belirsiz konular en sonda listelenmiştir.

Resmi proje adı **Yapay Zekâ Destekli Sağlık ve Fitness Platformu**; repository adı `smart-health-fitness-platform` olarak kalır.

## 1. Genel yapı

- Mobil uygulama `User` rolü içindir. Alt navigasyon: **Ana Sayfa · Planım · AI · Takip · Rehberim**. **Profil/Ayarlar** avatar üzerinden açılır; alt menüye eklenmez.
- Web uygulaması `Trainer`, `Dietitian` ve `Admin` içindir. Giriş sonrası rolün izin verdiği ekranlar gösterilir. Birden fazla role sahip hesabın panel seçimi henüz karara bağlanmalıdır.
- Mobil ve web veriyi ASP.NET Core API üzerinden alır; PostgreSQL'e doğrudan erişmez. AI isteği de backend üzerinden FastAPI servisine gider.
- Atama gerektiren içerik yoksa ilgili ekran boş durum gösterir. Boş durum, yeni veri oluşturulduğu anlamına gelmez.
- V1 danışman ataması Admin tarafından doğrudan `Active` oluşturulur; kullanıcı daveti/onayı yoktur. Aynı kullanıcı için tek aktif `WorkoutPlan` ve tek aktif `NutritionGoal` bulunur.
- Tablolarda `GET ...` mevcut sözleşmedeki okuma isteğini, `POST/PUT/PATCH ...` kaydetme isteğini gösterir. **Yerel** ifadesi cihaz izni, kamera veya GPS gibi backend dışı işlemdir.

## 2. Mobil ekranlar

### 2.1 Giriş öncesi (ana navigasyon dışında)

| Ekran | Amaç ve işlemler | Geçişler | Veri / servis |
|---|---|---|---|
| Karşılama / oturum kontrolü | Saklanan oturumu kontrol eder; giriş veya kayıt seçtirir. | Giriş, Kayıt; geçerli oturumla Ana Sayfa | Gerektiğinde `POST /api/auth/refresh`, `GET /api/users/me` |
| Kayıt | Ad, soyad, e-posta ve şifreyle `User` hesabı açar; doğrulama hatasını gösterir. | Giriş | `POST /api/auth/register` |
| Giriş | E-posta ve şifreyle oturum açar; hataları gösterir. | Kayıt; başarılıysa Ana Sayfa | `POST /api/auth/login`, `GET /api/users/me` |

### 2.2 Ana Sayfa

| Ekran | Amaç ve işlemler | Geçişler | Backend verisi |
|---|---|---|---|
| Ana Sayfa | Bugünkü antrenmanı, kalori/makro durumunu, aktiviteyi, son kiloyu ve bekleyen görevleri özetler; kartlara dokunulur. Bugünkü antrenman yalnızca aktif planın tarih aralığındaki bugünün `Weekday` günüdür. | Planım, antrenman günü, beslenme geçmişi, Takip, Rehberim, AI, Profil | `GET /api/users/me/dashboard?date=YYYY-MM-DD` (cihazın yerel tarihi); gerektiğinde `GET /api/users/me/advisors` |

### 2.3 Planım

| Ekran | Amaç ve işlemler | Geçişler | Backend verisi |
|---|---|---|---|
| Planım özeti | Atanmış `WorkoutPlan`, aktif `NutritionGoal`, `UserTask` ve `AdvisorNote` içeriklerini birlikte gösterir. Atama yoksa boş durum gösterir. | Antrenman programı, Beslenme hedefi, Görevler, Notlar, Rehberim | `GET /api/users/me/workout-plans`, `GET /api/users/me/nutrition-goals/active?date=YYYY-MM-DD`, `GET /api/users/me/tasks`, `GET /api/users/me/advisor-notes`; `/my-plan` yalnızca isteğe bağlı taslak |
| Antrenman programı | Aktif/geçerli programı ve `Weekday` ile haftanın gününe atanmış günlerini listeler; her haftanın gününde en fazla bir antrenman vardır. | Antrenman günü, antrenman geçmişi, Planım | `GET /api/users/me/workout-plans`, `GET /api/workout-plans/{workoutPlanId}` |
| Antrenman günü / egzersizler | `WorkoutDay` içindeki sıralı `WorkoutExercise` kayıtlarını, set/tekrar/süre/dinlenme bilgilerini gösterir; oturum başlatılır. Egzersiz açıklaması açılır. | Egzersiz detayı, aktif antrenman, program | `GET /api/workout-plans/{workoutPlanId}`, gerekirse `GET /api/exercises/{exerciseId}`, `POST /api/workout-sessions` |
| Egzersiz detayı | Talimatı ve varsa görsel/video bilgisini gösterir. | Antrenman günü, aktif antrenman | `GET /api/exercises/{exerciseId}` |
| Aktif antrenman | Yapılan set/tekrar/ağırlık veya süreyi girer; egzersizi ve sonunda oturumu tamamlar. | Tamamlanma özeti, antrenman günü | `PUT /api/workout-sessions/{sessionId}/exercises/{workoutExerciseId}`, `POST /api/workout-sessions/{sessionId}/complete` |
| Tamamlanma özeti / antrenman geçmişi | Bitirilen oturumu ve eski oturumları gösterir. | Planım, antrenman programı | `GET /api/users/me/workout-sessions`; tek oturum detayı yanıtı tanımsız |
| Beslenme hedefi | Tarih aralığı geçerli olan tek aktif `NutritionGoal` kaydının günlük kalori, makro ve su hedeflerini ve diyetisyen notlarını gösterir; öğün kaydına gider. | Beslenme kaydı, Notlar, Planım | `GET /api/users/me/nutrition-goals/active?date=YYYY-MM-DD`, `GET /api/users/me/advisor-notes` |
| Görevler | Danışman görevlerini ve son tarihlerini listeler; kendi görevini tamamlar. | Planım, görev ayrıntısı, Rehberim | `GET /api/users/me/tasks`, `PATCH /api/tasks/{taskId}` |
| Görev ayrıntısı | Açıklama ve durumu gösterir; durumu günceller. | Görevler | `GET /api/users/me/tasks` listesindeki kayıt, `PATCH /api/tasks/{taskId}` |
| Notlar | Danışman notlarını ve yazarı gösterir; okur. | Planım, Rehberim | `GET /api/users/me/advisor-notes` |

### 2.4 AI

| Ekran | Amaç ve işlemler | Geçişler | Backend verisi / servis |
|---|---|---|---|
| AI başlangıcı | Yemek veya ekipman taramasını seçtirir; sonuçlar tahmin olarak sunulur. | Yemek fotoğrafı, Ekipman fotoğrafı | Başlangıç için zorunlu backend verisi yok |
| Yemek fotoğrafı | Kameradan fotoğraf çeker veya galeriden seçer; analizi backend üzerinden başlatır. | Yemek analiz sonucu, AI | Yerel kamera/galeri izni; Flutter → `POST /api/ai/food/recognize` → ASP.NET Core → FastAPI |
| Yemek analiz sonucu / düzeltme | Tahmini yiyecek, porsiyon, kalori ve makroları gösterir; kullanıcı adı/değerleri, öğün türünü ve tüketim zamanını kontrol edip düzeltir. Kaydetmeden çıkabilir. | Takip > Beslenme geçmişi, AI | Tanıma yanıtındaki `items`, `totals`, `recognitionLogId`; onay sonrası `POST /api/users/me/nutrition-records` (`sourceType: AI`) |
| Ekipman fotoğrafı | Kameradan/galeriden ekipman görseli alır ve backend üzerinden taratır. | Ekipman sonucu, AI | Yerel kamera/galeri izni; Flutter → `POST /api/ai/gym-equipment/recognize` → ASP.NET Core → FastAPI |
| Ekipman sonucu / ilgili egzersizler | Tanınan `GymEquipment`, güven düzeyi ve backend'in eşlediği egzersizleri gösterir; egzersiz açılır. | Egzersiz detayı, AI | Tanıma yanıtındaki `equipment`, `confidence`, `exercises`; gerekirse `GET /api/gym-equipments/{gymEquipmentId}` ve `GET /api/exercises/{exerciseId}` |

### 2.5 Takip

| Ekran | Amaç ve işlemler | Geçişler | Backend verisi / servis |
|---|---|---|---|
| Takip özeti | Kilo, ölçüm, beslenme, koşu ve günlük aktivite özetlerine erişim sağlar; grafik kartları gösterir. | Kilo, Ölçümler, Beslenme geçmişi, Koşu, Sağlık verileri | İlgili `GET /api/users/me/...` kayıtları; ayrı zorunlu `Tracking` endpointi yok |
| Kilo geçmişi / grafik | Tarihli kiloları listeler ve değişimi çizer; yeni kayıt açar. | Kilo ekle, Takip | `GET /api/users/me/weight-records` |
| Kilo ekle | Kilo ve kayıt zamanını girip kaydeder; doğrulama hatasını gösterir. | Kilo geçmişi | `POST /api/users/me/weight-records` |
| Vücut ölçümleri / grafik | Tarihli ölçümleri listeler, uygun alanlarda gelişimi gösterir. | Ölçüm ekle, Takip | `GET /api/users/me/body-measurements` |
| Ölçüm ekle | Seçilen vücut ölçülerini ve zamanı girip kaydeder. | Vücut ölçümleri | `POST /api/users/me/body-measurements` |
| Beslenme geçmişi / günlük durum | Öğünleri tarihe göre listeler; günlük kalori/makroyu yalnızca geçerli tek aktif hedefle karşılaştırır; manuel kayıt ekler. | Manuel öğün ekle, AI > Yemek fotoğrafı, Beslenme hedefi, Takip | `GET /api/users/me/nutrition-records?date=...`, `GET /api/users/me/nutrition-goals/active?date=YYYY-MM-DD` |
| Manuel öğün ekle | Öğün türü, ad, porsiyon, kalori ve makroları girip kaydeder. | Beslenme geçmişi | `POST /api/users/me/nutrition-records` (`sourceType: Manual`) |
| Koşu geçmişi | Kaydedilmiş koşuları listeler; yeni koşu başlatır. | Canlı koşu, Koşu detayı, Takip | `GET /api/users/me/running-activities` |
| Canlı koşu | Konum izniyle GPS rotası, süre, mesafe ve hızı izler; koşuyu bitirip özeti onaylar. | Koşu özeti, Koşu geçmişi | Yerel konum/GPS; biten kayıt için `POST /api/users/me/running-activities` |
| Koşu özeti / detayı | Rota, mesafe, süre, tempo, ortalama hız ve tahmini kaloriyi gösterir. | Koşu geçmişi, Takip | `GET /api/running-activities/{runningActivityId}`; kaydetme yanıtı ayrıntısı henüz belirtilmemiş |
| Günlük aktivite / sağlık verileri | Flutter'ın kullanıcı izniyle Health Connect/HealthKit'ten okuyup API'ye gönderdiği adım, kalori, nabız ve diğer desteklenen verileri gösterir. | Sağlık bağlantısı ayarları, Takip | Health Connect/HealthKit → Flutter → ASP.NET Core API → PostgreSQL; `GET /api/users/me/activity-records`, `GET /api/users/me/health-data-records`; izin sonrası ilgili `POST` yolları |

### 2.6 Rehberim

| Ekran | Amaç ve işlemler | Geçişler | Backend verisi |
|---|---|---|---|
| Rehberim | Admin atamasıyla doğrudan `Active` olan `Trainer` ve `Dietitian` ilişkilerini ayrı gösterir; danışman yoksa boş durum sunar. | Danışman detayı, Planım | `GET /api/users/me/advisors` |
| Danışman detayı | Danışmanın profil özetini, verdiği program/hedef, görev ve notları gösterir; içerik açılır. Birden fazla danışmanda yazara göre ayırır. | Antrenman programı, Beslenme hedefi, Görevler, Notlar, Rehberim | `GET /api/users/me/advisors`, `GET /api/users/me/workout-plans`, `GET /api/users/me/nutrition-goals/active`, `GET /api/users/me/tasks`, `GET /api/users/me/advisor-notes`; tam danışman profili ve yazar alanları netleşmeli |

### 2.7 Profil/Ayarlar (alt menü dışında)

| Ekran | Amaç ve işlemler | Geçişler | Backend verisi / servis |
|---|---|---|---|
| Profil | Kişisel bilgileri görür; düzenlemeye geçer. Kilo geçmişi profil alanı yerine Takip'tedir. | Profil düzenle, Sağlık bağlantısı, Ayarlar, Ana Sayfa | `GET /api/users/me` |
| Profil düzenle | Ad, soyad, telefon, doğum tarihi, cinsiyet ve boyu günceller. | Profil | `PUT /api/users/me` |
| Sağlık bağlantısı ve izinler | Android'de Health Connect, iOS'ta HealthKit iznini ister; izin durumunu ve son verileri gösterir, senkronizasyonu başlatır. | Sağlık verileri, Profil | Yerel işletim sistemi izinleri; `GET /api/users/me/activity-records`, `GET /api/users/me/health-data-records`; senkronizasyon için ilgili `POST` yolları |
| Ayarlar / oturum | Hesaptan çıkış yapar; desteklenirse bildirim tercihlerine erişir. | Profil, Giriş | `POST /api/auth/logout`; bildirim tercihi için API/veri modeli tanımlı değil |

## 3. Web ekranları ve rol erişimi

**D = doğrudan erişim; — = erişim yok.** V1'de `Admin` yalnızca kullanıcıları görüntüleme, roller, `UserAdvisor` atamaları, egzersiz ve `GymEquipment` yönetimi alanlarına erişir. Liste ve detay API'lerinde backend ayrıca danışan ilişkisinin aktifliğini ve veri sahipliğini denetler.

| Web ekran grubu ve alt ekranları | Amaç / işlemler; sonraki ekran | Trainer | Dietitian | Admin | Mevcut backend verisi |
|---|---|:---:|:---:|:---:|---|
| **1. Login** | Giriş yapar; role göre Dashboard'a gider. | D | D | D | `POST /api/auth/login`, gerektiğinde `/refresh`, `/logout` |
| **2. Dashboard** | Bağlı danışanları ve ilgili görev/ilerleme özetini gösterir; Danışanlar veya ilgili atama ekranına gider. | D | D | D (sade) | Trainer: `GET /api/trainers/me/clients`; Dietitian: `GET /api/dietitians/me/clients`; web özet yanıtı tanımsız |
| **3. Danışanlar** | Yalnızca bağlı kullanıcıları listeler, seçip Danışan Detayı'na gider. | D | D | — | `GET /api/trainers/me/clients` veya `GET /api/dietitians/me/clients` |
| **4. Danışan Detayı** | Profil ve izinli ilerlemeyi gösterir; ilgili program/hedef, görev/not ekranlarına gider. Trainer antrenman/kilo/ölçüm/koşuyu; Dietitian beslenme/kilo/ölçümü görür. | D | D | — | `GET /api/users/{userId}`, ilgili `GET /api/users/{userId}/...` kayıtları; ilişki kontrolü şart |
| **5. Antrenman Programları** (liste, oluştur/düzenle, gün/egzersiz seçimi, geçmiş) | Trainer `WorkoutPlan` oluşturup her `WorkoutDay` için benzersiz `Weekday` seçer; bağlı danışana atar ve geçmişi inceler. | D | — | — | `GET /api/users/{userId}/workout-plans`, `GET /api/workout-plans/{workoutPlanId}`, `GET /api/exercises`, `POST /api/users/{userId}/workout-plans`, `PUT /api/workout-plans/{workoutPlanId}`, `GET /api/users/{userId}/workout-sessions` |
| **6. Beslenme Hedefleri** (danışan hedefleri, hedef oluşturma) | Dietitian kalori/makro/su hedefini tarihleriyle atar; danışanın beslenme kayıtlarını görür; Danışan Detayı'na döner. | — | D | — | `GET /api/users/{userId}/nutrition-goals`, `POST /api/users/{userId}/nutrition-goals`, `GET /api/users/{userId}/nutrition-records` |
| **7. Görevler / Notlar** (danışana göre liste, ekleme) | Bağlı danışana `UserTask` veya `AdvisorNote` ekler; görev durumunu görür; Danışan Detayı'na döner. | D | D | — | `GET/POST /api/users/{userId}/tasks`, `PATCH /api/tasks/{taskId}`, `GET/POST /api/users/{userId}/advisor-notes` |
| **8. Egzersiz Yönetimi** (katalog, detay; admin düzenleme) | Trainer egzersizi arar ve programa seçer. Admin egzersiz kaydı oluşturur/günceller. | D (okuma/seçim) | — | D (yönetim) | `GET /api/exercises`, `GET /api/exercises/{exerciseId}`; yalnızca Admin: `POST /api/exercises`, `PUT /api/exercises/{exerciseId}` |
| **9. Admin alanları** (kullanıcılar, roller, danışman atamaları, ekipmanlar) | Kullanıcıları görür, rol ve `UserAdvisor` ilişkilerini yönetir, egzersiz ve ekipman kataloğunu oluşturur/günceller. | — | — | D | `GET /api/users`, `PUT /api/users/{userId}/roles`, `GET/POST /api/user-advisors`, `PATCH /api/user-advisors/{userAdvisorId}`, `GET/POST/PUT /api/gym-equipments`, `GET/POST/PUT /api/exercises` |
| **10. Profil** | Kendi bilgisini görüntüler/düzenler; oturumu kapatır, Login'e döner. | D | D | D | `GET/PUT /api/users/me`, `POST /api/auth/logout` |

`Dietitian` için ayrı “Raporlar” menüsü yerine V1'de Danışan Detayı içindeki beslenme, kilo ve ölçüm grafikleri kullanılır. Trainer'ın egzersiz kataloğuna erişimi düzenleme yetkisi vermez. `Admin` atama yaptığı kullanıcıyı Admin > Kullanıcılar üzerinden seçer; bu, danışmanın kendi “Danışanlar” listesiyle aynı ekran değildir.

## 4. Temel kullanıcı akışları

1. **Register / Login:** Mobil Kayıt → `POST /api/auth/register` → Giriş → `POST /api/auth/login` → `User` ise Ana Sayfa. Trainer/Dietitian/Admin web Login → role uygun Dashboard. Token süresi dolunca `/api/auth/refresh`; çıkışta `/api/auth/logout`. Hatalar aynı formda gösterilir.
2. **Trainer atanması:** Admin > Kullanıcılar → kullanıcı seçimi → uygun `Trainer` seçimi → `POST /api/user-advisors` (`advisorType: Trainer`) → ilişki doğrudan `Active` → trainer'ın Danışanlar listesi ve kullanıcının Rehberim ekranı hemen güncellenir. Davet/onay yoktur. İlişki `PATCH /api/user-advisors/{userAdvisorId}` ile `Ended` veya `Cancelled` yapılabilir.
3. **Dietitian atanması:** Admin aynı atama ekranında `Dietitian` seçer → `POST /api/user-advisors` (`advisorType: Dietitian`) → ilişki doğrudan `Active` → diyetisyenin Danışanlar listesi ve mobil Rehberim hemen güncellenir. Atama yetkisi yalnızca Admin'dedir.
4. **Trainer'ın program ataması:** Trainer Login → Danışanlar → Danışan Detayı → Antrenman Programları → egzersiz kataloğundan seçim, her `WorkoutDay` için tekil `Weekday`, set/tekrar/dinlenme ve tarihleri girme → `POST /api/users/{userId}/workout-plans` → kullanıcı Planım'da aktif programı görür. Tarih aralığı dışında veya bugüne eşleşen gün yoksa bugünkü antrenman boş olur.
5. **Dietitian'ın hedef ataması:** Dietitian Login → Danışanlar → Danışan Detayı → Beslenme Hedefleri → günlük kalori, protein, karbonhidrat, yağ, su ve tarihleri girme → `POST /api/users/{userId}/nutrition-goals` → backend önceki aktif hedefi aynı işlemde pasifleştirir → kullanıcı Planım ve günlük beslenmede tarih aralığı geçerli yeni hedefi görür.
6. **Planım'da atamaları görme:** Kullanıcı Planım'ı açar → tek aktif program, tarih aralığı geçerli tek aktif hedef, görev ve notlar ilgili dört kaynaktan yüklenir → kartla ayrıntıya geçer. Atama veya o gün geçerli içerik yoksa ilgili bölüm boş durum gösterir.
7. **Antrenman tamamlama:** Planım → program günü → `POST /api/workout-sessions` → egzersiz gerçekleşenlerini `PUT /api/workout-sessions/{sessionId}/exercises/{workoutExerciseId}` ile kaydetme → `POST /api/workout-sessions/{sessionId}/complete` → mobil geçmiş ve trainer'ın danışan antrenman geçmişi güncellenir. Tamamlanmamış oturumdan çıkma/devam davranışı karar bekler.
8. **Kilo / vücut ölçümü ekleme:** Takip → Kilo veya Ölçümler → Ekle → değer ve kayıt zamanı → ilgili `POST /api/users/me/weight-records` veya `/body-measurements` → liste/grafik yenilenir; yetkili danışman Danışan Detayı'nda görür.
9. **Yemek fotoğrafından AI analizi:** AI → Yemek fotoğrafı → Flutter kamera/galeri → ASP.NET Core API → Python FastAPI → AI Model → backend üzerinden Flutter'a tahmin → kullanıcı porsiyon/kalori/makroları düzeltip onaylar → `POST /api/users/me/nutrition-records` (`sourceType: AI`, `foodRecognitionLogId`) → Takip > Beslenme geçmişi güncellenir. İptalde `NutritionRecord` oluşmaz; AI tahmini kesin beslenme verisi olarak sunulmaz.
10. **Spor ekipmanı AI analizi:** AI → Ekipman fotoğrafı → Flutter → ASP.NET Core API → Python FastAPI → AI ekipman tahmini → backend `GymEquipment.ModelKey` ve `EquipmentExercise` ile egzersizleri eşler → Flutter sonuç ekranı → Egzersiz detayı. Flutter FastAPI'ye doğrudan bağlanmaz.
11. **GPS koşu takibi:** Takip → Koşu geçmişi → Koşuyu başlat → yerel konum izni → canlı süre/rota/mesafe → Bitir → özet onayı → `POST /api/users/me/running-activities` → Koşu geçmişi/detayı. İzin reddinde takip başlamaz; kaydetme başarısızlığında veri kaybını önleme davranışı netleştirilmeli.
12. **Health Connect / HealthKit verilerini görüntüleme:** Profil > Sağlık bağlantısı → kullanıcıdan işletim sistemi izni → Health Connect / HealthKit → Flutter okur → ASP.NET Core API'ye `POST /api/users/me/activity-records` ve/veya `POST /api/users/me/health-data-records/batch` → PostgreSQL → Takip'te ilgili `GET` istekleriyle gösterilir. Sağlık platformu backend'e doğrudan bağlanmaz.

## 5. V1 kararlarından sonra kalan açık noktalar

Resmi ad, `UserAdvisor` aktivasyonu, `WorkoutDay.Weekday`, tek aktif `NutritionGoal`, AI ve sağlık veri yolu ile Admin V1 yetkileri kaynak belgelere işlendi. Aşağıdaki ayrıntılar bu kararlardan bağımsızdır ve uygulanacak ilgili ekrandan önce kesinleştirilmelidir.

| Konu | Kalan karar / etkisi |
|---|---|
| Danışman detayı | `GET /api/users/me/advisors` kısa profil verir; tam `AdvisorProfile.Biography` ve görev/notların `advisorId` ile ayrılması için yanıt yapısı henüz tanımlı değil. V1 ekranı mevcut kısa profille başlayabilir. |
| Antrenman oturumu | Yarım kalan `WorkoutSession` için devam/iptal ve tek oturum detayı yanıtı tanımlı değil. Bugünkü gün seçimi ise `Weekday` ile kesinleşti. |
| Sağlık senkronizasyonu ve ayarlar | İzin cihazda alınır; tekrar gönderilen örnekleri ayıklama, senkronizasyon sıklığı ve bildirim tercihinin saklanması tanımlı değil. |
| GPS koşusu | `RunningActivity.RouteData` nihai biçimi, başarısız kaydı kurtarma ve zayıf GPS davranışı henüz tanımlı değil. |

## 6. Geliştirme referansı

Önerilen ilk uçtan uca gösterim sırası: **giriş → Admin danışman ataması → Trainer programı / Dietitian hedefi → mobil Planım → antrenman tamamlama → Takip kayıtları**. AI, GPS ve sağlık bağlantısı bu temel akışın üzerine eklenir. Her ekranın boş, yükleniyor ve hata durumları olmalıdır; veri kaydetme başarısı backend yanıtıyla doğrulanmalıdır.
