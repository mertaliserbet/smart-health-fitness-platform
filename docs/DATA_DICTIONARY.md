# DATA_DICTIONARY.md

# Yapay Zekâ Destekli Sağlık ve Fitness Platformu
## Veri Sözlüğü

Bu doküman projede kullanılan temel domain kavramlarını, entity'leri, alanları ve ilişkileri tanımlar.

Amaç:

- Aynı kavramın farklı isimlerle oluşturulmasını engellemek
- Backend, mobile, web ve AI tarafında ortak terminoloji kullanmak
- Veritabanı tasarımını anlaşılır hale getirmek
- Codex tarafından yeni model/entity oluşturulurken mevcut yapının kontrol edilmesini sağlamak
- API sözleşmeleri hazırlanırken tek bir domain kaynağı oluşturmak

Bu dosya, `NAMING_CONVENTIONS.md` ile birlikte proje terminolojisinin ana referansıdır.

### Mobil atama okumaları: uygulanmış veri altyapısı

`AddMobileAssignmentReads` migration'ı şu mevcut kavramları kalıcı hale getirir: `AdvisorProfile`, `UserAdvisor`, `AdvisorNote`, `UserTask`, `Exercise`, `WorkoutPlan`, `WorkoutDay`, `WorkoutExercise`, `NutritionGoal`. Bunların dışında yeni domain tablosu eklenmez; `Advisor`/`Trainer`/`Dietitian` için ayrı kullanıcı tablosu oluşturulmaz. `Exercise`, programdaki `ExerciseId` foreign key'i ve gerçek `exerciseName` için gereklidir; Admin katalog oluşturma/güncelleme API'leri mevcut tabloyu kullanır.

- Kimlikler UUID; takvim alanları PostgreSQL `date` / C# `DateOnly`, oluşturma/güncelleme zamanları UTC `timestamptz` kullanır. Enumlar string saklanır ve JSON'da string döner.
- User, danışman, Trainer ve Dietitian referansları `users` tablosuna foreign key ile bağlıdır; atama verileri varken kullanıcı silme `Restrict` davranışıyla korunur. Plan silinirse kendi gün/egzersiz satırları `Cascade`; egzersiz kataloğu referansı `Restrict` olur.
- Bir kullanıcı-danışman çifti için tek aktif ilişki, kullanıcı başına tek aktif program/hedef ve program başına tek `Weekday` PostgreSQL filtreli/benzersiz indekslerle korunur. Gün sırası ve gün içi egzersiz sırası da benzersizdir. Yazma servisleri önceki aktif program/hedefi aynı transaction içinde pasifleştirir; okuma endpointi otomatik aktivasyon/pasifleştirme yapmaz. Aynı kullanıcıya eşzamanlı yazmalar kullanıcı satırı kilidiyle sıraya alınır; ilişki yazma tamamlanana kadar korunur.
- `UserAdvisor` varsayılan durumu `Active` olur. Aktifte `EndDate` null; Ended/Cancelled durumunda `EndDate >= StartDate` zorunludur. Kendi kendine danışman ilişkisi reddedilir. Rehberim yalnız aktif ilişki ve aktif, ilgili danışman rolünü taşıyan kullanıcıları gösterir; opsiyonel aktif profil yoksa isim/rol gösterilir, ünvan/uzmanlık null kalır. Profil aynı kullanıcı ve danışman türü için tektir.
- Beslenme hedefleri negatif olamaz; `numeric(12,2)` saklanır. Egzersiz ağırlığı `numeric(10,2)`; set/tekrar/süre pozitif, dinlenme/ağırlık negatif olamaz. Plan/hedef `EndDate` null veya `StartDate` ve sonrasıdır.
- İsim ve başlıklar en fazla 200 karakter; uzmanlık 500, katalog görsel/video URL'leri 2048 karakterdir. Not içeriği, açıklamalar ve biyografi `text`; güncel alan isimleri değişmez. Görev açıklaması/son tarihi/tamamlanma zamanı ve güncelleme zamanları nullable'dır.
- User görev/notları ilişki sona erse de kendi geçmişinde kalır. Program/hedef/görev/not yazma ve görev tamamlama mevcut tabloları kullanır; bu çalışma için yeni entity/migration gerekmez. Uygulamada seed/demo atama yapılmaz. Entegrasyon fixture'ları yalnız geçici test veritabanını doldurur.

---

# 1. Genel Kurallar

- Teknik isimler İngilizce kullanılacaktır.
- Entity isimleri tekil ve `PascalCase` olacaktır.
- PostgreSQL tabloları çoğul ve `snake_case` olacaktır.
- Varsayılan ID tipi `Guid` olarak düşünülmektedir.
- Normal uygulama kullanıcısının ana domain adı `User` olacaktır.
- `Client`, yalnızca Trainer/Dietitian arayüzlerinde kullanıcıya gösterilen UI ifadesidir; ayrı bir entity değildir.
- `Trainer` ve `Dietitian` temel danışman rolleridir.
- `Advisor`, Trainer ve Dietitian kavramlarını ortak ifade etmek için kullanılan üst seviye terimdir.
- Aynı veri iki farklı entity içinde tekrar tutulmamalıdır.
- AI çıktıları kesin sağlık sonucu değil, tahmini sonuç olarak ele alınmalıdır.
- Mobil ve web istemcileri doğrudan veritabanına erişmez.

---

# 2. User

**Amaç:** Sistemdeki temel kullanıcı hesabını temsil eder.

**Tablo:** `users`

