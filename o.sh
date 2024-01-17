#!/bin/bash

DB=`pwd | xargs basename`
DBFILTER="^${DB}$"
DBTEST=`pwd | xargs basename`-tests
DBFILTERTEST="^${DBTEST}$"

function _k {
    pkill -9 odoo
}
function _setup {
    pip install --upgrade pip
    pip install -r requirements.txt -e .
    pip install pudb ipython
}
function _doc {
    V=`python -c "import sys;t='{v[0]}.{v[1]}'.format(v=list(sys.version_info[:2]));sys.stdout.write(t)";` # python -V does not really work in 2
    F=~/src/doc_$DB
    pigeoo -m $2 -p ~/src/$DB/odoo/addons,~/.virtualenvs/$DB/lib/python$V/site-packages/odoo/addons -o $F
    python3 -m webbrowser -t $F/index_module.html 2>&1
}
function _clean {
    B=`odoo --version | awk '{print $3;}' | sed 's/\..*//'`
    if (($B<12)) ; then
        psql -d $DB -c "update res_users set login='admin' where id=1;"
    else
        psql -d $DB -c "update res_users set login='admin' where id=2;"
    fi
    psql -d $DB -c "UPDATE res_users SET password=login;"
    psql -d $DB -c "DELETE FROM ir_attachment WHERE name like '%assets_%';"
    psql -d $DB -c "UPDATE ir_cron SET active='f';"
    psql -d $DB -c "UPDATE ir_mail_server SET active=false;"
    psql -d $DB -c "UPDATE ir_config_parameter SET value = '2042-01-01 00:00:00' WHERE key = 'database.expiration_date';"
    psql -d $DB -c "UPDATE ir_config_parameter SET value = '"+new_uuid+"' WHERE key = 'database.uuid';"
    psql -d $DB -c "INSERT INTO ir_mail_server(active,name,smtp_host,smtp_port,smtp_encryption) VALUES (true,'mailcatcher','localhost',1025,false);"
}
function _pu {
    pip-df sync --update $2
}
function _ga {
    gitaggregate -c gitaggregate.yaml -d src/$2 -p
}
function _release {
    echo "git push && acsoo tag"
    git push && acsoo tag
}
function _bumpp {
    bumpversion patch  --commit && _release
}
function _bumpm {
    bumpversion minor  --commit && _release
}
function _bumpM {
    bumpversion major  --commit && _release
}
function _ddb {
    psql -l  | awk '{print $1;}' | grep -E $2 | xargs -t -I % click-odoo-dropdb %
}
function _dropdbs {
    PATTERN=`pwd | xargs basename`_
    _ddb 0 $PATTERN
}
# Main database
function _up {
    click-odoo-update -c .odoorc -d $DB
}
function _i {
    odoo -d `pwd | xargs basename` -c ./.odoorc --db-filter=$DBFILTER -i $2 --stop-after-init
}
function _u {
    odoo -d `pwd | xargs basename` -c ./.odoorc --db-filter=$DBFILTER -u $2 --stop-after-init
}
function _r {
    odoo -d $DB -c ./.odoorc --db-filter=$DBFILTER
}
function _rs {
    odoo shell -d $DB -c ./.odoorc
}
# Test DB
function _upt {
    click-odoo-update -c .odoorc -d $DBTEST
}
function _it {
    odoo -d $DBTEST -c ./.odoorc --db-filter=$DBFILTERTEST -i $2 --stop-after-init
}
function _t {
    odoo -d $DBTEST -c ./.odoorc --db-filter=$DBFILTERTEST -u $2 --test-enable --stop-after-init --workers 0
}
# Module-specific databases
function _rtt {
    DB=`pwd | xargs basename`_$2-tests
    DBFILTER="^${DB}$"
    odoo -d $DB -c ./.odoorc --db-filter=$DBFILTER
}
function _itt {
    DB=`pwd | xargs basename`_$2-tests
    DBFILTER="^${DB}$"
    echo $DB
    if psql $DB -c '' 2>&1; then
        dropdb $DB
    fi
    odoo -d $DB -c ./.odoorc --db-filter=$DBFILTER -i $2 --stop-after-init
}
function _itti {
    DB=`pwd | xargs basename`_$2-tests
    DBFILTER="^${DB}$"
    odoo -d $DB -c ./.odoorc --db-filter=$DBFILTER -i $3 --stop-after-init
}
function _tt {
    DB=`pwd | xargs basename`_$2-tests
    DBFILTER="^${DB}$"
    if ! psql $DB -c '' 2>&1 ; then
        echo "Installing first..."
        odoo -d $DB -c ./.odoorc --db-filter=$DBFILTER -i $2 --stop-after-init
    fi
    odoo -d $DB -c ./.odoorc --db-filter=$DBFILTER -u $2 --test-enable --stop-after-init --workers 0
}

# profiling
function _xprof {
  # if on python2, install gprof2dot in the venv
  XPROF="$2.xdot"
  gprof2dot -f pstats -o $XPROF $2
  xdot $XPROF
}

_$1 "$@"
