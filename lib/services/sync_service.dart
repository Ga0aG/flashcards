/// 占位的同步服务。
///
/// 数据已直接读写 Firestore（DatabaseService 改造完成后），
/// SDK 自带 IndexedDB 离线缓存与多设备实时同步，因此不再需要
/// 显式的 migrate/pull/merge 流程。保留这个空实现避免改动 AuthProvider。
class SyncService {
  Future<void> migrateIfNeeded(String uid) async {}
  Future<void> pullLatest(String uid) async {}
}