Kullanıcı; normal kullanıcı, trainer, dietitian veya admin rollerinden birine ya da birden fazlasına sahip olabilir.

Önerilen temel alanlar:

```text
Id
FirstName
LastName
Email
PasswordHash
PhoneNumber
BirthDate
Gender
HeightCm
IsActive
CreatedAt
UpdatedAt
```

Açıklamalar:

- `Id`: Kullanıcının benzersiz kimliği.
- `FirstName`: Ad; Türkçe dahil Unicode harfler ve harfe bağlı birleşen işaretler kabul edilir.
- `LastName`: Soyad; `FirstName` ile aynı validation kuralını kullanır. İsim parçaları arasında normal boşluk, tire (`-`) ve apostrof (`'`, `’`) kullanılabilir; sayı, diğer özel karakterler ve kontrol karakterleri kabul edilmez. Ayrıntılı kayıt kuralı `API_CONTRACT.md` §8.1'de tanımlıdır.
- `Email`: Sisteme giriş için kullanılan e-posta.
- `PasswordHash`: Şifrenin hashlenmiş hali.
- `PhoneNumber`: Opsiyonel telefon numarası.
- `BirthDate`: Opsiyonel doğum tarihi.
- `Gender`: Opsiyonel profil verisi.
- `HeightCm`: Kullanıcının boyu.
- `IsActive`: Hesabın aktif olup olmadığını belirtir.
- `CreatedAt`: Oluşturulma zamanı.
- `UpdatedAt`: Son güncellenme zamanı.

Not:

Kilo doğrudan `User` içinde tutulmamalıdır. Kilo geçmişi `WeightRecord` üzerinden yönetilmelidir.

Auth uygulamasında `Email`, baştaki/sondaki boşlukları kaldırılmış ve invariant küçük harfe dönüştürülmüş olarak saklanır; benzersiz indeks aynı e-postayla eşzamanlı kaydı da engeller. `FirstName`/`LastName` en fazla 100, `Email` 254, `PasswordHash` 512 karakterdir. `PasswordHash`, ASP.NET Core `PasswordHasher<User>` tarafından salt ile PBKDF2 kullanılarak üretilir; düz parola saklanmaz.

`PhoneNumber`, `BirthDate`, `Gender`, `HeightCm` ve `UpdatedAt` nullable'dır; public kayıt bu profil alanlarını doldurmaz. `BirthDate` yalnızca tarihtir (`DateOnly`), `HeightCm` nullable decimal'dir. `CreatedAt`/`UpdatedAt` UTC tarih/saatidir. Yeni kullanıcı `IsActive = true` oluşturulur; pasif kullanıcı login/refresh yapamaz ve access token ile korunan endpointlere erişemez. Bu aşamada profil güncelleme akışı yoktur.

---

# 3. Role

**Amaç:** Kullanıcı rollerini temsil eder.

**Tablo:** `roles`

Temel roller:

```text
User
Trainer
Dietitian
Admin
```

Önerilen alanlar:

```text
Id
Name
```

---

# 4. UserRole

**Amaç:** User ile Role arasındaki ilişkiyi temsil eder.

**Tablo:** `user_roles`

Önerilen alanlar:

```text
Id
UserId
RoleId
```

Bir kullanıcı birden fazla role sahip olabilir.

`Role.Name` benzersizdir. Migration yalnızca `User`, `Trainer`, `Dietitian`, `Admin` rol kayıtlarını ekler; yönetici veya danışman hesabı oluşturmaz. `UserRole` için `(UserId, RoleId)` benzersizdir. Public register yalnızca `User` ilişkisi oluşturur; istemci rol seçemez. Ayrı bir `UserRole` enum'u oluşturulmaz; rol değerleri `Role.Name` ile temsil edilir.

## 4.1 RefreshToken

**Amaç:** Kullanıcının access token yenileme yetkisini ve token'ın kullanım durumunu tutar.

**Tablo:** `refresh_tokens`

```text
Id
UserId
TokenHash
CreatedAt
ExpiresAt
RevokedAt
```

- `Id`/`UserId`: Guid; `UserId`, mevcut `User` kaydını işaret eder.
- `TokenHash`: Kriptografik rastgele üretilen refresh token'ın SHA-256 hash'i; 64 karakter ve benzersizdir. Ham refresh token yalnızca login/refresh yanıtında istemciye verilir; veritabanında veya loglarda saklanmaz.
- `CreatedAt`, `ExpiresAt`: Zorunlu UTC tarih/saatidir.
- `RevokedAt`: Nullable UTC tarih/saatidir; doluysa token kullanılamaz.
- Kullanılabilir token: `RevokedAt == null`, `ExpiresAt > now` ve ilgili `User.IsActive == true`.
- Refresh sırasında eski token tüketilir ve yeni token oluşturulur. Koşullu UPDATE ve transaction, eşzamanlı iki isteğin aynı token'ı kullanmasını engeller; yalnızca biri başarılı olur.
- Logout yalnızca giriş yapmış kullanıcının kendi refresh token'ını iptal eder. Access token ayrı olarak iptal edilmez; kısa geçerlilik süresi sonunda sona erer.
- Bu auth kaydı business domain'lerinden bağımsızdır; Advisor/Workout/Nutrition vb. tabloları gerektirmez.

---

# 5. AdvisorProfile

**Amaç:** Trainer ve Dietitian kullanıcılarına ait danışmanlık profil bilgilerini tutar.

**Tablo:** `advisor_profiles`

