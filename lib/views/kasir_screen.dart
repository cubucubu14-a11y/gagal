import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../services/sync_service.dart';
import 'setup_screen.dart';

class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  int _currentIndex = 0;
  final List<String> products = ['Cireng', 'Kentang', 'Chicken Roll', 'Tahu Crispy'];
  final List> cart = [];
  int? editingRawId;

  late final Box settingsBox;

  @override
  void initState() {
    super.initState();
    settingsBox = Hive.box('settingsBox');
    SyncService.triggerSync();
  }

  void _addToCart(String productName) async {
    int? price = await _showNumpadDialog(productName);
    if (price != null && price > 0) {
      setState(() {
        cart.add({'name': productName, 'price': price});
      });
    }
  }

  Future<int?> _showNumpadDialog(String productName) async {
    String input = '';
    return showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Input Harga: $productName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'Rp ${input.isEmpty ? '0' : NumberFormat('#,###', 'id_ID').format(int.parse(input))}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'DEL', '0', '000'].map((val) {
                      return ElevatedButton(
                        onPressed: () {
                          setStateDialog(() {
                            if (val == 'DEL') {
                              if (input.isNotEmpty) input = input.substring(0, input.length - 1);
                            } else if (val == '000') {
                              if (input.isNotEmpty) input += '000';
                            } else {
                              input += val;
                            }
                          });
                        },
                        child: Text(val, style: const TextStyle(fontSize: 18)),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                ElevatedButton(
                  onPressed: () {
                    int val = int.tryParse(input) ?? 0;
                    Navigator.pop(context, val);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _checkout(String method) async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keranjang masih kosong!')));
      return;
    }

    int total = cart.fold(0, (sum, item) => sum + (item['price'] as int));
    DateTime now = DateTime.now();
    String dateStr = DateFormat('yyyy-MM-dd').format(now);
    String timeStr = DateFormat('HH:mm:ss').format(now);
    
    int rawId = editingRawId ?? DateTime.now().millisecondsSinceEpoch;
    String branch = settingsBox.get('branchName') ?? 'DEFAULT';

    final transactionData = {
      'rawId': rawId,
      'id': 'TRX-$rawId',
      'dateOnly': dateStr,
      'timeOnly': timeStr,
      'paymentMethod': method,
      'total': total,
      'tab': branch,
      'items': List.from(cart),
      'synced': false,
    };

    final trxBox = Hive.box('transactionsBox');
    await trxBox.put(rawId, transactionData);

    setState(() {
      cart.clear();
      editingRawId = null;
    });

    await SyncService.triggerSync();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi berhasil disimpan!')));
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PILIH PRODUK', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.5, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () => _addToCart(products[index]),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.orange.shade50, border: Border.all(color: Colors.orange.shade200), borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.center,
                    child: Text(products[index], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('KERANJANG PESANAN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: cart.isEmpty
                    ? const Center(child: Text('Keranjang kosong'))
                    : ListView.builder(
                        itemCount: cart.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(cart[index]['name']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Rp ${NumberFormat('#,###', 'id_ID').format(cart[index]['price'])}'),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => setState(() => cart.removeAt(index)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  'Rp ${NumberFormat('#,###', 'id_ID').format(cart.fold(0, (sum, item) => sum + (item['price'] as int)))}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), onPressed: () => _checkout('QRIS'), child: const Text('QRIS'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () => _checkout('Tunai'), child: const Text('TUNAI'))),
              ],
            ),
          ],
        ),
      ),
      ValueListenableBuilder(
        valueListenable: Hive.box('transactionsBox').listenable(),
        builder: (context, Box box, _) {
          final keys = box.keys.toList().reversed.toList();
          if (keys.isEmpty) {
            return const Center(child: Text('Belum ada riwayat transaksi'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final trx = box.get(keys[index]);
              bool synced = trx['synced'] ?? false;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Rp ${NumberFormat('#,###', 'id_ID').format(trx['total'])} (${trx['paymentMethod']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: synced ? Colors.green.shade100 : Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                            child: Text(synced ? 'Synced' : 'Pending', style: TextStyle(fontSize: 11, color: synced ? Colors.green.shade800 : Colors.orange.shade800, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${trx['dateOnly']} ${trx['timeOnly']} • Tab: ${trx['tab']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                            label: const Text('Edit', style: TextStyle(color: Colors.blue)),
                            onPressed: () {
                              setState(() {
                                cart.clear();
                                cart.addAll(List>.from(trx['items']));
                                editingRawId = trx['rawId'];
                                _currentIndex = 0;
                              });
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                            label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                            onPressed: () async {
                              bool confirm = await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Hapus Transaksi?'),
                                  content: const Text('Transaksi ini akan dihapus dari aplikasi dan Google Sheets.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              ) ?? false;

                              if (!mounted) return;
                              if (confirm) {
                                final deleteQueueBox = Hive.box('deleteQueueBox');
                                await deleteQueueBox.add({'id': trx['rawId'], 'tab': trx['tab']});
                                await box.delete(trx['rawId']);
                                await SyncService.triggerSync();
                              }
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Kasir: ${settingsBox.get('branchName') ?? '-'}'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await SyncService.triggerSync();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sinkronisasi manual dijalankan!')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SetupScreen()));
            },
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.orange,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Kasir'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat'),
        ],
      ),
    );
  }
}
