import 'package:flutter/material.dart';
import 'skaner_entry_screen.dart';

/// Pasek wyszukiwania (lupa) dla list dyspozytora. Filtruje po dostawcy,
/// LOT-cie / numerze dostawy i odmianie. Zwraca przez [onChanged] tekst
/// przycięty i zamieniony na małe litery (gotowy do `contains`).
class SkanerSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hint;
  const SkanerSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Szukaj: dostawca, LOT, nr, odmiana…',
  });

  @override
  State<SkanerSearchField> createState() => _SkanerSearchFieldState();
}

class _SkanerSearchFieldState extends State<SkanerSearchField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _emit(String v) {
    widget.onChanged(v.trim().toLowerCase());
    setState(() {}); // pokaż/ukryj przycisk czyszczenia
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: TextField(
        controller: _ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: kSkanerAccent,
        onChanged: _emit,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: kSkanerTextSec, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: kSkanerTextSec, size: 20),
          suffixIcon: _ctrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: kSkanerTextSec, size: 18),
                  onPressed: () {
                    _ctrl.clear();
                    _emit('');
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: kSkanerCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kSkanerPrimary),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kSkanerAccent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Czy dokument pasuje do zapytania [q] (już lowercase). Sprawdza wszystkie
/// podane pola tekstowe. Puste zapytanie = pasuje wszystko.
bool matchesQuery(String q, Iterable<String?> fields) {
  if (q.isEmpty) return true;
  for (final f in fields) {
    if (f != null && f.toLowerCase().contains(q)) return true;
  }
  return false;
}
