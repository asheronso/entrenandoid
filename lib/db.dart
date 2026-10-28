import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

final currentUser = ValueNotifier<int?>(null);
final dataVersion = ValueNotifier<int>(0);

typedef Row = Map<String, Object?>;

const _seed = <(String, String, String)>[
  ('Press de banca', 'pecho', 'fuerza'), ('Press inclinado con mancuernas', 'pecho', 'fuerza'),
  ('Aperturas', 'pecho', 'fuerza'), ('Flexiones', 'pecho', 'peso corporal'),
  ('Dominadas', 'espalda', 'peso corporal'), ('Remo con barra', 'espalda', 'fuerza'),
  ('Jalón al pecho', 'espalda', 'fuerza'), ('Press militar', 'hombros', 'fuerza'),
  ('Elevaciones laterales', 'hombros', 'fuerza'), ('Curl de bíceps', 'bíceps', 'fuerza'),
  ('Curl martillo', 'bíceps', 'fuerza'), ('Extensión de tríceps', 'tríceps', 'fuerza'),
  ('Fondos', 'tríceps', 'peso corporal'), ('Sentadilla', 'piernas', 'fuerza'),
  ('Prensa', 'piernas', 'fuerza'), ('Peso muerto rumano', 'piernas', 'fuerza'),
  ('Hip thrust', 'glúteos', 'fuerza'), ('Plancha', 'abdomen', 'peso corporal'),
  ('Crunch', 'abdomen', 'peso corporal'), ('Cinta de correr', 'cardio', 'cardio'),
];

class Db {
  static Database? _d;
  static Future<Database> get() async => _d ??= await _open();

