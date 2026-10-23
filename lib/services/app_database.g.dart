// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WorkoutsIndexTable extends WorkoutsIndex
    with TableInfo<$WorkoutsIndexTable, WorkoutIndexRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutsIndexTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _splitMeta = const VerificationMeta('split');
  @override
  late final GeneratedColumn<String> split = GeneratedColumn<String>(
      'split', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _timeStartedMeta =
      const VerificationMeta('timeStarted');
  @override
  late final GeneratedColumn<String> timeStarted = GeneratedColumn<String>(
      'time_started', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationMinMeta =
      const VerificationMeta('durationMin');
  @override
  late final GeneratedColumn<double> durationMin = GeneratedColumn<double>(
      'duration_min', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _totalVolumeKgMeta =
      const VerificationMeta('totalVolumeKg');
  @override
  late final GeneratedColumn<double> totalVolumeKg = GeneratedColumn<double>(
      'total_volume_kg', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _tssScoreMeta =
      const VerificationMeta('tssScore');
  @override
  late final GeneratedColumn<int> tssScore = GeneratedColumn<int>(
      'tss_score', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _readinessScoreMeta =
      const VerificationMeta('readinessScore');
  @override
  late final GeneratedColumn<int> readinessScore = GeneratedColumn<int>(
      'readiness_score', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _startTimeMeta =
      const VerificationMeta('startTime');
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
      'start_time', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _dateLoggedMeta =
      const VerificationMeta('dateLogged');
  @override
  late final GeneratedColumn<DateTime> dateLogged = GeneratedColumn<DateTime>(
      'date_logged', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        filePath,
        split,
        date,
        timeStarted,
        durationMin,
        totalVolumeKg,
        tssScore,
        readinessScore,
        startTime,
        dateLogged,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workouts_index';
  @override
  VerificationContext validateIntegrity(Insertable<WorkoutIndexRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('split')) {
      context.handle(
          _splitMeta, split.isAcceptableOrUnknown(data['split']!, _splitMeta));
    } else if (isInserting) {
      context.missing(_splitMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('time_started')) {
      context.handle(
          _timeStartedMeta,
          timeStarted.isAcceptableOrUnknown(
              data['time_started']!, _timeStartedMeta));
    } else if (isInserting) {
      context.missing(_timeStartedMeta);
    }
    if (data.containsKey('duration_min')) {
      context.handle(
          _durationMinMeta,
          durationMin.isAcceptableOrUnknown(
              data['duration_min']!, _durationMinMeta));
    } else if (isInserting) {
      context.missing(_durationMinMeta);
    }
    if (data.containsKey('total_volume_kg')) {
      context.handle(
          _totalVolumeKgMeta,
          totalVolumeKg.isAcceptableOrUnknown(
              data['total_volume_kg']!, _totalVolumeKgMeta));
    }
    if (data.containsKey('tss_score')) {
      context.handle(_tssScoreMeta,
          tssScore.isAcceptableOrUnknown(data['tss_score']!, _tssScoreMeta));
    }
    if (data.containsKey('readiness_score')) {
      context.handle(
          _readinessScoreMeta,
          readinessScore.isAcceptableOrUnknown(
              data['readiness_score']!, _readinessScoreMeta));
    }
    if (data.containsKey('start_time')) {
      context.handle(_startTimeMeta,
          startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta));
    }
    if (data.containsKey('date_logged')) {
      context.handle(
          _dateLoggedMeta,
          dateLogged.isAcceptableOrUnknown(
              data['date_logged']!, _dateLoggedMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutIndexRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutIndexRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      split: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}split'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      timeStarted: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}time_started'])!,
      durationMin: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}duration_min'])!,
      totalVolumeKg: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total_volume_kg']),
      tssScore: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tss_score']),
      readinessScore: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}readiness_score']),
      startTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_time']),
      dateLogged: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date_logged']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $WorkoutsIndexTable createAlias(String alias) {
    return $WorkoutsIndexTable(attachedDatabase, alias);
  }
}

class WorkoutIndexRow extends DataClass implements Insertable<WorkoutIndexRow> {
  final int id;
  final String filePath;
  final String split;
  final DateTime date;
  final String timeStarted;
  final double durationMin;
  final double? totalVolumeKg;
  final int? tssScore;
  final int? readinessScore;

  /// `start_time` / `date_logged` frontmatter (UTC instants). Null on legacy
  /// notes written before Phase 5.
  final DateTime? startTime;
  final DateTime? dateLogged;
  final DateTime updatedAt;
  const WorkoutIndexRow(
      {required this.id,
      required this.filePath,
      required this.split,
      required this.date,
      required this.timeStarted,
      required this.durationMin,
      this.totalVolumeKg,
      this.tssScore,
      this.readinessScore,
      this.startTime,
      this.dateLogged,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_path'] = Variable<String>(filePath);
    map['split'] = Variable<String>(split);
    map['date'] = Variable<DateTime>(date);
    map['time_started'] = Variable<String>(timeStarted);
    map['duration_min'] = Variable<double>(durationMin);
    if (!nullToAbsent || totalVolumeKg != null) {
      map['total_volume_kg'] = Variable<double>(totalVolumeKg);
    }
    if (!nullToAbsent || tssScore != null) {
      map['tss_score'] = Variable<int>(tssScore);
    }
    if (!nullToAbsent || readinessScore != null) {
      map['readiness_score'] = Variable<int>(readinessScore);
    }
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<DateTime>(startTime);
    }
    if (!nullToAbsent || dateLogged != null) {
      map['date_logged'] = Variable<DateTime>(dateLogged);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WorkoutsIndexCompanion toCompanion(bool nullToAbsent) {
    return WorkoutsIndexCompanion(
      id: Value(id),
      filePath: Value(filePath),
      split: Value(split),
      date: Value(date),
      timeStarted: Value(timeStarted),
      durationMin: Value(durationMin),
      totalVolumeKg: totalVolumeKg == null && nullToAbsent
          ? const Value.absent()
          : Value(totalVolumeKg),
      tssScore: tssScore == null && nullToAbsent
          ? const Value.absent()
          : Value(tssScore),
      readinessScore: readinessScore == null && nullToAbsent
          ? const Value.absent()
          : Value(readinessScore),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      dateLogged: dateLogged == null && nullToAbsent
          ? const Value.absent()
          : Value(dateLogged),
      updatedAt: Value(updatedAt),
    );
  }

  factory WorkoutIndexRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutIndexRow(
      id: serializer.fromJson<int>(json['id']),
      filePath: serializer.fromJson<String>(json['filePath']),
      split: serializer.fromJson<String>(json['split']),
      date: serializer.fromJson<DateTime>(json['date']),
      timeStarted: serializer.fromJson<String>(json['timeStarted']),
      durationMin: serializer.fromJson<double>(json['durationMin']),
      totalVolumeKg: serializer.fromJson<double?>(json['totalVolumeKg']),
      tssScore: serializer.fromJson<int?>(json['tssScore']),
      readinessScore: serializer.fromJson<int?>(json['readinessScore']),
      startTime: serializer.fromJson<DateTime?>(json['startTime']),
      dateLogged: serializer.fromJson<DateTime?>(json['dateLogged']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'filePath': serializer.toJson<String>(filePath),
      'split': serializer.toJson<String>(split),
      'date': serializer.toJson<DateTime>(date),
      'timeStarted': serializer.toJson<String>(timeStarted),
      'durationMin': serializer.toJson<double>(durationMin),
      'totalVolumeKg': serializer.toJson<double?>(totalVolumeKg),
      'tssScore': serializer.toJson<int?>(tssScore),
      'readinessScore': serializer.toJson<int?>(readinessScore),
      'startTime': serializer.toJson<DateTime?>(startTime),
      'dateLogged': serializer.toJson<DateTime?>(dateLogged),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WorkoutIndexRow copyWith(
          {int? id,
          String? filePath,
          String? split,
          DateTime? date,
          String? timeStarted,
          double? durationMin,
          Value<double?> totalVolumeKg = const Value.absent(),
          Value<int?> tssScore = const Value.absent(),
          Value<int?> readinessScore = const Value.absent(),
          Value<DateTime?> startTime = const Value.absent(),
          Value<DateTime?> dateLogged = const Value.absent(),
          DateTime? updatedAt}) =>
      WorkoutIndexRow(
        id: id ?? this.id,
        filePath: filePath ?? this.filePath,
        split: split ?? this.split,
        date: date ?? this.date,
        timeStarted: timeStarted ?? this.timeStarted,
        durationMin: durationMin ?? this.durationMin,
        totalVolumeKg:
            totalVolumeKg.present ? totalVolumeKg.value : this.totalVolumeKg,
        tssScore: tssScore.present ? tssScore.value : this.tssScore,
        readinessScore:
            readinessScore.present ? readinessScore.value : this.readinessScore,
        startTime: startTime.present ? startTime.value : this.startTime,
        dateLogged: dateLogged.present ? dateLogged.value : this.dateLogged,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  WorkoutIndexRow copyWithCompanion(WorkoutsIndexCompanion data) {
    return WorkoutIndexRow(
      id: data.id.present ? data.id.value : this.id,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      split: data.split.present ? data.split.value : this.split,
      date: data.date.present ? data.date.value : this.date,
      timeStarted:
          data.timeStarted.present ? data.timeStarted.value : this.timeStarted,
      durationMin:
          data.durationMin.present ? data.durationMin.value : this.durationMin,
      totalVolumeKg: data.totalVolumeKg.present
          ? data.totalVolumeKg.value
          : this.totalVolumeKg,
      tssScore: data.tssScore.present ? data.tssScore.value : this.tssScore,
      readinessScore: data.readinessScore.present
          ? data.readinessScore.value
          : this.readinessScore,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      dateLogged:
          data.dateLogged.present ? data.dateLogged.value : this.dateLogged,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutIndexRow(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('split: $split, ')
          ..write('date: $date, ')
          ..write('timeStarted: $timeStarted, ')
          ..write('durationMin: $durationMin, ')
          ..write('totalVolumeKg: $totalVolumeKg, ')
          ..write('tssScore: $tssScore, ')
          ..write('readinessScore: $readinessScore, ')
          ..write('startTime: $startTime, ')
          ..write('dateLogged: $dateLogged, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      filePath,
      split,
      date,
      timeStarted,
      durationMin,
      totalVolumeKg,
      tssScore,
      readinessScore,
      startTime,
      dateLogged,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutIndexRow &&
          other.id == this.id &&
          other.filePath == this.filePath &&
          other.split == this.split &&
          other.date == this.date &&
          other.timeStarted == this.timeStarted &&
          other.durationMin == this.durationMin &&
          other.totalVolumeKg == this.totalVolumeKg &&
          other.tssScore == this.tssScore &&
          other.readinessScore == this.readinessScore &&
          other.startTime == this.startTime &&
          other.dateLogged == this.dateLogged &&
          other.updatedAt == this.updatedAt);
}

class WorkoutsIndexCompanion extends UpdateCompanion<WorkoutIndexRow> {
  final Value<int> id;
  final Value<String> filePath;
  final Value<String> split;
  final Value<DateTime> date;
  final Value<String> timeStarted;
  final Value<double> durationMin;
  final Value<double?> totalVolumeKg;
  final Value<int?> tssScore;
  final Value<int?> readinessScore;
  final Value<DateTime?> startTime;
  final Value<DateTime?> dateLogged;
  final Value<DateTime> updatedAt;
  const WorkoutsIndexCompanion({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.split = const Value.absent(),
    this.date = const Value.absent(),
    this.timeStarted = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.totalVolumeKg = const Value.absent(),
    this.tssScore = const Value.absent(),
    this.readinessScore = const Value.absent(),
    this.startTime = const Value.absent(),
    this.dateLogged = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  WorkoutsIndexCompanion.insert({
    this.id = const Value.absent(),
    required String filePath,
    required String split,
    required DateTime date,
    required String timeStarted,
    required double durationMin,
    this.totalVolumeKg = const Value.absent(),
    this.tssScore = const Value.absent(),
    this.readinessScore = const Value.absent(),
    this.startTime = const Value.absent(),
    this.dateLogged = const Value.absent(),
    required DateTime updatedAt,
  })  : filePath = Value(filePath),
        split = Value(split),
        date = Value(date),
        timeStarted = Value(timeStarted),
        durationMin = Value(durationMin),
        updatedAt = Value(updatedAt);
  static Insertable<WorkoutIndexRow> custom({
    Expression<int>? id,
    Expression<String>? filePath,
    Expression<String>? split,
    Expression<DateTime>? date,
    Expression<String>? timeStarted,
    Expression<double>? durationMin,
    Expression<double>? totalVolumeKg,
    Expression<int>? tssScore,
    Expression<int>? readinessScore,
    Expression<DateTime>? startTime,
    Expression<DateTime>? dateLogged,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filePath != null) 'file_path': filePath,
      if (split != null) 'split': split,
      if (date != null) 'date': date,
      if (timeStarted != null) 'time_started': timeStarted,
      if (durationMin != null) 'duration_min': durationMin,
      if (totalVolumeKg != null) 'total_volume_kg': totalVolumeKg,
      if (tssScore != null) 'tss_score': tssScore,
      if (readinessScore != null) 'readiness_score': readinessScore,
      if (startTime != null) 'start_time': startTime,
      if (dateLogged != null) 'date_logged': dateLogged,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  WorkoutsIndexCompanion copyWith(
      {Value<int>? id,
      Value<String>? filePath,
      Value<String>? split,
      Value<DateTime>? date,
      Value<String>? timeStarted,
      Value<double>? durationMin,
      Value<double?>? totalVolumeKg,
      Value<int?>? tssScore,
      Value<int?>? readinessScore,
      Value<DateTime?>? startTime,
      Value<DateTime?>? dateLogged,
      Value<DateTime>? updatedAt}) {
    return WorkoutsIndexCompanion(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      split: split ?? this.split,
      date: date ?? this.date,
      timeStarted: timeStarted ?? this.timeStarted,
      durationMin: durationMin ?? this.durationMin,
      totalVolumeKg: totalVolumeKg ?? this.totalVolumeKg,
      tssScore: tssScore ?? this.tssScore,
      readinessScore: readinessScore ?? this.readinessScore,
      startTime: startTime ?? this.startTime,
      dateLogged: dateLogged ?? this.dateLogged,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (split.present) {
      map['split'] = Variable<String>(split.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (timeStarted.present) {
      map['time_started'] = Variable<String>(timeStarted.value);
    }
    if (durationMin.present) {
      map['duration_min'] = Variable<double>(durationMin.value);
    }
    if (totalVolumeKg.present) {
      map['total_volume_kg'] = Variable<double>(totalVolumeKg.value);
    }
    if (tssScore.present) {
      map['tss_score'] = Variable<int>(tssScore.value);
    }
    if (readinessScore.present) {
      map['readiness_score'] = Variable<int>(readinessScore.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (dateLogged.present) {
      map['date_logged'] = Variable<DateTime>(dateLogged.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutsIndexCompanion(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('split: $split, ')
          ..write('date: $date, ')
          ..write('timeStarted: $timeStarted, ')
          ..write('durationMin: $durationMin, ')
          ..write('totalVolumeKg: $totalVolumeKg, ')
          ..write('tssScore: $tssScore, ')
          ..write('readinessScore: $readinessScore, ')
          ..write('startTime: $startTime, ')
          ..write('dateLogged: $dateLogged, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ActivitiesIndexTable extends ActivitiesIndex
    with TableInfo<$ActivitiesIndexTable, ActivityIndexRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivitiesIndexTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _timeStartedMeta =
      const VerificationMeta('timeStarted');
  @override
  late final GeneratedColumn<String> timeStarted = GeneratedColumn<String>(
      'time_started', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationMinMeta =
      const VerificationMeta('durationMin');
  @override
  late final GeneratedColumn<double> durationMin = GeneratedColumn<double>(
      'duration_min', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _distanceKmMeta =
      const VerificationMeta('distanceKm');
  @override
  late final GeneratedColumn<double> distanceKm = GeneratedColumn<double>(
      'distance_km', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _elevationGainMMeta =
      const VerificationMeta('elevationGainM');
  @override
  late final GeneratedColumn<double> elevationGainM = GeneratedColumn<double>(
      'elevation_gain_m', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _avgHrMeta = const VerificationMeta('avgHr');
  @override
  late final GeneratedColumn<int> avgHr = GeneratedColumn<int>(
      'avg_hr', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _tssScoreMeta =
      const VerificationMeta('tssScore');
  @override
  late final GeneratedColumn<int> tssScore = GeneratedColumn<int>(
      'tss_score', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _gpxFileNameMeta =
      const VerificationMeta('gpxFileName');
  @override
  late final GeneratedColumn<String> gpxFileName = GeneratedColumn<String>(
      'gpx_file_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startTimeMeta =
      const VerificationMeta('startTime');
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
      'start_time', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _dateLoggedMeta =
      const VerificationMeta('dateLogged');
  @override
  late final GeneratedColumn<DateTime> dateLogged = GeneratedColumn<DateTime>(
      'date_logged', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _rpeMeta = const VerificationMeta('rpe');
  @override
  late final GeneratedColumn<double> rpe = GeneratedColumn<double>(
      'rpe', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        filePath,
        category,
        date,
        timeStarted,
        durationMin,
        distanceKm,
        elevationGainM,
        avgHr,
        tssScore,
        gpxFileName,
        startTime,
        dateLogged,
        durationSeconds,
        rpe,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activities_index';
  @override
  VerificationContext validateIntegrity(Insertable<ActivityIndexRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('time_started')) {
      context.handle(
          _timeStartedMeta,
          timeStarted.isAcceptableOrUnknown(
              data['time_started']!, _timeStartedMeta));
    } else if (isInserting) {
      context.missing(_timeStartedMeta);
    }
    if (data.containsKey('duration_min')) {
      context.handle(
          _durationMinMeta,
          durationMin.isAcceptableOrUnknown(
              data['duration_min']!, _durationMinMeta));
    } else if (isInserting) {
      context.missing(_durationMinMeta);
    }
    if (data.containsKey('distance_km')) {
      context.handle(
          _distanceKmMeta,
          distanceKm.isAcceptableOrUnknown(
              data['distance_km']!, _distanceKmMeta));
    }
    if (data.containsKey('elevation_gain_m')) {
      context.handle(
          _elevationGainMMeta,
          elevationGainM.isAcceptableOrUnknown(
              data['elevation_gain_m']!, _elevationGainMMeta));
    }
    if (data.containsKey('avg_hr')) {
      context.handle(
          _avgHrMeta, avgHr.isAcceptableOrUnknown(data['avg_hr']!, _avgHrMeta));
    }
    if (data.containsKey('tss_score')) {
      context.handle(_tssScoreMeta,
          tssScore.isAcceptableOrUnknown(data['tss_score']!, _tssScoreMeta));
    }
    if (data.containsKey('gpx_file_name')) {
      context.handle(
          _gpxFileNameMeta,
          gpxFileName.isAcceptableOrUnknown(
              data['gpx_file_name']!, _gpxFileNameMeta));
    }
    if (data.containsKey('start_time')) {
      context.handle(_startTimeMeta,
          startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta));
    }
    if (data.containsKey('date_logged')) {
      context.handle(
          _dateLoggedMeta,
          dateLogged.isAcceptableOrUnknown(
              data['date_logged']!, _dateLoggedMeta));
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    }
    if (data.containsKey('rpe')) {
      context.handle(
          _rpeMeta, rpe.isAcceptableOrUnknown(data['rpe']!, _rpeMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityIndexRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityIndexRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      timeStarted: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}time_started'])!,
      durationMin: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}duration_min'])!,
      distanceKm: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}distance_km']),
      elevationGainM: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}elevation_gain_m']),
      avgHr: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}avg_hr']),
      tssScore: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tss_score']),
      gpxFileName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gpx_file_name']),
      startTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_time']),
      dateLogged: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date_logged']),
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds']),
      rpe: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}rpe']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ActivitiesIndexTable createAlias(String alias) {
    return $ActivitiesIndexTable(attachedDatabase, alias);
  }
}

class ActivityIndexRow extends DataClass
    implements Insertable<ActivityIndexRow> {
  final int id;
  final String filePath;
  final String category;
  final DateTime date;
  final String timeStarted;
  final double durationMin;
  final double? distanceKm;
  final double? elevationGainM;
  final int? avgHr;
  final int? tssScore;
  final String? gpxFileName;

  /// Phase 5 metadata. `startTime` / `dateLogged` are UTC instants (null on
  /// legacy notes); `durationSeconds` and `rpe` are written by the manual
  /// outdoor logger.
  final DateTime? startTime;
  final DateTime? dateLogged;
  final int? durationSeconds;
  final double? rpe;
  final DateTime updatedAt;
  const ActivityIndexRow(
      {required this.id,
      required this.filePath,
      required this.category,
      required this.date,
      required this.timeStarted,
      required this.durationMin,
      this.distanceKm,
      this.elevationGainM,
      this.avgHr,
      this.tssScore,
      this.gpxFileName,
      this.startTime,
      this.dateLogged,
      this.durationSeconds,
      this.rpe,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_path'] = Variable<String>(filePath);
    map['category'] = Variable<String>(category);
    map['date'] = Variable<DateTime>(date);
    map['time_started'] = Variable<String>(timeStarted);
    map['duration_min'] = Variable<double>(durationMin);
    if (!nullToAbsent || distanceKm != null) {
      map['distance_km'] = Variable<double>(distanceKm);
    }
    if (!nullToAbsent || elevationGainM != null) {
      map['elevation_gain_m'] = Variable<double>(elevationGainM);
    }
    if (!nullToAbsent || avgHr != null) {
      map['avg_hr'] = Variable<int>(avgHr);
    }
    if (!nullToAbsent || tssScore != null) {
      map['tss_score'] = Variable<int>(tssScore);
    }
    if (!nullToAbsent || gpxFileName != null) {
      map['gpx_file_name'] = Variable<String>(gpxFileName);
    }
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<DateTime>(startTime);
    }
    if (!nullToAbsent || dateLogged != null) {
      map['date_logged'] = Variable<DateTime>(dateLogged);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || rpe != null) {
      map['rpe'] = Variable<double>(rpe);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ActivitiesIndexCompanion toCompanion(bool nullToAbsent) {
    return ActivitiesIndexCompanion(
      id: Value(id),
      filePath: Value(filePath),
      category: Value(category),
      date: Value(date),
      timeStarted: Value(timeStarted),
      durationMin: Value(durationMin),
      distanceKm: distanceKm == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceKm),
      elevationGainM: elevationGainM == null && nullToAbsent
          ? const Value.absent()
          : Value(elevationGainM),
      avgHr:
          avgHr == null && nullToAbsent ? const Value.absent() : Value(avgHr),
      tssScore: tssScore == null && nullToAbsent
          ? const Value.absent()
          : Value(tssScore),
      gpxFileName: gpxFileName == null && nullToAbsent
          ? const Value.absent()
          : Value(gpxFileName),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      dateLogged: dateLogged == null && nullToAbsent
          ? const Value.absent()
          : Value(dateLogged),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      rpe: rpe == null && nullToAbsent ? const Value.absent() : Value(rpe),
      updatedAt: Value(updatedAt),
    );
  }

  factory ActivityIndexRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityIndexRow(
      id: serializer.fromJson<int>(json['id']),
      filePath: serializer.fromJson<String>(json['filePath']),
      category: serializer.fromJson<String>(json['category']),
      date: serializer.fromJson<DateTime>(json['date']),
      timeStarted: serializer.fromJson<String>(json['timeStarted']),
      durationMin: serializer.fromJson<double>(json['durationMin']),
      distanceKm: serializer.fromJson<double?>(json['distanceKm']),
      elevationGainM: serializer.fromJson<double?>(json['elevationGainM']),
      avgHr: serializer.fromJson<int?>(json['avgHr']),
      tssScore: serializer.fromJson<int?>(json['tssScore']),
      gpxFileName: serializer.fromJson<String?>(json['gpxFileName']),
      startTime: serializer.fromJson<DateTime?>(json['startTime']),
      dateLogged: serializer.fromJson<DateTime?>(json['dateLogged']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      rpe: serializer.fromJson<double?>(json['rpe']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'filePath': serializer.toJson<String>(filePath),
      'category': serializer.toJson<String>(category),
      'date': serializer.toJson<DateTime>(date),
      'timeStarted': serializer.toJson<String>(timeStarted),
      'durationMin': serializer.toJson<double>(durationMin),
      'distanceKm': serializer.toJson<double?>(distanceKm),
      'elevationGainM': serializer.toJson<double?>(elevationGainM),
      'avgHr': serializer.toJson<int?>(avgHr),
      'tssScore': serializer.toJson<int?>(tssScore),
      'gpxFileName': serializer.toJson<String?>(gpxFileName),
      'startTime': serializer.toJson<DateTime?>(startTime),
      'dateLogged': serializer.toJson<DateTime?>(dateLogged),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'rpe': serializer.toJson<double?>(rpe),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ActivityIndexRow copyWith(
          {int? id,
          String? filePath,
          String? category,
          DateTime? date,
          String? timeStarted,
          double? durationMin,
          Value<double?> distanceKm = const Value.absent(),
          Value<double?> elevationGainM = const Value.absent(),
          Value<int?> avgHr = const Value.absent(),
          Value<int?> tssScore = const Value.absent(),
          Value<String?> gpxFileName = const Value.absent(),
          Value<DateTime?> startTime = const Value.absent(),
          Value<DateTime?> dateLogged = const Value.absent(),
          Value<int?> durationSeconds = const Value.absent(),
          Value<double?> rpe = const Value.absent(),
          DateTime? updatedAt}) =>
      ActivityIndexRow(
        id: id ?? this.id,
        filePath: filePath ?? this.filePath,
        category: category ?? this.category,
        date: date ?? this.date,
        timeStarted: timeStarted ?? this.timeStarted,
        durationMin: durationMin ?? this.durationMin,
        distanceKm: distanceKm.present ? distanceKm.value : this.distanceKm,
        elevationGainM:
            elevationGainM.present ? elevationGainM.value : this.elevationGainM,
        avgHr: avgHr.present ? avgHr.value : this.avgHr,
        tssScore: tssScore.present ? tssScore.value : this.tssScore,
        gpxFileName: gpxFileName.present ? gpxFileName.value : this.gpxFileName,
        startTime: startTime.present ? startTime.value : this.startTime,
        dateLogged: dateLogged.present ? dateLogged.value : this.dateLogged,
        durationSeconds: durationSeconds.present
            ? durationSeconds.value
            : this.durationSeconds,
        rpe: rpe.present ? rpe.value : this.rpe,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ActivityIndexRow copyWithCompanion(ActivitiesIndexCompanion data) {
    return ActivityIndexRow(
      id: data.id.present ? data.id.value : this.id,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      category: data.category.present ? data.category.value : this.category,
      date: data.date.present ? data.date.value : this.date,
      timeStarted:
          data.timeStarted.present ? data.timeStarted.value : this.timeStarted,
      durationMin:
          data.durationMin.present ? data.durationMin.value : this.durationMin,
      distanceKm:
          data.distanceKm.present ? data.distanceKm.value : this.distanceKm,
      elevationGainM: data.elevationGainM.present
          ? data.elevationGainM.value
          : this.elevationGainM,
      avgHr: data.avgHr.present ? data.avgHr.value : this.avgHr,
      tssScore: data.tssScore.present ? data.tssScore.value : this.tssScore,
      gpxFileName:
          data.gpxFileName.present ? data.gpxFileName.value : this.gpxFileName,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      dateLogged:
          data.dateLogged.present ? data.dateLogged.value : this.dateLogged,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      rpe: data.rpe.present ? data.rpe.value : this.rpe,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityIndexRow(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('category: $category, ')
          ..write('date: $date, ')
          ..write('timeStarted: $timeStarted, ')
          ..write('durationMin: $durationMin, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('elevationGainM: $elevationGainM, ')
          ..write('avgHr: $avgHr, ')
          ..write('tssScore: $tssScore, ')
          ..write('gpxFileName: $gpxFileName, ')
          ..write('startTime: $startTime, ')
          ..write('dateLogged: $dateLogged, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('rpe: $rpe, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      filePath,
      category,
      date,
      timeStarted,
      durationMin,
      distanceKm,
      elevationGainM,
      avgHr,
      tssScore,
      gpxFileName,
      startTime,
      dateLogged,
      durationSeconds,
      rpe,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityIndexRow &&
          other.id == this.id &&
          other.filePath == this.filePath &&
          other.category == this.category &&
          other.date == this.date &&
          other.timeStarted == this.timeStarted &&
          other.durationMin == this.durationMin &&
          other.distanceKm == this.distanceKm &&
          other.elevationGainM == this.elevationGainM &&
          other.avgHr == this.avgHr &&
          other.tssScore == this.tssScore &&
          other.gpxFileName == this.gpxFileName &&
          other.startTime == this.startTime &&
          other.dateLogged == this.dateLogged &&
          other.durationSeconds == this.durationSeconds &&
          other.rpe == this.rpe &&
          other.updatedAt == this.updatedAt);
}

class ActivitiesIndexCompanion extends UpdateCompanion<ActivityIndexRow> {
  final Value<int> id;
  final Value<String> filePath;
  final Value<String> category;
  final Value<DateTime> date;
  final Value<String> timeStarted;
  final Value<double> durationMin;
  final Value<double?> distanceKm;
  final Value<double?> elevationGainM;
  final Value<int?> avgHr;
  final Value<int?> tssScore;
  final Value<String?> gpxFileName;
  final Value<DateTime?> startTime;
  final Value<DateTime?> dateLogged;
  final Value<int?> durationSeconds;
  final Value<double?> rpe;
  final Value<DateTime> updatedAt;
  const ActivitiesIndexCompanion({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.category = const Value.absent(),
    this.date = const Value.absent(),
    this.timeStarted = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.distanceKm = const Value.absent(),
    this.elevationGainM = const Value.absent(),
    this.avgHr = const Value.absent(),
    this.tssScore = const Value.absent(),
    this.gpxFileName = const Value.absent(),
    this.startTime = const Value.absent(),
    this.dateLogged = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.rpe = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ActivitiesIndexCompanion.insert({
    this.id = const Value.absent(),
    required String filePath,
    required String category,
    required DateTime date,
    required String timeStarted,
    required double durationMin,
    this.distanceKm = const Value.absent(),
    this.elevationGainM = const Value.absent(),
    this.avgHr = const Value.absent(),
    this.tssScore = const Value.absent(),
    this.gpxFileName = const Value.absent(),
    this.startTime = const Value.absent(),
    this.dateLogged = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.rpe = const Value.absent(),
    required DateTime updatedAt,
  })  : filePath = Value(filePath),
        category = Value(category),
        date = Value(date),
        timeStarted = Value(timeStarted),
        durationMin = Value(durationMin),
        updatedAt = Value(updatedAt);
  static Insertable<ActivityIndexRow> custom({
    Expression<int>? id,
    Expression<String>? filePath,
    Expression<String>? category,
    Expression<DateTime>? date,
    Expression<String>? timeStarted,
    Expression<double>? durationMin,
    Expression<double>? distanceKm,
    Expression<double>? elevationGainM,
    Expression<int>? avgHr,
    Expression<int>? tssScore,
    Expression<String>? gpxFileName,
    Expression<DateTime>? startTime,
    Expression<DateTime>? dateLogged,
    Expression<int>? durationSeconds,
    Expression<double>? rpe,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filePath != null) 'file_path': filePath,
      if (category != null) 'category': category,
      if (date != null) 'date': date,
      if (timeStarted != null) 'time_started': timeStarted,
      if (durationMin != null) 'duration_min': durationMin,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (elevationGainM != null) 'elevation_gain_m': elevationGainM,
      if (avgHr != null) 'avg_hr': avgHr,
      if (tssScore != null) 'tss_score': tssScore,
      if (gpxFileName != null) 'gpx_file_name': gpxFileName,
      if (startTime != null) 'start_time': startTime,
      if (dateLogged != null) 'date_logged': dateLogged,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (rpe != null) 'rpe': rpe,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ActivitiesIndexCompanion copyWith(
      {Value<int>? id,
      Value<String>? filePath,
      Value<String>? category,
      Value<DateTime>? date,
      Value<String>? timeStarted,
      Value<double>? durationMin,
      Value<double?>? distanceKm,
      Value<double?>? elevationGainM,
      Value<int?>? avgHr,
      Value<int?>? tssScore,
      Value<String?>? gpxFileName,
      Value<DateTime?>? startTime,
      Value<DateTime?>? dateLogged,
      Value<int?>? durationSeconds,
      Value<double?>? rpe,
      Value<DateTime>? updatedAt}) {
    return ActivitiesIndexCompanion(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      category: category ?? this.category,
      date: date ?? this.date,
      timeStarted: timeStarted ?? this.timeStarted,
      durationMin: durationMin ?? this.durationMin,
      distanceKm: distanceKm ?? this.distanceKm,
      elevationGainM: elevationGainM ?? this.elevationGainM,
      avgHr: avgHr ?? this.avgHr,
      tssScore: tssScore ?? this.tssScore,
      gpxFileName: gpxFileName ?? this.gpxFileName,
      startTime: startTime ?? this.startTime,
      dateLogged: dateLogged ?? this.dateLogged,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      rpe: rpe ?? this.rpe,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (timeStarted.present) {
      map['time_started'] = Variable<String>(timeStarted.value);
    }
    if (durationMin.present) {
      map['duration_min'] = Variable<double>(durationMin.value);
    }
    if (distanceKm.present) {
      map['distance_km'] = Variable<double>(distanceKm.value);
    }
    if (elevationGainM.present) {
      map['elevation_gain_m'] = Variable<double>(elevationGainM.value);
    }
    if (avgHr.present) {
      map['avg_hr'] = Variable<int>(avgHr.value);
    }
    if (tssScore.present) {
      map['tss_score'] = Variable<int>(tssScore.value);
    }
    if (gpxFileName.present) {
      map['gpx_file_name'] = Variable<String>(gpxFileName.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (dateLogged.present) {
      map['date_logged'] = Variable<DateTime>(dateLogged.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (rpe.present) {
      map['rpe'] = Variable<double>(rpe.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivitiesIndexCompanion(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('category: $category, ')
          ..write('date: $date, ')
          ..write('timeStarted: $timeStarted, ')
          ..write('durationMin: $durationMin, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('elevationGainM: $elevationGainM, ')
          ..write('avgHr: $avgHr, ')
          ..write('tssScore: $tssScore, ')
          ..write('gpxFileName: $gpxFileName, ')
          ..write('startTime: $startTime, ')
          ..write('dateLogged: $dateLogged, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('rpe: $rpe, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PlansIndexTable extends PlansIndex
    with TableInfo<$PlansIndexTable, PlanIndexRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlansIndexTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _programNameMeta =
      const VerificationMeta('programName');
  @override
  late final GeneratedColumn<String> programName = GeneratedColumn<String>(
      'program_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationWeeksMeta =
      const VerificationMeta('durationWeeks');
  @override
  late final GeneratedColumn<int> durationWeeks = GeneratedColumn<int>(
      'duration_weeks', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _daysPerWeekMeta =
      const VerificationMeta('daysPerWeek');
  @override
  late final GeneratedColumn<int> daysPerWeek = GeneratedColumn<int>(
      'days_per_week', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
      'start_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        filePath,
        programName,
        durationWeeks,
        daysPerWeek,
        startDate,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plans_index';
  @override
  VerificationContext validateIntegrity(Insertable<PlanIndexRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('program_name')) {
      context.handle(
          _programNameMeta,
          programName.isAcceptableOrUnknown(
              data['program_name']!, _programNameMeta));
    } else if (isInserting) {
      context.missing(_programNameMeta);
    }
    if (data.containsKey('duration_weeks')) {
      context.handle(
          _durationWeeksMeta,
          durationWeeks.isAcceptableOrUnknown(
              data['duration_weeks']!, _durationWeeksMeta));
    } else if (isInserting) {
      context.missing(_durationWeeksMeta);
    }
    if (data.containsKey('days_per_week')) {
      context.handle(
          _daysPerWeekMeta,
          daysPerWeek.isAcceptableOrUnknown(
              data['days_per_week']!, _daysPerWeekMeta));
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlanIndexRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanIndexRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      programName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}program_name'])!,
      durationWeeks: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_weeks'])!,
      daysPerWeek: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}days_per_week']),
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_date']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PlansIndexTable createAlias(String alias) {
    return $PlansIndexTable(attachedDatabase, alias);
  }
}

class PlanIndexRow extends DataClass implements Insertable<PlanIndexRow> {
  final int id;
  final String filePath;
  final String programName;
  final int durationWeeks;
  final int? daysPerWeek;
  final DateTime? startDate;
  final DateTime updatedAt;
  const PlanIndexRow(
      {required this.id,
      required this.filePath,
      required this.programName,
      required this.durationWeeks,
      this.daysPerWeek,
      this.startDate,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_path'] = Variable<String>(filePath);
    map['program_name'] = Variable<String>(programName);
    map['duration_weeks'] = Variable<int>(durationWeeks);
    if (!nullToAbsent || daysPerWeek != null) {
      map['days_per_week'] = Variable<int>(daysPerWeek);
    }
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlansIndexCompanion toCompanion(bool nullToAbsent) {
    return PlansIndexCompanion(
      id: Value(id),
      filePath: Value(filePath),
      programName: Value(programName),
      durationWeeks: Value(durationWeeks),
      daysPerWeek: daysPerWeek == null && nullToAbsent
          ? const Value.absent()
          : Value(daysPerWeek),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlanIndexRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanIndexRow(
      id: serializer.fromJson<int>(json['id']),
      filePath: serializer.fromJson<String>(json['filePath']),
      programName: serializer.fromJson<String>(json['programName']),
      durationWeeks: serializer.fromJson<int>(json['durationWeeks']),
      daysPerWeek: serializer.fromJson<int?>(json['daysPerWeek']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'filePath': serializer.toJson<String>(filePath),
      'programName': serializer.toJson<String>(programName),
      'durationWeeks': serializer.toJson<int>(durationWeeks),
      'daysPerWeek': serializer.toJson<int?>(daysPerWeek),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlanIndexRow copyWith(
          {int? id,
          String? filePath,
          String? programName,
          int? durationWeeks,
          Value<int?> daysPerWeek = const Value.absent(),
          Value<DateTime?> startDate = const Value.absent(),
          DateTime? updatedAt}) =>
      PlanIndexRow(
        id: id ?? this.id,
        filePath: filePath ?? this.filePath,
        programName: programName ?? this.programName,
        durationWeeks: durationWeeks ?? this.durationWeeks,
        daysPerWeek: daysPerWeek.present ? daysPerWeek.value : this.daysPerWeek,
        startDate: startDate.present ? startDate.value : this.startDate,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PlanIndexRow copyWithCompanion(PlansIndexCompanion data) {
    return PlanIndexRow(
      id: data.id.present ? data.id.value : this.id,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      programName:
          data.programName.present ? data.programName.value : this.programName,
      durationWeeks: data.durationWeeks.present
          ? data.durationWeeks.value
          : this.durationWeeks,
      daysPerWeek:
          data.daysPerWeek.present ? data.daysPerWeek.value : this.daysPerWeek,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanIndexRow(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('programName: $programName, ')
          ..write('durationWeeks: $durationWeeks, ')
          ..write('daysPerWeek: $daysPerWeek, ')
          ..write('startDate: $startDate, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, filePath, programName, durationWeeks,
      daysPerWeek, startDate, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanIndexRow &&
          other.id == this.id &&
          other.filePath == this.filePath &&
          other.programName == this.programName &&
          other.durationWeeks == this.durationWeeks &&
          other.daysPerWeek == this.daysPerWeek &&
          other.startDate == this.startDate &&
          other.updatedAt == this.updatedAt);
}

class PlansIndexCompanion extends UpdateCompanion<PlanIndexRow> {
  final Value<int> id;
  final Value<String> filePath;
  final Value<String> programName;
  final Value<int> durationWeeks;
  final Value<int?> daysPerWeek;
  final Value<DateTime?> startDate;
  final Value<DateTime> updatedAt;
  const PlansIndexCompanion({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.programName = const Value.absent(),
    this.durationWeeks = const Value.absent(),
    this.daysPerWeek = const Value.absent(),
    this.startDate = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PlansIndexCompanion.insert({
    this.id = const Value.absent(),
    required String filePath,
    required String programName,
    required int durationWeeks,
    this.daysPerWeek = const Value.absent(),
    this.startDate = const Value.absent(),
    required DateTime updatedAt,
  })  : filePath = Value(filePath),
        programName = Value(programName),
        durationWeeks = Value(durationWeeks),
        updatedAt = Value(updatedAt);
  static Insertable<PlanIndexRow> custom({
    Expression<int>? id,
    Expression<String>? filePath,
    Expression<String>? programName,
    Expression<int>? durationWeeks,
    Expression<int>? daysPerWeek,
    Expression<DateTime>? startDate,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filePath != null) 'file_path': filePath,
      if (programName != null) 'program_name': programName,
      if (durationWeeks != null) 'duration_weeks': durationWeeks,
      if (daysPerWeek != null) 'days_per_week': daysPerWeek,
      if (startDate != null) 'start_date': startDate,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PlansIndexCompanion copyWith(
      {Value<int>? id,
      Value<String>? filePath,
      Value<String>? programName,
      Value<int>? durationWeeks,
      Value<int?>? daysPerWeek,
      Value<DateTime?>? startDate,
      Value<DateTime>? updatedAt}) {
    return PlansIndexCompanion(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      programName: programName ?? this.programName,
      durationWeeks: durationWeeks ?? this.durationWeeks,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      startDate: startDate ?? this.startDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (programName.present) {
      map['program_name'] = Variable<String>(programName.value);
    }
    if (durationWeeks.present) {
      map['duration_weeks'] = Variable<int>(durationWeeks.value);
    }
    if (daysPerWeek.present) {
      map['days_per_week'] = Variable<int>(daysPerWeek.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlansIndexCompanion(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('programName: $programName, ')
          ..write('durationWeeks: $durationWeeks, ')
          ..write('daysPerWeek: $daysPerWeek, ')
          ..write('startDate: $startDate, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WorkoutsIndexTable workoutsIndex = $WorkoutsIndexTable(this);
  late final $ActivitiesIndexTable activitiesIndex =
      $ActivitiesIndexTable(this);
  late final $PlansIndexTable plansIndex = $PlansIndexTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [workoutsIndex, activitiesIndex, plansIndex];
}

typedef $$WorkoutsIndexTableCreateCompanionBuilder = WorkoutsIndexCompanion
    Function({
  Value<int> id,
  required String filePath,
  required String split,
  required DateTime date,
  required String timeStarted,
  required double durationMin,
  Value<double?> totalVolumeKg,
  Value<int?> tssScore,
  Value<int?> readinessScore,
  Value<DateTime?> startTime,
  Value<DateTime?> dateLogged,
  required DateTime updatedAt,
});
typedef $$WorkoutsIndexTableUpdateCompanionBuilder = WorkoutsIndexCompanion
    Function({
  Value<int> id,
  Value<String> filePath,
  Value<String> split,
  Value<DateTime> date,
  Value<String> timeStarted,
  Value<double> durationMin,
  Value<double?> totalVolumeKg,
  Value<int?> tssScore,
  Value<int?> readinessScore,
  Value<DateTime?> startTime,
  Value<DateTime?> dateLogged,
  Value<DateTime> updatedAt,
});

class $$WorkoutsIndexTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutsIndexTable> {
  $$WorkoutsIndexTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get split => $composableBuilder(
      column: $table.split, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timeStarted => $composableBuilder(
      column: $table.timeStarted, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get durationMin => $composableBuilder(
      column: $table.durationMin, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalVolumeKg => $composableBuilder(
      column: $table.totalVolumeKg, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tssScore => $composableBuilder(
      column: $table.tssScore, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get readinessScore => $composableBuilder(
      column: $table.readinessScore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dateLogged => $composableBuilder(
      column: $table.dateLogged, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$WorkoutsIndexTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutsIndexTable> {
  $$WorkoutsIndexTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get split => $composableBuilder(
      column: $table.split, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timeStarted => $composableBuilder(
      column: $table.timeStarted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get durationMin => $composableBuilder(
      column: $table.durationMin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalVolumeKg => $composableBuilder(
      column: $table.totalVolumeKg,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tssScore => $composableBuilder(
      column: $table.tssScore, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get readinessScore => $composableBuilder(
      column: $table.readinessScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dateLogged => $composableBuilder(
      column: $table.dateLogged, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$WorkoutsIndexTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutsIndexTable> {
  $$WorkoutsIndexTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get split =>
      $composableBuilder(column: $table.split, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get timeStarted => $composableBuilder(
      column: $table.timeStarted, builder: (column) => column);

  GeneratedColumn<double> get durationMin => $composableBuilder(
      column: $table.durationMin, builder: (column) => column);

  GeneratedColumn<double> get totalVolumeKg => $composableBuilder(
      column: $table.totalVolumeKg, builder: (column) => column);

  GeneratedColumn<int> get tssScore =>
      $composableBuilder(column: $table.tssScore, builder: (column) => column);

  GeneratedColumn<int> get readinessScore => $composableBuilder(
      column: $table.readinessScore, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get dateLogged => $composableBuilder(
      column: $table.dateLogged, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WorkoutsIndexTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorkoutsIndexTable,
    WorkoutIndexRow,
    $$WorkoutsIndexTableFilterComposer,
    $$WorkoutsIndexTableOrderingComposer,
    $$WorkoutsIndexTableAnnotationComposer,
    $$WorkoutsIndexTableCreateCompanionBuilder,
    $$WorkoutsIndexTableUpdateCompanionBuilder,
    (
      WorkoutIndexRow,
      BaseReferences<_$AppDatabase, $WorkoutsIndexTable, WorkoutIndexRow>
    ),
    WorkoutIndexRow,
    PrefetchHooks Function()> {
  $$WorkoutsIndexTableTableManager(_$AppDatabase db, $WorkoutsIndexTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutsIndexTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutsIndexTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutsIndexTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String> split = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<String> timeStarted = const Value.absent(),
            Value<double> durationMin = const Value.absent(),
            Value<double?> totalVolumeKg = const Value.absent(),
            Value<int?> tssScore = const Value.absent(),
            Value<int?> readinessScore = const Value.absent(),
            Value<DateTime?> startTime = const Value.absent(),
            Value<DateTime?> dateLogged = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              WorkoutsIndexCompanion(
            id: id,
            filePath: filePath,
            split: split,
            date: date,
            timeStarted: timeStarted,
            durationMin: durationMin,
            totalVolumeKg: totalVolumeKg,
            tssScore: tssScore,
            readinessScore: readinessScore,
            startTime: startTime,
            dateLogged: dateLogged,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String filePath,
            required String split,
            required DateTime date,
            required String timeStarted,
            required double durationMin,
            Value<double?> totalVolumeKg = const Value.absent(),
            Value<int?> tssScore = const Value.absent(),
            Value<int?> readinessScore = const Value.absent(),
            Value<DateTime?> startTime = const Value.absent(),
            Value<DateTime?> dateLogged = const Value.absent(),
            required DateTime updatedAt,
          }) =>
              WorkoutsIndexCompanion.insert(
            id: id,
            filePath: filePath,
            split: split,
            date: date,
            timeStarted: timeStarted,
            durationMin: durationMin,
            totalVolumeKg: totalVolumeKg,
            tssScore: tssScore,
            readinessScore: readinessScore,
            startTime: startTime,
            dateLogged: dateLogged,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WorkoutsIndexTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WorkoutsIndexTable,
    WorkoutIndexRow,
    $$WorkoutsIndexTableFilterComposer,
    $$WorkoutsIndexTableOrderingComposer,
    $$WorkoutsIndexTableAnnotationComposer,
    $$WorkoutsIndexTableCreateCompanionBuilder,
    $$WorkoutsIndexTableUpdateCompanionBuilder,
    (
      WorkoutIndexRow,
      BaseReferences<_$AppDatabase, $WorkoutsIndexTable, WorkoutIndexRow>
    ),
    WorkoutIndexRow,
    PrefetchHooks Function()>;
typedef $$ActivitiesIndexTableCreateCompanionBuilder = ActivitiesIndexCompanion
    Function({
  Value<int> id,
  required String filePath,
  required String category,
  required DateTime date,
  required String timeStarted,
  required double durationMin,
  Value<double?> distanceKm,
  Value<double?> elevationGainM,
  Value<int?> avgHr,
  Value<int?> tssScore,
  Value<String?> gpxFileName,
  Value<DateTime?> startTime,
  Value<DateTime?> dateLogged,
  Value<int?> durationSeconds,
  Value<double?> rpe,
  required DateTime updatedAt,
});
typedef $$ActivitiesIndexTableUpdateCompanionBuilder = ActivitiesIndexCompanion
    Function({
  Value<int> id,
  Value<String> filePath,
  Value<String> category,
  Value<DateTime> date,
  Value<String> timeStarted,
  Value<double> durationMin,
  Value<double?> distanceKm,
  Value<double?> elevationGainM,
  Value<int?> avgHr,
  Value<int?> tssScore,
  Value<String?> gpxFileName,
  Value<DateTime?> startTime,
  Value<DateTime?> dateLogged,
  Value<int?> durationSeconds,
  Value<double?> rpe,
  Value<DateTime> updatedAt,
});

class $$ActivitiesIndexTableFilterComposer
    extends Composer<_$AppDatabase, $ActivitiesIndexTable> {
  $$ActivitiesIndexTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timeStarted => $composableBuilder(
      column: $table.timeStarted, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get durationMin => $composableBuilder(
      column: $table.durationMin, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get distanceKm => $composableBuilder(
      column: $table.distanceKm, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get elevationGainM => $composableBuilder(
      column: $table.elevationGainM,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get avgHr => $composableBuilder(
      column: $table.avgHr, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tssScore => $composableBuilder(
      column: $table.tssScore, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gpxFileName => $composableBuilder(
      column: $table.gpxFileName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dateLogged => $composableBuilder(
      column: $table.dateLogged, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rpe => $composableBuilder(
      column: $table.rpe, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ActivitiesIndexTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivitiesIndexTable> {
  $$ActivitiesIndexTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timeStarted => $composableBuilder(
      column: $table.timeStarted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get durationMin => $composableBuilder(
      column: $table.durationMin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get distanceKm => $composableBuilder(
      column: $table.distanceKm, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get elevationGainM => $composableBuilder(
      column: $table.elevationGainM,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get avgHr => $composableBuilder(
      column: $table.avgHr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tssScore => $composableBuilder(
      column: $table.tssScore, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gpxFileName => $composableBuilder(
      column: $table.gpxFileName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dateLogged => $composableBuilder(
      column: $table.dateLogged, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rpe => $composableBuilder(
      column: $table.rpe, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ActivitiesIndexTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivitiesIndexTable> {
  $$ActivitiesIndexTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get timeStarted => $composableBuilder(
      column: $table.timeStarted, builder: (column) => column);

  GeneratedColumn<double> get durationMin => $composableBuilder(
      column: $table.durationMin, builder: (column) => column);

  GeneratedColumn<double> get distanceKm => $composableBuilder(
      column: $table.distanceKm, builder: (column) => column);

  GeneratedColumn<double> get elevationGainM => $composableBuilder(
      column: $table.elevationGainM, builder: (column) => column);

  GeneratedColumn<int> get avgHr =>
      $composableBuilder(column: $table.avgHr, builder: (column) => column);

  GeneratedColumn<int> get tssScore =>
      $composableBuilder(column: $table.tssScore, builder: (column) => column);

  GeneratedColumn<String> get gpxFileName => $composableBuilder(
      column: $table.gpxFileName, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get dateLogged => $composableBuilder(
      column: $table.dateLogged, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<double> get rpe =>
      $composableBuilder(column: $table.rpe, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ActivitiesIndexTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ActivitiesIndexTable,
    ActivityIndexRow,
    $$ActivitiesIndexTableFilterComposer,
    $$ActivitiesIndexTableOrderingComposer,
    $$ActivitiesIndexTableAnnotationComposer,
    $$ActivitiesIndexTableCreateCompanionBuilder,
    $$ActivitiesIndexTableUpdateCompanionBuilder,
    (
      ActivityIndexRow,
      BaseReferences<_$AppDatabase, $ActivitiesIndexTable, ActivityIndexRow>
    ),
    ActivityIndexRow,
    PrefetchHooks Function()> {
  $$ActivitiesIndexTableTableManager(
      _$AppDatabase db, $ActivitiesIndexTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivitiesIndexTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivitiesIndexTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivitiesIndexTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<String> timeStarted = const Value.absent(),
            Value<double> durationMin = const Value.absent(),
            Value<double?> distanceKm = const Value.absent(),
            Value<double?> elevationGainM = const Value.absent(),
            Value<int?> avgHr = const Value.absent(),
            Value<int?> tssScore = const Value.absent(),
            Value<String?> gpxFileName = const Value.absent(),
            Value<DateTime?> startTime = const Value.absent(),
            Value<DateTime?> dateLogged = const Value.absent(),
            Value<int?> durationSeconds = const Value.absent(),
            Value<double?> rpe = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              ActivitiesIndexCompanion(
            id: id,
            filePath: filePath,
            category: category,
            date: date,
            timeStarted: timeStarted,
            durationMin: durationMin,
            distanceKm: distanceKm,
            elevationGainM: elevationGainM,
            avgHr: avgHr,
            tssScore: tssScore,
            gpxFileName: gpxFileName,
            startTime: startTime,
            dateLogged: dateLogged,
            durationSeconds: durationSeconds,
            rpe: rpe,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String filePath,
            required String category,
            required DateTime date,
            required String timeStarted,
            required double durationMin,
            Value<double?> distanceKm = const Value.absent(),
            Value<double?> elevationGainM = const Value.absent(),
            Value<int?> avgHr = const Value.absent(),
            Value<int?> tssScore = const Value.absent(),
            Value<String?> gpxFileName = const Value.absent(),
            Value<DateTime?> startTime = const Value.absent(),
            Value<DateTime?> dateLogged = const Value.absent(),
            Value<int?> durationSeconds = const Value.absent(),
            Value<double?> rpe = const Value.absent(),
            required DateTime updatedAt,
          }) =>
              ActivitiesIndexCompanion.insert(
            id: id,
            filePath: filePath,
            category: category,
            date: date,
            timeStarted: timeStarted,
            durationMin: durationMin,
            distanceKm: distanceKm,
            elevationGainM: elevationGainM,
            avgHr: avgHr,
            tssScore: tssScore,
            gpxFileName: gpxFileName,
            startTime: startTime,
            dateLogged: dateLogged,
            durationSeconds: durationSeconds,
            rpe: rpe,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ActivitiesIndexTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ActivitiesIndexTable,
    ActivityIndexRow,
    $$ActivitiesIndexTableFilterComposer,
    $$ActivitiesIndexTableOrderingComposer,
    $$ActivitiesIndexTableAnnotationComposer,
    $$ActivitiesIndexTableCreateCompanionBuilder,
    $$ActivitiesIndexTableUpdateCompanionBuilder,
    (
      ActivityIndexRow,
      BaseReferences<_$AppDatabase, $ActivitiesIndexTable, ActivityIndexRow>
    ),
    ActivityIndexRow,
    PrefetchHooks Function()>;
typedef $$PlansIndexTableCreateCompanionBuilder = PlansIndexCompanion Function({
  Value<int> id,
  required String filePath,
  required String programName,
  required int durationWeeks,
  Value<int?> daysPerWeek,
  Value<DateTime?> startDate,
  required DateTime updatedAt,
});
typedef $$PlansIndexTableUpdateCompanionBuilder = PlansIndexCompanion Function({
  Value<int> id,
  Value<String> filePath,
  Value<String> programName,
  Value<int> durationWeeks,
  Value<int?> daysPerWeek,
  Value<DateTime?> startDate,
  Value<DateTime> updatedAt,
});

class $$PlansIndexTableFilterComposer
    extends Composer<_$AppDatabase, $PlansIndexTable> {
  $$PlansIndexTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get programName => $composableBuilder(
      column: $table.programName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationWeeks => $composableBuilder(
      column: $table.durationWeeks, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get daysPerWeek => $composableBuilder(
      column: $table.daysPerWeek, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PlansIndexTableOrderingComposer
    extends Composer<_$AppDatabase, $PlansIndexTable> {
  $$PlansIndexTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get programName => $composableBuilder(
      column: $table.programName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationWeeks => $composableBuilder(
      column: $table.durationWeeks,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get daysPerWeek => $composableBuilder(
      column: $table.daysPerWeek, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlansIndexTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlansIndexTable> {
  $$PlansIndexTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get programName => $composableBuilder(
      column: $table.programName, builder: (column) => column);

  GeneratedColumn<int> get durationWeeks => $composableBuilder(
      column: $table.durationWeeks, builder: (column) => column);

  GeneratedColumn<int> get daysPerWeek => $composableBuilder(
      column: $table.daysPerWeek, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlansIndexTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlansIndexTable,
    PlanIndexRow,
    $$PlansIndexTableFilterComposer,
    $$PlansIndexTableOrderingComposer,
    $$PlansIndexTableAnnotationComposer,
    $$PlansIndexTableCreateCompanionBuilder,
    $$PlansIndexTableUpdateCompanionBuilder,
    (
      PlanIndexRow,
      BaseReferences<_$AppDatabase, $PlansIndexTable, PlanIndexRow>
    ),
    PlanIndexRow,
    PrefetchHooks Function()> {
  $$PlansIndexTableTableManager(_$AppDatabase db, $PlansIndexTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlansIndexTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlansIndexTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlansIndexTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String> programName = const Value.absent(),
            Value<int> durationWeeks = const Value.absent(),
            Value<int?> daysPerWeek = const Value.absent(),
            Value<DateTime?> startDate = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              PlansIndexCompanion(
            id: id,
            filePath: filePath,
            programName: programName,
            durationWeeks: durationWeeks,
            daysPerWeek: daysPerWeek,
            startDate: startDate,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String filePath,
            required String programName,
            required int durationWeeks,
            Value<int?> daysPerWeek = const Value.absent(),
            Value<DateTime?> startDate = const Value.absent(),
            required DateTime updatedAt,
          }) =>
              PlansIndexCompanion.insert(
            id: id,
            filePath: filePath,
            programName: programName,
            durationWeeks: durationWeeks,
            daysPerWeek: daysPerWeek,
            startDate: startDate,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlansIndexTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlansIndexTable,
    PlanIndexRow,
    $$PlansIndexTableFilterComposer,
    $$PlansIndexTableOrderingComposer,
    $$PlansIndexTableAnnotationComposer,
    $$PlansIndexTableCreateCompanionBuilder,
    $$PlansIndexTableUpdateCompanionBuilder,
    (
      PlanIndexRow,
      BaseReferences<_$AppDatabase, $PlansIndexTable, PlanIndexRow>
    ),
    PlanIndexRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WorkoutsIndexTableTableManager get workoutsIndex =>
      $$WorkoutsIndexTableTableManager(_db, _db.workoutsIndex);
  $$ActivitiesIndexTableTableManager get activitiesIndex =>
      $$ActivitiesIndexTableTableManager(_db, _db.activitiesIndex);
  $$PlansIndexTableTableManager get plansIndex =>
      $$PlansIndexTableTableManager(_db, _db.plansIndex);
}
