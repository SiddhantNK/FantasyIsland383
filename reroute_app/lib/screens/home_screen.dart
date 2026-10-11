import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'dispatcher_screen.dart';
import 'driver_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  PlanModel? _latestPlan;
  List<LocationModel> _locations = [];
  bool _isLoading = true;
  bool _isConnected = false;
  String _engine = 'ortools';

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final health = await ApiService.checkHealth();
      final state = await ApiService.getState();
      final plan = await ApiService.getLatestPlan();

      final locList = (state['locations'] as List<dynamic>?)
              ?.map((l) => LocationModel.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [];

      if (mounted) {
        setState(() {
          _isConnected = true;
          _engine = health['engine'] ?? 'ortools';
          _locations = locList;
          _latestPlan = plan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isLoading = false;
        });
      }
    }
  }

  void _showBackendSettings() {
    final controller = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Backend API URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the backend host (use 10.0.2.2 for Android emulator or 127.0.0.1 for desktop/web):',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Base URL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ApiService.baseUrl = controller.text.trim();
              Navigator.pop(ctx);
              _refreshData();
            },
            child: const Text('Save & Reconnect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryGradientStart, AppTheme.primaryGradientEnd],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.alt_route_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'ReRoute',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 16),
            // Connection status pill
            GestureDetector(
              onTap: _showBackendSettings,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isConnected ? AppTheme.emerald.withOpacity(0.15) : AppTheme.rose.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isConnected ? AppTheme.emerald : AppTheme.rose,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _isConnected ? AppTheme.emerald : AppTheme.rose,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isConnected ? 'API Live (${_engine.toUpperCase()})' : 'API Offline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _isConnected ? AppTheme.emeraldLight : AppTheme.roseLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.settings, size: 12, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh All',
            icon: const Icon(Icons.refresh, color: AppTheme.textMuted),
            onPressed: _refreshData,
          ),
          const SizedBox(width: 10),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _navTab(0, 'Driver Portal', Icons.local_shipping_outlined),
                  const SizedBox(width: 12),
                  _navTab(1, 'Dispatcher Console', Icons.dashboard_outlined),
                  const SizedBox(width: 12),
                  _navTab(2, 'Audit History', Icons.history_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isConnected
              ? _buildOfflineState()
              : IndexedStack(
                  index: _currentTabIndex,
                  children: [
                    DriverScreen(
                      plan: _latestPlan,
                      locations: _locations,
                      onRefresh: _refreshData,
                    ),
                    DispatcherScreen(
                      plan: _latestPlan,
                      locations: _locations,
                      onRefresh: _refreshData,
                    ),
                    const HistoryScreen(),
                  ],
                ),
    );
  }

  Widget _navTab(int index, String title, IconData icon) {
    final selected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppTheme.primary : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppTheme.primaryLight : AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppTheme.primaryLight : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.rose.withOpacity(0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppTheme.rose, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Cannot reach ReRoute Backend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure your FastAPI server is running on ${ApiService.baseUrl}.\nRun command:\nuvicorn app.main:app --reload --host 0.0.0.0 --port 8000',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _showBackendSettings,
                  child: const Text('Change URL'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _refreshData,
                  child: const Text('Retry Connection'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
