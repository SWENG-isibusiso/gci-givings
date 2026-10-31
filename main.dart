import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Provides kIsWeb
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  runApp(const GLGivingsApp());
}

// Global state variables
List<Map<String, String>> globalGivingHistory = [];
Map<String, String> globalMemberProfile = {
  'name': 'Church Member',
  'phone': '0712345678',
  'branch': 'GospelLife Main Sanctuary',
  'email': 'donor@example.com',
};
Uint8List? globalProfileImageBytes; // Cross-platform byte storage for images

class GLGivingsApp extends StatelessWidget {
  const GLGivingsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue,
          secondary: Colors.red,
        ),
        useMaterial3: true,
      ),
      home: const DecorativeSplashScreen(),
    );
  }
}

class DecorativeSplashScreen extends StatefulWidget {
  const DecorativeSplashScreen({super.key});

  @override
  State<DecorativeSplashScreen> createState() => _DecorativeSplashScreenState();
}

class _DecorativeSplashScreenState extends State<DecorativeSplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.red.withValues(alpha: 0.2),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: CircleAvatar(
              radius: 120,
              backgroundColor: Colors.blue.withValues(alpha: 0.2),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.yellow, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRKUllNameTYo14py7Kg99dkvM_9ji7jLUR9eUvlgWOQg&s=10',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.church, size: 65, color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  'GospelLife',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                const Text(
                  'GCI Giving',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 45,
                  height: 45,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Preparing your giving portal...',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const GivingHomeScreen(),
      const HistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        indicatorColor: Colors.yellow,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.volunteer_activism_outlined, color: Colors.black),
            selectedIcon: Icon(Icons.volunteer_activism, color: Colors.blue),
            label: 'Give',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined, color: Colors.black),
            selectedIcon: Icon(Icons.history, color: Colors.green),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: Colors.black),
            selectedIcon: Icon(Icons.person, color: Colors.red),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class GivingHomeScreen extends StatefulWidget {
  const GivingHomeScreen({super.key});

  @override
  State<GivingHomeScreen> createState() => _GivingHomeScreenState();
}

class _GivingHomeScreenState extends State<GivingHomeScreen> {
  String paymentProvider = 'M-Pesa';
  String selectedCategory = 'Tithe';

  // Text Controllers
  final TextEditingController amountController = TextEditingController();
  late TextEditingController phoneController;
  final TextEditingController bankNameController = TextEditingController(text: 'Equity Bank');
  final TextEditingController accountNumberController = TextEditingController();

  // Selection Lists
  final List<String> categories = [
    'Tithe',
    'Offering',
    'Building Fund',
    'Missions',
    'Thanksgiving',
  ];
  final List<int> quickAmounts = [100, 500, 1000, 2000];

  @override
  void initState() {
    super.initState();
    phoneController = TextEditingController(
      text: globalMemberProfile['phone'] ?? '',
    );
    amountController.text = '100';
  }

  @override
  void dispose() {
    amountController.dispose();
    phoneController.dispose();
    bankNameController.dispose();
    accountNumberController.dispose();
    super.dispose();
  }