Önerilen alanlar:

```text
Id
UserId
AdvisorType
Title
Biography
Specialization
IsActive
CreatedAt
UpdatedAt
```

`AdvisorType`:

```text
Trainer
Dietitian
```

Not:

`AdvisorProfile`, ayrı bir kullanıcı hesabı değildir. İlgili `User` kaydını genişletir.

---

# 6. UserAdvisor

**Amaç:** Normal kullanıcı ile Trainer/Dietitian arasındaki danışmanlık ilişkisini temsil eder.

**Tablo:** `user_advisors`

Önerilen alanlar:

```text
Id
UserId
AdvisorId
AdvisorType
StartDate
EndDate
Status
CreatedAt
```

`Status` için önerilen değerler:

```text
Active
Ended
Cancelled
```

İlişki:

```text
User
  |
  v
UserAdvisor
  |
  v
Advisor
```

Kurallar:

- Bir kullanıcı aynı anda birden fazla danışmana sahip olabilir.
- Bir trainer/dietitian birden fazla kullanıcıyla çalışabilir.
- `AdvisorId`, sistemde Trainer veya Dietitian rolüne sahip bir `User` kaydını işaret eder.
- V1'de ilişkiyi yalnızca `Admin` oluşturur. Davet veya kullanıcı onayı yoktur; yeni kayıt doğrudan `Active` olur ve hemen iki tarafın ekranlarında görünür.
- `StartDate` V1'de atama tarihidir. İlişki sonradan yalnızca `Ended` veya `Cancelled` durumuna geçirilebilir; bu durumda `EndDate` doldurulur.
- `Pending` V1 `UserAdvisor` durumları arasında kullanılmaz.

---

# 7. AdvisorNote

**Amaç:** Trainer veya Dietitian tarafından kullanıcıya bırakılan notları temsil eder.

**Tablo:** `advisor_notes`

Önerilen alanlar:

```text
Id
UserId
AdvisorId
Title
Content
CreatedAt
UpdatedAt
```

Örnek:

```text
"Bugün antrenman sonrası 10 dakika esneme yap."
```

---

# 8. UserTask

**Amaç:** Trainer veya Dietitian tarafından kullanıcıya atanan görevleri temsil eder.

**Tablo:** `user_tasks`

Önerilen alanlar:

```text
Id
UserId
AdvisorId
Title
Description
DueDate
Status
CompletedAt
CreatedAt
UpdatedAt
```

`Status`:

```text
Pending
InProgress
Completed
Cancelled
```

V1 yazma davranışı: Görevi aktif bağlı Trainer/Dietitian oluşturur; ilk durum `Pending`, `CompletedAt = null` olur. User yalnız kendi bekleyen/devam eden görevini tamamlar. Görevi oluşturan danışmanın durum değiştirmesi için aktif ilişki gerekir. `Completed` ve `Cancelled` son durumdur; yeniden açılmaz. Aynı durum tekrar gönderildiğinde kayıt ve tamamlanma zamanı korunur. `CompletedAt` tamamlamada sunucu tarafından UTC atanır; istemciden alınmaz. Görev/not başlığı boş olamaz ve en fazla 200 karakterdir; not içeriği zorunludur.

Örnek görevler:

- Günlük 2.5 litre su iç.
- Öğle öğününü kaydet.
- Haftalık 3 koşuyu tamamla.
- Pazartesi antrenman programını uygula.

---

# 9. Exercise

**Amaç:** Sistemde bulunan egzersizleri temsil eder.

**Tablo:** `exercises`

Önerilen alanlar:

```text
Id
Name
Description
Instructions
VideoUrl
ImageUrl
IsActive
CreatedAt
UpdatedAt
```

Örnek:

```text
Bench Press
Lat Pulldown
Squat
Leg Press
```

---

# 10. MuscleGroup

**Amaç:** Egzersizlerin çalıştırdığı kas gruplarını temsil eder.

**Tablo:** `muscle_groups`

Önerilen alanlar:

```text
Id
Name
```

Örnek:

```text
Chest
Back
Shoulders
Biceps
Triceps
Quadriceps
Hamstrings
Calves
Core
```

---

# 11. ExerciseMuscleGroup

**Amaç:** Exercise ile MuscleGroup arasındaki many-to-many ilişkiyi temsil eder.

**Tablo:** `exercise_muscle_groups`

Önerilen alanlar:

```text
Id
ExerciseId
MuscleGroupId
IsPrimary
```

---

# 12. WorkoutPlan

**Amaç:** Trainer tarafından kullanıcı için oluşturulan antrenman programını temsil eder.

**Tablo:** `workout_plans`

Önerilen alanlar:

```text
Id
UserId
TrainerId
Name
Description
StartDate
EndDate
IsActive
CreatedAt
UpdatedAt
```

V1'de bir `User` için aynı anda en fazla bir `IsActive = true` `WorkoutPlan` bulunur. Yeni plan aktif hale getirildiğinde önceki aktif plan pasifleştirilir. Aktif plan yalnızca `StartDate` ve `EndDate` dahil tarih aralığında bugünkü antrenman üretir.

Aktif programı oluşturan ve danışanla aktif Trainer ilişkisi devam eden kişi programı düzenleyebilir. Düzenleme plan/gün/korunan egzersiz kimliklerini ve oluşturma zamanını korur; mevcut `UpdatedAt` alanı eşzamanlı eski ekranın güncel içeriği ezmesini engelleyen sürüm kontrolünde kullanılır. Pasif geçmiş program düzenlenmez. Şema değişikliği yoktur; PUT kuralları `API_CONTRACT.md` 15.5'tedir.

