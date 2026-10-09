# Yapay Zekâ Destekli Sağlık ve Fitness Platformu — Web UI Spesifikasyonu

Bu belge React web panelinin V1 ekran düzenini tarif eder. Ekranlar ve rol erişimi `UI_FLOW.md`, veri adları `DATA_DICTIONARY.md`, istekler `API_CONTRACT.md` ile uyumludur. Web paneli `Trainer`, `Dietitian`, `Admin` içindir; normal `User` günlük işlemlerini mobilde yapar. Yeni özellik, tablo veya endpoint varsayılmaz.

## 1. Ortak yerleşim

```text
┌──────────────────────────────────────────────────────────────┐
│ Sol sidebar   │ Üst header: sayfa adı · danışan bağlamı · profil │
│              ├──────────────────────────────────────────────┤
│ Dashboard    │ Kısa özet kartları / filtreler                 │
│ Danışanlar   │                                              │
│ ...          │ Tablo, form veya grafik ana içerik alanı       │
│ Profil       │                                              │
└──────────────────────────────────────────────────────────────┘
```

- Sol sidebar role göre yalnızca erişilebilir alanları gösterir. Aktif sayfa mavi vurgu ve açık metinle belirtilir. Logo/ürün adı üstte, Profil/Çıkış altta olabilir.
- Üst header sayfa başlığını, danışan ayrıntısındaysa seçili danışan adını, sağda hesap menüsünü gösterir. “Geri” bağlantısı listeye döner.
- Dashboard kısa kartlardan oluşur; ayrıntılı rapor veya tüm kayıtlar burada yığılmaz. Tablolarda arama/filtre yalnızca API'nin desteklediği alanlarla sınırlıdır.
- Masaüstünde sidebar + geniş içerik; orta genişlikte daraltılabilir sidebar; dar ekranda açılır menü ve tek sütun kart/form. Tabloların kritik kolonları kalır, diğer bilgiler satır ayrıntısına taşınır. Formlar dar ekranda tek sütundur.
- `UI_DESIGN_GUIDE.md` içindeki renk rolleri paylaşılır; webde veri okunabilirliği ve karşılaştırma mobildeki görsel yoğunluktan daha önemlidir. Kart, tablo, form ve grafik başlıkları tutarlı olmalıdır.
- Liste ve detayda boş, yükleniyor ve hata durumları ayrı tasarlanır. Form hatası ilgili alanın altında, API hatası kısa mesaj ve tekrar deneme yolu ile gösterilir. Kaydetme başarısı API yanıtından sonra görünür.

## 2. Rol menüleri

| Rol | Sidebar / görünür alanlar | Yetki sınırı |
|---|---|---|
| `Trainer` | Dashboard, Danışanlar, Antrenman Programları, Egzersizler (okuma/seçim), Görevler / Notlar, Profil | Yalnız `Active` `UserAdvisor` ilişkisi olan danışanlara program, görev ve not atar; egzersiz kataloğunu düzenlemez. |
| `Dietitian` | Dashboard, Danışanlar, Beslenme Hedefleri, Görevler / Notlar, Profil | Yalnız bağlı danışanların izinli beslenme/kilo/ölçüm verilerini görür; hedef, görev ve not atar. |
| `Admin` | Dashboard (sade giriş), Kullanıcılar, Danışman Atamaları, Egzersizler, Ekipmanlar, Roller, Profil | Kullanıcıları görüntüler; rol, `UserAdvisor`, `Exercise`, `GymEquipment` yönetir. Kişisel sağlık/koşu/beslenme raporlarına V1 erişimi yoktur. |

**Raporlar:** İstekteki Dietitian “Raporlar” ihtiyacı V1'de **Danışan Detayı > İlerleme** alanında beslenme, kilo ve ölçüm grafikleriyle karşılanır. `UI_FLOW.md` ile uyum için ayrı sidebar öğesi veya yeni rapor endpointi açılmaz.

Bir hesabın birden fazla web rolüne sahip olması halinde girişten sonra panel seçimi gösterilir. Yalnızca API'nin döndürdüğü `Trainer`, `Dietitian` ve `Admin` rolleri seçilebilir; tek web rolünde ilgili panel doğrudan açılır. Yalnız `User` rolüne sahip hesap web paneline alınmaz. Panel değiştirme yeni bir yetki vermez. Sidebar gizlemesi güvenlik yerine geçmez; backend yetki ve aktif ilişkiyi denetler.

## 3. Ekran grupları

