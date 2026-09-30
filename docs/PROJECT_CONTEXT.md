# Yapay Zekâ Destekli Sağlıklı Yaşam ve Danışmanlık Platformu

## 1. Proje Özeti

Bu proje; kullanıcıların antrenman, beslenme, kilo, vücut ölçümleri, koşu ve günlük aktivite verilerini takip edebilecekleri; aynı zamanda kişisel antrenör/koç ve diyetisyenlerle çalışabilecekleri **mobil + web tabanlı yapay zekâ destekli bir sağlıklı yaşam ve danışmanlık platformudur**.

Sistem iki ana kullanıcı tarafına ayrılır:

- **Mobil uygulama:** Normal kullanıcıların günlük kullanım alanıdır.
- **Web uygulaması:** Trainer, diyetisyen ve admin kullanıcılarının danışan yönetimi ve atama işlemlerini yaptığı yönetim panelidir.

Projenin ayırt edici yönlerinden biri, klasik takip özelliklerine ek olarak iki farklı yapay zekâ modülü içermesidir:

1. **Spor salonu ekipmanı tanıma**
2. **Yemek fotoğrafından tahmini kalori ve makro analizi**

Bunlara ek olarak mobil uygulamada GPS tabanlı koşu takibi ve uygun cihazlarda Apple Health / HealthKit veya Android Health Connect üzerinden sağlık ve aktivite verilerinin alınması hedeflenmektedir.

Proje iki kişilik ekip tarafından üniversite bitirme projesi kapsamında geliştirilecektir.

**Proje bitiş tarihi: 24.12.2026**

Planlanan sunum tarihleri:

- 15.10.2026
- 29.10.2026
- 12.11.2026
- 03.12.2026
- 24.12.2026

---

# 2. Projenin Temel Amacı

Platformun temel amacı, kullanıcının spor, beslenme ve günlük aktivite süreçlerini tek uygulama üzerinden takip edebilmesini ve gerektiğinde profesyonel yönlendirme alabilmesini sağlamaktır.

Normal kullanıcı:

- Kayıt olabilir ve giriş yapabilir.
- Profil bilgilerini yönetebilir.
- Kilo ve vücut ölçülerini kaydedebilir.
- Eğitmen tarafından hazırlanan antrenman programını görüntüleyebilir.
- Antrenmanlarını tamamlandı olarak işaretleyebilir.
- Diyetisyen tarafından belirlenen beslenme hedeflerini görüntüleyebilir.
- Günlük beslenme ve kalori kayıtlarını tutabilir.
- Yemek fotoğrafından tahmini kalori ve makro analizi alabilir.
- Koşularını GPS ile takip edebilir.
- Adım, kalp atış hızı, aktif kalori ve benzeri desteklenen sağlık verilerini görüntüleyebilir.
- Kendi gelişimini grafikler üzerinden takip edebilir.
- Kendisine bağlı trainer ve diyetisyenleri görüntüleyebilir.
- Trainer/diyetisyen tarafından atanan plan, görev, hedef ve notları takip edebilir.
- Spor salonundaki ekipmanların fotoğrafını çekerek ekipmanı tanıyabilir.
- Tanınan ekipmanla yapılabilecek egzersizleri görüntüleyebilir.

Trainer ve diyetisyenler ise web paneli üzerinden danışanlarını yönetebilecek, kendilerine tanımlanan yetkiler doğrultusunda plan, hedef, görev ve not atayabilecek ve danışan ilerlemesini görüntüleyebilecektir.

---

# 3. Kullanıcı Rolleri

## 3.1 Normal Kullanıcı

Normal kullanıcı ağırlıklı olarak Flutter mobil uygulamayı kullanır.

Temel yetenekleri:

- Register / Login
- Profil yönetimi
- Kilo takibi
- Vücut ölçümü takibi
- Antrenman programı görüntüleme
- Egzersiz detaylarını görüntüleme
- Antrenman tamamlandı bilgisi girme
- Beslenme kaydı oluşturma
- Kalori ve makro takibi
- AI ile yemek analizi
- AI ile spor ekipmanı tanıma
- Koşu takibi
- Aktivite ve akıllı cihaz verilerini görüntüleme
- Gelişim grafiklerini görüntüleme
- Trainer ve diyetisyenlerini görüntüleme
- Kendisine atanan görev, hedef, plan ve notları takip etme

