# API_CONTRACT.md

# Yapay Zekâ Destekli Sağlık ve Fitness Platformu
## API Sözleşmesi

Bu doküman mobil uygulama, web uygulaması ve ASP.NET Core backend arasındaki REST API sözleşmesini tanımlar.

Amaç:

- Flutter ve React taraflarının aynı endpoint ve veri yapılarını kullanmasını sağlamak
- Backend tamamlanmadan önce frontend geliştirmesinin mock veriyle ilerleyebilmesini sağlamak
- Codex'in yeni endpoint, DTO veya alan ismi üretirken mevcut sözleşmeyi kontrol etmesini sağlamak
- API değişikliklerinin sessizce yapılmasını engellemek
- Mert ve Uğur'un aynı veri formatı üzerinden çalışmasını sağlamak

Bu dosya aşağıdaki dokümanlarla birlikte değerlendirilmelidir:

- `AGENTS.md`
- `docs/PROJECT_CONTEXT.md`
- `docs/NAMING_CONVENTIONS.md`
- `docs/DATA_DICTIONARY.md`
- `docs/UI_FLOW.md`

---

# 1. Genel API Kuralları

Base path:

```text
/api
```

Örnek:

```text
/api/auth/login
/api/users/me
/api/workout-plans
```

API:

- REST yaklaşımını kullanır.
- JSON request/response kullanır.
- Dosya yükleme gereken endpointlerde `multipart/form-data` kullanılır.
- JSON alanları `camelCase` olmalıdır.
- Route isimleri küçük harf ve `kebab-case` olmalıdır.
- Kaynak isimleri mümkün olduğunca çoğul kullanılmalıdır.
- ID tipi varsayılan olarak UUID / Guid kabul edilir.
- Tarihler ISO 8601 formatında gönderilir.
- Backend tarihleri UTC olarak saklamalıdır.
- Mobil ve web uygulamaları PostgreSQL'e doğrudan bağlanmaz.

---

# 2. Authentication

Protected endpointlerde:

```http
Authorization: Bearer <accessToken>
```

header'ı kullanılmalıdır.

Authentication yapısı:

- JWT Access Token
- Refresh Token

Ana roller:

```text
User
Trainer
Dietitian
Admin
```

Authorization yalnızca frontend üzerinde yapılmamalıdır. Backend her protected endpoint için rol ve sahiplik kontrolü yapmalıdır.
`Assigned Trainer` ve `Assigned Dietitian`, ilgili `UserAdvisor` ilişkisinin `Active` olmasını gerektirir. V1'de Admin yetkisi kullanıcı/rol, danışman ataması, egzersiz ve `GymEquipment` yönetimiyle sınırlıdır.

---

# 3. Ortak Veri Formatları

## 3.1 ID

```json
{
  "id": "baf24bf9-23e8-4b2d-9740-15ef18c3ab11"
}
```

ID değerleri string olarak taşınan UUID değerleridir.

---

## 3.2 Tarih / Saat

```json
{
  "createdAt": "2026-10-15T12:30:00Z"
}
```

Tarih/saat:

```text
ISO 8601
UTC
```

formatında olmalıdır.

---

## 3.3 Sadece Tarih

```json
{
  "startDate": "2026-10-15"
}
```

---

## 3.4 Enum

Enum değerleri string olarak döndürülmelidir.

```json
{
  "status": "Active"
}
```

Sayısal enum değerleri client'a açılmamalıdır.

---

# 4. Standart Başarı Kodları

```text
200 OK
201 Created
204 No Content
```

---

# 5. Standart Hata Kodları

```text
400 Bad Request
401 Unauthorized
403 Forbidden
404 Not Found
409 Conflict
422 Unprocessable Entity
500 Internal Server Error
```

---

# 6. Standart Hata Formatı

ASP.NET Core `ProblemDetails` yaklaşımı kullanılmalıdır.

Örnek:

```json
{
  "type": "https://example.com/errors/validation",
  "title": "Validation failed",
  "status": 400,
  "detail": "One or more validation errors occurred.",
  "instance": "/api/auth/register",
  "errors": {
    "email": [
      "Email is required."
    ]
  }
}
```

Frontend hata mesajlarını yalnızca HTTP status code üzerinden tahmin etmemeli, response body'sini de dikkate almalıdır.

---

# 7. Sayfalama

Liste endpointlerinde ihtiyaç olduğunda:

```text
page
pageSize
```

query parametreleri kullanılabilir.

Örnek:

```http
GET /api/users?page=1&pageSize=20
```

Response:

```json
{
  "items": [],
  "page": 1,
  "pageSize": 20,
  "totalCount": 0,
  "totalPages": 0
}
```

---

# 8. AUTH ENDPOINTLERİ

## 8.1 Register

```http
POST /api/auth/register
```

Yetki:

```text
Public
```

Request DTO:

```text
RegisterRequest
```

Request:

```json
{
  "firstName": "Mert",
  "lastName": "Şerbet",
  "email": "mert@example.com",
  "password": "StrongPassword123!"
}
```

Response:

```http
201 Created
```

```json
{
  "id": "9a97f2b9-2a82-45bd-b7f9-ae24fb73441d",
  "firstName": "Mert",
  "lastName": "Şerbet",
  "email": "mert@example.com",
  "roles": [
    "User"
  ]
}
```

Not:

Normal kayıt olan kullanıcıya varsayılan olarak `User` rolü verilir.

---

## 8.2 Login

```http
POST /api/auth/login
```

Yetki:

```text
Public
```

Request DTO:

```text
LoginRequest
```

Request:

```json
{
  "email": "mert@example.com",
  "password": "StrongPassword123!"
}
```

Response DTO:

```text
LoginResponse
```

Response:

```json
{
  "accessToken": "jwt-access-token",
  "refreshToken": "refresh-token",
  "expiresAt": "2026-10-15T13:00:00Z",
  "user": {
    "id": "9a97f2b9-2a82-45bd-b7f9-ae24fb73441d",
    "firstName": "Mert",
    "lastName": "Şerbet",
    "email": "mert@example.com",
    "roles": [
      "User"
    ]
  }
}
```