| Grup / erişim | Düzen ve ana içerik | Birincil işlem ve geçiş | Veri / durum sınırı |
|---|---|---|---|
| **Login** / tüm web rolleri | Ortalanmış kısa form: ürün adı, e-posta, şifre, hata alanı. Başarılı girişte role uygun panel. | **Giriş Yap** → Dashboard; profil menüsünden çıkış → Login. | `POST /api/auth/login`, `/refresh`, `/logout`. Kayıt V1 web ekranı değildir. |
| **Dashboard** / Trainer, Dietitian, Admin | Trainer: bağlı danışan sayısı/listesine bağlantı, son seçili danışan ilerlemesine giriş. Dietitian: bağlı danışanlar ve hedef/beslenme alanına giriş. Admin: kullanıcılar/atamalar/roller/kataloglara kısa bağlantılar. | **Danışanları Gör** veya Admin **Kullanıcıları Gör**. | Trainer `GET /api/trainers/me/clients`; Dietitian `GET /api/dietitians/me/clients`; Admin `GET /api/users`. Ayrı web dashboard/istatistik endpointi yok; temelsiz metrik gösterilmez. |
| **Danışanlar** / Trainer, Dietitian | Liste: ad, ilişki durumu, başlangıç tarihi; satırdan ayrıntı. Arama, mevcut liste üzerinde yerel yapılabilir. | **Danışanı Aç** → Danışan Detayı. | `GET /api/trainers/me/clients` veya `/api/dietitians/me/clients`; yalnız `Active` ilişkiler. Boşta “Bağlı danışan yok”. |
| **Danışan Detayı** / Trainer, Dietitian | Üstte profil özeti; role göre sekmeler. Trainer: antrenman, oturum geçmişi, kilo/ölçüm, koşu, görev/not. Dietitian: beslenme hedefi/kayıtları, kilo/ölçüm, görev/not ve bunların grafikleri. | Trainer **Program Ata**; Dietitian **Hedef Ata**; ilgili görev/not formuna geçiş. | `GET /api/users/{userId}` ve yalnız rolün izinli alt kaynakları. Grafikler mevcut kayıtlarından türetilir; ayrı “Raporlar” API'si yok. |
| **Antrenman Programları** / Trainer | Danışana ait plan listesi → oluştur/düzenle formu. Gün kartlarında `DayNumber` sıra ve `Weekday` haftanın günü ayrı seçilir; aynı gün ikinci kez seçilemez. Egzersiz kataloğundan ekle; set/tekrar/süre/dinlenme gir. | **Programı Kaydet ve Ata** → Danışan Detayı/plan; eski planı aç/düzenle. | `GET /api/users/{userId}/workout-plans`, `GET /api/workout-plans/{id}`, `GET /api/exercises`, `POST /api/users/{userId}/workout-plans`, `PUT /api/workout-plans/{id}`. V1'de kullanıcı başına tek aktif plan. |
| **Beslenme Hedefleri** / Dietitian | Danışanın hedef geçmişi ve yeni hedef formu: kalori, protein, karbonhidrat, yağ, su hedefi, başlangıç/bitiş. Geçerli aktif hedef belirgin kartta; geçmiş pasif olarak işaretli. | **Hedefi Ata** → Danışan Detayı/hedef. | `GET/POST /api/users/{userId}/nutrition-goals`. Backend yeni hedefi aktif edip öncekini pasifleştirir. Su tüketim ilerlemesi için veri yok. |
| **Görevler / Notlar** / Trainer, Dietitian | Seçili danışana göre iki görünüm: görev listesi/durum ve not listesi. Formlar kısa; görevde başlık/açıklama/son tarih, notta başlık/içerik. | **Görev Ata** veya **Not Ekle** → listeye dön. | `GET/POST /api/users/{userId}/tasks`, `PATCH /api/tasks/{taskId}`, `GET/POST /api/users/{userId}/advisor-notes`. Yalnız bağlı danışan. |
| **Egzersiz Yönetimi** / Trainer okuma, Admin yönetim | Katalog tablo/kartları: ad, açıklama, görsel/video varsa; arama/kas grubu filtresi. Trainer yalnız seçer; Admin oluşturma/düzenleme formuna geçer. | Trainer **Programa Ekle**; Admin **Egzersiz Kaydet**. | `GET /api/exercises`, `GET /api/exercises/{id}`; Admin için `POST/PUT /api/exercises`. İstek alanlarının kesin biçimi API sözleşmesinde henüz örneklenmemiş. |
| **Admin alanları** / Admin | Kullanıcılar tablosu → kullanıcı ve rol ayrıntısı; danışman aday seçimi ve mevcut `UserAdvisor` ilişkileri; egzersiz/ekipman katalogları. Geniş sistem ayarı yok. | **Rolü Kaydet**, **Danışman Ata**, **İlişkiyi Bitir**, **Ekipman Kaydet**. | `GET /api/users` ve rol filtresi, `PUT /api/users/{userId}/roles`, `GET/POST /api/user-advisors`, `PATCH /api/user-advisors/{userAdvisorId}`, `GET/POST /api/exercises`, `PUT /api/exercises/{exerciseId}`, `GET/POST /api/gym-equipments`, `PUT /api/gym-equipments/{gymEquipmentId}`. |
| **Profil** / Trainer, Dietitian, Admin | Kendi ad/e-posta/temel bilgileri ve düzenleme formu; çıkış. | **Profili Kaydet**; **Çıkış Yap** → Login. | `GET/PUT /api/users/me`, `POST /api/auth/logout`. |

