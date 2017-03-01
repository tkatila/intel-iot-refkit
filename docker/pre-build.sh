#!/bin/bash -xeu
# pre-build.sh: Pre-build steps
# Copyright (c) 2017, Intel Corporation.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.

# Catch errors in pipelines
set -o pipefail

# bitbake started to depend on a locale with UTF-8 support
# when migrating to Python3.
export LC_ALL=en_US.UTF-8

cd $WORKSPACE

# document env.vars in build log
env |sort

# use +u to avoid exit caused by unbound variables use in init scripts
set +u
# note, BUILD_DIR is also undef in CI case, but is set in local-build case.
source refkit-init-build-env ${BUILD_DIR}
set -u

# Take local CI preferences if present, 1st time, to get bb_e_env parsed
if [ -f $WORKSPACE/meta-*/conf/distro/include/refkit-ci.inc ]; then
  cat $WORKSPACE/meta-*/conf/distro/include/refkit-ci.inc > conf/auto.conf
fi

# use bitbake -e for variables parsing, then pick REFKIT_CI part
bitbake -e >bb_e_out 2>bb_e_err || (cat bb_e_err && false)
grep -E "^REFKIT_CI" bb_e_out > ${WORKSPACE}/refkit_ci_vars || true

if [ ! -z ${JOB_NAME+x} ]; then
  # in CI: run pre-build oe-selftests using development-mode settings in auto.conf
  # we can't use full auto.conf of builder, oe-selftest does not like buildhistory=ON
  echo "include conf/distro/include/refkit-development.inc" > ${WORKSPACE}/build/conf/auto.conf
  _tests=`grep REFKIT_CI_PREBUILD_SELFTESTS ${WORKSPACE}/refkit_ci_vars | perl -pe 's/.+="(.*)"/\1/g; s/[^ .a-zA-Z0-9_-]//g'`
  if [ -n "$_tests" ]; then
    oe-selftest --run-tests ${_tests}
  fi
  rm -f ${WORKSPACE}/build/conf/auto.conf
fi