---

## 8.3 Refresh Token

```http
POST /api/auth/refresh
```

Request:

```json
{
  "refreshToken": "refresh-token"
}
```

Response:

```json
{
  "accessToken": "new-jwt-access-token",
  "refreshToken": "new-refresh-token",
  "expiresAt": "2026-10-15T14:00:00Z"
}
```

---

## 8.4 Logout

```http
POST /api/auth/logout
```

Yetki:

```text
Authenticated
```

Request:

```json
{
  "refreshToken": "refresh-token"
}
```

Response:

```http
204 No Content
```

Refresh token geçersiz hale getirilmelidir.

---

# 9. USER / PROFILE ENDPOINTLERİ

## 9.1 Kendi Profilini Getir

```http
GET /api/users/me
```

Yetki:

```text
Authenticated
```

Response:

```json
{
  "id": "9a97f2b9-2a82-45bd-b7f9-ae24fb73441d",
  "firstName": "Mert",
  "lastName": "Şerbet",
  "email": "mert@example.com",
  "phoneNumber": null,
  "birthDate": "2003-08-15",
  "gender": null,
  "heightCm": 180,
  "roles": [
    "User"
  ]
}
```

---

## 9.2 Kendi Profilini Güncelle

```http
PUT /api/users/me
```

Request DTO:

```text
UpdateUserProfileRequest
```

Request:

```json
{
  "firstName": "Mert",
  "lastName": "Şerbet",
  "phoneNumber": "+905xxxxxxxxx",
  "birthDate": "2003-08-15",
  "gender": null,
  "heightCm": 180
}
```

Response:

```http
200 OK
```

---

## 9.3 Kullanıcı Detayı

```http
GET /api/users/{userId}
```

Yetki:

```text
Admin
Assigned Trainer
Assigned Dietitian
```

Trainer/Dietitian yalnızca yetkili olduğu danışanları görüntüleyebilir.

---

# 10. ADMIN USER ENDPOINTLERİ

## 10.1 Kullanıcıları Listele

```http
GET /api/users
```

Yetki:

```text
Admin
```

Opsiyonel query:

```text
page
pageSize
role
search
```

---

## 10.2 Kullanıcı Rollerini Güncelle

```http
PUT /api/users/{userId}/roles
```

Yetki:

```text
Admin
```

Request:

```json
{
  "roles": [
    "Trainer"
  ]
}
```

---

# 11. ADVISOR / USERADVISOR ENDPOINTLERİ

## 11.1 Kendi Danışmanlarını Getir

```http
GET /api/users/me/advisors
```

Yetki:

```text
User
```

V1'de yalnızca `Active` ilişkiler döner; kullanıcı onayı veya davet durumu yoktur.

Response:

```json
[
  {
    "userAdvisorId": "7ec2ad83-3713-49bd-940c-d416589f850f",
    "advisorId": "432d325b-f07d-42df-b175-012657c8be9c",
    "advisorType": "Trainer",
    "firstName": "Ahmet",
    "lastName": "Yılmaz",
    "title": "Personal Trainer",
    "specialization": "Strength Training",
    "status": "Active",
    "startDate": "2026-10-20",
    "endDate": null
  },
  {
    "userAdvisorId": "598b7077-5a66-4533-a683-d38180f12552",
    "advisorId": "65805970-f478-443e-8fa5-c27b68f4ea74",
    "advisorType": "Dietitian",
    "firstName": "Ayşe",
    "lastName": "Demir",
    "title": "Dietitian",
    "specialization": "Sports Nutrition",
    "status": "Active",
    "startDate": "2026-10-20",
    "endDate": null
  }
]
```

---

## 11.2 Trainer'ın Danışanlarını Getir

```http
GET /api/trainers/me/clients
```

Yetki:

```text
Trainer
```

Yalnızca `Active` `UserAdvisor` ilişkileri listelenir.

Response:

```json
[
  {
    "id": "9a97f2b9-2a82-45bd-b7f9-ae24fb73441d",
    "firstName": "Mert",
    "lastName": "Şerbet",
    "relationshipStatus": "Active",
    "startDate": "2026-10-20"
  }
]
```

---

## 11.3 Diyetisyenin Danışanlarını Getir

```http
GET /api/dietitians/me/clients
```

Yetki:

```text
Dietitian
```

Yalnızca `Active` `UserAdvisor` ilişkileri listelenir.

Admin, atama ekranında danışman adaylarını mevcut `GET /api/users?role=Trainer` veya `?role=Dietitian` çağrılarıyla bulur.

## 11.3.1 Admin'in Kullanıcı-Danışman İlişkilerini Getirmesi

```http
GET /api/user-advisors?userId={userId}
```

Yetki: `Admin`. Yanıt, seçilen kullanıcının `Active`, `Ended` ve `Cancelled` ilişkilerini `userAdvisorId`, `advisorId`, `advisorType`, `status`, `startDate` ve `endDate` alanlarıyla listeler. Bu liste Admin'in mevcut atamayı görüp sonlandırması içindir.

Response DTO: `UserAdvisorResponse[]`. Her öğe ayrıca `userId` içerir. `GET /api/users?role=Trainer` ve `?role=Dietitian` ile seçilen danışmanların rolleri backend tarafından doğrulanır.

---

## 11.4 Kullanıcıya Danışman Ata

```http
POST /api/user-advisors
```

Yetki:

```text
Admin
```

Request DTO:

```text
CreateUserAdvisorRequest
```

Response DTO: `UserAdvisorResponse`.

Request:

```json
{
  "userId": "9a97f2b9-2a82-45bd-b7f9-ae24fb73441d",
  "advisorId": "432d325b-f07d-42df-b175-012657c8be9c",
  "advisorType": "Trainer",
  "startDate": "2026-10-20"
}
```

Response:

```http
201 Created
```