## 3.2 Trainer / Koç

Trainer ağırlıklı olarak React web panelini kullanır.

Temel yetenekleri:

- Sisteme giriş yapma
- Kendisine bağlı danışanları görüntüleme
- Danışan detayını görüntüleme
- Antrenman programı oluşturma
- Programa egzersiz ekleme
- Set, tekrar, dinlenme ve açıklama bilgileri belirleme
- Danışana görev atama
- Danışana not bırakma
- Danışanın antrenman geçmişini görüntüleme
- Kilo ve vücut gelişimini görüntüleme
- Koşu/aktivite özetlerini görüntüleme
- İlerleme grafiklerini görüntüleme

## 3.3 Diyetisyen

Diyetisyen web panelini kullanır.

Temel yetenekleri:

- Kendisine bağlı danışanları görüntüleme
- Danışan detayını görüntüleme
- Kilo ve vücut gelişimini görüntüleme
- Beslenme ve kalori kayıtlarını görüntüleme
- Günlük kalori hedefi belirleme
- Protein, karbonhidrat ve yağ hedefleri belirleme
- Beslenme hedefi veya temel plan atama
- Danışana görev ve not atama
- AI ile oluşturulan yemek kayıtlarını görüntüleme
- Danışanın ilerleme grafiklerini görüntüleme

İlk sürümde çok detaylı klinik diyet planlama sistemi hedeflenmemektedir.

## 3.4 Admin

Admin web panelini kullanır.

Temel yetenekleri:

- Kullanıcıları görüntüleme
- Kullanıcı rollerini yönetme
- Trainer / diyetisyen / kullanıcı ilişkilerini yönetme
- Gerekirse kullanıcıya trainer veya diyetisyen atama
- Egzersiz kayıtlarını yönetme
- Spor ekipmanı kayıtlarını yönetme
- Temel sistem yönetimi

Admin paneli V1 kapsamında sade tutulacaktır.

---

# 4. Kullanıcı – Danışman İlişkisi

Bir normal kullanıcı aynı anda birden fazla yönlendirici ile çalışabilir.

Örnek:

```text
Kullanıcı: Mert
Trainer: Ahmet
Diyetisyen: Ayşe
```

Aynı trainer veya diyetisyen de birden fazla danışana sahip olabilir.

Bu nedenle kullanıcı-danışman ilişkisi ayrı bir ilişki yapısıyla yönetilmelidir.

```text
User
  |
  v
UserAdvisor
  |
  v
Advisor
```

`UserAdvisor` için düşünülebilecek alanlar:

```text
Id
UserId
AdvisorId
AdvisorType
StartDate
EndDate
Status
```

İleride gerekli olması halinde ilişkiye yetki alanları da eklenebilir:

```text
CanViewWeight
CanViewNutrition
CanEditWorkout
CanEditNutrition
CanViewActivity
```

---

# 5. Danışman Atama ve Kullanıcıya Görev Aktarma Mantığı

Web panelindeki en önemli akışlardan biri trainer/diyetisyen ile kullanıcı arasındaki danışmanlık ilişkisidir.

```text
Admin / Yetkili
      ↓
Kullanıcıya Trainer veya Diyetisyen Atar
      ↓
UserAdvisor Kaydı
      ↓
Trainer / Diyetisyen Danışanı Görür
      ↓
Plan / Hedef / Görev / Not Atar
      ↓
ASP.NET Core API
      ↓
PostgreSQL
      ↓
Mobil Uygulama
      ↓
Planım
```

Kullanıcı mobil uygulamadaki **Planım** sayfasından koç ve diyetisyen tarafından kendisine verilen içerikleri takip eder.

---

# 6. Genel Sistem Mimarisi

```text
                           PostgreSQL
                               ▲
                               │
Flutter Mobile ─────────► ASP.NET Core API ◄───────── React Web
                               │
                               ▼
                        Python FastAPI
                               │
                               ▼
                           AI Models
```

