#!/bin/bash

set -e

systemctl enable --now ufw.service
ufw default deny incoming
ufw default allow outgoing
ufw enable