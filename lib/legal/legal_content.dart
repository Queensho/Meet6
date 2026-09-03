import 'package:flutter/material.dart';

class LegalSection {
  const LegalSection({required this.title, required this.body});

  final String title;
  final String body;
}

class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.sections,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<LegalSection> sections;
}

class Meet6LegalContent {
  const Meet6LegalContent._();

  static const String version = '2026-09-03';
  static const String lastUpdated = '3 Eylül 2026';
  static const String supportChannel = 'Ayarlar → Yardım ve destek';

  static const kvkkNotice = LegalDocument(
    id: 'kvkk-notice',
    title: 'KVKK Aydınlatma Metni',
    subtitle: 'Hangi kişisel verileri neden ve nasıl işlediğimizi öğren.',
    icon: Icons.policy_outlined,
    sections: [
      LegalSection(
        title: '1. Veri sorumlusu',
        body: 'Meet6 hizmeti kapsamında kişisel veriler, Meet6 hizmetini işleten veri sorumlusu tarafından 6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) çerçevesinde işlenir. Veri sorumlusunun yayıma esas ticari unvanı, tebligat adresi ve KVKK başvuru kanalı uygulama mağazası yayını öncesinde bu metne ve Yardım ve destek bölümüne eklenmelidir.',
      ),
      LegalSection(
        title: '2. İşlenen veri kategorileri',
        body: 'Telefon numarası ve oturum bilgileri; ad, doğum tarihi, yaş, cinsiyet, biyografi, ilgi alanları, profil soruları ve fotoğraflar; şehir/ülke ve cihazdan izin verilmesi halinde enlem-boylam; eşleşme tercihleri; oda ve özel mesaj içerikleri; eşleşme, engelleme ve şikâyet kayıtları; bildirim cihaz anahtarları; IP, istek zamanı, hata ve güvenlik kayıtları işlenebilir.',
      ),
      LegalSection(
        title: '3. İşleme amaçları',
        body: 'Hesap oluşturmak ve oturumu güvenli tutmak; 6 kişilik odaları ve eşleştirmeyi çalıştırmak; mesafe filtresi uygulamak; mesajlaşma ve bildirimleri sunmak; sahte hesap, taciz, spam ve kötüye kullanımı önlemek; şikâyetleri incelemek; hizmet güvenliği, hata giderme ve yasal yükümlülükleri yerine getirmek amaçlarıyla veri işlenir.',
      ),
      LegalSection(
        title: '4. Hukuki sebepler ve toplama yöntemi',
        body: 'Veriler; uygulamaya yazdığın bilgilerden, yüklediğin fotoğraflardan, verdiğin cihaz izinlerinden ve Meet6 içindeki kullanımından elektronik ortamda elde edilir. İşleme faaliyetine göre sözleşmenin kurulması/ifası, hukuki yükümlülük, bir hakkın tesisi veya korunması, meşru menfaat ve gerekli olduğu hallerde açık rıza gibi KVKK’da öngörülen işleme şartlarına dayanılır. Aydınlatma ile açık rıza birbirinden ayrı süreçlerdir.',
      ),
      LegalSection(
        title: '5. Aktarım',
        body: 'Veriler, hizmetin çalışması için gerekli ölçüde barındırma/sunucu ve bildirim altyapısı sağlayıcılarına, güvenlik ve teknik hizmet sağlayıcılarına; ayrıca kanunen yetkili kamu kurumlarına hukuki zorunluluk halinde aktarılabilir. Aktarım yalnızca ilgili hizmet veya hukuki gereklilikle sınırlı tutulur.',
      ),
      LegalSection(
        title: '6. Saklama ve silme',
        body: 'Veriler kullanım amacı devam ettiği süre ve uygulanabilir yasal saklama süreleri boyunca tutulur. Hesap silindiğinde profil ve aktif hizmet verileri silme sürecine alınır. Güvenlik/şikâyet kayıtları veya yedekler, hukuki yükümlülük ve güvenli silme döngüsü gerektirdiği ölçüde sınırlı bir süre daha tutulabilir.',
      ),
      LegalSection(
        title: '7. KVKK kapsamındaki hakların',
        body: 'KVKK madde 11 kapsamındaki hakların çerçevesinde verinin işlenip işlenmediğini öğrenme, bilgi talep etme, amacına uygun kullanılıp kullanılmadığını öğrenme, aktarılan kişileri bilme, şartları varsa düzeltme/silme isteme, otomatik analiz sonucuna itiraz etme ve kanuna aykırı işleme nedeniyle zararın giderilmesini talep etme haklarına sahipsin. Başvuru kanalı: Ayarlar → Yardım ve destek.',
      ),
    ],
  );

