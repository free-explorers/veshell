import 'package:flutter/material.dart';
import 'package:shell/theme/theme.dart';

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
      style: Theme.of(context).textTheme.titleLarge,
      decoration: InputDecoration(
        prefixIcon: const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 32, 12),
          child: Icon(
            Icons.search,
            size: 28,
          ),
        ),
        hintText: 'Search',
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
