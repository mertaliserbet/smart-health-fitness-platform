# Yapay Zekâ Destekli Sağlık ve Fitness Platformu — Mobil Ekran Spesifikasyonu ve Wireframe'ler

Bu belge `UI_FLOW.md` içindeki **36 mobil ekran/görünümü** tasarım açısından tarif eder. Bunlar 36 ayrı alt menü sekmesi değildir: ana navigasyon beş sekme, profil avatar üzerinden; ayrıntılar bu grupların altındadır. Kod veya yeni API tanımlamaz. Görsel kurallar `UI_DESIGN_GUIDE.md` içindedir.

**Tablo anahtarı:** İçerik sırası soldan sağa değil, **üstten alta** yazılır. `B` boş durum, `Y` yükleniyor durumu, `H` hata durumudur. Her satırda bunlar ekrana özgü davranışı anlatır. `CTA` birincil eylemdir; `İkincil` daha düşük öncelikli eylemdir. Alt navigasyon yalnızca ana gruplarda görünür. Form ve tam ekran işlem akışlarında geri/kapama üst header'dadır.

## 1. Giriş öncesi — M01–M03

| ID / ekran | Amaç; header | İçerik sırası ve bileşenler | CTA; ikincil | B / Y / H | Geçiş |
|---|---|---|---|---|---|
| M01 Karşılama / oturum kontrolü (Splash) | Uygulama açılışını ve oturumu denetler; logo + kısa ad, alt menü yok. | Marka alanı → kısa yükleme göstergesi → gerekirse giriş/kayıt seçenekleri. | **Giriş Yap**; **Kayıt Ol**. | B: oturum yoksa iki seçenek; Y: token/profil kontrolü; H: ağ hatasında yeniden dene ve giriş yolu. | M02, M03; geçerli oturumla M04. |
| M02 Giriş | E-posta/şifreyle oturum açar; “Giriş Yap”, geri/karşılama. | Başlık → e-posta input → şifre input/göster → alan hataları → CTA → kayıt bağlantısı. | **Giriş Yap**; **Kayıt Ol**. | B: boş form; Y: CTA kilitli spinner; H: alan veya genel API hatası, girdiler korunur. | M03, M04. |
| M03 Kayıt | `User` hesabı oluşturur; “Kayıt Ol”, geri. | Kısa açıklama → ad → soyad → e-posta → şifre → alan hataları → CTA. | **Hesap Oluştur**; **Giriş Yap**. | B: boş form; Y: CTA kilitli; H: doğrulama/çakışma mesajı, girdiler korunur. | M02. |

## 2. Ana Sayfa — M04

| ID / ekran | Amaç; header | İçerik sırası ve bileşenler | CTA; ikincil | B / Y / H | Geçiş |
|---|---|---|---|---|---|
| M04 Ana Sayfa | Bugünü tek bakışta özetler; “Merhaba, ad” + bugün tarihi + sağ avatar. | Günlük aktivite `MetricCard` → bugünkü `WorkoutCard` → kalori/makro `NutritionSummaryCard` → adım/son kilo küçük metrikler → en fazla 2 görev/not → “Tümünü gör”. İlk alan kısa tutulur. | **Antrenmanı Başlat** yalnızca bugüne uygun gün varsa; kart bağlantıları. | B: antrenman/hedef/aktivite yoksa ilgili kart ayrı boş mesaj; Y: kart iskeleti; H: özet yenileme ve kart bazlı tekrar dene. | M05/M07/M09, M11, M20/M29/M32, M33. |

## 3. Planım — M05–M14

`Planım` üstündeki **Antrenman / Beslenme / Görevler** sekmeleri M05 ekranının durumlarıdır; ayrı ana navigasyon ekranları değildir. Her sekmede kaydırma konumu ve seçili durum açık kalır. Bugünkü antrenman, aktif `WorkoutPlan` tarih aralığı ve `WorkoutDay.Weekday` ile belirlenir; aynı planda aynı güne ikinci kayıt yoktur.

