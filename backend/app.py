import os
import sqlite3
import secrets
from datetime import datetime
from functools import wraps

from flask import Flask, request, jsonify, g
from flask_cors import CORS
from flask_socketio import SocketIO, emit, join_room, leave_room
from werkzeug.security import generate_password_hash, check_password_hash


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "chat.db")

app = Flask(__name__)
app.config["SECRET_KEY"] = "dev-secret-key-change-me"
CORS(app)

socketio = SocketIO(
    app,
    cors_allowed_origins="*",
    async_mode="threading",
)

online_users = {}


def get_db():
    if "db" not in g:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        g.db = conn
    return g.db


@app.teardown_appcontext
def close_db(_error):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def query_one(sql, params=()):
    db = get_db()
    return db.execute(sql, params).fetchone()


def query_all(sql, params=()):
    db = get_db()
    rows = db.execute(sql, params).fetchall()
    return [dict(row) for row in rows]


def execute(sql, params=()):
    db = get_db()
    cursor = db.execute(sql, params)
    db.commit()
    return cursor


def init_db():
    with app.app_context():
        db = get_db()

        db.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                nickname TEXT NOT NULL,
                avatar TEXT,
                bio TEXT,
                interests TEXT,
                created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS auth_tokens (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                token TEXT UNIQUE NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id)
            );

            CREATE TABLE IF NOT EXISTS friends (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                friend_id INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                UNIQUE(user_id, friend_id),
                FOREIGN KEY(user_id) REFERENCES users(id),
                FOREIGN KEY(friend_id) REFERENCES users(id)
            );

            CREATE TABLE IF NOT EXISTS groups (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                avatar TEXT,
                created_by INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY(created_by) REFERENCES users(id)
            );

            CREATE TABLE IF NOT EXISTS group_members (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                group_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                UNIQUE(group_id, user_id),
                FOREIGN KEY(group_id) REFERENCES groups(id),
                FOREIGN KEY(user_id) REFERENCES users(id)
            );

            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sender_id INTEGER NOT NULL,
                receiver_id INTEGER,
                group_id INTEGER,
                content TEXT NOT NULL,
                message_type TEXT NOT NULL DEFAULT 'text',
                created_at TEXT NOT NULL,
                FOREIGN KEY(sender_id) REFERENCES users(id),
                FOREIGN KEY(receiver_id) REFERENCES users(id),
                FOREIGN KEY(group_id) REFERENCES groups(id)
            );
            """
        )

        db.commit()


def now_iso():
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def row_to_user(row):
    if row is None:
        return None

    return {
        "id": row["id"],
        "username": row["username"],
        "nickname": row["nickname"],
        "avatar": row["avatar"],
        "bio": row["bio"],
        "interests": row["interests"].split(",") if row["interests"] else [],
    }


def get_user_by_token(token):
    if not token:
        return None

    row = query_one(
        """
        SELECT u.*
        FROM auth_tokens t
        JOIN users u ON u.id = t.user_id
        WHERE t.token = ?
        """,
        (token,),
    )
    return row


def token_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        token = auth_header.replace("Bearer ", "").strip()

        user = get_user_by_token(token)
        if user is None:
            return jsonify({"message": "Unauthorized"}), 401

        g.current_user = user
        return fn(*args, **kwargs)

    return wrapper


@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


@app.route("/api/register", methods=["POST"])
def register():
    data = request.get_json() or {}

    username = data.get("username", "").strip()
    password = data.get("password", "").strip()
    nickname = data.get("nickname", username).strip()

    if not username or not password:
        return jsonify({"message": "username and password are required"}), 400

    exists = query_one("SELECT id FROM users WHERE username = ?", (username,))
    if exists:
        return jsonify({"message": "username already exists"}), 409

    avatar = data.get("avatar") or f"https://api.dicebear.com/7.x/adventurer/png?seed={username}"
    bio = data.get("bio") or "期待遇见有趣的灵魂。"
    interests = ",".join(data.get("interests") or ["旅行", "音乐", "咖啡"])

    cursor = execute(
        """
        INSERT INTO users (
            username, password_hash, nickname, avatar, bio, interests, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (
            username,
            generate_password_hash(password),
            nickname,
            avatar,
            bio,
            interests,
            now_iso(),
        ),
    )

    user_id = cursor.lastrowid
    token = secrets.token_urlsafe(32)

    execute(
        "INSERT INTO auth_tokens (user_id, token, created_at) VALUES (?, ?, ?)",
        (user_id, token, now_iso()),
    )

    user = query_one("SELECT * FROM users WHERE id = ?", (user_id,))

    return jsonify(
        {
            "token": token,
            "user": row_to_user(user),
        }
    ), 201