Örnek:

```text
4 Haftalık Başlangıç Programı
Push/Pull/Legs Programı
```

---

# 13. WorkoutDay

**Amaç:** WorkoutPlan içindeki günleri veya antrenman bölümlerini temsil eder.

**Tablo:** `workout_days`

Önerilen alanlar:

```text
Id
WorkoutPlanId
Name
DayNumber
Weekday
Description
```

`DayNumber` program içindeki sıralama numarasıdır. `Weekday` haftalık takvim günüdür ve `Monday`, `Tuesday`, `Wednesday`, `Thursday`, `Friday`, `Saturday` veya `Sunday` değerlerinden birini alır. V1'de her `WorkoutDay` için zorunludur; aynı `WorkoutPlan` içinde aynı `Weekday` değeri ikinci kez kullanılamaz. Bugünkü antrenman, tarih aralığındaki aktif planın bugünün `Weekday` değeriyle eşleşen günüdür; eşleşme yoksa bugün antrenman yoktur.

Örnek:

```text
Day 1 - Push
Day 2 - Pull
Day 3 - Legs
```

---

# 14. WorkoutExercise

**Amaç:** Bir WorkoutDay içinde yapılacak egzersizi ve egzersiz detaylarını temsil eder.

**Tablo:** `workout_exercises`

Önerilen alanlar:

```text
Id
WorkoutDayId
ExerciseId
Order
Sets
Reps
DurationSeconds
RestSeconds
WeightKg
Notes
```

Not:

Her egzersizde tüm alanların zorunlu olması gerekmez.

Örneğin:

- Ağırlık egzersizi için `Sets`, `Reps`
- Kardiyo egzersizi için `DurationSeconds`

kullanılabilir.

---

# 15. WorkoutSession

V1 uygulanmıştır. User/Plan/Day FK'leri `RESTRICT`; sahiplik ve gün/program eşleşmesi API'de doğrulanır. Status string olarak `InProgress`, `Completed`, `Cancelled` saklanır; `Planned` ayrılmıştır, V1 DB kontrolü kabul etmez. Kullanıcı başına tek `InProgress` için filtreli unique index vardır. `StartedAt` sunucu UTC; `CompletedAt` yalnızca Completed durumunda dolu ve başlangıçtan önce olamaz. `Notes` nullable ayrılmış alandır, V1 oturum notu yazmaz; egzersiz notları WorkoutLog'dadır. Oturum başlatılan programın içeriği değiştirilemez; yeni program atanır. Gün/egzersiz hedefleri ve eski oturumlar korunur. İptal fiziksel silme yapmaz.

**Amaç:** Kullanıcının gerçekleştirdiği tek bir antrenman oturumunu temsil eder.

**Tablo:** `workout_sessions`

Önerilen alanlar:

```text
Id
UserId
WorkoutPlanId
WorkoutDayId
StartedAt
CompletedAt
Status
Notes
```

`Status`:

```text
Planned
InProgress
Completed
Cancelled
```

---

# 16. WorkoutLog

V1 uygulanmıştır. `WorkoutSessionId`/`WorkoutExerciseId` çifti unique; bir egzersizin gerçek set/tekrar veya süre değerleri aynı logda güncellenir. FK'ler `RESTRICT`; silme endpointi yoktur. Sayısal alanlar nullable ve negatif olamaz. `WeightKg numeric(10,2)`; sıfır desteklenir. `CompletedReps` set başına tekrar sayısıdır; ayrı set kayıtları V1 kapsamında değildir. `IsCompleted` zorunlu; tamamlandı işaretinde hedef türüne uygun değerler pozitif olmalıdır (API doğrulaması). `Notes` nullable, en fazla 10000 karakter. `CreatedAt` sunucu UTC, güncellemelerde korunur. Terminal oturum logları değiştirilemez. Oturumun Completed olması tüm egzersizlerin tamamlandığı anlamına gelmez; yapılmayan egzersizler de detayda gösterilir.

**Amaç:** Kullanıcının gerçekleştirdiği egzersiz bazlı antrenman kayıtlarını temsil eder.

**Tablo:** `workout_logs`

Önerilen alanlar:

```text
Id
WorkoutSessionId
WorkoutExerciseId
CompletedSets
CompletedReps
WeightKg
DurationSeconds
IsCompleted
Notes
CreatedAt
```

---

# 17. WeightRecord

**Amaç:** Kullanıcının kilo geçmişini tutar.

**Tablo:** `weight_records`

Önerilen alanlar:

```text
Id
UserId
WeightKg
RecordedAt
CreatedAt
```

Uygulama kuralları: `Id`/`UserId` UUID, `WeightKg` PostgreSQL `numeric(6,2)`, `RecordedAt`/`CreatedAt` UTC `timestamp with time zone` olarak saklanır. Kilo 0,01–1000 kg aralığında ve en fazla iki ondalık basamaklıdır; bu teknik giriş sınırıdır, sağlık hedefi değildir. Kayıt zamanı zorunludur ve gelecekte olamaz. `CreatedAt` sunucu tarafından üretilir. Kullanıcı kimliği JWT `sub` alanından alınır; request'ten seçilemez. `(UserId, RecordedAt)` indeksi ve `users` foreign key'i vardır; kullanıcı silinirse kayıtları da silinir. Aynı zamana birden fazla kayıt izinlidir. Liste `RecordedAt`, ardından `CreatedAt` ve `Id` azalan sırasındadır; ilk kayıt güncel kilodur.

