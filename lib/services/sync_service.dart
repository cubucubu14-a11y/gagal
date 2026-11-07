import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class SyncService {
  static Future<void> triggerSync() async {
    final settingsBox = Hive.box('settingsBox');
    final trxBox = Hive.box('transactionsBox');
    final deleteQueueBox = Hive.box('deleteQueueBox');

    final String? scriptUrl = settingsBox.get('scriptUrl');
    if (scriptUrl == null || scriptUrl.isEmpty) return;

    // 1. Eksekusi Delete Queue ke Backend Apps Script Lama
    final List deleteKeys = deleteQueueBox.keys.toList();
    for (var key in deleteKeys) {
      final data = deleteQueueBox.get(key);
      try {
        final response = await http.post(
          Uri.parse(scriptUrl),
          body: {
            'action': 'delete',
            'tab': data['tab'],
            'id': data['id'].toString(),
          },
        );
        if (response.statusCode == 200 || response.statusCode == 302) {
          await deleteQueueBox.delete(key);
        }
      } catch (e) {
        print('Gagal menghapus antrean: $e');
      }
    }

    // 2. Eksekusi Pending Upserts (Data Belum Synced)
    for (var key in trxBox.keys) {
      final trx = trxBox.get(key);
      if (trx != null && trx['synced'] == false) {
        try {
          final response = await http.post(
            Uri.parse(scriptUrl),
            body: {
              'action': 'upsert',
              'tab': trx['tab'],
              'id': trx['rawId'].toString(),
              'tanggal': trx['dateOnly'],
              'jam': trx['timeOnly'],
              'nominal': trx['total'].toString(),
              'metode': trx['paymentMethod'],
            },
          );

          if (response.statusCode == 200 || response.statusCode == 302) {
            trx['synced'] = true;
            await trxBox.put(key, trx);
          }
        } catch (e) {
          print('Gagal sinkronisasi upsert: $e');
        }
      }
    }
  }
}