| ID / ekran | Amaç; header | İçerik sırası ve bileşenler | CTA; ikincil | B / Y / H | Geçiş |
|---|---|---|---|---|---|
| M05 Planım özeti | Atanmış içeriğe giriş; “Planım” + avatar, altında üç sekme. | Antrenman: bugün kartı → haftalık gün şeridi → program bağlantısı. Beslenme: aktif hedef özeti → makrolar → diyetisyen notu. Görevler: bekleyen → tamamlanan. | Sekmeye göre **Antrenmanı Başlat**, **Öğün Ekle** veya **Görevi Aç**; sekme değiştir. | B: her sekmede ayrı “Henüz atama yok”; Y: sekme kart iskeleti; H: başarısız kaynağı ayrı yeniden dene. | M06, M07, M11, M12–M14, M26. |
| M06 Antrenman programı | Aktif programın haftalık yapısı; geri + program adı. | Tarih aralığı/durum → Pazartesi–Pazar gün şeridi → dolu günlerin `WorkoutCard` listesi → geçmiş bağlantısı. | **Bugünkü Günü Aç** varsa; gün seç / **Geçmişi Gör**. | B: plan yok veya hafta günü boş; Y: plan iskeleti; H: programı tekrar yükle. | M07, M10, M05. |
| M07 Antrenman günü / egzersizler | Seçilen `WorkoutDay` ve sırayı gösterir; geri + gün adı/hafta günü. | Gün özeti → sıralı egzersiz kartları (görsel alanı, set/tekrar veya süre, dinlenme, not) → alt sabit CTA. | **Antrenmanı Başlat**; egzersiz detayını aç. | B: günün egzersizi yoksa başlatma yok; Y: egzersiz iskeleti; H: gün verisini yeniden dene. | M08, M09, M06. |
| M08 Egzersiz detayı | Hareketin nasıl yapılacağını açıklar; geri + egzersiz adı. | Varsa görsel/video alanı → açıklama/talimat → programdaki set/tekrar/süre/dinlenme bilgisi. | **Antrenmana Dön**; medya varsa aç. | B: medya yoksa metin öne çıkar; Y: içerik iskeleti; H: talimat yüklenemezse geri/yeniden dene. | M07, M09. |
| M09 Aktif antrenman | Gerçekleşen egzersizi kaydeder; gün adı + oturum ilerlemesi. | Tamamlanan/toplam egzersiz göstergesi → aktif egzersiz → set/tekrar/ağırlık veya süre inputları → not → sonraki egzersiz → alt sabit tamamlama. | **Seti Kaydet** / sonunda **Antrenmanı Tamamla**; egzersizler arası geç. | B: kaydedilmiş log yoksa plan değerleri giriş başlangıcı; Y: gönderim kilitli; H: giriş korunur, tekrar kaydet. Yarım oturumdan çıkış/devam kuralı açık. | M08, M10. |
| M10 Tamamlanma özeti / geçmiş | Bitmiş oturumu ve eski oturumları okur; geri + “Antrenman Geçmişi”. | Son tamamlanma durumu → tarihli oturum listesi → varsa gerçekleşen özet. Ayrı tek oturum detay ekranı üretilmez. | **Planıma Dön**; oturum listesinde tarih seç. | B: oturum yok; Y: liste iskeleti; H: geçmişi yeniden dene. Tek oturum ayrıntısı API yanıtı kesinleşene kadar listede mevcut alanlar kullanılır. | M05, M06. |
| M11 Beslenme hedefi | Tek aktif `NutritionGoal` değerlerini okur; geri + “Beslenme Hedefim”. | Kalori hedef kartı → protein/karbonhidrat/yağ hedefleri → su **hedefi** metni → geçerlilik tarihleri → diyetisyen notu/öğün bağlantısı. | **Öğünlerimi Gör**; notu aç. | B: bu tarihte geçerli hedef yoksa “Aktif hedef yok”; Y: hedef iskeleti; H: tekrar dene. Su tüketimi ilerlemesi çizilmez. | M25, M14, M05. |
| M12 Görevler | `UserTask` listesini okur; geri + “Görevler”, bekleyen/tamamlanan filtreleri. | Bekleyen görev kartları → tamamlanan liste → son tarih ve durum etiketleri. | **Görevi Aç**; filtre değiştir. | B: görev yok; Y: liste iskeleti; H: yeniden dene. | M13, M05. |
| M13 Görev ayrıntısı | Görev açıklamasını gösterir ve sahip olduğu görevi tamamlar; geri + görev adı. | Veren danışman varsa → açıklama → son tarih → durum → alt CTA. | **Tamamlandı Olarak İşaretle**; görevlere dön. | B: açıklama boşsa başlık/tarih kalır; Y: durum güncellenirken kilitli; H: mevcut durum korunur, tekrar dene. | M12, M05. |
| M14 Notlar | Danışman notlarını okur; geri + “Notlar”. | Tarihe göre not kartları → başlık → içerik → yazar bilgisi varsa. | **Planıma Dön**; danışmana git. | B: not yok; Y: kart iskeleti; H: tekrar dene. Yazar alanı API'de yoksa yanlış kişi adı gösterilmez. | M05, M34. |

