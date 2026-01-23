import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final List<Widget>? actions;

  const AppAppBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: Text(
        title,
        style: AppTextStyles.heading3,
      ),
      actions: actions,
      elevation: 0,
    );
  }
}



