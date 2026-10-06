import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/theme//provider/theme.dart';

class SearchInput extends StatelessWidget {
  const SearchInput({
    required this.searchController,
    required this.searchFocusNode,
    super.key,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: searchController,
      focusNode: searchFocusNode,
      autofocus: true,
      // Keep the keyboard focus on the search field when the user clicks
      // anywhere else in the overview (a file row, the preview, a mode
      // button). The default would unfocus it, and the Super-based shortcuts
      // only fire while focus is inside their subtree.
      onTapOutside: (_) {},
      style: Theme.of(context).textTheme.titleLarge,
      decoration: InputDecoration(
        prefixIcon: const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 32, 12),
          child: Icon(Icons.search, size: 28),
        ),
        hintText: context.l10n.search,
        fillColor: Theme.of(context).colorScheme.surface,
        filled: true,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(surfaceRadius)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(surfaceRadius)),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }
}
