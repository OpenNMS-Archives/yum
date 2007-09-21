#!/bin/sh -e

find . -name opennms-repo\*.rpm | xargs rpm --resign
