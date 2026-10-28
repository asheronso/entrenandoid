import 'dart:async';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'db.dart';
import 'models.dart';

String day(String iso) => iso.substring(0, 10);

Widget withUser(Widget Function(BuildContext, int) b) => ListenableBuilder(
    listenable: Listenable.merge([dataVersion, currentUser]),
    builder: (c, _) {
      final u = currentUser.value;
      if (u == null) return const Center(child: Text('Crea un perfil en Inicio'));
      return b(c, u);
    });

const _loader = Center(child: CircularProgressIndicator());

Future<void> addUserDialog(BuildContext c) async {
  final t = TextEditingController();
  final ok = await showDialog<bool>(
      context: c,
      builder: (ctx) => AlertDialog(
            title: const Text('Nuevo perfil'),
            content: TextField(controller: t, autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre o alias')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
            ],
          ));
  if (ok == true && t.text.trim().isNotEmpty) {
    currentUser.value = await Db.addUser(t.text.trim());
    dataVersion.value++;
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('GymProgress'), actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ]),
        body: IndexedStack(index: i, children: const [
          HomeScreen(), TrainScreen(), HistoryScreen(), ProgressScreen()
        ]),
        bottomNavigationBar: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: (v) => setState(() => i = v),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
              NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Entrenar'),
              NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
              NavigationDestination(icon: Icon(Icons.show_chart), label: 'Progreso'),
            ]),
      );
}

// ---------------- INICIO ----------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([dataVersion, currentUser]),
      builder: (c, _) => FutureBuilder<List<Row>>(
          future: Db.users(),
          builder: (c, s) {
            if (!s.hasData) return _loader;
            final us = s.data!;
            if (us.isNotEmpty && !us.any((u) => u['id'] == currentUser.value)) {
              Future.microtask(() => currentUser.value = us.first['id'] as int);
            }
            if (us.isEmpty) {
              return Center(
                  child: FilledButton.icon(
                      onPressed: () => addUserDialog(c),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Crear primer perfil')));
            }
            return ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                Expanded(
                    child: DropdownButton<int>(
                        isExpanded: true,
                        value: us.any((u) => u['id'] == currentUser.value) ? currentUser.value : null,
                        items: [
                          for (final u in us)
                            DropdownMenuItem(value: u['id'] as int, child: Text(u['name'] as String))
                        ],
                        onChanged: (v) => currentUser.value = v)),
                IconButton(icon: const Icon(Icons.person_add), onPressed: () => addUserDialog(c)),
              ]),
              if (currentUser.value != null)
                FutureBuilder<Row>(
                    future: Db.stats(currentUser.value!),
                    builder: (c, s) {
                      if (!s.hasData) return _loader;
                      final r = s.data!;
                      final mins = ((r['secs'] as num) / 60).round();
                      Widget card(String t, String v) => Card(
                          child: SizedBox(
                              width: 160,
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(v, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                    Text(t),
                                  ]))));
                      return Wrap(children: [
                        card('Sesiones', '${r['ses']}'),
                        card('Ejercicios', '${r['nex']}'),
                        card('Series', '${r['nsets']}'),
                        card('Repeticiones', '${r['reps']}'),
                        card('Volumen (est. de carga)', '${(r['vol'] as num).toStringAsFixed(0)} kg'),
                        card('Tiempo acumulado', '$mins min'),
                      ]);
                    }),
            ]);
          }));
}

// ---------------- ENTRENAR ----------------
class SetRow {
  final reps = TextEditingController();
  final w = TextEditingController();
  final rest = TextEditingController(text: '90');
  SetRow([String r = '', String ww = '', String rs = '90']) {
    reps.text = r; w.text = ww; rest.text = rs;
  }
}

class ExItem {
  final int id;
  final String name;
  final List<SetRow> sets = [SetRow()];
  ExItem(this.id, this.name);
}

Future<ExItem?> pickExercise(BuildContext c) async {
  final all = await Db.exercises();
  if (!c.mounted) return null;
  String q = '';
  return showDialog<ExItem>(
      context: c,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
            final f = all.where((e) => (e['name'] as String).toLowerCase().contains(q.toLowerCase())).toList();
            final exact = f.any((e) => (e['name'] as String).toLowerCase() == q.trim().toLowerCase());
            return AlertDialog(
                title: const Text('Ejercicio'),
                content: SizedBox(
                    width: double.maxFinite,
                    height: 420,
                    child: Column(children: [
                      TextField(
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar'),
                          onChanged: (v) => setS(() => q = v)),
                      Expanded(
                          child: ListView(children: [
                        for (final e in f)
                          ListTile(
                              title: Text(e['name'] as String),
                              subtitle: Text(e['muscle_group'] as String),
                              onTap: () => Navigator.pop(ctx, ExItem(e['id'] as int, e['name'] as String))),
                        if (q.trim().isNotEmpty && !exact)
                          ListTile(
                              leading: const Icon(Icons.add),
                              title: Text('Crear "${q.trim()}"'),
                              onTap: () async {
                                final id = await Db.addExercise(q.trim());
                                if (ctx.mounted) Navigator.pop(ctx, ExItem(id, q.trim()));
                              }),
                      ]))
                    ])));
          }));
}

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});
  @override
  State<TrainScreen> createState() => _TrainState();
}

