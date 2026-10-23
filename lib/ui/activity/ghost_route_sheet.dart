/// Bottom sheet that lists the `.gpx` files in the vault's `Tracks/` folder
/// and loads the chosen one as a [GhostRoute] (a reference trace drawn on the
/// live map). Tracks the user dropped into the folder by hand, such as planned
/// trails, show up here next to recorded activities.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../services/ghost_route.dart';
import '../app_services.dart';
import '../theme/app_theme.dart';

/// What the picker returns. The whole result is null when the sheet is
/// dismissed; `route == null` means "remove the current ghost".
typedef GhostPick = ({GhostRoute? route});

Future<GhostPick?> showGhostRoutePicker(
  BuildContext context, {
  GhostRoute? current,
}) {
  return showModalBottomSheet<GhostPick>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _GhostRouteSheet(current: current),
  );
}

class _GhostRouteSheet extends StatefulWidget {
  const _GhostRouteSheet({this.current});

  final GhostRoute? current;

  @override
  State<_GhostRouteSheet> createState() => _GhostRouteSheetState();
}

class _GhostRouteSheetState extends State<_GhostRouteSheet> {
  Future<List<File>>? _tracks;
  String? _loadingName;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tracks ??= AppScope.of(context).vault.listTracks();
  }

  Future<void> _choose(File file) async {
    if (_loadingName != null) return;
    final vault = AppScope.of(context).vault;
    final navigator = Navigator.of(context);
    final name = p.basename(file.path);
    setState(() {
      _loadingName = name;
      _error = null;
    });
    try {
      final route = await GhostRoute.load(vault, name);
      if (!mounted) return;
      navigator.pop<GhostPick>((route: route));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingName = null;
        _error = 'Could not load $name: '
            '${e is FormatException ? e.message : 'unreadable GPX file'}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Ghost route',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Shown on the map while you record, so you can follow a '
                'planned trail or beat an earlier run. Newest tracks first.',
                style: TextStyle(color: AppColors.textDim, height: 1.35),
              ),
            ),
            if (current != null)
              ListTile(
                leading:
                    const Icon(Icons.layers_clear, color: AppColors.danger),
                title: Text('Remove "${current.name}"'),
                onTap: () => Navigator.of(context).pop<GhostPick>(
                  (route: null),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            Expanded(
              child: FutureBuilder<List<File>>(
                future: _tracks,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final files = snap.data ?? const <File>[];
                  if (files.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No tracks yet.\nRecord an activity, or copy a .gpx '
                          'file into the Tracks folder of your vault.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textDim,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: files.length,
                    itemBuilder: (context, i) {
                      final name = p.basename(files[i].path);
                      final busy = _loadingName == name;
                      final selected = current?.fileName == name;
                      return ListTile(
                        enabled: _loadingName == null,
                        leading: Icon(
                          Icons.route,
                          color: selected ? AppColors.accent : AppColors.drop,
                        ),
                        title: Text(
                          p.basenameWithoutExtension(name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : (selected
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.accent,
                                  )
                                : null),
                        onTap: () => _choose(files[i]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
