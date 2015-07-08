#!/bin/sh

pushd ../../opensource_projects/rawline/
gem build *.gemspec
popd
gem install ../../opensource_projects/rawline/*.gem
