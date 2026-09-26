import '../models/user_model.dart';

class AuthService {
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  Future<UserModel> signInAnonymous() async {
    _currentUser = UserModel(
      id: "guest_${DateTime.now().millisecondsSinceEpoch}",
      email: "guest@printora.app",
      name: "Guest User",
    );
    return _currentUser!;
  }
}
