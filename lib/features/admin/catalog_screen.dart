import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../shared/widgets/offline_banner.dart';

const _suppliersToSeed = [
  ('265', 'Ornysiak Grzegorz'),
  ('266', 'Osiński Roman'),
  ('266', 'Żórawska Anna'),
  ('267', 'Retman Krzysztof'),
  ('268', 'Kalińska'),
  ('269', 'Dominiak Łukasz EKO'),
  ('270', 'Widłak Piotr'),
  ('271', 'Pilacka Agnieszka'),
  ('272', 'Rosłoń Andrzej'),
  ('273', 'Wasilewski Grzegorz'),
  ('274', 'Żólcik Jarosław'),
  ('275', 'Kocyk Marcin'),
  ('276', 'Szymański Rafał'),
  ('277', 'Glinka Paweł'),
  ('278', 'Morawski Rafał'),
  ('279', 'Żurawski'),
  ('280', 'Szymaniak Piotr'),
  ('281', 'Wasilewski Piotr'),
  ('282', 'Arczewski'),
  ('283', 'Zadorski'),
  ('284', 'Łowiecki Zbigniew'),
  ('285', 'Kuklk'),
  ('404', 'Jaworski'),
  ('405', 'Wilga Fruit'),
  ('406', 'Dobrzyński Marcin'),
  ('407', 'Hoffman'),
  ('408', 'Chryn Dariusz'),
  ('409', 'Warzybok Jacek JABTAR'),
  ('410', 'Polny Farm Flasińska'),
  ('412', 'Kępka Mariusz EKO'),
  ('414', 'Stasiak'),
  ('415', 'Stolarski Mariusz'),
  ('416', 'Fudecki'),
  ('417', 'Ślarzyński Przemysław'),
  ('418', 'Paradowska Agnieszka'),
  ('419', 'Smaga'),
  ('420', 'Mir-Pol'),
  ('421', 'Paniec Paweł'),
  ('422', 'Jaradys Łukasz'),
  ('423', 'Pawelec Paweł'),
  ('424', 'Rowalczyk Piotr'),
  ('425', 'Multismak'),
  ('426', 'Sad-Fruit'),
  ('427', 'Lewandowski Adrian'),
  ('428', 'Pietrzak Waldemar'),
  ('429', 'Pro-Agro'),
  ('430', 'ZYSR'),
  ('431', 'Pil Paw'),
  ('432', 'Rechnio Małgorzata'),
  ('433', 'Urbański Janusz'),
  ('434', 'Nowak Wojciech'),
  ('435', 'Zgieta Bogdan'),
  ('436', 'Przychodzeń Mariusz'),
  ('437', 'Przychodzeń Sławomir'),
  ('438', 'RYLEX'),
  ('998', 'GRÓJECKA MBF'),
  ('999', 'MBF'),
];

