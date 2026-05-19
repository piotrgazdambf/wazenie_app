import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../core/constants.dart';
import 'skaner_entry_screen.dart';

// ── Ekran Dyspozytora ─────────────────────────────────────────────────────────

class DyspozytoScreen extends ConsumerStatefulWidget {
  const DyspozytoScreen({super.key});

  @override
  ConsumerState<DyspozytoScreen> createState() => _DyspozytoScreenState();
}

class _DyspozytoScreenState extends ConsumerState<DyspozytoScreen> {
  AppUser?  _loggedUser;
  String    _pin        = '';
  AppUser?  _selected;
  String?   _pinError;
  bool      _pinLoading = false;

  void _selectUser(AppUser u) {
    setState(() { _selected = u; _pin = ''; _pinError = null; });
  }

  void _appendDigit(String d) {
    if (_pin.length >= 4) return;
    final newPin = _pin + d;
    setState(() { _pin = newPin; _pinError = null; });
    if (newPin.length == 4) _verifyPin(newPin);
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verifyPin(String pin) async {
    if (_selected == null) return;
    setState(() => _pinLoading = true);
    try {
      final ok = await ref.read(pinAuthServiceProvider).verifyPin(_selected!.id, pin);
      if (ok) {
        setState(() { _loggedUser = _selected; _pinLoading = false; });
      } else {
        setState(() { _pin = ''; _pinError = 'Błędny PIN'; _pinLoading = false; });
      }
    } catch (_) {
      setState(() { _pin = ''; _pinError = 'Błąd połączenia'; _pinLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedUser != null) {
      return _DyspozytoPanel(
        user: _loggedUser!,
        onLogout: () => setState(() { _loggedUser = null; _selected = null; _pin = ''; }),
      );
    }
    if (_selected != null) return _buildPin();
    return _buildSelectUser();
  }

  // ── Wybór użytkownika ────────────────────────────────────────────────────────

  Widget _buildSelectUser() {
    final usersAsync = ref.watch(skanerUsersProvider);
    return Scaffold(
      backgroundColor: kSkanerBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.manage_accounts_outlined, color: kSkanerAccent, size: 52),
              const SizedBox(height: 12),
              const Text('Dyspozytor',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Wybierz konto',
                  style: TextStyle(color: kSkanerTextSec, fontSize: 14)),
              const SizedBox(height: 36),
              usersAsync.when(
                loading: () => const CircularProgressIndicator(color: kSkanerAccent),
                error:   (e, _) => Text('Błąd: $e', style: const TextStyle(color: Colors.red)),
                data:    (users) => Column(
                  children: users
                      .map((u) => _UserTile(user: u, onTap: () => _selectUser(u)))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => context.go('/skaner'),
                icon: const Icon(Icons.arrow_back_ios, color: kSkanerTextSec, size: 14),
                label: const Text('Wróć', style: TextStyle(color: kSkanerTextSec)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Wprowadzanie PIN ─────────────────────────────────────────────────────────

  Widget _buildPin() {
    return Scaffold(
      backgroundColor: kSkanerBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() { _selected = null; _pin = ''; _pinError = null; }),
                  icon: const Icon(Icons.arrow_back_ios, color: kSkanerTextSec, size: 14),
                  label: const Text('Zmień konto', style: TextStyle(color: kSkanerTextSec)),
                ),
              ),
              const Spacer(),
              CircleAvatar(
                radius: 34,
                backgroundColor: kSkanerPrimary,
                child: Text(
                  _selected!.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              Text(_selected!.name,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? kSkanerAccent : Colors.transparent,
                      border: Border.all(color: kSkanerAccent.withValues(alpha: 0.5), width: 2),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              if (_pinError != null)
                Text(_pinError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              const Spacer(),
              if (_pinLoading)
                const CircularProgressIndicator(color: kSkanerAccent)
              else
                _Numpad(onDigit: _appendDigit, onBackspace: _backspace),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Panel Dyspozytora (po zalogowaniu) ────────────────────────────────────────

class _DyspozytoPanel extends StatefulWidget {
  final AppUser user;
  final VoidCallback onLogout;
  const _DyspozytoPanel({required this.user, required this.onLogout});

  @override
  State<_DyspozytoPanel> createState() => _DyspozytooPanelState();
}

class _DyspozytooPanelState extends State<_DyspozytoPanel> {
  bool _oczekujaceExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSkanerBg,
      appBar: AppBar(
        backgroundColor: kSkanerCard,
        foregroundColor: Colors.white,
        leading: BackButton(onPressed: () => context.go('/skaner')),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dyspozytor', style: TextStyle(color: Colors.white, fontSize: 16)),
            Text(widget.user.name,
                style: const TextStyle(color: kSkanerTextSec, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout, color: kSkanerTextSec, size: 18),
            label: const Text('Wyloguj', style: TextStyle(color: kSkanerTextSec, fontSize: 12)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Accordion: Oczekujące ──────────────────────────────────────────
          _OczekujaceAccordion(
            user: widget.user,
            expanded: _oczekujaceExpanded,
            onToggle: () => setState(() => _oczekujaceExpanded = !_oczekujaceExpanded),
          ),
          const SizedBox(height: 20),
          // ── Sekcja skanowania / zejście ────────────────────────────────────
          _SkanujSectionHeader(),
          const SizedBox(height: 10),
          _ZejscieScanner(user: widget.user),
        ],
      ),
    );
  }
}

// ── Accordion Oczekujące ──────────────────────────────────────────────────────

class _OczekujaceAccordion extends StatelessWidget {
  final AppUser user;
  final bool expanded;
  final VoidCallback onToggle;

  const _OczekujaceAccordion({
    required this.user,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('skaner_wnioski')
          .where('status', isEqualTo: 'oczekujacy')
          .snapshots(),
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? [])
          ..sort((a, b) {
            final aMs = ((a.data() as Map)['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bMs = ((b.data() as Map)['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bMs.compareTo(aMs);
          });
        final count = docs.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nagłówek akordeonu
            GestureDetector(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: kSkanerCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: count > 0 ? kSkanerAccent.withValues(alpha: 0.5) : kSkanerPrimary,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top, color: kSkanerAccent, size: 20),
                    const SizedBox(width: 10),
                    const Text('Oczekujące',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    if (count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      )
                    else
                      const Text('0', style: TextStyle(color: kSkanerTextSec, fontSize: 14)),
                    const Spacer(),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: kSkanerTextSec,
                    ),
                  ],
                ),
              ),
            ),
            // Zawartość
            if (expanded) ...[
              const SizedBox(height: 10),
              if (snap.connectionState == ConnectionState.waiting)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: kSkanerAccent),
                ))
              else if (docs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kSkanerCard.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('Brak oczekujących zleceń',
                        style: TextStyle(color: kSkanerTextSec, fontSize: 14)),
                  ),
                )
              else
                ...docs.map((doc) => _WniosekTile(
                      doc: doc as DocumentSnapshot<Map<String, dynamic>>,
                      user: user,
                    )),
            ],
          ],
        );
      },
    );
  }
}

