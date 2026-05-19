import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
              // Kropki PIN
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

class _DyspozytoPanel extends ConsumerStatefulWidget {
  final AppUser user;
  final VoidCallback onLogout;
  const _DyspozytoPanel({required this.user, required this.onLogout});

  @override
  ConsumerState<_DyspozytoPanel> createState() => _DyspozytooPanelState();
}

class _DyspozytooPanelState extends ConsumerState<_DyspozytoPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

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
        bottom: TabBar(
          controller: _tabs,
          labelColor: kSkanerAccent,
          unselectedLabelColor: kSkanerTextSec,
          indicatorColor: kSkanerAccent,
          tabs: const [
            Tab(text: 'Oczekujące'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OczekujaceTab(user: widget.user),
        ],
      ),
    );
  }
}

// ── Zakładka Oczekujące ───────────────────────────────────────────────────────

class _OczekujaceTab extends StatelessWidget {
  final AppUser user;
  const _OczekujaceTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('skaner_wnioski')
          .where('status', isEqualTo: 'oczekujacy')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kSkanerAccent));
        }
        if (snap.hasError) {
          return Center(child: Text('Błąd: ${snap.error}',
              style: const TextStyle(color: Colors.red)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 56, color: kSkanerPrimary),
                SizedBox(height: 12),
                Text('Brak oczekujących zleceń',
                    style: TextStyle(color: kSkanerTextSec, fontSize: 15)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: docs.length,
          itemBuilder: (_, i) => _WniosekTile(
            doc: docs[i] as DocumentSnapshot<Map<String, dynamic>>,
            user: user,
          ),
        );
      },
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
    final d       = doc.data()!;
    final lot     = d['lot'] as String? ?? '';
    final odmiana = d['odmiana'] as String? ?? '';
    final owoc    = d['owoc'] as String? ?? '';
    final dostawca = d['dostawca'] as String? ?? '';
    final ilosc   = d['skrzynie_ilosc'] as int? ?? 0;
    final kg      = (d['kg_szacunek'] as num?)?.toDouble() ?? 0.0;
    final ts      = (d['created_at'] as Timestamp?)?.toDate();
    final fmt     = NumberFormat('#,##0', 'pl_PL');
    final timeFmt = DateFormat('dd.MM HH:mm');

    return Card(
      color: kSkanerCard,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: kSkanerPrimary, width: 1),
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
                    onPressed: () => _akceptuj(context, doc.id, user),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _akceptuj(BuildContext context, String id, AppUser user) async {
    await FirebaseFirestore.instance.collection('skaner_wnioski').doc(id).update({
      'status':         'zaakceptowany',
      'dyspozytor_id':  user.id,
      'dyspozytor_name': user.name,
      'updated_at':     FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zlecenie zaakceptowane'),
            backgroundColor: Color(0xFF2D6A4F)));
    }
  }

  Future<void> _odrzuc(BuildContext context, String id, AppUser user) async {
    await FirebaseFirestore.instance.collection('skaner_wnioski').doc(id).update({
      'status':         'odrzucony',
      'dyspozytor_id':  user.id,
      'dyspozytor_name': user.name,
      'updated_at':     FieldValue.serverTimestamp(),
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
