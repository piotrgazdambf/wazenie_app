import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/models/raport_wstepny.dart';
import '../../shared/widgets/offline_banner.dart';

const _suppliersToSeed = [
  ('001', 'BudziĹ„ski Mariusz'),
  ('002', 'Fijka Roman'),
  ('003', 'Trade Trap Traczyk Marianna'),
  ('004', 'ĹšwiÄ…tek Piotr'),
  ('005', 'Ĺozowski Adam'),
  ('006', 'Kurant Grzegorz'),
  ('007', 'Rog Sad'),
  ('008', 'Mazur Piotr'),
  ('009', 'Pawlica Monika'),
  ('010', 'Ĺozowski Artur'),
  ('011', 'JabĹ‚oĹ„ska Barbara'),
  ('012', 'Sortpak'),
  ('013', 'Sobiepanek Krzysztof'),
  ('014', 'Krawczak Marzanna'),
  ('015', 'Tompex'),
  ('016', 'BÄ…k Wojciech'),
  ('017', 'Fijka Teresa'),
  ('018', 'Regulski Rogsad'),
  ('019', 'Konrad ZwierzyĹ„ski'),
  ('020', 'Kochanowska Violetta'),
  ('021', 'Naduk Monika'),
  ('022', 'Sung Pol'),
  ('023', 'CiĹşdziel ElĹĽbieta'),
  ('024', 'Ĺukawski Sylwester'),
  ('025', 'Paprocki'),
  ('026', 'Ryl Pol'),
  ('027', 'Szynkiewicz Jan'),
  ('028', 'Gulba Waldemar MBF'),
  ('029', 'Oliwia'),
  ('030', 'Jakubczyk'),
  ('031', 'Mroziak Ula'),
  ('032', 'Jakubowski Henryk'),
  ('033', 'Szynkiewicz Jacek'),
  ('034', 'WrĂłbel Dariusz'),
  ('035', 'Keral (Krawiec)'),
  ('036', 'DubiĹ„ski Krzysztof'),
  ('037', 'MÄ™trak Dariusz'),
  ('038', 'Frut Pol 2'),
  ('039', 'New Pol'),
  ('040', 'Pro Pol'),
  ('041', 'Kasprzak Maria'),
  ('042', 'Rudolf Renata'),
  ('043', 'Maciak Artur'),
  ('044', 'Kucharska Elzbieta'),
  ('045', 'KmieÄ‡ Ĺukasz'),
  ('046', 'Markiewicz'),
  ('047', 'Borowiecka'),
  ('048', 'Petrus Piotr SĹ‚owikowski'),
  ('049', 'GON'),
  ('050', 'Wieczorek Kamil'),
  ('051', 'Raj Pol Trade'),
  ('052', 'Michalczyk Albert'),
  ('053', 'Marcin BÄ…k'),
  ('054', 'Szynkiewicz Maria'),
  ('055', 'Szewczyk Marianna'),
  ('056', 'Chodak Mariusz'),
  ('057', 'Kowalczyk MirosĹ‚aw'),
  ('058', 'Kucharska Maria'),
  ('059', 'CÄ…kala Piotr'),
  ('060', 'Mokosa'),
  ('061', 'An Vivo'),
  ('062', 'Budyta SĹ‚awomir'),
  ('063', 'Krawczyk Zbigniew'),
  ('064', 'Milewska Iwona'),
  ('065', 'Janus Arkadiusz'),
  ('066', 'Grzywacz MirosĹ‚aw gruszka'),
  ('067', 'JaskuĹ‚owski EKO'),
  ('068', 'Sobczak'),
  ('069', 'Winiarek'),
  ('070', 'TwĂłj Owoc'),
  ('071', 'Witczak WĹ‚adysĹ‚aw'),
  ('072', 'ZwoliĹ„ski JarosĹ‚aw'),
  ('073', 'MrĂłz Kazimierz'),
  ('074', 'Pindor Marek'),
  ('075', 'Kacprzak Kazimierz'),
  ('076', 'SzczeĹ›niak Anna'),
  ('077', 'StrzyĹĽewski Janusz'),
  ('078', 'Dubielak Karolina'),
  ('079', 'MariaĹ„czyk Zbigniew'),
  ('080', 'WiĹ›niewski Rajmund'),
  ('081', 'Gruppa Organic'),
  ('082', 'Deczewska Zofia'),
  ('083', 'BiaĹ‚kowski Piotr'),
  ('084', 'Giza Mariusz'),
  ('085', 'PaczyĹ„ski Marian'),
  ('086', 'Sobieraj Irena'),
  ('087', 'Krzyszczak BogusĹ‚aw'),
  ('088', 'Gwardys Dorota'),
  ('089', 'Molak Adam'),
  ('090', 'DomaĹ„ska Anna'),
  ('091', 'Szynkiewicz Woj.'),
  ('092', 'Strzelczyk'),
  ('093', 'Mordecki Tomasz'),
  ('094', 'Molak Szczepan'),
  ('095', 'Chmielewski Jerzy'),
  ('096', 'Wojda PaweĹ‚'),
  ('098', 'Chys Artur'),
  ('099', 'Jaworski PaweĹ‚'),
  ('100', 'Rytka Gruszka'),
  ('101', 'GĂłrski PaweĹ‚'),
  ('102', 'Maryniowski Grzegorz'),
  ('103', 'Markiewicz Dominik'),
  ('104', 'KozĹ‚owski Grzegorz'),
  ('105', 'Kulczyk'),
  ('106', 'Iwanowski BogusĹ‚aw'),
  ('107', 'BÄ…kowski RafaĹ‚'),
  ('108', 'Gmurowski SĹ‚awomir'),
  ('109', 'GrzÄ™da Henryk'),
  ('110', 'Przybysz Edward'),
  ('111', 'Rudnicki Grzegorz'),
  ('112', 'SĹ‚omski Filip'),
  ('113', 'ZduĹ„czyk Jan'),
  ('114', 'Kocyk Adam'),
  ('115', 'Wach Jakub'),
  ('116', 'Kowalczyk Daniel'),
  ('117', 'PaczyĹ„ski Marcin'),
  ('118', 'Mroziak JarosĹ‚aw'),
  ('119', 'JeĹĽ Andrzej'),
  ('120', 'Skiba Artur'),
  ('121', 'Sosnowski Ĺukasz'),
  ('122', 'Pawlak WiesĹ‚aw'),
  ('123', 'Szlaski Kamil'),
  ('124', 'BĹ‚eszyĹ„ski Piotr'),
  ('125', 'Paradowski RadosĹ‚aw'),
  ('126', 'Jakubczyk Grzegorz'),
  ('127', 'NaleĹĽyty SĹ‚awomir'),
  ('128', 'Kotwa ZdzisĹ‚aw'),
  ('129', 'Rutka'),
  ('130', 'JĂłĹşwiak Tomasz'),
  ('131', 'Cybulski Janusz'),
  ('132', 'Durka Andrzej'),
  ('133', 'Wasiluk Agnieszka'),
  ('134', 'GĂłrski'),
  ('135', 'Sobczak Bernadetta'),
  ('136', 'Kurach PaweĹ‚'),
  ('137', 'CzerwiĹ„ski Mariusz'),
  ('138', 'SowiĹ„ski Andrzej'),
  ('139', 'GĹ‚owacki Mariusz'),
  ('140', 'Kurach'),
  ('141', 'Smardz'),
  ('142', 'Chojecki Andrzej'),
  ('143', 'Lech RafaĹ‚'),
  ('144', 'Sobotka Kazimierz'),
  ('145', 'KozĹ‚owski Marcin'),
  ('146', 'Wilsad'),
  ('147', 'Sobolewski Tomasz'),
  ('148', 'Bartczak Ewa'),
  ('149', 'Przybyszewski EKO'),
  ('150', 'DÄ…browski Tadeusz'),
  ('151', 'Rudzka Julita'),
  ('152', 'Batte Piotr'),
  ('153', 'DobrzyĹ„ski Janusz'),
  ('154', 'Gwardys'),
  ('155', 'BaraĹ„ska'),
  ('156', 'WojewĂłdzki Eko'),
  ('157', 'Batte Artur'),
  ('158', 'StrzyĹĽewski Piotr'),
  ('159', 'Lusawa Radomir'),
  ('160', 'Soska Andrzej'),
  ('161', 'Stawikowska Iwona'),
  ('162', 'Kasprowicz Jan'),
  ('163', 'WĂłjcik Maciej'),
  ('164', 'Budyta Jacek'),
  ('165', 'Oktabowicz Grzegorz'),
  ('166', 'PotyraĹ‚o WiesĹ‚aw'),
  ('167', 'Siarno Mateusz (SĹ‚omiĹ„ski Emil)'),
  ('168', 'SzymaĹ„ski Piotr'),
  ('169', 'Kowalski Laski'),
  ('170', 'Rybicki'),
  ('171', 'PaczyĹ„ski Robert'),
  ('172', 'PaczyĹ„ski Mariusz'),
  ('173', 'Walczak Maciej'),
  ('174', 'KrĂłl Robert'),
  ('175', 'GĂłrski Glinki'),
  ('176', 'Wrotek Grzegorz'),
  ('177', 'SaĹ‚yga Waldemar'),
  ('178', 'Bio-Vivo'),
  ('179', 'Przybyszewski Wolska ChynĂłw'),
  ('180', 'Matysiak Andrzej'),
  ('181', 'Jezierski'),
  ('182', 'SabaĹ‚a Artur'),
  ('183', 'Giza Karol'),
  ('184', 'Piekarniak'),
  ('185', 'Pagacz Grzegorz'),
  ('186', 'Biedrzycki Jacek'),
  ('187', 'Ĺuczak Eko'),
  ('188', 'KwaĹ›niewski MirosĹ‚aw Grzegorzewice'),
  ('189', 'Nowakowska Edyta'),
  ('190', 'SzczeĹ›niak Grzegorz'),
  ('191', 'MrĂłz Sylwester ChynĂłw'),
  ('192', 'Zakrzewski'),
  ('193', 'Marczak Arkariusz'),
  ('194', 'Nowacka MirosĹ‚awa'),
  ('195', 'Lubowiecki Agnieszka'),
  ('196', 'NaleĹĽyty Jan'),
  ('197', 'Van Rossum'),
  ('198', 'MiÄ…dowicz'),
  ('199', 'Kucharczyk Teresa'),
  ('200', 'GrzegrzĂłĹ‚ka Mariusz'),
  ('201', 'Przybylska WiesĹ‚awa'),
  ('202', 'Kurach Eurosad'),
  ('203', 'Bonder'),
  ('204', 'Chmielewska Karolina'),
  ('205', 'ZieliĹ„ska Malwina'),
  ('206', 'Durka Grzegorz'),
  ('207', 'SowiĹ„ski MirosĹ‚aw'),
  ('208', 'Wielgus'),
  ('209', 'Durka Marek'),
  ('210', 'Kwiatkowski Krzysztof'),
  ('211', 'Pawlak Radomir'),
  ('212', 'Gietka Krzysztof'),
  ('213', 'Kiwak Dariusz'),
  ('214', 'Talaga'),
  ('215', 'NapiĂłrkowska'),
  ('216', 'La Sad'),
  ('217', 'Lewandowski Tomasz'),
  ('218', 'Ĺuczak Ignacy'),
  ('219', 'Polish Agro'),
  ('220', 'Duch SĹ‚awomir'),
  ('221', 'Ag-Pol Nowosielska'),
  ('222', 'Flak Marcin'),
  ('223', 'GĂłrzyĹ„ski Tomasz'),
  ('224', 'StÄ™pieĹ„'),
  ('225', 'KobusiĹ„ski Krzysztof'),
  ('226', 'Czapski'),
  ('227', 'Podymniak Jerzy'),
  ('228', 'SieĹ„kowski RafaĹ‚'),
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
  ('240', 'NadwiĹ›lanka'),
  ('241', 'Mulik'),
  ('242', 'ZieliĹ„ski Piotr'),
  ('243', 'Zapora Krzysztof'),
  ('244', 'Zapora Ĺukasz'),
  ('245', 'BogdaĹ„ski RadosĹ‚aw'),
  ('246', 'Piekarniak Mariusz'),
  ('247', 'Angelard Andrzej'),
  ('248', 'Kostaniak Katarzyna'),
  ('249', 'Wachnik Ryszard'),
  ('250', 'JodĹ‚owski Zbigniew'),
  ('251', 'KsiÄ…ĹĽek'),
  ('252', 'Zdrojek Karolina'),
  ('253', 'Ĺukasiak'),
  ('254', 'StrzeĹĽek Tomasz'),
  ('255', 'BedyĹ„ski Grzegorz'),
  ('256', 'MarszaĹ‚ Stanislaw'),
  ('257', 'DubiĹ„ska ElĹĽbieta'),
  ('258', 'Dylicki Waldemar'),
  ('259', 'Art-Pol Wasiak Artur'),
  ('260', 'Ĺukasiak'),
  ('261', 'Szlasa Dariusz'),
  ('262', 'PaweĹ‚ Jaworski'),
  ('263', 'Szynkiewicz Tomasz'),
  ('264', 'SabaĹ‚a Piotr'),
  ('265', 'KoĹ‚dra MieczysĹ‚aw'),
  ('266', 'Ornysiak Grzegorz'),
  ('267', 'Ĺ»Ăłrawska Anna'),
  ('268', 'Retman Krzysztof'),
  ('269', 'KaliĹ„ska'),
  ('270', 'Dominiak Ĺukasz EKO'),
  ('271', 'WidĹ‚ak Piotr'),
  ('272', 'Pilacka Agnieszka'),
  ('273', 'RosĹ‚oĹ„ Andrzej'),
  ('274', 'Wasilewski Grzegorz'),
  ('275', 'Ĺ»Ăłlcik JarosĹ‚aw'),
  ('276', 'Kocyk Marcin'),
  ('277', 'SzymaĹ„ski RafaĹ‚'),
  ('278', 'Glinka PaweĹ‚'),
  ('279', 'Morawski RafaĹ‚'),
  ('280', 'Ĺ»urawski'),
  ('281', 'Szymaniak Piotr'),
  ('282', 'Wasilewski Piotr'),
  ('283', 'Arczewski'),
  ('284', 'Zadorski'),
  ('285', 'Ĺowiecki Zbigniew'),
  ('286', 'Kuklewski MirosĹ‚aw'),
  ('287', 'KoĹ‚aciĹ„ski'),
  ('288', 'Fabisiak'),
  ('289', 'KilijaĹ„ski Kamil'),
  ('290', 'MaĹ‚achowski Grzegorz'),
  ('291', 'JÄ™dral RafaĹ‚'),
  ('292', 'Olborski Waldemar'),
  ('293', 'Chylak Jakub'),
  ('294', 'KÄ™pka Piotr'),
  ('295', 'PĹ‚ocha Szymon'),
  ('296', 'Cichecki ZdzisĹ‚aw'),
  ('297', 'Marat Wojciech'),
  ('298', 'MrĂłz Sylwester'),
  ('299', 'Staay Food Konrad'),
  ('300', 'WiĹ›niewski Waldemar'),
  ('301', 'Piekarniak Tadeusz'),
  ('302', 'Kowalczyk Janusz POTYCZ'),
  ('303', 'KlaliĹ„ski Kacper'),
  ('304', 'BuĹ‚a MichaĹ‚'),
  ('305', 'ĹapiĹ„ski Robert'),
  ('306', 'Nowakowska Agnieszka'),
  ('307', 'GĹ‚owacki MichaĹ‚'),
  ('308', 'Kalka gruszka'),
  ('309', 'Bartczak BoĹĽena'),
  ('310', 'Rogowski Bartosz Brzezie'),
  ('311', 'SaĹ‚yga E.'),
  ('312', 'Gwardys ElĹĽbieta'),
  ('313', 'Sobczak Agnieszka'),
  ('314', 'PiÄ™tka Agata'),
  ('316', 'PepĹ‚owski'),
  ('317', 'Movena'),
  ('318', 'StrzyĹĽewski Ĺukasz'),
  ('319', 'DobrzyĹ„ski Tomasz'),
  ('320', 'Klimek RafaĹ‚'),
  ('321', 'KuĹĽma Tomasz'),
  ('322', 'ZduĹ„czyk Krzysztof'),
  ('323', 'MrĂłz Emil'),
  ('324', 'Gwara Marek'),
  ('325', 'Gwardys Jan'),
  ('326', 'Wargocki Marek'),
  ('327', 'Milewski RafaĹ‚'),
  ('328', 'Ciok'),
  ('331', 'Fruvo B.V.'),
  ('332', 'Poprawska-Antczak'),
  ('333', 'Kulesza'),
  ('334', 'ZwierzyĹ„ski Konrad'),
  ('335', 'Eko-Fruits'),
  ('336', 'Teum Peters'),
  ('337', 'Sosnowski Witold'),
  ('338', 'Wichniewicz Jacek'),
  ('339', 'Stas NV Belgia'),
  ('340', 'Rylsad (Rylski)'),
  ('341', 'MK Fruit Mariusz KopeÄ‡'),
  ('342', 'SzczeĹ›niak Gabriela'),
  ('343', 'Wojtczak Ĺukasz'),
  ('344', 'Strujno Sad'),
  ('345', 'JaĹ‚ocha Sylwia EKOPLON'),
  ('347', 'Pilacki Tomasz'),
  ('348', 'RogoziĹ„ski Robert'),
  ('349', 'Glinka Janusz'),
  ('350', 'Owocowo'),
  ('351', 'Grupa Owoce Natury'),
  ('352', 'PĹ‚aczek Marcin'),
  ('353', 'Sosnowski Jakub'),
  ('354', 'SaĹ‚yga Grzegorz'),
  ('356', 'NiedziaĹ‚ek Wojciech'),
  ('357', 'SaĹ‚yga MichaĹ‚'),
  ('358', 'Mirkowski JarosĹ‚aw'),
  ('361', 'Kralewski Marek'),
  ('362', 'Donica Marcin'),
  ('363', 'Ĺapacz Grzegorz'),
  ('364', 'Zalewski Bogdan'),
  ('367', 'Przybylski Zbigniew'),
  ('369', 'Kurach Marek'),
  ('370', 'Marchewska Jerzy'),
  ('371', 'Nowak Iwona'),
  ('372', 'MiÄ…dowicz Marek'),
  ('373', 'Pietruszka'),
  ('374', 'JÄ™drzejczyk RafaĹ‚'),
  ('375', 'Piekarniak (Glinki)'),
  ('376', 'Wijaszka Tomasz'),
  ('377', 'Wojstas Dominik'),
  ('378', 'Pilacki Grzegorz'),
  ('379', 'Ĺapacz Tadeusz'),
  ('380', 'PierĹ›ciĹ„ski Ĺukasz'),
  ('381', 'Walczak Bogdan'),
  ('382', 'KamiĹ„ski Artur'),
  ('383', 'ChoiĹ„ski D.'),
  ('384', 'Kurek Zbigniew'),
  ('385', 'Durka Jerzy'),
  ('387', 'MarszaĹ‚ Monika'),
  ('388', 'Wrotek Jan'),
  ('389', 'Knotek Marcin'),
  ('390', 'DÄ…browski Aneta'),
  ('391', 'Karaluch'),
  ('392', 'WiÄ…z'),
  ('393', 'Donica (WARKA)'),
  ('394', 'Oliwa Andrzej'),
  ('395', 'Szymaniak-Muranowicz Hanna'),
  ('396', 'Kanarek Jacek'),
  ('397', 'Soska'),
  ('398', 'Bartczak (Jasieniec)'),
  ('400', 'Pro-Organic'),
  ('401', 'Grupa Konary'),
  ('402', 'Fijka Jan'),
  ('404', 'SaĹ‚yga Jacek'),
  ('405', 'Jaworski'),
  ('406', 'Wilga Fruit'),
  ('407', 'DobrzyĹ„ski Marcin'),
  ('408', 'Hoffman'),
  ('409', 'Chryn Dariusz'),
  ('410', 'Warzybok Jacek JABTAR'),
  ('412', 'Plny Farm FlasiĹ„ska'),
  ('414', 'KÄ™pka Mariusz EKO'),
  ('415', 'Stasiak'),
  ('416', 'Stolarski Mariusz'),
  ('417', 'Fudecki'),
  ('418', 'ĹšlarzyĹ„ski PrzemysĹ‚aw'),
  ('419', 'Paradowska Agnieszka'),
  ('420', 'Smaga'),
  ('421', 'Mir-Pol'),
  ('422', 'Paniec PaweĹ‚'),
  ('423', 'Jaradys Ĺukasz'),
  ('424', 'Pawelec PaweĹ‚'),
  ('425', 'Rowalczyk Piotr'),
  ('426', 'Multismak'),
  ('427', 'Sad-Fruit'),
  ('428', 'Lewandowski Adrian'),
  ('429', 'Pietrzak Waldemar'),
  ('430', 'Pro-Agro'),
  ('431', 'ZYSR'),
  ('432', 'Pil Paw'),
  ('433', 'Rechnio MaĹ‚gorzata'),
  ('434', 'UrbaĹ„ski Janusz'),
  ('435', 'Nowak Wojciech'),
  ('436', 'Zgieta Bogdan'),
  ('437', 'PrzychodzeĹ„ Mariusz'),
  ('438', 'PrzychodzeĹ„ SĹ‚awomir'),
  ('439', 'RYLEX'),
  ('440', 'ZieliĹ„ski Grzegorz'),
  ('441', 'RosiĹ„ska EKO'),
  ('442', 'Kuzma Krzysztof'),
  ('443', 'SkarzyĹ„ska Alina'),
  ('445', 'Marszak Kamil'),
  ('446', 'Szewczyk SĹ‚awomir'),
  ('447', 'Holandia Boskop'),
  ('448', 'Nowak WĹ‚adysĹ‚aw'),
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
  ('464', 'RakiĹ„ska Emilia'),
  ('465', 'WÄ™sek'),
  ('466', 'SĹ‚omski'),
  ('467', 'StÄ™pniak Jacek'),
  ('468', 'Golab Fruits'),
  ('469', 'Sady GrĂłjeckie'),
  ('470', 'SĹ‚owiĹ„ski Kazimierz'),
  ('998', 'GRĂ“JECKA MBF'),
  ('999', 'MBF'),
  ('000', 'MBF'),
];

