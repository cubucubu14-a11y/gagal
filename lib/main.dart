import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

void main() {
  runApp(const KasirApp());
}

class KasirApp extends StatelessWidget {
  const KasirApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kasir Woii',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==========================================
// 1. SPLASH / SETUP AWAL URL APPS SCRIPT
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkUrl();
  }

  void _checkUrl() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedUrl = prefs.getString('SCRIPT_URL');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const KasirHomePage()),
      );
    }
  }

  void _saveUrl() async {
    if (_urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL Apps Script tidak boleh kosong!')),
      );
      return;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('SCRIPT_URL', _urlController.text.trim());
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const KasirHomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Awal - Kasir Woii')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Masukkan URL Google Apps Script Anda:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'https://script.google.com/macros/s/...',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveUrl,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('Simpan & Masuk Aplikasi', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. HALAMAN UTAMA KASIR
// ==========================================
class KasirHomePage extends StatefulWidget {
  const KasirHomePage({Key? key}) : super(key: key);

  @override
  State<KasirHomePage> createState() => _KasirHomePageState();
}

class CartItem {
  final String name;
  final int price;
  CartItem({required this.name, required this.price});
}

class _KasirHomePageState extends State<KasirHomePage> {
  final List<String> _defaultProducts = ['Cireng', 'Kentang', 'Chicken Roll', 'Tahu Crispy', 'Bakso Bakar'];
  final List<CartItem> _cart = [];
  
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  void _initBluetooth() async {
    bool? isConnected = await bluetooth.isConnected;
    List<BluetoothDevice> devices = [];
    try {
      devices = await bluetooth.getBondedDevices();
    } catch (_) {}

    setState(() {
      _devices = devices;
      _connected = isConnected ?? false;
    });
  }

  int get _totalAmount {
    return _cart.fold(0, (sum, item) => sum + item.price);
  }

  // Buka Pop-up Numpad Standar Kasir
  void _openNumpad(String productName) {
    String inputVal = "";
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void appendChar(String char) {
              setDialogState(() {
                if (char == '000') {
                  if (inputVal.isNotEmpty) inputVal += '000';
                } else if (char == 'DEL') {
                  if (inputVal.isNotEmpty) {
                    inputVal = inputVal.substring(0, inputVal.length - 1);
                  }
                } else {
                  inputVal += char;
                }
              });
            }

            int getParsedPrice() {
              return int.tryParse(inputVal) ?? 0;
            }

            return AlertDialog(
              title: Text('Input Harga: $productName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[100],
                    ),
                    child: Text(
                      inputVal.isEmpty ? 'Rp 0' : 'Rp ${NumberFormat('#,###', 'id_ID').format(getParsedPrice())}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Numpad Grid
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.5,
                    children: [
                      ...['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '000', 'DEL'].map((val) {
                        return ElevatedButton(
                          onPressed: () => appendChar(val),
                          child: Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        );
                      }),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () {
                    int price = getParsedPrice();
                    if (price > 0) {
                      setState(() {
                        _cart.add(CartItem(name: productName, price: price));
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Tambah ke Keranjang'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog Pengaturan (Ubah URL & Printer)
  void _showSettingsDialog() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentUrl = prefs.getString('SCRIPT_URL') ?? '';
    TextEditingController urlController = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pengaturan Aplikasi'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('URL Google Apps Script:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('Printer Thermal Bluetooth (58mm):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<BluetoothDevice>(
                  value: _selectedDevice,
                  hint: const Text('Pilih Perangkat Printer'),
                  items: _devices.map((device) {
                    return DropdownMenuItem(
                      value: device,
                      child: Text(device.name ?? 'Unknown Device'),
                    );
                  }).toList(),
                  onChanged: (device) {
                    setState(() {
                      _selectedDevice = device;
                    });
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    if (_selectedDevice != null) {
                      bluetooth.connect(_selectedDevice!).then((isConnected) {
                        setState(() {
                          _connected = true;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Printer Berhasil Terhubung!')),
                        );
                      }).catchError((err) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal terhubung: $err')),
                        );
                      });
                    }
                  },
                  child: const Text('Connect Printer'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
            ElevatedButton(
              onPressed: () async {
                await prefs.setString('SCRIPT_URL', urlController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL berhasil diperbarui!')),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  // Proses Simpan Transaksi & Cetak Struk Bluetooth
  void _checkout(String paymentMethod) async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang masih kosong!')),
      );
      return;
    }

    // 1. Kirim ke Google Apps Script
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('SCRIPT_URL');
    
    if (url != null && url.isNotEmpty) {
      try {
        List> itemsList = _cart.map((e) => {'name': e.name, 'price': e.price}).toList();
        await http.post(
          Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            'date': DateTime.now().toIso8601String(),
            'paymentMethod': paymentMethod,
            'total': _totalAmount,
            'items': itemsList,
          }),
        );
      } catch (_) {}
    }

    // 2. Cetak Struk ke Printer Thermal 58mm (Baris per Baris)
    if (_connected) {
      bluetooth.printNewLine();
      bluetooth.printCustom("CIRENG WOII", 1, 1);
      bluetooth.printCustom("--------------------------------", 1, 1);
      
      for (var item in _cart) {
        String line = "1x ${item.name}".padRight(18) + "Rp ${NumberFormat('#,###', 'id_ID').format(item.price)}".padLeft(14);
        bluetooth.printCustom(line, 0, 0);
      }

      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printCustom("METODE: $paymentMethod", 0, 0);
      bluetooth.printCustom("TOTAL: Rp ${NumberFormat('#,###', 'id_ID').format(_totalAmount)}", 1, 1);
      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printCustom("TERIMA KASIH", 1, 1);
      bluetooth.printNewLine();
      bluetooth.paperCut();
    }

    setState(() {
      _cart.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaksi berhasil disimpan & dicetak!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir Woii'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Grid Menu Produk
          Expanded(
            flex: 5,
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _defaultProducts.length,
              itemBuilder: (context, index) {
                String product = _defaultProducts[index];
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[100],
                    foregroundColor: Colors.black87,
                  ),
                  onPressed: () => _openNumpad(product),
                  child: Text(
                    product,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Area Keranjang Belanja Rinci
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Keranjang Pesanan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _cart.length,
                      itemBuilder: (context, index) {
                        final item = _cart[index];
                        return ListTile(
                          dense: true,
                          title: Text('1x ${item.name}', style: const TextStyle(fontWeight: FontWeight.w500)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Rp ${NumberFormat('#,###', 'id_ID').format(item.price)}'),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _cart.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        'Rp ${NumberFormat('#,###', 'id_ID').format(_totalAmount)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                          onPressed: () => _checkout('QRIS'),
                          icon: const Icon(Icons.qr_code),
                          label: const Text('QRIS'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: () => _checkout('Tunai'),
                          icon: const Icon(Icons.money),
                          label: const Text('Tunai'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
