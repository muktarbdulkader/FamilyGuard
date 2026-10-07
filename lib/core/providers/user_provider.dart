import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'auth_provider.dart';

// Current user data provider
final currentUserDataProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user != null) {
        return UserService().getUserStream(user.uid);
      }
      return Stream.value(null);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});