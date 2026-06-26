import os
import logging
import asyncio
import re
import json
import time
import secrets
import sys
from pathlib import Path
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes

logging.basicConfig(format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", level=logging.INFO)
logger = logging.getLogger(__name__)

BOT_TOKEN = os.getenv("BOT_TOKEN")
CRUNCHYROLL_EMAIL = os.getenv("CRUNCHYROLL_EMAIL")
CRUNCHYROLL_PASSWORD = os.getenv("CRUNCHYROLL_PASSWORD")
DOWNLOAD_DIR = os.getenv("DOWNLOAD_DIR", "./downloads")
_raw_ids = os.getenv("ALLOWED_USER_IDS", "")
ALLOWED_USER_IDS = [int(i.strip()) for i in _raw_ids.split(",") if i.strip().isdigit()]
ADMIN_IDS = [int(i.strip()) for i in os.getenv("ADMIN_IDS", "").split(",") if i.strip().isdigit()]

VALID_QUALITIES = ["best", "1080p", "720p", "480p", "360p"]
CR_URL_PATTERN = re.compile(r"https?://(www\.)?crunchyroll\.com/.+")
DB_FILE = "db.json"

POINTS_PER_REFERRAL = 3
POINTS_PER_PREMIUM = 3
PREMIUM_DURATION_HOURS = 2


# ─── Markdown Escape ─────────────────────────────────────────
def esc(text):
    """Escape special characters for MarkdownV2."""
    special = r"\_*[]()~`>#+-=|{}.!"
    return "".join(f"\\{c}" if c in special else c for c in str(text))


# ─── Database ────────────────────────────────────────────────
def load_db():
    if not os.path.exists(DB_FILE):
        return {"users": {}, "redeem_codes": {}}
    with open(DB_FILE, "r") as f:
        return json.load(f)

def save_db(db):
    with open(DB_FILE, "w") as f:
        json.dump(db, f, indent=2)

def get_user(db, user_id):
    uid = str(user_id)
    if uid not in db["users"]:
        db["users"][uid] = {
            "points": 0,
            "premium_until": 0,
            "referrals": 0,
            "referred_by": None,
            "username": ""
        }
    return db["users"][uid]

def is_premium(user):
    return time.time() < user.get("premium_until", 0)

def grant_premium(user):
    now = time.time()
    current = user.get("premium_until", now)
    base = max(current, now)
    user["premium_until"] = base + (PREMIUM_DURATION_HOURS * 3600)


# ─── Auth ────────────────────────────────────────────────────
def is_authorized(user_id):
    if not ALLOWED_USER_IDS:
        return True
    return user_id in ALLOWED_USER_IDS

def is_admin(user_id):
    return user_id in ADMIN_IDS


# ─── Download ────────────────────────────────────────────────
def build_command(url, quality):
    quality_map = {
        "best":  "bestvideo+bestaudio/best",
        "1080p": "bestvideo[height<=1080]+bestaudio/best[height<=1080]",
        "720p":  "bestvideo[height<=720]+bestaudio/best[height<=720]",
        "480p":  "bestvideo[height<=480]+bestaudio/best[height<=480]",
        "360p":  "bestvideo[height<=360]+bestaudio/best[height<=360]",
    }
    output = os.path.join(DOWNLOAD_DIR, "%(series)s/%(season)s/%(title)s.%(ext)s")
    return [
        "yt-dlp",
        "--username", CRUNCHYROLL_EMAIL,
        "--password", CRUNCHYROLL_PASSWORD,
        "-f", quality_map[quality],
        "-o", output,
        "--merge-output-format", "mkv",
        "--embed-subs",
        "--sub-langs", "all",
        "--write-sub",
        "--add-metadata",
        url,
    ]


# ─── /start ──────────────────────────────────────────────────
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    args = context.args

    db = load_db()
    u = get_user(db, user.id)
    u["username"] = user.username or user.first_name

    # Handle referral
    if args and args[0].startswith("ref_"):
        referrer_id = args[0][4:]
        if referrer_id != str(user.id) and u["referred_by"] is None:
            u["referred_by"] = referrer_id
            referrer = db["users"].get(referrer_id)
            if referrer:
                referrer["points"] += POINTS_PER_REFERRAL
                referrer["referrals"] += 1
                try:
                    await context.bot.send_message(
                        int(referrer_id),
                        f"🎉 Someone joined using your referral link\\!\n"
                        f"You earned *{POINTS_PER_REFERRAL} points*\\! 🔥",
                        parse_mode="MarkdownV2"
                    )
                except Exception:
                    pass
    save_db(db)

    premium_badge = "👑 Premium" if is_premium(u) else "🆓 Free"
    points = u['points']

    text = (
        "👋 *This is A4U CR\\-DL Bot\\!*\n\n"
        "Your one\\-stop Crunchyroll anime downloader 🎌\n\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "✨ *Features*\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "📥 Download anime up to *720p* \\(Free\\)\n"
        "🎬 Download in *1080p* \\(Premium only\\)\n"
        "🖼️ Custom thumbnail on downloads \\(Premium\\)\n"
        "📦 Files sent directly to your chat\n"
        "🌐 All subtitle languages embedded\n\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "👑 *Premium System*\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "• Earn *3 points* per referral 🔗\n"
        "• Spend *3 points* \\= *2 hours* of Premium ⏳\n"
        "• Use /redeem to activate premium\n\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "📋 *Commands*\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "/link \\<url\\> \\[quality\\] — Download anime\n"
        "/profile — Your points & premium status\n"
        "/referral — Get your referral link\n"
        "/redeem — Spend points for premium\n"
        "/redeemcode \\<code\\> — Redeem a gift code\n\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        f"Your status: *{esc(premium_badge)}* \\| Points: *{esc(points)}* 🪙\n\n"
        "Cooked by @Mystery\\_143 👨‍🍳"
    )

    keyboard = InlineKeyboardMarkup([
        [InlineKeyboardButton("🔗 My Referral Link", callback_data="referral")],
        [InlineKeyboardButton("👤 My Profile", callback_data="profile")],
        [InlineKeyboardButton("👑 Activate Premium", callback_data="redeem")],
    ])

    await update.message.reply_text(text, parse_mode="MarkdownV2", reply_markup=keyboard)


# ─── /profile ────────────────────────────────────────────────
async def profile(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    db = load_db()
    u = get_user(db, user.id)

    if is_premium(u):
        remaining = int((u["premium_until"] - time.time()) / 60)
        h, m = divmod(remaining, 60)
        prem_status = f"👑 Premium — expires in *{h}h {m}m*"
    else:
        prem_status = "🆓 Free user"

    text = (
        f"👤 *Your Profile*\n\n"
        f"🆔 ID: `{esc(user.id)}`\n"
        f"👤 Name: {esc(user.first_name)}\n"
        f"📊 Status: {prem_status}\n"
        f"🪙 Points: *{esc(u['points'])}*\n"
        f"🔗 Referrals: *{esc(u['referrals'])}*\n\n"
        f"_3 points \\= 2 hours Premium_"
    )

    if hasattr(update, 'message') and update.message:
        await update.message.reply_text(text, parse_mode="MarkdownV2")
    else:
        await update.effective_message.reply_text(text, parse_mode="MarkdownV2")


# ─── /referral ───────────────────────────────────────────────
async def referral(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    bot_username = (await context.bot.get_me()).username
    ref_link = f"https://t.me/{bot_username}?start=ref_{user.id}"
    db = load_db()
    u = get_user(db, user.id)
    save_db(db)

    text = (
        f"🔗 *Your Referral Link*\n\n"
        f"`{esc(ref_link)}`\n\n"
        f"Share this link with friends\\!\n"
        f"You earn *{POINTS_PER_REFERRAL} points* for every person who joins\\.\n\n"
        f"🪙 Your points: *{esc(u['points'])}*\n"
        f"👥 Total referrals: *{esc(u['referrals'])}*"
    )

    if hasattr(update, 'message') and update.message:
        await update.message.reply_text(text, parse_mode="MarkdownV2")
    else:
        await update.effective_message.reply_text(text, parse_mode="MarkdownV2")


# ─── /redeem ─────────────────────────────────────────────────
async def redeem(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    db = load_db()
    u = get_user(db, user.id)

    if u["points"] < POINTS_PER_PREMIUM:
        text = (
            f"❌ *Not enough points\\!*\n\n"
            f"You have *{esc(u['points'])}* points\\.\n"
            f"You need *{POINTS_PER_PREMIUM}* points for 2 hours of Premium\\.\n\n"
            f"Share your referral link to earn more\\! Use /referral"
        )
        if hasattr(update, 'message') and update.message:
            await update.message.reply_text(text, parse_mode="MarkdownV2")
        else:
            await update.effective_message.reply_text(text, parse_mode="MarkdownV2")
        return

    u["points"] -= POINTS_PER_PREMIUM
    grant_premium(u)
    save_db(db)

    expires_in = int((u["premium_until"] - time.time()) / 60)
    h, m = divmod(expires_in, 60)

    text = (
        f"🎉 *Premium Activated\\!*\n\n"
        f"👑 You now have Premium for *2 hours*\\!\n"
        f"⏳ Expires in: *{h}h {m}m*\n"
        f"🪙 Remaining points: *{esc(u['points'])}*\n\n"
        f"Enjoy 1080p downloads and custom thumbnails\\! 🎬"
    )

    if hasattr(update, 'message') and update.message:
        await update.message.reply_text(text, parse_mode="MarkdownV2")
    else:
        await update.effective_message.reply_text(text, parse_mode="MarkdownV2")


# ─── /redeemcode ─────────────────────────────────────────────
async def redeemcode(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    if not context.args:
        await update.message.reply_text(
            "❌ Usage: `/redeemcode <code>`", parse_mode="MarkdownV2"
        )
        return

    code = context.args[0].upper()
    db = load_db()
    codes = db.get("redeem_codes", {})

    if code not in codes:
        await update.message.reply_text("❌ Invalid or expired code\\.", parse_mode="MarkdownV2")
        return

    code_data = codes[code]
    uid = str(user.id)

    if uid in code_data.get("used_by", []):
        await update.message.reply_text("❌ You already used this code\\.", parse_mode="MarkdownV2")
        return

    if code_data.get("max_uses", 1) <= len(code_data.get("used_by", [])):
        await update.message.reply_text("❌ This code has reached its usage limit\\.", parse_mode="MarkdownV2")
        return

    u = get_user(db, user.id)
    reward = code_data.get("points", 0)
    premium_hours = code_data.get("premium_hours", 0)

    if reward:
        u["points"] += reward
    if premium_hours:
        u["premium_until"] = max(u.get("premium_until", time.time()), time.time()) + (premium_hours * 3600)

    code_data.setdefault("used_by", []).append(uid)
    save_db(db)

    msg = "✅ *Code redeemed successfully\\!*\n\n"
    if reward:
        msg += f"🪙 \\+{reward} points added\\!\n"
    if premium_hours:
        msg += f"👑 \\+{premium_hours} hours of Premium added\\!\n"
    msg += f"\n🪙 Total points: *{esc(u['points'])}*"

    await update.message.reply_text(msg, parse_mode="MarkdownV2")


# ─── /broadcast ──────────────────────────────────────────────
async def broadcast(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    if not is_admin(user.id):
        await update.message.reply_text("⛔ Admin only\\.", parse_mode="MarkdownV2")
        return

    if not context.args:
        await update.message.reply_text(
            "❌ Usage: `/broadcast <message>`", parse_mode="MarkdownV2"
        )
        return

    message = " ".join(context.args)
    db = load_db()
    users = db["users"]

    sent = 0
    failed = 0
    status = await update.message.reply_text(f"📡 Broadcasting to {len(users)} users\\.\\.\\.", parse_mode="MarkdownV2")

    for uid in users:
        try:
            await context.bot.send_message(
                int(uid),
                f"📢 *Announcement*\n\n{esc(message)}\n\n_— A4U CR\\-DL Bot_",
                parse_mode="MarkdownV2"
            )
            sent += 1
            await asyncio.sleep(0.05)
        except Exception:
            failed += 1

    await status.edit_text(
        f"✅ Broadcast complete\\!\n\n📨 Sent: {sent}\n❌ Failed: {failed}",
        parse_mode="MarkdownV2"
    )


# ─── /gencode ────────────────────────────────────────────────
async def gencode(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    if not is_admin(user.id):
        await update.message.reply_text("⛔ Admin only\\.", parse_mode="MarkdownV2")
        return

    args = context.args
    points = int(args[0]) if len(args) > 0 else 0
    premium_hours = int(args[1]) if len(args) > 1 else 0
    max_uses = int(args[2]) if len(args) > 2 else 1

    code = secrets.token_hex(4).upper()
    db = load_db()
    db.setdefault("redeem_codes", {})[code] = {
        "points": points,
        "premium_hours": premium_hours,
        "max_uses": max_uses,
        "used_by": []
    }
    save_db(db)

    await update.message.reply_text(
        f"✅ *Redeem Code Generated\\!*\n\n"
        f"🎟️ Code: `{code}`\n"
        f"🪙 Points: *{points}*\n"
        f"👑 Premium Hours: *{premium_hours}*\n"
        f"👥 Max Uses: *{max_uses}*",
        parse_mode="MarkdownV2"
    )


# ─── /link ───────────────────────────────────────────────────
async def link(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    if not is_authorized(user.id):
        await update.message.reply_text("⛔ Not authorized\\.", parse_mode="MarkdownV2")
        return

    args = context.args
    if not args:
        await update.message.reply_text(
            "❌ Usage: `/link <url> [quality]`", parse_mode="MarkdownV2"
        )
        return

    url = args[0]
    quality = args[1].lower() if len(args) > 1 else "best"

    if not CR_URL_PATTERN.match(url):
        await update.message.reply_text("❌ Invalid Crunchyroll URL\\.", parse_mode="MarkdownV2")
        return

    if quality not in VALID_QUALITIES:
        await update.message.reply_text(
            f"❌ Invalid quality\\. Choose: {', '.join(f'`{q}`' for q in VALID_QUALITIES)}",
            parse_mode="MarkdownV2"
        )
        return

    db = load_db()
    u = get_user(db, user.id)
    save_db(db)
    user_is_premium = is_premium(u)

    if quality == "1080p" and not user_is_premium:
        await update.message.reply_text(
            "👑 *1080p is a Premium feature\\!*\n\n"
            "You need Premium to download in 1080p\\.\n\n"
            "Earn points by referring friends with /referral\n"
            "Then activate Premium with /redeem\n\n"
            "_3 points \\= 2 hours Premium_",
            parse_mode="MarkdownV2"
        )
        return

    Path(DOWNLOAD_DIR).mkdir(parents=True, exist_ok=True)
    premium_tag = " 👑" if user_is_premium else ""
    status = await update.message.reply_text(
        f"⏳ Starting download{esc(premium_tag)}\\.\\.\\.\n🎬 Quality: `{quality}`",
        parse_mode="MarkdownV2"
    )

    cmd = build_command(url, quality)
    try:
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT
        )

        output_lines = []
        saved_path = ""

        async for raw in process.stdout:
            line = raw.decode("utf-8", errors="replace").strip()
            if not line:
                continue
            output_lines.append(line)
            if "[download] Destination:" in line:
                saved_path = line.split("Destination:")[-1].strip()
            if len(output_lines) % 15 == 0:
                try:
                    await status.edit_text(
                        f"⏳ `{esc(line)}`", parse_mode="MarkdownV2"
                    )
                except Exception:
                    pass

        await process.wait()

        if process.returncode != 0:
            tail = esc("\n".join(output_lines[-5:]))
            await status.edit_text(
                f"❌ *Download failed\\.*\n\n`{tail}`",
                parse_mode="MarkdownV2"
            )
            return

        await status.edit_text("📦 Download complete\\! Sending file\\.\\.\\.", parse_mode="MarkdownV2")

        if saved_path and os.path.exists(saved_path):
            file_size = os.path.getsize(saved_path)
            if file_size > 2_000_000_000:
                await status.edit_text(
                    f"✅ *Downloaded\\!*\n\n"
                    f"⚠️ File is too large to send via Telegram \\({file_size // 1_000_000}MB\\)\\.\n"
                    f"📁 Saved at: `{esc(saved_path)}`",
                    parse_mode="MarkdownV2"
                )
                return

            fname = esc(os.path.basename(saved_path))
            caption = (
                f"🍥 *A4U CR\\-DL Bot*\n"
                f"📁 `{fname}`\n"
                f"🎬 Quality: `{quality}`"
            )
            if user_is_premium:
                caption += "\n👑 _Premium download_"
            caption += "\n\nCooked by @Mystery\\_143 👨‍🍳"

            with open(saved_path, "rb") as f:
                if user_is_premium:
                    thumb_path = saved_path.rsplit(".", 1)[0] + ".jpg"
                    thumb = open(thumb_path, "rb") if os.path.exists(thumb_path) else None
                    await context.bot.send_video(
                        chat_id=update.effective_chat.id,
                        video=f,
                        caption=caption,
                        parse_mode="MarkdownV2",
                        thumbnail=thumb,
                        supports_streaming=True,
                    )
                    if thumb:
                        thumb.close()
                else:
                    await context.bot.send_document(
                        chat_id=update.effective_chat.id,
                        document=f,
                        caption=caption,
                        parse_mode="MarkdownV2"
                    )
            await status.delete()
        else:
            await status.edit_text("✅ Download complete\\! File saved on server\\.", parse_mode="MarkdownV2")

    except FileNotFoundError:
        await status.edit_text("❌ `yt\\-dlp` not installed on server\\.", parse_mode="MarkdownV2")
    except Exception as e:
        logger.exception("Download error")
        await status.edit_text(f"❌ Error: {esc(str(e))}", parse_mode="MarkdownV2")


# ─── Callback Buttons ────────────────────────────────────────
async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    if query.data == "referral":
        await referral(query, context)
    elif query.data == "profile":
        await profile(query, context)
    elif query.data == "redeem":
        await redeem(query, context)


# ─── Main ────────────────────────────────────────────────────
def main():
    import asyncio
    import sys

    if sys.version_info >= (3, 12):
        try:
            loop = asyncio.get_event_loop()
            if loop.is_closed():
                raise RuntimeError
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

    app = Application.builder().token(BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("help", start))
    app.add_handler(CommandHandler("profile", profile))
    app.add_handler(CommandHandler("referral", referral))
    app.add_handler(CommandHandler("redeem", redeem))
    app.add_handler(CommandHandler("redeemcode", redeemcode))
    app.add_handler(CommandHandler("broadcast", broadcast))
    app.add_handler(CommandHandler("gencode", gencode))
    app.add_handler(CommandHandler("link", link))
    app.add_handler(CallbackQueryHandler(button_handler))
    logger.info("A4U CR-DL Bot started.")
    app.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == "__main__":
    main()
