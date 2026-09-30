# DATA_DICTIONARY.md

# Yapay Zekâ Destekli Sağlıklı Yaşam ve Danışmanlık Platformu
## Veri Sözlüğü

Bu doküman projede kullanılan temel domain kavramlarını, entity'leri, alanları ve ilişkileri tanımlar.

Amaç:

- Aynı kavramın farklı isimlerle oluşturulmasını engellemek
- Backend, mobile, web ve AI tarafında ortak terminoloji kullanmak
- Veritabanı tasarımını anlaşılır hale getirmek
- Codex tarafından yeni model/entity oluşturulurken mevcut yapının kontrol edilmesini sağlamak
- API sözleşmeleri hazırlanırken tek bir domain kaynağı oluşturmak

Bu dosya, `NAMING_CONVENTIONS.md` ile birlikte proje terminolojisinin ana referansıdır.

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
- `FirstName`: Ad.
- `LastName`: Soyad.
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
Pending
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
Description
```

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
ConsumedAt
CreatedAt
```

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
EstimatedPortion
EstimatedCalories
EstimatedProteinGrams
EstimatedCarbohydrateGrams
EstimatedFatGrams
Confidence
WasCorrectedByUser
CreatedAt
```

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

UI adı `AI` olabilir ancak backend tarafında mümkün olduğunca spesifik servis isimleri kullanılmalıdır.

Örnek:

```text
FoodRecognitionService
GymEquipmentRecognitionService
```

---

# 33. Temel Enum'lar

## UserRole

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
Pending
Active
Ended
Cancelled
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
