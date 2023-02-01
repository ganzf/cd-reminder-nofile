# Storage file for cd-reminder
cd_reminder_storage=$HOME/.cd-reminder

__prettyTodo__() {
  idx=$1
  if [ ! -z "$idx" ]; then
    idx="($idx) "
  fi
  line=$2
  since=`echo "$line" | cut -d' ' -f2`
  uuid=`echo "$line" | cut -d' ' -f3`
  done=`echo "$line" | cut -d' ' -f4`
  if [ "$done" = "[X]" ]; then
    isDone="$GREEN√$RESET"
  elif [ "$done" = "[O]" ]; then
    isDone="$RED✗$RESET"
  fi
  # compute duration between now and since (timestamp in seconds)
  duration=`expr $(date +%s) - $since`
  ((sec=duration%60, duration/=60, min=duration%60, hrs=duration/60))
  pretty=$(printf "created %dh%02dm%02ds ago" $hrs $min $sec)
  todo=`echo $line | cut -d' ' -f5-`
  echo -e "$idx$isDone $todo ($pretty)"
}

__getTodoList__() {
    BLUE='\033[0;34m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    RESET='\033[0m'
    pwd=`pwd`
    outputRaw=$1
    recursive=$2
    rootpath=`cat $cd_reminder_storage | grep "^$pwd\s" | cut -d' ' -f1 | uniq`
    if [ -z "$rootpath" ]; then
      return
    fi
    # subpaths is a list of paths matching the current pwd
    subpaths=`cat $cd_reminder_storage | grep $pwd | cut -d' ' -f1 | grep -v "^$rootpath$" | uniq`
    # rootpath is the first of the subpaths
    # echo "rootpath: [$rootpath]"
    # echo "subpaths: [$subpaths]"
    rootlines=`cat $cd_reminder_storage | grep "^$rootpath\s"`
    idx=0
    # for each line in rootlines print the line
    if [ "$recursive" = "true" ] && [ "$outputRaw" != "true" ]; then
      echo -e "$YELLOW$rootpath$RESET: "
    fi
    while IFS= read -r line; do
      #inc idx
      ((idx++))
      if [ "$outputRaw" = "true" ]; then
        echo $line
      else
        pretty=`__prettyTodo__ "$idx" "$line"`
        echo -e "$pretty"
      fi
    done <<< $rootlines
    # for each subpath, print the lines that match the subpath
    # if not recurive, return
    if [ "$recursive" != "true" ]; then
      return
    fi
    while IFS= read -r line; do
      # for each subpaths, do the loop above
      sublines=`cat $cd_reminder_storage | grep "^$line\s"`
      if [ -z "$sublines" ]; then
        continue
      fi
      if [ "$recursive" = "true" ] && [ "$outputRaw" != "true" ]; then
        subdir=`echo $line | cut -d' ' -f1`
        # treelike caracter for subdirs
        c="├──"
        echo -e "$c$YELLOW$subdir$RESET: "
      fi
      while IFS= read -r line; do
        #inc idx
        ((idx++))
        if [ "$outputRaw" = "true" ]; then
          echo $line
        else
          pretty=`__prettyTodo__ "$idx" "$line"`
          # treelike character for subfile
          c="│   └──"
          echo -e "$c$pretty"
        fi
      done <<< $sublines
    done <<< $subpaths
}

# calls the builtin cd command, and then optionally cat's the .cd-reminder file
# in the directory if it exists
reminder_cd() {
    # change directory and parse home file
    builtin cd "$@" && {
      __getTodoList__
    }
}

# Either creates an empty .cd-reminder file, or if an argument is included
# then creates and appends to that file the first argument
remindme() {
  if [ "$1" = "-h" ]; then
    echo "Usage: remindme <todo>"
    echo " Description: Will create a reminder for the current directory"
    echo " Example: remindme to do this thing and notice the spaces between the words"
    echo "Usage: itsdone <index>"
    echo " Description: Will mark the reminder as done"
    echo " Example: itsdone 1"
    echo "Usage: forgetit <index>"
    echo " Description: Will remove the reminder from the list"
    echo " Example: forgetit 1"
    echo "Usage: whatnow [-r]"
    echo " Description: Will list all the reminders"
    echo " Option: -r will list all the reminders recursively from subdirectories"
    echo " Example: whatnow -r"
    return
  fi

  todo=$@
  if [ -z "$todo" ]; then
    echo "Usage: remindme <todo>"
    return
  fi
  str=$@
  # if str contains \n, print error
  if [[ $str == *$'\n'* ]]; then
    echo "Error: todo cannot contain newlines"
    return
  fi
  pwd=`pwd`
  timestamp=`date +%s`
  # generate uuid
  uuid=`uuidgen`
  final="$pwd $timestamp $uuid [O] $todo"
  echo $final >> $cd_reminder_storage
  pretty=`__prettyTodo__ "" $final`
  echo -e "Added: $pretty"
}

# usage itsdone <index>
itsdone() {
  if [ -z "$1" ]; then
    echo "Usage: itsdone <index>"
    return
  fi
  while [ ! -z "$1" ]; do
    idx=$1
    lineidx=0
    list=`__getTodoList__ true true`
    while IFS= read -r line; do
      # inc lineidx
      ((lineidx++))
      # echo "line: $line"
      # echo "lineidx: $lineidx"
      # if the line does not start with (number) continue
      if [ "$lineidx" = "$idx" ]; then
        uuid=`echo $line | cut -d' ' -f3`
        # echo "uuid: $uuid"
        # remove the line that has the same uuid from $cd_reminder_storage
        # cross platform: avoid using sed
        # echo "[$line]"
        raw=`cat $cd_reminder_storage`
        # echo "raw: [$raw]"
        next_first=`echo $raw | grep -B 10000 $uuid | grep -v $uuid`
        # echo "next_first: [$next_first]"
        # replace [O] with [X] in line without using sed
        nextline=`echo $line | tr '[O]' '[X]'`
        # echo "nextline: [$nextline]"

        next_second=`echo $raw | grep -A 10000 $uuid | grep -v $uuid`
        # echo "next_second: [$next_second]"
        # pretty=`__prettyTodo__ "" $nextline`
        # echo "pretty: [$pretty]"
        echo $next_first > $cd_reminder_storage
        echo $nextline >> $cd_reminder_storage
        echo $next_second >> $cd_reminder_storage
      fi
    done <<< $list
    shift
  done
  whatnow
}

# usage forgetit <index>
forgetit() {
  if [ -z "$1" ]; then
    echo "Usage: itsdone <index>"
    return
  fi
  uuids=""
  while [ ! -z "$1" ]; do
    idx=$1
    lineidx=0
    list=`__getTodoList__ true true`
    while IFS= read -r line; do
      ((lineidx++))
      if [ "$lineidx" = "$idx" ]; then
        # if the line does not start with (number) continue
        uuid=`echo $line | cut -d' ' -f3`
        if [ -z "$uuids" ]; then
          uuids="\($uuid"
        else
          uuids="$uuids\|$uuid"
        fi
      fi
    done <<< $list
  shift
  done
  uuids="$uuids\)"
  # echo "uuids: $uuids"
  raw=`cat $cd_reminder_storage`
  next=`echo $raw | grep -v "$uuids"`
  echo "$next" > $cd_reminder_storage
  whatnow
}

whatnow() {
  # no raw output but use recursion
  list=`__getTodoList__ false true`
  if [ -z "$list" ]; then
    echo "You have no todos !"
    return
  fi
  echo "You have the following todos:"
  echo $list
}

alias cd=reminder_cd