class _TrainState extends State<TrainScreen> {
  DateTime date = DateTime.now();
  DateTime? started;
  final items = <ExItem>[];
  Timer? timer;
  int remaining = 0;
  final defRest = TextEditingController(text: '90');

  @override
  void dispose() { timer?.cancel(); super.dispose(); }

  void startRest(int s) {
    timer?.cancel();
    setState(() => remaining = s);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remaining <= 1) {
        t.cancel();
        setState(() => remaining = 0);
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Descanso terminado!')));
        }
      } else {
        setState(() => remaining--);
      }
    });
  }

  Widget num(TextEditingController c, String l, bool dec) => TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: dec),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(dec ? r'[0-9.,]' : r'[0-9]'))],
      decoration: InputDecoration(labelText: l, isDense: true, border: const OutlineInputBorder()));

  Future<void> save() async {
    final uid = currentUser.value;
    final m = ScaffoldMessenger.of(context);
    if (uid == null) { m.showSnackBar(const SnackBar(content: Text('Selecciona un usuario en Inicio'))); return; }
    final data = <(int, List<SetData>)>[];
    for (final e in items) {
      final sets = <SetData>[];
      for (final s in e.sets) {
        final r = int.tryParse(s.reps.text);
        final w = double.tryParse(s.w.text.replaceAll(',', '.'));
        if (r == null || w == null) {
          m.showSnackBar(SnackBar(content: Text('Completa repeticiones y peso en ${e.name} (0 kg es válido)')));
          return;
        }
        sets.add(SetData(r, w, int.tryParse(s.rest.text) ?? 0));
      }
      if (sets.isNotEmpty) data.add((e.id, sets));
    }
    if (data.isEmpty) { m.showSnackBar(const SnackBar(content: Text('Añade al menos un ejercicio con series'))); return; }
    await Db.saveSession(uid, date, DateTime.now().difference(started ?? DateTime.now()).inSeconds, data);
    setState(() { items.clear(); started = null; });
    dataVersion.value++;
    m.showSnackBar(const SnackBar(content: Text('Sesión guardada')));
  }

  @override
  Widget build(BuildContext context) {
    final mm = (remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (remaining % 60).toString().padLeft(2, '0');
    return ListView(padding: const EdgeInsets.all(12), children: [
      ListTile(
          leading: const Icon(Icons.calendar_today),
          title: Text(day(date.toIso8601String())),
          onTap: () async {
            final d = await showDatePicker(
                context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (d != null) setState(() => date = d);
          }),
      for (final e in items)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: Text(e.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => items.remove(e))),
                  ]),
                  for (var j = 0; j < e.sets.length; j++)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          SizedBox(width: 22, child: Text('${j + 1}')),
                          Expanded(child: num(e.sets[j].reps, 'Reps', false)),
                          const SizedBox(width: 6),
                          Expanded(child: num(e.sets[j].w, 'Kg', true)),
                          const SizedBox(width: 6),
                          Expanded(child: num(e.sets[j].rest, 'Desc s', false)),
                          IconButton(
                              visualDensity: VisualDensity.compact, padding: EdgeInsets.zero,
                              tooltip: 'Duplicar',
                              icon: const Icon(Icons.copy),
                              onPressed: () => setState(() => e.sets.insert(j + 1,
                                  SetRow(e.sets[j].reps.text, e.sets[j].w.text, e.sets[j].rest.text)))),
                          IconButton(
                              visualDensity: VisualDensity.compact, padding: EdgeInsets.zero,
                              tooltip: 'Descanso',
                              icon: const Icon(Icons.timer),
                              onPressed: () => startRest(int.tryParse(e.sets[j].rest.text) ?? 90)),
                          IconButton(
                              visualDensity: VisualDensity.compact, padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => e.sets.removeAt(j))),
                        ])),
                  TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir serie (sugiere la anterior, editable)'),
                      onPressed: () => setState(() {
                            final l = e.sets.isEmpty ? null : e.sets.last;
                            e.sets.add(l == null ? SetRow() : SetRow(l.reps.text, l.w.text, l.rest.text));
                          })),
                ]))),
      OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Añadir ejercicio'),
          onPressed: () async {
            final e = await pickExercise(context);
            if (e != null) setState(() { items.add(e); started ??= DateTime.now(); });
          }),
      Card(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Text(remaining > 0 ? '$mm:$ss' : 'Descanso', style: const TextStyle(fontSize: 22)),
                const Spacer(),
                SizedBox(width: 80, child: num(defRest, 'Seg', false)),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => startRest(int.tryParse(defRest.text) ?? 90), child: const Text('Iniciar')),
                if (remaining > 0)
                  IconButton(icon: const Icon(Icons.stop), onPressed: () { timer?.cancel(); setState(() => remaining = 0); }),
              ]))),
      const SizedBox(height: 8),
      FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.save),
          label: const Text('Guardar y finalizar entrenamiento'),
          onPressed: save),
    ]);
  }
}