## 4. AI — M15–M19

Fotoğraf Flutter'dan ASP.NET Core API'ye gider; FastAPI ile yalnızca backend konuşur. Yemek tahmini kesin veri değildir. Ekipman önerileri AI modelinden değil, backend'deki `EquipmentExercise` ilişkisinden gelir.

| ID / ekran | Amaç; header | İçerik sırası ve bileşenler | CTA; ikincil | B / Y / H | Geçiş |
|---|---|---|---|---|---|
| M15 AI başlangıcı | İki analizi seçtirir; “AI” + kısa “Tahmini sonuçlar” açıklaması. | Büyük **Yemek Tara** kartı → büyük **Ekipman Tara** kartı → kısa tahmin uyarısı. | **Yemek Tara**; **Ekipman Tara** eş düzey seçenek. | B: kartlar her zaman görünür; Y: zorunlu veri yok; H: yalnızca kamera açılırken hata M16/M18'de. | M16, M18. |
| M16 Yemek fotoğrafı | Fotoğraf alır; geri + “Yemek Tara”. | Kamera/önizleme alanı → fotoğraf çek → galeri seç → seçili görüntü → analiz CTA. | **Analiz Et**; **Galeriden Seç** / yeniden çek. | B: henüz fotoğraf yok; Y: “Analiz ediliyor”; H: izin/dosya/ağ hatası ve yeniden seç/dene. | M17, M15. |
| M17 Yemek analiz sonucu / düzeltme | AI öğelerini kontrol ettirir ve onaylı `NutritionRecord` oluşturur; geri + “Analiz Sonucu”. | Tahmini etiketi → fotoğraf → tanınan öğe ve porsiyon listesi → toplam kalori halkası ve makrolar → öğün türü/zamanı → düzenlenebilir ad/değerler → alt CTA. | **Beslenme Kaydına Ekle**; **Düzenle** / vazgeç. | B: öğe tanınmadıysa yeniden fotoğraf; Y: kayıt sırasında kilitli; H: düzeltilen değerler korunur, tekrar kaydet. | M25, M16, M15. |
| M18 Ekipman fotoğrafı | Ekipman fotoğrafı alır; geri + “Ekipman Tara”. | Kamera/önizleme → çek/galeri → seçili görüntü → analiz CTA. | **Ekipmanı Tanı**; **Galeriden Seç** / yeniden çek. | B: fotoğraf yok; Y: “Analiz ediliyor”; H: izin/dosya/ağ hatası ve yeniden dene. | M19, M15. |
| M19 Ekipman sonucu / ilgili egzersizler | Tanınan ekipmanı ve backend eşleştirmesini sunar; geri + “Ekipman Sonucu”. | Ekipman adı/görseli varsa → güven skoru “tahmin” etiketi → açıklama → ilgili egzersiz kartları. | **Egzersizi Aç**; **Yeniden Tara**. | B: ekipman veya eşleşen egzersiz yoksa açık mesaj; Y: kart iskeleti; H: yeniden tara/dene. | M08, M18, M15. |

## 5. Takip — M20–M30

“Günlük kalori”, M25'in tarih seçilmiş görünümüdür; yeni ekran değildir. Haftalık/aylık grafik, M21/M23/M25'in filtre durumudur. “Koşuyu başlatma”, M27 içindeki izin ve başlatma durumudur; canlı koşu M28'dir.