Örnek:

```text
01.10.2026 → 83.2 kg
08.10.2026 → 82.4 kg
15.10.2026 → 81.8 kg
```

---

# 18. BodyMeasurement

**Amaç:** Kullanıcının fiziksel ölçümlerini geçmişe dönük olarak tutar.

**Tablo:** `body_measurements`

Önerilen alanlar:

```text
Id
UserId
ChestCm
WaistCm
HipCm
ArmCm
ThighCm
BodyFatPercentage
RecordedAt
CreatedAt
```

Tüm ölçümlerin zorunlu olması gerekmez.

En az bir ölçüm zorunludur; boş alanlar `null` saklanır. Göğüs, bel, kalça, kol ve uyluk 0,01–1000 cm; `BodyFatPercentage` 0–100 aralığındadır. Tüm sayılar en fazla iki ondalık basamaklı ve `numeric(6,2)` olarak saklanır. Bunlar teknik giriş sınırlarıdır. Kimlik, tarih, sahiplik, sıralama, indeks ve foreign key davranışı `WeightRecord` ile aynıdır. Veritabanı check constraint'leri sayı aralıklarını ve en az bir ölçüm koşulunu da korur.

---

# 19. NutritionGoal

**Amaç:** Diyetisyen tarafından kullanıcı için belirlenen günlük beslenme hedeflerini temsil eder.

**Tablo:** `nutrition_goals`

Önerilen alanlar:

```text
Id
UserId
DietitianId
DailyCalories
ProteinGrams
CarbohydrateGrams
FatGrams
WaterMl
StartDate
EndDate
IsActive
CreatedAt
UpdatedAt
```

V1'de bir `User` için aynı anda en fazla bir `IsActive = true` `NutritionGoal` bulunur. Yeni hedef oluşturulup aktif edildiğinde önceki aktif hedef aynı işlemde `IsActive = false` yapılır; önceki hedef otomatik olarak yeniden etkinleşmez. Mobil `Planım` ve günlük beslenme durumu yalnızca bu aktif hedefi kullanır. Hedefin `StartDate` ve `EndDate` tarihleri dahil geçerlilik aralığı dışındaysa o gün için hedef gösterilmez.

---

# 20. NutritionRecord

**Amaç:** Kullanıcının tükettiği öğün veya besin kaydını temsil eder.

**Tablo:** `nutrition_records`

Önerilen alanlar:

```text
Id
UserId
MealType
Name
Calories
ProteinGrams
CarbohydrateGrams
FatGrams
PortionDescription
SourceType
FoodRecognitionLogId
ConsumedAt
CreatedAt
```

`FoodRecognitionLogId` manuel kayıtta `null` olabilir. AI sonucundan kaydedilen öğün, ham tahmin kaydına bu alanla bağlanır; kullanıcının düzelttiği değerler `NutritionRecord` üzerinde tutulur.

Manuel beslenme takibi için uygulanan kurallar:

- `Id`/`UserId`: UUID. Sahip, JWT'deki giriş yapan `User`dır; istemci kullanıcı ID'si seçemez.
- `Name`: zorunlu, en fazla 200 karakter; baştaki/sondaki boşluklar temizlenir. `PortionDescription`: isteğe bağlı metin.
- Kalori ve üç makro alanı: zorunlu `decimal`, PostgreSQL `numeric(12,2)`; 0–9999999999.99, en fazla iki ondalık basamak. Sıfır kabul edilir, negatif değerler reddedilir.
- `ConsumedAt` ve `CreatedAt`: UTC `timestamp with time zone`. Tüketim zamanı zorunludur ve gelecekte olamaz; oluşturma zamanı sunucuda belirlenir.
- `MealType`: yalnız `Breakfast`, `Lunch`, `Dinner`, `Snack`; veritabanında metin enum ve kontrol kısıtı.
- Bu aşamada yalnız `SourceType=Manual` ve `FoodRecognitionLogId=null` kabul edilir. AI tablosu oluşturulmaz; nullable sütunda henüz foreign key yoktur. AI akışı uygulanırken manuel kaynak kısıtı ve ham analiz ilişkisi ilgili migration ile güncellenmelidir.
- `UserId` için `users` foreign key'i vardır; kullanıcı fiziksel olarak silinirse kişisel beslenme kayıtları da silinir. Kayıt silme/düzenleme endpointi bu aşamada yoktur.
- `(UserId, ConsumedAt)` indeksi kullanıcı/tarih filtrelerini destekler. Liste tüketim zamanı, ardından oluşturma zamanı azalan sıradadır.
- Günlük özet ayrı tablo/entity değildir; kullanıcının gün aralığındaki kayıtlarından kalori/makro toplamları hesaplanır. Hedef, mevcut tek aktif `NutritionGoal` ve o hedefin tarih aralığı üzerinden okunur. Geçmiş pasif hedefler otomatik olarak seçilmez.
- Gün sınırları ve saat dilimi davranışı `API_CONTRACT.md` 20.1/20.5'te tanımlıdır; Flutter yerel takvim gününü offset içeren gece yarısı sınırlarıyla gönderir.

`MealType` örnekleri:

```text
Breakfast
Lunch
Dinner
Snack
```

`SourceType`:

```text
Manual
AI
```

---

# 21. FoodRecognitionLog

**Amaç:** Yemek görseli üzerinden yapılan AI analizinin sonucunu ve tahminlerini kayıt altına alır.