Ana uygulama API'si **ASP.NET Core Web API** olacaktır.

Temel prensip:

```text
Flutter / React
      ↓
ASP.NET Core API
      ↓
PostgreSQL
```

Mobil ve web uygulamaları PostgreSQL'e doğrudan bağlanmamalıdır.

AI işlemlerinde:

```text
Flutter
   ↓
ASP.NET Core API
   ↓
Python FastAPI
   ↓
AI Model
   ↓
Sonuç
   ↓
ASP.NET Core
   ↓
Flutter
```

AI servisi yalnızca model çıkarımı ve AI'ya ait işlemlerle ilgilenmelidir. Uygulamanın ana iş kuralları ASP.NET Core tarafında tutulmalıdır.

---

# 7. Teknoloji Seçimleri

## 7.1 Backend

- C#
- ASP.NET Core Web API
- Entity Framework Core
- REST API
- JWT Authentication
- Refresh Token
- Role / Claim Based Authorization

## 7.2 Veritabanı

- PostgreSQL

## 7.3 Mobil

- Flutter
- Dart

## 7.4 Web

- React
- TypeScript

## 7.5 Yapay Zekâ

- Python
- FastAPI
- PyTorch veya uygun başka bir framework
- OpenCV
- Gerektiğinde YOLO veya uygun başka bir computer vision modeli

## 7.6 Sağlık / Aktivite Entegrasyonu

Android:
- Health Connect

iOS:
- Apple Health / HealthKit

## 7.7 Diğer Araçlar

- Git
- GitHub
- Codex
- Docker
- Docker Compose
- Postman
- xUnit
- Gerekirse GitHub Actions

---

# 8. Mobil Uygulama Bilgi Mimarisi

Mobil uygulamada çok sayıda özellik bulunmasına rağmen ana navigasyon sade tutulacaktır.

Alt navigasyon:

```text
Ana Sayfa | Planım | AI | Takip | Rehberim
```

**AI** butonu alt menünün ortasında daha belirgin bir buton olarak tasarlanabilir.

Profil ve ayarlar ana alt menüye eklenmek yerine sağ üstteki kullanıcı/avatar alanından açılacaktır.

## 8.1 Ana Sayfa

- Bugünkü antrenman
- Günlük kalori durumu
- Makro özeti
- Günlük adım sayısı
- Aktivite özeti
- Son kilo bilgisi
- Bugünkü koşu / son aktivite
- Trainer tarafından verilen yeni görev
- Diyetisyen tarafından verilen yeni hedef/not
- Son AI analizleri

## 8.2 Planım

Bu ekran trainer ve diyetisyen tarafından kullanıcıya atanan içeriklerin merkezidir.

### Antrenman
- Haftalık antrenman programı
- Bugünkü antrenman
- Egzersizler
- Set / tekrar
- Dinlenme bilgileri
- Açıklamalar
- Tamamlandı işaretleme
- Geçmiş antrenmanlar

### Beslenme
- Günlük kalori hedefi
- Protein hedefi
- Karbonhidrat hedefi
- Yağ hedefi
- Diyetisyen notları
- Beslenme hedefleri
- Öğün kayıtları

### Görevler
- Trainer görevleri
- Diyetisyen görevleri
- Açıklamalar
- Tarih bilgisi
- Tamamlandı durumu

## 8.3 AI

### Yemek Tara

- Kamera ile fotoğraf çekme
- Galeriden fotoğraf yükleme
- Yemeği tanıma
- Yaklaşık porsiyon tahmini
- Tahmini kalori
- Tahmini protein
- Tahmini karbonhidrat
- Tahmini yağ
- Kullanıcı düzeltmesi
- Beslenme kaydına ekleme

Bu değerler kesin tıbbi ölçüm değil, **AI destekli tahmin** olarak gösterilmelidir.

### Ekipman Tara

```text
Fotoğraf
   ↓
AI
   ↓
Lat Pulldown
   ↓
ASP.NET Core
   ↓
EquipmentExercises
   ↓
İlgili Egzersizler
```