@app.route("/api/login", methods=["POST"])
def login():
    data = request.get_json() or {}

    username = data.get("username", "").strip()
    password = data.get("password", "").strip()

    user = query_one("SELECT * FROM users WHERE username = ?", (username,))
    if user is None or not check_password_hash(user["password_hash"], password):
        return jsonify({"message": "invalid username or password"}), 401

    token = secrets.token_urlsafe(32)

    execute(
        "INSERT INTO auth_tokens (user_id, token, created_at) VALUES (?, ?, ?)",
        (user["id"], token, now_iso()),
    )

    return jsonify(
        {
            "token": token,
            "user": row_to_user(user),
        }
    )


@app.route("/api/me", methods=["GET"])
@token_required
def me():
    return jsonify({"user": row_to_user(g.current_user)})


@app.route("/api/me", methods=["PUT"])
@token_required
def update_me():
    data = request.get_json() or {}
    current_user = g.current_user
    user_id = current_user["id"]

    username = data.get("username", current_user["username"]).strip()
    nickname = data.get("nickname", current_user["nickname"]).strip()
    avatar = data.get("avatar", current_user["avatar"])
    bio = data.get("bio", current_user["bio"])
    interests_raw = data.get("interests", current_user["interests"])

    if not username:
        return jsonify({"message": "用户名不能为空"}), 400

    if not nickname:
        return jsonify({"message": "昵称不能为空"}), 400

    exists = query_one(
        "SELECT id FROM users WHERE username = ? AND id != ?",
        (username, user_id),
    )
    if exists:
        return jsonify({"message": "用户名已被占用"}), 409

    if isinstance(interests_raw, list):
        interests = ",".join([str(item).strip() for item in interests_raw if str(item).strip()])
    else:
        interests = str(interests_raw or "")

    execute(
        """
        UPDATE users
        SET username = ?, nickname = ?, avatar = ?, bio = ?, interests = ?
        WHERE id = ?
        """,
        (username, nickname, avatar, bio, interests, user_id),
    )

    user = query_one("SELECT * FROM users WHERE id = ?", (user_id,))
    return jsonify({"user": row_to_user(user)})


@app.route("/api/users/<int:user_id>", methods=["GET"])
@token_required
def get_user(user_id):
    user = query_one(
        """
        SELECT id, username, nickname, avatar, bio, interests
        FROM users
        WHERE id = ?
        """,
        (user_id,),
    )

    if user is None:
        return jsonify({"message": "用户不存在"}), 404

    return jsonify({"user": row_to_user(user)})


@app.route("/api/users/recommendations", methods=["GET"])
@token_required
def recommendations():
    current_user_id = g.current_user["id"]

    users = query_all(
        """
        SELECT id, username, nickname, avatar, bio, interests
        FROM users
        WHERE id != ?
          AND id NOT IN (
            SELECT friend_id FROM friends WHERE user_id = ?
          )
        ORDER BY id DESC
        LIMIT 20
        """,
        (current_user_id, current_user_id),
    )

    for user in users:
        user["interests"] = user["interests"].split(",") if user["interests"] else []

    return jsonify({"users": users})


@app.route("/api/friends", methods=["GET"])
@token_required
def get_friends():
    current_user_id = g.current_user["id"]

    friends = query_all(
        """
        SELECT u.id, u.username, u.nickname, u.avatar, u.bio, u.interests
        FROM friends f
        JOIN users u ON u.id = f.friend_id
        WHERE f.user_id = ?
        ORDER BY f.created_at DESC
        """,
        (current_user_id,),
    )

    for friend in friends:
        friend["interests"] = friend["interests"].split(",") if friend["interests"] else []

    return jsonify({"friends": friends})


