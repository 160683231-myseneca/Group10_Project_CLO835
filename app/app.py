from flask import Flask, g,render_template, request, url_for
from pymysql import connections
import re
import os
import random
import argparse
import logging
import sys


app = Flask(__name__)

app.logger.addHandler(logging.StreamHandler(sys.stdout))
app.logger.setLevel(logging.INFO)

def get_env_var_or_default(env_var_name, default_value):
    return os.environ.get(env_var_name) or default_value

GROUPNAME_FROM_ENV = get_env_var_or_default("GROUP_NAME", "Group Name")
GROUPSLOGAN_FROM_ENV = get_env_var_or_default("GROUP_SLOGAN", "Our Group Slogan")
GROUPIMAGE_FROM_ENV = get_env_var_or_default("GROUP_IMAGE", "https://picsum.photos/1300/250")
DBHOST = get_env_var_or_default("DBHOST", "localhost")
DBUSER = get_env_var_or_default("DBUSER", "root")
DBPWD = os.environ.get("DBPWD")
if DBPWD is None or DBPWD == "":
    raise ValueError("DBPWD environment variable is not set or is empty")
DATABASE = get_env_var_or_default("DATABASE", "employees")
VERSION_FROM_ENV = get_env_var_or_default("VERSION", "v1")
COLOR_FROM_ENV = get_env_var_or_default("APP_COLOR", "opal")
DBPORT = int(get_env_var_or_default("DBPORT", "3306"))

# Define the supported color codes
color_codes = {
    "red": "#e74c3c",
    "green": "#16a085",
    "blue": "#89CFF0",
    "blue2": "#30336b",
    "pink": "#f4c2c2",
    "darkblue": "#130f40",
    "lime": "#C1FF9C",
    "opal": "#a8e4e0",
}

color_pattern = "|".join(color_codes.keys())
version_color_regex = re.compile(rf"^/(?P<version>v\d+(\.\d+)*)/(?P<color>{color_pattern})(?:/|$)")
color_version_regex = re.compile(rf"^/(?P<color>{color_pattern})/(?P<version>v\d+(\.\d+)*)(?:/|$)")
version_regex= re.compile(r"^/(?P<version>v\d+(\.\d+)*)(?:/|$)")
color_regex = re.compile(rf"^/(?P<color>{color_pattern})(?:/|$)")

def extract_global_env(request_path):
    version_color_match = version_color_regex.match(request_path)
    if version_color_match:
        version = version_color_match.group('version')
        color = version_color_match.group('color')
    else:
        color_version_match = color_version_regex.match(request_path)
        if color_version_match:
            version = color_version_match.group('version')
            color = color_version_match.group('color')
        else:
            version_match = version_regex.match(request_path)
            if version_match:
                version = version_match.group('version')
                color = None
            else:
                color_match = color_regex.match(request_path)
                if color_match:
                    color = color_match.group('color')
                    version = None
                else:
                    version, color = None, None
    return version, color

# Process command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('--color', required=False, default=COLOR_FROM_ENV)
parser.add_argument('--version', required=False, default=VERSION_FROM_ENV)
parser.add_argument('--groupname', required=False, default=GROUPNAME_FROM_ENV)
parser.add_argument('--groupslogan', required=False, default=GROUPSLOGAN_FROM_ENV)
parser.add_argument('--groupimage', required=False, default=GROUPIMAGE_FROM_ENV)
args = parser.parse_args()

VERSION = args.version
if args.color in color_codes:
    COLOR = args.color
else:
    COLOR = "red"
GROUPNAME=args.groupname
GROUPSLOGAN=args.groupslogan
GROUPIMAGE=args.groupimage

# Set the app configuration for VERSION and COLOR
app.config['VERSION'] = VERSION
app.config['COLOR'] = color_codes[COLOR]
app.config['GROUPNAME'] = GROUPNAME
app.config['GROUPSLOGAN'] = GROUPSLOGAN
app.config['GROUPIMAGE'] = GROUPIMAGE

# Connect to MySQL database
try:
    db_conn = connections.Connection(
        host=DBHOST,
        port=DBPORT,
        user=DBUSER,
        password=DBPWD, 
        db=DATABASE,
    )