  static const privacyPolicy = LegalDocument(
    id: 'privacy-policy',
    title: 'Gizlilik Politikası',
    subtitle: 'Meet6 içinde gizliliğin ve verilerin nasıl korunur.',
    icon: Icons.privacy_tip_outlined,
    sections: [
      LegalSection(
        title: 'Gizlilik yaklaşımı',
        body: 'Meet6, yalnızca hizmeti sunmak, güvenliğini sağlamak ve kullanıcı deneyimini geliştirmek için gerekli verileri işlemeyi hedefler. Kişisel veriler reklam verenlere satılmaz. Yetkisiz erişimi azaltmak için oturum, erişim kontrolü, sunucu güvenliği ve yedekleme önlemleri kullanılır.',
      ),
      LegalSection(
        title: 'Diğer kullanıcıların gördüğü bilgiler',
        body: 'Profilinde yayımladığın ad, yaş, fotoğraflar, biyografi, ilgi alanları ve profil cevapları oda/eşleşme deneyiminde diğer uygun kullanıcılara gösterilebilir. Telefon numaran, tam cihaz konumun, oturum anahtarların ve teknik güvenlik kayıtların profilinde gösterilmez.',
      ),
      LegalSection(
        title: 'Mesajlar ve güvenlik',
        body: 'Oda ve özel mesajlar hizmetin çalışması, mesaj geçmişi ve güvenlik amacıyla sunucuda işlenebilir. Şikâyet halinde ilgili içerik, inceleme ve kötüye kullanımın önlenmesi amacıyla değerlendirilebilir. Engellenen kullanıcılar güvenlik filtresinde tekrar karşılaştırılmaz.',
      ),
      LegalSection(
        title: 'Bildirimler ve cihaz bilgisi',
        body: 'Bildirimleri etkinleştirirsen cihazına ait push bildirim anahtarı, eşleşme ve mesaj bildirimlerini göndermek için kullanılabilir. Bildirim tercihlerini uygulama ayarlarından değiştirebilirsin.',
      ),
      LegalSection(
        title: 'Hesap silme',
        body: 'Ayarlar içinden hesabını kalıcı olarak silebilirsin. Bu işlem profil, fotoğraf, eşleşme ve mesaj verilerinin aktif sistemlerden silinme sürecini başlatır. Kanunen tutulması gereken kayıtlar ve döngüsel yedekler istisna olabilir.',
      ),
    ],
  );

  static const locationAndPhotos = LegalDocument(
    id: 'location-photos',
    title: 'Konum ve Fotoğraf Verileri',
    subtitle: 'Konum ve fotoğraf izinlerinin ne için kullanıldığını gör.',
    icon: Icons.location_on_outlined,
    sections: [
      LegalSection(
        title: 'Konum neden kullanılıyor?',
        body: 'Konum, uygun kullanıcıları belirlenen mesafe tercihine göre eşleştirmek için kullanılır. Cihaz izni olmadan konum alınmaz. Konum iznini işletim sistemi ayarlarından kapatabilirsin; ancak mesafe tabanlı eşleştirme bu durumda çalışmayabilir.',
      ),
      LegalSection(
        title: 'Tam konum diğer kullanıcılara gösterilmez',
        body: 'Enlem ve boylam eşleştirme hesabında kullanılabilir; diğer kullanıcılara harita pini veya tam koordinat olarak gösterilmez. Profilde şehir/ülke gibi daha genel bir konum bilgisi kullanılabilir.',
      ),
      LegalSection(
        title: 'Fotoğraflar nasıl kullanılıyor?',
        body: 'Seçtiğin profil fotoğrafları Meet6 sunucusuna yüklenir ve profil/oda/eşleşme ekranlarında diğer uygun kullanıcılara gösterilir. Uygulama yüklemeden önce fotoğrafı kırpmana izin verir ve dosyayı performans için sıkıştırır.',
      ),
      LegalSection(
        title: 'Fotoğraf güvenliği',
        body: 'Meet6 mevcut uygulama akışında profil fotoğraflarına biyometrik yüz tanıma uygulamaz. Uygunsuz, başkasına ait veya yanıltıcı fotoğraflar şikâyet/moderasyon kapsamında kaldırılabilir. Profil fotoğraflarını değiştirebilir ve hesabını silerek aktif profil medyanın silinme sürecini başlatabilirsin.',
      ),
    ],
  );