| ID / ekran | Amaç; header | İçerik sırası ve bileşenler | CTA; ikincil | B / Y / H | Geçiş |
|---|---|---|---|---|---|
| M20 Takip özeti | Takip alanlarına erişim; “Takip” + avatar. | Kilo/ölçüm küçük metrikleri → beslenme günlük özet → kayıt tarihlerinden takvim şeridi → koşu/aktivite kartları → sağlık verileri. Streak/rekor kartı ancak tanımı ve hesaplaması kararlaştırılırsa açılır. | **Kayıt Ekle** bağlamsal; kategori kartları. | B: her kart kendi “Henüz veri yok” durumunda; Y: kart iskeleti; H: ilgili kartta tekrar dene. | M21, M23, M25, M27, M30. |
| M21 Kilo geçmişi / grafik | `WeightRecord` değişimini gösterir; geri + “Kilo”. | Son kilo metrik kartı → hafta/ay filtresi → tarih/birimli grafik → kayıt listesi. | **Kilo Ekle**; grafik dönemi değiştir. | B: “Henüz kilo kaydı yok”; Y: grafik/list iskeleti; H: tekrar dene. | M22, M20. |
| M22 Kilo ekle | Tarihli kilo kaydı yapar; geri + “Kilo Ekle”. | `kg` sayısal input → tarih/saat → kısa doğrulama → alt CTA. | **Kaydet**; vazgeç. | B: boş form; Y: kaydetme spinner; H: alan/API hatası, değer korunur. | M21. |
| M23 Vücut ölçümleri / grafik | Ölçüm gelişimini gösterir; geri + “Vücut Ölçümleri”. | Ölçüm türü seçimi → son değer → hafta/ay grafiği → tarihli kayıtlar. | **Ölçüm Ekle**; ölçüm türü/dönem değiştir. | B: seçili türde kayıt yok; Y: grafik/list iskeleti; H: yeniden dene. | M24, M20. |
| M24 Ölçüm ekle | `BodyMeasurement` alanlarından seçilenleri kaydeder; geri + “Ölçüm Ekle”. | Bel/göğüs/kalça/kol/bacak `cm` alanları → yağ yüzdesi isteğe bağlı → tarih/saat → CTA. | **Kaydet**; vazgeç. | B: boş alanlar; Y: kaydetme spinner; H: alan/API hatası, girişler korunur. | M23. |
| M25 Beslenme geçmişi / günlük durum | Günün öğünlerini ve kalori/makroyu gösterir; geri + “Beslenme”. | Tarih seçici → geçerli hedef varsa kalori halkası/makro göstergeleri → öğün kartları → öğün ekleme seçenekleri. | **Öğün Ekle**; **Yemek Tara** / tarih değiştir. | B: öğün yok; hedef yoksa yalnız tüketim göster; Y: günlük kart iskeleti; H: kayıt ve hedef için ayrı tekrar dene. | M26, M16, M11, M20. |
| M26 Manuel öğün ekle | `NutritionRecord` oluşturur; geri + “Öğün Ekle”. | Öğün türü → ad → porsiyon → kalori → protein/karbonhidrat/yağ → tüketim zamanı → CTA. | **Kaydet**; vazgeç / AI ile tara. | B: boş form; Y: kaydetme spinner; H: alan/API hatası, girişler korunur. | M25, M16. |
| M27 Koşu geçmişi | Geçmiş `RunningActivity` kayıtlarını gösterir; geri + “Koşu”. | Son koşu özeti → tarihli koşu kartları → başlangıç CTA. Konum izni gerektiğinde açıklama paneli. | **Koşuyu Başlat**; koşu detayını aç. | B: “Henüz koşu yok”; Y: liste iskeleti; H: listeyi yeniden dene / izin reddinde ayarlara git. | M28, M29, M20. |
| M28 Canlı koşu | GPS ile süre, mesafe, pace ve rotayı izler; “Koşu sürüyor” + belirgin durum. | Büyük süre → mesafe/pace metrikleri → harita → anlık durum → altta Duraklat/Devam ve Bitir. | **Koşuyu Bitir**; **Duraklat/Devam**. | B: GPS noktası yoksa “Konum bekleniyor”; Y: konum alınıyor; H: GPS kaybı belirgin uyarı, uydurma rota yok. Duraklama süresinin hesaba katılması netleşmeli. | M29. |
| M29 Koşu özeti / detayı | Tamamlanan koşuyu gözden geçirir ve geçmişten okur; geri + “Koşu Özeti”. | Rota/harita varsa → süre/mesafe/ortalama pace/hız/kalori → kaydetme durumu. | Yeni koşu sonrası **Koşuyu Kaydet**; geçmişten açıldığında **Geçmişe Dön**. | B: rota yoksa sayısal özet; Y: kayıt gönderimi veya detay iskeleti; H: kaydedilmemiş özet korunur, tekrar dene. | M27, M20. |
| M30 Günlük aktivite / sağlık verileri | Kaynağı belli adım, aktif kalori, nabız vb. gösterir; geri + “Sağlık Verileri”. | Gün seçimi → adım/aktif kalori kartları → mevcut sağlık ölçümleri → kaynak ve son senkronizasyon bilgisi varsa. | **Senkronize Et** yalnız izin varsa; **Sağlık Bağlantısı**. | B: izin yok/veri yok ayrı mesaj; Y: okuma/senkronizasyon göstergesi; H: izin veya ağ hatası, yeniden dene. | M35, M20. |

## 6. Rehberim — M31–M32