```json
{
  "userAdvisorId": "7ec2ad83-3713-49bd-940c-d416589f850f",
  "userId": "9a97f2b9-2a82-45bd-b7f9-ae24fb73441d",
  "advisorId": "432d325b-f07d-42df-b175-012657c8be9c",
  "advisorType": "Trainer",
  "status": "Active",
  "startDate": "2026-10-20",
  "endDate": null
}
```

V1'de atama yalnızca Admin tarafından yapılır ve doğrudan `Active` oluşturulur. `startDate` atama günüdür; gelecekte tarihli davet/planlı aktivasyon V1'de yoktur. Aynı kullanıcı-danışman çifti için ikinci aktif ilişki oluşturulamaz (`409 Conflict`).

---

## 11.5 Danışman İlişkisini Güncelle

```http
PATCH /api/user-advisors/{userAdvisorId}
```

Yetki:

```text
Admin
```

Request:

```json
{
  "status": "Ended",
  "endDate": "2026-12-24"
}
```

V1'de `status` yalnızca `Ended` veya `Cancelled` olabilir. `endDate` zorunludur; `Pending` ve kullanıcı onayı akışı yoktur. Başarı yanıtı `200 OK` ile güncel ilişkiyi döner.

---

# 12. ADVISOR NOTE ENDPOINTLERİ

## 12.1 Kullanıcının Notlarını Getir

Kendi notları:

```http
GET /api/users/me/advisor-notes
```

Belirli danışan:

```http
GET /api/users/{userId}/advisor-notes
```

Yetki:

```text
User: yalnızca kendi notları
Trainer/Dietitian: yalnızca bağlı danışan
```

---

## 12.2 Kullanıcıya Not Ekle

```http
POST /api/users/{userId}/advisor-notes
```

Yetki:

```text
Assigned Trainer
Assigned Dietitian
```

Request:

```json
{
  "title": "Antrenman Notu",
  "content": "Antrenman sonrası 10 dakika esneme yap."
}
```

Response:

```http
201 Created
```

---

# 13. USER TASK ENDPOINTLERİ

## 13.1 Kendi Görevlerini Getir

```http
GET /api/users/me/tasks
```

Opsiyonel query:

```text
status
```

Örnek:

```http
GET /api/users/me/tasks?status=Pending
```

---

## 13.2 Danışanın Görevlerini Getir

```http
GET /api/users/{userId}/tasks
```

Yetki:

```text
Assigned Trainer
Assigned Dietitian
```

---

## 13.3 Görev Ata

```http
POST /api/users/{userId}/tasks
```

Yetki:

```text
Assigned Trainer
Assigned Dietitian
```

Request:

```json
{
  "title": "Öğle öğününü kaydet",
  "description": "Bugünkü öğle öğününü uygulamaya ekle.",
  "dueDate": "2026-11-05"
}
```

Response:

```http
201 Created
```

---

## 13.4 Görev Durumunu Güncelle

```http
PATCH /api/tasks/{taskId}
```

Yetki:

```text
Task Owner User
Task Creator Advisor
```

Request:

```json
{
  "status": "Completed"
}
```

---

# 14. EXERCISE ENDPOINTLERİ

## 14.1 Egzersizleri Listele

```http
GET /api/exercises
```

Yetki:

```text
Authenticated
```

Opsiyonel query:

```text
search
muscleGroupId
```

Response:

```json
[
  {
    "id": "1dd55d43-ee46-4769-94e0-bad9fcf79df1",
    "name": "Bench Press",
    "description": "Chest exercise",
    "videoUrl": null,
    "imageUrl": null
  }
]
```

---

## 14.2 Egzersiz Detayı

```http
GET /api/exercises/{exerciseId}
```

---

## 14.3 Egzersiz Oluştur

```http
POST /api/exercises
```

Yetki:

```text
Admin
```

---

## 14.4 Egzersiz Güncelle

```http
PUT /api/exercises/{exerciseId}
```

Yetki:

```text
Admin
```

---

# 15. WORKOUT PLAN ENDPOINTLERİ

## 15.1 Kullanıcının Kendi Programlarını Getir

```http
GET /api/users/me/workout-plans
```

Yetki:

```text
User
```

Liste, `isActive`, `startDate` ve `endDate` alanlarını taşır. V1'de kullanıcı başına en fazla bir aktif `WorkoutPlan` bulunur; geçerli tarih aralığı dışındaki plan bugünkü antrenman sayılmaz.

---

## 15.2 Danışanın Programlarını Getir

```http
GET /api/users/{userId}/workout-plans
```

Yetki:

```text
Assigned Trainer
```

---

## 15.3 Program Detayı

```http
GET /api/workout-plans/{workoutPlanId}
```

Yetki:

```text
Owner User
Assigned Trainer
```

Response örneği:

```json
{
  "id": "78ddeebe-f4db-427f-9bda-22777ca56585",
  "userId": "9a97f2b9-2a82-45bd-b7f9-ae24fb73441d",
  "trainerId": "432d325b-f07d-42df-b175-012657c8be9c",
  "name": "4 Haftalık Başlangıç Programı",
  "description": "Temel kuvvet programı",
  "startDate": "2026-11-01",
  "endDate": "2026-11-30",
  "isActive": true,
  "days": [
    {
      "id": "27635ace-c211-4cfb-a340-c356701e6e43",
      "name": "Push",
      "dayNumber": 1,
      "weekday": "Monday",
      "exercises": [
        {
          "id": "435d9193-fb1e-493d-bd80-c0f30ce84449",
          "exerciseId": "1dd55d43-ee46-4769-94e0-bad9fcf79df1",
          "exerciseName": "Bench Press",
          "order": 1,
          "sets": 4,
          "reps": 10,
          "restSeconds": 90,
          "weightKg": null,
          "notes": null
        }
      ]
    }
  ]
}
```

---

## 15.4 Program Oluştur ve Danışana Ata

```http
POST /api/users/{userId}/workout-plans
```

Yetki:

```text
Assigned Trainer
```

Trainer ID access token'dan alınmalıdır.

Request DTO:

```text
CreateWorkoutPlanRequest
```

Request:

```json
{
  "name": "4 Haftalık Başlangıç Programı",
  "description": "Temel kuvvet programı",
  "startDate": "2026-11-01",
  "endDate": "2026-11-30",
  "days": [
    {
      "name": "Push",
      "dayNumber": 1,
      "weekday": "Monday",
      "description": null,
      "exercises": [
        {
          "exerciseId": "1dd55d43-ee46-4769-94e0-bad9fcf79df1",
          "order": 1,
          "sets": 4,
          "reps": 10,
          "durationSeconds": null,
          "restSeconds": 90,
          "weightKg": null,
          "notes": null
        }
      ]
    }
  ]
}
```

Response:

```http
201 Created
```

`weekday` zorunludur ve `Monday`–`Sunday` string değerlerinden biridir. `dayNumber` yalnızca program içi sıralamadır. Aynı plandaki iki gün aynı `weekday` değerini alamaz (`400 Bad Request`). V1'de yeni aktif plan önceki aktif planı pasifleştirir. `PUT /api/workout-plans/{workoutPlanId}` aynı gün benzersizliği ve tarih aralığı kuralını korur.

---

## 15.5 Program Güncelle

```http
PUT /api/workout-plans/{workoutPlanId}
```

Yetki:

```text
Creator Trainer
```

---

# 16. WORKOUT SESSION / LOG ENDPOINTLERİ

## 16.1 Antrenman Oturumu Başlat

```http
POST /api/workout-sessions
```

Yetki:

```text
User
```

Request:

```json
{
  "workoutPlanId": "78ddeebe-f4db-427f-9bda-22777ca56585",
  "workoutDayId": "27635ace-c211-4cfb-a340-c356701e6e43"
}
```

Response:

```json
{
  "id": "484e0d66-f5c8-4bd1-9a02-e8412f998a94",
  "status": "InProgress",
  "startedAt": "2026-11-05T16:00:00Z"
}
```

---

## 16.2 Egzersiz Kaydı Ekle / Güncelle

```http
PUT /api/workout-sessions/{sessionId}/exercises/{workoutExerciseId}
```

Request:

```json
{
  "completedSets": 4,
  "completedReps": 10,
  "weightKg": 60,
  "durationSeconds": null,
  "isCompleted": true,
  "notes": null
}
```

---

## 16.3 Antrenmanı Tamamla

```http
POST /api/workout-sessions/{sessionId}/complete
```

Response:

```json
{
  "id": "484e0d66-f5c8-4bd1-9a02-e8412f998a94",
  "status": "Completed",
  "completedAt": "2026-11-05T17:05:00Z"
}
```

---

## 16.4 Antrenman Geçmişi

Kullanıcı:

```http
GET /api/users/me/workout-sessions
```

Trainer:

```http
GET /api/users/{userId}/workout-sessions
```

Trainer yalnızca bağlı danışanın verisini görebilir.

---

# 17. WEIGHT RECORD ENDPOINTLERİ

## 17.1 Kendi Kilo Kayıtlarını Getir

```http
GET /api/users/me/weight-records
```

Response:

```json
[
  {
    "id": "0bec6163-394c-43bd-ac68-478cf84a913e",
    "weightKg": 82.4,
    "recordedAt": "2026-11-01T08:00:00Z"
  }
]
```

---

## 17.2 Kilo Kaydı Ekle

```http
POST /api/users/me/weight-records
```

Request:

```json
{
  "weightKg": 82.4,
  "recordedAt": "2026-11-01T08:00:00Z"
}
```

---

## 17.3 Danışanın Kilo Geçmişini Gör

```http
GET /api/users/{userId}/weight-records
```

Yetki:

```text
Assigned Trainer
Assigned Dietitian
```

---

# 18. BODY MEASUREMENT ENDPOINTLERİ

## 18.1 Kendi Ölçümlerini Getir

```http
GET /api/users/me/body-measurements
```

---

## 18.2 Ölçüm Ekle

```http
POST /api/users/me/body-measurements
```

Request:

```json
{
  "chestCm": 102,
  "waistCm": 88,
  "hipCm": 98,
  "armCm": 36,
  "thighCm": 58,
  "bodyFatPercentage": null,
  "recordedAt": "2026-11-01T08:00:00Z"
}
```

---

## 18.3 Danışanın Ölçümlerini Gör

```http
GET /api/users/{userId}/body-measurements
```

Yetki:

```text
Assigned Trainer
Assigned Dietitian
```

---

# 19. NUTRITION GOAL ENDPOINTLERİ

## 19.1 Kullanıcının Aktif Beslenme Hedefini Getir

```http
GET /api/users/me/nutrition-goals/active
```

Opsiyonel `date=YYYY-MM-DD` query parametresi mobil cihazın yerel takvim tarihidir; mobil V1'de gönderir. Parametre yoksa sunucunun UTC takvim tarihi kullanılır. `IsActive = true` olan tek hedefin tarih aralığı bu tarihi kapsıyorsa döner; aksi halde `404 Not Found` döner. Mobil `Planım` ve günlük beslenme ekranı yalnızca bu endpointteki hedefi kullanır.

Response:

```json
{
  "id": "69116652-f078-4a9f-b30e-3ddc37ac737e",
  "dailyCalories": 2400,
  "proteinGrams": 160,
  "carbohydrateGrams": 270,
  "fatGrams": 75,
  "waterMl": 2500,
  "isActive": true,
  "startDate": "2026-11-01",
  "endDate": "2026-11-30"
}
```

---

## 19.2 Danışanın Hedeflerini Getir

```http
GET /api/users/{userId}/nutrition-goals
```

Yetki:

```text
Assigned Dietitian
```

---

## 19.3 Beslenme Hedefi Oluştur

```http
POST /api/users/{userId}/nutrition-goals
```

Yetki:

```text
Assigned Dietitian
```

Dietitian ID token'dan alınmalıdır.

Request:

```json
{
  "dailyCalories": 2400,
  "proteinGrams": 160,
  "carbohydrateGrams": 270,
  "fatGrams": 75,
  "waterMl": 2500,
  "startDate": "2026-11-01",
  "endDate": "2026-11-30"
}
```

