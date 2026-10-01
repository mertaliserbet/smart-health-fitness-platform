# NAMING_CONVENTIONS.md

# Yapay Zekâ Destekli Sağlık ve Fitness Platformu
## İsimlendirme Standartları

Bu doküman; backend, mobil, web, yapay zekâ servisi, veritabanı, API ve Git üzerinde kullanılan isimlerin tutarlı olmasını sağlamak için hazırlanmıştır.

Amaç:

- Aynı kavram için farklı isimler kullanılmasını engellemek
- Mert, Uğur ve Codex tarafından üretilen kodların aynı standartta olmasını sağlamak
- API, veritabanı ve istemci taraflarında isim karmaşasını önlemek
- Kodun okunabilirliğini ve sürdürülebilirliğini artırmak

Bu dosya, proje boyunca isimlendirme konusunda **ana referans** olarak kabul edilmelidir.

---

# 1. Genel Kural

Aynı kavram proje genelinde mümkün olduğunca aynı temel isimle kullanılmalıdır.

Örnek:

Doğru:

```text
WorkoutPlan
workoutPlan
workout_plan
workout-plans
```

Yanlış:

```text
WorkoutPlan
TrainingPlan
ExerciseProgram
WorkoutProgram
```

Aynı kavram için gereksiz alternatif isimler oluşturulmamalıdır.

Yeni bir isim eklemeden önce:

1. `DATA_DICTIONARY.md`
2. Mevcut entity/model isimleri
3. API endpointleri
4. Veritabanı tabloları

kontrol edilmelidir.

---

# 2. Dil Kullanımı

Kod, veritabanı, API ve teknik dosya isimlerinde **İngilizce** kullanılacaktır.

Kullanıcı arayüzünde Türkçe metin kullanılabilir.

Örnek:

Kod:

```text
WorkoutPlan
NutritionRecord
RunningActivity
```

UI:

```text
Antrenman Programı
Beslenme Kaydı
Koşu Aktivitesi
```

Türkçe ve İngilizce isimler kod içerisinde karıştırılmamalıdır.

Yanlış:

```text
AntrenmanPlan
BeslenmeRecord
KosuActivity
```

---

# 3. C# / ASP.NET Core İsimlendirme

## 3.1 Class

Class isimleri `PascalCase` kullanılmalıdır.

Doğru:

```csharp
WorkoutPlan
NutritionRecord
UserAdvisor
RunningActivity
```

Yanlış:

```csharp
workoutPlan
workout_plan
Workoutplan
```

---

## 3.2 Interface

Interface isimleri `I` harfi ile başlamalıdır.

```csharp
IWorkoutService
INutritionService
IUserRepository
IAIRecognitionService
```

---

## 3.3 Method

Method isimleri `PascalCase` olmalıdır.

```csharp
GetWorkoutPlan()
CreateWorkoutPlan()
UpdateNutritionGoal()
GetUserAdvisors()
```

Async metodlarda `Async` eki kullanılmalıdır.

```csharp
GetWorkoutPlanAsync()
CreateWorkoutPlanAsync()
SaveChangesAsync()
```

---

## 3.4 Property

Property isimleri `PascalCase` olmalıdır.

```csharp
Id
UserId
WorkoutPlanId
CreatedAt
UpdatedAt
IsActive
```

---

## 3.5 Local Variable

Local variable isimleri `camelCase` olmalıdır.

```csharp
userId
workoutPlan
nutritionRecord
runningActivity
```

---

## 3.6 Parameter

Method parametreleri `camelCase` olmalıdır.

```csharp
GetWorkoutPlanAsync(Guid userId)
CreateNutritionRecord(CreateNutritionRecordRequest request)
```

---

## 3.7 Private Field

Private field isimleri `_camelCase` formatında olmalıdır.

```csharp
_privateService
_workoutRepository
_dbContext
_logger
```

---

## 3.8 Constant

Constant isimleri `PascalCase` kullanılmalıdır.

```csharp
DefaultPageSize
MaximumUploadSize
TokenExpirationMinutes
```

---

# 4. Entity İsimlendirme

Entity isimleri tekil ve `PascalCase` olmalıdır.

Doğru:

```text
User
Role
UserRole
AdvisorProfile
UserAdvisor
Exercise
MuscleGroup
WorkoutPlan
WorkoutDay
WorkoutExercise
WorkoutSession
WorkoutLog
WeightRecord
BodyMeasurement
NutritionRecord
NutritionGoal
RunningActivity
ActivityRecord
HealthDataRecord
GymEquipment
EquipmentExercise
AIRecognitionLog
FoodRecognitionLog
AdvisorNote
UserTask
```

Entity isimleri çoğul kullanılmamalıdır.

Yanlış:

```text
Users
WorkoutPlans
NutritionRecords
```

---

# 5. DTO İsimlendirme

DTO isimleri işlemi açıkça belirtmelidir.

## Request

```text
CreateWorkoutPlanRequest
UpdateWorkoutPlanRequest
CreateNutritionRecordRequest
LoginRequest
RegisterRequest
```

## Response

```text
WorkoutPlanResponse
NutritionRecordResponse
LoginResponse
UserProfileResponse
```

## Liste / Özet DTO

```text
WorkoutPlanSummaryResponse
ClientListItemResponse
RunningActivitySummaryResponse
```

Belirsiz isimler kullanılmamalıdır.

Yanlış:

```text
WorkoutDto
DataDto
ResultDto
RequestDto
```

---

# 6. Service İsimlendirme

Servis class isimleri işle ilgili olmalıdır.

```text
WorkoutService
NutritionService
UserService
AdvisorService
RunningService
HealthDataService
AIRecognitionService
```

Interface karşılığı:

```text
IWorkoutService
INutritionService
IUserService
IAdvisorService
IRunningService
IHealthDataService
IAIRecognitionService
```

---

# 7. Repository İsimlendirme

Repository kullanılacaksa:

```text
UserRepository
WorkoutPlanRepository
NutritionRecordRepository
```

Interface:

```text
IUserRepository
IWorkoutPlanRepository
INutritionRecordRepository
```

Generic repository gereksiz yere kullanılmamalıdır.

---

# 8. Controller İsimlendirme

ASP.NET Core controller isimleri çoğul domain ismi + `Controller` formatında olmalıdır.

```text
UsersController
WorkoutPlansController
NutritionRecordsController
RunningActivitiesController
AdvisorsController
AIController
```

---

# 9. PostgreSQL Tablo İsimlendirme

PostgreSQL tablo isimlerinde:

- `snake_case`
- çoğul isim

kullanılacaktır.

Örnek:

```text
users
roles
user_roles
advisor_profiles
user_advisors
exercises
muscle_groups
exercise_muscle_groups
workout_plans
workout_days
workout_exercises
workout_sessions
workout_logs
weight_records
body_measurements
nutrition_records
nutrition_goals
running_activities
activity_records
health_data_records
gym_equipments
equipment_exercises
ai_recognition_logs
food_recognition_logs
advisor_notes
user_tasks
```

---

# 10. PostgreSQL Kolon İsimlendirme

Kolon isimleri `snake_case` olmalıdır.

```text
id
user_id
advisor_id
workout_plan_id
created_at
updated_at
start_date
end_date
is_active
```

C# karşılığı:

```text
UserId      → user_id
CreatedAt   → created_at
IsActive    → is_active
```

---

# 11. Primary Key

Varsayılan primary key adı:

```text
id
```

C# tarafında:

```csharp
Id
```

kullanılacaktır.

---

# 12. Foreign Key

Foreign key isimleri:

```text
user_id
advisor_id
workout_plan_id
exercise_id
```

C# tarafında:

```csharp
UserId
AdvisorId
WorkoutPlanId
ExerciseId
```

---

# 13. Tarih Alanları

Genel tarih alanları:

```text
created_at
updated_at
deleted_at
start_date
end_date
completed_at
```

C#:

```text
CreatedAt
UpdatedAt
DeletedAt
StartDate
EndDate
CompletedAt
```

Aynı anlama gelen farklı alanlar oluşturulmamalıdır.

Örneğin hem:

```text
created_date
creation_date
created_at
```

kullanılmamalıdır.

Standart:

```text
created_at
```

---

# 14. Boolean Alanlar

Boolean alan isimleri olumlu ve anlaşılır olmalıdır.

Doğru:

```text
is_active
is_completed
is_deleted
is_verified
```

