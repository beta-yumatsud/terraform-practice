#!/usr/bin/env sh
amazon-linux-extras install -y docker
systemctl start docker
systemctl enable docker