Başarı: `201 Created`; yanıt oluşturulan `NutritionGoal` kaydını 19.1'deki alanlarla ve `isActive: true` değeriyle döner. V1'de yeni hedef doğrudan aktif oluşturulur; aynı kullanıcının önceki aktif `NutritionGoal` kaydı aynı veritabanı işleminde pasifleştirilir. Kullanıcı başına en fazla bir aktif hedef vardır. `startDate`/`endDate` geçerlilik aralığı dışında mobilde günlük hedef gösterilmez; eski hedef otomatik olarak yeniden etkinleşmez.

---

# 20. NUTRITION RECORD ENDPOINTLERİ

## 20.1 Kendi Beslenme Kayıtlarını Getir

```http
GET /api/users/me/nutrition-records
```

Opsiyonel query:

```text
date
from
to
mealType
```

Örnek:

```http
GET /api/users/me/nutrition-records?date=2026-11-05
```

---

## 20.2 Manuel Beslenme Kaydı Ekle

```http
POST /api/users/me/nutrition-records
```

Request:

```json
{
  "mealType": "Lunch",
  "name": "Tavuk ve Pilav",
  "calories": 650,
  "proteinGrams": 48,
  "carbohydrateGrams": 72,
  "fatGrams": 16,
  "portionDescription": "1 porsiyon",
  "sourceType": "Manual",
  "foodRecognitionLogId": null,
  "consumedAt": "2026-11-05T12:30:00Z"
}
```

---

## 20.3 AI Sonucunu Beslenme Kaydı Olarak Kaydet

Aynı endpoint kullanılır:

```http
POST /api/users/me/nutrition-records
```

Request:

```json
{
  "mealType": "Lunch",
  "name": "Tavuk, Pilav ve Salata",
  "calories": 650,
  "proteinGrams": 48,
  "carbohydrateGrams": 72,
  "fatGrams": 16,
  "portionDescription": "AI tahmini - kullanıcı tarafından kontrol edildi",
  "sourceType": "AI",
  "foodRecognitionLogId": "d5408855-9398-460d-a6dc-b15c65d9a29e",
  "consumedAt": "2026-11-05T12:30:00Z"
}
```

Kullanıcı analiz sonucunu onaylamadan `NutritionRecord` oluşturulmaz. `foodRecognitionLogId`, ham `FoodRecognitionLog` kaydını gösterir; kullanıcı düzeltmeleri yalnızca `NutritionRecord` alanlarına yazılır. AI yanıtındaki çoklu `items` tek öğün kaydına dönüştürülür; `name` ve toplam değerler kullanıcı tarafından son kez onaylanır.

---

## 20.4 Diyetisyenin Danışan Beslenme Kayıtlarını Görmesi

```http
GET /api/users/{userId}/nutrition-records
```

Yetki:

```text
Assigned Dietitian
```

---

# 21. RUNNING ACTIVITY ENDPOINTLERİ

İlk sürümde GPS takibi mobilde yapılabilir ve tamamlanan aktivite backend'e gönderilebilir.

## 21.1 Koşu Kaydı Oluştur

```http
POST /api/users/me/running-activities
```

Request:

```json
{
  "startedAt": "2026-11-05T06:00:00Z",
  "endedAt": "2026-11-05T06:31:42Z",
  "durationSeconds": 1902,
  "distanceMeters": 5240,
  "averagePaceSecondsPerKm": 363,
  "averageSpeedKmh": 9.92,
  "estimatedCalories": 410,
  "routeData": {
    "type": "polyline",
    "value": "encoded-polyline-data"
  }
}
```

Not:

`routeData` formatı Flutter harita/GPS implementasyonu kesinleştiğinde netleştirilebilir.

---

## 21.2 Koşu Geçmişini Getir

```http
GET /api/users/me/running-activities
```

---

## 21.3 Koşu Detayı

```http
GET /api/running-activities/{runningActivityId}
```

---

## 21.4 Danışanın Koşu Geçmişini Gör

```http
GET /api/users/{userId}/running-activities
```

Yetki:

```text
Assigned Trainer
```

Diyetisyen erişimi gerekiyorsa ilişki yetkileri üzerinden ayrıca açılabilir.

---

# 22. ACTIVITY RECORD ENDPOINTLERİ

Health Connect/HealthKit → Flutter (kullanıcı izniyle okuma) → ASP.NET Core API → PostgreSQL. Sağlık platformu ve akıllı cihaz backend'e doğrudan bağlanmaz.

## 22.1 Günlük Aktivite Özeti

```http
GET /api/users/me/activity-records
```

Opsiyonel query:

```text
date
from
to
```

---

## 22.2 Aktivite Kaydı Senkronize Et

```http
POST /api/users/me/activity-records
```

Request:

```json
{
  "date": "2026-11-05",
  "stepCount": 8400,
  "activeCalories": 520,
  "distanceMeters": 6800,
  "activeMinutes": 72,
  "sourceType": "HealthConnect"
}
```

---

# 23. HEALTH DATA ENDPOINTLERİ

Health Connect / HealthKit verilerinin toplu senkronizasyonu için:
Flutter cihazdaki kullanıcı iznini kontrol eder ve okuduğu veriyi bu API'ye gönderir; backend yalnızca kimliği doğrulanmış kullanıcının kayıtlarını saklar.

## 23.1 Sağlık Verilerini Toplu Gönder

```http
POST /api/users/me/health-data-records/batch
```

Request:

```json
{
  "records": [
    {
      "dataType": "HeartRate",
      "value": 78,
      "unit": "bpm",
      "source": "HealthConnect",
      "recordedAt": "2026-11-05T10:15:00Z"
    },
    {
      "dataType": "StepCount",
      "value": 1200,
      "unit": "count",
      "source": "HealthConnect",
      "recordedAt": "2026-11-05T10:30:00Z"
    }
  ]
}
```

Response:

```json
{
  "acceptedCount": 2
}
```

---

## 23.2 Sağlık Verilerini Getir

```http
GET /api/users/me/health-data-records
```

Opsiyonel query:

```text
dataType
from
to
```

---

# 24. GYM EQUIPMENT ENDPOINTLERİ

## 24.1 Ekipmanları Listele

```http
GET /api/gym-equipments
```

---

## 24.2 Ekipman Detayı

```http
GET /api/gym-equipments/{gymEquipmentId}
```

Response:

```json
{
  "id": "eae3fa0f-84dc-48fb-99f7-1a38ea1aff37",
  "name": "Lat Pulldown",
  "modelKey": "lat_pulldown",
  "description": "Back training equipment",
  "imageUrl": null,
  "isActive": true,
  "exercises": [
    {
      "id": "50d0d5fd-f734-423f-be54-d14ce95d0176",
      "name": "Wide Grip Lat Pulldown"
    }
  ]
}
```

---

## 24.3 Ekipman Oluştur

```http
POST /api/gym-equipments
```

Yetki:

```text
Admin
```

Request DTO: `CreateGymEquipmentRequest`.

```json
{
  "name": "Lat Pulldown",
  "modelKey": "lat_pulldown",
  "description": "Back training equipment",
  "imageUrl": null,
  "isActive": true,
  "exerciseIds": ["50d0d5fd-f734-423f-be54-d14ce95d0176"]
}
```

`exerciseIds`, var olan `Exercise` kayıtlarına kurulan `EquipmentExercise` eşleştirmelerini belirler. Başarı: `201 Created`, yanıt `GymEquipmentResponse` (24.2'deki detay yapısı).

## 24.4 Ekipman Güncelle

```http
PUT /api/gym-equipments/{gymEquipmentId}
```

Yetki: `Admin`. Request DTO: `UpdateGymEquipmentRequest`; 24.3'teki alanları ve `exerciseIds` listesini taşır. Var olan `GymEquipment` kaydını ve `EquipmentExercise` eşleştirmelerini günceller. `modelKey` AI tahminiyle eşleştiği için diğer kayıtlarla çakışamaz (`409 Conflict`). Başarı: `200 OK`, yanıt `GymEquipmentResponse` (24.2'deki detay yapısı).

---

# 25. AI — GYM EQUIPMENT RECOGNITION

## 25.1 Spor Ekipmanı Tanı

```http
POST /api/ai/gym-equipment/recognize
```

Yetki:

```text
User
```

Content-Type:

```text
multipart/form-data
```

Form field:

```text
image
```

Desteklenen temel formatlar:

```text
jpg
jpeg
png
webp
```

Response:

```json
{
  "recognitionLogId": "e432133b-66bf-4673-b366-d88301697f75",
  "equipment": {
    "id": "eae3fa0f-84dc-48fb-99f7-1a38ea1aff37",
    "name": "Lat Pulldown",
    "modelKey": "lat_pulldown"
  },
  "confidence": 0.94,
  "exercises": [
    {
      "id": "50d0d5fd-f734-423f-be54-d14ce95d0176",
      "name": "Wide Grip Lat Pulldown"
    },
    {
      "id": "73ec967f-bf4e-480c-a583-444978d36de9",
      "name": "Close Grip Lat Pulldown"
    }
  ]
}
```

Önemli:

AI servisi yalnızca tahmin üretir.

Görüntü önce Flutter'dan ASP.NET Core API'ye gider; backend FastAPI model sonucunu `GymEquipment.ModelKey` ile eşleştirir ve `EquipmentExercise` kayıtlarından egzersizleri ekleyerek Flutter'a döner. Flutter FastAPI'ye doğrudan bağlanmaz.

```text
Lat Pulldown
```

ile hangi egzersizlerin yapılacağı eşleştirmesi backend/database tarafından yapılır.

---

# 26. AI — FOOD RECOGNITION

## 26.1 Yemek Fotoğrafını Analiz Et

```http
POST /api/ai/food/recognize
```

Yetki:

```text
User
```

Content-Type:

```text
multipart/form-data
```

Form field:

```text
image
```

Response:

```json
{
  "recognitionLogId": "d5408855-9398-460d-a6dc-b15c65d9a29e",
  "items": [
    {
      "name": "Chicken Breast",
      "estimatedPortion": "150 g",
      "estimatedCalories": 250,
      "estimatedProteinGrams": 46,
      "estimatedCarbohydrateGrams": 0,
      "estimatedFatGrams": 5,
      "confidence": 0.91
    },
    {
      "name": "Rice",
      "estimatedPortion": "200 g",
      "estimatedCalories": 320,
      "estimatedProteinGrams": 6,
      "estimatedCarbohydrateGrams": 68,
      "estimatedFatGrams": 2,
      "confidence": 0.88
    }
  ],
  "totals": {
    "estimatedCalories": 570,
    "estimatedProteinGrams": 52,
    "estimatedCarbohydrateGrams": 68,
    "estimatedFatGrams": 7
  }
}
```

Önemli:

- Bu sonuçlar tahminidir.
- Kullanıcı sonucu kaydetmeden önce düzenleyebilmelidir.
- Düzeltilen sonuç daha sonra `NutritionRecord` olarak kaydedilir.
- AI çıktısı tıbbi veya klinik doğruluk iddiası taşımaz.
- Görüntü Flutter → ASP.NET Core API → Python FastAPI → AI Model yolunu izler; tahmin backend üzerinden Flutter'a döner. Flutter FastAPI'ye doğrudan bağlanmaz.
- `FoodRecognitionLog.DetectedItems`, `items` listesini; logun `EstimatedCalories` ve makro alanları `totals` değerlerini temsil eder. Kullanıcı düzeltmesi ham logu değiştirmez.

---

# 27. MOBİL ANA SAYFA ENDPOINTİ

Mobil ana sayfa için client'ın çok sayıda endpoint çağırmasını azaltmak amacıyla bir özet endpoint kullanılabilir.

```http
GET /api/users/me/dashboard
```

