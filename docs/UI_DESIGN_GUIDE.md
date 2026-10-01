# Yapay Zekâ Destekli Sağlık ve Fitness Platformu — UI Tasarım Rehberi

Bu belge V1 mobil arayüzünün görsel ve etkileşim kurallarını tanımlar. Ekran içeriği ve geçişleri için `UI_FLOW.md`, veri ve yetki için `DATA_DICTIONARY.md` ile `API_CONTRACT.md` esas alınır. Buradaki bileşen adları tasarım adıdır; Flutter sınıfı, backend modeli veya yeni API değildir.

## 1. Tasarım yönü

- Koyu tema ağırlıklı, sakin ve premium fitness görünümü. Mavi, kullanıcıyı birincil eyleme yönlendiren vurgu rengidir.
- Büyük, okunabilir başlık; kısa metin; bir ekranda belirgin tek birincil eylem; kartlarla bölünmüş içerik.
- Alt navigasyonda **Ana Sayfa, Planım, AI, Takip, Rehberim**. AI ortada biraz daha vurgulu olabilir; profil sağ üst avatardan açılır.
- Ana Sayfa ilk bakışta bugünü anlatır. Ayrıntı ve uzun geçmiş listeleri ilgili alt ekranlara taşınır.
- Antrenman ve koşu sırasında sayı, ilerleme ve bitirme eylemi dekoratif içerikten önce gelir. AI tahminleri daima “tahmini” olarak etiketlenir.

## 2. Renk rolleri

Aşağıdaki hex değerleri başlangıç örneğidir; uygulama öncesinde gerçek cihazlarda okunabilirlik kontrolüyle ayarlanabilir. Renk hiçbir zaman durumun tek göstergesi olmamalıdır.

| Rol | Kullanım | Örnek |
|---|---|---|
| Background | Sayfanın ana zemini | `#0B1020` |
| Surface | Header, alt menü, form yüzeyi | `#121A2B` |
| Card | İçerik kartı ve panel | `#1A2538` |
| Primary | Birincil CTA, aktif sekme, ilerleme halkası | `#4D8DFF` |
| Secondary | Daha düşük öncelikli vurgu ve bağlantı | `#8BB5FF` |
| Success | Kaydedildi / tamamlandı | `#42C98B` |
| Warning | Eksik izin, bekleyen durum | `#F3B55B` |
| Error | Doğrulama ve işlem hatası | `#F07178` |
| Text primary | Başlık ve temel değer | `#F5F7FC` |
| Text secondary | Yardımcı açıklama ve etiket | `#A7B3C9` |
| Divider / border | Kart ayrımı ve giriş kenarı | `#2A3952` |

Kalori, protein, karbonhidrat ve yağ grafiklerinde farklı tonlar kullanılabilir; her grafik ayrıca metin etiketi ve sayısal değer taşır. Sağlık ve AI sonuçlarında renk tek başına “iyi/kötü” yargısı vermez.

## 3. Tipografi ve aralık

| Düzey | Önerilen görünüm | Kullanım |
|---|---|---|
| Sayfa başlığı | 26–30 sp, güçlü ağırlık | Ana Sayfa, Planım, Takip |
| Bölüm başlığı | 19–22 sp, güçlü ağırlık | Bugünkü antrenman, Günlük durum |
| Kart başlığı | 16–18 sp, orta/güçlü ağırlık | Kart içindeki konu |
| Ana metrik | 28–36 sp, güçlü ağırlık | Süre, mesafe, kalori, kilo |
| Gövde | 14–16 sp | Açıklamalar ve liste satırları |
| Yardımcı metin | 12–14 sp | Tarih, kaynak, tahmini bilgisi |

- Sistem sans fontu yeterlidir; özel font zorunlu değildir. Kullanıcının metin büyütme ayarıyla satırlar kırılabilir olmalıdır.
- Aralık ölçeği: **4, 8, 12, 16, 24, 32**. Sayfa yatay boşluğu çoğunlukla 16–20; kart içi 16–20; bölümler arası 24.
- Sayfanın ilk görünen alanında en önemli kart ve CTA bulunur. Uzun içerikler kaydırılır; sık kullanılan eylem altta sabitlenebilir.
- Kart köşesi yaklaşık 16–20, buton/input köşesi 12–16, küçük etiket 8–12. Aynı tür bileşende aynı yarıçap kullanılır.
- Dokunma alanları rahat basılabilir büyüklükte olmalı; yalnızca küçük ikon hedeflerine güvenilmemelidir.

