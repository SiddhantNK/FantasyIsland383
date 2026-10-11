import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  String _selectedVehicle = 'V01';
  bool _showVehiclePicker = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _loginAsDriver() {
    AuthService.loginAsDriver(
      name: 'Driver $_selectedVehicle',
      vehicleId: _selectedVehicle,
    );
    widget.onLoginSuccess();
  }

  void _loginAsDispatcher() {
    AuthService.loginAsDispatcher(name: 'Fleet Dispatcher');
    widget.onLoginSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 500;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenH - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 24 : 40,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: screenH * 0.06),

                      // ── Logo & Title ──────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryGradientStart,
                              AppTheme.primaryGradientEnd,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.alt_route_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'ReRoute',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMain,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Dynamic Delivery Optimization',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),

                      SizedBox(height: screenH * 0.05),

                      // ── Role Selection ────────────────────────────────
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 14),
                              child: Text(
                                'Select your role to continue',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),

                            // ── Driver Card ─────────────────────────────
                            _RoleCard(
                              icon: Icons.local_shipping_rounded,
                              title: 'Driver',
                              subtitle: 'View your route, report disruptions on the road',
                              accentColor: AppTheme.primary,
                              accentSoft: AppTheme.primarySoft,
                              onTap: () {
                                setState(() => _showVehiclePicker = true);
                              },
                              trailing: _showVehiclePicker
                                  ? null
                                  : const Icon(Icons.arrow_forward_ios_rounded,
                                      size: 14, color: AppTheme.textDim),
                            ),

                            // ── Vehicle Picker (animated) ───────────────
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              child: _showVehiclePicker
                                  ? Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primarySoft,
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(14),
                                          bottomRight: Radius.circular(14),
                                        ),
                                        border: Border.all(
                                          color: AppTheme.primary.withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Select your vehicle',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: ['V01', 'V02', 'V03']
                                                .map((v) => Expanded(
                                                      child: Padding(
                                                        padding: EdgeInsets.only(
                                                            right: v != 'V03' ? 8 : 0),
                                                        child: _VehicleChip(
                                                          vehicleId: v,
                                                          selected: _selectedVehicle == v,
                                                          onTap: () =>
                                                              setState(() => _selectedVehicle = v),
                                                        ),
                                                      ),
                                                    ))
                                                .toList(),
                                          ),
                                          const SizedBox(height: 14),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: _loginAsDriver,
                                              icon: const Icon(Icons.login_rounded, size: 18),
                                              label: Text('Sign in as Driver ($_selectedVehicle)'),
                                              style: ElevatedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(vertical: 14),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 12),

                            // ── Dispatcher Card ─────────────────────────
                            _RoleCard(
                              icon: Icons.dashboard_rounded,
                              title: 'Dispatcher',
                              subtitle:
                                  'Manage fleet, review incidents, approve re-routing',
                              accentColor: AppTheme.emerald,
                              accentSoft: AppTheme.emeraldSoft,
                              onTap: _loginAsDispatcher,
                              trailing: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: AppTheme.textDim),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenH * 0.06),

                      // ── Footer ────────────────────────────────────────
                      Text(
                        'FantasyIsland383 · Hackathon Demo',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textDim.withValues(alpha: 0.6),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Role Card ───────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color accentSoft;
  final VoidCallback onTap;
  final Widget? trailing;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.accentSoft,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: accentSoft,
        highlightColor: accentSoft.withValues(alpha: 0.5),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.shadowSm,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Vehicle Chip ────────────────────────────────────────────────────────────
class _VehicleChip extends StatelessWidget {
  final String vehicleId;
  final bool selected;
  final VoidCallback onTap;

  const _VehicleChip({
    required this.vehicleId,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.primary
                : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          children: [
            Icon(
              Icons.local_shipping_rounded,
              size: 20,
              color: selected ? Colors.white : AppTheme.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              vehicleId,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
