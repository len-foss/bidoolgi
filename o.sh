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
function _prod2test {
    click-odoo-dropdb $DBTEST
    click-odoo-copydb $DB $DBTEST
    _clean 0 $DBTEST
}
function _clean {
    DB=${2:-$DB}
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
function _upi {
    click-odoo-update -c .odoorc -d $DB --i18n-overwrite
}
function _i {
    odoo -d `pwd | xargs basename` -c ./.odoorc --db-filter=$DBFILTER -i $2 --stop-after-init
}
function _u {
    odoo -d `pwd | xargs basename` -c ./.odoorc --db-filter=$DBFILTER -u $2 --stop-after-init
}
function _rd {
    odoo -d $DB -c ./.odoorc --db-filter=$DBFILTER --dev=all
}
function _r {
    odoo -d $DB -c ./.odoorc --db-filter=$DBFILTER
}
function _rt {
    odoo -d $DBTEST -c ./.odoorc --db-filter=$DBFILTERTEST
}
function _rs {
    odoo shell -d $DB -c ./.odoorc -p 9069
}
function _rst {
    odoo shell -d $DBTEST -c ./.odoorc -p 9069
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

PROJECT_ADDONS_PATH="odoo/addons"

function commit_odoo_addon {
    local folder="$1"
    local commit_tag="$2"
    git add "$PROJECT_ADDONS_PATH/$folder"
    git commit -m "[$commit_tag] $folder:"
}

function commit_odoo_addons {
    local folders="$1"
    local commit_tag="$2"
    git add "$PROJECT_ADDONS_PATH"
    git commit -m "[$commit_tag] $folders:"
}

function _c {
    local commit_tag="$2"
    local changed_folders=()
    
    # Determine the correct path to check
    local addons_path="$PROJECT_ADDONS_PATH"
    local current_dir=$(pwd)
    local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    
    # If we're already in the odoo/addons directory, use relative paths
    if [[ "$current_dir" == "$git_root/$PROJECT_ADDONS_PATH" ]] || [[ "$current_dir" =~ /odoo/addons$ ]]; then
        # Use --relative to get paths relative to current directory
        while IFS= read -r folder_name; do
            if [[ -n "$folder_name" && ! " ${changed_folders[@]} " =~ " ${folder_name} " ]]; then
                changed_folders+=("$folder_name")
            fi
        done < <(git diff --name-only --cached --relative 2>/dev/null | cut -d'/' -f1 | sort -u)
        
        # If no staged changes, check unstaged changes
        if [ ${#changed_folders[@]} -eq 0 ]; then
            while IFS= read -r folder_name; do
                if [[ -n "$folder_name" && ! " ${changed_folders[@]} " =~ " ${folder_name} " ]]; then
                    changed_folders+=("$folder_name")
                fi
            done < <(git diff --name-only --relative 2>/dev/null | cut -d'/' -f1 | sort -u)
        fi
    else
        # Running from project root or elsewhere
        while IFS= read -r folder_name; do
            if [[ -n "$folder_name" && ! " ${changed_folders[@]} " =~ " ${folder_name} " ]]; then
                changed_folders+=("$folder_name")
            fi
        done < <(git diff --name-only --cached "$addons_path" 2>/dev/null | sed "s|^$addons_path/||" | cut -d'/' -f1 | sort -u)

        # If no staged changes, check unstaged changes
        if [ ${#changed_folders[@]} -eq 0 ]; then
            while IFS= read -r folder_name; do
                if [[ -n "$folder_name" && ! " ${changed_folders[@]} " =~ " ${folder_name} " ]]; then
                    changed_folders+=("$folder_name")
                fi
            done < <(git diff --name-only "$addons_path" 2>/dev/null | sed "s|^$addons_path/||" | cut -d'/' -f1 | sort -u)
        fi
    fi

    if [ ${#changed_folders[@]} -eq 0 ]; then
        echo "No changes found in $PROJECT_ADDONS_PATH"
        return 0
    fi

    if [ -z "$commit_tag" ]; then
        echo "Select commit tag:"
        echo "1) IMP (Improvement)"
        echo "2) REF (Refactor)"
        echo "3) ADD (Add)"
        echo "4) REM (Remove)"
        echo "5) FIX (Fix)"
        echo "6) Custom input"
        read -p "Enter choice (1-6): " -n 1 -r
        echo

        case $REPLY in
            1) commit_tag="IMP" ;;
            2) commit_tag="REF" ;;
            3) commit_tag="ADD" ;;
            4) commit_tag="REM" ;;
            5) commit_tag="FIX" ;;
            6)
                read -p "Enter custom commit tag: " commit_tag
                ;;
            *)
                echo "Invalid choice, using FIX as default"
                commit_tag="FIX"
                ;;
        esac
    fi

    if [ ${#changed_folders[@]} -eq 1 ]; then
        echo "All changes belong to folder: ${changed_folders[0]}"
        commit_odoo_addon "${changed_folders[0]}" "$commit_tag"
    else
        echo "Changes found in multiple folders: ${changed_folders[*]}"
        read -p "Should commits be split? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for folder in "${changed_folders[@]}"; do
                commit_odoo_addon "$folder" "$commit_tag"
            done
        else
            folders_str=$(IFS=','; echo "${changed_folders[*]}")
            commit_odoo_addons "$folders_str" "$commit_tag"
        fi
    fi
}

_$1 "$@"
