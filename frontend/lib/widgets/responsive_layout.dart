import 'package:flutter/material.dart';
import '../core/theme/beast_tokens.dart';
import 'beast_logo.dart';

class NavDestinationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NavDestinationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class ResponsiveScaffold extends StatelessWidget {
  final String title;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavDestinationItem> destinations;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final Widget? drawer;
  final bool isOffline;

  const ResponsiveScaffold({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.floatingActionButton,
    this.actions,
    this.drawer,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      drawer: drawer,
      appBar: AppBar(
        backgroundColor: BeastColors.white,
        foregroundColor: BeastColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BeastLogo(
              size: 32,
              borderRadius: BeastRadius.xs,
            ),
            const SizedBox(width: BeastSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'B.E.A.S.T ACADEMY',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: BeastColors.dark900,
                    height: 1.1,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: BeastColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: actions,
        bottom: isOffline
            ? PreferredSize(
                preferredSize: const Size.fromHeight(26),
                child: Container(
                  width: double.infinity,
                  color: BeastColors.warningLight,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 14, color: BeastColors.warning),
                      SizedBox(width: 6),
                      Text(
                        'Offline Cache Active — Reconnecting to live cloud...',
                        style: TextStyle(
                          color: BeastColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: isDesktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: BeastColors.white,
                  selectedIconTheme: const IconThemeData(color: BeastColors.dark900),
                  unselectedIconTheme: const IconThemeData(color: BeastColors.textMuted),
                  indicatorColor: BeastColors.peach200,
                  selectedLabelTextStyle: const TextStyle(
                    color: BeastColors.dark900,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: BeastColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                  destinations: destinations
                      .map((d) => NavigationRailDestination(
                            icon: Icon(d.icon, size: 20),
                            selectedIcon: Icon(d.selectedIcon, size: 20),
                            label: Text(d.label),
                          ))
                      .toList(),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: BeastColors.borderSubtle),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              backgroundColor: BeastColors.white,
              indicatorColor: BeastColors.peach200,
              elevation: 3,
              height: 64,
              destinations: destinations
                  .map((d) => NavigationDestination(
                        icon: Icon(d.icon, size: 22, color: BeastColors.textMuted),
                        selectedIcon: Icon(d.selectedIcon, size: 22, color: BeastColors.dark900),
                        label: d.label,
                      ))
                  .toList(),
            ),
      floatingActionButton: floatingActionButton,
    );
  }
}