| ID / ekran | Amaç; header | İçerik sırası ve bileşenler | CTA; ikincil | B / Y / H | Geçiş |
|---|---|---|---|---|---|
| M31 Rehberim | Aktif danışmanları listeler; “Rehberim” + avatar. | `Trainer` kartları → `Dietitian` kartları; her kartta ad/ünvan/uzmanlık varsa. Birden fazla kart desteklenir. | **Danışmanı Gör**; ilgili plan/hedef bağlantısı. | B: “Henüz danışman atanmadı”, kullanıcıya atama CTA'sı yok; Y: kart iskeleti; H: yeniden dene. | M32, M06, M11. |
| M32 Danışman detayı | Seçilen danışmanın mevcut kısa profilini ve ilişkili içeriği gösterir; geri + danışman adı. | Rol/başlık/uzmanlık → program veya hedef bağlantısı → görev/not bağlantısı. İçerik yazarına göre ayırma ancak API alanı varsa. | **Atanan İçeriği Aç**; görev/notu aç. | B: ilgili içerik yok; Y: profil/kart iskeleti; H: yeniden dene. `Biography` ve yazar alanı yoksa boş alan uydurulmaz. | M06, M11, M12, M14, M31. |

## 7. Profil / Ayarlar — M33–M36

| ID / ekran | Amaç; header | İçerik sırası ve bileşenler | CTA; ikincil | B / Y / H | Geçiş |
|---|---|---|---|---|---|
| M33 Profil | Kişisel hesap özetini gösterir; geri + “Profil”. | Avatar/ad → e-posta/telefon/boy vb. → sağlık bağlantısı satırı → ayarlar satırı. Kilo için Takip bağlantısı. | **Profili Düzenle**; **Sağlık Bağlantısı** / Ayarlar. | B: opsiyonel alanlar “Eklenmedi”; Y: profil iskeleti; H: yeniden dene. | M34, M35, M36, M21, M04. |
| M34 Profil düzenle | `User` profil alanlarını günceller; geri + “Profili Düzenle”. | Ad/soyad → telefon → doğum tarihi/cinsiyet → boy (`cm`) → CTA. Kilo burada düzenlenmez. | **Kaydet**; vazgeç. | B: mevcut değerler doldurulur; Y: kaydetme spinner; H: alan/API hatası, girişler korunur. | M33. |
| M35 Sağlık bağlantısı ve izinler | Health Connect/HealthKit izni ve senkronizasyonu; geri + “Sağlık Bağlantısı”. | Platform adı → izin durumu → okunabilecek desteklenen veri türleri → senkronizasyon eylemi → veri ekranı bağlantısı. “Bağlı cihaz” listesi varsayılmaz. | **İzin Ver / Senkronize Et** duruma göre; **Verileri Gör**. | B: izin yoksa açıklama; Y: cihaz/API okuması; H: izin reddi/servis hatası ve ayarlara git/tekrar dene. | M30, M33. |
| M36 Ayarlar / oturum | Hesap ve çıkış alanı; geri + “Ayarlar”. | Hesap özeti → sağlık bağlantısı satırı → bildirim tercihi için V1'de işlevsiz kontrol gösterilmez → çıkış. | **Çıkış Yap**; Profil'e dön. | B: hesap seçenekleri sabit; Y: çıkış isteği; H: çıkış hatası ve tekrar dene. | M35, M33, M02. |

## 8. Metin tabanlı wireframe'ler

Bu şemalar görsel oran veya kesin piksel ölçüsü belirtmez. Köşeli alanlar `AppCard`, köşeli CTA'lar butondur. `…` aynı ekrandaki kaydırılabilir kayıtları gösterir. Duruma bağlı öğeler ilgili satırdaki B/Y/H kurallarına uyar.

### WF01 — Splash, giriş, kayıt (M01–M03)

```text
SPLASH                   GİRİŞ                    KAYIT
┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐
│      [logo]       │    │ ‹  Giriş Yap      │    │ ‹  Kayıt Ol       │
│ Sağlık ve Fitness │    │                   │    │ Ad     [________] │
│ Platformu         │    │ E-posta [_______] │    │ Soyad  [________] │
│ [oturum kontrolü] │    │ Şifre   [_______] │    │ E-posta[________] │
│                   │    │ [Giriş Yap]       │    │ Şifre  [________] │
│ [Giriş Yap]       │    │ Kayıt Ol →        │    │ [Hesap Oluştur]  │
│ [Kayıt Ol]        │    │                   │    │ Giriş Yap →      │
└───────────────────┘    └───────────────────┘    └───────────────────┘
```