## 4. Yerleşim ve gezinme

- Üst header: sayfa başlığı, gerektiğinde kısa tarih/bağlam, sağda avatar veya sayfaya özgü eylem. Geri oku yalnızca alt ekranlarda.
- Alt menü beş ana grupta kalır. Detay, form, kamera, aktif antrenman ve canlı koşuda alt menü gerektiğinde gizlenir; geri veya kapat eylemi görünür olur.
- `Planım` tek giriş ekranıdır; **Antrenman / Beslenme / Görevler** sekmeleri aynı ekranın durumlarıdır. Notlar, görev ve danışman içeriklerinden açılır.
- `Takip` girişinde alt kategorilere kartlarla erişilir. Haftalık/aylık seçim mevcut geçmiş verisini filtreler; ayrı ekran açmaz.
- Profilin “Genel Görünüm / Egzersizler / Ölçümler / Aktivite” şeklinde ikinci bir navigasyonu V1'de kullanılmaz; egzersiz ve ölçüm zaten Planım/Takip'tedir.
- Dar ekranda kartlar tek sütun, geniş ekranda uygun özet kartları iki sütun olabilir. Metin kesilip anlam kaybolmamalıdır.

## 5. Tekrar kullanılabilir tasarım bileşenleri

| Bileşen | İçerik ve davranış |
|---|---|
| `PrimaryButton` | Dolu mavi; tek ana eylem; bekleme sırasında metin korunur, ilerleme göstergesi eklenir. |
| `SecondaryButton` | Yüzey/çerçeve; geri, galeri seçimi veya ikinci seçenek. |
| `TextAction` | Düşük öncelikli bağlantı; ör. “Tümünü gör”. |
| `AppCard` | Başlık, kısa içerik, gerekirse sağ ok; tek dokunma hedefi. |
| `MetricCard` | Etiket, büyük sayı, birim, tarih/kaynak; boşsa “Veri yok”. |
| `WorkoutCard` | Gün/program adı, egzersiz sayısı, gün, durum, başlat/ayrıntı. Süre yalnızca gerçekten biliniyorsa gösterilir. |
| `NutritionSummaryCard` | Kalori halkası, makro hedefleri ve gerçekleşen değerler; aktif hedef yoksa hedef halkası yerine açıklama. |
| `AdvisorCard` | İsim, `Trainer`/`Dietitian` rolü, ünvan/uzmanlık varsa, detay geçişi. |
| `ProgressRing` | Gerçekleşen/hedef, birim ve metin etiketi; hedef sıfır/eksikse yüzde üretilmez. |
| `SectionHeader` | Bölüm başlığı, isteğe bağlı “Tümünü gör”; aynı hiyerarşide tutarlı. |
| `StatusChip` | Bekleyen, tamamlandı, aktif veya tahmini gibi metinli durum. |
| `EmptyState` | Neden boş olduğu + yalnızca mümkünse çözüm eylemi; ör. “Henüz program atanmadı”. |
| `ErrorPanel` | Kısa hata, tekrar dene, gerekirse forma dön. |

Bu adlar tasarım tarifidir; gereksiz widget/hizmet soyutlaması oluşturma zorunluluğu getirmez.

## 6. Form, grafik ve durum kuralları

### Butonlar ve girişler

- Birincil CTA: **Antrenmanı Başlat**, **Kaydet**, **Analiz Et**, **Koşuyu Bitir** gibi fiille yazılır.
- İkincil eylem: galeri seç, vazgeç, geçmişe dön. Yıkıcı veya geri alınamaz eylem gerekiyorsa açık sonuç metni gösterilir.
- E-posta/şifre, sayı ve birim, tarih/saat seçici, tekli seçim ve çok satırlı not alanları tutarlı etiket ve yardım metni taşır. Sayısal alanlarda birim (`kg`, `cm`, `kcal`, `g`, `km`) daima görünür.
- Doğrulama hatası ilgili alanın altında gösterilir. API `ProblemDetails` alan mesajları genel hata metninin yerine kullanılabilir.
- Kaydetme sırasında yinelenen gönderim engellenir. Başarı yalnızca API yanıtından sonra gösterilir.