AI yalnızca ekipmanı tanır. Egzersiz eşleştirmesi backend/veritabanı tarafından yapılır.

## 8.4 Takip

- Kilo takibi
- Vücut ölçümleri
- Kilo grafikleri
- Vücut gelişim grafikleri
- Kalori geçmişi
- Makro geçmişi
- Beslenme geçmişi
- Koşu geçmişi
- Adım sayısı
- Aktivite verileri
- Akıllı cihaz verileri
- Sağlık entegrasyonundan gelen desteklenen veriler

### Koşu Takibi

- GPS konumu
- Rota
- Toplam mesafe
- Süre
- Ortalama hız
- Anlık hız
- Pace
- Tahmini kalori
- Koşu geçmişi

## 8.5 Rehberim

```text
Rehberim
│
├── Koçum / Trainer
└── Diyetisyenim
```

Trainer için:
- Profil bilgileri
- Verdiği antrenman programları
- Görevleri
- Notları

Diyetisyen için:
- Profil bilgileri
- Beslenme hedefleri
- Görevleri
- Notları

## 8.6 Profil ve Ayarlar

- Profil bilgileri
- Boy
- Kilo
- Temel kullanıcı bilgileri
- Bağlı cihazlar
- Health Connect / Apple Health izinleri
- Bildirim ayarları
- Hesap ayarları
- Çıkış

---

# 9. Web Uygulaması Bilgi Mimarisi

## 9.1 Trainer Paneli

```text
Dashboard
Danışanlar
Programlar
Egzersizler
Görevler / Notlar
Profil
```

Trainer; danışanlarını görüntüleyebilir, program oluşturabilir, egzersiz ekleyebilir, görev/not atayabilir ve ilerlemelerini takip edebilir.

## 9.2 Diyetisyen Paneli

```text
Dashboard
Danışanlar
Beslenme Hedefleri
Görevler / Notlar
Raporlar
Profil
```

Diyetisyen; danışanın kilo, ölçüm, kalori, makro ve AI yemek kayıtlarını görebilir; hedef, görev ve not tanımlayabilir.

## 9.3 Admin Paneli

```text
Dashboard
Kullanıcılar
Danışman Atamaları
Egzersizler
Ekipmanlar
Roller
```

Admin gerektiğinde kullanıcı, trainer ve diyetisyen ilişkilerini yönetebilir.

---

# 10. Yapay Zekâ Modülleri

## 10.1 Gym Equipment Recognition

İlk sürüm için yaklaşık 5–10 ekipman sınıfı yeterlidir.

Örnekler:

- Treadmill
- Leg Press
- Lat Pulldown
- Chest Press
- Smith Machine
- Cable Machine

AI çıktısı yalnızca ekipman kimliğidir. Egzersiz önerileri backend/veritabanı tarafından eşleştirilir.

## 10.2 Food Recognition & Calorie Estimation

```text
Kamera / Galeri
      ↓
Fotoğraf
      ↓
ASP.NET Core
      ↓
Python FastAPI
      ↓
Food Recognition
      ↓
Tahmini Porsiyon
      ↓
Tahmini Kalori + Makro
      ↓
Kullanıcı Düzeltmesi
      ↓
Nutrition Record
```

Çıktılar:

- Tanınan yiyecek
- Tahmini porsiyon
- Tahmini kalori
- Tahmini protein
- Tahmini karbonhidrat
- Tahmini yağ

---

# 11. Akıllı Cihaz ve Sağlık Verileri

Her saat üreticisi için ayrı entegrasyon yerine platform düzeyindeki sağlık servisleri tercih edilir.

Android:

```text
Wearable / Health App
        ↓
Health Connect
        ↓
Flutter
        ↓
ASP.NET Core
```

iOS:

```text
Apple Watch / Health Source
        ↓
Apple Health / HealthKit
        ↓
Flutter
        ↓
ASP.NET Core
```

İlk aşamada hedeflenen veriler:

- Adım sayısı
- Kalp atış hızı
- Aktif kalori
- Yürüme / koşu mesafesi
- Egzersiz kayıtları
- Aktivite süresi