Opsiyonel `date=YYYY-MM-DD` query parametresi, mobil cihazın yerel takvim tarihini belirtir. Mobil V1'de bu parametreyi gönderir; parametre yoksa sunucunun UTC takvim tarihi kullanılır. `todayWorkout`, o tarihte aktif ve tarih aralığı geçerli olan tek `WorkoutPlan` içindeki `Weekday` eşleşmesinden hesaplanır. Eşleşme yoksa `todayWorkout: null` döner. Aynı tarih için `nutrition` hedefi de yalnızca geçerli aktif `NutritionGoal` üzerinden hesaplanır; hedef yoksa hedef alanları `null` olur.

Yetki:

```text
User
```

Örnek response:

```json
{
  "todayWorkout": {
    "workoutPlanId": "78ddeebe-f4db-427f-9bda-22777ca56585",
    "workoutDayId": "27635ace-c211-4cfb-a340-c356701e6e43",
    "name": "Push Day",
    "isCompleted": false
  },
  "nutrition": {
    "calorieGoal": 2400,
    "consumedCalories": 1320,
    "proteinGoal": 160,
    "consumedProtein": 85
  },
  "activity": {
    "stepCount": 6400,
    "activeCalories": 410
  },
  "latestWeight": {
    "weightKg": 82.4,
    "recordedAt": "2026-11-01T08:00:00Z"
  },
  "pendingTasks": 2,
  "advisorNotes": 1
}
```

Bu endpoint sadece özet bilgi sunar. Ana verilerin kaynağı ilgili domain endpointleridir.

---

# 28. PLANIM ENDPOINT YAKLAŞIMI

`Planım` ayrı bir database entity değildir.

Mobil uygulama gerekli verileri:

```text
WorkoutPlan
NutritionGoal
UserTask
AdvisorNote
```

kaynaklarından alır.

İlk sürümde mobil ayrı endpointleri çağırabilir.

İleride ihtiyaç duyulursa toplu endpoint:

```http
GET /api/users/me/my-plan
```

eklenebilir.

Örnek response:

```json
{
  "activeWorkoutPlan": {},
  "activeNutritionGoal": {},
  "tasks": [],
  "advisorNotes": []
}
```

Bu endpoint performans/UX ihtiyacı oluşmadan zorunlu değildir.

---

# 29. REHBERİM ENDPOINT YAKLAŞIMI

Mobil `Rehberim` ekranının temel endpointi:

```http
GET /api/users/me/advisors
```

Ayrı `MyAdvisor` entity oluşturulmamalıdır.

---

# 30. TRACKING ENDPOINT YAKLAŞIMI

Mobil `Takip` ekranı aşağıdaki kaynaklardan veri kullanır:

```text
/api/users/me/weight-records
/api/users/me/body-measurements
/api/users/me/nutrition-records
/api/users/me/running-activities
/api/users/me/activity-records
/api/users/me/health-data-records
```

İleride dashboard/aggregation endpointleri eklenebilir ancak temel domain endpointleri korunmalıdır.

---

# 31. DOSYA YÜKLEME KURALLARI

AI görüntü endpointleri başlangıçta şu formatları kabul etmelidir:

```text
image/jpeg
image/png
image/webp
```

Dosya boyutu için başlangıç sınırı:

```text
10 MB
```

olarak düşünülebilir.

Nihai limit backend configuration üzerinden değiştirilebilir.

Geçersiz dosya tipi:

```http
400 Bad Request
```

veya uygun validation response ile dönmelidir.

---

# 32. AUTHORIZATION MATRİSİ

| Kaynak / İşlem | User | Trainer | Dietitian | Admin |
|---|---|---|---|---|
| Kendi profilini görme | ✓ | ✓ | ✓ | ✓ |
| Kendi profilini güncelleme | ✓ | ✓ | ✓ | ✓ |
| Kendi danışmanlarını görme | ✓ | - | - | - |
| Danışan listesini görme | - | ✓ | ✓ | - |
| UserAdvisor oluşturma | - | - | - | ✓ |
| UserAdvisor listeleme/sonlandırma | - | - | - | ✓ |
| Kullanıcıları görme / rollerini yönetme | - | - | - | ✓ |
| WorkoutPlan oluşturma | - | ✓ | - | - |
| Kendi WorkoutPlan'ını görme | ✓ | - | - | - |
| Danışan WorkoutPlan'ını görme | - | ✓ | - | - |
| NutritionGoal oluşturma | - | - | ✓ | - |
| Kendi NutritionGoal'ını görme | ✓ | - | - | - |
| NutritionRecord oluşturma | ✓ | - | - | - |
| Danışan NutritionRecord görme | - | - | ✓ | - |
| WeightRecord oluşturma | ✓ | - | - | - |
| Danışan WeightRecord görme | - | ✓ | ✓ | - |
| UserTask oluşturma | - | ✓ | ✓ | - |
| Kendi task'ını tamamlama | ✓ | - | - | - |
| RunningActivity oluşturma | ✓ | - | - | - |
| Danışan RunningActivity görme | - | ✓ | - | - |
| Egzersiz kataloğunu yönetme | - | - | - | ✓ |
| GymEquipment kataloğunu yönetme | - | - | - | ✓ |
| Food Recognition | ✓ | - | - | - |
| Equipment Recognition | ✓ | - | - | - |

Not:

Trainer/Dietitian için danışan okuma ve yazma yetkileri yalnızca `Active` `UserAdvisor` ilişkisiyle geçerlidir. V1'de ilişkiye ek permission alanları kullanılmaz; Admin'in kişisel sağlık/veri ekranlarına erişimi bu yönetim kapsamına dahil değildir.

---

# 33. VALIDATION TEMEL KURALLARI

Örnek validationlar:

```text
Email → valid email
Password → minimum güvenlik kuralı
WeightKg → > 0
HeightCm → > 0
Calories → >= 0
ProteinGrams → >= 0
CarbohydrateGrams → >= 0
FatGrams → >= 0
DistanceMeters → >= 0
DurationSeconds → >= 0
Confidence → 0 ile 1 arasında
```

Backend validation zorunludur.

Frontend validation kullanıcı deneyimi içindir ancak backend validation'ın yerine geçmez.

---

# 34. RESPONSE İÇİN NULL KURALI