// ── Nagłówek sekcji skanowania ────────────────────────────────────────────────

class _SkanujSectionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.qr_code_scanner, color: kSkanerAccent, size: 18),
        const SizedBox(width: 8),
        const Text(
          'SKANUJ / ZEJŚCIE ZE STANÓW',
          style: TextStyle(
            color: kSkanerAccent,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ── Sekcja skanowania (dyspozytor robi zejście) ────────────────────────────────

class _ZejscieScanner extends StatefulWidget {
  final AppUser user;
  const _ZejscieScanner({required this.user});

  @override
  State<_ZejscieScanner> createState() => _ZejscieScannerState();
}

class _ZejscieScannerState extends State<_ZejscieScanner> {
  final _lotCtrl   = TextEditingController();
  final _wagaCtrl  = TextEditingController();
  final _iloscCtrl = TextEditingController();
  final _lotFocus  = FocusNode();

  Map<String, dynamic>? _delivery; // dane z Firestore
  double _pobrano = 0.0;            // już pobrano z tego LOT
  bool _loading  = false;
  bool _sending  = false;
  String? _error;
  bool _useWaga  = true;           // true = waga netto, false = skrzynie

  @override
  void dispose() {
    _lotCtrl.dispose();
    _wagaCtrl.dispose();
    _iloscCtrl.dispose();
    _lotFocus.dispose();
    super.dispose();
  }

  Future<void> _lookupLot(String lot) async {
    final trimmed = lot.trim();
    if (trimmed.isEmpty) return;
    setState(() { _loading = true; _error = null; _delivery = null; _wagaCtrl.clear(); _iloscCtrl.clear(); });

    try {
      final db = FirebaseFirestore.instance;

      // Pobierz dokument dostawy
      final docId = trimmed.replaceAll('/', '_');
      DocumentSnapshot<Map<String, dynamic>> doc =
          await db.collection(AppConstants.colDeliveries).doc(docId).get();
      if (!doc.exists) {
        final snap = await db.collection(AppConstants.colDeliveries)
            .where('lot', isEqualTo: trimmed).limit(1).get();
        if (snap.docs.isNotEmpty) {
          doc = snap.docs.first as DocumentSnapshot<Map<String, dynamic>>;
        }
      }
      if (!doc.exists || doc.data() == null) {
        setState(() { _error = 'Nie znaleziono dostawy: $trimmed'; _loading = false; });
        return;
      }

      // Suma już pobranych kg dla tego LOT
      final zejsciaSnap = await db.collection('skaner_zejscia')
          .where('lot', isEqualTo: doc.data()!['lot'] ?? trimmed)
          .get();
      final pobrano = zejsciaSnap.docs
          .fold<double>(0.0, (s, d) => s + ((d.data()['waga_zejscia'] as num?)?.toDouble() ?? 0.0));

      setState(() {
        _delivery = {...doc.data()!, '_id': doc.id};
        _pobrano  = pobrano;
        _loading  = false;
      });
    } catch (e) {
      setState(() { _error = 'Błąd: $e'; _loading = false; });
    }
  }

  double get _wagaLimit {
    final raw = (_delivery?['waga_netto'] ?? '').toString()
        .replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(raw) ?? 0.0;
  }

  double get _pozostalo => (_wagaLimit - _pobrano).clamp(0.0, double.infinity);

  double get _wagaZejscia {
    if (_useWaga) {
      return double.tryParse(_wagaCtrl.text.replaceAll(',', '.')) ?? 0.0;
    } else {
      // przelicz z skrzyń: szacunek
      final ilosc = int.tryParse(_iloscCtrl.text) ?? 0;
      final total = ((_delivery?['skrzynie_drew'] as int?) ?? 0) +
                    ((_delivery?['skrzynie_plast'] as int?) ?? 0);
      if (total == 0) return 0.0;
      final wagaNetto = _wagaLimit;
      return ilosc * (wagaNetto / total);
    }
  }

  Future<void> _wykonajZejscie() async {
    final d = _delivery;
    if (d == null) return;
    final waga = _wagaZejscia;
    if (waga <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj wagę lub liczbę skrzyń'), backgroundColor: Colors.red));
      return;
    }
    if (waga > _pozostalo + 0.1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Nie można pobrać ${waga.toStringAsFixed(0)} kg — pozostało ${_pozostalo.toStringAsFixed(0)} kg'),
        backgroundColor: Colors.red));
      return;
    }

    setState(() => _sending = true);
    try {
      final db  = FirebaseFirestore.instance;
      final lot = d['lot'] as String? ?? _lotCtrl.text.trim();
      final wagaPo = _pobrano + waga;

      // 1. Zapisz zejście w skaner_zejscia
      await db.collection('skaner_zejscia').add({
        'lot':             lot,
        'owoc':            d['owoc'] ?? '',
        'odmiana':         d['odmiana'] ?? '',
        'dostawca':        d['dostawca'] ?? '',
        'waga_limit':      _wagaLimit,
        'waga_zejscia':    waga,
        'waga_przed':      _pobrano,
        'waga_po':         wagaPo,
        'metoda':          _useWaga ? 'waga' : 'skrzynie',
        'skrzynie_ilosc':  _useWaga ? 0 : (int.tryParse(_iloscCtrl.text) ?? 0),
        'dyspozytor_id':   widget.user.id,
        'dyspozytor_name': widget.user.name,
        'wniosek_id':      null,
        'created_at':      FieldValue.serverTimestamp(),
      });

      // 2. Zapisz w MCR queue
      final now = DateTime.now();
      final mcrId = 'mcr_skaner_${now.millisecondsSinceEpoch}';
      await db.collection(AppConstants.colMcrQueue).doc(mcrId).set({
        'id':           mcrId,
        'lot':          lot,
        'czas':         '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
        'akcja':        'Zejście',
        'waga_netto':   waga.toStringAsFixed(2),
        'owoc':         d['owoc'] ?? '',
        'odmiana':      d['odmiana'] ?? '',
        'przeznaczenie':d['przeznaczenie'] ?? '',
        'status':       'done',
        'createdAt':    FieldValue.serverTimestamp(),
      });

      if (mounted) {
        final fmt = NumberFormat('#,##0', 'pl_PL');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Zejście ${fmt.format(waga)} kg — pozostało ${fmt.format((_wagaLimit - wagaPo).clamp(0, double.infinity))} kg'),
          backgroundColor: const Color(0xFF2D6A4F),
        ));
        // Reset do kolejnego skanowania
        setState(() {
          _delivery = null;
          _pobrano  = 0.0;
          _sending  = false;
          _lotCtrl.clear();
          _wagaCtrl.clear();
          _iloscCtrl.clear();
        });
        _lotFocus.requestFocus();
      }
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'pl_PL');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Pole LOT ──────────────────────────────────────────────────────
        TextField(
          controller: _lotCtrl,
          focusNode: _lotFocus,
          autofocus: false,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Zeskanuj lub wpisz LOT...',
            hintStyle: const TextStyle(color: kSkanerTextSec),
            filled: true,
            fillColor: kSkanerCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kSkanerPrimary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kSkanerAccent, width: 2),
            ),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kSkanerAccent)),
                  )
                : IconButton(
                    icon: const Icon(Icons.search, color: kSkanerAccent),
                    onPressed: () => _lookupLot(_lotCtrl.text),
                  ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _lookupLot,
        ),

        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ],

        if (_delivery != null) ...[
          const SizedBox(height: 16),

          // ── Karta dostawy + limit ─────────────────────────────────────
          _DeliveryLimitCard(
            delivery: _delivery!,
            pobrano: _pobrano,
            pozostalo: _pozostalo,
            limit: _wagaLimit,
            fmt: fmt,
          ),
          const SizedBox(height: 16),

          // ── Wybór metody ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _MetodaChip(
                label: 'Waga netto [kg]',
                icon: Icons.scale_outlined,
                selected: _useWaga,
                onTap: () => setState(() { _useWaga = true; _iloscCtrl.clear(); }),
              )),
              const SizedBox(width: 10),
              Expanded(child: _MetodaChip(
                label: 'Skrzynie [szt.]',
                icon: Icons.inventory_2_outlined,
                selected: !_useWaga,
                onTap: () => setState(() { _useWaga = false; _wagaCtrl.clear(); }),
              )),
            ],
          ),
          const SizedBox(height: 12),

          // ── Pole wprowadzania ─────────────────────────────────────────
          if (_useWaga)
            TextField(
              controller: _wagaCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Waga zejścia',
                labelStyle: const TextStyle(color: kSkanerTextSec),
                hintText: '0.0',
                hintStyle: const TextStyle(color: kSkanerTextSec),
                suffixText: 'kg',
                suffixStyle: const TextStyle(color: kSkanerTextSec),
                filled: true,
                fillColor: kSkanerCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kSkanerPrimary)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kSkanerAccent, width: 2)),
              ),
            )
          else
            TextField(
              controller: _iloscCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Liczba skrzyń',
                labelStyle: const TextStyle(color: kSkanerTextSec),
                suffixText: 'szt.',
                suffixStyle: const TextStyle(color: kSkanerTextSec),
                filled: true,
                fillColor: kSkanerCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kSkanerPrimary)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kSkanerAccent, width: 2)),
              ),
            ),

          // Szacunek kg dla metody skrzyniowej
          if (!_useWaga && _wagaZejscia > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kSkanerAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kSkanerAccent.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Szacunek: ~${fmt.format(_wagaZejscia)} kg',
                style: const TextStyle(color: kSkanerAccent, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── Przycisk Zejście ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kSkanerAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _sending ? null : _wykonajZejscie,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.arrow_downward),
              label: const Text('Zejście ze stanów',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Karta dostawy z paskiem limitu ────────────────────────────────────────────

class _DeliveryLimitCard extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final double pobrano;
  final double pozostalo;
  final double limit;
  final NumberFormat fmt;

  const _DeliveryLimitCard({
    required this.delivery,
    required this.pobrano,
    required this.pozostalo,
    required this.limit,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final owoc    = delivery['owoc'] as String? ?? '';
    final odmiana = delivery['odmiana'] as String? ?? '';
    final lot     = delivery['lot'] as String? ?? '';
    final dostawca = delivery['dostawca'] as String? ?? '';
    final progress = limit > 0 ? (pobrano / limit).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSkanerCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kSkanerPrimary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$owoc${odmiana.isNotEmpty ? " · $odmiana" : ""}',
            style: const TextStyle(color: kSkanerAccent, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(lot, style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'monospace')),
          const SizedBox(height: 4),
          Text('Dostawca: $dostawca', style: const TextStyle(color: kSkanerTextSec, fontSize: 12)),
          const SizedBox(height: 12),
          // Pasek postępu
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: kSkanerPrimary.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.9 ? Colors.redAccent : kSkanerAccent,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Pobrano: ${fmt.format(pobrano)} kg',
                  style: const TextStyle(color: kSkanerTextSec, fontSize: 12)),
              const Spacer(),
              Text(
                'Pozostało: ${fmt.format(pozostalo)} kg',
                style: TextStyle(
                  color: pozostalo < 100 ? Colors.redAccent : kSkanerAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('Limit (waga netto): ${fmt.format(limit)} kg',
              style: const TextStyle(color: kSkanerTextSec, fontSize: 11)),
        ],
      ),
    );
  }
}

