function sb {
    source ~/.bashrc
}
function w {
    workon `pwd | xargs basename`
}
function m {
    mkvirtualenv `pwd | xargs basename` -a . --python=/usr/bin/python$1
}
function copydb {
    C="CREATE DATABASE \"$2\" WITH TEMPLATE \"$1\";"
    psql -c "$C"
}
function ddb {
    psql -l  | awk '{print $1;}' | grep -E $1 | xargs -t -I % dropdb %
}
