import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// หน้าผู้จัดการ - ดู Report ของ Feedback และคนขับรถ
class ManagerPage extends StatefulWidget {
  const ManagerPage({super.key});

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage>
    with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  // Search & Filter
  String _feedbackSearch = '';
  String _feedbackTypeFilter = 'all'; // all, complain, rating

  String _driverSearch = '';
  String _driverRouteFilter = 'all'; // all, green, red, blue

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('หน้าผู้จัดการ'),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'ออกจากระบบ',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.feedback), text: 'Feedback'),
            Tab(icon: Icon(Icons.person), text: 'คนขับรถ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFeedbackTab(), _buildDriverTab()],
      ),
    );
  }

  /// Tab 1: รายงาน Feedback (จาก Firestore collection 'feedback')
  Widget _buildFeedbackTab() {
    return Column(
      children: [
        // Search & Filter Bar
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              // Search
              TextField(
                decoration: InputDecoration(
                  hintText: 'ค้นหาข้อความ...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (value) => setState(() => _feedbackSearch = value),
              ),
              const SizedBox(height: 8),
              // Filter chips
              Row(
                children: [
                  const Text(
                    'ประเภท: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    'ทั้งหมด',
                    'all',
                    _feedbackTypeFilter,
                    (v) => setState(() => _feedbackTypeFilter = v),
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    'ร้องเรียน',
                    'complain',
                    _feedbackTypeFilter,
                    (v) => setState(() => _feedbackTypeFilter = v),
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    'ให้คะแนน',
                    'rating',
                    _feedbackTypeFilter,
                    (v) => setState(() => _feedbackTypeFilter = v),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Feedback List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('feedback')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
              }

              var feedbacks = snapshot.data?.docs ?? [];

              // Apply filters
              feedbacks = feedbacks.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final message = (data['message'] ?? '')
                    .toString()
                    .toLowerCase();
                final type = data['type'] ?? 'complain';

                // Search filter
                if (_feedbackSearch.isNotEmpty &&
                    !message.contains(_feedbackSearch.toLowerCase())) {
                  return false;
                }

                // Type filter
                if (_feedbackTypeFilter != 'all' &&
                    type != _feedbackTypeFilter) {
                  return false;
                }

                return true;
              }).toList();

              if (feedbacks.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'ไม่พบ Feedback',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: feedbacks.length,
                itemBuilder: (context, index) {
                  final doc = feedbacks[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final message = data['message'] ?? '';
                  final rating = data['rating'] ?? 0;
                  final type = data['type'] ?? 'complain';
                  final timestamp = data['timestamp'] as Timestamp?;
                  final dateStr = timestamp != null
                      ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year} ${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                      : '-';

                  return GestureDetector(
                    onTap: () => _showFeedbackDetail(
                      context,
                      message: message,
                      type: type,
                      rating: rating,
                      dateStr: dateStr,
                    ),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: type == 'complain'
                                        ? Colors.red.shade100
                                        : Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    type == 'complain'
                                        ? 'ร้องเรียน'
                                        : 'ให้คะแนน',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: type == 'complain'
                                          ? Colors.red.shade700
                                          : Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (type == 'rating')
                                  Row(
                                    children: List.generate(5, (i) {
                                      return Icon(
                                        i < rating
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: Colors.amber,
                                        size: 18,
                                      );
                                    }),
                                  ),
                                const Spacer(),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              message,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Tab 2: รายชื่อคนขับรถ (จาก Realtime Database path 'GPS')
  Widget _buildDriverTab() {
    return Column(
      children: [
        // Search & Filter Bar
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              // Search
              TextField(
                decoration: InputDecoration(
                  hintText: 'ค้นหาชื่อคนขับ...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (value) => setState(() => _driverSearch = value),
              ),
              const SizedBox(height: 8),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'สาย: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      'ทั้งหมด',
                      'all',
                      _driverRouteFilter,
                      (v) => setState(() => _driverRouteFilter = v),
                    ),
                    const SizedBox(width: 8),
                    _routeFilterChip('หน้ามอ', 'green', Colors.green),
                    const SizedBox(width: 8),
                    _routeFilterChip('หอพัก', 'red', Colors.red),
                    const SizedBox(width: 8),
                    _routeFilterChip('ICT', 'blue', Colors.blue),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Driver List
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('GPS').onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
              }

              final data = snapshot.data?.snapshot.value;
              if (data == null) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'ยังไม่มีข้อมูลคนขับ',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              // Parse GPS data to get drivers
              List<Map<String, dynamic>> drivers = [];
              if (data is Map) {
                data.forEach((busId, busData) {
                  if (busData is Map) {
                    Map<dynamic, dynamic> driverData = busData;
                    if (busData.containsKey(busId) && busData[busId] is Map) {
                      driverData = busData[busId];
                    }

                    final driverName =
                        driverData['driverName']?.toString() ?? '';
                    final routeColor =
                        driverData['routeColor']?.toString() ?? '';
                    final lat = busData['lat'];
                    final lng = busData['lng'];

                    if (driverName.isNotEmpty) {
                      drivers.add({
                        'busId': busId,
                        'driverName': driverName,
                        'routeColor': routeColor,
                        'isActive': lat != null && lng != null,
                      });
                    }
                  }
                });
              }

              // Apply filters
              drivers = drivers.where((driver) {
                final name = (driver['driverName'] ?? '')
                    .toString()
                    .toLowerCase();
                final route = (driver['routeColor'] ?? '')
                    .toString()
                    .toLowerCase();

                // Search filter
                if (_driverSearch.isNotEmpty &&
                    !name.contains(_driverSearch.toLowerCase())) {
                  return false;
                }

                // Route filter
                if (_driverRouteFilter != 'all' &&
                    route != _driverRouteFilter) {
                  return false;
                }

                return true;
              }).toList();

              if (drivers.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('ไม่พบคนขับ', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: drivers.length,
                itemBuilder: (context, index) {
                  final driver = drivers[index];
                  final busId = driver['busId'] ?? '';
                  final driverName = driver['driverName'] ?? 'ไม่ระบุชื่อ';
                  final routeColor = driver['routeColor'] ?? '';
                  final isActive = driver['isActive'] ?? false;

                  Color routeColorValue = Colors.purple;
                  String routeName = 'ไม่ระบุ';
                  if (routeColor.toLowerCase() == 'green') {
                    routeColorValue = Colors.green;
                    routeName = 'สายหน้ามอ';
                  } else if (routeColor.toLowerCase() == 'red') {
                    routeColorValue = Colors.red;
                    routeName = 'สายหอพัก';
                  } else if (routeColor.toLowerCase() == 'blue') {
                    routeColorValue = Colors.blue;
                    routeName = 'สาย ICT';
                  }

                  return GestureDetector(
                    onTap: () => _showDriverDetail(
                      context,
                      driverName: driverName,
                      busId: busId,
                      routeName: routeName,
                      routeColor: routeColorValue,
                      isActive: isActive,
                    ),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isActive
                              ? routeColorValue
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: routeColorValue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: routeColorValue,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person,
                                    color: routeColorValue,
                                    size: 28,
                                  ),
                                  Text(
                                    busId.replaceAll('bus_', '#'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: routeColorValue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driverName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: routeColorValue,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.route,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'กำลังขับ $routeName',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                    boxShadow: isActive
                                        ? [
                                            BoxShadow(
                                              color: Colors.green.withValues(
                                                alpha: 0.5,
                                              ),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isActive ? 'LIVE' : 'OFF',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(
    String label,
    String value,
    String currentValue,
    Function(String) onSelect,
  ) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9C27B0) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF9C27B0) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _routeFilterChip(String label, String value, Color color) {
    final isSelected = _driverRouteFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _driverRouteFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// แสดง Dialog รายละเอียด Feedback
  void _showFeedbackDetail(
    BuildContext context, {
    required String message,
    required String type,
    required int rating,
    required String dateStr,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: type == 'complain'
                          ? Colors.red.shade100
                          : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type == 'complain' ? Icons.warning : Icons.star,
                          size: 16,
                          color: type == 'complain'
                              ? Colors.red.shade700
                              : Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          type == 'complain' ? 'ร้องเรียน' : 'ให้คะแนน',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: type == 'complain'
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    iconSize: 24,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Rating (if applicable)
              if (type == 'rating') ...[
                Row(
                  children: [
                    const Text(
                      'ความพึงพอใจ: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 24,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              // Message
              const Text(
                'ข้อความ:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              // Date
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    dateStr,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// แสดง Dialog รายละเอียดคนขับ
  void _showDriverDetail(
    BuildContext context, {
    required String driverName,
    required String busId,
    required String routeName,
    required Color routeColor,
    required bool isActive,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Driver Avatar
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: routeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: routeColor, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person, color: routeColor, size: 50),
                    Text(
                      busId.replaceAll('bus_', 'รถ #'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: routeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Driver Name
              Text(
                driverName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Route Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: routeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.route, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'กำลังขับ $routeName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? Colors.green : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 3,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isActive ? 'กำลังให้บริการ' : 'ไม่ได้ให้บริการ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.green.shade700 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Bus Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _infoRow(Icons.directions_bus, 'รหัสรถ', busId),
                    const SizedBox(height: 8),
                    _infoRow(Icons.person, 'ชื่อคนขับ', driverName),
                    const SizedBox(height: 8),
                    _infoRow(Icons.route, 'เส้นทาง', routeName),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ปิด',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