**Tablo:** `food_recognition_logs`

Önerilen alanlar:

```text
Id
UserId
ImageUrl
DetectedFood
DetectedItems
EstimatedPortion
EstimatedCalories
EstimatedProteinGrams
EstimatedCarbohydrateGrams
EstimatedFatGrams
Confidence
WasCorrectedByUser
CreatedAt
```

`DetectedItems`, API'deki `items` listesinin her yiyecek için ad, tahmini porsiyon, kalori, makrolar ve güven düzeyini saklayan JSON karşılığıdır. `DetectedFood` ve `EstimatedPortion` genel özet; `EstimatedCalories` ve makro alanları `totals` toplamıdır. `FoodRecognitionLog` ham tahmini korur; kullanıcı düzeltmesi onu değiştirmez.

Kurallar:

- AI sonucu tahmini değerdir.
- Kullanıcı kayıt öncesinde sonucu düzeltebilir.
- Düzeltilmiş son beslenme kaydı `NutritionRecord` olarak tutulabilir.
- AI ham sonucu ile kullanıcı tarafından kabul edilen veri birbirinden ayrılmalıdır.

---

# 22. RunningActivity

**Amaç:** Kullanıcının uygulama üzerinden gerçekleştirdiği koşu aktivitesini temsil eder.

**Tablo:** `running_activities`

Önerilen alanlar:

```text
Id
UserId
StartedAt
EndedAt
DurationSeconds
DistanceMeters
AveragePaceSecondsPerKm
AverageSpeedKmh
EstimatedCalories
RouteData
CreatedAt
```

V1 alan kuralları:

- `Id` mobilin oluşturduğu UUID'dir; aynı koşunun ağ hatasından sonra tekrar gönderilmesi yeni satır oluşturmaz. `UserId` JWT'den belirlenir, `users` FK'sıdır. Kullanıcı yalnız kendi koşularını listeler/okur/ekler.
- `StartedAt/EndedAt/CreatedAt` UTC timestamp; bitiş başlangıçtan önce veya gelecekte olamaz. `DurationSeconds` duraklamalar hariç aktif süre (1–86400), duvar saati aralığından büyük olamaz.
- `DistanceMeters` ve `AverageSpeedKmh`: decimal(12,2); `AveragePaceSecondsPerKm`: nullable decimal(14,2). GPS segmentlerinden mesafe, aktif süreyle ortalama hız/pace backend'de hesaplanır. Sıfır mesafede pace null, hız 0.
- `EstimatedCalories`: nullable decimal(12,2), V1'de null; uydurma kalori değeri yoktur.
- `RouteData`: zorunlu PostgreSQL JSONB. `{type:"gps-segments",segments:[[GPS noktaları], ...]}`; noktada latitude, longitude, accuracyMeters ve UTC recordedAt bulunur. Koşul ve request/response örnekleri `API_CONTRACT.md` 21. bölümündedir. Duraklama/GPS boşlukları ayrı segmentlerdir; araları mesafeye eklenmez. Kullanıcı/başlangıç indeksli; User silinmesinde kişisel kayıtlar mevcut tracking tabloları gibi cascade silinir.
- Mobil yalnız ön planda takip eder; arka planda otomatik duraklar. Tamamlanmış fakat gönderilememiş özet kullanıcı/API adresine özel güvenli cihaz deposunda saklanır; yeniden açılışta aynı ID ile tekrar kaydedilir. Devam eden koşu bellektedir; uygulama zorla kapatılırsa tamamlanmamış koşu kurtarılmaz.

İleride eklenebilecek alanlar:

```text
AverageHeartRate
MaximumHeartRate
Cadence
ElevationGain
```

---

# 23. ActivityRecord

**Amaç:** Günlük genel aktivite özetlerini tutar.

**Tablo:** `activity_records`

Önerilen alanlar:

```text
Id
UserId
Date
StepCount
ActiveCalories
DistanceMeters
ActiveMinutes
SourceType
CreatedAt
UpdatedAt
```

`SourceType` örnekleri:

```text
Manual
Mobile
HealthConnect
HealthKit
```

---

# 24. HealthDataRecord

**Amaç:** Apple Health / HealthKit veya Android Health Connect üzerinden alınan sağlık/aktivite verilerini temsil eder.

**Tablo:** `health_data_records`

Önerilen alanlar:

```text
Id
UserId
DataType
Value
Unit
Source
RecordedAt
CreatedAt
```

`DataType` örnekleri:

```text
StepCount
HeartRate
ActiveCalories
Distance
WorkoutDuration
```

Not:

Bu tablo generic bir sağlık veri yapısıdır. Gerektiğinde kullanım senaryosuna göre sadeleştirilebilir.

---

# 25. GymEquipment

**Amaç:** AI tarafından tanınabilen spor salonu ekipmanlarını temsil eder.

**Tablo:** `gym_equipments`

Önerilen alanlar:

```text
Id
Name
ModelKey
Description
ImageUrl
IsActive
CreatedAt
UpdatedAt
```

Örnek:

```text
Lat Pulldown
Leg Press
Chest Press
Smith Machine
Cable Machine
Treadmill
```

`ModelKey` örneği:

```text
lat_pulldown
leg_press
chest_press
```

AI model çıktısı bu alanla eşleştirilebilir.

---

# 26. EquipmentExercise

**Amaç:** GymEquipment ile Exercise arasındaki many-to-many ilişkiyi temsil eder.

**Tablo:** `equipment_exercises`

