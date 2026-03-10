import 'package:flutter/foundation.dart';

class UserListsStore {
  static final UserListsStore instance = UserListsStore._();
  UserListsStore._();

  final ValueNotifier<List<Map<String, dynamic>>> coordinators = ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<List<Map<String, dynamic>>> classReps = ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<List<Map<String, dynamic>>> sergeants = ValueNotifier<List<Map<String, dynamic>>>([]);

  void setCoordinators(List<Map<String, dynamic>> list) {
    coordinators.value = List<Map<String, dynamic>>.from(list);
  }

  void setClassRepresentatives(List<Map<String, dynamic>> list) {
    classReps.value = List<Map<String, dynamic>>.from(list);
  }

  void setSergeants(List<Map<String, dynamic>>? list) {
    if (list == null) {
      sergeants.value = const [];
    } else {
      sergeants.value = List<Map<String, dynamic>>.from(list);
    }
  }

  void removeCoordinatorByUsername(String username) {
    coordinators.value = coordinators.value.where((c) => c['username'] != username).toList();
  }

  void removeClassRepByUsernameOrKtuId(String id) {
    classReps.value = classReps.value.where((r) => r['username'] != id && r['ktu_id'] != id).toList();
  }

  void removeSergeantByEmail(String email) {
    sergeants.value = sergeants.value.where((s) => s['email'] != email).toList();
  }

  void addCoordinator(Map<String, dynamic> coord) {
    final list = List<Map<String, dynamic>>.from(coordinators.value);
    list.add(coord);
    coordinators.value = list;
  }

  void addClassRep(Map<String, dynamic> rep) {
    final list = List<Map<String, dynamic>>.from(classReps.value);
    list.add(rep);
    classReps.value = list;
  }

  void addSergeant(Map<String, dynamic> sergeant) {
    final list = List<Map<String, dynamic>>.from(sergeants.value);
    list.add(sergeant);
    sergeants.value = list;
  }
}