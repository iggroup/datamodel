#!/bin/bash
pg_dump -Fc -f ../dumps/qgep_tuto.dump -d "service=qgep_tuto"
pg_dump -Fc -f ../dumps/qgep_ardon.dump -d "service=qgep_ardon"
pg_dump -Fc -f ../dumps/qgep_conthey.dump -d "service=qgep_conthey"
pg_dump -Fc -f ../dumps/qgep_mtnoble.dump -d "service=qgep_mtnoble"
pg_dump -Fc -f ../dumps/qgep_vetroz.dump -d "service=qgep_vetroz"
pg_dump -Fc -f ../dumps/qgep_vex.dump -d "service=qgep_vex"

# Launch PUM upgrade
psql -U postgres -c 'DROP DATABASE qgep_test;'
psql -U postgres -c 'CREATE DATABASE qgep_test;'
pum test-and-upgrade -pp qgep_tuto -pt qgep_test -pc qgep_comp -t qgep_sys.pum_info -d delta/ -f ../dumps/dump.dump -i constraints views indexes --exclude-schema public --exclude-schema qgep_migration -v int SRID 2056 -x

psql -U postgres -c 'DROP DATABASE qgep_test;'
psql -U postgres -c 'CREATE DATABASE qgep_test;'
pum test-and-upgrade -pp qgep_ardon -pt qgep_test -pc qgep_comp -t qgep_sys.pum_info -d delta/ -f dump.dump -i constraints views indexes --exclude-schema public -v int SRID 2056

psql -U postgres -c 'DROP DATABASE qgep_test;'
psql -U postgres -c 'CREATE DATABASE qgep_test;'
pum test-and-upgrade -pp qgep_conthey -pt qgep_test -pc qgep_comp -t qgep_sys.pum_info -d delta/ -f dump.dump -i constraints views indexes --exclude-schema public -v int SRID 2056

psql -U postgres -c 'DROP DATABASE qgep_test;'
psql -U postgres -c 'CREATE DATABASE qgep_test;'
pum test-and-upgrade -pp qgep_mtnoble -pt qgep_test -pc qgep_comp -t qgep_sys.pum_info -d delta/ -f dump.dump -i constraints views indexes --exclude-schema public -v int SRID 2056

psql -U postgres -c 'DROP DATABASE qgep_test;'
psql -U postgres -c 'CREATE DATABASE qgep_test;'
pum test-and-upgrade -pp qgep_vetroz -pt qgep_test -pc qgep_comp -t qgep_sys.pum_info -d delta/ -f dump.dump -i constraints views indexes --exclude-schema public -v int SRID 2056

psql -U postgres -c 'DROP DATABASE qgep_test;'
psql -U postgres -c 'CREATE DATABASE qgep_test;'
pum test-and-upgrade -pp qgep_vex -pt qgep_test -pc qgep_comp -t qgep_sys.pum_info -d delta/ -f dump.dump -i constraints views indexes --exclude-schema public -v int SRID 2056
