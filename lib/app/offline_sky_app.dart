import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/search/discover_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/sky_map/sky_screen.dart';

const Color skyBackground = Color(0xFF070B15);
const Color skySurface = Color(0xFF101725);
const Color skyElevated = Color(0xFF192438);
const Color skyAccent = Color(0xFF7DD3FC);
const Color skyGold = Color(0xFFF5C76B);
const Color skyTextPrimary = Color(0xFFE7EDF8);
const Color skyTextSecondary = Color(0xFF9AA8BD);
const Color skyOutline = Color(0xFF29364A);
const Color skyViolet = Color(0xFFB9A7E8);

class OfflineSkyApp extends StatelessWidget {
  const OfflineSkyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: skyAccent,
          brightness: Brightness.dark,
          surface: skySurface,
        ).copyWith(
          primary: skyAccent,
          onPrimary: skyBackground,
          secondary: skyViolet,
          onSecondary: skyBackground,
          tertiary: skyGold,
          onTertiary: skyBackground,
          surface: skySurface,
          error: const Color(0xFFFF9299),
        );
    final roundedButton = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return MaterialApp(
      title: 'Offline Sky',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: skyBackground,
        cardTheme: CardThemeData(
          color: skySurface,
          margin: EdgeInsets.zero,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: skyOutline.withValues(alpha: .72)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: skyBackground,
          foregroundColor: skyTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: skyTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: skySurface,
          hintStyle: const TextStyle(color: Color(0xFF7F8DA3)),
          labelStyle: const TextStyle(color: skyTextSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: skyOutline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: skyOutline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: skyAccent, width: 1.4),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFFF9299)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFFF9299), width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
            shape: WidgetStatePropertyAll(roundedButton),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
            shape: WidgetStatePropertyAll(roundedButton),
            side: const WidgetStatePropertyAll(BorderSide(color: skyOutline)),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
            shape: WidgetStatePropertyAll(roundedButton),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: roundedButton,
          ),
        ),
        listTileTheme: ListTileThemeData(
          iconColor: skyTextSecondary,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          minVerticalPadding: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: skySurface,
          modalBackgroundColor: skySurface,
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
          dragHandleColor: Color(0xFF5A6A82),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: skySurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: skyOutline),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: skyElevated,
          contentTextStyle: const TextStyle(color: skyTextPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: skyOutline),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: skyAccent,
          linearTrackColor: Color(0xFF27344A),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0B111D),
          indicatorColor: skyAccent.withValues(alpha: 0.16),
          elevation: 0,
          height: 78,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? skyAccent
                  : const Color(0xFF9AA8BD),
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              color: states.contains(WidgetState.selected)
                  ? skyTextPrimary
                  : skyTextSecondary,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: skyTextPrimary,
          displayColor: const Color(0xFFF4F7FE),
        ),
      ),
      home: const OfflineSkyClock(child: AppShell()),
    );
  }
}

class OfflineSkyClock extends ConsumerStatefulWidget {
  const OfflineSkyClock({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<OfflineSkyClock> createState() => _OfflineSkyClockState();
}

class _OfflineSkyClockState extends ConsumerState<OfflineSkyClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => ref.read(skyStateProvider.notifier).tickClock(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = [
    SkyScreen(),
    DiscoverScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.public), label: 'Sky'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Discover'),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            label: 'Saved',
          ),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      ?action,
    ],
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      letterSpacing: 1.5,
      color: const Color(0xFF91A5C5),
      fontWeight: FontWeight.w700,
    ),
  );
}

class InfoChip extends StatelessWidget {
  const InfoChip({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: skyElevated,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: const Color(0xFF28354B)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: skyAccent),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: skyAccent),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: const Color(0xFF9AA8BD)),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}
