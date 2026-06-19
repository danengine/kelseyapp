import 'package:flutter/material.dart';

import 'kelsey_brand.dart';

/// One tab in [KelseyBottomNavBar].
class KelseyNavDestination {
  const KelseyNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Branded bottom navigation — teal active state, soft pill indicator.
class KelseyBottomNavBar extends StatelessWidget {
  const KelseyBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<KelseyNavDestination> destinations;

  static const _activeColor = KelseyColors.adminTeal;
  static const _inactiveColor = Color(0xFF9CA3AF);
  static const _activeBg = Color(0x1A0B5858); // adminTeal @ 10%

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFF3F4F6))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Row(
            children: List.generate(destinations.length, (index) {
              final dest = destinations[index];
              final selected = index == selectedIndex;
              return Expanded(
                child: _KelseyNavItem(
                  icon: selected ? dest.selectedIcon : dest.icon,
                  label: dest.label,
                  selected: selected,
                  onTap: () => onSelected(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _KelseyNavItem extends StatelessWidget {
  const _KelseyNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: KelseyBottomNavBar._activeColor.withValues(alpha: 0.08),
        highlightColor: KelseyBottomNavBar._activeColor.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? KelseyBottomNavBar._activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? KelseyBottomNavBar._activeColor : KelseyBottomNavBar._inactiveColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? KelseyBottomNavBar._activeColor : KelseyBottomNavBar._inactiveColor,
                  letterSpacing: selected ? 0.1 : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
