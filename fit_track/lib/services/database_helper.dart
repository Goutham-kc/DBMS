import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fit_track_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // 1. Owner Table
    await db.execute('''
      CREATE TABLE Owner (
        Owner_ID TEXT PRIMARY KEY, 
        Email TEXT, 
        FName TEXT, 
        LName TEXT
      )
    ''');
    
    // 2. Trainer Table (1:N with Owner)
    await db.execute('''
      CREATE TABLE Trainer (
        Trainer_ID TEXT PRIMARY KEY, 
        Email TEXT, 
        FName TEXT, 
        LName TEXT, 
        Owner_ID TEXT,
        FOREIGN KEY (Owner_ID) REFERENCES Owner (Owner_ID)
      )
    ''');
    
    // 3. Goal Table
    await db.execute('CREATE TABLE Goal (Goal_ID TEXT PRIMARY KEY, Goal_Name TEXT)');

    // 4. Member Table (1:N with Trainer)
    await db.execute('''
      CREATE TABLE Member (
        Member_ID TEXT PRIMARY KEY, 
        Email TEXT, 
        FName TEXT, 
        LName TEXT, 
        Age INTEGER, 
        Join_Date TEXT, 
        Trainer_ID TEXT,
        Goal_ID TEXT,
        FOREIGN KEY (Trainer_ID) REFERENCES Trainer (Trainer_ID),
        FOREIGN KEY (Goal_ID) REFERENCES Goal (Goal_ID)
      )
    ''');

    // 5. Membership Table (Weak Entity, 1:1 with Member)
    await db.execute('''
      CREATE TABLE Membership (
        Membership_ID TEXT PRIMARY KEY,
        Member_ID TEXT,
        Start_Date TEXT,
        End_Date TEXT,
        Days_Left INTEGER,
        Membership_Type TEXT,
        FOREIGN KEY (Member_ID) REFERENCES Member (Member_ID) ON DELETE CASCADE
      )
    ''');

    // 6. BodyPart Table
    await db.execute('CREATE TABLE BodyPart (BodyPart_ID TEXT PRIMARY KEY, BodyPart_Name TEXT)');

    // 7. Workout Table (Assigned by Trainer)
    await db.execute('''
      CREATE TABLE Workout (
        Workout_ID TEXT PRIMARY KEY,
        Workout_Name TEXT,
        Trainer_ID TEXT,
        FOREIGN KEY (Trainer_ID) REFERENCES Trainer (Trainer_ID)
      )
    ''');

    // 8. Workout_BodyPart (M:N Relationship)
    await db.execute('''
      CREATE TABLE Workout_Targets (
        Workout_ID TEXT,
        BodyPart_ID TEXT,
        PRIMARY KEY (Workout_ID, BodyPart_ID),
        FOREIGN KEY (Workout_ID) REFERENCES Workout (Workout_ID),
        FOREIGN KEY (BodyPart_ID) REFERENCES BodyPart (BodyPart_ID)
      )
    ''');

    // Initial Data for Testing
    await db.insert('Owner', {
      'Owner_ID': 'OWN1', 
      'Email': '240263@tkmce.ac.in', 
      'FName': 'Goutham', 
      'LName': 'KC'
    });
    
    await db.insert('Goal', {'Goal_ID': 'G1', 'Goal_Name': 'Muscle Gain'});
  }

  Future<bool> isOwner(String email) async {
    final db = await instance.database;
    final res = await db.query('Owner', where: 'Email = ?', whereArgs: [email]);
    return res.isNotEmpty;
  }

  Future<bool> isTrainer(String email) async {
    final db = await instance.database;
    final res = await db.query('Trainer', where: 'Email = ?', whereArgs: [email]);
    return res.isNotEmpty;
  }
}