const _owoceDomyslne = [
  'jabĹ‚ko', 'gruszka', 'wiĹ›nia', 'rabarbar',
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

// â”€â”€ ZakĹ‚adka dostawcĂłw â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                    ? const Center(child: Text('Brak dostawcĂłw', style: TextStyle(color: AppTheme.textSecondary)))
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
        title: const Text('Dodaj dostawcÄ™'),
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
        title: const Text('Resetuj dostawcĂłw'),
        content: const Text('Usunie WSZYSTKICH dostawcĂłw i wgra Ĺ›wieĹĽÄ… listÄ™. Na pewno?'),
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
        SnackBar(content: Text('Zresetowano. Dodano $written dostawcĂłw.')),
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
        SnackBar(content: Text('Dodano $written dostawcĂłw')),
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
          title: const Text('Edytuj dostawcÄ™'),
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
                      label: Text('PrzywrĂłÄ‡ z listy: ${seedEntry.$2}',
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
          title: const Text('UsuĹ„ dostawcÄ™'),
          content: const Text('Na pewno usunÄ…Ä‡?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('UsuĹ„'),
            ),
          ],
        ),
      );
}

// â”€â”€ ZakĹ‚adka owocĂłw â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                    ? const Center(child: Text('Brak owocĂłw', style: TextStyle(color: AppTheme.textSecondary)))
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
        SnackBar(content: Text('Dodano $written owocĂłw')),
      );
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('UsuĹ„ owoc'),
          content: const Text('Na pewno usunÄ…Ä‡?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('UsuĹ„'),
            ),
          ],
        ),
      );
}