Opsiyonel alanlar gerektiğinde `null` olabilir.

Örnek:

```json
{
  "endDate": null,
  "phoneNumber": null
}
```

Client'lar opsiyonel alanların her zaman dolu olduğunu varsaymamalıdır.

---

# 35. API DEĞİŞİKLİK KURALI

Aşağıdakiler API contract değişikliği olarak kabul edilir:

- Endpoint route değiştirme
- Request field ekleme/kaldırma
- Zorunlu field değiştirme
- Response field kaldırma
- Field adı değiştirme
- Enum değeri değiştirme
- Authorization kuralı değiştirme
- Veri tipi değiştirme

Bu değişiklikler yapılmadan önce:

1. Mobile etkisi kontrol edilir.
2. Web etkisi kontrol edilir.
3. Backend etkisi kontrol edilir.
4. `API_CONTRACT.md` güncellenir.
5. Gerekirse `DATA_DICTIONARY.md` güncellenir.

Sessiz contract değişikliği yapılmamalıdır.

---

# 36. FRONTEND MOCK KULLANIMI

Backend endpoint henüz tamamlanmadıysa Flutter veya React tarafı bu dokümandaki response formatını mock veri olarak kullanabilir.

Örnek:

```json
{
  "id": "78ddeebe-f4db-427f-9bda-22777ca56585",
  "name": "Push Day"
}
```

Backend tamamlandığında frontend modeli yeniden tasarlamak yerine gerçek API'ye bağlanmalıdır.

Bu nedenle request/response formatı geliştirme başlamadan önce mümkün olduğunca kararlaştırılmalıdır.

---

# 37. CODEX İÇİN ZORUNLU KURAL

Codex yeni endpoint oluşturmadan önce:

1. Bu dosyada benzer endpoint olup olmadığını kontrol et.
2. `DATA_DICTIONARY.md` domain isimlerini kullan.
3. `NAMING_CONVENTIONS.md` route ve JSON kurallarına uy.
4. Var olan request/response formatını gereksiz yere değiştirme.
5. Yeni field gerekiyorsa client etkisini belirt.
6. Database değişikliği gerekiyorsa ayrıca belirt.
7. Authorization kontrolünü backend'de uygula.
8. API contract değiştiyse bu dosyayı güncelle.
9. Frontend ile uyumsuz sessiz değişiklik yapma.
10. Gereksiz endpoint çoğaltma.

---

# 38. V1 ENDPOINT ÖZETİ

## Auth

```text
POST   /api/auth/register
POST   /api/auth/login
POST   /api/auth/refresh
POST   /api/auth/logout
```

## Users

```text
GET    /api/users/me
PUT    /api/users/me
GET    /api/users/{userId}
GET    /api/users
PUT    /api/users/{userId}/roles
GET    /api/users/me/dashboard
```

## Advisors

```text
GET    /api/users/me/advisors
GET    /api/trainers/me/clients
GET    /api/dietitians/me/clients
GET    /api/user-advisors?userId={userId}
POST   /api/user-advisors
PATCH  /api/user-advisors/{userAdvisorId}
```

## Notes

```text
GET    /api/users/me/advisor-notes
GET    /api/users/{userId}/advisor-notes
POST   /api/users/{userId}/advisor-notes
```

## Tasks

```text
GET    /api/users/me/tasks
GET    /api/users/{userId}/tasks
POST   /api/users/{userId}/tasks
PATCH  /api/tasks/{taskId}
```

## Exercises

```text
GET    /api/exercises
GET    /api/exercises/{exerciseId}
POST   /api/exercises
PUT    /api/exercises/{exerciseId}
```

## Workout

```text
GET    /api/users/me/workout-plans
GET    /api/users/{userId}/workout-plans
GET    /api/workout-plans/{workoutPlanId}
POST   /api/users/{userId}/workout-plans
PUT    /api/workout-plans/{workoutPlanId}

POST   /api/workout-sessions
PUT    /api/workout-sessions/{sessionId}/exercises/{workoutExerciseId}
POST   /api/workout-sessions/{sessionId}/complete
GET    /api/users/me/workout-sessions
GET    /api/users/{userId}/workout-sessions
```

## Weight

```text
GET    /api/users/me/weight-records
POST   /api/users/me/weight-records
GET    /api/users/{userId}/weight-records
```

## Body Measurements

```text
GET    /api/users/me/body-measurements
POST   /api/users/me/body-measurements
GET    /api/users/{userId}/body-measurements
```

## Nutrition

```text
GET    /api/users/me/nutrition-goals/active
GET    /api/users/{userId}/nutrition-goals
POST   /api/users/{userId}/nutrition-goals

GET    /api/users/me/nutrition-records
POST   /api/users/me/nutrition-records
GET    /api/users/{userId}/nutrition-records
```

## Running

```text
POST   /api/users/me/running-activities
GET    /api/users/me/running-activities
GET    /api/running-activities/{runningActivityId}
GET    /api/users/{userId}/running-activities
```

## Activity / Health

```text
GET    /api/users/me/activity-records
POST   /api/users/me/activity-records
POST   /api/users/me/health-data-records/batch
GET    /api/users/me/health-data-records
```

## Gym Equipment

```text
GET    /api/gym-equipments
GET    /api/gym-equipments/{gymEquipmentId}
POST   /api/gym-equipments
PUT    /api/gym-equipments/{gymEquipmentId}
```

## AI

```text
POST   /api/ai/gym-equipment/recognize
POST   /api/ai/food/recognize
```

---

# 39. Son Not

Bu doküman projenin **V1 API sözleşmesidir**.

Kodlama sırasında küçük teknik değişiklikler gerekebilir. Ancak endpoint, request, response veya domain isimlerinde değişiklik yapılacaksa bu dosya güncellenmeli ve mobile/web tarafı ile koordineli ilerlenmelidir.

Amaç tüm endpointleri ilk günden eksiksiz yazmak değil; her geliştiricinin ve Codex'in sistemin nasıl haberleşeceğini aynı şekilde anlamasını sağlamaktır.