@app.route("/api/friends", methods=["POST"])
@token_required
def add_friend():
    data = request.get_json() or {}
    current_user_id = g.current_user["id"]
    friend_id = data.get("friend_id")

    if not friend_id:
        return jsonify({"message": "friend_id is required"}), 400

    if int(friend_id) == int(current_user_id):
        return jsonify({"message": "cannot add yourself"}), 400

    friend = query_one("SELECT id FROM users WHERE id = ?", (friend_id,))
    if friend is None:
        return jsonify({"message": "friend not found"}), 404

    created_at = now_iso()

    execute(
        """
        INSERT OR IGNORE INTO friends (user_id, friend_id, created_at)
        VALUES (?, ?, ?)
        """,
        (current_user_id, friend_id, created_at),
    )

    execute(
        """
        INSERT OR IGNORE INTO friends (user_id, friend_id, created_at)
        VALUES (?, ?, ?)
        """,
        (friend_id, current_user_id, created_at),
    )

    return jsonify({"message": "friend added"})


@app.route("/api/friends/<int:friend_id>", methods=["DELETE"])
@token_required
def remove_friend(friend_id):
    current_user_id = g.current_user["id"]

    if int(friend_id) == int(current_user_id):
        return jsonify({"message": "不能删除自己"}), 400

    friend = query_one("SELECT id FROM users WHERE id = ?", (friend_id,))
    if friend is None:
        return jsonify({"message": "用户不存在"}), 404

    execute(
        "DELETE FROM friends WHERE user_id = ? AND friend_id = ?",
        (current_user_id, friend_id),
    )
    execute(
        "DELETE FROM friends WHERE user_id = ? AND friend_id = ?",
        (friend_id, current_user_id),
    )

    return jsonify({"message": "好友已删除"})


@app.route("/api/groups", methods=["POST"])
@token_required
def create_group():
    data = request.get_json() or {}
    name = data.get("name", "").strip()
    member_ids = data.get("member_ids") or []

    if not name:
        return jsonify({"message": "group name is required"}), 400

    current_user_id = g.current_user["id"]

    cursor = execute(
        """
        INSERT INTO groups (name, avatar, created_by, created_at)
        VALUES (?, ?, ?, ?)
        """,
        (
            name,
            data.get("avatar"),
            current_user_id,
            now_iso(),
        ),
    )

    group_id = cursor.lastrowid
    all_member_ids = set([current_user_id] + [int(item) for item in member_ids])

    for user_id in all_member_ids:
        execute(
            """
            INSERT OR IGNORE INTO group_members (group_id, user_id, created_at)
            VALUES (?, ?, ?)
            """,
            (group_id, user_id, now_iso()),
        )

    return jsonify({"group_id": group_id, "message": "group created"}), 201


@app.route("/api/groups", methods=["GET"])
@token_required
def get_groups():
    current_user_id = g.current_user["id"]

    groups = query_all(
        """
        SELECT g.id, g.name, g.avatar, g.created_by, g.created_at
        FROM groups g
        JOIN group_members gm ON gm.group_id = g.id
        WHERE gm.user_id = ?
        ORDER BY g.created_at DESC
        """,
        (current_user_id,),
    )

    return jsonify({"groups": groups})


@app.route("/api/messages/private/<int:friend_id>", methods=["GET"])
@token_required
def get_private_messages(friend_id):
    current_user_id = g.current_user["id"]
    limit = int(request.args.get("limit", 50))

    messages = query_all(
        """
        SELECT m.*, u.nickname AS sender_name, u.avatar AS sender_avatar
        FROM messages m
        JOIN users u ON u.id = m.sender_id
        WHERE m.group_id IS NULL
          AND (
            (m.sender_id = ? AND m.receiver_id = ?)
            OR
            (m.sender_id = ? AND m.receiver_id = ?)
          )
        ORDER BY m.created_at ASC
        LIMIT ?
        """,
        (current_user_id, friend_id, friend_id, current_user_id, limit),
    )

    return jsonify({"messages": messages})


