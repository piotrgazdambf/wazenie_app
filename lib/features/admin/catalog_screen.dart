import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../shared/widgets/offline_banner.dart';

const _suppliersToSeed = [
  ('001', 'Budziński Mariusz'),
  ('002', 'Fijka Roman'),
  ('003', 'Trade Trap Traczyk Marianna'),
  ('004', 'Świątek Piotr'),
  ('005', 'Łozowski Adam'),
  ('006', 'Kurant Grzegorz'),
  ('007', 'Rog Sad'),
  ('008', 'Mazur Piotr'),
  ('009', 'Pawlica Monika'),
  ('010', 'Łozowski Artur'),
  ('011', 'Jabłońska Barbara'),
  ('012', 'Sortpak'),
  ('013', 'Sobiepanek Krzysztof'),
  ('014', 'Krawczak Marzanna'),
  ('015', 'Tompex'),
  ('016', 'Bąk Wojciech'),
  ('017', 'Fijka Teresa'),
  ('018', 'Regulski Rogsad'),
  ('019', 'Konrad Zwierzyński'),
  ('020', 'Kochanowska Violetta'),
  ('021', 'Naduk Monika'),
  ('022', 'Sung Pol'),
  ('023', 'Ciździel Elżbieta'),
  ('024', 'Łukawski Sylwester'),
  ('025', 'Paprocki'),
  ('026', 'Ryl Pol'),
  ('027', 'Szynkiewicz Jan'),
  ('028', 'Gulba Waldemar MBF'),
  ('029', 'Oliwia'),
  ('030', 'Jakubczyk'),
  ('031', 'Mroziak Ula'),
  ('032', 'Jakubowski Henryk'),
  ('033', 'Szynkiewicz Jacek'),
  ('034', 'Wróbel Dariusz'),
  ('035', 'Keral (Krawiec)'),
  ('036', 'Dubiński Krzysztof'),
  ('037', 'Mętrak Dariusz'),
  ('038', 'Frut Pol 2'),
  ('039', 'New Pol'),
  ('040', 'Pro Pol'),
  ('041', 'Kasprzak Maria'),
  ('042', 'Rudolf Renata'),
  ('043', 'Maciak Artur'),
  ('044', 'Kucharska Elzbieta'),
  ('045', 'Kmieć Łukasz'),
  ('046', 'Markiewicz'),
  ('047', 'Borowiecka'),
  ('048', 'Petrus Piotr Słowikowski'),
  ('049', 'GON'),
  ('050', 'Wieczorek Kamil'),
  ('051', 'Raj Pol Trade'),
  ('052', 'Michalczyk Albert'),
  ('053', 'Marcin Bąk'),
  ('054', 'Szynkiewicz Maria'),
  ('055', 'Szewczyk Marianna'),
  ('056', 'Chodak Mariusz'),
  ('057', 'Kowalczyk Mirosław'),
  ('058', 'Kucharska Maria'),
  ('059', 'Cąkala Piotr'),
  ('060', 'Mokosa'),
  ('061', 'An Vivo'),
  ('062', 'Budyta Sławomir'),
  ('063', 'Krawczyk Zbigniew'),
  ('064', 'Milewska Iwona'),
  ('065', 'Janus Arkadiusz'),
  ('066', 'Grzywacz Mirosław gruszka'),
  ('067', 'Jaskułowski EKO'),
  ('068', 'Sobczak'),
  ('069', 'Winiarek'),
  ('070', 'Twój Owoc'),
  ('071', 'Witczak Władysław'),
  ('072', 'Zwoliński Jarosław'),
  ('073', 'Mróz Kazimierz'),
  ('074', 'Pindor Marek'),
  ('075', 'Kacprzak Kazimierz'),
  ('076', 'Szcześniak Anna'),
  ('077', 'Strzyżewski Janusz'),
  ('078', 'Dubielak Karolina'),
  ('079', 'Mariańczyk Zbigniew'),
  ('080', 'Wiśniewski Rajmund'),
  ('081', 'Gruppa Organic'),
  ('082', 'Deczewska Zofia'),
  ('083', 'Białkowski Piotr'),
  ('084', 'Giza Mariusz'),
  ('085', 'Paczyński Marian'),
  ('086', 'Sobieraj Irena'),
  ('087', 'Krzyszczak Bogusław'),
  ('088', 'Gwardys Dorota'),
  ('089', 'Molak Adam'),
  ('090', 'Domańska Anna'),
  ('091', 'Szynkiewicz Woj.'),
  ('092', 'Strzelczyk'),
  ('093', 'Mordecki Tomasz'),
  ('094', 'Molak Szczepan'),
  ('095', 'Chmielewski Jerzy'),
  ('096', 'Wojda Paweł'),
  ('098', 'Chys Artur'),
  ('099', 'Jaworski Paweł'),
  ('100', 'Rytka Gruszka'),
  ('101', 'Górski Paweł'),
  ('102', 'Maryniowski Grzegorz'),
  ('103', 'Markiewicz Dominik'),
  ('104', 'Kozłowski Grzegorz'),
  ('105', 'Kulczyk'),
  ('106', 'Iwanowski Bogusław'),
  ('107', 'Bąkowski Rafał'),
  ('108', 'Gmurowski Sławomir'),
  ('109', 'Grzęda Henryk'),
  ('110', 'Przybysz Edward'),
  ('111', 'Rudnicki Grzegorz'),
  ('112', 'Słomski Filip'),
  ('113', 'Zduńczyk Jan'),
  ('114', 'Kocyk Adam'),
  ('115', 'Wach Jakub'),
  ('116', 'Kowalczyk Daniel'),
  ('117', 'Paczyński Marcin'),
  ('118', 'Mroziak Jarosław'),
  ('119', 'Jeż Andrzej'),
  ('120', 'Skiba Artur'),
  ('121', 'Sosnowski Łukasz'),
  ('122', 'Pawlak Wiesław'),
  ('123', 'Szlaski Kamil'),
  ('124', 'Błeszyński Piotr'),
  ('125', 'Paradowski Radosław'),
  ('126', 'Jakubczyk Grzegorz'),
  ('127', 'Należyty Sławomir'),
  ('128', 'Kotwa Zdzisław'),
  ('129', 'Rutka'),
  ('130', 'Jóźwiak Tomasz'),
  ('131', 'Cybulski Janusz'),
  ('132', 'Durka Andrzej'),
  ('133', 'Wasiluk Agnieszka'),
  ('134', 'Górski'),
  ('135', 'Sobczak Bernadetta'),
  ('136', 'Kurach Paweł'),
  ('137', 'Czerwiński Mariusz'),
  ('138', 'Sowiński Andrzej'),
  ('139', 'Głowacki Mariusz'),
  ('140', 'Kurach'),
  ('141', 'Smardz'),
  ('142', 'Chojecki Andrzej'),
  ('143', 'Lech Rafał'),
  ('144', 'Sobotka Kazimierz'),
  ('145', 'Kozłowski Marcin'),
  ('146', 'Wilsad'),
  ('147', 'Sobolewski Tomasz'),
  ('148', 'Bartczak Ewa'),
  ('149', 'Przybyszewski EKO'),
  ('150', 'Dąbrowski Tadeusz'),
  ('151', 'Rudzka Julita'),
  ('152', 'Batte Piotr'),
  ('153', 'Dobrzyński Janusz'),
  ('154', 'Gwardys'),
  ('155', 'Barańska'),
  ('156', 'Wojewódzki Eko'),
  ('157', 'Batte Artur'),
  ('158', 'Strzyżewski Piotr'),
  ('159', 'Lusawa Radomir'),
  ('160', 'Soska Andrzej'),
  ('161', 'Stawikowska Iwona'),
  ('162', 'Kasprowicz Jan'),
  ('163', 'Wójcik Maciej'),
  ('164', 'Budyta Jacek'),
  ('165', 'Oktabowicz Grzegorz'),
  ('166', 'Potyrało Wiesław'),
  ('167', 'Siarno Mateusz (Słomiński Emil)'),
  ('168', 'Szymański Piotr'),
  ('169', 'Kowalski Laski'),
  ('170', 'Rybicki'),
  ('171', 'Paczyński Robert'),
  ('172', 'Paczyński Mariusz'),
  ('173', 'Walczak Maciej'),
  ('174', 'Król Robert'),
  ('175', 'Górski Glinki'),
  ('176', 'Wrotek Grzegorz'),
  ('177', 'Sałyga Waldemar'),
  ('178', 'Bio-Vivo'),
  ('179', 'Przybyszewski Wolska Chynów'),
  ('180', 'Matysiak Andrzej'),
  ('181', 'Jezierski'),
  ('182', 'Sabała Artur'),
  ('183', 'Giza Karol'),
  ('184', 'Piekarniak'),
  ('185', 'Pagacz Grzegorz'),
  ('186', 'Biedrzycki Jacek'),
  ('187', 'Łuczak Eko'),
  ('188', 'Kwaśniewski Mirosław Grzegorzewice'),
  ('189', 'Nowakowska Edyta'),
  ('190', 'Szcześniak Grzegorz'),
  ('191', 'Mróz Sylwester Chynów'),
  ('192', 'Zakrzewski'),
  ('193', 'Marczak Arkariusz'),
  ('194', 'Nowacka Mirosława'),
  ('195', 'Lubowiecki Agnieszka'),
  ('196', 'Należyty Jan'),
  ('197', 'Van Rossum'),
  ('198', 'Miądowicz'),
  ('199', 'Kucharczyk Teresa'),
  ('200', 'Grzegrzółka Mariusz'),
  ('201', 'Przybylska Wiesława'),
  ('202', 'Kurach Eurosad'),
  ('203', 'Bonder'),
  ('204', 'Chmielewska Karolina'),
  ('205', 'Zielińska Malwina'),
  ('206', 'Durka Grzegorz'),
  ('207', 'Sowiński Mirosław'),
  ('208', 'Wielgus'),
  ('209', 'Durka Marek'),
  ('210', 'Kwiatkowski Krzysztof'),
  ('211', 'Pawlak Radomir'),
  ('212', 'Gietka Krzysztof'),
  ('213', 'Kiwak Dariusz'),
  ('214', 'Talaga'),
  ('215', 'Napiórkowska'),
  ('216', 'La Sad'),
  ('217', 'Lewandowski Tomasz'),
  ('218', 'Łuczak Ignacy'),
  ('219', 'Polish Agro'),
  ('220', 'Duch Sławomir'),
  ('221', 'Ag-Pol Nowosielska'),
  ('222', 'Flak Marcin'),
  ('223', 'Górzyński Tomasz'),
  ('224', 'Stępień'),
  ('225', 'Kobusiński Krzysztof'),
  ('226', 'Czapski'),
  ('227', 'Podymniak Jerzy'),
  ('228', 'Sieńkowski Rafał'),
  ('229', 'Anuszkiewicz'),
  ('230', 'Kwiatkowski Sylwester'),
  ('231', 'Lesiak Cezary'),
  ('232', 'Czamara Andrzej'),
  ('233', 'Kulmatycki Dariusz'),
  ('234', 'Pik Owoc'),
  ('235', 'Alco'),
  ('236', 'Kowalski Michal'),
  ('237', 'Szumpur'),
  ('238', 'Bialski Owoc'),
  ('239', 'Wit Pol'),
  ('240', 'Nadwiślanka'),
  ('241', 'Mulik'),
  ('242', 'Zieliński Piotr'),
  ('243', 'Zapora Krzysztof'),
  ('244', 'Zapora Łukasz'),
  ('245', 'Bogdański Radosław'),
  ('246', 'Piekarniak Mariusz'),
  ('247', 'Angelard Andrzej'),
  ('248', 'Kostaniak Katarzyna'),
  ('249', 'Wachnik Ryszard'),
  ('250', 'Jodłowski Zbigniew'),
  ('251', 'Książek'),
  ('252', 'Zdrojek Karolina'),
  ('253', 'Łukasiak'),
  ('254', 'Strzeżek Tomasz'),
  ('255', 'Bedyński Grzegorz'),
  ('256', 'Marszał Stanislaw'),
  ('257', 'Dubińska Elżbieta'),
  ('258', 'Dylicki Waldemar'),
  ('259', 'Art-Pol Wasiak Artur'),
  ('260', 'Łukasiak'),
  ('261', 'Szlasa Dariusz'),
  ('262', 'Paweł Jaworski'),
  ('263', 'Szynkiewicz Tomasz'),
  ('264', 'Sabała Piotr'),
  ('265', 'Kołdra Mieczysław'),
  ('266', 'Ornysiak Grzegorz'),
  ('267', 'Żórawska Anna'),
  ('268', 'Retman Krzysztof'),
  ('269', 'Kalińska'),
  ('270', 'Dominiak Łukasz EKO'),
  ('271', 'Widłak Piotr'),
  ('272', 'Pilacka Agnieszka'),
  ('273', 'Rosłoń Andrzej'),
  ('274', 'Wasilewski Grzegorz'),
  ('275', 'Żólcik Jarosław'),
  ('276', 'Kocyk Marcin'),
  ('277', 'Szymański Rafał'),
  ('278', 'Glinka Paweł'),
  ('279', 'Morawski Rafał'),
  ('280', 'Żurawski'),
  ('281', 'Szymaniak Piotr'),
  ('282', 'Wasilewski Piotr'),
  ('283', 'Arczewski'),
  ('284', 'Zadorski'),
  ('285', 'Łowiecki Zbigniew'),
  ('286', 'Kuklewski Mirosław'),
  ('287', 'Kołaciński'),
  ('288', 'Fabisiak'),
  ('289', 'Kilijański Kamil'),
  ('290', 'Małachowski Grzegorz'),
  ('291', 'Jędral Rafał'),
  ('292', 'Olborski Waldemar'),
  ('293', 'Chylak Jakub'),
  ('294', 'Kępka Piotr'),
  ('295', 'Płocha Szymon'),
  ('296', 'Cichecki Zdzisław'),
  ('297', 'Marat Wojciech'),
  ('298', 'Mróz Sylwester'),
  ('299', 'Staay Food Konrad'),
  ('300', 'Wiśniewski Waldemar'),
  ('301', 'Piekarniak Tadeusz'),
  ('302', 'Kowalczyk Janusz POTYCZ'),
  ('303', 'Klaliński Kacper'),
  ('304', 'Buła Michał'),
  ('305', 'Łapiński Robert'),
  ('306', 'Nowakowska Agnieszka'),
  ('307', 'Głowacki Michał'),
  ('308', 'Kalka gruszka'),
  ('309', 'Bartczak Bożena'),
  ('310', 'Rogowski Bartosz Brzezie'),
  ('311', 'Sałyga E.'),
  ('312', 'Gwardys Elżbieta'),
  ('313', 'Sobczak Agnieszka'),
  ('314', 'Piętka Agata'),
  ('316', 'Pepłowski'),
  ('317', 'Movena'),
  ('318', 'Strzyżewski Łukasz'),
  ('319', 'Dobrzyński Tomasz'),
  ('320', 'Klimek Rafał'),
  ('321', 'Kużma Tomasz'),
  ('322', 'Zduńczyk Krzysztof'),
  ('323', 'Mróz Emil'),
  ('324', 'Gwara Marek'),
  ('325', 'Gwardys Jan'),
  ('326', 'Wargocki Marek'),
  ('327', 'Milewski Rafał'),
  ('328', 'Ciok'),
  ('331', 'Fruvo B.V.'),
  ('332', 'Poprawska-Antczak'),
  ('333', 'Kulesza'),
  ('334', 'Zwierzyński Konrad'),
  ('335', 'Eko-Fruits'),
  ('336', 'Teum Peters'),
  ('337', 'Sosnowski Witold'),
  ('338', 'Wichniewicz Jacek'),
  ('339', 'Stas NV Belgia'),
  ('340', 'Rylsad (Rylski)'),
  ('341', 'MK Fruit Mariusz Kopeć'),
  ('342', 'Szcześniak Gabriela'),
  ('343', 'Wojtczak Łukasz'),
  ('344', 'Strujno Sad'),
  ('345', 'Jałocha Sylwia EKOPLON'),
  ('347', 'Pilacki Tomasz'),
  ('348', 'Rogoziński Robert'),
  ('349', 'Glinka Janusz'),
  ('350', 'Owocowo'),
  ('351', 'Grupa Owoce Natury'),
  ('352', 'Płaczek Marcin'),
  ('353', 'Sosnowski Jakub'),
  ('354', 'Sałyga Grzegorz'),
  ('356', 'Niedziałek Wojciech'),
  ('357', 'Sałyga Michał'),
  ('358', 'Mirkowski Jarosław'),
  ('361', 'Kralewski Marek'),
  ('362', 'Donica Marcin'),
  ('363', 'Łapacz Grzegorz'),
  ('364', 'Zalewski Bogdan'),
  ('367', 'Przybylski Zbigniew'),
  ('369', 'Kurach Marek'),
  ('370', 'Marchewska Jerzy'),
  ('371', 'Nowak Iwona'),
  ('372', 'Miądowicz Marek'),
  ('373', 'Pietruszka'),
  ('374', 'Jędrzejczyk Rafał'),
  ('375', 'Piekarniak (Glinki)'),
  ('376', 'Wijaszka Tomasz'),
  ('377', 'Wojstas Dominik'),
  ('378', 'Pilacki Grzegorz'),
  ('379', 'Łapacz Tadeusz'),
  ('380', 'Pierściński Łukasz'),
  ('381', 'Walczak Bogdan'),
  ('382', 'Kamiński Artur'),
  ('383', 'Choiński D.'),
  ('384', 'Kurek Zbigniew'),
  ('385', 'Durka Jerzy'),
  ('387', 'Marszał Monika'),
  ('388', 'Wrotek Jan'),
  ('389', 'Knotek Marcin'),
  ('390', 'Dąbrowski Aneta'),
  ('391', 'Karaluch'),
  ('392', 'Wiąz'),
  ('393', 'Donica (WARKA)'),
  ('394', 'Oliwa Andrzej'),
  ('395', 'Szymaniak-Muranowicz Hanna'),
  ('396', 'Kanarek Jacek'),
  ('397', 'Soska'),
  ('398', 'Bartczak (Jasieniec)'),
  ('400', 'Pro-Organic'),
  ('401', 'Grupa Konary'),
  ('402', 'Fijka Jan'),
  ('404', 'Sałyga Jacek'),
  ('405', 'Jaworski'),
  ('406', 'Wilga Fruit'),
  ('407', 'Dobrzyński Marcin'),
  ('408', 'Hoffman'),
  ('409', 'Chryn Dariusz'),
  ('410', 'Warzybok Jacek JABTAR'),
  ('412', 'Plny Farm Flasińska'),
  ('414', 'Kępka Mariusz EKO'),
  ('415', 'Stasiak'),
  ('416', 'Stolarski Mariusz'),
  ('417', 'Fudecki'),
  ('418', 'Ślarzyński Przemysław'),
  ('419', 'Paradowska Agnieszka'),
  ('420', 'Smaga'),
  ('421', 'Mir-Pol'),
  ('422', 'Paniec Paweł'),
  ('423', 'Jaradys Łukasz'),
  ('424', 'Pawelec Paweł'),
  ('425', 'Rowalczyk Piotr'),
  ('426', 'Multismak'),
  ('427', 'Sad-Fruit'),
  ('428', 'Lewandowski Adrian'),
  ('429', 'Pietrzak Waldemar'),
  ('430', 'Pro-Agro'),
  ('431', 'ZYSR'),
  ('432', 'Pil Paw'),
  ('433', 'Rechnio Małgorzata'),
  ('434', 'Urbański Janusz'),
  ('435', 'Nowak Wojciech'),
  ('436', 'Zgieta Bogdan'),
  ('437', 'Przychodzeń Mariusz'),
  ('438', 'Przychodzeń Sławomir'),
  ('439', 'RYLEX'),
  ('998', 'GRÓJECKA MBF'),
  ('999', 'MBF'),
  ('000', 'MBF'),
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
