import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'reminder/reminder_page.dart';
import 'account/account_page.dart';

const _kTabs = <_TabItem>[
  _TabItem(
      icon: Icons.water_drop_outlined,
      label: '喝水提醒',
      page: ReminderPage()),
  _TabItem(
      icon: Icons.person_outline_rounded, label: '账号&飞书', page: AccountPage()),
];

/// 首页 - 两Tab结构(提醒设置+统计已合并)
/// 安卓返回键逻辑:
/// 1. 弹窗状态下返回:关闭弹窗(Flutter自动处理)
/// 2. 非首个Tab:回到上一个Tab
/// 3. 首个Tab连续两次返回:退出App
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  DateTime? _lastBackPressed;

  Future<bool> _onWillPop() async {
    // 弹窗打开时由系统处理关闭
    if (Navigator.of(context).canPop()) return true;

    if (_index != 0) {
      // 非首个Tab:回到上一个Tab
      setState(() => _index = _index - 1);
      return false;
    }
    // 首个Tab:连续两次返回退出
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('再按一次返回键退出'),
          duration: Duration(seconds: 2),
        ));
      return false;
    }
    SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: _kTabs.map((t) => t.page).toList(),
        ),
        bottomNavigationBar: _CreamBottomBar(
          index: _index,
          onChanged: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.icon, required this.label, required this.page});
  final IconData icon;
  final String label;
  final Widget page;
}

/// 奶油风底部Tab栏 - 水波纹点击反馈
class _CreamBottomBar extends StatelessWidget {
  const _CreamBottomBar({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = _kTabs;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: List.generate(items.length, (i) {
              final t = items[i];
              final selected = i == index;
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    borderRadius: BorderRadius.circular(16),
                    splashColor: AppColors.softBlue.withAlpha(80),
                    highlightColor: AppColors.softBlue.withAlpha(40),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t.icon,
                              size: 24,
                              color: selected
                                  ? AppColors.softBlueDeep
                                  : AppColors.textDisabled),
                          const SizedBox(height: 2),
                          Text(t.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: selected
                                    ? AppColors.softBlueDeep
                                    : AppColors.textDisabled,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
