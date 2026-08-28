import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/state/app_state.dart';
import '../index/index_screen.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.appState, super.key});

  final AppState appState;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _TodayScreen(appState: widget.appState, onOpenIndex: () => _selectTab(1)),
      IndexScreen(appState: widget.appState),
      _BookmarksScreen(appState: widget.appState),
      SettingsScreen(appState: widget.appState),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: IndexedStack(index: _selectedIndex, children: pages),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.format_list_bulleted_rounded),
              label: 'الفهرس',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_border_rounded),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: 'العلامات',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_rounded),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }

  void _selectTab(int index) => setState(() => _selectedIndex = index);
}

class _TodayScreen extends StatelessWidget {
  const _TodayScreen({required this.appState, required this.onOpenIndex});

  final AppState appState;
  final VoidCallback onOpenIndex;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, child) {
        return CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text(AppConstants.appName),
              actions: [
                IconButton(
                  tooltip: 'الفهرس',
                  onPressed: onOpenIndex,
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              sliver: SliverList.list(
                children: [
                  _ReadingCard(
                    pageNumber: appState.lastReadPage,
                    onPressed: () =>
                        _openReader(context, appState.lastReadPage),
                  ),
                  const SizedBox(height: 24),
                  Text('استكشف', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.grid_view_rounded,
                          title: 'صفحات المصحف',
                          subtitle: '604 صفحة',
                          onTap: onOpenIndex,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.bookmark_rounded,
                          title: 'علاماتي',
                          subtitle: '${appState.bookmarkedPages.length} محفوظة',
                          onTap: () => _openReader(
                            context,
                            appState.bookmarkedPages.isEmpty
                                ? appState.lastReadPage
                                : appState.bookmarkedPages.last,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(20),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: const Icon(Icons.light_mode_rounded),
                      ),
                      title: const Text('ورد اليوم'),
                      subtitle: const Text(
                        'ابدأ بعشر صفحات، والقليل الدائم أحب.',
                      ),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () => _openReader(context, appState.lastReadPage),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _openReader(BuildContext context, int page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(appState: appState, initialPage: page),
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.pageNumber, required this.onPressed});

  final int pageNumber;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [colors.primary, colors.tertiary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 42),
          const SizedBox(height: 28),
          const Text('تابع القراءة', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            'صفحة $pageNumber',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('فتح المصحف'),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 18),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarksScreen extends StatelessWidget {
  const _BookmarksScreen({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, child) {
        final pages = appState.bookmarkedPages.toList()..sort();
        return Scaffold(
          appBar: AppBar(title: const Text('العلامات المرجعية')),
          body: pages.isEmpty
              ? const _EmptyBookmarks()
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: pages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final page = pages[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.bookmark_rounded),
                        title: Text('صفحة $page'),
                        subtitle: const Text('مصحف المدينة النبوية'),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReaderScreen(
                              appState: appState,
                              initialPage: page,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _EmptyBookmarks extends StatelessWidget {
  const _EmptyBookmarks();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_add_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد علامات بعد',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('أضف علامة من داخل المصحف للعودة إلى الصفحة سريعًا.'),
          ],
        ),
      ),
    );
  }
}