  static Future<Database> _open() async {
    final p = join(await getDatabasesPath(), 'gymprogress.db');
    return openDatabase(p, version: 1,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, v) async {
          await d.execute('''CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL, created_at TEXT NOT NULL)''');
          await d.execute('''CREATE TABLE exercises(id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE COLLATE NOCASE, muscle_group TEXT NOT NULL DEFAULT 'otro',
            exercise_type TEXT NOT NULL DEFAULT 'fuerza', notes TEXT)''');
          await d.execute('''CREATE TABLE sessions(id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            date TEXT NOT NULL, duration_seconds INTEGER NOT NULL DEFAULT 0, notes TEXT)''');
          await d.execute('''CREATE TABLE workout_exercises(id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
            exercise_id INTEGER NOT NULL REFERENCES exercises(id),
            order_index INTEGER NOT NULL, notes TEXT)''');
          await d.execute('''CREATE TABLE sets(id INTEGER PRIMARY KEY AUTOINCREMENT,
            workout_exercise_id INTEGER NOT NULL REFERENCES workout_exercises(id) ON DELETE CASCADE,
            set_number INTEGER NOT NULL, repetitions INTEGER NOT NULL CHECK(repetitions>=0),
            weight_kg REAL NOT NULL CHECK(weight_kg>=0), rest_seconds INTEGER NOT NULL DEFAULT 0,
            duration_seconds INTEGER, set_type TEXT NOT NULL DEFAULT 'efectiva', notes TEXT)''');
          await d.execute('CREATE INDEX idx_sessions_user_date ON sessions(user_id,date)');
          await d.execute('CREATE INDEX idx_we_session ON workout_exercises(session_id)');
          await d.execute('CREATE INDEX idx_we_exercise ON workout_exercises(exercise_id)');
          await d.execute('CREATE INDEX idx_sets_we ON sets(workout_exercise_id)');
          final b = d.batch();
          for (final e in _seed) {
            b.insert('exercises', {'name': e.$1, 'muscle_group': e.$2, 'exercise_type': e.$3});
          }
          await b.commit(noResult: true);
        });
  }

  static Future<List<Row>> users() async => (await get()).query('users', orderBy: 'name');
  static Future<int> addUser(String name) async => (await get())
      .insert('users', {'name': name, 'created_at': DateTime.now().toIso8601String()});
  static Future<List<Row>> exercises() async =>
      (await get()).query('exercises', orderBy: 'name COLLATE NOCASE');

  static Future<int> addExercise(String name, {String group = 'otro', String type = 'fuerza'}) async {
    final d = await get();
    final ex = await d.query('exercises', where: 'name=?', whereArgs: [name]);
    if (ex.isNotEmpty) return ex.first['id'] as int;
    return d.insert('exercises', {'name': name, 'muscle_group': group, 'exercise_type': type});
  }

  static Future<void> saveSession(int uid, DateTime date, int dur, List<(int, List<SetData>)> items) async {
    final d = await get();
    await d.transaction((t) async {
      final sid = await t.insert('sessions',
          {'user_id': uid, 'date': date.toIso8601String(), 'duration_seconds': dur});
      for (var i = 0; i < items.length; i++) {
        final we = await t.insert('workout_exercises',
            {'session_id': sid, 'exercise_id': items[i].$1, 'order_index': i});
        final sets = items[i].$2;
        for (var j = 0; j < sets.length; j++) {
          await t.insert('sets', {
            'workout_exercise_id': we, 'set_number': j + 1, 'repetitions': sets[j].reps,
            'weight_kg': sets[j].weight, 'rest_seconds': sets[j].rest, 'set_type': sets[j].type,
          });
        }
      }
    });
  }

  static Future<void> deleteSession(int id) async =>
      (await get()).delete('sessions', where: 'id=?', whereArgs: [id]);

  static Future<List<Row>> sessions(int uid) async => (await get()).rawQuery('''
    SELECT s.id, s.date, s.duration_seconds dur, COUNT(DISTINCT we.id) nex, COUNT(st.id) nsets,
      COALESCE(SUM(st.repetitions*st.weight_kg),0) vol
    FROM sessions s LEFT JOIN workout_exercises we ON we.session_id=s.id
    LEFT JOIN sets st ON st.workout_exercise_id=we.id
    WHERE s.user_id=? GROUP BY s.id ORDER BY s.date DESC''', [uid]);

  static Future<List<Row>> detail(int sid) async => (await get()).rawQuery('''
    SELECT e.name, st.set_number, st.repetitions, st.weight_kg, st.rest_seconds
    FROM workout_exercises we JOIN exercises e ON e.id=we.exercise_id
    JOIN sets st ON st.workout_exercise_id=we.id WHERE we.session_id=?
    ORDER BY we.order_index, st.set_number''', [sid]);

  static Future<List<Row>> progress(int uid, int exId) async => (await get()).rawQuery('''
    SELECT s.date d, MAX(st.weight_kg) mw, AVG(st.repetitions) ar,
      SUM(st.repetitions*st.weight_kg) vol
    FROM sessions s JOIN workout_exercises we ON we.session_id=s.id
    JOIN sets st ON st.workout_exercise_id=we.id
    WHERE s.user_id=? AND we.exercise_id=? GROUP BY s.id ORDER BY s.date''', [uid, exId]);

  static Future<Row> stats(int uid) async {
    final d = await get();
    final r = (await d.rawQuery('''
      SELECT COUNT(DISTINCT s.id) ses, COUNT(DISTINCT we.id) nex, COUNT(st.id) nsets,
        COALESCE(SUM(st.repetitions),0) reps, COALESCE(SUM(st.repetitions*st.weight_kg),0) vol
      FROM sessions s LEFT JOIN workout_exercises we ON we.session_id=s.id
      LEFT JOIN sets st ON st.workout_exercise_id=we.id WHERE s.user_id=?''', [uid])).first;
    final t = await d.rawQuery(
        'SELECT COALESCE(SUM(duration_seconds),0) t FROM sessions WHERE user_id=?', [uid]);
    return {...r, 'secs': t.first['t']};
  }

  static Future<List<Row>> exportRows() async => (await get()).rawQuery('''
    SELECT u.name usuario, s.date fecha, e.name ejercicio, st.set_number serie,
      st.repetitions repeticiones, st.weight_kg peso_kg, st.rest_seconds descanso_s,
      COALESCE(st.duration_seconds,'') duracion_s, COALESCE(st.notes,'') observaciones
    FROM sets st JOIN workout_exercises we ON we.id=st.workout_exercise_id
    JOIN sessions s ON s.id=we.session_id JOIN users u ON u.id=s.user_id
    JOIN exercises e ON e.id=we.exercise_id ORDER BY s.date, we.order_index, st.set_number''');

  static String csv(List<Row> rows) {
    if (rows.isEmpty) return 'sin datos';
    final k = rows.first.keys.toList();
    String q(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    return [k.join(','), ...rows.map((r) => k.map((c) => q(r[c])).join(','))].join('\n');
  }

  static Future<String> backupJson() async {
    final d = await get();
    final out = <String, Object?>{'app': 'GymProgress', 'version': 1};
    for (final t in ['users', 'exercises', 'sessions', 'workout_exercises', 'sets']) {
      out[t] = await d.query(t);
    }
    return const JsonEncoder.withIndent('  ').convert(out);
  }

  /// DATOS DE DEMOSTRACIÓN (usuario claramente identificado).
  static Future<int> seedDemo() async {
    final d = await get();
    final uid = await d.insert('users',
        {'name': 'Demo (datos de ejemplo)', 'created_at': DateTime.now().toIso8601String()});
    final eid = await addExercise('Press de banca');
    for (var i = 0; i < 6; i++) {
      final date = DateTime.now().subtract(Duration(days: 7 * (5 - i)));
      await saveSession(uid, date, 3000, [
        (eid, [
          SetData(12, 20 + i * 2.5, 60, 'calentamiento'), SetData(10, 30 + i * 2.5, 90),
          SetData(8, 40 + i * 2.5, 90), SetData(6, 45 + i * 2.5, 120, 'fallo'),
        ])
      ]);
    }
    return uid;
  }
}
