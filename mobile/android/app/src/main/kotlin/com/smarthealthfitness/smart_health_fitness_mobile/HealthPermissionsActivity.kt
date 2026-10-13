package com.smarthealthfitness.smart_health_fitness_mobile

import android.app.Activity
import android.os.Bundle
import android.widget.ScrollView
import android.widget.TextView
import android.graphics.Color

/** Health Connect's permission rationale must also work without a signed-in Flutter session. */
class HealthPermissionsActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val padding = (24 * resources.displayMetrics.density).toInt()
        val text = TextView(this).apply {
            textSize = 18f
            setTextColor(Color.rgb(167, 179, 201))
            setPadding(padding, padding, padding, padding)
            text = """
                Yapay Zekâ Destekli Sağlık ve Fitness Platformu

                Sağlık verileri ve izinler

                Takip ekranında seçtiğin adım, aktif kalori ve kalp atış hızı verilerini Health Connect'ten yalnız okuma izninle alıyoruz.

                Bu temel sürüm verileri cihazda gösterir. Sağlık verileri sunucuya gönderilmez, dosyaya kaydedilmez veya reklam için kullanılmaz. Sağlık platformuna veri yazılmaz.

                Okuma yalnız ekran açıkken yapılır. Arka planda senkronizasyon yoktur. Veri bulunmadığında tahmini veya sahte değer oluşturulmaz.

                İzinleri Health Connect > Uygulama izinleri bölümünden değiştirebilir veya kaldırabilirsin. Nabız değeri canlı ölçüm veya tıbbi yorum değildir.
            """.trimIndent()
        }
        setContentView(ScrollView(this).apply {
            setBackgroundColor(Color.rgb(11, 16, 32))
            addView(text)
        })
    }
}