// â”€â”€ ZakĹ‚adka raportĂłw wstÄ™pnych (mockowanie / podglÄ…d) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//
// INTEGRACJA: W docelowym flow Generator LOT tworzy dokumenty w kolekcji
// "lot_raporty_wstepne". PoniĹĽszy seed sĹ‚uĹĽy wyĹ‚Ä…cznie do testĂłw lokalnych.
// Seed nie nadpisuje istniejÄ…cych dokumentĂłw (SetOptions merge:true).

const _seedRaporty = [
  {"id": "mock_sok_jablko_1",       "lot_produkcji": "P/0001/26-S", "typ_produkcji": "sok",               "owoc": "JabĹ‚ko",  "brix": 12.4, "witamina_c": 8.2,  "uzysk_pct": 22.0},
  {"id": "mock_sok_gruszka_1",      "lot_produkcji": "P/0002/26-S", "typ_produkcji": "sok",               "owoc": "Gruszka", "brix": 13.1, "witamina_c": 6.5,  "uzysk_pct": 24.0},
  {"id": "mock_sok_jablko_2",       "lot_produkcji": "P/0003/26-S", "typ_produkcji": "sok",               "owoc": "JabĹ‚ko",  "brix": 11.8, "witamina_c": 7.9,  "uzysk_pct": 21.5},
  {"id": "mock_przecier_jablko_1",  "lot_produkcji": "P/0001/26-P", "typ_produkcji": "przecier_nadzienie","owoc": "JabĹ‚ko",  "brix": 14.2, "uzysk_pct": 35.0},
  {"id": "mock_przecier_gruszka_1", "lot_produkcji": "P/0002/26-P", "typ_produkcji": "przecier_nadzienie","owoc": "Gruszka", "brix": 15.0, "uzysk_pct": 33.5},
  {"id": "mock_obieranie_jablko_1", "lot_produkcji": "P/0001/26-O", "typ_produkcji": "obieranie",         "owoc": "JabĹ‚ko"},
];