Tüm erişimler kullanıcı izinlerine bağlı olmalıdır.

---

# 12. Muhtemel Veritabanı Varlıkları

```text
Users
Roles
UserRoles

AdvisorProfiles
UserAdvisors

Exercises
MuscleGroups
ExerciseMuscleGroups

WorkoutPlans
WorkoutDays
WorkoutExercises
WorkoutSessions
WorkoutLogs

AdvisorAssignments
AdvisorNotes
UserTasks

WeightRecords
BodyMeasurements

NutritionRecords
NutritionGoals
FoodRecognitionLogs

RunningActivities
ActivityRecords
HealthDataRecords

GymEquipments
EquipmentExercises

AIRecognitionLogs
```

Nihai isimler geliştirme başlamadan önce:

- `docs/NAMING_CONVENTIONS.md`
- `docs/DATA_DICTIONARY.md`

dosyalarında kesinleştirilmelidir.

---

# 13. Temel İş Akışları

## 13.1 Kullanıcı Kaydı

```text
Flutter → Register → ASP.NET Core → PostgreSQL
```

## 13.2 Trainer Program Atama

```text
Trainer → Web Panel → Danışanı Seç → Workout Plan → Kaydet / Ata → API → Mobil Planım
```

## 13.3 Diyetisyen Hedef Atama

```text
Dietitian → Web Panel → Danışanı Seç → Kalori / Makro Hedefi → Görev / Not → API → Mobil Planım
```

## 13.4 Antrenman Tamamlama

```text
Mobil → Planım → Bugünkü Antrenman → Tamamlandı → WorkoutLog → Trainer Web
```

## 13.5 Yemek Analizi

```text
Mobil Kamera → Yemek Fotoğrafı → AI → Kalori / Makro Tahmini → Kullanıcı Düzeltmesi → NutritionRecord
```

## 13.6 Koşu Kaydı

```text
Mobil → Koşuyu Başlat → GPS → Mesafe / Süre / Pace / Rota → RunningActivity
```

---

# 14. Geliştirme Takvimi

## 14.1 15.10.2026 — Temel Sistem

- Gereksinimlerin kesinleştirilmesi
- GitHub repository kurulumu
- `AGENTS.md`
- `PROJECT_CONTEXT.md`
- `NAMING_CONVENTIONS.md`
- `DATA_DICTIONARY.md`
- `API_CONTRACT.md`
- Temel ER diagramı
- ASP.NET Core kurulumu
- PostgreSQL
- Entity Framework Core
- Flutter projesi
- React projesi
- Register / Login temel akışı
- JWT temel yapısı
- Mobil/Web → API bağlantısının doğrulanması

## 14.2 29.10.2026 — Kullanıcı ve Danışman Sistemi

- User / Trainer / Dietitian / Admin rolleri
- UserAdvisor ilişkisi
- Trainer / diyetisyen atama işlemleri
- Web danışan listeleri
- Mobil Rehberim ekranı
- Yetkilendirme temelleri
- Web dashboard iskeleti

## 14.3 12.11.2026 — Antrenman ve Danışman Atamaları

- Exercise sistemi
- WorkoutPlan
- WorkoutDay
- WorkoutExercise
- WorkoutLog
- Trainer program oluşturma
- Programın danışana atanması
- Mobil Planım
- Antrenman tamamlama
- Diyetisyen kalori/makro hedefi
- Görev / not yapısı

## 14.4 03.12.2026 — Takip, Aktivite ve AI

- Kilo takibi
- Vücut ölçümleri
- İlerleme grafikleri
- Beslenme kayıtları
- Kalori / makro takibi
- GPS koşu takibi
- RunningActivity
- Gym Equipment Recognition
- Food Recognition
- Tahmini kalori/makro analizi
- Flutter kamera entegrasyonu
- FastAPI entegrasyonu
- Mümkün olan seviyede Health Connect / HealthKit entegrasyonu

## 14.5 24.12.2026 — Final

Bu aşamada yeni büyük özellik eklenmemelidir.