// ---------------- HISTORIAL ----------------
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _detail(BuildContext c, int id) async {
    final rows = await Db.detail(id);
    if (!c.mounted) return;
    final b = StringBuffer();
    String? last;
    for (final r in rows) {
      if (r['name'] != last) { last = r['name'] as String; b.writeln('\n$last'); }
      b.writeln('  ${r['set_number']}) ${r['repetitions']} reps × ${r['weight_kg']} kg · ${r['rest_seconds']} s');
    }
    showDialog(
        context: c,
        builder: (ctx) => AlertDialog(
            title: const Text('Detalle de sesión'),
            content: SingleChildScrollView(child: Text(b.toString().trim())),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))]));
  }

  Future<void> _delete(BuildContext c, int id) async {
    final ok = await showDialog<bool>(
        context: c,
        builder: (ctx) => AlertDialog(
              title: const Text('¿Eliminar sesión?'),
              content: const Text('Se borrarán todas sus series. No se puede deshacer.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
              ],
            ));
    if (ok == true) { await Db.deleteSession(id); dataVersion.value++; }
  }

  @override
  Widget build(BuildContext context) => withUser((c, uid) => FutureBuilder<List<Row>>(
      future: Db.sessions(uid),
      builder: (c, s) {
        if (!s.hasData) return _loader;
        final r = s.data!;
        if (r.isEmpty) return const Center(child: Text('Aún no hay sesiones'));
        return ListView.builder(
            itemCount: r.length,
            itemBuilder: (c, i) => ListTile(
                  title: Text(day(r[i]['date'] as String)),
                  subtitle: Text('${r[i]['nex']} ejercicios · ${r[i]['nsets']} series · '
                      '${(r[i]['vol'] as num).toStringAsFixed(0)} kg de volumen (est.)'),
                  onTap: () => _detail(c, r[i]['id'] as int),
                  trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _delete(c, r[i]['id'] as int)),
                ));
      }));
}

// ---------------- PROGRESO ----------------
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressState();
}

class _ProgressState extends State<ProgressScreen> {
  int? ex;

  Widget chart(String title, String unit, List<double> ys, List<String> labels) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$title ($unit)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (ys.isEmpty)
              const SizedBox(height: 80, child: Center(child: Text('Sin datos para este ejercicio')))
            else
              SizedBox(
                  height: 180,
                  child: LineChart(LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                          spots: [for (var i = 0; i < ys.length; i++) FlSpot(i.toDouble(), ys[i])],
                          barWidth: 3,
                          dotData: const FlDotData(show: true))
                    ],
                    titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: (ys.length / 5).ceil().toDouble(),
                                getTitlesWidget: (v, m) {
                                  final i = v.toInt();
                                  return i >= 0 && i < labels.length
                                      ? Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(labels[i], style: const TextStyle(fontSize: 10)))
                                      : const SizedBox();
                                }))),
                  ))),
          ])));

  @override
  Widget build(BuildContext context) => withUser((c, uid) => FutureBuilder<List<Row>>(
      future: Db.exercises(),
      builder: (c, s) {
        if (!s.hasData) return _loader;
        final exs = s.data!;
        ex ??= exs.first['id'] as int;
        return ListView(padding: const EdgeInsets.all(12), children: [
          DropdownButton<int>(
              isExpanded: true,
              value: ex,
              items: [for (final e in exs) DropdownMenuItem(value: e['id'] as int, child: Text(e['name'] as String))],
              onChanged: (v) => setState(() => ex = v)),
          FutureBuilder<List<Row>>(
              future: Db.progress(uid, ex!),
              builder: (c, p) {
                if (!p.hasData) return _loader;
                final r = p.data!;
                final labels = r.map((x) => day(x['d'] as String).substring(5)).toList();
                List<double> col(String k) => r.map((x) => (x[k] as num).toDouble()).toList();
                return Column(children: [
                  chart('Peso máximo por sesión', 'kg', col('mw'), labels),
                  chart('Repeticiones promedio por serie', 'reps', col('ar'), labels),
                  chart('Volumen por sesión (estimación de carga)', 'kg·rep', col('vol'), labels),
                ]);
              }),
        ]);
      }));
}

// ---------------- AJUSTES ----------------
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _share(String name, String content) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsString(content);
    await Share.shareXFiles([XFile(f.path)]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ajustes')),
        body: ListView(children: [
          ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Exportar CSV'),
              onTap: () async => _share('gymprogress.csv', Db.csv(await Db.exportRows()))),
          ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Copia de seguridad JSON'),
              onTap: () async => _share('gymprogress_backup.json', await Db.backupJson())),
          ListTile(
              leading: const Icon(Icons.science),
              title: const Text('Cargar datos de demostración'),
              subtitle: const Text('Crea el usuario "Demo (datos de ejemplo)"'),
              onTap: () async {
                currentUser.value = await Db.seedDemo();
                dataVersion.value++;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos de demostración cargados')));
                }
              }),
          const ListTile(
              leading: Icon(Icons.lock),
              title: Text('Privacidad'),
              subtitle: Text('Todo se guarda localmente. La app no solicita permisos ni usa Internet.')),
        ]),
      );
}