  static const terms = LegalDocument(
    id: 'terms',
    title: 'Kullanım Şartları',
    subtitle: 'Meet6 kullanırken uyman gereken temel şartlar.',
    icon: Icons.description_outlined,
    sections: [
      LegalSection(
        title: 'Hizmeti kullanma şartı',
        body: 'Meet6 yalnızca 18 yaş ve üzerindeki kişiler içindir. Hesabında doğru yaş bilgisi vermeli, hesabını başkasına kullandırmamalı ve oturum güvenliğini korumalısın. Hizmeti kullanman bu şartları ve uygulamadaki topluluk/güvenlik kurallarını kabul ettiğin anlamına gelir.',
      ),
      LegalSection(
        title: '6 kişilik oda ve eşleşme',
        body: 'Meet6, uygunluk filtrelerine göre kullanıcıları 6 kişilik geçici odalarda buluşturur. Oda süresi, uzatma oylaması ve gizli seçim kuralları uygulamanın güncel ürün akışına göre yürür. Karşılıklı seçim olması özel mesaj hakkı doğurabilir; eşleşme veya belirli bir sonuç garanti edilmez.',
      ),
      LegalSection(
        title: 'Yasak davranışlar',
        body: 'Taciz, tehdit, nefret söylemi, cinsel sömürü, reşit olmayan kişilere yönelik içerik veya iletişim, dolandırıcılık, sahte kimlik, izinsiz ticari mesaj, spam, yasa dışı içerik, başka kişilerin kişisel verilerini izinsiz paylaşma ve güvenlik mekanizmalarını aşma yasaktır.',
      ),
      LegalSection(
        title: 'Moderasyon ve hesap işlemleri',
        body: 'Meet6 güvenlik amacıyla içerik veya hesapları inceleyebilir; kuralları ihlal eden içerikleri kaldırabilir, özellikleri sınırlandırabilir, eşleştirmeyi engelleyebilir veya hesabı askıya alıp kapatabilir. Kullanıcılar diğer hesapları engelleyebilir ve şikâyet edebilir.',
      ),
      LegalSection(
        title: 'Hizmetin sürekliliği',
        body: 'Bakım, güvenlik, teknik arıza veya zorunlu nedenlerle hizmet geçici olarak kesilebilir ya da özellikler değişebilir. Meet6, uygulama içinde tanışılan kişilerin uygulama dışındaki davranışlarını kontrol edemez; yüz yüze buluşmalarda kişisel güvenlik önlemlerini almak kullanıcıların sorumluluğundadır.',
      ),
    ],
  );

  static const adultAndSafety = LegalDocument(
    id: 'adult-safety',
    title: '18+ ve Güvenlik Kuralları',
    subtitle: 'Yaş sınırı ve güvenli kullanım kuralları.',
    icon: Icons.verified_user_outlined,
    sections: [
      LegalSection(
        title: 'Kesin 18+ kuralı',
        body: 'Meet6, 18 yaşından küçük kişiler tarafından kullanılamaz. Profil oluştururken doğum tarihi 18+ olacak şekilde doğrulanır. Yanlış yaş beyanı veya reşit olmayan bir kişiye ait olduğu düşünülen hesap güvenlik gerekçesiyle kısıtlanabilir veya kapatılabilir.',
      ),
      LegalSection(
        title: 'Reşit olmayan kullanıcı şüphesi',
        body: 'Bir hesabın 18 yaşından küçük bir kişiye ait olduğunu düşünüyorsan hesap/profil üzerindeki şikâyet özelliğini kullan. Reşit olmayan kişilere yönelik cinsel içerik, istismar veya sömürüye ilişkin içerik ve davranışlar kesinlikle yasaktır ve gerekli durumlarda yetkili mercilere bildirilebilir.',
      ),
      LegalSection(
        title: 'Yüz yüze buluşma güvenliği',
        body: 'İlk buluşmalarda kamusal ve yoğun bir yer seç; güvendiğin bir kişiye planını bildir; ulaşımını mümkünse kendin ayarla; para, şifre, doğrulama kodu veya hassas finansal bilgilerini paylaşma. Rahatsız olduğunda iletişimi kes, engelle ve gerekirse şikâyet et.',
      ),
      LegalSection(
        title: 'Acil durumlar',
        body: 'Meet6 bir acil yardım hizmeti değildir. Fiziksel güvenliğine yönelik acil bir risk varsa uygulama içi destek yerine bulunduğun yerdeki resmi acil yardım ve kolluk kanallarına başvur.',
      ),
    ],
  );

  static const documents = <LegalDocument>[
    kvkkNotice,
    privacyPolicy,
    locationAndPhotos,
    terms,
    adultAndSafety,
  ];
}
