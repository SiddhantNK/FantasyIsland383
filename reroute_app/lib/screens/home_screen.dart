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
        backgroundColor: AppTheme.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Text(
          'Backend API Connection',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textMain),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the backend host URL (use 127.0.0.1 for desktop/web or 10.0.2.2 for Android emulator):',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                prefixIcon: Icon(Icons.link_rounded, size: 18, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              ApiService.baseUrl = controller.text.trim();
              Navigator.pop(ctx);
              _refreshData();
            },
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Save & Reconnect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 24,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryGradientStart, AppTheme.primaryGradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.alt_route_rounded, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 12),
            const Text(
              'ReRoute',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Text(
                'DISPATCH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 18),
            // Connection status badge
            InkWell(
              onTap: _showBackendSettings,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: _isConnected ? AppTheme.emeraldSoft : AppTheme.roseSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isConnected
                        ? AppTheme.emerald.withValues(alpha: 0.3)
                        : AppTheme.rose.withValues(alpha: 0.3),
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
                    const SizedBox(width: 7),
                    Text(
                      _isConnected ? 'API Live (${_engine.toUpperCase()})' : 'API Offline',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _isConnected ? AppTheme.emerald : AppTheme.rose,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.settings_outlined,
                      size: 13,
                      color: _isConnected ? AppTheme.emerald : AppTheme.rose,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.sync_rounded, size: 15),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceWhite,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                _navTab(0, 'Driver Portal', Icons.local_shipping_outlined),
                const SizedBox(width: 8),
                _navTab(1, 'Dispatcher Console', Icons.dashboard_outlined),
                const SizedBox(width: 8),
                _navTab(2, 'Audit History', Icons.history_rounded),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primary,
              ),
            )
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
    return InkWell(
      onTap: () => setState(() => _currentTabIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primary.withValues(alpha: 0.3) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
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
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.shadowCard,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.roseSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, color: AppTheme.rose, size: 36),
            ),
            const SizedBox(height: 18),
            const Text(
              'Cannot reach ReRoute Backend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ensure your backend server is running on ${ApiService.baseUrl}.\nStart command:\npython -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _showBackendSettings,
                  icon: const Icon(Icons.settings_outlined, size: 15),
                  label: const Text('Change URL'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _refreshData,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry Connection'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
