#!/bin/sh -e

find . -name opennms-\*.rpm | xargs rpm --resign