### WF02 — Ana Sayfa (M04)

```text
┌──────────────────────────────┐
│ Merhaba, Mert      05 Eki (●)│
│ ┌──────────────────────────┐ │
│ │ Günlük Aktivite          │ │
│ │ 6.420 adım  ·  410 kcal  │ │
│ └──────────────────────────┘ │
│ Bugünkü Antrenman             │
│ ┌──────────────────────────┐ │
│ │ Push · Pazartesi         │ │
│ │ 6 egzersiz              │ │
│ │ [Antrenmanı Başlat]      │ │
│ └──────────────────────────┘ │
│ Kalori / Makro                │
│ ┌──────────────────────────┐ │
│ │ (1320 / 2400)  P K Y     │ │
│ └──────────────────────────┘ │
│ 2 görev  ·  Son kilo 82,4 kg  │
├──────────────────────────────┤
│ Ana  Planım   AI  Takip Reh. │
└──────────────────────────────┘
```

### WF03 — Planım: Antrenman / Beslenme / Görevler (M05)

```text
┌──────────────────────────────┐
│ Planım                    (●)│
│ [Antrenman][Beslenme][Görev] │
│                              │
│ ANTR.     BESLENME   GÖREVLER│
│ Bugün     Hedef      Bekleyen│
│ ┌──────┐  ┌──────┐   ┌──────┐│
│ │Push  │  │2400  │   │2 görev││
│ │Pzt   │  │kcal  │   │       ││
│ └──────┘  └──────┘   └──────┘│
│ Hafta     P/K/Y      Tarihler│
│ P S Ç P C C P       Tamamlandı│
│ [Günü Aç] [Öğünler] [Görevler]│
├──────────────────────────────┤
│ Ana  Planım   AI  Takip Reh. │
└──────────────────────────────┘
```

Şemadaki üç sütun **aynı anda gösterilmez**; seçilen sekmenin alternatif durumlarını özetler. Küçük cihazda her sekme tek sütundur.

### WF04 — Program, gün, egzersiz detayı (M06–M08)

```text
PROGRAM                  GÜN                     EGZERSİZ
┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐
│ ‹ Başlangıç Planı │    │ ‹ Pazartesi / Push│    │ ‹ Bench Press     │
│ 01–30 Kasım       │    │ 6 egzersiz        │    │ [görsel varsa]    │
│ P S Ç P C C P     │    │ 1. Bench Press   │    │ Talimat           │
│ [Push] [Pull] ... │    │ 4 set × 10 tekrar│    │ ...               │
│ Bugün: Push       │    │ 90 sn dinlenme   │    │ Program: 4 × 10  │
│ [Bugünkü Günü Aç] │    │ 2. ...           │    │ [Antrenmana Dön]  │
│ Geçmişi Gör →     │    │ [Antrenmanı Başlat]│   │                   │
└───────────────────┘    └───────────────────┘    └───────────────────┘
```

### WF05 — Aktif antrenman ve geçmiş (M09–M10)

```text
AKTİF ANTRENMAN            TAMAMLANMA / GEÇMİŞ
┌──────────────────────┐    ┌──────────────────────┐
│ Push · 2 / 6         │    │ ‹ Antrenman Geçmişi  │
│ [████░░░░]           │    │ Tamamlandı ✓         │
│ Bench Press          │    │ 02 Kasım · Push      │
│ Plan: 4 × 10         │    │ ┌──────────────────┐ │
│ Yapılan set [__]     │    │ │ 02 Kasım · Push  │ │
│ Tekrar      [__]     │    │ └──────────────────┘ │
│ Ağırlık kg  [__]     │    │ ...                  │
│ [Seti Kaydet]        │    │ [Planıma Dön]       │
│ [Antrenmanı Tamamla] │    │                      │
└──────────────────────┘    └──────────────────────┘
```

### WF06 — Beslenme hedefi, görev, not (M11–M14)

```text
BESLENME HEDEFİ           GÖREVLER / DETAY          NOTLAR
┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐
│ ‹ Beslenme Hedefim│    │ ‹ Görevler        │    │ ‹ Notlar          │
│ 2400 kcal / gün   │    │ [Bekleyen][Biten] │    │ ┌───────────────┐ │
│ P 160g K 270g    │    │ Öğününü kaydet  › │    │ │ Antrenman notu │ │
│ Y 75g            │    │ Son tarih: 05 Kas │    │ │ 10 dk esneme   │ │
│ Su hedefi 2500 ml │    │ ─ Ayrıntı ─       │    │ └───────────────┘ │
│ 01–30 Kasım       │    │ Açıklama ...      │    │ ...               │
│ [Öğünlerimi Gör]  │    │ [Tamamlandı]      │    │ [Planıma Dön]    │
└───────────────────┘    └───────────────────┘    └───────────────────┘
```