C#:

```text
IsActive
IsCompleted
IsDeleted
IsVerified
```

Yanlış:

```text
status_flag
active_value
completed_check
```

---

# 15. API Endpoint İsimlendirme

Endpointlerde:

- küçük harf
- kebab-case
- çoğul kaynak isimleri

kullanılmalıdır.

Örnek:

```http
/api/users
/api/workout-plans
/api/nutrition-records
/api/running-activities
/api/user-advisors
/api/gym-equipments
```

---

# 16. API Endpoint Örnekleri

Liste:

```http
GET /api/workout-plans
```

Tek kayıt:

```http
GET /api/workout-plans/{id}
```

Yeni kayıt:

```http
POST /api/workout-plans
```

Güncelleme:

```http
PUT /api/workout-plans/{id}
```

Silme:

```http
DELETE /api/workout-plans/{id}
```

Alt kaynak:

```http
GET /api/users/{userId}/advisors
GET /api/trainers/{trainerId}/clients
GET /api/users/{userId}/running-activities
```

Endpoint içerisinde fiil kullanımından kaçınılmalıdır.

Tercih edilmez:

```http
/api/getWorkoutPlan
/api/createWorkout
```

---

# 17. JSON Alan İsimlendirme

API JSON alanlarında `camelCase` kullanılacaktır.

Örnek:

```json
{
  "id": 12,
  "userId": 5,
  "workoutPlanId": 8,
  "createdAt": "2026-10-12T10:30:00Z",
  "isCompleted": true
}
```

---

# 18. Flutter / Dart İsimlendirme

## Class

`PascalCase`

```dart
WorkoutPlan
NutritionRecord
RunningActivity
```

## Variable

`camelCase`

```dart
workoutPlan
nutritionRecord
userId
```

## Method

`camelCase`

```dart
getWorkoutPlan()
saveNutritionRecord()
startRunningActivity()
```

## File

`snake_case`

```text
workout_plan.dart
nutrition_record.dart
running_activity.dart
```

## Widget

```text
WorkoutPlanCard
NutritionSummaryCard
RunningActivityScreen
```

---

# 19. Flutter Ekran İsimleri

Ekranlarda `Screen` eki kullanılacaktır.

```text
HomeScreen
MyPlanScreen
AIScreen
TrackingScreen
MyAdvisorsScreen
LoginScreen
RegisterScreen
ProfileScreen
RunningTrackingScreen
```

---

# 20. Flutter Service İsimleri

```text
ApiService
AuthService
WorkoutService
NutritionService
RunningService
HealthService
AIService
```

Dosya örnekleri:

```text
api_service.dart
auth_service.dart
workout_service.dart
```

---

# 21. React / TypeScript İsimlendirme

## Component

`PascalCase`

```text
TrainerDashboard
ClientList
WorkoutPlanForm
NutritionGoalForm
```

## File

Component dosyalarında `PascalCase` tercih edilir.

```text
TrainerDashboard.tsx
ClientList.tsx
WorkoutPlanForm.tsx
```

Utility / service dosyalarında `camelCase` kullanılabilir.

```text
apiClient.ts
authService.ts
workoutService.ts
```

---

# 22. TypeScript Variable ve Function

`camelCase`

```typescript
userId
workoutPlan
getWorkoutPlans()
createNutritionGoal()
```

---

# 23. TypeScript Type / Interface

`PascalCase`

```typescript
User
WorkoutPlan
NutritionRecord
RunningActivity
```

API request/response modellerinde:

```text
CreateWorkoutPlanRequest
WorkoutPlanResponse
```

---

# 24. React Hook

Custom hook isimleri `use` ile başlamalıdır.

```text
useAuth
useWorkoutPlans
useNutritionRecords
useRunningActivities
```

---

# 25. Python / FastAPI İsimlendirme

Python tarafında PEP 8 temel alınmalıdır.

## Class

`PascalCase`

```python
FoodRecognitionService
GymEquipmentModel
PredictionResult
```

## Function

`snake_case`

```python
recognize_food()
recognize_equipment()
estimate_calories()
```

## Variable

`snake_case`

```python
image_path
prediction_result
estimated_calories
```

## File

`snake_case`

```text
food_recognition.py
equipment_recognition.py
prediction_service.py
```

