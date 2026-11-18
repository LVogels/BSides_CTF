"""
CASTRA LEGIONIS — Frontier Watch Console
=========================================
Intentionally vulnerable web app for the "Ambiorix" BSides Limburg CTF.

Attack surface (by design):
  1. A shared "recruit" account whose credentials are leaked in an HTML comment
     on the login page (view-source enumeration).
  2. Once authenticated, the watch-report form renders the attacker-controlled
     `sigil` field through render_template_string() -> Jinja2 SSTI -> RCE.

Everything in this file is deliberately insecure and scoped to the lab.
"""
from flask import Flask, request, redirect, session, render_template_string

app = Flask(__name__)
app.secret_key = "frontier-watch-rotates-at-dawn"

# VULN: hard-coded shared recruit account; creds leaked in login page source.
RECRUIT_USER = "tiro"
RECRUIT_PASS = "AveLegioXIV-54"

# In-memory board (resets on restart -> trivially stateless between solvers).
REPORTS = [
    {"author": "praefectus", "sigil": "LEG-XIV",
     "report": "Night watch quiet. Fires seen in the tree line to the north-east."},
    {"author": "optio", "sigil": "CORVVS",
     "report": "Supply wagons from Aduatuca delayed again. Scouts uneasy."},
]


def page(title, body, logged_in=False, extra_head=""):
    """Plain string-templated layout. No Jinja here -> SSTI is isolated to `sigil`."""
    nav = ('<a href="/board">Watch Board</a> &middot; <a href="/logout">Stand down</a>'
           if logged_in else '<a href="/login">Report for duty</a>')
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} &middot; Castra Legionis</title>{extra_head}
<style>
  :root{{--ink:#e8e2d0;--bg:#1a1613;--panel:#241f1a;--gold:#c9a227;--line:#4a3f33;}}
  *{{box-sizing:border-box}}
  body{{margin:0;font-family:Georgia,'Times New Roman',serif;background:var(--bg);
       color:var(--ink);line-height:1.5}}
  header{{background:linear-gradient(180deg,#2d261f,#1a1613);border-bottom:2px solid var(--gold);
         padding:18px 20px}}
  header h1{{margin:0;font-size:20px;letter-spacing:2px;color:var(--gold)}}
  header small{{color:#9b8f7a;letter-spacing:1px}}
  nav{{margin-top:8px;font-size:14px}} nav a{{color:var(--gold);text-decoration:none;margin-right:6px}}
  main{{max-width:760px;margin:24px auto;padding:0 16px}}
  .panel{{background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:18px;margin-bottom:16px}}
  h2{{color:var(--gold);border-bottom:1px solid var(--line);padding-bottom:6px;font-size:18px}}
  label{{display:block;margin:10px 0 4px;color:#b9ad96;font-size:14px}}
  input,textarea{{width:100%;background:#15110d;border:1px solid var(--line);color:var(--ink);
                 padding:8px;border-radius:4px;font-family:inherit}}
  button{{margin-top:14px;background:var(--gold);color:#1a1613;border:0;padding:9px 18px;
         border-radius:4px;font-weight:bold;cursor:pointer;letter-spacing:1px}}
  pre.sigil{{background:#15110d;border:1px dashed var(--gold);padding:12px;border-radius:4px;
            white-space:pre-wrap;word-break:break-word}}
  .report{{border-left:3px solid var(--gold);padding:6px 12px;margin:10px 0;background:#1f1a15}}
  .report .meta{{color:#9b8f7a;font-size:13px}}
  .flash{{color:#e0b84a}}
  footer{{text-align:center;color:#6b6152;font-size:12px;margin:30px 0}}
</style></head>
<body>
<header>
  <h1>CASTRA LEGIONIS</h1>
  <small>Frontier Watch Console &middot; Legio XIV &middot; Aduatuca sector</small>
  <nav>{nav}</nav>
</header>
<main>{body}</main>
<footer>Property of the Roman frontier command. Unauthorised access is forbidden by the Legate.</footer>
</body></html>"""


@app.route("/")
def index():
    body = """
    <div class="panel">
      <h2>Ave, legionary.</h2>
      <p>This console logs the night-watch reports for the frontier camp. Only
      enlisted men may file or read reports. If you have been posted to the watch,
      report for duty and enter your watchword.</p>
      <p><a href="/login" style="color:#c9a227">&raquo; Report for duty</a></p>
    </div>"""
    return page("Watch Console", body)


@app.route("/login", methods=["GET", "POST"])
def login():
    flash = ""
    if request.method == "POST":
        u = request.form.get("username", "")
        p = request.form.get("password", "")
        if u == RECRUIT_USER and p == RECRUIT_PASS:
            session["user"] = u
            return redirect("/board")
        flash = '<p class="flash">Watchword rejected. The optio has been notified.</p>'
    # VULN: leaked credentials in an HTML comment (view-source enumeration).
    leak = ("\n    <!-- TODO(centurion): disable the shared recruit login before "
            "we go live. creds still: tiro / AveLegioXIV-54 -->\n")
    body = f"""{leak}
    <div class="panel">
      <h2>Report for duty</h2>
      {flash}
      <form method="post">
        <label>Name</label>
        <input name="username" autocomplete="off" placeholder="e.g. tiro">
        <label>Watchword</label>
        <input name="password" type="password" autocomplete="off">
        <button type="submit">Enter the camp</button>
      </form>
    </div>"""
    return page("Report for duty", body)


@app.route("/logout")
def logout():
    session.clear()
    return redirect("/")


@app.route("/board", methods=["GET", "POST"])
def board():
    if "user" not in session:
        return redirect("/login")

    filed = ""
    if request.method == "POST":
        author = request.form.get("author", "anon").strip() or "anon"
        report = request.form.get("report", "").strip()
        sigil = request.form.get("sigil", "").strip()

        if report:
            REPORTS.append({"author": author, "sigil": sigil, "report": report})

        # Light discipline filter (flavour + stops the low-effort config dump).
        if "config" in sigil.lower():
            rendered = "[the centurion forbids that word upon a sigil]"
        else:
            # VULN: attacker-controlled `sigil` passed to render_template_string
            #       -> Server-Side Template Injection -> RCE.
            try:
                rendered = render_template_string(sigil)
            except Exception as e:  # keep the service up no matter what players throw
                rendered = f"[sigil could not be struck: {type(e).__name__}]"

        filed = f"""
        <div class="panel">
          <h2>Report filed under your sigil</h2>
          <p>The quartermaster strikes your sigil into the wax tablet:</p>
          <pre class="sigil">{rendered}</pre>
        </div>"""

    # NOTE: report bodies are rendered safely (escaped via !r-ish manual escape).
    rows = ""
    for r in REPORTS:
        safe = (r["report"].replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))
        who = (r["author"].replace("<", "&lt;").replace(">", "&gt;"))
        sig = (r["sigil"].replace("<", "&lt;").replace(">", "&gt;"))
        rows += (f'<div class="report"><div class="meta">{who} &middot; '
                 f'sigil {sig}</div>{safe}</div>')

    form = """
    <div class="panel">
      <h2>File a watch report</h2>
      <form method="post">
        <label>Your name</label>
        <input name="author" autocomplete="off">
        <label>Report</label>
        <textarea name="report" rows="3"></textarea>
        <label>Sigil (stamped onto the tablet)</label>
        <input name="sigil" autocomplete="off" placeholder="e.g. LEG-XIV">
        <button type="submit">File report</button>
      </form>
    </div>"""

    body = filed + form + f'<div class="panel"><h2>Watch board</h2>{rows}</div>'
    return page("Watch Board", body, logged_in=True)


@app.route("/healthz")
def healthz():
    return "ok\n", 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