### WF07 — AI seçimi ve fotoğraf alma (M15, M16, M18)

```text
AI BAŞLANGICI             FOTOĞRAF (YEMEK/EKİPMAN)
┌──────────────────────┐   ┌──────────────────────┐
│ AI                   │   │ ‹ Yemek Tara          │
│ Sonuçlar tahminidir. │   │ ┌──────────────────┐ │
│ ┌──────────────────┐ │   │ │ Kamera / önizleme │ │
│ │ Yemek Tara       │ │   │ │                  │ │
│ └──────────────────┘ │   │ └──────────────────┘ │
│ ┌──────────────────┐ │   │ [Fotoğraf Çek]       │
│ │ Ekipman Tara     │ │   │ Galeriden Seç        │
│ └──────────────────┘ │   │ [Analiz Et]          │
├──────────────────────┤   └──────────────────────┘
│ Ana Planım AI Takip R.│
└──────────────────────┘
```

### WF08 — Yemek sonucu ve düzeltme (M17)

```text
┌──────────────────────────────┐
│ ‹ Analiz Sonucu              │
│ Tahmini değerler             │
│ [fotoğraf]                   │
│ Tavuk 150 g       [Düzenle] │
│ Pilav 200 g       [Düzenle] │
│ ┌──────────────────────────┐ │
│ │ Toplam 570 kcal (halka)  │ │
│ │ P 52g  K 68g  Y 7g      │ │
│ └──────────────────────────┘ │
│ Öğün türü [Öğle]  Saat [12:30]│
│ Ad / porsiyon / değerler     │
│ [Beslenme Kaydına Ekle]      │
└──────────────────────────────┘
```

### WF09 — Ekipman sonucu (M19)

```text
┌──────────────────────────────┐
│ ‹ Ekipman Sonucu             │
│ Lat Pulldown · AI tahmini    │
│ Güven skoru: 0,94           │
│ [ekipman görseli varsa]      │
│ Bu ekipmanla egzersizler     │
│ ┌──────────────────────────┐ │
│ │ Wide Grip Lat Pulldown › │ │
│ └──────────────────────────┘ │
│ ┌──────────────────────────┐ │
│ │ Close Grip ...         › │ │
│ └──────────────────────────┘ │
│ [Yeniden Tara]               │
└──────────────────────────────┘
```

### WF10 — Takip özeti, kilo, ölçüm (M20–M24)

```text
TAKİP                    KİLO / ÖLÇÜM GEÇMİŞİ      EKLEME FORMU
┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐
│ Takip         (●) │    │ ‹ Kilo            │    │ ‹ Kilo Ekle       │
│ [Kilo] [Ölçümler] │    │ Son: 82,4 kg      │    │ Kilo kg [____]    │
│ [Beslenme]        │    │ [Hafta] [Ay]      │    │ Tarih  [____]    │
│ P S Ç P C C P     │    │ ┌───────────────┐ │    │ Saat   [____]    │
│ [Koşu] [Aktivite] │    │ │ tarihli grafik │ │    │ [Kaydet]        │
│ [Sağlık Verileri] │    │ └───────────────┘ │    │                   │
│                   │    │ [Kilo Ekle]       │    │                   │
├───────────────────┤    └───────────────────┘    └───────────────────┘
│ Ana Plan AI Takip R│    Ölçümde tür + cm grafiği; formda isteğe bağlı ölçüler.
└───────────────────┘
```

### WF11 — Günlük kalori / öğün geçmişi ve manuel kayıt (M25–M26)

```text
BESLENME                  MANUEL ÖĞÜN
┌──────────────────────┐   ┌──────────────────────┐
│ ‹ Beslenme  [Tarih]  │   │ ‹ Öğün Ekle           │
│ (1320 / 2400 kcal)   │   │ Tür   [Öğle]         │
│ P 85/160 K 140/270  │   │ Ad    [___________]   │
│ Y 40/75             │   │ Porsiyon [_______]   │
│ Kahvaltı  420 kcal  │   │ Kalori  [____] kcal  │
│ Öğle      650 kcal  │   │ P [__] K [__] Y [__]  │
│ ...                  │   │ Saat [____]          │
│ [Öğün Ekle]          │   │ [Kaydet]             │
│ Yemek Tara →         │   │ AI ile Tara →        │
└──────────────────────┘   └──────────────────────┘
```

