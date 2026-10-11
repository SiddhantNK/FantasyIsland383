import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'dispatcher_screen.dart';
import 'driver_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Backend Connection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMain),
            ),
            const SizedBox(height: 6),
            const Text(
              'Use 127.0.0.1 for desktop/web or 10.0.2.2 for Android emulator.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                prefixIcon: Icon(Icons.link_rounded, size: 18, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ApiService.baseUrl = controller.text.trim();
                      Navigator.pop(ctx);
                      _refreshData();
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Save & Reconnect'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUserMenu() {
    final user = AuthService.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: user?.isDriver == true ? AppTheme.primarySoft : AppTheme.emeraldSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                user?.isDriver == true
                    ? Icons.local_shipping_rounded
                    : Icons.dashboard_rounded,
                color: user?.isDriver == true ? AppTheme.primary : AppTheme.emerald,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              user?.name ?? 'User',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMain),
            ),
            if (user?.email.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                user!.email,
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    user?.roleLabel.toUpperCase() ?? 'GUEST',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (user?.isDriver == true && user?.vehicleId != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'VEHICLE: ${user!.vehicleId}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            _MenuOption(
              icon: Icons.settings_outlined,
              label: 'Backend Connection',
              onTap: () {
                Navigator.pop(ctx);
                _showBackendSettings();
              },
            ),
            const SizedBox(height: 8),
            _MenuOption(
              icon: Icons.sync_rounded,
              label: 'Refresh Data',
              onTap: () {
                Navigator.pop(ctx);
                _refreshData();
              },
            ),
            const SizedBox(height: 8),
            _MenuOption(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              color: AppTheme.rose,
              onTap: () {
                Navigator.pop(ctx);
                widget.onLogout();
              },
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  List<_NavItem> get _navItems {
    final isDriver = AuthService.isDriver;
    if (isDriver) {
      return [
        _NavItem(icon: Icons.local_shipping_rounded, activeIcon: Icons.local_shipping, label: 'My Route'),
        _NavItem(icon: Icons.history_outlined, activeIcon: Icons.history_rounded, label: 'History'),
      ];
    }
    return [
      _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      _NavItem(icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping_rounded, label: 'Drivers'),
      _NavItem(icon: Icons.history_outlined, activeIcon: Icons.history_rounded, label: 'History'),
    ];
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
      );
    }

    if (!_isConnected) {
      return _buildOfflineState();
    }

    if (AuthService.isDriver) {
      if (_currentTabIndex == 0) {
        return DriverScreen(
          plan: _latestPlan,
          locations: _locations,
          onRefresh: _refreshData,
        );
      }
      return const HistoryScreen();
    }

    // Dispatcher tabs
    switch (_currentTabIndex) {
      case 0:
        return DispatcherScreen(
          plan: _latestPlan,
          locations: _locations,
          onRefresh: _refreshData,
        );
      case 1:
        return DriverScreen(
          plan: _latestPlan,
          locations: _locations,
          onRefresh: _refreshData,
        );
      case 2:
        return const HistoryScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final navItems = _navItems;
    // Clamp index if role changes
    if (_currentTabIndex >= navItems.length) {
      _currentTabIndex = 0;
    }

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryGradientStart, AppTheme.primaryGradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.alt_route_rounded, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            const Text(
              'ReRoute',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 10),
            // Connection status dot
            GestureDetector(
              onTap: _showBackendSettings,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isConnected ? AppTheme.emeraldSoft : AppTheme.roseSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isConnected
                        ? AppTheme.emerald.withValues(alpha: 0.3)
                        : AppTheme.rose.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _isConnected ? AppTheme.emerald : AppTheme.rose,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isConnected ? _engine.toUpperCase() : 'Offline',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: _isConnected ? AppTheme.emerald : AppTheme.rose,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Refresh button
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.sync_rounded, size: 20),
            color: AppTheme.textMuted,
            tooltip: 'Refresh',
          ),
          // User avatar / menu
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _showUserMenu,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: user?.isDriver == true ? AppTheme.primarySoft : AppTheme.emeraldSoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: user?.isDriver == true
                        ? AppTheme.primary.withValues(alpha: 0.3)
                        : AppTheme.emerald.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 16,
                  color: user?.isDriver == true ? AppTheme.primary : AppTheme.emerald,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppTheme.border,
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          border: Border(top: BorderSide(color: AppTheme.border.withValues(alpha: 0.8))),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: navItems.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final selected = _currentTabIndex == idx;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentTabIndex = idx),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                            decoration: BoxDecoration(
                              color: selected ? AppTheme.primarySoft : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              selected ? item.activeIcon : item.icon,
                              size: 22,
                              color: selected ? AppTheme.primary : AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? AppTheme.primary : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.roseSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, color: AppTheme.rose, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Cannot reach backend',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ensure the server is running on\n${ApiService.baseUrl}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppTheme.textMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showBackendSettings,
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Change URL'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Supporting Types ────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: c),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppTheme.textDim),
            ],
          ),
        ),
      ),
    );
  }
}