const _owoceDomyslne = [
  'jabłko', 'gruszka', 'wiśnia', 'rabarbar',
  'truskawka', 'marchewka', 'mango',
];

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OfflineOverflowGuard(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Katalog'),
            leading: BackButton(onPressed: () => context.go('/home')),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Dostawcy'),
                Tab(text: 'Owoce'),
              ],
            ),
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              const Expanded(
                child: TabBarView(
                  children: [
                    _DostawcyTab(),
                    _OwaceTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Zakładka dostawców ─────────────────────────────────────────────────────────

class _DostawcyTab extends StatelessWidget {
  const _DostawcyTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.colSuppliers)
          .orderBy('kod')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showAddDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Dodaj dostawcę'),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryMid),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _seedSuppliers(context, docs),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Seeduj'),
                    style: OutlinedButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            if (snap.connectionState == ConnectionState.waiting)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: docs.isEmpty
                    ? const Center(child: Text('Brak dostawców', style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        itemCount: docs.length,
                        itemBuilder: (ctx, i) {
                          final d = docs[i].data() as Map<String, dynamic>;
                          final kod   = d['kod'] as String? ?? '';
                          final nazwa = d['nazwa'] as String? ?? '';
                          return Dismissible(
                            key: Key(docs[i].id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              color: AppTheme.errorRed,
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            confirmDismiss: (_) => _confirmDelete(ctx),
                            onDismissed: (_) {
                              FirebaseFirestore.instance
                                  .collection(AppConstants.colSuppliers)
                                  .doc(docs[i].id)
                                  .delete();
                            },
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryMid.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    kod,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryDark,
                                    ),
                                  ),
                                ),
                                title: Text(nazwa, style: const TextStyle(fontSize: 14)),
                              ),
                            ),
                          );
                        },
                      ),
              ),
          ],
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    final kodCtrl   = TextEditingController();
    final nazwaCtrl = TextEditingController();
    final formKey   = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dodaj dostawcę'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: kodCtrl,
                decoration: const InputDecoration(labelText: 'Kod (3 cyfry)'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wymagany' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: nazwaCtrl,
                decoration: const InputDecoration(labelText: 'Nazwa'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wymagana' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await FirebaseFirestore.instance
                  .collection(AppConstants.colSuppliers)
                  .add({'kod': kodCtrl.text.trim(), 'nazwa': nazwaCtrl.text.trim()});
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  Future<void> _seedSuppliers(BuildContext context, List<QueryDocumentSnapshot> existing) async {
    final existingKody = existing
        .map((d) => (d.data() as Map<String, dynamic>)['kod'] as String? ?? '')
        .toSet();

    final db    = FirebaseFirestore.instance;
    var batch   = db.batch();
    int count   = 0;
    int written = 0;

    for (final (kod, nazwa) in _suppliersToSeed) {
      if (existingKody.contains(kod)) continue;
      batch.set(db.collection(AppConstants.colSuppliers).doc(), {'kod': kod, 'nazwa': nazwa});
      count++;
      if (count == 500) {
        await batch.commit();
        batch  = db.batch();
        count  = 0;
      }
      written++;
    }
    if (count > 0) await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dodano $written dostawców')),
      );
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Usuń dostawcę'),
          content: const Text('Na pewno usunąć?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Usuń'),
            ),
          ],
        ),
      );
}

// ── Zakładka owoców ────────────────────────────────────────────────────────────

class _OwaceTab extends StatelessWidget {
  const _OwaceTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('owoce')
          .orderBy('nazwa')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showAddDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Dodaj owoc'),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryMid),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _seedOwoce(context, docs),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Seeduj'),
                    style: OutlinedButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            if (snap.connectionState == ConnectionState.waiting)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: docs.isEmpty
                    ? const Center(child: Text('Brak owoców', style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        itemCount: docs.length,
                        itemBuilder: (ctx, i) {
                          final d     = docs[i].data() as Map<String, dynamic>;
                          final nazwa = d['nazwa'] as String? ?? '';
                          return Dismissible(
                            key: Key(docs[i].id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              color: AppTheme.errorRed,
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            confirmDismiss: (_) => _confirmDelete(ctx),
                            onDismissed: (_) {
                              FirebaseFirestore.instance
                                  .collection('owoce')
                                  .doc(docs[i].id)
                                  .delete();
                            },
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.eco_outlined, color: AppTheme.successGreen, size: 20),
                                title: Text(nazwa, style: const TextStyle(fontSize: 14)),
                              ),
                            ),
                          );
                        },
                      ),
              ),
          ],
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    final nazwaCtrl = TextEditingController();
    final formKey   = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dodaj owoc'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nazwaCtrl,
            decoration: const InputDecoration(labelText: 'Nazwa owocu'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Wymagana' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await FirebaseFirestore.instance
                  .collection('owoce')
                  .add({'nazwa': nazwaCtrl.text.trim().toLowerCase()});
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  Future<void> _seedOwoce(BuildContext context, List<QueryDocumentSnapshot> existing) async {
    final existingNames = existing
        .map((d) => (d.data() as Map<String, dynamic>)['nazwa'] as String? ?? '')
        .toSet();

    final db    = FirebaseFirestore.instance;
    final batch = db.batch();
    int written = 0;

    for (final owoc in _owoceDomyslne) {
      if (existingNames.contains(owoc)) continue;
      batch.set(db.collection('owoce').doc(), {'nazwa': owoc});
      written++;
    }
    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dodano $written owoców')),
      );
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Usuń owoc'),
          content: const Text('Na pewno usunąć?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Usuń'),
            ),
          ],
        ),
      );
}