class _MetodaChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MetodaChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? kSkanerAccent.withValues(alpha: 0.15) : kSkanerCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? kSkanerAccent : kSkanerPrimary,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? kSkanerAccent : kSkanerTextSec, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? kSkanerAccent : kSkanerTextSec,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Kafelek wniosku ───────────────────────────────────────────────────────────

class _WniosekTile extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final AppUser user;
  const _WniosekTile({required this.doc, required this.user});

  @override
  Widget build(BuildContext context) {
    final d        = doc.data()!;
    final lot      = d['lot'] as String? ?? '';
    final odmiana  = d['odmiana'] as String? ?? '';
    final owoc     = d['owoc'] as String? ?? '';
    final dostawca = d['dostawca'] as String? ?? '';
    final ilosc    = d['skrzynie_ilosc'] as int? ?? 0;
    final kg       = (d['kg_szacunek'] as num?)?.toDouble() ?? 0.0;
    final ts       = (d['created_at'] as Timestamp?)?.toDate();
    final fmt      = NumberFormat('#,##0', 'pl_PL');
    final timeFmt  = DateFormat('dd.MM HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kSkanerCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kSkanerPrimary, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$owoc${odmiana.isNotEmpty ? " · $odmiana" : ""}',
                          style: const TextStyle(
                              color: kSkanerAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(lot,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                if (ts != null)
                  Text(timeFmt.format(ts),
                      style: const TextStyle(color: kSkanerTextSec, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Dostawca: $dostawca',
                style: const TextStyle(color: kSkanerTextSec, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                _Chip('$ilosc skrz.', kSkanerPrimary),
                const SizedBox(width: 8),
                if (kg > 0) _Chip('~${fmt.format(kg)} kg', const Color(0xFF2D6A4F)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Odrzuć'),
                    onPressed: () => _odrzuc(context, doc.id, user),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSkanerAccent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Akceptuj'),
                    onPressed: () => _akceptuj(context, doc.id, user, d),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _akceptuj(
      BuildContext context, String id, AppUser user, Map<String, dynamic> d) async {
    final lot  = d['lot'] as String? ?? '';
    final kg   = (d['kg_szacunek'] as num?)?.toDouble() ?? 0.0;
    final db   = FirebaseFirestore.instance;

    // Pobierz dane dostawy żeby znać limit
    double limit = 0.0;
    try {
      final docId = lot.replaceAll('/', '_');
      var delivDoc = await db.collection(AppConstants.colDeliveries).doc(docId).get();
      if (!delivDoc.exists) {
        final snap = await db.collection(AppConstants.colDeliveries)
            .where('lot', isEqualTo: lot).limit(1).get();
        if (snap.docs.isNotEmpty) delivDoc = snap.docs.first as DocumentSnapshot<Map<String, dynamic>>;
      }
      if (delivDoc.exists) {
        final raw = (delivDoc.data()?['waga_netto'] ?? '').toString()
            .replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
        limit = double.tryParse(raw) ?? 0.0;
      }
    } catch (_) {}

    // Pobierz już pobrane
    double pobrano = 0.0;
    try {
      final snap = await db.collection('skaner_zejscia').where('lot', isEqualTo: lot).get();
      pobrano = snap.docs.fold(0.0, (s, d) => s + ((d.data()['waga_zejscia'] as num?)?.toDouble() ?? 0.0));
    } catch (_) {}

    final wagaPo = pobrano + kg;

    // 1. Aktualizuj wniosek
    await db.collection('skaner_wnioski').doc(id).update({
      'status':          'zaakceptowany',
      'dyspozytor_id':   user.id,
      'dyspozytor_name': user.name,
      'updated_at':      FieldValue.serverTimestamp(),
    });

    // 2. Zapisz zejście w skaner_zejscia
    if (kg > 0) {
      try {
        await db.collection('skaner_zejscia').add({
          'lot':             lot,
          'owoc':            d['owoc'] ?? '',
          'odmiana':         d['odmiana'] ?? '',
          'dostawca':        d['dostawca'] ?? '',
          'waga_limit':      limit,
          'waga_zejscia':    kg,
          'waga_przed':      pobrano,
          'waga_po':         wagaPo,
          'metoda':          'skrzynie',
          'skrzynie_ilosc':  d['skrzynie_ilosc'] ?? 0,
          'dyspozytor_id':   user.id,
          'dyspozytor_name': user.name,
          'wniosek_id':      id,
          'created_at':      FieldValue.serverTimestamp(),
        });

        // 3. MCR queue
        final now   = DateTime.now();
        final mcrId = 'mcr_skaner_${now.millisecondsSinceEpoch}';
        await db.collection(AppConstants.colMcrQueue).doc(mcrId).set({
          'id':           mcrId,
          'lot':          lot,
          'czas':         '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
          'akcja':        'Zejście',
          'waga_netto':   kg.toStringAsFixed(2),
          'owoc':         d['owoc'] ?? '',
          'odmiana':      d['odmiana'] ?? '',
          'przeznaczenie':d['przeznaczenie'] ?? '',
          'status':       'done',
          'createdAt':    FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaakceptowano i wykonano zejście'),
            backgroundColor: Color(0xFF2D6A4F)));
    }
  }

  Future<void> _odrzuc(BuildContext context, String id, AppUser user) async {
    await FirebaseFirestore.instance.collection('skaner_wnioski').doc(id).update({
      'status':          'odrzucony',
      'dyspozytor_id':   user.id,
      'dyspozytor_name': user.name,
      'updated_at':      FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zlecenie odrzucone'),
            backgroundColor: Colors.redAccent));
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Kafelek użytkownika ───────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;
  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: kSkanerCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: kSkanerPrimary,
                  child: Text(
                    user.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(user.name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                if (user.isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ADMIN',
                        style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: kSkanerTextSec),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Klawiatura PIN ────────────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  const _Numpad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    const rows = [['1','2','3'], ['4','5','6'], ['7','8','9']];
    return Column(
      children: [
        ...rows.map((row) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((d) => _Key(label: d, onTap: () => onDigit(d))).toList(),
          ),
        )),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 72),
            _Key(label: '0', onTap: () => onDigit('0')),
            SizedBox(
              width: 72, height: 72,
              child: Material(
                color: kSkanerCard,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBackspace,
                  child: const Center(
                    child: Icon(Icons.backspace_outlined, color: kSkanerTextSec, size: 24)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Key({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72, height: 72,
      child: Material(
        color: kSkanerPrimary.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }
}