---

# 26. AI Model Çıktıları

AI model çıktılarında mümkün olduğunca sabit ve backend ile eşleşebilir isimler kullanılmalıdır.

Örnek:

```text
lat_pulldown
leg_press
chest_press
smith_machine
cable_machine
```

Backend tarafında bu değerler bir mapping ile domain kayıtlarına bağlanabilir.

AI çıktısı kullanıcıya doğrudan gösterilecek Türkçe metin olmak zorunda değildir.

---

# 27. Enum İsimlendirme

Enum adı `PascalCase` olmalıdır.

```text
UserRole
AdvisorType
TaskStatus
WorkoutStatus
RecognitionType
Weekday
```

Enum değerleri de `PascalCase` kullanılmalıdır.

```text
User
Trainer
Dietitian
Admin

Pending
Active
Completed
Cancelled
```

`WorkoutDay.Weekday` haftanın gününü `Monday`, `Tuesday`, `Wednesday`, `Thursday`, `Friday`, `Saturday`, `Sunday` string değerleriyle belirtir. `DayNumber` program içi sıra için kalır; bu iki alan aynı anlamda kullanılmaz.

---

# 28. Status İsimlendirme

Aynı kavram için farklı status değerleri oluşturulmamalıdır.

Örneğin task için:

```text
Pending
InProgress
Completed
Cancelled
```

Bir yerde:

```text
Done
```

başka yerde:

```text
Finished
```

kullanılmamalıdır.

---

# 29. Dosya ve Klasör İsimlendirme

Ana proje klasörleri:

```text
backend
mobile
web
ai
docs
```

Klasör isimleri kısa ve açık olmalıdır.

Gereksiz kısaltmalardan kaçınılmalıdır.

Yanlış:

```text
bk
mob
wrk
nr
```

---

# 30. Environment Variable İsimlendirme

Environment variable isimleri:

`UPPER_SNAKE_CASE`

Örnek:

```text
DATABASE_CONNECTION_STRING
JWT_SECRET
JWT_ISSUER
JWT_AUDIENCE
AI_SERVICE_BASE_URL
```

Secret değerler repository'ye commit edilmemelidir.

---

# 31. Git Branch İsimlendirme

Format:

```text
type/short-description
```

Örnek:

```text
feature/auth-api
feature/workout-api
feature/mobile-workout
feature/web-trainer-dashboard
feature/ai-food
feature/ai-equipment
feature/running-tracking

fix/login-validation
fix/workout-response

docs/api-contract
docs/data-dictionary

refactor/workout-service
```

---

# 32. Commit Mesajları

Commit mesajları kısa ve açıklayıcı olmalıdır.

Önerilen format:

```text
type: kısa açıklama
```

Örnek:

```text
feat: add workout plan endpoints
feat: add trainer dashboard
fix: correct refresh token validation
docs: update API contract
refactor: simplify nutrition service
test: add workout service tests
```

---

# 33. Kısaltmalar

Gereksiz kısaltmalardan kaçınılmalıdır.

Doğru:

```text
WorkoutPlan
NutritionRecord
RunningActivity
```

Yanlış:

```text
WPlan
NutrRec
RunAct
```

Yaygın ve açık teknik kısaltmalar kullanılabilir:

```text
API
DTO
JWT
AI
GPS
URL
HTTP
```

---

# 34. ID Kullanımı

Projede ID alanlarında tek bir standart kullanılmalıdır.

Önerilen yaklaşım:

```text
Guid
```

C#:

```csharp
public Guid Id { get; set; }
```

Foreign key:

```csharp
public Guid UserId { get; set; }
```

Proje başında farklı bir karar alınırsa tüm sistem buna göre güncellenmelidir.

Aynı projede bazı entitylerde `int`, bazılarında `Guid` kullanılmamalıdır.

---

# 35. Null Kullanımı

Bir alan gerçekten opsiyonelse nullable yapılmalıdır.

Örnek:

```csharp
public DateTime? CompletedAt { get; set; }
```

Zorunlu alanlar gereksiz yere nullable yapılmamalıdır.

---

# 36. User / Client / Member Kullanımı

Normal uygulama kullanıcısı için ana teknik kavram:

```text
User
```

