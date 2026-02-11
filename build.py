import argparse
import glob
import platform
import logging
import shutil
import subprocess
import sys
import os
import urllib.request
import zipfile


# Note: these paths are for local Windows installs.  All of these tools
# can be installed under Linux as well, but these paths will need to change.
plat = platform.system()
assembler = ".\\merlin\\Merlin32_v1.2_b2\\windows\\merlin32.exe"
assembler_libdir = ".\\merlin\\Merlin32_v1.2_b2\\library\\"
ciderpresscli = ".\\ciderpress\\cp2.exe"


def merlin_check(app, libdir, cpapp):
    # If merlin is present, do nothing
    if not os.path.exists("merlin"):
        # pull a version from the web
        url="https://brutaldeluxe.fr/products/crossdevtools/merlin/Merlin32_v1.2.zip"
        try:
            log.info(f"Attempting to pull merlin32 from: {url}")
            _ = urllib.request.urlretrieve(url, "merlin.zip")
        except Exception as e:
            log.warning(f"Download failed: {e}")
            return app, libdir, cpapp
        # unpack
        try:
            os.makedirs("merlin")
            with zipfile.ZipFile("merlin.zip", "r") as zf:
                zf.extractall("merlin")
            os.unlink("merlin.zip")
        except Exception as e:
            log.warning(f"Unable to unpack Merlin32: {e}")
    if not os.path.exists("ciderpress"):
        url = "https://github.com/fadden/CiderPress2/releases/download/v1.1.1/cp2_1.1.1_win-x86_sc.zip"
        try:
            log.info(f"Attempting to pull ciderpress from: {url}")
            _ = urllib.request.urlretrieve(url, "ciderpress.zip")
        except Exception as e:
            log.warning(f"Download failed: {e}")
            return app, libdir, cpapp
        # unpack
        try:
            os.makedirs("ciderpress")
            with zipfile.ZipFile("ciderpress.zip", "r") as zf:
                zf.extractall("ciderpress")
            os.unlink("ciderpress.zip")
        except Exception as e:
            log.warning(f"Unable to unpack ciderpress: {e}")
    # generate the name of the assembler and the library directory
    prefix = glob.glob("merlin/*")[0]
    app = os.path.join(prefix, plat, "merlin32")
    if plat.startswith("Win"):
        app += ".exe"
    libdir = os.path.join(prefix, "library")
    log.info(f"Using Merlin32: {app} {libdir}")
    cpapp = os.path.join("ciderpress", "cp2")
    if plat.startswith("Win"):
        cpapp += ".exe"
    log.info(f"Using CiderPress2: {cpapp}")
    return app, libdir, cpapp


parser = argparse.ArgumentParser()
parser.add_argument("--verbose", action="store_true", default=False, help="Run in verbose mode")
parser.add_argument("--logfile", help="Log file for verbose output", default="")
parser.add_argument("--debug", action="store_true", default=False, help="Include BASIC.SYSTEM")
args = parser.parse_args()

mode = "release"
if args.debug:
    mode = "debug"

# Set up logging
level = logging.INFO
if args.verbose:
    level = logging.DEBUG
    
log = logging.getLogger("build")
logging.basicConfig(filename=args.logfile, level=level)

assembler, assembler_libdir, ciderpresscli = merlin_check(assembler, assembler_libdir, ciderpresscli)

# Check for all the tools to be present
prerequisites = True
for name in (assembler, assembler_libdir, ciderpresscli, ):
    if not os.path.exists(name):
        log.warning(f"required build tool: {name} could not be found.")
        prerequisites = False
if not prerequisites:
    log.error("Please install necessary build tools and rerun the build process.")
    sys.exit(1)

# Set the version number and start the build process
# Must be 5 characters
version = [0,1,0]
s=""
for v in version:
    s += f"{int(v):02x}0a"
s = s[:-2] + "ff"
version = f"{version[0]}.{version[1]}.{version[2]}"
    
# Burn the version number into the source file VERSION.S 
log.info("Generating 6502 source code...")
with open(os.path.join("src","VERSION.S"), "w") as out:
    text = f"version  asc  '{version}'\n"
    out.write(text)

