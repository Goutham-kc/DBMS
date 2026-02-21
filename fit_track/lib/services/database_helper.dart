import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fit_track_final_v4.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('CREATE TABLE Owner (Owner_ID TEXT PRIMARY KEY, Email TEXT, FName TEXT, LName TEXT)');
    await db.execute('CREATE TABLE Trainer (Trainer_ID TEXT PRIMARY KEY, Email TEXT, FName TEXT, LName TEXT, Owner_ID TEXT)');
    await db.execute('CREATE TABLE Member (Member_ID TEXT PRIMARY KEY, Email TEXT, FName TEXT, LName TEXT, Age INTEGER, Join_Date TEXT)');

    // PRE-AUTHORIZE TEAM
    List<Map<String, String>> team = [
      {'ID': 'OWN1', 'Email': 'goutham.project@gmail.com', 'Name': 'Goutham'},
      {'ID': 'OWN2', 'Email': 'vaishnav.project@gmail.com', 'Name': 'Vaishnav'},
      {'ID': 'OWN3', 'Email': 'navyasree.project@gmail.com', 'Name': 'Navyasree'},
      {'ID': 'OWN4', 'Email': 'akash.project@gmail.com', 'Name': 'Akash'},
    ];

    for (var person in team) {
      await db.insert('Owner', {
        'Owner_ID': person['ID'], 
        'Email': person['Email']?.toLowerCase().trim() ?? '', 
        'FName': person['Name'], 
        'LName': 'Team'
      });
    }
  }

  Future<bool> isOwner(String email) async {
    final db = await instance.database;
    final res = await db.query('Owner', where: 'Email = ?', whereArgs: [email.toLowerCase().trim()]);
    return res.isNotEmpty;
  }
}