Önerilen alanlar:

```text
Id
GymEquipmentId
ExerciseId
```

Örnek:

```text
Lat Pulldown
    ↓
Wide Grip Lat Pulldown
Close Grip Lat Pulldown
Single Arm Pulldown
```

Bu eşleştirme AI modelinin içinde tutulmamalıdır.

---

# 27. AIRecognitionLog

**Amaç:** Genel AI tanıma işlemlerinin geçmişini tutar.

**Tablo:** `ai_recognition_logs`

Önerilen alanlar:

```text
Id
UserId
RecognitionType
ImageUrl
PredictedLabel
Confidence
CreatedAt
```

`RecognitionType`:

```text
GymEquipment
Food
```

Not:

Food Recognition için daha ayrıntılı kayıt gerekiyorsa `FoodRecognitionLog` kullanılmalıdır.

---

# 28. Advisor Assignment Kavramı

`AdvisorAssignment` adı genel görev ataması için kullanılmamalıdır.

Projede iki ayrı kavram net şekilde ayrılır:

```text
UserAdvisor
```

Kullanıcı ile danışman arasındaki ilişkiyi temsil eder.

```text
UserTask
```

Danışmanın kullanıcıya verdiği görevi temsil eder.

Bu iki kavram birbirine karıştırılmamalıdır.

---

# 29. Kullanıcıya Atanan İçerikler

Mobil uygulamadaki **Planım** ekranı tek bir tabloya bağlı değildir.

Planım ekranı aşağıdaki kaynakları bir araya getirir:

```text
WorkoutPlan
NutritionGoal
UserTask
AdvisorNote
```

Yani `MyPlan` isminde ayrı bir entity oluşturmak zorunlu değildir.

`Planım`, bir UI/domain görünümüdür.

---

# 30. Rehberim Kavramı

Mobil uygulamadaki **Rehberim** ekranı aşağıdaki verilere dayanır:

```text
UserAdvisor
AdvisorProfile
User
```

`MyAdvisor` isminde yeni bir entity oluşturulmamalıdır.

---

# 31. Takip Kavramı

Mobil uygulamadaki **Takip** ekranı bir UI bölümüdür.

Aşağıdaki verileri toplu gösterir:

```text
WeightRecord
BodyMeasurement
NutritionRecord
RunningActivity
ActivityRecord
HealthDataRecord
```

`Tracking` adıyla tek bir ana entity oluşturulması zorunlu değildir.

---

# 32. AI Kavramı

Mobil uygulamadaki **AI** ekranı iki ana özelliği toplar:

```text
Food Recognition
Gym Equipment Recognition
```

`FoodRecognition` yemek görselini analiz eden işlemin adıdır; V1'de ayrı bir `FoodRecognition` entity'si oluşturulmaz. Ham tahmin `FoodRecognitionLog`, kullanıcının onayladığı/düzelttiği öğün `NutritionRecord` olarak tutulur. Ekipman tahmini mevcut `GymEquipment` kaydıyla eşleşir.

UI adı `AI` olabilir ancak backend tarafında mümkün olduğunca spesifik servis isimleri kullanılmalıdır.

Örnek:

```text
FoodRecognitionService
GymEquipmentRecognitionService
```

---

# 33. Temel Enum'lar ve Sabit Değerler

## Rol Adları (`Role.Name`)

`UserRole` ilişki entity'sidir; aynı isimle ikinci bir enum oluşturulmaz. Auth rol değerleri `Role.Name` ve kodda `RoleNames` sabitleriyle temsil edilir.

```text
User
Trainer
Dietitian
Admin
```

## AdvisorType

```text
Trainer
Dietitian
```

## UserAdvisorStatus

```text
Active
Ended
Cancelled
```

## Weekday

```text
Monday
Tuesday
Wednesday
Thursday
Friday
Saturday
Sunday
```

## UserTaskStatus

```text
Pending
InProgress
Completed
Cancelled
```

## WorkoutSessionStatus

```text
Planned
InProgress
Completed
Cancelled
```

## MealType

```text
Breakfast
Lunch
Dinner
Snack
```

## NutritionSourceType

```text
Manual
AI
```

## HealthDataSourceType

```text
Manual
Mobile
HealthConnect
HealthKit
```

## AIRecognitionType

```text
GymEquipment
Food
```

---

# 34. Temel İlişkiler

```text
User
 ├── UserRoles
 ├── UserAdvisors
 ├── WeightRecords
 ├── BodyMeasurements
 ├── NutritionRecords
 ├── NutritionGoals
 ├── RunningActivities
 ├── ActivityRecords
 ├── HealthDataRecords
 ├── WorkoutPlans
 ├── WorkoutSessions
 └── UserTasks
```

Trainer:

```text
Trainer(User)
 ├── UserAdvisors
 ├── WorkoutPlans
 ├── AdvisorNotes
 └── UserTasks
```

Dietitian:

```text
Dietitian(User)
 ├── UserAdvisors
 ├── NutritionGoals
 ├── AdvisorNotes
 └── UserTasks
```

Workout:

```text
WorkoutPlan
   ↓
WorkoutDay
   ↓
WorkoutExercise
   ↓
Exercise
```

Equipment:

```text
GymEquipment
   ↓
EquipmentExercise
   ↓
Exercise
```

---

# 35. Kullanılmaması Gereken Alternatif İsimler

Aşağıdaki alternatifler kullanılmamalıdır.

