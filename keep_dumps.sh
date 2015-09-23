#!/bin/bash

. /opt/reductor_satellite/etc/const 

mkdir -p /var/rkn/
cp $SSLDIR/php/register.zip /var/rkn/register_$(date +day_%d_hour_%H).zip
