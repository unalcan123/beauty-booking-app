# Brow Belle — Flutter Web

Telefon ve bilgisayar tarayıcılarında kullanılacak randevu arayüzü.
Supabase'e bağlıdır: müsait saatleri sunucudan alır ve randevuları çift kayıt olmadan kaydeder.

## Yerel kullanım

Flutter SDK kurulu bir bilgisayarda bu klasörde çalıştırın:

```sh
flutter pub get
flutter run -d chrome --dart-define-from-file=config/supabase.json
```

## GitHub Pages

Bu klasörün içeriğini ayrı bir GitHub deposunun köküne yükleyin.
Çalışma alanının tamamını yüklemeyin: üst klasörde gizli Telegram bilgileri olabilir.
Ana dalın adı `main` olmalıdır.
GitHub deposunda Settings → Pages → Source alanını GitHub Actions olarak seçin.
`main` dalına gönderim yapıldığında iş akışı analiz, web derleme ve yayınlamayı yapar.
Yayınlanan adres Actions çıktısında görünür.

İş akışı bu klasörün kendi deposu olduğu varsayımıyla hazırlanmıştır.
Henüz yerel derleme veya yayın doğrulanmamıştır.

## Rezervasyonlar ve yönetim

Kurulum, müsaitlik kuralları ve admin paneli için `ADMIN_SETUP.md` dosyasına bakın.
Gizli (secret/service_role) API anahtarlarını Flutter Web içine koymayın.
Henüz e-posta/SMS onayı ve müşterinin kendi randevusunu iptal etmesi yoktur.

## Alan adı

Alan adı alındığında GitHub Pages Custom domain ve DNS ayarları yapılır.
İş akışındaki web derlemesinde `--base-href /` kullanılmalı ve alan adı
`web/CNAME` dosyasına eklenmelidir.