- Entegrasyonların tamamlanması
- Hata düzeltme
- Authentication / Authorization testleri
- API testleri
- Mobil / Web / AI testleri
- UI/UX iyileştirmeleri
- Deployment
- Demo verileri
- Bitirme raporu
- Sunum
- Final demo

**Proje bitiş tarihi: 24.12.2026**

---

# 15. İki Kişilik İş Bölümü

## 15.1 Mert

### Mobil
- Flutter
- Kullanıcı mobil uygulaması
- Mobil navigasyon
- API entegrasyonu
- Kamera
- GPS
- Koşu takibi
- Health Connect / HealthKit entegrasyonu

### Backend
- ASP.NET Core
- Entity Framework Core
- REST API
- Authentication
- Authorization
- JWT
- Refresh Token
- PostgreSQL entegrasyonu
- Database migrations
- API sözleşmelerinin backend uygulaması

### AI / Computer Vision
- Python
- FastAPI
- Gym Equipment Recognition
- Food Recognition
- Kalori / makro tahmin entegrasyonu
- AI servisinin ASP.NET Core ile entegrasyonu

## 15.2 Uğur Çetin

### Web
- React
- TypeScript
- Trainer paneli
- Diyetisyen paneli
- Admin ekranları
- Dashboard
- Danışan listesi
- Danışan detayları
- Antrenman programı oluşturma arayüzleri
- Beslenme hedefi atama arayüzleri
- Görev / not ekranları
- Grafikler
- Web API entegrasyonları
- Form ve hata yönetimi

## 15.3 Ortak Sorumluluklar

- Sistem mimarisi kararları
- Veritabanı tasarım kararları
- API sözleşmelerinin belirlenmesi
- İsimlendirme standartları
- Test
- Kod inceleme
- Dokümantasyon
- Bitirme raporu
- Sunum
- Demo senaryosu

---

# 16. GitHub ve Codex Çalışma Düzeni

```text
project-root/
│
├── backend/
├── mobile/
├── web/
├── ai/
├── docs/
│   ├── PROJECT_CONTEXT.md
│   ├── NAMING_CONVENTIONS.md
│   ├── DATA_DICTIONARY.md
│   └── API_CONTRACT.md
│
├── AGENTS.md
├── README.md
└── .gitignore
```

Feature branch örnekleri:

```text
feature/auth-api
feature/workout-api
feature/mobile-workout
feature/web-trainer-dashboard
feature/ai-food
feature/ai-equipment
feature/running-tracking
```

Akış:

```text
Feature Branch → Pull Request → Review → main
```

Codex geliştirme yapmadan önce:

1. `AGENTS.md`
2. `docs/PROJECT_CONTEXT.md`
3. `docs/NAMING_CONVENTIONS.md`
4. `docs/DATA_DICTIONARY.md`
5. `docs/API_CONTRACT.md`

dosyalarını dikkate almalıdır.

---

# 17. API ve Veritabanı Koordinasyonu

Mobil ve web ekiplerinin farklı isimler kullanmasını engellemek için API ve veri modelinde tek kaynak kullanılmalıdır.

Örnek:

```text
C# Entity           PostgreSQL

WorkoutPlan      →  workout_plans
WorkoutPlanId    →  workout_plan_id
CreatedAt        →  created_at
UserAdvisor      →  user_advisors
```

Kesin kurallar `NAMING_CONVENTIONS.md` dosyasında tanımlanacaktır.

Projedeki kavramların anlamı `DATA_DICTIONARY.md` dosyasında tutulacaktır.

API endpoint, request ve response yapıları `API_CONTRACT.md` içerisinde tanımlanacaktır.

EF Core migration yönetimi ağırlıklı olarak backend sorumlusu tarafından yürütülmelidir.

---

# 18. V1 Kapsamı

## Backend

- Authentication
- Authorization
- PostgreSQL
- EF Core
- User / Trainer / Dietitian / Admin
- UserAdvisor
- Workout sistemi
- Advisor görev / not yapısı
- Kilo / vücut ölçümü
- Beslenme / kalori / makro
- RunningActivity
- AI entegrasyonları
- Temel sağlık verisi entegrasyonu

