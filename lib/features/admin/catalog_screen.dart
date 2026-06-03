import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/models/raport_wstepny.dart';
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
  ('440', 'Zieliński Grzegorz'),
  ('441', 'Rosińska EKO'),
  ('442', 'Kuzma Krzysztof'),
  ('443', 'Skarzyńska Alina'),
  ('445', 'Marszak Kamil'),
  ('446', 'Szewczyk Sławomir'),
  ('447', 'Holandia Boskop'),
  ('448', 'Nowak Władysław'),
  ('449', 'Zulczyk Jarek'),
  ('450', 'Krzysztof Bader'),
  ('451', 'Cichocka'),
  ('452', 'Sabala Mirek'),
  ('453', 'Szczepaniak Jola'),
  ('454', 'Wasilewski Hubert'),
  ('455', 'Jakubiak Marcin'),
  ('456', 'Agro Queens'),
  ('457', 'Wasilewski Kazimierz'),
  ('458', 'S.O. Matulka'),
  ('459', 'Galas'),
  ('460', 'Peters Paul'),
  ('461', 'Wdowiak'),
  ('462', 'Sawicki'),
  ('463', 'Dulcaszek Sylwester'),
  ('464', 'Rakińska Emilia'),
  ('465', 'Węsek'),
  ('466', 'Słomski'),
  ('467', 'Stępniak Jacek'),
  ('468', 'Golab Fruits'),
  ('469', 'Sady Grójeckie'),
  ('470', 'Słowiński Kazimierz'),
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
        length: 3,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Katalog'),
            leading: BackButton(onPressed: () => context.go('/home')),
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'Dostawcy'),
                Tab(text: 'Owoce'),
                Tab(text: 'Raporty wstępne'),
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
                    _RaportyWstepneTab(),
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
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _resetAndSeed(context, docs),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Resetuj'),
                    style: OutlinedButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      foregroundColor: AppTheme.errorRed,
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
                                onTap: () => _showEditDialog(ctx, docs[i].id, kod, nazwa),
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
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                                  onPressed: () => _showEditDialog(ctx, docs[i].id, kod, nazwa),
                                ),
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

  Future<void> _resetAndSeed(BuildContext context, List<QueryDocumentSnapshot> existing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resetuj dostawców'),
        content: const Text('Usunie WSZYSTKICH dostawców i wgra świeżą listę. Na pewno?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resetuj i seeduj'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final db = FirebaseFirestore.instance;
    var batch = db.batch();
    int count = 0;
    for (final doc in existing) {
      batch.delete(doc.reference);
      count++;
      if (count == 500) { await batch.commit(); batch = db.batch(); count = 0; }
    }
    if (count > 0) await batch.commit();

    batch = db.batch();
    count = 0;
    int written = 0;
    for (final (kod, nazwa) in _suppliersToSeed) {
      batch.set(db.collection(AppConstants.colSuppliers).doc(), {'kod': kod, 'nazwa': nazwa});
      count++;
      if (count == 500) { await batch.commit(); batch = db.batch(); count = 0; }
      written++;
    }
    if (count > 0) await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zresetowano. Dodano $written dostawców.')),
      );
    }
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

  void _showEditDialog(BuildContext context, String docId, String currentKod, String currentNazwa) {
    final kodCtrl   = TextEditingController(text: currentKod);
    final nazwaCtrl = TextEditingController(text: currentNazwa);
    final formKey   = GlobalKey<FormState>();
    final seedMatches = _suppliersToSeed.where((e) => e.$1 == currentKod);
    final seedEntry   = seedMatches.isEmpty ? null : seedMatches.first;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Edytuj dostawcę'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: kodCtrl,
                  decoration: const InputDecoration(labelText: 'Kod'),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Wymagany' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: nazwaCtrl,
                  decoration: const InputDecoration(labelText: 'Nazwa'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Wymagana' : null,
                ),
                if (seedEntry != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => setS(() {
                        kodCtrl.text   = seedEntry.$1;
                        nazwaCtrl.text = seedEntry.$2;
                      }),
                      icon: const Icon(Icons.restore, size: 16),
                      label: Text('Przywróć z listy: ${seedEntry.$2}',
                          style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryMid,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await FirebaseFirestore.instance
                    .collection(AppConstants.colSuppliers)
                    .doc(docId)
                    .update({
                  'kod':   kodCtrl.text.trim(),
                  'nazwa': nazwaCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
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

// ── Zakładka raportów wstępnych (mockowanie / podgląd) ────────────────────────
//
// INTEGRACJA: W docelowym flow Generator LOT tworzy dokumenty w kolekcji
// "lot_raporty_wstepne". Poniższy seed służy wyłącznie do testów lokalnych.
// Seed nie nadpisuje istniejących dokumentów (SetOptions merge:true).

const _seedRaporty = [
  {"id": "mock_sok_jablko_1",       "lot_produkcji": "P/0001/26-S", "typ_produkcji": "sok",               "owoc": "Jabłko",  "brix": 12.4, "witamina_c": 8.2,  "wytlok_pct": 22.0},
  {"id": "mock_sok_gruszka_1",      "lot_produkcji": "P/0002/26-S", "typ_produkcji": "sok",               "owoc": "Gruszka", "brix": 13.1, "witamina_c": 6.5,  "wytlok_pct": 24.0},
  {"id": "mock_sok_jablko_2",       "lot_produkcji": "P/0003/26-S", "typ_produkcji": "sok",               "owoc": "Jabłko",  "brix": 11.8, "witamina_c": 7.9,  "wytlok_pct": 21.5},
  {"id": "mock_przecier_jablko_1",  "lot_produkcji": "P/0001/26-P", "typ_produkcji": "przecier_nadzienie","owoc": "Jabłko",  "brix": 14.2, "wytlok_pct": 35.0},
  {"id": "mock_przecier_gruszka_1", "lot_produkcji": "P/0002/26-P", "typ_produkcji": "przecier_nadzienie","owoc": "Gruszka", "brix": 15.0, "wytlok_pct": 33.5},
  {"id": "mock_obieranie_jablko_1", "lot_produkcji": "P/0001/26-O", "typ_produkcji": "obieranie",         "owoc": "Jabłko"},
];

class _RaportyWstepneTab extends StatefulWidget {
  const _RaportyWstepneTab();
  @override
  State<_RaportyWstepneTab> createState() => _RaportyWstepneTabState();
}

class _RaportyWstepneTabState extends State<_RaportyWstepneTab> {
  bool _seeding = false;

  Future<void> _seed() async {
    setState(() => _seeding = true);
    final db = FirebaseFirestore.instance;
    try {
      for (final r in _seedRaporty) {
        final id   = r["id"] as String;
        final data = Map<String, dynamic>.from(r)..remove("id");
        data["status"]     = "otwarty";
        data["source_app"] = "wazenie_seed";
        data["created_at"] = FieldValue.serverTimestamp();
        await db.collection(AppConstants.colRaportyWstepne).doc(id).set(data, SetOptions(merge: true));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Dodano 6 przykładowych kart"),
          backgroundColor: Color(0xFF2D6A4F),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Błąd: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _delete(String docId) =>
      FirebaseFirestore.instance.collection(AppConstants.colRaportyWstepne).doc(docId).delete();

  Future<void> _toggleStatus(String docId, String current) =>
      FirebaseFirestore.instance.collection(AppConstants.colRaportyWstepne).doc(docId)
          .update({"status": current == "otwarty" ? "zamkniety" : "otwarty"});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF1A1A2E),
          child: Row(
            children: [
              const Expanded(
                child: Text("Karty raportów wstępnych",
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A4F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _seeding ? null : _seed,
                icon: _seeding
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.add_chart, size: 16),
                label: const Text("Seed przykłady",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(AppConstants.colRaportyWstepne)
                .orderBy("created_at", descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.article_outlined, color: Colors.white24, size: 52),
                      SizedBox(height: 12),
                      Text("Brak kart raportów wstępnych",
                          style: TextStyle(color: Colors.white54)),
                      SizedBox(height: 8),
                      Text("Kliknij Seed przykłady aby dodać dane testowe.",
                          style: TextStyle(color: Colors.white30, fontSize: 12)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc    = docs[i] as DocumentSnapshot<Map<String, dynamic>>;
                  final r      = RaportWstepny.fromFirestore(doc);
                  final closed = r.status == "zamkniety";
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: closed ? Colors.white12 : r.typProdukcji.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: r.typProdukcji.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(r.typProdukcji.icon,
                            color: closed ? Colors.white30 : r.typProdukcji.color, size: 18),
                      ),
                      title: Text(r.lotProdukcji,
                          style: TextStyle(
                              color: closed ? Colors.white38 : Colors.white,
                              fontFamily: "monospace",
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      subtitle: Text(
                        "${r.owoc}  ·  ${r.typProdukcji.label}"
                        "${r.brix != null ? "  ·  BRIX ${r.brix!.toStringAsFixed(1)}" : ""}",
                        style: TextStyle(
                            color: closed ? Colors.white24 : Colors.white54, fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _toggleStatus(doc.id, r.status),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: closed ? Colors.white12 : const Color(0xFF2D6A4F).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                closed ? "zamknięty" : "otwarty",
                                style: TextStyle(
                                    color: closed ? Colors.white30 : const Color(0xFF52B788),
                                    fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                            onPressed: () => _delete(doc.id),
                            tooltip: "Usuń",
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