for name in ("extract_font.py", "gen_xpos_table.py", "gen_sprites.py"):
    cmd = [sys.executable, os.path.join("utilities", name)]
    log.info(f"Running script: {name}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if '[Error]' in result.stdout:
        result.returncode = 1
    if result.returncode != 0:
        log.error(f"Error running: {name}: {result.stdout}")
        sys.exit(1)

files = ["DRAWING.S", "LOADER.S", "SPACEPARA.S"]

log.info("Assembling 6502 source code...")

# compile sources
# Merlin does not handle subdirs very well...
orig_dir = os.getcwd()
os.chdir("src")
for name in files:
    cmd = [os.path.join("..", assembler), os.path.join("..", assembler_libdir), name]
    log.info(f"Assembling: {name}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if '[Error]' in result.stdout:
        result.returncode = 1
    if result.returncode != 0:
        log.error(f"assembling: {name}: {result.stdout}")
        sys.exit(1)
os.chdir(orig_dir)


log.info("Building SPACEPAR.SYSTEM(SYS#ff) file...")

# Build 'SPACEPAR.SYSTEM,TSYS' from bins
# size is $2000+length of SPACEPARA#064000
with open("bin/SPACEPARA#064000", "rb") as f:
    game_data = f.read()
with open("bin/LOADER#062000", "rb") as f:
    loader_data = f.read()
with open("bin/DRAWING#060800", "rb") as f:
    drawing_data = f.read()

data = bytearray(len(game_data)+0x2000)
data[0:0+len(loader_data)] = loader_data
data[0x0800:0x0800+len(drawing_data)] = drawing_data
data[0x2000:0x2000+len(game_data)] = game_data

outname = "SYSTEM/SPACEPAR.SYSTEM#ff2000"
with open(outname, "wb") as fp:
    fp.write(data)
log.info(f"Wrote system file: {outname}")

log.info("Building .po disk image...")
# Create a release .po image
rel_filename = "SpacePara_Release.po"
try:
    os.remove(rel_filename)
except Exception:
    pass
cmd = [ciderpresscli, "create-disk-image", rel_filename, "140K", "prodos"]
result = subprocess.run(cmd, capture_output=True, text=True, check=True)
log.info(f"Created release disk image: {result.stdout} {result.stderr}")
cmd = [ciderpresscli, "rename", rel_filename, ":", f"SPACEP_{version}"]
result = subprocess.run(cmd, capture_output=True, text=True, check=True)
log.info(f"Renamed release disk image: {result.stdout} {result.stderr}")

# Copy system files - PRODOS, BASIC...  
try:
    os.remove("SYSTEM/_FileInformation.txt")
except Exception:
    pass
cmd = [ciderpresscli, "add", "--strip-paths", rel_filename, "SYSTEM"]
result = subprocess.run(cmd, capture_output=True, text=True, check=True)
log.info(f"System files added to disk image: {result.stdout} {result.stderr}")

# in release mode builds, remove SYSTEM/BASIC.SYSTEM
if mode == "release":
    cmd = [ciderpresscli, "rm", rel_filename, "BASIC.SYSTEM"]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    log.info(f"System files added to disk image: {result.stdout} {result.stderr}")
    
for name in os.listdir("basic"):
    if name.upper().endswith(".ABAS"):
        root = os.path.splitext(name)[0]
        try:
            os.remove(os.path.join("basic", root))
        except Exception:
            pass
        # make a temp copy to rename the file so the import is clean
        shutil.copy(os.path.join("basic", name), os.path.join("basic", root))
        cmd = [ciderpresscli, "import", "--strip-paths", rel_filename, "bas",  f"basic/{root}"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        os.remove(os.path.join("basic", root))
        log.info(f"Imported: basic/{name} as {root}")

skip_prefix = ["_", "BIGFONT", "DRAWING", "LOADER", "TITLE", "SPACEPARA"]
for name in os.listdir("bin"):
    valid = True
    for s in skip_prefix:
        if name.startswith(s):
            valid = False
    if not valid:
        continue
    cmd = [ciderpresscli, "add", "--strip-paths", rel_filename, f"bin/{name}"]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    log.info(f"Imported: {name}")

log.info(f"Build v{version} complete.")
 