## Mobile

- Login / Register
- Ana Sayfa
- Planım
- AI
- Takip
- Rehberim
- Profil
- Kilo / ölçüm
- Antrenman görüntüleme ve tamamlama
- Kalori / makro takibi
- Yemek fotoğrafı analizi
- Spor ekipmanı tanıma
- GPS koşu takibi
- Gelişim grafikleri
- Trainer / diyetisyen bilgileri
- Görev / hedef takibi
- Health Connect / HealthKit temel entegrasyonu

## Web

- Login
- Trainer dashboard
- Dietitian dashboard
- Temel admin
- Danışan listeleri
- Danışan detayları
- Trainer/diyetisyen atama ilişkilerinin yönetimi
- Antrenman programı oluşturma
- Beslenme hedefi atama
- Görev / not atama
- Kullanıcı ilerleme verileri
- Grafikler

## AI

- Gym Equipment Recognition
- Food Recognition
- Tahmini porsiyon
- Tahmini kalori
- Tahmini protein / karbonhidrat / yağ
- Flutter kamera entegrasyonu
- FastAPI servisi
- ASP.NET Core entegrasyonu

---

# 19. V1 Kapsamı Dışındaki Özellikler

- Marketplace
- Eğitmen paket satışı
- Ödeme sistemi
- Komisyon sistemi
- Abonelik sistemi
- Video görüşme
- Canlı görüntülü koçluk
- Canlı pose estimation
- Otomatik hareket formu değerlendirme
- Sosyal medya yapısı
- Çok gelişmiş chat sistemi
- Klinik seviyede detaylı diyet planlama
- Her akıllı saat markasına özel doğrudan entegrasyon

---

# 20. Demo Senaryosu

1. Kullanıcı mobil uygulamadan sisteme giriş yapar.
2. Trainer web paneline giriş yapar.
3. Trainer kendisine bağlı danışanı görüntüler.
4. Trainer kullanıcıya antrenman programı atar.
5. Diyetisyen kullanıcıya kalori/makro hedefi ve görev atar.
6. Kullanıcı mobil **Planım** ekranında atanan içerikleri görür.
7. Kullanıcı antrenmanı tamamlar.
8. Trainer web panelinde tamamlanan antrenmanı görür.
9. Kullanıcı kilo bilgisini girer.
10. Kullanıcı koşu başlatır ve temel koşu verisi kaydedilir.
11. Kullanıcı yemek fotoğrafı çeker.
12. AI tahmini kalori ve makro değerlerini üretir.
13. Kullanıcı sonucu düzeltip kaydeder.
14. Kullanıcı spor salonu ekipmanı fotoğrafı çeker.
15. AI ekipmanı tanır.
16. Sistem ekipmanla yapılabilecek egzersizleri gösterir.
17. Kullanıcının gelişim verileri mobil ve web grafiklerinde görüntülenir.

---

# 21. Başarı Kriterleri

- Sistem uçtan uca çalışmalıdır.
- Mobil ve web uygulamaları backend ile haberleşmelidir.
- Kullanıcı giriş sistemi çalışmalıdır.
- Roller ve yetkilendirme çalışmalıdır.
- UserAdvisor ilişkisi çalışmalıdır.
- Trainer program oluşturabilmelidir.
- Diyetisyen hedef / görev atayabilmelidir.
- Mobil kullanıcı atanan içerikleri görebilmelidir.
- Kullanıcı antrenman tamamlayabilmelidir.
- Kilo ve gelişim kayıtları tutulmalıdır.
- Kalori ve beslenme kayıtları tutulmalıdır.
- GPS ile temel koşu kaydı oluşturulabilmelidir.
- Gym Equipment Recognition entegre edilmelidir.
- Food Recognition ve tahmini kalori/makro analizi entegre edilmelidir.
- Temel dashboard ve grafikler bulunmalıdır.
- Final tarihinde gösterilebilir, stabil bir V1 çalışmalıdır.

---

# 22. Öncelik Sırası

