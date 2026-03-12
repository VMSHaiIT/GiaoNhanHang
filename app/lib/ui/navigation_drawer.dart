import 'package:flutter/material.dart';
import 'design_system.dart';

class AppNavigationDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback onLogout;

  const AppNavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onLogout,
  });

  static const int _managementStartIndex = 0;
  static const int _managementEndIndex = 4;

  @override
  Widget build(BuildContext context) {
    final isManagementSelected = selectedIndex >= _managementStartIndex &&
        selectedIndex <= _managementEndIndex;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                children: [
                  ExpansionTile(
                    initiallyExpanded: isManagementSelected,
                    leading: Icon(
                      Icons.settings_applications,
                      color: isManagementSelected
                          ? AppTheme.primaryColor
                          : Colors.black87,
                    ),
                    title: Text(
                      'Quản lý',
                      style: TextStyle(
                        color: isManagementSelected
                            ? AppTheme.primaryColor
                            : Colors.black87,
                        fontWeight: isManagementSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    children: [
                      _buildNavItem(
                        icon: Icons.badge,
                        title: 'Quản lý nhân viên',
                        index: 0,
                        isSelected: selectedIndex == 0,
                        onItemSelected: onItemSelected,
                        isChild: true,
                      ),
                      _buildNavItem(
                        icon: Icons.send,
                        title: 'Quản lý khách gửi',
                        index: 1,
                        isSelected: selectedIndex == 1,
                        onItemSelected: onItemSelected,
                        isChild: true,
                      ),
                      _buildNavItem(
                        icon: Icons.inventory_2,
                        title: 'Quản lý khách nhận',
                        index: 2,
                        isSelected: selectedIndex == 2,
                        onItemSelected: onItemSelected,
                        isChild: true,
                      ),
                      _buildNavItem(
                        icon: Icons.route,
                        title: 'Quản lý tuyến',
                        index: 3,
                        isSelected: selectedIndex == 3,
                        onItemSelected: onItemSelected,
                        isChild: true,
                      ),
                      _buildNavItem(
                        icon: Icons.directions_transit,
                        title: 'Quản lý chuyến đi',
                        index: 4,
                        isSelected: selectedIndex == 4,
                        onItemSelected: onItemSelected,
                        isChild: true,
                      ),
                    ],
                  ),
                  _buildNavItem(
                    icon: Icons.add_shopping_cart,
                    title: 'Tạo đơn mới',
                    index: 5,
                    isSelected: selectedIndex == 5,
                    onItemSelected: onItemSelected,
                  ),
                  _buildNavItem(
                    icon: Icons.warehouse,
                    title: 'Kho hàng đi',
                    index: 6,
                    isSelected: selectedIndex == 6,
                    onItemSelected: onItemSelected,
                  ),
                  _buildNavItem(
                    icon: Icons.list_alt,
                    title: 'Phối hàng',
                    index: 7,
                    isSelected: selectedIndex == 7,
                    onItemSelected: onItemSelected,
                  ),
                  _buildNavItem(
                    icon: Icons.warehouse_outlined,
                    title: 'Kho hàng đến',
                    index: 8,
                    isSelected: selectedIndex == 8,
                    onItemSelected: onItemSelected,
                  ),
                  _buildNavItem(
                    icon: Icons.location_on,
                    title: 'Phát vị trí GPS',
                    index: 9,
                    isSelected: selectedIndex == 9,
                    onItemSelected: onItemSelected,
                  ),
                  _buildNavItem(
                    icon: Icons.show_chart,
                    title: 'Báo cáo',
                    index: 10,
                    isSelected: selectedIndex == 10,
                    onItemSelected: onItemSelected,
                  ),
                  _buildNavItem(
                    icon: Icons.settings,
                    title: 'Cấu hình',
                    index: 11,
                    isSelected: selectedIndex == 11,
                    onItemSelected: onItemSelected,
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: ElevatedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingL,
                      vertical: AppTheme.spacingM),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required int index,
    required bool isSelected,
    required Function(int) onItemSelected,
    bool isChild = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.only(
        left: isChild ? AppTheme.spacingL * 2 : AppTheme.spacingM,
        right: AppTheme.spacingM,
      ),
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.black87),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor,
      onTap: () => onItemSelected(index),
    );
  }
}
