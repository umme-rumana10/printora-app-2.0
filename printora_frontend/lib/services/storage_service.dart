class StorageService {
  static final Map<String, dynamic> _memoryCache = {};

  static void save(String key, dynamic value) {
    _memoryCache[key] = value;
  }

  static dynamic get(String key) {
    return _memoryCache[key];
  }

  static void remove(String key) {
    _memoryCache.remove(key);
  }
}