```text
1. Repository + Proje Standartları
2. Authentication
3. Database
4. User / Advisor Sistemi
5. Workout Sistemi
6. Mobile Temel Yapı
7. Trainer / Dietitian Web Paneli
8. Plan / Görev / Hedef Akışları
9. Progress Tracking
10. Nutrition
11. Running Tracking
12. Gym Equipment AI
13. Food AI
14. Health Integration
15. Testing
16. Deployment
```

---

# 23. Önemli Proje Prensipleri

## 23.1 Önce Çalışan Sistem

Yeni teknoloji kullanmak uğruna proje gereksiz şekilde karmaşıklaştırılmamalıdır.

## 23.2 Modular Monolith

ASP.NET Core tarafında ilk sürüm için microservice mimarisi kullanılmayacaktır.

Örnek modüller:

```text
Identity
Users
Advisors
Workouts
Nutrition
Tracking
Running
AI
```

Python AI servisi ayrı servis olabilir.

## 23.3 İstemciler DB'ye Doğrudan Bağlanmaz

```text
Flutter / React
      ↓
ASP.NET Core
      ↓
PostgreSQL
```

## 23.4 AI ve İş Mantığı Ayrılır

AI modeli tahmin üretir. İş kuralları ve veri eşleştirmeleri backend tarafından yönetilir.

## 23.5 API Contract Tek Kaynaktır

Mobil ve web aynı API isimlerini kullanmalıdır. Yeni endpoint veya DTO eklenirken `API_CONTRACT.md` güncellenmelidir.

## 23.6 Son Aşamada Yeni Büyük Özellik Eklenmez

Finale yaklaşıldığında öncelik test, bug fix, deployment, dokümantasyon, demo ve sunumdur.

---

# 24. Codex İçin Genel Proje Bağlamı

- Proje iki kişilik üniversite bitirme projesidir.
- Proje bitiş tarihi 24.12.2026'dır.
- Mobil Flutter ile geliştirilecektir.
- Web React + TypeScript ile geliştirilecektir.
- Backend ASP.NET Core olacaktır.
- Veritabanı PostgreSQL olacaktır.
- ORM Entity Framework Core olacaktır.
- AI servisi Python + FastAPI olacaktır.
- Mobil uygulama normal kullanıcı odaklıdır.
- Web uygulama Trainer, Dietitian ve Admin odaklıdır.
- Kullanıcı aynı anda birden fazla danışmanla çalışabilir.
- Mobil ana menü: Ana Sayfa, Planım, AI, Takip, Rehberim.
- Food Recognition ve Gym Equipment Recognition proje kapsamındadır.
- GPS koşu takibi proje kapsamındadır.
- Health Connect / HealthKit entegrasyonu temel seviyede hedeflenmektedir.
- Marketplace, ödeme, video görüşme ve canlı pose estimation V1 kapsamında değildir.
- Backend modular monolith yaklaşımında tutulmalıdır.
- Gereksiz mimari karmaşıklıktan kaçınılmalıdır.
- Var olan isimler değiştirilmemelidir.
- API ve database değişiklikleri sessizce yapılmamalıdır.
- Çalışan uçtan uca özellik, yarım kalan çok sayıdaki özellikten daha değerlidir.

---

# 25. Kısa Proje Tanımı

> **Yapay Zekâ Destekli Sağlıklı Yaşam ve Danışmanlık Platformu**, kullanıcıların antrenman, beslenme, kilo, vücut gelişimi, koşu ve günlük aktivite verilerini takip edebildiği; aynı zamanda trainer ve diyetisyenlerden plan, hedef ve görev alabildiği mobil ve web tabanlı bir sistemdir. Platform, yemek fotoğrafından tahmini kalori/makro analizi ve spor salonu ekipmanı tanıma özellikleri için yapay zekâ modülleri içerir. Kullanıcı mobil uygulama üzerinden günlük sürecini yönetirken trainer ve diyetisyenler web panelinden danışanlarını takip eder ve ilgili planları oluşturur. Sistem Flutter, React + TypeScript, ASP.NET Core, PostgreSQL ve Python/FastAPI teknolojileriyle geliştirilecektir.