class _RaportyWstepneTab extends StatefulWidget {
  const _RaportyWstepneTab();
  @override
  State<_RaportyWstepneTab> createState() => _RaportyWstepneTabState();
}

class _RaportyWstepneTabState extends State<_RaportyWstepneTab> {
  bool _seeding  = false;
  bool _cleaning = false;

  // Usuwa stare dokumenty od raporty_produkcyjne z LOT < 153
  Future<void> _cleanOldLots() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Wyczyść stare LOTy', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Usunie dokumenty source_app="raporty_produkcyjne" z LOT < 153.\nTej operacji nie można cofnąć.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('Anuluj')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(_, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cleaning = true);
    final db = FirebaseFirestore.instance;
    int deleted = 0;
    int skipped = 0;
    try {
      final snap = await db.collection(AppConstants.colRaportyWstepne).get();
      for (final doc in snap.docs) {
        final d = doc.data();
        if ((d['source_app'] as String?) != 'raporty_produkcyjne') { skipped++; continue; }
        final lot = (d['lot_produkcji'] as String?) ?? '';
        final prefix = _lotPrefix(lot);
        if (prefix == null || prefix < 153) {
          await doc.reference.delete();
          deleted++;
        } else {
          skipped++;
        }
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Usunięto $deleted dok. | Pozostawiono $skipped'),
        backgroundColor: const Color(0xFF2D6A4F),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  static int? _lotPrefix(String lot) {
    if (!lot.startsWith('LOT C:')) return null;
    final num = lot.replaceFirst('LOT C:', '').trim();
    final m = RegExp(r'^(\d{3})').firstMatch(num);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

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

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: _cleaning ? null : _cleanOldLots,
          icon: _cleaning
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.delete_sweep, size: 16),
          label: const Text('Wyczyść stare LOTy'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 40),
            textStyle: const TextStyle(fontSize: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _seeding ? null : _seed,
          icon: _seeding
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.add_chart, size: 16),
          label: const Text('Seed przykłady'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D6A4F),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 40),
            textStyle: const TextStyle(fontSize: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.colRaportyWstepne)
          .orderBy("created_at", descending: true)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        Widget body;
        if (snap.connectionState == ConnectionState.waiting) {
          body = const Center(child: CircularProgressIndicator());
        } else if (docs.isEmpty) {
          body = const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.article_outlined, color: Colors.white24, size: 52),
                SizedBox(height: 12),
                Text("Brak kart raportów wstępnych",
                    style: TextStyle(color: Colors.white54)),
                SizedBox(height: 8),
                Text("Kliknij 'Seed przykłady' aby dodać dane testowe.",
                    style: TextStyle(color: Colors.white30, fontSize: 12)),
              ],
            ),
          );
        } else {
          body = ListView.builder(
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
        }
        return Column(
          children: [
            _buildHeader(),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

