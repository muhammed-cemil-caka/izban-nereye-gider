/// Firebase web/REST yapılandırması.
///
/// Bu değerler gizli değildir; istemciye zaten açıkta gider ve projeyi
/// tanımlamaktan başka iş görmez. Güvenlik sınırı Firestore kurallarıdır
/// (backend/firestore.rules).
class FirebaseAyari {
  static const projeKimligi = 'izban-nereye-gider';
  static const apiAnahtari = 'AIzaSyCTZ4jFWdscorX5XXAVe21t_TnN1w4OZDw';

  static String get firestoreTaban =>
      'https://firestore.googleapis.com/v1/projects/$projeKimligi'
      '/databases/(default)/documents';
}