except Exception as e:
    print(f"Failed to connect to database: {e}")
    exit(1)
    
@app.context_processor
def inject_global_env():
    app.logger.info(f"Injecting GROUPIMAGE={app.config['GROUPIMAGE']}")
    return dict(
        VERSION=app.config['VERSION'],
        COLOR=app.config['COLOR'],
        GROUPNAME=app.config['GROUPNAME'],
        GROUPSLOGAN=app.config['GROUPSLOGAN'],
        GROUPIMAGE=app.config['GROUPIMAGE']
    )
    
@app.before_request
def initialize_global_env():
    version, color = extract_global_env(request.path)
    g.version = version
    g.color = color
    g.groupname = app.config['GROUPNAME']
    g.groupslogan = app.config['GROUPSLOGAN']
    g.groupimage = app.config['GROUPIMAGE']
    app.logger.info(f"Initializing GROUPIMAGE={g.groupimage}")

@app.context_processor
def inject_versioned_url():
    def complete_url(endpoint, **values):
        version = g.get('version')
        color = g.get('color')
        if version and color:
            return f"/{version}/{color}/{endpoint.lstrip('/')}"
        elif version:
            return f"/{version}/{endpoint.lstrip('/')}"
        elif color:
            return f"/{color}/{endpoint.lstrip('/')}"
        else:
            return f"/{endpoint.lstrip('/')}"
    return dict(complete_url=complete_url)


@app.route("/", methods=['GET', 'POST'])
@app.route("/<path1>/", methods=['GET', 'POST'])
@app.route("/<path1>/<path2>/", methods=['GET', 'POST'])
def home(path1=None, path2=None):
    return render_template('addemp.html')

@app.route("/about", methods=['GET','POST'])
@app.route("/<path1>/about", methods=['GET', 'POST'])
@app.route("/<path1>/<path2>/about", methods=['GET', 'POST'])
def about(path1=None, path2=None):
    return render_template('about.html')
    
@app.route("/addemp", methods=['POST'])
@app.route("/<path1>/addemp", methods=['GET', 'POST'])
@app.route("/<path1>/<path2>/addemp", methods=['GET', 'POST'])
def addemp(path1=None, path2=None):
    emp_id = request.form['emp_id']
    first_name = request.form['first_name']
    last_name = request.form['last_name']
    primary_skill = request.form['primary_skill']
    location = request.form['location']

  
    insert_sql = "INSERT INTO employee VALUES (%s, %s, %s, %s, %s)"
    cursor = db_conn.cursor()

    try:
        
        cursor.execute(insert_sql,(emp_id, first_name, last_name, primary_skill, location))
        db_conn.commit()
        emp_name = "" + first_name + " " + last_name

    finally:
        cursor.close()

    print("all modification done...")
    return render_template('addempoutput.html', name=emp_name)

@app.route("/getemp", methods=['GET', 'POST'])
@app.route("/<path1>/getemp", methods=['GET', 'POST'])
@app.route("/<path1>/<path2>/getemp", methods=['GET', 'POST'])
def getemp(path1=None, path2=None):
    return render_template("getemp.html")


@app.route("/fetchdata", methods=['GET','POST'])
@app.route("/<path1>/fetchdata", methods=['GET', 'POST'])
@app.route("/<path1>/<path2>/fetchdata", methods=['GET', 'POST'])
def fetchdata(path1=None, path2=None):
    emp_id = request.form['emp_id']

    output = {}
    select_sql = "SELECT emp_id, first_name, last_name, primary_skill, location from employee where emp_id=%s"
    cursor = db_conn.cursor()

    try:
        cursor.execute(select_sql,(emp_id))
        result = cursor.fetchone()
        
        # Add No Employee found form
        output["emp_id"] = result[0]
        output["first_name"] = result[1]
        output["last_name"] = result[2]
        output["primary_skills"] = result[3]
        output["location"] = result[4]
        
    except Exception as e:
        print(e)

    finally:
        cursor.close()

    return render_template("getempoutput.html", id=output["emp_id"], fname=output["first_name"],
                           lname=output["last_name"], interest=output["primary_skills"], location=output["location"])

if __name__ == '__main__':

    app.run(host='0.0.0.0',port=81,debug=True)