  // 💾 FIRESTORE SAVE FUNCTION
  Future<void> _saveContributionToFirestore({
    required String donorName,
    required String email,
    required String category,
    required double amount,
    required String provider,
    required String paymentReference,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('contributions').add({
        'donorName': donorName,
        'email': email,
        'category': category,
        'amount': amount,
        'paymentProvider': provider,
        'paymentReference': paymentReference,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Contribution saved to Firestore');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save contribution: $e')),
      );
    }
  }

  // 💳 PAYMENT HANDLER METHOD
  void handleGive() async {
    debugPrint(">>> PAY BUTTON TAP DETECTED <<<");

    final amount = amountController.text.trim();
    final phone = phoneController.text.trim();
    final accountNumber = accountNumberController.text.trim();

    // Validation checks
    if (amount.isEmpty || double.tryParse(amount) == null || double.parse(amount) <= 0) {
      debugPrint(">>> Validation Error: Invalid or empty amount <<<");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid giving amount'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if ((paymentProvider == 'M-Pesa' || paymentProvider == 'Airtel Money') && phone.isEmpty) {
      debugPrint(">>> Validation Error: Empty phone number <<<");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid mobile money number'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (paymentProvider == 'Bank' && accountNumber.isEmpty) {
      debugPrint(">>> Validation Error: Empty account number <<<");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your bank account number'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final double parsedAmount = double.parse(amount);
    final Uri serverUrl = Uri.parse('https://gci-givings.vercel.app/api/paystack-initialize');

    debugPrint(">>> PAYMENT PROCESS STARTED <<<");

    try {
      final userEmail = globalMemberProfile['email'] ?? 'donor@example.com';
      final userName = globalMemberProfile['name'] ?? 'Anonymous';

      debugPrint('SENDING PAYMENT TO URL: $serverUrl');

      final response = await http.post(
        serverUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': userEmail,
          'amount': parsedAmount,
          'paymentProvider': paymentProvider,
          'phone': phone,
          'accountNumber': accountNumber,
          'category': selectedCategory,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('connection timed out. Please check if the server is running.');
        },
      );

      debugPrint("Server Status Code: ${response.statusCode}");
      debugPrint("Server Response Body: ${response.body}");

      if (response.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server Error: ${response.statusCode}')),
        );
        return;
      }

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data['status'] == true) {
        final String authUrl = data['data']['authorization_url'];
        final String ref = data['data']['reference'] ?? 'REF_${DateTime.now().millisecondsSinceEpoch}';

        debugPrint("Paystack Auth URL: $authUrl");

        await _saveContributionToFirestore(
          donorName: userName,
          email: userEmail,
          category: selectedCategory,
          amount: parsedAmount,
          provider: paymentProvider,
          paymentReference: ref,
        );

        setState(() {
          globalGivingHistory.insert(0, {
            'category': selectedCategory,
            'provider': paymentProvider,
            'amount': 'KSh $amount',
            'date': DateTime.now().toString().split(' ')[0],
          });
        });

        final Uri paystackUri = Uri.parse(authUrl);
        await launchUrl(
          paystackUri,
          webOnlyWindowName: '_self',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${data['message']}')),
        );
      }
    } catch (e, stackTrace) {
      debugPrint(">>> PAYMENT ERROR: $e");
      debugPrint(">>> STACKTRACE: $stackTrace");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to backend: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('GCI Givings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.yellow, width: 3),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRKUllNameTYo14py7Kg99dkvM_9ji7jLUR9eUvlgWOQg&s=10',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.church, size: 45, color: Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'GospelLife',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Card(
              color: Colors.yellow[50],
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.yellow, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Select Payment Method',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('M-Pesa', style: TextStyle(fontSize: 12))),
                            selected: paymentProvider == 'M-Pesa',
                            selectedColor: Colors.green,
                            labelStyle: TextStyle(
                              color: paymentProvider == 'M-Pesa' ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => paymentProvider = 'M-Pesa');
                            },
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Airtel', style: TextStyle(fontSize: 12))),
                            selected: paymentProvider == 'Airtel Money',
                            selectedColor: Colors.red,
                            labelStyle: TextStyle(
                              color: paymentProvider == 'Airtel Money' ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => paymentProvider = 'Airtel Money');
                            },
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Bank', style: TextStyle(fontSize: 12))),
                            selected: paymentProvider == 'Bank',
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(
                              color: paymentProvider == 'Bank' ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => paymentProvider = 'Bank');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Giving Category',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      items: categories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) => setState(() => selectedCategory = val!),
                    ),
                    const SizedBox(height: 16),
                    if (paymentProvider == 'M-Pesa' || paymentProvider == 'Airtel Money')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mobile Money Number',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: 'Enter phone number',
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bank Account Details',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: accountNumberController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Enter account number',
                              labelText: 'Account Number',
                              prefixIcon: const Icon(Icons.numbers, color: Colors.blue),
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Amount (KSh)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter amount',
                        prefixText: 'KSh ',
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      alignment: WrapAlignment.center,
                      children: quickAmounts.map((amt) {
                        return OutlinedButton(
                          onPressed: () => setState(() => amountController.text = amt.toString()),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blue, width: 1.5),
                            backgroundColor: Colors.white,
                          ),
                          child: Text('$amt', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: handleGive,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: paymentProvider == 'M-Pesa'
                            ? Colors.green
                            : paymentProvider == 'Airtel Money'
                                ? Colors.red
                                : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Pay with $paymentProvider', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Giving History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red,
        centerTitle: true,
      ),
      body: globalGivingHistory.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 70, color: Colors.black45),
                  SizedBox(height: 10),
                  Text('No gifts recorded yet.', style: TextStyle(fontSize: 16, color: Colors.black54)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: globalGivingHistory.length,
              itemBuilder: (context, index) {
                final item = globalGivingHistory[index];
                final provider = item['provider'];
                final color = provider == 'M-Pesa'
                    ? Colors.green
                    : provider == 'Airtel Money'
                        ? Colors.red
                        : Colors.blue;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: color, width: 1),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(
                        provider == 'Bank' ? Icons.account_balance : Icons.phone_android,
                        color: color,
                      ),
                    ),
                    title: Text(item['category']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    subtitle: Text('${item['provider']} • ${item['date']}'),
                    trailing: Text(
                      item['amount']!,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController branchController;
  late TextEditingController emailController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: globalMemberProfile['name']);
    phoneController = TextEditingController(text: globalMemberProfile['phone']);
    branchController = TextEditingController(text: globalMemberProfile['branch']);
    emailController = TextEditingController(text: globalMemberProfile['email']);
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    branchController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Wrap(
              children: [
                const ListTile(
                  title: Text(
                    'Set Profile Picture From:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blue),
                  title: const Text('Take Photo (Camera)'),
                  onTap: () {
                    Navigator.pop(context);
                    pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.green),
                  title: const Text('Pick from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        final Uint8List imageBytes = await image.readAsBytes();
        setState(() {
          globalProfileImageBytes = imageBytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load image: $e')),
        );
      }
    }
  }

  void saveProfile() {
    setState(() {
      globalMemberProfile['name'] = nameController.text.isEmpty ? 'Church Member' : nameController.text;
      globalMemberProfile['phone'] = phoneController.text;
      globalMemberProfile['branch'] = branchController.text.isEmpty ? 'GospelLife Sanctuary' : branchController.text;
      globalMemberProfile['email'] = emailController.text.isEmpty ? 'donor@example.com' : emailController.text;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile details saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Member Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: showImagePickerOptions,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.yellow, width: 3),
                      color: Colors.blue[50],
                    ),
                    child: ClipOval(
                      child: globalProfileImageBytes != null
                          ? Image.memory(
                              globalProfileImageBytes!,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.person, size: 65, color: Colors.blue),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: branchController,
              decoration: const InputDecoration(labelText: 'Church Branch', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveProfile,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              child: const Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }
}