@app.route("/api/messages/group/<int:group_id>", methods=["GET"])
@token_required
def get_group_messages(group_id):
    current_user_id = g.current_user["id"]

    member = query_one(
        """
        SELECT id FROM group_members
        WHERE group_id = ? AND user_id = ?
        """,
        (group_id, current_user_id),
    )

    if member is None:
        return jsonify({"message": "not a group member"}), 403

    limit = int(request.args.get("limit", 50))

    messages = query_all(
        """
        SELECT m.*, u.nickname AS sender_name, u.avatar AS sender_avatar
        FROM messages m
        JOIN users u ON u.id = m.sender_id
        WHERE m.group_id = ?
        ORDER BY m.created_at ASC
        LIMIT ?
        """,
        (group_id, limit),
    )

    return jsonify({"messages": messages})


@socketio.on("connect")
def socket_connect(auth):
    token = None

    if isinstance(auth, dict):
        token = auth.get("token")

    if not token:
        token = request.args.get("token")

    user = get_user_by_token(token)

    if user is None:
        return False

    user_id = user["id"]
    online_users[user_id] = request.sid

    join_room(f"user:{user_id}")

    group_rows = query_all(
        "SELECT group_id FROM group_members WHERE user_id = ?",
        (user_id,),
    )

    for row in group_rows:
        join_room(f"group:{row['group_id']}")

    emit(
        "connected",
        {
            "message": "connected",
            "user_id": user_id,
        },
    )


@socketio.on("disconnect")
def socket_disconnect():
    disconnected_user_id = None

    for user_id, sid in list(online_users.items()):
        if sid == request.sid:
            disconnected_user_id = user_id
            break

    if disconnected_user_id:
        online_users.pop(disconnected_user_id, None)
        leave_room(f"user:{disconnected_user_id}")


@socketio.on("send_message")
def send_message(data):
    token = data.get("token")
    user = get_user_by_token(token)

    if user is None:
        emit("error", {"message": "Unauthorized"})
        return

    sender_id = user["id"]
    receiver_id = data.get("receiver_id")
    group_id = data.get("group_id")
    content = (data.get("content") or "").strip()

    if not content:
        emit("error", {"message": "content is required"})
        return

    if not receiver_id and not group_id:
        emit("error", {"message": "receiver_id or group_id is required"})
        return

    if receiver_id and group_id:
        emit("error", {"message": "only one of receiver_id or group_id is allowed"})
        return

    created_at = now_iso()

    if group_id:
        member = query_one(
            """
            SELECT id FROM group_members
            WHERE group_id = ? AND user_id = ?
            """,
            (group_id, sender_id),
        )

        if member is None:
            emit("error", {"message": "not a group member"})
            return

    cursor = execute(
        """
        INSERT INTO messages (
            sender_id, receiver_id, group_id, content, message_type, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (
            sender_id,
            receiver_id,
            group_id,
            content,
            data.get("message_type", "text"),
            created_at,
        ),
    )

    message = {
        "id": cursor.lastrowid,
        "sender_id": sender_id,
        "receiver_id": receiver_id,
        "group_id": group_id,
        "content": content,
        "message_type": data.get("message_type", "text"),
        "created_at": created_at,
        "sender_name": user["nickname"],
        "sender_avatar": user["avatar"],
    }

    if receiver_id:
        emit("new_message", message, room=f"user:{receiver_id}")
        emit("new_message", message, room=f"user:{sender_id}")

    if group_id:
        emit("new_message", message, room=f"group:{group_id}")


@socketio.on("join_group")
def join_group(data):
    token = data.get("token")
    group_id = data.get("group_id")
    user = get_user_by_token(token)

    if user is None:
        emit("error", {"message": "Unauthorized"})
        return

    member = query_one(
        """
        SELECT id FROM group_members
        WHERE group_id = ? AND user_id = ?
        """,
        (group_id, user["id"]),
    )

    if member is None:
        emit("error", {"message": "not a group member"})
        return

    join_room(f"group:{group_id}")
    emit("joined_group", {"group_id": group_id})


if __name__ == "__main__":
    init_db()
    socketio.run(app, host="0.0.0.0", port=5000, debug=True)