### WF12 — Koşu geçmişi, canlı koşu, sonuç (M27–M29)

```text
GEÇMİŞ                   CANLI KOŞU                SONUÇ
┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐
│ ‹ Koşu            │    │ Koşu sürüyor      │    │ ‹ Koşu Özeti      │
│ Son: 5,24 km      │    │ 00:31:42          │    │ [rota / harita]   │
│ 05 Kasım · 5,24km │    │ 5,24 km           │    │ 5,24 km · 31:42   │
│ ...               │    │ 6:03 / km         │    │ 6:03 / km         │
│ [Koşuyu Başlat]   │    │ ┌───────────────┐ │    │ Tah. 410 kcal    │
│                   │    │ │ harita / rota  │ │    │ [Koşuyu Kaydet]  │
│                   │    │ └───────────────┘ │    │                   │
│                   │    │ [Duraklat] [Bitir]│    │                   │
└───────────────────┘    └───────────────────┘    └───────────────────┘
```

### WF13 — Günlük sağlık verileri (M30)

```text
┌──────────────────────────────┐
│ ‹ Sağlık Verileri   [Tarih]  │
│ ┌────────────┐ ┌───────────┐ │
│ │ 6.420 adım │ │ 410 kcal  │ │
│ └────────────┘ └───────────┘ │
│ Nabız: 78 bpm               │
│ Kaynak: Health Connect       │
│ [Senkronize Et]              │
│ Sağlık Bağlantısı →          │
└──────────────────────────────┘
```

### WF14 — Rehberim ve danışman detayı (M31–M32)

```text
REHBERİM                 DANIŞMAN DETAYI
┌──────────────────────┐   ┌──────────────────────┐
│ Rehberim         (●) │   │ ‹ Ahmet Yılmaz       │
│ Trainer               │   │ Trainer              │
│ ┌──────────────────┐ │   │ Strength Training    │
│ │ Ahmet Yılmaz   › │ │   │ Atanan program →     │
│ └──────────────────┘ │   │ Görevler →           │
│ Dietitian             │   │ Notlar →             │
│ ┌──────────────────┐ │   │                      │
│ │ Ayşe Demir     › │ │   │                      │
│ └──────────────────┘ │   │                      │
├──────────────────────┤   └──────────────────────┘
│ Ana Plan AI Takip Reh.│
└──────────────────────┘
```

### WF15 — Profil, sağlık bağlantısı, ayarlar (M33–M36)

```text
PROFİL                   SAĞLIK BAĞLANTISI         AYARLAR
┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐
│ ‹ Profil          │    │ ‹ Sağlık Bağlantısı│   │ ‹ Ayarlar         │
│ [avatar] Mert     │    │ Health Connect    │    │ Hesap bilgileri   │
│ E-posta           │    │ İzin: Verildi     │    │ Sağlık bağlantısı │
│ Boy: 180 cm       │    │ Adım, nabız, ...  │    │                   │
│ [Profili Düzenle] │    │ [Senkronize Et]   │    │                   │
│ Sağlık Bağlantısı │    │ Verileri Gör →    │    │ [Çıkış Yap]      │
│ Ayarlar           │    │                   │    │                   │
└───────────────────┘    └───────────────────┘    └───────────────────┘
```

Profil düzenleme, M34'te listelenen alanlarla standart formdur. “Bildirim tercihi” için API/veri modeli olmadığından V1'de işlevsiz bir kontrol gösterilmez.

## 9. Tasarımda görülen veri sınırları

- `NutritionGoal.WaterMl` hedefi var, içilen su kaydı yok; su ilerleme halkası gösterilmez.
- Günlük dashboard yanıtı kişisel rekor/streak veya AI geçmişi vermez; bunlar V1 ana ekranında varsayılmaz.
- `WorkoutSession` için yarım oturumdan devam/iptal ve tek oturum detayı yanıtı, `RunningActivity.RouteData` biçimi ile GPS kaydını kurtarma davranışı açık kalır.
- Danışman kısa profili mevcut API ile gösterilir; uzun biyografi ve görev/notları yazara göre kesin ayrıştırma yanıt alanları netleşince yapılır.
- Bildirim tercihleri ve bağlı cihaz listesi için veri modeli/API yoktur. Sağlık bağlantısı işletim sistemi iznini gösterir.