## 4. Önemli web etkileşimleri

### Trainer: program atama

1. Danışanlar listesinden aktif ilişkili kullanıcı açılır.
2. Antrenman Programları'nda plan adı, tarih aralığı ve `WorkoutDay` eklenir. Her günün `Weekday` değeri benzersizdir; `DayNumber` yalnız sıralamadır.
3. `Exercise` kataloğundan seçim yapılır; `WorkoutExercise` set/tekrar/süre/dinlenme alanları doldurulur.
4. Kaydetme API yanıtıyla doğrulanır; eski aktif plan backend tarafından pasifleştirilir. Mobil Planım aynı aktif planı okur.

### Dietitian: hedef atama

1. Danışan Detayı > Beslenme Hedefleri açılır; önceki hedef ve kayıtlar görülür.
2. Kalori/makro/su hedefleri ve tarih aralığı girilir. Su alanı hedef olup tüketim kaydı anlamına gelmez.
3. Kaydetmede backend önceki `NutritionGoal` kaydını pasifleştirir. Yeni hedef mobil Planım ve günlük beslenmede yalnız geçerli tarih aralığında görünür.

### Admin: danışman ve katalog

1. Kullanıcılar'da `User` seçilir. `GET /api/users?role=Trainer` veya `?role=Dietitian` ile uygun danışman adayları gösterilir.
2. Mevcut ilişkiler `GET /api/user-advisors?userId=...` ile görülür. **Danışman Ata** sonrası kayıt doğrudan `Active` olur; davet/onay adımı yoktur. İlişki `Ended` veya `Cancelled` yapılabilir.
3. Egzersiz kataloğu yalnız Admin tarafından değişir. Ekipman formunda `GymEquipment.ModelKey` ve eşlenen `Exercise` seçimleri (`exerciseIds`) görülür; AI modelinin içine öneri yazılmaz.

## 5. Tablo, form, grafik ve durum kalıpları

- Tabloda başlık, sayfalama varsa sayfa bilgisi, satır eylemleri ve boş durum bulunur. `page/pageSize` yalnız ilgili endpoint desteklediği yerde kullanılır. Uzun metin detayda açılır.
- Formda görünür etiket, birim, zorunlu/isteğe bağlı ayrımı ve kaydetme öncesi doğrulama vardır. Aynı danışana ait olmayan plan/hedef bağlantısı açılmaz.
- Grafikte dönem, eksen/birim ve veri kaynağı yazılır. Trainer'ın beslenme kaydı yetkisi olmadığı için onun grafiğinde bu veri gösterilmez; Dietitian'ın koşu verisi V1'de gösterilmez.
- Boş liste: “Henüz kayıt yok”; ilgili yetki varsa oluşturma eylemi. Yüklenirken tablo/kart iskeleti. Hata: kısa açıklama + tekrar dene; form girdileri korunur.
- Başarı mesajı kısa ve somuttur: “Program atandı”, “Hedef kaydedildi”. Tek aktif plan/hedef değişimi form öncesinde açıklanır.

## 6. Tasarımda açık kalan veri noktaları

- Web için ayrı toplu dashboard yanıtı yok. Özetler mevcut liste/veriden üretilebilir; tüm danışanlar için ağır rapor varsayılmaz.
- `Exercise` oluşturma/güncelleme isteklerinin ayrıntılı request/response örneği API sözleşmesinde eksik; form alanları kodlama öncesinde netleşmeli.
- Görev/not liste yanıtlarında yazar kimliği ve danışman uzun profili net değil; kesin ilişkilendirme olmadan danışman adı uydurulmaz.
- Çoklu web rolüne sahip hesap panelini Bölüm 2'deki kurala göre seçer; yeni yetki veya API alanı oluşturulmaz.