### Beslenme ve sağlık görselleştirmesi

- Kalori için büyük dairesel halka; protein/karbonhidrat/yağ için daha küçük yatay veya halka göstergeleri. Hedef ve tüketim sayıları birlikte yazılır.
- Öğün kartı: öğün türü, ad, saat, kalori, makrolar ve `Manual`/`AI` kaynak etiketi. AI etiketli değerler kullanıcı kaydetmeden önce tahmin olarak sunulur.
- `NutritionGoal.WaterMl` su **hedefidir**. V1'de su tüketim kaydı/API'si tanımlı olmadığından “içilen su” halkası veya günlük su tamamlama eylemi gösterilmez.
- Kilo, ölçüm, kalori ve aktivite grafikleri mevcut kayıtların tarihini ve birimini belirtir. Haftalık/aylık görünüm aynı kayıtların filtrelenmesidir. Veri azsa grafik yerine açık metin kullanılır.
- Streak, kişisel rekor veya takvim özeti ancak mevcut `WorkoutSession`/`RunningActivity` kayıtlarından tanımı belirlenip güvenilir hesaplanabiliyorsa görünür; V1 için yeni veri veya endpoint varsayılmaz.

### Empty / loading / error

| Durum | Ortak tasarım |
|---|---|
| Empty | “Henüz kayıt yok” gibi gerçek neden; uygun olduğunda **Ekle**, **Tara** veya **Koşu başlat**. Danışman atamasını kullanıcı yapamadığı için yanlış CTA gösterilmez. |
| Loading | Yerleşimi koruyan kart iskeleti; kısa işlemde buton içi spinner. Kamera/AI işlemi açık “Analiz ediliyor” metni taşır. |
| Error | Anlaşılır kısa mesaj + **Tekrar dene**. Form girdileri ve henüz kaydedilmemiş fotoğraf/koşu özeti mümkün olduğunca korunur. |
| İzin reddi | Kamera/konum/sağlık izni için neden gerektiği ve ayarlara gitme yolu. İzin verilmiş gibi sahte veri gösterilmez. |

### Grafik ve hareket

- Grafik eksenleri ve birimleri okunur; yalnızca rengi farklı çizgilerle ayrım yapılmaz. Gelecek tarih için veri varmış gibi çizilmez.
- Animasyon küçük ve hızlıdır; ilerleme halkası isteğe bağlı hareket eder. Kullanıcının azaltılmış hareket tercihi varsa animasyon azaltılır.
- `confidence` (AI güven skoru) modelin kesinliği gibi sunulmaz; düşük güven veya tanınamayan durumda yeniden fotoğraf çekme yolu verilir.

## 7. V1 veri sınırları

- “Bugünkü antrenman”, tek aktif `WorkoutPlan` içindeki tarih ve `WorkoutDay.Weekday` eşleşmesinden gelir. Uygun gün yoksa kartın boş durumu gösterilir.
- Günlük kalori/makro hedefi yalnızca ilgili tarihte geçerli tek aktif `NutritionGoal` üzerinden gösterilir. Hedef yokken sıfır hedef çizilmez.
- Sağlık izni cihazda alınır; veri Health Connect/HealthKit → Flutter → ASP.NET Core API → PostgreSQL yolunu izler. “Bağlı cihaz” listesi veya üretici entegrasyonu varsayılmaz.
- AI fotoğrafı Flutter → ASP.NET Core API → FastAPI üzerinden gider. Ekipman-egzersiz eşleştirmesi backend'dedir; yemek tahmini kullanıcı onayından sonra `NutritionRecord` olur.
- Bildirim tercihi için veri modeli/API tanımlı değil. Ayarlar tasarımında yer ayrılabilir; V1'de işlevsiz bir anahtar gösterilmez.