```text
TrainingPlan       → WorkoutPlan
WorkoutProgram     → WorkoutPlan

Coach              → Trainer

Dietician          → Dietitian
Nutritionist       → Dietitian

Customer           → User
Member             → User
Client Entity      → User

WeightHistory      → WeightRecord
NutritionHistory   → NutritionRecord
RunRecord          → RunningActivity

Equipment          → GymEquipment
Machine            → GymEquipment
```

UI metinlerinde Türkçe karşılıklar kullanılabilir ancak teknik domain isimleri değiştirilmemelidir.

---

# 36. Veri Sahipliği

## User Tarafından Oluşturulan

```text
WeightRecord
BodyMeasurement
NutritionRecord
RunningActivity
```

## Trainer Tarafından Oluşturulan

```text
WorkoutPlan
AdvisorNote
UserTask
```

## Dietitian Tarafından Oluşturulan

```text
NutritionGoal
AdvisorNote
UserTask
```

## Sistem / AI Tarafından Oluşturulan

```text
FoodRecognitionLog
AIRecognitionLog
ActivityRecord
HealthDataRecord
```

---

# 37. Silme Politikası

İlk sürüm için kritik geçmiş veriler mümkün olduğunca doğrudan silinmemelidir.

Özellikle:

```text
WorkoutLog
WeightRecord
NutritionRecord
RunningActivity
AIRecognitionLog
```

gibi geçmiş kayıtlarında hard delete yerine gerektiğinde soft delete yaklaşımı değerlendirilebilir.

Bu karar her entity için zorunlu değildir; uygulama gereksinimine göre belirlenmelidir.

---

# 38. Audit Alanları

İhtiyaç duyulan entitylerde ortak olarak şu alanlar kullanılabilir:

```text
CreatedAt
UpdatedAt
```

Gerekli yerlerde:

```text
DeletedAt
```

eklenebilir.

Bu alanların isimleri proje genelinde değiştirilmemelidir.

---

# 39. AI Verisi ile Ana Domain Verisinin Ayrılması

Örnek yemek akışı:

```text
FoodRecognitionLog
        ↓
Kullanıcı kontrolü
        ↓
NutritionRecord
```

AI'nın tahmin ettiği değer doğrudan kesin kullanıcı verisi kabul edilmemelidir.

Örnek ekipman akışı:

```text
AI Prediction
      ↓
GymEquipment.ModelKey
      ↓
GymEquipment
      ↓
EquipmentExercise
      ↓
Exercise
```

---

# 40. API Hazırlanırken Bu Dosyanın Kullanımı

`API_CONTRACT.md` hazırlanırken endpointler bu veri sözlüğündeki domain isimlerine göre oluşturulmalıdır.

Örnek:

```text
WorkoutPlan
```

için:

```http
/api/workout-plans
```

```text
RunningActivity
```

için:

```http
/api/running-activities
```

```text
NutritionRecord
```

için:

```http
/api/nutrition-records
```

---

# 41. Codex İçin Zorunlu Kontrol

Codex yeni bir veri modeli oluşturmadan önce:

1. Bu dosyada kavramı ara.
2. Aynı amacı karşılayan entity olup olmadığını kontrol et.
3. `NAMING_CONVENTIONS.md` kurallarına uy.
4. Var olan ilişki yapısını bozma.
5. Aynı veriyi farklı tabloda tekrar oluşturma.
6. Yeni entity gerekiyorsa neden gerekli olduğunu belirt.
7. Database değişikliği gerekiyorsa ilgili migration öncesinde değişikliği açıkça belirt.
8. API etkisi varsa `API_CONTRACT.md` güncellenmesini unutma.

---

# 42. Hızlı Referans

```text
User                     → Temel kullanıcı hesabı
Role                     → Kullanıcı rolü
UserRole                 → User-Role ilişkisi

AdvisorProfile           → Trainer/Dietitian profil bilgileri
UserAdvisor              → User-Advisor ilişkisi
AdvisorNote              → Danışman notu
UserTask                 → Danışman tarafından atanan görev

Exercise                 → Egzersiz
MuscleGroup              → Kas grubu
ExerciseMuscleGroup      → Exercise-MuscleGroup ilişkisi

WorkoutPlan              → Antrenman programı
WorkoutDay               → Program günü
WorkoutExercise          → Gün içindeki egzersiz
WorkoutSession           → Gerçekleştirilen antrenman oturumu
WorkoutLog               → Egzersiz bazlı gerçekleşen kayıt

WeightRecord             → Kilo kaydı
BodyMeasurement          → Vücut ölçümü

NutritionGoal            → Diyetisyen hedefi
NutritionRecord          → Öğün/beslenme kaydı
FoodRecognitionLog       → AI yemek tahmini

RunningActivity          → Koşu kaydı
ActivityRecord           → Günlük aktivite özeti
HealthDataRecord         → Health Connect/HealthKit verisi

GymEquipment             → Spor salonu ekipmanı
EquipmentExercise        → Ekipman-egzersiz ilişkisi
AIRecognitionLog         → Genel AI tanıma kaydı
```

---

# 43. Son Not

Bu dosyadaki alanlar ilk teknik taslaktır.

Geliştirme sırasında gerçekten ihtiyaç duyulan alanlar sadeleştirilebilir veya yeni alanlar eklenebilir. Ancak:

- entity isimleri,
- temel domain anlamları,
- veri sahipliği,
- ana ilişkiler

ekip tarafından karar verilmeden değiştirilmemelidir.

Her değişiklikte bu dosya da güncel tutulmalıdır.
