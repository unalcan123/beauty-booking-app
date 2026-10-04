# Yönetici girişini etkinleştirme

Müşteri adresi `/#/`, yönetim adresi `/#/admin` ve `/#/dashboard`.
GitHub proje adreslerinde depo adından sonra bu parçalar gelir.
Müşteri sayfasında yönetim bağlantısı yoktur. Yönetim verileri sunucudaki
admin üyeliği ve RLS kurallarıyla korunur; bağlantıyı gizlemek tek başına güvenlik değildir.
Bağlantı kurulana kadar panel erişime kapalıdır.

Kurulu proje: `beauty-booking` (ref `hieefplluyxsaivfeszj`, eu-central-1 / Frankfurt).
Şema ve RLS kuralları uygulandı. Proje URL'si ve yayınlanabilir anahtar
`config/supabase.json` içindedir; bu anahtar tarayıcıya açık olacak şekilde tasarlanmıştır.
Secret/service_role anahtarı bu depoya veya Flutter'a asla eklenmez.

Yeni bir projede yeniden kurmak için:

1. SQL Editor içinde sırasıyla `supabase/schema.sql`, `supabase/booking.sql`, `supabase/cancellation.sql`, `supabase/admin_services.sql`, `supabase/dutch_names.sql` çalıştır.
2. Authentication > Users > Add user ile kendi e-postan ve güçlü şifrenle
   yönetici hesabı oluştur ("Auto Confirm User" işaretli). Şifreyi dosyalara veya GitHub'a yazma.
3. SQL Editor içinde çalıştır:
   `insert into public.admins(user_id) select id from auth.users where email = 'SENIN@EPOSTAN';`
4. Authentication > Sign In / Providers bölümünde "Allow new users to sign up" ayarını kapat.
5. `config/supabase.json` dosyasına proje URL'si ve publishable key (`sb_publishable_...`) yaz.

Yerel çalıştırma:

```sh
flutter run -d chrome --dart-define-from-file=config/supabase.json
```

GitHub Pages iş akışı `config/supabase.json` dosyasını kullanır. İstersen depo
Settings > Secrets and variables > Actions > Variables alanındaki `SUPABASE_URL` ve
`SUPABASE_ANON_KEY` değişkenleriyle geçersiz kılabilirsin. İş akışı `sb_publishable_`
ile başlamayan bir anahtarla derlemeyi reddeder.

`/#/admin` adresinden kendi e-posta ve şifrenle giriş yap.

Dashboard kayıtlı randevuları, müşteri sayısını ve iptal edilmemiş randevuların
planlanan gelirini gösterir. Panelde örnek müşteri verisi veya varsayılan admin şifresi yoktur.

Müşteri rezervasyonu gerçektir: müsait saatler sunucuda `get_available_slots` ile hesaplanır,
kayıt `book_appointment` ile yapılır. Çalışma saatleri 09:00–18:00 (Europe/Amsterdam),
başlangıçlar tam saatte, en fazla 90 gün ileri. Tek koltuk varsayılır: çakışan aktif randevuları
`appointments_no_overlap` kısıtı veritabanında engeller (eşzamanlı isteklerde de).
İptal (`status = 'cancelled'`) saati yeniden açar. Ziyaretçiler başka müşterilerin bilgilerini göremez.

## Fiyatlar

Dashboard'daki "Hizmetler ve fiyatlar" bölümünden kalem simgesiyle fiyat değiştirilir.
Müşteri sayfası fiyatları veritabanından okur. Yeni fiyat yalnızca sonraki randevulara uygulanır;
mevcut randevular alındıkları fiyatla kalır. Fiyatı yalnızca adminler değiştirebilir (RLS).

## İptal ve e-posta bildirimleri

Müşteri onay e-postasındaki (ve onay ekranındaki) `/#/iptal?t=...` bağlantısıyla randevudan
en geç 24 saat önce iptal edebilir. Kayıt silinmez, `cancelled` olur ve saat yeniden açılır.
Admin, Dashboard'daki iptal düğmesiyle iptal edebilir; müşteriye e-posta gider.

E-postaları `supabase/functions/notify` Edge Function'ı Resend API ile gönderir
(gönderen alan adı Resend'de doğrulanmış olmalı: `browbelle.nl`, DNS kayıtları Vimexx'te).
Veritabanı tetikleyicisi fonksiyonu Vault'taki `notify_webhook_secret` ile çağırır.
Edge Function secret'ları (Supabase > Edge Functions > Secrets):

- `RESEND_API_KEY`: Resend API anahtarı (yalnızca "Sending access")
- `MAIL_FROM` (isteğe bağlı): gönderen, varsayılan `Brow Belle <info@browbelle.nl>`
- `REPLY_TO` (isteğe bağlı): müşteri yanıtlarının gideceği adres; boşsa yanıt adresi eklenmez
- `SALON_EMAIL` (isteğe bağlı): yeni randevu/iptal kopyalarının gideceği özel adres
- `SITE_URL`, `NOTIFY_WEBHOOK_SECRET`

Gönderen adresi değiştirmek için `MAIL_FROM` güncellenir; kod değişmez.

Doğrulama: yapılandırma yokken müşteri sayfasında yönetim bağlantısı olmaması,
/admin ve /dashboard doğrudan erişiminin kapalı kalması otomatik test edilir.
Gerçek giriş ve RLS, proje kurulduktan sonra admin olmayan bir hesapla da denenmelidir.