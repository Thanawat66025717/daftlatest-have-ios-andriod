import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BusStopMapPage extends StatefulWidget {
  const BusStopMapPage({super.key});

  @override
  State<BusStopMapPage> createState() => _BusStopMapPageState();
}

class _BusStopMapPageState extends State<BusStopMapPage> {
  late final MapController _mapController;
  late LatLng _stopLocation;
  String _stopName = '';
  List<Map<String, dynamic>> _allBusStops = [];
  String? _selectedStopId; // เก็บ ID ของป้ายที่กำลังเลือกดูรายละเอียด

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Default to University if no args
    _stopLocation = const LatLng(19.03011372185138, 99.89781512200192);
    _fetchBusStops();
  }

  Future<void> _fetchBusStops() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Bus stop')
          .get();
      final stops = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'lat': double.tryParse(data['lat'].toString()) ?? 0.0,
          'long': double.tryParse(data['long'].toString()) ?? 0.0,
          'route_id': data['route_id'],
        };
      }).toList();

      if (mounted) {
        setState(() {
          _allBusStops = stops;
        });
      }
    } catch (e) {
      debugPrint("Error fetching bus stops: $e");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final lat = double.tryParse(args['lat']?.toString() ?? '');
      final long = double.tryParse(args['long']?.toString() ?? '');
      final name = args['name']?.toString();
      final id = args['id']?.toString(); // รับ ID มาด้วย

      if (lat != null && long != null) {
        _stopLocation = LatLng(lat, long);
      }
      if (name != null) {
        _stopName = name;
      }
      // ถ้ามี ID ส่งมา ให้ set เป็น selectedStopId เลย เพื่อให้โชว์ popup อัตโนมัติ
      if (id != null) {
        _selectedStopId = id;
      }
    }
  }

  // [HELPER] ฟังก์ชันสร้าง Chip สีแสดงสายรถ (S1 = เขียว, S2 = แดง, S3 = น้ำเงิน)
  // รองรับข้อมูลทั้งแบบ List ["S1", "S2"] และ String "S1, S2"
  Widget _buildRouteChips(dynamic routesData) {
    if (routesData == null) {
      return const SizedBox.shrink();
    }

    List<String> routes = [];
    if (routesData is List) {
      routes = routesData.map((e) => e.toString()).toList();
    } else if (routesData is String) {
      routes = routesData.split(',').map((e) => e.trim()).toList();
    }

    if (routes.isEmpty) return const SizedBox.shrink();

    routes.sort();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      spacing: 4,
      children: routes.map((route) {
        Color color = Colors.grey;
        String upperRoute = route.toUpperCase().trim();
        String label = route;

        if (upperRoute.contains('S1')) {
          color = const Color.fromRGBO(68, 182, 120, 1);
        } else if (upperRoute.contains('S2')) {
          color = const Color.fromRGBO(255, 56, 89, 1);
        } else if (upperRoute.contains('S3')) {
          color = const Color.fromRGBO(17, 119, 252, 1);
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_stopName.isNotEmpty ? _stopName : 'ตำแหน่งป้ายรถเมล์'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _stopLocation, // จุดกึ่งกลางเริ่มต้น (ป้ายที่เลือก)
          initialZoom: 18,
          onTap: (_, __) {
            // กดที่ว่างๆ บนแผนที่ ให้ปิด Popup รายละเอียด
            setState(() {
              _selectedStopId = null;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.upbus.app',
          ),
          MarkerLayer(
            markers: [
              // [LAYER 1] แสดงไอคอนป้ายรถเมล์ (ทุกป้ายในระบบ)
              ..._allBusStops.map((stop) {
                bool isSelected = _selectedStopId == stop['id'];

                return Marker(
                  point: LatLng(stop['lat'], stop['long']),
                  width: 40,
                  height: 40,
                  // [FIX] ใช้ bottomCenter เพื่อให้ฐานป้ายปักที่พิกัดพอดี ไม่ลอยถูกต้อง
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        // กดป้ายเดิม = ปิด, กดป้ายใหม่ = เปิด
                        if (_selectedStopId == stop['id']) {
                          _selectedStopId = null;
                        } else {
                          _selectedStopId = stop['id'];
                        }
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior:
                          Clip.none, // อนุญาตให้ Popup ล้นออกนอกกรอบ Marker ได้
                      children: [
                        // 1.1 รูปไอคอนป้ายรถเมล์
                        Image.asset(
                          'assets/images/bus-stopicon.png',
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                        ),

                        // 1.2 Popup รายละเอียด (แสดงเฉพาะตอนถูกเลือก)
                        if (isSelected)
                          Positioned(
                            // ดัน Popup ขึ้นไปข้างบน (สูงกว่าตัวป้าย 50px)
                            bottom: 50,
                            child: Container(
                              width: 160,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    stop['name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  _buildRouteChips(stop['route_id']),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),

              // [LAYER 2] หมุดแดง (Red Pin) ปักทับเฉพาะป้ายเป้าหมายที่เราเลือกมาจากหน้า List
              Marker(
                point: _stopLocation,
                width: 60,
                height: 60,
                alignment: Alignment.bottomCenter,
                child: IgnorePointer(
                  // IgnorePointer เพื่อให้กดทะลุไปโดนป้ายข้างล่างได้ (จะได้กดดู Popup ได้)
                  child: Column(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 36,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _mapController.move(_stopLocation, 18);
        },
        child: const Icon(Icons.center_focus_strong),
      ),
    );
  }
}
