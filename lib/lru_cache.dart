import 'dart:collection';

class LRUCache<K, V> {
  final LinkedHashMap<K, V> _cache = LinkedHashMap();
  final V? Function(K) valueGetter;
  final int _capacity;

  LRUCache(this._capacity, this.valueGetter);

  V? operator [](K key) {
    V? v = _cache.remove(key);
    if (v == null) {
      v = valueGetter(key);
      if (v == null) {
        return null;
      }
      _cache[key] = v;
      if (_cache.length > _capacity) {
        _cache.remove(_cache.keys.first);
      }
    } else {
      _cache[key] = v;
    }
    return v;
  }

  V? remove(K key) {
    return _cache.remove(key);
  }
}