Trainer ve diyetisyen ekranlarında kullanıcıya UI seviyesinde:

```text
Client / Danışan
```

denebilir.

Ancak backend domain modelinde aynı kişiyi temsil eden ayrı `Client` entity oluşturulmamalıdır.

Temel entity:

```text
User
```

olmalıdır.

---

# 37. Trainer / Coach Kullanımı

Teknik domain adı:

```text
Trainer
```

UI tarafında Türkçe karşılık:

```text
Koç
Eğitmen
```

kullanılabilir.

Backend içerisinde aynı rol için hem `Trainer` hem `Coach` kullanılmamalıdır.

Standart:

```text
Trainer
```

---

# 38. Dietitian Kullanımı

Teknik isim:

```text
Dietitian
```

Aşağıdaki alternatifler kullanılmamalıdır:

```text
Dietician
Nutritionist
NutritionAdvisor
```

Eğer farklı bir rol gerçekten gerekirse ayrıca tanımlanmalıdır.

---

# 39. Advisor Kullanımı

`Advisor`, trainer ve dietitian rollerini ortak bir kavram altında ifade etmek için kullanılabilir.

```text
Advisor
UserAdvisor
AdvisorProfile
```

`Advisor`, ayrı bir kullanıcı rolü gibi kullanılmamalıdır.

Trainer ve Dietitian esas rollerdir.

---

# 40. AI İsimlendirme

Genel prefix olarak:

```text
AI
```

kullanılabilir.

Örnek:

```text
AIRecognitionLog
AIRecognitionService
AIScreen
```

Belirli modüllerde açık isim tercih edilmelidir:

```text
FoodRecognition
GymEquipmentRecognition
```

---

# 41. Tutarlılık Kontrolü

Yeni bir yapı oluşturulmadan önce şu sorular sorulmalıdır:

1. Bu kavram zaten var mı?
2. Aynı işi yapan başka bir entity/model var mı?
3. `DATA_DICTIONARY.md` içinde tanımlı mı?
4. API'de karşılığı var mı?
5. Veritabanında farklı isimle zaten mevcut mu?
6. Mobil ve web aynı kavramı hangi isimle kullanıyor?

Eğer bir isim değiştirilecekse:

- backend
- mobile
- web
- database
- API contract
- data dictionary
- tests
- documentation

etkileri birlikte değerlendirilmelidir.

---

# 42. Codex İçin Zorunlu Kural

Codex yeni:

- entity
- model
- DTO
- table
- column
- endpoint
- service
- enum
- role

oluşturmadan önce mevcut isimleri kontrol etmelidir.

Mevcut kavrama alternatif isim oluşturmamalıdır.

İsimlendirme konusunda belirsizlik varsa otomatik olarak yeni isim üretmek yerine mevcut dokümantasyondaki terminoloji tercih edilmelidir.

---

# 43. Kısa Referans

```text
C# Class                 PascalCase
C# Method                PascalCase
C# Property              PascalCase
C# Variable              camelCase
C# Private Field         _camelCase

PostgreSQL Table         snake_case + plural
PostgreSQL Column        snake_case

API Route                kebab-case + plural
JSON Field               camelCase

Flutter Class            PascalCase
Flutter Variable         camelCase
Flutter File             snake_case

React Component          PascalCase
TypeScript Variable      camelCase
TypeScript Type          PascalCase

Python Class             PascalCase
Python Function          snake_case
Python Variable          snake_case
Python File              snake_case

Environment Variable     UPPER_SNAKE_CASE

Git Branch               type/short-description
```

---

# 44. Ana Domain Terimleri

Proje boyunca temel teknik isimler:

```text
User
Trainer
Dietitian
Advisor
UserAdvisor

Exercise
MuscleGroup

WorkoutPlan
WorkoutDay
WorkoutExercise
WorkoutSession
WorkoutLog

WeightRecord
BodyMeasurement

NutritionRecord
NutritionGoal

RunningActivity
ActivityRecord
HealthDataRecord

GymEquipment
EquipmentExercise

FoodRecognition
FoodRecognitionLog
AIRecognitionLog

AdvisorNote
UserTask
```

Bu terimler, `DATA_DICTIONARY.md` hazırlanırken ayrıntılı olarak tanımlanacaktır.
