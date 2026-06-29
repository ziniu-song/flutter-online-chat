import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/message.dart';

class LocalMessageDb {
  LocalMessageDb._();

  static final LocalMessageDb instance = LocalMessageDb._();

  Database? _db;

  bool get _unsupported => kIsWeb;

  Future<Database> get database async {
    if (_unsupported) {
      throw UnsupportedError('当前平台不支持本地 SQLite 缓存');
    }

    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'pink_chat_cache.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY,
            sender_id INTEGER NOT NULL,
            receiver_id INTEGER,
            group_id INTEGER,
            content TEXT NOT NULL,
            message_type TEXT NOT NULL,
            created_at TEXT NOT NULL,
            sender_name TEXT,
            sender_avatar TEXT
          )
        ''');
      },
    );

    return _db!;
  }

  Future<void> upsertMessages(List<ChatMessage> messages) async {
    if (_unsupported) return;
    if (messages.isEmpty) return;

    final db = await database;
    final batch = db.batch();

    for (final message in messages) {
      batch.insert(
        'messages',
        message.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> upsertMessage(ChatMessage message) async {
    await upsertMessages([message]);
  }

  Future<List<ChatMessage>> getPrivateMessages({
    required int currentUserId,
    required int peerId,
  }) async {
    if (_unsupported) return [];

    final db = await database;
    final rows = await db.query(
      'messages',
      where:
          'group_id IS NULL AND ((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?))',
      whereArgs: [currentUserId, peerId, peerId, currentUserId],
      orderBy: 'created_at ASC',
    );

    return rows.map(ChatMessage.fromJson).toList();
  }

  Future<List<ChatMessage>> getGroupMessages(int groupId) async {
    if (_unsupported) return [];

    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'created_at ASC',
    );

    return rows.map(ChatMessage.fromJson).toList();
  }

  Future<void> clear() async {
    if (_unsupported) return;

    final db = await database;
    await db.delete('messages');
  }
}
