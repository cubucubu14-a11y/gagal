import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class SyncService {
  static Future<void> triggerSync() async {
    final settingsBox = Hive.box('settingsBox');
    final trxBox = Hive.box('transactionsBox');
    final deleteQueueBox = Hive.box('deleteQueueBox');

    final String? scriptUrl = settingsBox.get('scriptUrl');
    if (scriptUrl == null || scriptUrl.isEmpty) return;

    // 1. Eksekusi Delete Queue ke Apps Script
    final List deleteKeys = deleteQueueBox.keys.toList();
    for (var key in deleteKeys) {
      final data = deleteQueueBox.get(key);
      try {
        final String rawIdOnly = data['id'].toString().replaceAll('TRX-', '');
        
        final response = await http.post(
          Uri.parse(scriptUrl),
          body: {
            'action': 'delete',
            'tab': data['tab'].toString(),
            'id': rawIdOnly,
          },
        );
        
        print('Response Delete Status: ${response.statusCode}');
        print('Response Delete Body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 302) {
          await deleteQueueBox.delete(key);
        }
      } catch (e) {
        print('Gagal menghapus antrean: $e');
      }
    }

    // 2. Eksekusi Pending Upserts (Data Baru / Edit)
    for (var key in trxBox.keys) {
      final trx = trxBox.get(key);
      if (trx != null && trx['synced'] == false) {
        try {
          final String rawIdOnly = trx['rawId'].toString().replaceAll('TRX-', '');

          final response = await http.post(
            Uri.parse(scriptUrl),
            body: {
              'action': 'upsert',
              'tab': trx['tab'].toString(),
              'id': rawIdOnly,
              'tanggal': trx['dateOnly'].toString(),
              'jam': trx['timeOnly'].toString(),
              'nominal': trx['total'].toString(),
              'metode': trx['paymentMethod'].toString(),
            },
          );

          print('Response Upsert Status: ${response.statusCode}');
          print('Response Upsert Body: ${response.body}');

          // Jika Apps Script sukses merespon (biasanya status 200)
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
