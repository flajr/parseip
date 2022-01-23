import os
import std/[parseopt, parseutils, re, tables, strutils]
import zip/gzipfiles

proc perr(s: string, i: int) =
  echo "ERROR: " & s
  quit i

proc pinf(s: string, verbose: bool) =
  if verbose:
    echo "INFO: " & s

let help = """
    parseip [OPTIONS] [FILE[ FILE]]

    + support for reading *.gz files
    + PATTERN support regex syntax
    + Regex for IPv4 is fast and simple: \b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b
      WARNING: This Regex can obviously parse some non IPv4 addresses
    + Reading STDIN if no file is present

    SYNTAX for OPTIONS:
      -o:ARG        # OK
      -o=ARG        # OK
      -oARG         # OK
      -o ARG        # ERROR
      --option:ARG  # OK
      --option=ARG  # OK
      --optionARG   # ERROR
      --option ARG  # OK

    OPTIONS:
      -c|--clean              Cleaner output, do not print address counts
                              + Output is sorted
                              + Honor --limit settings
      -e|--exclude=PATTERN    Exclude IP if line contains PATTERN 
                              + usable with -p, exclude has priority
      -h|--help               Show this help
      -i|--ignorecase         Ignore case for -p and -e options
      -l|--limit=NUM          Limit output number of addresses
                              + Default: 25
                              + For no limit set to 0
      -p|--parse=PATTERN      Parse IP only if line contains PATTERN
                              + usable with -e, exclude has priority
      -n|--nosort             Do not sort output (performance gain is almost zero)
                              + Sorting is by occurances of IPs
      -s|--seek=BYTES[K,M,G]  Skip BYTES when reading input
                              + No suffix means standard bytes
                              + [K,M,G] are standard unit suffixes of Byte
                              + Base is 1024 (NOT 1000)
      --version               Version of program
      -v|--verbose            Show what is going on

    EXAMPLES:
      parseip -c FILE
      parseip -l=10 FILE.gz
      cat FILE |parseip
      parseip --parse "85.237.234.40|85.237.254.228" FILE
      parseip -p"sasl" -e"127.0.0.1|46.229.230|93.184.77" FILE
      parseip -p="127.0.0.[0-9]+" FILE
      parseip -s20M /var/log/messages
    """.dedent()

var
  version     = "1.6.0"
  stdinBool   = true
  counter     = 0
  ipLimit     = 25
  args = initOptParser(shortNoVal = {'c','h','i','v','V', 'n'}, longNoVal = @["clean","help","version","verbose","ignorecase","nosort"])
  files:        seq[string]
  verboseBool     = false
  cleanBool   = false
  ipCount     = initCountTable[string]()
  matches:      seq[string]
  parse:        string
  parseRe:      Regex
  parseBool   = false
  exclude:      string
  excludeRe:    Regex
  excludeBool = false
  ignoreCase  = false
  sortBool    = true
  seekBool    = false
  seekValue:    int
  gzBool      = false

let
  gzRegex = re(r"\.gz$")
  # ipRegexAccurate = re"(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
  ipRegexSimple = re(r"[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}", {reStudy})

for kind, key, val in getopt(args):
  case kind
  of cmdEnd: 
    assert(false)
  of cmdLongOption, cmdShortOption:
    case key
    of "clean", "c":
      pinf("Clean output, do not print address counts", verboseBool)
      cleanBool = true
    of "exclude", "e":
      exclude = val
      pinf("Exclude lines containing: " & exclude, verboseBool)
    of "help", "h": 
      echo "Version: " & version
      echo help
      quit 0
    of "version", "V": 
      echo "Version: " & version
      quit 0
    of "ignorecase", "i":
      pinf("Setting case insensivity", verboseBool)
      ignoreCase = true
    of "limit", "l":
      if parseInt(val, ipLimit, 0) == 0:
        perr("Bad limit, must be number", 3)
      else:
        if ipLimit < 0:
          perr("Lowest number for limit is 0", 2)
        pinf("Setting output limit: " & intToStr(ipLimit), verboseBool)
    of "verbose", "v": 
      verboseBool = true
      pinf("Verbose output", verboseBool)
    of "parse", "p":
      parse = val
      pinf("Parse only lines containing: " & parse, verboseBool)
    of "nosort", "n":
      sortBool = false
      pinf("Sorting by occurances disabled", verboseBool)
    of "seek", "s":
      var seekType: int

      if parseInt(val, seekValue, 0) == 0:
        perr("Bad seek value: Must be number", 3)

      if seekValue <= 0:
        perr("Bad seek value: Must be higher than 0", 3)

      if   val.endsWith("K"): seekType = 1024
      elif val.endsWith("M"): seekType = 1024 * 1024
      elif val.endsWith("G"): seekType = 1024 * 1024 * 1024
      else:                   seekType = 1

      seekValue = seekValue * seekType
      pinf("Skip " & intToStr(seekValue) & " bytes for input stream", verboseBool)
      seekBool = true
    else:
      perr("Bad option: " & key, 1)
  of cmdArgument:
    # file argument given means no stdin, only options allowed
    stdinBool = false
    if fileExists(key):
      pinf("Search in file: " & key, verboseBool)
      files.add(key)
    else:
      perr("File is missing or not readable: " & key, 1)

if not isEmptyOrWhitespace(parse):
  parseBool = true
  if ignoreCase:
    parseRe = re(parse, {reStudy, reIgnoreCase})
  else:
    parseRe = re(parse, {reStudy})

if not isEmptyOrWhitespace(exclude):
  excludeBool = true
  if ignoreCase:
    excludeRe = re(exclude, {reStudy, reIgnoreCase})
  else:
    excludeRe = re(exclude, {reStudy})

if stdinBool:
  files.add("_STDIN_")

for file in files:
  let fileIter: Stream = 
    if contains(file, gzRegex, 0):
      pinf("Found .gz extension", verboseBool)
      gzBool = true
      newGzFileStream(file)
    elif stdinBool and file == "_STDIN_":
      pinf("Reading stdin...", verboseBool)
      newFileStream(stdin)
    else:
      newFileStream(file)

  if seekBool:
    setPosition(fileIter, seekValue)

  for line in fileIter.lines:
    if excludeBool and contains(line, excludeRe, 0): continue
    if parseBool and not contains(line, parseRe, 0): continue
    matches = findAll(line, ipRegexSimple, 0)
    for match in matches:
      ipCount.inc(match)

if sortBool:
  ipCount.sort()

if cleanBool:
  for k in keys(ipCount):
    if counter == ipLimit: 
      break
    echo k  
    inc counter
else:
  for k, v in pairs(ipCount):
    if counter == ipLimit: 
      break
    echo v, "\t", k
    inc counter
